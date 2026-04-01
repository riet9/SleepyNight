function Get-DefaultConfig {
    @{
        enabled = $true
        schedule = @{
            useWeekendSchedule = $true
            weekdays = @{
                start = "20:30"
                end = "03:00"
            }
            weekends = @{
                start = "22:30"
                end = "04:00"
            }
        }
        enforcementMode = "lock_shutdown"
        graceMinutes = 2
        lockCheckSeconds = 30
        warningMinutes = @(60, 30, 15, 10, 5, 1)
        messageTitle = "SleepyNight"
        loggingEnabled = $true
        statusRefreshSeconds = 5
        emergencyCode = ""
        skipCooldownDays = 14
        scheduleChangeCooldownDays = 7
        watchdogEnabled = $true
        watchdogHeartbeatFreshSeconds = 120
        watchdogRepairCooldownSeconds = 90
    }
}

function Get-DefaultState {
    @{
        skipUntil = $null
        lastSkipActivatedAt = $null
        lastScheduleChangeAt = $null
        quickTestBackupConfig = $null
        lastUpdated = $null
        note = ""
        lastWatchdogCheckAt = $null
        lastWatchdogRepairAt = $null
        lastWatchdogReason = ""
    }
}

function Get-DefaultStatus {
    @{
        phase = "unknown"
        statusText = "Status is not available yet"
        nextStart = $null
        nextEnd = $null
        activeSchedule = ""
        skipUntil = $null
        lastUpdated = $null
        agentRunning = $false
        agentPid = $null
        lastAction = ""
        heartbeatUtc = $null
        watchdogState = "unknown"
        watchdogReason = ""
        watchdogLastCheckUtc = $null
        watchdogLastRepairUtc = $null
    }
}

function Get-ConfigPath {
    Join-Path $PSScriptRoot "sleepy-night-config.json"
}

function Get-StatePath {
    Join-Path $PSScriptRoot "sleepy-night-state.json"
}

function Get-StatusPath {
    Join-Path $PSScriptRoot "sleepy-night-status.json"
}

function Get-LogPath {
    Join-Path $PSScriptRoot "sleepy-night.log"
}

function ConvertTo-Hashtable {
    param([object]$InputObject)

    if ($null -eq $InputObject) {
        return @{}
    }

    if ($InputObject -is [hashtable]) {
        return $InputObject
    }

    $result = @{}
    foreach ($property in $InputObject.PSObject.Properties) {
        $value = $property.Value
        if ($value -is [System.Management.Automation.PSCustomObject] -or $value -is [hashtable]) {
            $result[$property.Name] = ConvertTo-Hashtable -InputObject $value
        } elseif ($value -is [System.Array]) {
            $items = @()
            foreach ($item in $value) {
                if ($item -is [System.Management.Automation.PSCustomObject] -or $item -is [hashtable]) {
                    $items += ,(ConvertTo-Hashtable -InputObject $item)
                } else {
                    $items += $item
                }
            }
            $result[$property.Name] = $items
        } else {
            $result[$property.Name] = $value
        }
    }

    $result
}

function Merge-ConfigData {
    param(
        [hashtable]$Defaults,
        [hashtable]$Overrides
    )

    $merged = @{}
    foreach ($key in $Defaults.Keys) {
        $defaultValue = $Defaults[$key]
        if ($Overrides.ContainsKey($key)) {
            $overrideValue = $Overrides[$key]
            if ($defaultValue -is [hashtable] -and $overrideValue -is [hashtable]) {
                $merged[$key] = Merge-ConfigData -Defaults $defaultValue -Overrides $overrideValue
            } else {
                $merged[$key] = $overrideValue
            }
        } else {
            $merged[$key] = $defaultValue
        }
    }

    foreach ($key in $Overrides.Keys) {
        if (-not $merged.ContainsKey($key)) {
            $merged[$key] = $Overrides[$key]
        }
    }

    $merged
}

function Save-JsonFile {
    param(
        [string]$Path,
        [hashtable]$Data
    )

    $Data | ConvertTo-Json -Depth 8 | Set-Content -Path $Path -Encoding UTF8
}

function Read-JsonFile {
    param(
        [string]$Path,
        [hashtable]$Defaults
    )

    if (-not (Test-Path $Path)) {
        Save-JsonFile -Path $Path -Data $Defaults
        return [pscustomobject]$Defaults
    }

    try {
        $raw = Get-Content -Path $Path -Raw | ConvertFrom-Json
        $current = ConvertTo-Hashtable -InputObject $raw
        $merged = Merge-ConfigData -Defaults $Defaults -Overrides $current
        if ((ConvertTo-Json $current -Depth 8) -ne (ConvertTo-Json $merged -Depth 8)) {
            Save-JsonFile -Path $Path -Data $merged
        }
        return [pscustomobject]$merged
    } catch {
        Save-JsonFile -Path $Path -Data $Defaults
        return [pscustomobject]$Defaults
    }
}

function Initialize-SleepyNightFiles {
    Read-Config | Out-Null
    Read-State | Out-Null
    Read-Status | Out-Null
    if (-not (Test-Path (Get-LogPath))) {
        Set-Content -Path (Get-LogPath) -Value "" -Encoding UTF8
    }
}

function Read-Config {
    Read-JsonFile -Path (Get-ConfigPath) -Defaults (Get-DefaultConfig)
}

function Save-Config {
    param([hashtable]$Config)

    Save-JsonFile -Path (Get-ConfigPath) -Data $Config
}

function Get-ScheduleChangeCooldownDays {
    param([object]$Config = $null)

    if ($null -eq $Config) {
        $Config = Read-Config
    }

    $days = [int]($Config.scheduleChangeCooldownDays)
    if ($days -lt 0) {
        return 0
    }

    return $days
}

function Get-NextScheduleChangeAvailableAt {
    param(
        [object]$State,
        [object]$Config = $null
    )

    if ($null -eq $Config) {
        $Config = Read-Config
    }

    if ($null -eq $State.lastScheduleChangeAt -or [string]::IsNullOrWhiteSpace([string]$State.lastScheduleChangeAt)) {
        return $null
    }

    $cooldownDays = Get-ScheduleChangeCooldownDays -Config $Config
    if ($cooldownDays -le 0) {
        return $null
    }

    ([datetime]$State.lastScheduleChangeAt).AddDays($cooldownDays)
}

function Test-ScheduleChanged {
    param(
        [object]$CurrentConfig,
        [object]$NewConfig
    )

    return (
        [string]$CurrentConfig.schedule.weekdays.start -ne [string]$NewConfig.schedule.weekdays.start -or
        [string]$CurrentConfig.schedule.weekdays.end -ne [string]$NewConfig.schedule.weekdays.end -or
        [string]$CurrentConfig.schedule.weekends.start -ne [string]$NewConfig.schedule.weekends.start -or
        [string]$CurrentConfig.schedule.weekends.end -ne [string]$NewConfig.schedule.weekends.end -or
        [bool]$CurrentConfig.schedule.useWeekendSchedule -ne [bool]$NewConfig.schedule.useWeekendSchedule
    )
}

function Save-ConfigWithPolicy {
    param(
        [hashtable]$Config,
        [switch]$IgnoreScheduleCooldown,
        [string]$Source = "SleepyNight"
    )

    $currentConfig = ConvertTo-Hashtable -InputObject (Read-Config)
    $state = ConvertTo-Hashtable -InputObject (Read-State)
    $now = Get-Date
    $scheduleChanged = Test-ScheduleChanged -CurrentConfig ([pscustomobject]$currentConfig) -NewConfig ([pscustomobject]$Config)

    if ($scheduleChanged -and -not $IgnoreScheduleCooldown) {
        $nextAvailableAt = Get-NextScheduleChangeAvailableAt -State ([pscustomobject]$state) -Config ([pscustomobject]$currentConfig)
        if ($null -ne $nextAvailableAt -and $now -lt $nextAvailableAt) {
            throw ("Schedule change is on cooldown until {0}." -f $nextAvailableAt.ToString("dd.MM.yyyy HH:mm"))
        }
    }

    Save-Config -Config $Config

    if ($scheduleChanged -and -not $IgnoreScheduleCooldown) {
        $state["lastScheduleChangeAt"] = $now.ToString("o")
        Save-State -State $state
        Write-Log -Message ("Schedule was changed from {0}" -f $Source)
    }
}

function Read-State {
    Read-JsonFile -Path (Get-StatePath) -Defaults (Get-DefaultState)
}

function Save-State {
    param([hashtable]$State)

    $State["lastUpdated"] = (Get-Date).ToString("o")
    Save-JsonFile -Path (Get-StatePath) -Data $State
}

function Get-QuickTestBackupConfig {
    $state = ConvertTo-Hashtable -InputObject (Read-State)
    if ($null -eq $state["quickTestBackupConfig"]) {
        return $null
    }

    ConvertTo-Hashtable -InputObject $state["quickTestBackupConfig"]
}

function Save-QuickTestBackupConfig {
    param(
        [hashtable]$Config,
        [switch]$Force
    )

    $state = ConvertTo-Hashtable -InputObject (Read-State)
    if (-not $Force -and $null -ne $state["quickTestBackupConfig"]) {
        return
    }

    $state["quickTestBackupConfig"] = $Config
    Save-State -State $state
}

function Clear-QuickTestBackupConfig {
    $state = ConvertTo-Hashtable -InputObject (Read-State)
    $state["quickTestBackupConfig"] = $null
    Save-State -State $state
}

function Read-Status {
    Read-JsonFile -Path (Get-StatusPath) -Defaults (Get-DefaultStatus)
}

function Save-StatusInternal {
    param([hashtable]$Status)

    $Status["lastUpdated"] = (Get-Date).ToString("o")
    Save-JsonFile -Path (Get-StatusPath) -Data $Status
}

function Save-Status {
    param([hashtable]$Status)

    $Status["heartbeatUtc"] = (Get-Date).ToUniversalTime().ToString("o")
    Save-StatusInternal -Status $Status
}

function Save-StatusWithoutHeartbeat {
    param([hashtable]$Status)

    Save-StatusInternal -Status $Status
}

function Get-WatchdogHeartbeatFreshSeconds {
    param([object]$Config = $null)

    if ($null -eq $Config) {
        $Config = Read-Config
    }

    $seconds = [int]($Config.watchdogHeartbeatFreshSeconds)
    if ($seconds -lt 15) {
        return 15
    }

    return $seconds
}

function Get-WatchdogRepairCooldownSeconds {
    param([object]$Config = $null)

    if ($null -eq $Config) {
        $Config = Read-Config
    }

    $seconds = [int]($Config.watchdogRepairCooldownSeconds)
    if ($seconds -lt 5) {
        return 5
    }

    return $seconds
}

function Get-AgentHealthStatus {
    param(
        [object]$Config = $null,
        [object]$Status = $null
    )

    if ($null -eq $Config) {
        $Config = Read-Config
    }

    if ($null -eq $Status) {
        $Status = Read-Status
    }

    $heartbeatFreshSeconds = Get-WatchdogHeartbeatFreshSeconds -Config $Config
    $processAlive = $false
    $agentPid = $null

    if ($null -ne $Status.agentPid -and [int]$Status.agentPid -gt 0) {
        $agentPid = [int]$Status.agentPid
        try {
            $processAlive = -not (Get-Process -Id $agentPid -ErrorAction Stop).HasExited
        } catch {
            $processAlive = $false
        }
    }

    if (-not $processAlive) {
        $processAlive = Test-AgentRunning
    }

    $heartbeatUtc = $null
    if ($null -ne $Status.heartbeatUtc -and -not [string]::IsNullOrWhiteSpace([string]$Status.heartbeatUtc)) {
        $heartbeatUtc = [datetime]$Status.heartbeatUtc
    }

    $heartbeatAgeSeconds = $null
    $heartbeatHealthy = $false
    $heartbeatState = "missing"
    if ($null -ne $heartbeatUtc) {
        $heartbeatAgeSeconds = [int][Math]::Max(0, ((Get-Date).ToUniversalTime() - $heartbeatUtc.ToUniversalTime()).TotalSeconds)
        if ($heartbeatAgeSeconds -le $heartbeatFreshSeconds) {
            $heartbeatHealthy = $true
            $heartbeatState = "healthy"
        } elseif ($heartbeatAgeSeconds -le ($heartbeatFreshSeconds * 3)) {
            $heartbeatState = "stale"
        } else {
            $heartbeatState = "old"
        }
    }

    $reason = if (-not $processAlive) {
        "Agent process is not running"
    } elseif (-not $heartbeatHealthy) {
        if ($heartbeatState -eq "missing") {
            "Heartbeat is missing"
        } else {
            "Heartbeat is $heartbeatState"
        }
    } else {
        "Agent is healthy"
    }

    @{
        ProcessAlive = $processAlive
        AgentPid = $agentPid
        HeartbeatUtc = $heartbeatUtc
        HeartbeatAgeSeconds = $heartbeatAgeSeconds
        HeartbeatHealthy = $heartbeatHealthy
        HeartbeatState = $heartbeatState
        ShouldRestart = (-not $processAlive) -or (-not $heartbeatHealthy)
        Reason = $reason
    }
}

function Update-WatchdogSnapshot {
    param(
        [string]$State,
        [string]$Reason,
        [datetime]$Now = (Get-Date),
        [Nullable[datetime]]$RepairAt = $null
    )

    $stateData = ConvertTo-Hashtable -InputObject (Read-State)
    $stateData["lastWatchdogCheckAt"] = $Now.ToString("o")
    $stateData["lastWatchdogReason"] = $Reason
    if ($RepairAt.HasValue) {
        $stateData["lastWatchdogRepairAt"] = $RepairAt.Value.ToString("o")
    }
    Save-State -State $stateData

    $statusData = ConvertTo-Hashtable -InputObject (Read-Status)
    $statusData["watchdogState"] = $State
    $statusData["watchdogReason"] = $Reason
    $statusData["watchdogLastCheckUtc"] = $Now.ToUniversalTime().ToString("o")
    if ($RepairAt.HasValue) {
        $statusData["watchdogLastRepairUtc"] = $RepairAt.Value.ToUniversalTime().ToString("o")
    }
    Save-StatusWithoutHeartbeat -Status $statusData
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $config = Read-Config
    if (-not $config.loggingEnabled) {
        return
    }

    $line = "{0} [{1}] {2}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -Path (Get-LogPath) -Value $line -Encoding UTF8

    $allLines = Get-Content -Path (Get-LogPath)
    if ($allLines.Count -gt 1000) {
        $allLines | Select-Object -Last 1000 | Set-Content -Path (Get-LogPath) -Encoding UTF8
    }
}

function ConvertTo-TimeSpanValue {
    param([string]$TimeText)

    if ([string]::IsNullOrWhiteSpace($TimeText)) {
        throw "Time must not be empty."
    }

    $parts = $TimeText.Split(":")
    if ($parts.Count -ne 2) {
        throw "Time must be in HH:mm format."
    }

    New-TimeSpan -Hours ([int]$parts[0]) -Minutes ([int]$parts[1])
}

function Get-ScheduleForDate {
    param(
        [object]$Config,
        [datetime]$Date
    )

    $weekend = $Date.DayOfWeek -in @([DayOfWeek]::Saturday, [DayOfWeek]::Sunday)
    $useWeekend = [bool]$Config.schedule.useWeekendSchedule -and $weekend

    if ($useWeekend) {
        return @{
            Name = "Weekend"
            Start = [string]$Config.schedule.weekends.start
            End = [string]$Config.schedule.weekends.end
        }
    }

    return @{
        Name = "Weekday"
        Start = [string]$Config.schedule.weekdays.start
        End = [string]$Config.schedule.weekdays.end
    }
}

function Get-WindowForDate {
    param(
        [object]$Config,
        [datetime]$Date
    )

    $schedule = Get-ScheduleForDate -Config $Config -Date $Date
    $startSpan = ConvertTo-TimeSpanValue -TimeText $schedule.Start
    $endSpan = ConvertTo-TimeSpanValue -TimeText $schedule.End
    $start = $Date.Date.Add($startSpan)
    $end = $Date.Date.Add($endSpan)

    if ($end -le $start) {
        $end = $end.AddDays(1)
    }

    @{
        Start = $start
        End = $end
        ScheduleName = $schedule.Name
        StartText = $schedule.Start
        EndText = $schedule.End
        WindowId = "{0}_{1}_{2}" -f $Date.ToString("yyyyMMdd"), $schedule.Start, $schedule.End
    }
}

function Get-RelevantWindow {
    param(
        [object]$Config,
        [datetime]$Now = (Get-Date)
    )

    $previousWindow = Get-WindowForDate -Config $Config -Date $Now.Date.AddDays(-1)
    $todayWindow = Get-WindowForDate -Config $Config -Date $Now.Date
    $tomorrowWindow = Get-WindowForDate -Config $Config -Date $Now.Date.AddDays(1)

    if ($Now -ge $previousWindow.Start -and $Now -lt $previousWindow.End) {
        $previousWindow["InRestriction"] = $true
        $previousWindow["NextWindow"] = $todayWindow
        return $previousWindow
    }

    if ($Now -ge $todayWindow.Start -and $Now -lt $todayWindow.End) {
        $todayWindow["InRestriction"] = $true
        $todayWindow["NextWindow"] = $tomorrowWindow
        return $todayWindow
    }

    if ($Now -lt $todayWindow.Start) {
        $todayWindow["InRestriction"] = $false
        $todayWindow["NextWindow"] = $todayWindow
        return $todayWindow
    }

    $tomorrowWindow["InRestriction"] = $false
    $tomorrowWindow["NextWindow"] = $tomorrowWindow
    $tomorrowWindow
}

function Get-AgentProcesses {
    $scriptPath = Join-Path $PSScriptRoot "sleepy-night-agent.ps1"
    $escapedPath = [Regex]::Escape($scriptPath)
    @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" | Where-Object {
        $_.CommandLine -match $escapedPath
    })
}

function Test-AgentRunning {
    (Get-AgentProcesses).Count -gt 0
}

function Start-AgentProcess {
    if (Test-AgentRunning) {
        return $false
    }

    $scriptPath = Join-Path $PSScriptRoot "sleepy-night-agent.ps1"
    Start-Process -WindowStyle Hidden -FilePath "powershell.exe" -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $scriptPath
    ) | Out-Null

    $true
}

function Stop-AgentProcess {
    $processes = Get-AgentProcesses
    foreach ($process in $processes) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }

    $processes.Count
}

function Get-SkipCooldownDays {
    param([object]$Config = $null)

    if ($null -eq $Config) {
        $Config = Read-Config
    }

    $days = [int]($Config.skipCooldownDays)
    if ($days -lt 0) {
        return 0
    }

    return $days
}

function Get-NextSkipAvailableAt {
    param(
        [object]$State,
        [object]$Config = $null
    )

    if ($null -eq $Config) {
        $Config = Read-Config
    }

    if ($null -eq $State.lastSkipActivatedAt -or [string]::IsNullOrWhiteSpace([string]$State.lastSkipActivatedAt)) {
        return $null
    }

    $cooldownDays = Get-SkipCooldownDays -Config $Config
    if ($cooldownDays -le 0) {
        return $null
    }

    ([datetime]$State.lastSkipActivatedAt).AddDays($cooldownDays)
}

function Get-SkipText {
    param(
        [object]$State,
        [object]$Config = $null
    )

    if ($null -eq $Config) {
        $Config = Read-Config
    }

    if ($null -ne $State.skipUntil -and -not [string]::IsNullOrWhiteSpace([string]$State.skipUntil)) {
        $skipUntil = [datetime]$State.skipUntil
        if ((Get-Date) -lt $skipUntil) {
            return "Skip is active until {0}" -f $skipUntil.ToString("dd.MM HH:mm")
        }
    }

    $nextAvailableAt = Get-NextSkipAvailableAt -State $State -Config $Config
    if ($null -ne $nextAvailableAt -and (Get-Date) -lt $nextAvailableAt) {
        return "Next skip is available on {0}" -f $nextAvailableAt.ToString("dd.MM HH:mm")
    }

    return ""
}

function Set-SkipUntil {
    param([datetime]$Until)

    $config = Read-Config
    $state = ConvertTo-Hashtable -InputObject (Read-State)
    $now = Get-Date

    if ($null -ne $state["skipUntil"] -and -not [string]::IsNullOrWhiteSpace([string]$state["skipUntil"])) {
        $currentSkipUntil = [datetime]$state["skipUntil"]
        if ($now -lt $currentSkipUntil) {
            throw ("Skip is already active until {0}." -f $currentSkipUntil.ToString("dd.MM.yyyy HH:mm"))
        }
    }

    $nextAvailableAt = Get-NextSkipAvailableAt -State ([pscustomobject]$state) -Config $config
    if ($null -ne $nextAvailableAt -and $now -lt $nextAvailableAt) {
        throw ("Skip is on cooldown until {0}." -f $nextAvailableAt.ToString("dd.MM.yyyy HH:mm"))
    }

    $state["skipUntil"] = $Until.ToString("o")
    $state["lastSkipActivatedAt"] = $now.ToString("o")
    Save-State -State $state
    Write-Log -Message ("Restriction skip is active until {0}" -f $Until.ToString("dd.MM.yyyy HH:mm"))
}

function Clear-Skip {
    $state = ConvertTo-Hashtable -InputObject (Read-State)
    $state["skipUntil"] = $null
    Save-State -State $state
    Write-Log -Message "Restriction skip cleared"
}

function Get-TaskNames {
    param([string]$TaskPrefix = "SleepyNight")

    @{
        Agent = "$TaskPrefix Agent"
        Watchdog = "$TaskPrefix Watchdog"
    }
}

function Get-WatchdogTimes {
    @(
        "00:15",
        "02:15",
        "04:15",
        "06:15",
        "08:15",
        "10:15",
        "12:15",
        "14:15",
        "16:15",
        "18:15",
        "20:15",
        "22:15"
    )
}

function Test-ScheduledTaskInstalled {
    param([string]$TaskName)

    try {
        $process = Start-Process `
            -FilePath "schtasks.exe" `
            -ArgumentList @("/Query", "/TN", $TaskName) `
            -NoNewWindow `
            -PassThru `
            -Wait `
            -RedirectStandardOutput "$env:TEMP\sleepynight-taskcheck.out" `
            -RedirectStandardError "$env:TEMP\sleepynight-taskcheck.err"

        return ($process.ExitCode -eq 0)
    } catch {
        return $false
    } finally {
        Remove-Item "$env:TEMP\sleepynight-taskcheck.out" -ErrorAction SilentlyContinue
        Remove-Item "$env:TEMP\sleepynight-taskcheck.err" -ErrorAction SilentlyContinue
    }
}

