. (Join-Path $PSScriptRoot "sleepy-night-core.ps1")

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class SleepyNightNative {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool LockWorkStation();
}
"@

$mutex = New-Object System.Threading.Mutex($false, "Global\SleepyNightAgent")
if (-not $mutex.WaitOne(0, $false)) {
    exit 0
}

function Show-Message {
    param(
        [string]$Title,
        [string]$Text
    )

    try {
        msg.exe * "$Title`n$Text" | Out-Null
    } catch {
        # Ignore environments where interactive messages are unavailable.
    }
}

function Update-AgentStatus {
    param(
        [string]$Phase,
        [string]$StatusText,
        [hashtable]$Window,
        [object]$State,
        [string]$LastAction = ""
    )

    $status = ConvertTo-Hashtable -InputObject (Read-Status)
    $status["phase"] = $Phase
    $status["statusText"] = $StatusText
    $status["nextStart"] = if ($Window.ContainsKey("Start")) { $Window.Start.ToString("o") } else { $null }
    $status["nextEnd"] = if ($Window.ContainsKey("End")) { $Window.End.ToString("o") } else { $null }
    $status["activeSchedule"] = if ($Window.ContainsKey("ScheduleName")) { $Window.ScheduleName } else { "" }
    $status["skipUntil"] = $State.skipUntil
    $status["agentRunning"] = $true
    $status["agentPid"] = $PID
    if ($LastAction) {
        $status["lastAction"] = $LastAction
    }
    Save-Status -Status $status
}

function Get-ActiveSkipUntil {
    $state = Read-State
    if ($null -eq $state.skipUntil -or [string]::IsNullOrWhiteSpace([string]$state.skipUntil)) {
        return $null
    }

    $skipUntil = [datetime]$state.skipUntil
    if ((Get-Date) -ge $skipUntil) {
        Clear-Skip
        return $null
    }

    $skipUntil
}

function Set-SkipForCurrentOrNextWindow {
    param([object]$Config)

    $window = Get-RelevantWindow -Config $Config -Now (Get-Date)
    $until = if ($window.InRestriction) { $window.End } else { $window.Start }
    Set-SkipUntil -Until $until
}

function Invoke-Enforcement {
    param(
        [object]$Config,
        [hashtable]$Window,
        [datetime]$Deadline,
        [bool]$FirstEntry
    )

    $mode = [string]$Config.enforcementMode

    if ($FirstEntry) {
        $modeText = switch ($mode) {
            "warn_only" { "Warning-only mode is active" }
            "lock_only" { "Lock-only mode is active" }
            "lock_logoff" { "The session will be signed out" }
            default { "The computer will be shut down" }
        }

        Show-Message `
            -Title $Config.messageTitle `
            -Text ("Restricted time is active until {0}. {1}." -f $Window.End.ToString("HH:mm"), $modeText)

        Write-Log -Message ("Restriction started for schedule '{0}' until {1}" -f $Window.ScheduleName, $Window.End.ToString("dd.MM HH:mm"))
    }

    if ($mode -ne "warn_only") {
        [SleepyNightNative]::LockWorkStation() | Out-Null
    }

    if ($mode -eq "lock_shutdown" -and (Get-Date) -ge $Deadline) {
        Write-Log -Message "Shutting down the computer"
        shutdown.exe /s /f /t 0
        return $true
    }

    if ($mode -eq "lock_logoff" -and (Get-Date) -ge $Deadline) {
        Write-Log -Message "Signing out from the current session"
        shutdown.exe /l /f
        return $true
    }

    $false
}

Initialize-SleepyNightFiles
Write-Log -Message "Background agent started"

$lastWindowId = ""
$sentWarnings = @{}
$restrictionShown = $false
$deadline = $null

try {
    while ($true) {
        $config = Read-Config
        $state = Read-State
        $window = Get-RelevantWindow -Config $config -Now (Get-Date)
        $skipUntil = Get-ActiveSkipUntil

        if (-not $config.enabled) {
            Update-AgentStatus `
                -Phase "disabled" `
                -StatusText "Protection is disabled" `
                -Window $window `
                -State $state `
                -LastAction "Protection disabled"
            Start-Sleep -Seconds ([Math]::Max([int]$config.statusRefreshSeconds, 5))
            continue
        }

        if ($window.WindowId -ne $lastWindowId) {
            $lastWindowId = $window.WindowId
            $sentWarnings = @{}
            $restrictionShown = $false
            $deadline = $null
        }

        if ($skipUntil) {
            $skipText = "Restriction is skipped until {0}" -f $skipUntil.ToString("dd.MM HH:mm")
            Update-AgentStatus `
                -Phase "skipped" `
                -StatusText $skipText `
                -Window $window `
                -State (Read-State) `
                -LastAction $skipText
            Start-Sleep -Seconds ([Math]::Max([int]$config.statusRefreshSeconds, 5))
            continue
        }

        $now = Get-Date
        if (-not $window.InRestriction) {
            $minutesUntilStart = [int][Math]::Ceiling(($window.Start - $now).TotalMinutes)
            foreach ($offset in (@($config.warningMinutes) | Sort-Object -Descending)) {
                if (-not $sentWarnings.ContainsKey($offset) -and $minutesUntilStart -le $offset -and $minutesUntilStart -gt 0) {
                    $warningText = "Restriction starts in about $minutesUntilStart minute(s). Window: $($window.Start.ToString('HH:mm'))-$($window.End.ToString('HH:mm'))."
                    Show-Message -Title $config.messageTitle -Text $warningText
                    Write-Log -Message ("Warning shown about {0} minute(s) before restriction" -f $minutesUntilStart)
                    $sentWarnings[$offset] = $true
                }
            }

            $statusText = "Allowed now. Next restriction: {0} {1}-{2}" -f $window.ScheduleName, $window.Start.ToString("HH:mm"), $window.End.ToString("HH:mm")
            Update-AgentStatus `
                -Phase "allowed" `
                -StatusText $statusText `
                -Window $window `
                -State $state `
                -LastAction "Waiting for the next window"

            Start-Sleep -Seconds ([Math]::Max([int]$config.statusRefreshSeconds, 5))
            continue
        }

        $firstEntry = $false
        if (-not $restrictionShown) {
            $firstEntry = $true
            $restrictionShown = $true
            $deadline = (Get-Date).AddMinutes([int]$config.graceMinutes)
        }

        $statusText = "Restricted until {0}. Mode: {1}" -f $window.End.ToString("HH:mm"), $config.enforcementMode
        Update-AgentStatus `
            -Phase "restricted" `
            -StatusText $statusText `
            -Window $window `
            -State $state `
            -LastAction "Restriction is active"

        $completed = Invoke-Enforcement `
            -Config $config `
            -Window $window `
            -Deadline $deadline `
            -FirstEntry:$firstEntry

        if ($completed) {
            break
        }

        Start-Sleep -Seconds ([Math]::Max([int]$config.lockCheckSeconds, 5))
    }
} finally {
    $finalStatus = ConvertTo-Hashtable -InputObject (Read-Status)
    $finalStatus["agentRunning"] = $false
    $finalStatus["agentPid"] = $null
    $finalStatus["lastAction"] = "Agent stopped"
    Save-Status -Status $finalStatus
    Write-Log -Message "Background agent stopped"
    $mutex.ReleaseMutex() | Out-Null
    $mutex.Dispose()
}
