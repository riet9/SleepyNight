. (Join-Path $PSScriptRoot "sleepy-night-core.ps1")

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

Initialize-SleepyNightFiles

$script:RoyalPalette = @{
    Ink = [System.Drawing.Color]::FromArgb(30, 28, 52)
    Midnight = [System.Drawing.Color]::FromArgb(20, 24, 54)
    Panel = [System.Drawing.Color]::FromArgb(245, 241, 231)
    PanelAlt = [System.Drawing.Color]::FromArgb(232, 223, 199)
    Gold = [System.Drawing.Color]::FromArgb(191, 155, 83)
    GoldSoft = [System.Drawing.Color]::FromArgb(214, 183, 120)
    Ivory = [System.Drawing.Color]::FromArgb(252, 249, 242)
    Line = [System.Drawing.Color]::FromArgb(207, 193, 162)
    Success = [System.Drawing.Color]::FromArgb(79, 122, 92)
    Danger = [System.Drawing.Color]::FromArgb(128, 48, 48)
    Muted = [System.Drawing.Color]::FromArgb(108, 97, 78)
    Info = [System.Drawing.Color]::FromArgb(75, 98, 140)
}

function New-TimePicker {
    param(
        [int]$X,
        [int]$Y,
        [string]$TimeValue
    )

    $picker = New-Object System.Windows.Forms.DateTimePicker
    $picker.Format = [System.Windows.Forms.DateTimePickerFormat]::Custom
    $picker.CustomFormat = "HH:mm"
    $picker.ShowUpDown = $true
    $picker.Width = 110
    $picker.Location = New-Object System.Drawing.Point($X, $Y)
    $picker.Value = [datetime]::Today.Add((ConvertTo-TimeSpanValue -TimeText $TimeValue))
    $picker
}

function Set-RoyalButtonStyle {
    param(
        [System.Windows.Forms.Button]$Button,
        [string]$Variant = "gold"
    )

    $Button.FlatStyle = "Flat"
    $Button.FlatAppearance.BorderSize = 1
    $Button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $Button.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9.5)

    if ($Variant -eq "dark") {
        $Button.BackColor = $script:RoyalPalette.Midnight
        $Button.ForeColor = $script:RoyalPalette.Ivory
        $Button.FlatAppearance.BorderColor = $script:RoyalPalette.Gold
        return
    }

    if ($Variant -eq "soft") {
        $Button.BackColor = $script:RoyalPalette.PanelAlt
        $Button.ForeColor = $script:RoyalPalette.Midnight
        $Button.FlatAppearance.BorderColor = $script:RoyalPalette.Line
        return
    }

    if ($Variant -eq "info") {
        $Button.BackColor = $script:RoyalPalette.Info
        $Button.ForeColor = $script:RoyalPalette.Ivory
        $Button.FlatAppearance.BorderColor = $script:RoyalPalette.GoldSoft
        return
    }

    $Button.BackColor = $script:RoyalPalette.Gold
    $Button.ForeColor = $script:RoyalPalette.Midnight
    $Button.FlatAppearance.BorderColor = $script:RoyalPalette.GoldSoft
}

function Set-RoyalInputStyle {
    param([System.Windows.Forms.Control]$Control)

    $Control.BackColor = [System.Drawing.Color]::White
    $Control.ForeColor = $script:RoyalPalette.Ink
    $Control.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
}

function Set-SectionLabelStyle {
    param([System.Windows.Forms.Label]$Label)

    $Label.ForeColor = $script:RoyalPalette.Muted
    $Label.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9.2)
}

function Get-TimePickerValue {
    param([System.Windows.Forms.DateTimePicker]$Picker)
    $Picker.Value.ToString("HH:mm")
}

function Get-SelectedModeValue {
    param([System.Windows.Forms.ComboBox]$Combo)

    if ($null -eq $Combo.SelectedItem) {
        return "lock_shutdown"
    }

    [string]$Combo.SelectedValue
}

function Get-ModeItems {
    @(
        [pscustomobject]@{ Name = "Warn only"; Value = "warn_only" }
        [pscustomobject]@{ Name = "Lock only"; Value = "lock_only" }
        [pscustomobject]@{ Name = "Lock and shut down"; Value = "lock_shutdown" }
        [pscustomobject]@{ Name = "Lock and sign out"; Value = "lock_logoff" }
    )
}

function Update-ControlsFromConfig {
    param(
        [object]$Config,
        [object]$Controls
    )

    $Controls.EnabledCheck.Checked = [bool]$Config.enabled
    $Controls.WeekendCheck.Checked = [bool]$Config.schedule.useWeekendSchedule
    $Controls.WeekdayStart.Value = [datetime]::Today.Add((ConvertTo-TimeSpanValue -TimeText $Config.schedule.weekdays.start))
    $Controls.WeekdayEnd.Value = [datetime]::Today.Add((ConvertTo-TimeSpanValue -TimeText $Config.schedule.weekdays.end))
    $Controls.WeekendStart.Value = [datetime]::Today.Add((ConvertTo-TimeSpanValue -TimeText $Config.schedule.weekends.start))
    $Controls.WeekendEnd.Value = [datetime]::Today.Add((ConvertTo-TimeSpanValue -TimeText $Config.schedule.weekends.end))
    $Controls.GraceBox.Value = [decimal][int]$Config.graceMinutes
    $Controls.LockBox.Value = [decimal][int]$Config.lockCheckSeconds
    $Controls.WarningBox.Text = (@($Config.warningMinutes) -join ", ")
    $Controls.LoggingCheck.Checked = [bool]$Config.loggingEnabled
    $Controls.EmergencyCodeBox.Text = [string]$Config.emergencyCode
    $Controls.TitleBox.Text = [string]$Config.messageTitle

    foreach ($item in $Controls.ModeBox.Items) {
        if ($item.Value -eq [string]$Config.enforcementMode) {
            $Controls.ModeBox.SelectedItem = $item
            break
        }
    }
}

function Build-ConfigFromControls {
    param([object]$Controls)

    $warnings = @()
    foreach ($item in ($Controls.WarningBox.Text -split ",")) {
        $trimmed = $item.Trim()
        if (-not $trimmed) {
            continue
        }

        if ($trimmed -notmatch '^\d+$') {
            throw "Warnings must be a comma-separated list of numbers."
        }

        $warnings += [int]$trimmed
    }

    if ($warnings.Count -eq 0) {
        $warnings = @(60, 30, 15, 10, 5, 1)
    }

    @{
        enabled = $Controls.EnabledCheck.Checked
        schedule = @{
            useWeekendSchedule = $Controls.WeekendCheck.Checked
            weekdays = @{
                start = Get-TimePickerValue -Picker $Controls.WeekdayStart
                end = Get-TimePickerValue -Picker $Controls.WeekdayEnd
            }
            weekends = @{
                start = Get-TimePickerValue -Picker $Controls.WeekendStart
                end = Get-TimePickerValue -Picker $Controls.WeekendEnd
            }
        }
        enforcementMode = [string]$Controls.ModeBox.SelectedItem.Value
        graceMinutes = [int]$Controls.GraceBox.Value
        lockCheckSeconds = [int]$Controls.LockBox.Value
        warningMinutes = @($warnings | Sort-Object -Descending)
        messageTitle = if ([string]::IsNullOrWhiteSpace($Controls.TitleBox.Text)) { "SleepyNight" } else { $Controls.TitleBox.Text.Trim() }
        loggingEnabled = $Controls.LoggingCheck.Checked
        statusRefreshSeconds = 5
        emergencyCode = $Controls.EmergencyCodeBox.Text
    }
}

function Invoke-InstallTasks {
    $installer = Join-Path $PSScriptRoot "install-sleepy-night-tasks.ps1"
    Start-Process -Verb RunAs -FilePath "powershell.exe" -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $installer
    ) | Out-Null
}

function Invoke-UninstallTasks {
    $installer = Join-Path $PSScriptRoot "install-sleepy-night-tasks.ps1"
    Start-Process -Verb RunAs -FilePath "powershell.exe" -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $installer,
        "-Uninstall"
    ) | Out-Null
}

function Get-UiStatusText {
    $status = Read-Status
    $state = Read-State
    $taskNames = Get-TaskNames
    $taskInstalled = Test-ScheduledTaskInstalled -TaskName $taskNames.Agent
    $skipText = Get-SkipText -State $state

    @{
        Agent = if ($status.agentRunning) { "Agent is running" } else { "Agent is not running" }
        Phase = [string]$status.statusText
        Task = if ($taskInstalled) { "Autostart is installed" } else { "Autostart is not installed" }
        Skip = if ($skipText) { $skipText } else { "No active skip" }
        Next = if ($status.nextStart) {
            $start = ([datetime]$status.nextStart).ToString("dd.MM HH:mm")
            $end = if ($status.nextEnd) { ([datetime]$status.nextEnd).ToString("dd.MM HH:mm") } else { "-" }
            "Next window: $start -> $end"
        } else {
            "Next window is not calculated yet"
        }
    }
}

function Invoke-UiSafe {
    param(
        [scriptblock]$Action,
        [string]$ErrorMessage = "Unexpected UI error."
    )

    try {
        & $Action
    } catch {
        Write-Log -Level "ERROR" -Message ("UI error: {0}" -f $_.Exception.Message)
        [System.Windows.Forms.MessageBox]::Show("$ErrorMessage`n`n$($_.Exception.Message)")
    }
}

function Confirm-EmergencyCode {
    param([object]$Config)

    if ([string]::IsNullOrWhiteSpace([string]$Config.emergencyCode)) {
        return $true
    }

    $entered = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Enter the emergency skip code",
        "SleepyNight",
        ""
    )

    if ($entered -ne [string]$Config.emergencyCode) {
        [System.Windows.Forms.MessageBox]::Show("Incorrect code.")
        return $false
    }

    $true
}

function Create-QuickTestWindow {
    $config = ConvertTo-Hashtable -InputObject (Read-Config)
    Save-QuickTestBackupConfig -Config $config
    $start = (Get-Date).AddMinutes(2)
    $end = (Get-Date).AddMinutes(20)

    $config.schedule.useWeekendSchedule = $false
    $config.schedule.weekdays.start = $start.ToString("HH:mm")
    $config.schedule.weekdays.end = $end.ToString("HH:mm")
    $config.enforcementMode = "lock_only"
    $config.graceMinutes = 1
    $config.warningMinutes = @(1)

    Save-ConfigWithPolicy -Config $config -IgnoreScheduleCooldown -Source "PowerShell UI quick test"
    Update-ControlsFromConfig -Config (Read-Config) -Controls $controls
    Write-Log -Message ("Quick test created: {0}-{1}" -f $config.schedule.weekdays.start, $config.schedule.weekdays.end)
    [System.Windows.Forms.MessageBox]::Show("Quick test created.`nStart: $($config.schedule.weekdays.start)`nEnd: $($config.schedule.weekdays.end)`nMode: lock_only")
    Refresh-UiStatus
}

function Stop-QuickTestWindow {
    $config = Get-QuickTestBackupConfig
    if ($null -eq $config) {
        $config = ConvertTo-Hashtable -InputObject (Get-DefaultConfig)
    }

    Save-ConfigWithPolicy -Config $config -IgnoreScheduleCooldown -Source "PowerShell UI quick test stop"
    Clear-QuickTestBackupConfig
    Update-ControlsFromConfig -Config (Read-Config) -Controls $controls
    Write-Log -Message "Quick test stopped and the previous schedule was restored"
    [System.Windows.Forms.MessageBox]::Show("Quick test stopped. Previous schedule restored.")
    Refresh-UiStatus
}

$config = Read-Config
$state = Read-State

$form = New-Object System.Windows.Forms.Form
$form.Text = "SleepyNight"
$form.Size = New-Object System.Drawing.Size(820, 930)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.BackColor = $script:RoyalPalette.Ivory

$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(15, 12)
$headerPanel.Size = New-Object System.Drawing.Size(770, 86)
$headerPanel.BackColor = $script:RoyalPalette.Midnight

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "SleepyNight"
$titleLabel.Location = New-Object System.Drawing.Point(20, 14)
$titleLabel.Size = New-Object System.Drawing.Size(280, 30)
$titleLabel.ForeColor = $script:RoyalPalette.Ivory
$titleLabel.Font = New-Object System.Drawing.Font("Georgia", 16, [System.Drawing.FontStyle]::Bold)

$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Text = "A calmer evening ritual with a little more authority."
$subtitleLabel.Location = New-Object System.Drawing.Point(22, 46)
$subtitleLabel.Size = New-Object System.Drawing.Size(420, 22)
$subtitleLabel.ForeColor = $script:RoyalPalette.GoldSoft
$subtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)

$crestLabel = New-Object System.Windows.Forms.Label
$crestLabel.Text = "NIGHT COURT MODE"
$crestLabel.Location = New-Object System.Drawing.Point(565, 18)
$crestLabel.Size = New-Object System.Drawing.Size(180, 22)
$crestLabel.ForeColor = $script:RoyalPalette.GoldSoft
$crestLabel.TextAlign = "MiddleRight"
$crestLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)

$headerRule = New-Object System.Windows.Forms.Panel
$headerRule.Location = New-Object System.Drawing.Point(520, 50)
$headerRule.Size = New-Object System.Drawing.Size(225, 2)
$headerRule.BackColor = $script:RoyalPalette.Gold

[void]$headerPanel.Controls.Add($titleLabel)
[void]$headerPanel.Controls.Add($subtitleLabel)
[void]$headerPanel.Controls.Add($crestLabel)
[void]$headerPanel.Controls.Add($headerRule)

$heroPanel = New-Object System.Windows.Forms.Panel
$heroPanel.Location = New-Object System.Drawing.Point(15, 108)
$heroPanel.Size = New-Object System.Drawing.Size(770, 122)
$heroPanel.BackColor = $script:RoyalPalette.PanelAlt

$heroBadge = New-Object System.Windows.Forms.Label
$heroBadge.Text = "ALLOWED NOW"
$heroBadge.Location = New-Object System.Drawing.Point(18, 18)
$heroBadge.Size = New-Object System.Drawing.Size(180, 30)
$heroBadge.TextAlign = "MiddleCenter"
$heroBadge.BackColor = $script:RoyalPalette.Success
$heroBadge.ForeColor = $script:RoyalPalette.Ivory
$heroBadge.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11)

$heroCountdownCaption = New-Object System.Windows.Forms.Label
$heroCountdownCaption.Text = "Countdown to next restriction"
$heroCountdownCaption.Location = New-Object System.Drawing.Point(18, 58)
$heroCountdownCaption.Size = New-Object System.Drawing.Size(240, 18)
$heroCountdownCaption.ForeColor = $script:RoyalPalette.Muted
$heroCountdownCaption.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)

$heroCountdownValue = New-Object System.Windows.Forms.Label
$heroCountdownValue.Text = "--:--"
$heroCountdownValue.Location = New-Object System.Drawing.Point(18, 74)
$heroCountdownValue.Size = New-Object System.Drawing.Size(260, 34)
$heroCountdownValue.ForeColor = $script:RoyalPalette.Midnight
$heroCountdownValue.Font = New-Object System.Drawing.Font("Georgia", 18, [System.Drawing.FontStyle]::Bold)

$heroWindowCaption = New-Object System.Windows.Forms.Label
$heroWindowCaption.Text = "Upcoming window"
$heroWindowCaption.Location = New-Object System.Drawing.Point(330, 18)
$heroWindowCaption.Size = New-Object System.Drawing.Size(140, 18)
$heroWindowCaption.ForeColor = $script:RoyalPalette.Muted
$heroWindowCaption.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)

$heroWindowValue = New-Object System.Windows.Forms.Label
$heroWindowValue.Text = "Weekday 20:30 -> 03:00"
$heroWindowValue.Location = New-Object System.Drawing.Point(330, 36)
$heroWindowValue.Size = New-Object System.Drawing.Size(390, 28)
$heroWindowValue.ForeColor = $script:RoyalPalette.Ink
$heroWindowValue.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11)

$heroNote = New-Object System.Windows.Forms.Label
$heroNote.Text = "The crown stays calm until the evening threshold arrives."
$heroNote.Location = New-Object System.Drawing.Point(330, 66)
$heroNote.Size = New-Object System.Drawing.Size(400, 40)
$heroNote.ForeColor = $script:RoyalPalette.Ink
$heroNote.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)

$heroDivider = New-Object System.Windows.Forms.Panel
$heroDivider.Location = New-Object System.Drawing.Point(295, 16)
$heroDivider.Size = New-Object System.Drawing.Size(1, 90)
$heroDivider.BackColor = $script:RoyalPalette.Line

[void]$heroPanel.Controls.Add($heroBadge)
[void]$heroPanel.Controls.Add($heroCountdownCaption)
[void]$heroPanel.Controls.Add($heroCountdownValue)
[void]$heroPanel.Controls.Add($heroDivider)
[void]$heroPanel.Controls.Add($heroWindowCaption)
[void]$heroPanel.Controls.Add($heroWindowValue)
[void]$heroPanel.Controls.Add($heroNote)

$statusGroup = New-Object System.Windows.Forms.GroupBox
$statusGroup.Text = "Status"
$statusGroup.Location = New-Object System.Drawing.Point(15, 244)
$statusGroup.Size = New-Object System.Drawing.Size(770, 155)
$statusGroup.BackColor = $script:RoyalPalette.Panel
$statusGroup.ForeColor = $script:RoyalPalette.Ink
$statusGroup.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10)

$agentLabel = New-Object System.Windows.Forms.Label
$agentLabel.Location = New-Object System.Drawing.Point(20, 30)
$agentLabel.Size = New-Object System.Drawing.Size(650, 24)
$agentLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$phaseLabel = New-Object System.Windows.Forms.Label
$phaseLabel.Location = New-Object System.Drawing.Point(20, 58)
$phaseLabel.Size = New-Object System.Drawing.Size(720, 36)
$phaseLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$taskLabel = New-Object System.Windows.Forms.Label
$taskLabel.Location = New-Object System.Drawing.Point(20, 94)
$taskLabel.Size = New-Object System.Drawing.Size(340, 24)

$skipLabel = New-Object System.Windows.Forms.Label
$skipLabel.Location = New-Object System.Drawing.Point(390, 94)
$skipLabel.Size = New-Object System.Drawing.Size(340, 24)

$nextLabel = New-Object System.Windows.Forms.Label
$nextLabel.Location = New-Object System.Drawing.Point(20, 118)
$nextLabel.Size = New-Object System.Drawing.Size(720, 20)

foreach ($control in @($agentLabel, $phaseLabel, $taskLabel, $skipLabel, $nextLabel)) {
    [void]$statusGroup.Controls.Add($control)
}

$scheduleGroup = New-Object System.Windows.Forms.GroupBox
$scheduleGroup.Text = "Schedule"
$scheduleGroup.Location = New-Object System.Drawing.Point(15, 412)
$scheduleGroup.Size = New-Object System.Drawing.Size(770, 170)
$scheduleGroup.BackColor = $script:RoyalPalette.Panel
$scheduleGroup.ForeColor = $script:RoyalPalette.Ink
$scheduleGroup.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10)

$enabledCheck = New-Object System.Windows.Forms.CheckBox
$enabledCheck.Text = "Protection enabled"
$enabledCheck.Location = New-Object System.Drawing.Point(20, 30)
$enabledCheck.AutoSize = $true

$weekendCheck = New-Object System.Windows.Forms.CheckBox
$weekendCheck.Text = "Use a separate weekend schedule"
$weekendCheck.Location = New-Object System.Drawing.Point(290, 30)
$weekendCheck.AutoSize = $true

$weekdayStartLabel = New-Object System.Windows.Forms.Label
$weekdayStartLabel.Text = "Weekdays: start"
$weekdayStartLabel.Location = New-Object System.Drawing.Point(20, 65)
$weekdayStartLabel.AutoSize = $true

$weekdayStart = New-TimePicker -X 140 -Y 60 -TimeValue $config.schedule.weekdays.start

$weekdayEndLabel = New-Object System.Windows.Forms.Label
$weekdayEndLabel.Text = "end"
$weekdayEndLabel.Location = New-Object System.Drawing.Point(270, 65)
$weekdayEndLabel.AutoSize = $true

$weekdayEnd = New-TimePicker -X 330 -Y 60 -TimeValue $config.schedule.weekdays.end

$weekendStartLabel = New-Object System.Windows.Forms.Label
$weekendStartLabel.Text = "Weekends: start"
$weekendStartLabel.Location = New-Object System.Drawing.Point(20, 100)
$weekendStartLabel.AutoSize = $true

$weekendStart = New-TimePicker -X 170 -Y 95 -TimeValue $config.schedule.weekends.start

$weekendEndLabel = New-Object System.Windows.Forms.Label
$weekendEndLabel.Text = "end"
$weekendEndLabel.Location = New-Object System.Drawing.Point(300, 100)
$weekendEndLabel.AutoSize = $true

$weekendEnd = New-TimePicker -X 360 -Y 95 -TimeValue $config.schedule.weekends.end

$warningLabel = New-Object System.Windows.Forms.Label
$warningLabel.Text = "Warnings (min)"
$warningLabel.Location = New-Object System.Drawing.Point(20, 135)
$warningLabel.AutoSize = $true

$warningBox = New-Object System.Windows.Forms.TextBox
$warningBox.Location = New-Object System.Drawing.Point(190, 131)
$warningBox.Size = New-Object System.Drawing.Size(300, 24)
$warningBox.Text = (@($config.warningMinutes) -join ", ")

foreach ($control in @(
    $enabledCheck, $weekendCheck,
    $weekdayStartLabel, $weekdayStart, $weekdayEndLabel, $weekdayEnd,
    $weekendStartLabel, $weekendStart, $weekendEndLabel, $weekendEnd,
    $warningLabel, $warningBox
)) {
    [void]$scheduleGroup.Controls.Add($control)
}

$behaviorGroup = New-Object System.Windows.Forms.GroupBox
$behaviorGroup.Text = "Behavior"
$behaviorGroup.Location = New-Object System.Drawing.Point(15, 596)
$behaviorGroup.Size = New-Object System.Drawing.Size(770, 155)
$behaviorGroup.BackColor = $script:RoyalPalette.Panel
$behaviorGroup.ForeColor = $script:RoyalPalette.Ink
$behaviorGroup.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10)

$modeLabel = New-Object System.Windows.Forms.Label
$modeLabel.Text = "Mode"
$modeLabel.Location = New-Object System.Drawing.Point(20, 35)
$modeLabel.AutoSize = $true

$modeBox = New-Object System.Windows.Forms.ComboBox
$modeBox.Location = New-Object System.Drawing.Point(120, 30)
$modeBox.Size = New-Object System.Drawing.Size(290, 25)
$modeBox.DropDownStyle = "DropDownList"
$modeBox.DisplayMember = "Name"
$modeBox.ValueMember = "Value"
foreach ($item in (Get-ModeItems)) {
    [void]$modeBox.Items.Add($item)
}

$graceLabel = New-Object System.Windows.Forms.Label
$graceLabel.Text = "Delay before action (min)"
$graceLabel.Location = New-Object System.Drawing.Point(20, 70)
$graceLabel.AutoSize = $true

$graceBox = New-Object System.Windows.Forms.NumericUpDown
$graceBox.Location = New-Object System.Drawing.Point(240, 66)
$graceBox.Minimum = 0
$graceBox.Maximum = 120
$graceBox.Size = New-Object System.Drawing.Size(100, 24)

$lockLabel = New-Object System.Windows.Forms.Label
$lockLabel.Text = "Check interval (sec)"
$lockLabel.Location = New-Object System.Drawing.Point(20, 105)
$lockLabel.AutoSize = $true

$lockBox = New-Object System.Windows.Forms.NumericUpDown
$lockBox.Location = New-Object System.Drawing.Point(240, 101)
$lockBox.Minimum = 5
$lockBox.Maximum = 300
$lockBox.Size = New-Object System.Drawing.Size(100, 24)

$loggingCheck = New-Object System.Windows.Forms.CheckBox
$loggingCheck.Text = "Write log"
$loggingCheck.Location = New-Object System.Drawing.Point(455, 32)
$loggingCheck.AutoSize = $true

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Notification title"
$titleLabel.Location = New-Object System.Drawing.Point(455, 62)
$titleLabel.AutoSize = $true

$titleBox = New-Object System.Windows.Forms.TextBox
$titleBox.Location = New-Object System.Drawing.Point(455, 82)
$titleBox.Size = New-Object System.Drawing.Size(250, 24)

$emergencyLabel = New-Object System.Windows.Forms.Label
$emergencyLabel.Text = "Emergency skip code"
$emergencyLabel.Location = New-Object System.Drawing.Point(455, 108)
$emergencyLabel.AutoSize = $true

$emergencyCodeBox = New-Object System.Windows.Forms.TextBox
$emergencyCodeBox.Location = New-Object System.Drawing.Point(455, 128)
$emergencyCodeBox.Size = New-Object System.Drawing.Size(250, 24)
$emergencyCodeBox.UseSystemPasswordChar = $true

foreach ($control in @(
    $modeLabel, $modeBox,
    $graceLabel, $graceBox,
    $lockLabel, $lockBox,
    $loggingCheck, $titleLabel, $titleBox, $emergencyLabel, $emergencyCodeBox
)) {
    [void]$behaviorGroup.Controls.Add($control)
}

$actionsGroup = New-Object System.Windows.Forms.GroupBox
$actionsGroup.Text = "Actions"
$actionsGroup.Location = New-Object System.Drawing.Point(15, 764)
$actionsGroup.Size = New-Object System.Drawing.Size(770, 75)
$actionsGroup.BackColor = $script:RoyalPalette.Panel
$actionsGroup.ForeColor = $script:RoyalPalette.Ink
$actionsGroup.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10)

$saveButton = New-Object System.Windows.Forms.Button
$saveButton.Text = "Save"
$saveButton.Location = New-Object System.Drawing.Point(15, 28)
$saveButton.Size = New-Object System.Drawing.Size(100, 30)

$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = "Start agent"
$startButton.Location = New-Object System.Drawing.Point(125, 28)
$startButton.Size = New-Object System.Drawing.Size(120, 30)

$stopButton = New-Object System.Windows.Forms.Button
$stopButton.Text = "Stop agent"
$stopButton.Location = New-Object System.Drawing.Point(255, 28)
$stopButton.Size = New-Object System.Drawing.Size(130, 30)

$installButton = New-Object System.Windows.Forms.Button
$installButton.Text = "Install autostart"
$installButton.Location = New-Object System.Drawing.Point(395, 28)
$installButton.Size = New-Object System.Drawing.Size(155, 30)

$removeButton = New-Object System.Windows.Forms.Button
$removeButton.Text = "Remove autostart"
$removeButton.Location = New-Object System.Drawing.Point(560, 28)
$removeButton.Size = New-Object System.Drawing.Size(165, 30)

foreach ($control in @($saveButton, $startButton, $stopButton, $installButton, $removeButton)) {
    [void]$actionsGroup.Controls.Add($control)
}

$secondaryButtons = @(
    @{ Text = "Skip tonight"; X = 15; Width = 130 }
    @{ Text = "Clear skip"; X = 155; Width = 120 }
    @{ Text = "Open log"; X = 285; Width = 100 }
    @{ Text = "Refresh"; X = 395; Width = 90 }
    @{ Text = "Test in 2 min"; X = 495; Width = 110 }
    @{ Text = "To tray"; X = 610; Width = 80 }
    @{ Text = "Exit"; X = 15; Width = 110 }
)

$extraPanel = New-Object System.Windows.Forms.Panel
$extraPanel.Location = New-Object System.Drawing.Point(15, 846)
$extraPanel.Size = New-Object System.Drawing.Size(770, 80)
$extraPanel.BackColor = $script:RoyalPalette.Ivory

$skipButton = New-Object System.Windows.Forms.Button
$skipButton.Text = $secondaryButtons[0].Text
$skipButton.Location = New-Object System.Drawing.Point($secondaryButtons[0].X, 5)
$skipButton.Size = New-Object System.Drawing.Size($secondaryButtons[0].Width, 30)

$clearSkipButton = New-Object System.Windows.Forms.Button
$clearSkipButton.Text = $secondaryButtons[1].Text
$clearSkipButton.Location = New-Object System.Drawing.Point($secondaryButtons[1].X, 5)
$clearSkipButton.Size = New-Object System.Drawing.Size($secondaryButtons[1].Width, 30)

$openLogButton = New-Object System.Windows.Forms.Button
$openLogButton.Text = $secondaryButtons[2].Text
$openLogButton.Location = New-Object System.Drawing.Point($secondaryButtons[2].X, 5)
$openLogButton.Size = New-Object System.Drawing.Size($secondaryButtons[2].Width, 30)

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = $secondaryButtons[3].Text
$refreshButton.Location = New-Object System.Drawing.Point($secondaryButtons[3].X, 5)
$refreshButton.Size = New-Object System.Drawing.Size($secondaryButtons[3].Width, 30)

$trayButton = New-Object System.Windows.Forms.Button
$testButton = New-Object System.Windows.Forms.Button
$testButton.Text = $secondaryButtons[4].Text
$testButton.Location = New-Object System.Drawing.Point($secondaryButtons[4].X, 5)
$testButton.Size = New-Object System.Drawing.Size($secondaryButtons[4].Width, 30)

$stopTestButton = New-Object System.Windows.Forms.Button
$stopTestButton.Text = "Stop test"
$stopTestButton.Location = New-Object System.Drawing.Point(15, 42)
$stopTestButton.Size = New-Object System.Drawing.Size(110, 30)

$trayButton = New-Object System.Windows.Forms.Button
$trayButton.Text = $secondaryButtons[5].Text
$trayButton.Location = New-Object System.Drawing.Point($secondaryButtons[5].X, 5)
$trayButton.Size = New-Object System.Drawing.Size($secondaryButtons[5].Width, 30)

$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Text = $secondaryButtons[6].Text
$exitButton.Location = New-Object System.Drawing.Point(690, 5)
$exitButton.Size = New-Object System.Drawing.Size(80, 30)

foreach ($control in @($skipButton, $clearSkipButton, $openLogButton, $refreshButton, $testButton, $stopTestButton, $trayButton, $exitButton)) {
    [void]$extraPanel.Controls.Add($control)
}

foreach ($control in @($headerPanel, $heroPanel, $statusGroup, $scheduleGroup, $behaviorGroup, $actionsGroup, $extraPanel)) {
    [void]$form.Controls.Add($control)
}

foreach ($button in @($saveButton, $startButton, $stopButton, $installButton, $removeButton, $skipButton, $clearSkipButton, $openLogButton, $refreshButton, $testButton)) {
    Set-RoyalButtonStyle -Button $button -Variant "gold"
}

foreach ($button in @($trayButton, $exitButton)) {
    Set-RoyalButtonStyle -Button $button -Variant "dark"
}

Set-RoyalButtonStyle -Button $startButton -Variant "info"
Set-RoyalButtonStyle -Button $stopButton -Variant "danger"
Set-RoyalButtonStyle -Button $installButton -Variant "soft"
Set-RoyalButtonStyle -Button $removeButton -Variant "soft"
Set-RoyalButtonStyle -Button $skipButton -Variant "soft"
Set-RoyalButtonStyle -Button $clearSkipButton -Variant "soft"
Set-RoyalButtonStyle -Button $openLogButton -Variant "soft"
Set-RoyalButtonStyle -Button $refreshButton -Variant "soft"
Set-RoyalButtonStyle -Button $testButton -Variant "info"
Set-RoyalButtonStyle -Button $stopTestButton -Variant "danger"

foreach ($input in @($weekdayStart, $weekdayEnd, $weekendStart, $weekendEnd, $warningBox, $modeBox, $graceBox, $lockBox, $titleBox, $emergencyCodeBox)) {
    Set-RoyalInputStyle -Control $input
}

foreach ($check in @($enabledCheck, $weekendCheck, $loggingCheck)) {
    $check.ForeColor = $script:RoyalPalette.Ink
    $check.BackColor = $script:RoyalPalette.Panel
    $check.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9.5)
}

foreach ($label in @(
    $weekdayStartLabel, $weekdayEndLabel,
    $weekendStartLabel, $weekendEndLabel,
    $warningLabel, $modeLabel, $graceLabel, $lockLabel, $titleLabel, $emergencyLabel
)) {
    Set-SectionLabelStyle -Label $label
}

$agentLabel.ForeColor = $script:RoyalPalette.Midnight
$phaseLabel.ForeColor = $script:RoyalPalette.Ink
$taskLabel.ForeColor = $script:RoyalPalette.Success
$skipLabel.ForeColor = $script:RoyalPalette.Ink
$nextLabel.ForeColor = $script:RoyalPalette.Ink
$phaseLabel.MaximumSize = New-Object System.Drawing.Size(720, 0)

$controls = [pscustomobject]@{
    EnabledCheck = $enabledCheck
    WeekendCheck = $weekendCheck
    WeekdayStart = $weekdayStart
    WeekdayEnd = $weekdayEnd
    WeekendStart = $weekendStart
    WeekendEnd = $weekendEnd
    ModeBox = $modeBox
    GraceBox = $graceBox
    LockBox = $lockBox
    WarningBox = $warningBox
    LoggingCheck = $loggingCheck
    TitleBox = $titleBox
    EmergencyCodeBox = $emergencyCodeBox
}

Update-ControlsFromConfig -Config $config -Controls $controls

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
$notifyIcon.Visible = $true
$notifyIcon.Text = "SleepyNight"

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$menuShow = $contextMenu.Items.Add("Open")
$menuSkip = $contextMenu.Items.Add("Skip tonight")
$menuClearSkip = $contextMenu.Items.Add("Clear skip")
$menuStart = $contextMenu.Items.Add("Start agent")
$menuStop = $contextMenu.Items.Add("Stop agent")
$null = $contextMenu.Items.Add("-")
$menuExit = $contextMenu.Items.Add("Exit")
$notifyIcon.ContextMenuStrip = $contextMenu

$script:AllowExit = $false

function Refresh-UiStatus {
    try {
        $statusData = Get-UiStatusText
        $status = Read-Status
        $agentLabel.Text = $statusData.Agent
        $phaseLabel.Text = $statusData.Phase
        $taskLabel.Text = $statusData.Task
        $skipLabel.Text = $statusData.Skip
        $nextLabel.Text = $statusData.Next

        $phase = [string]$status.phase
        switch ($phase) {
            "restricted" {
                $heroBadge.Text = "RESTRICTED"
                $heroBadge.BackColor = $script:RoyalPalette.Danger
                $heroNote.Text = "The restricted window is active. The crown is enforcing the rule."
            }
            "skipped" {
                $heroBadge.Text = "SKIPPED"
                $heroBadge.BackColor = $script:RoyalPalette.Gold
                $heroBadge.ForeColor = $script:RoyalPalette.Midnight
                $heroNote.Text = "Tonight is temporarily relaxed, but the watch is still awake."
            }
            "disabled" {
                $heroBadge.Text = "DISABLED"
                $heroBadge.BackColor = $script:RoyalPalette.Muted
                $heroBadge.ForeColor = $script:RoyalPalette.Ivory
                $heroNote.Text = "Protection is currently off."
            }
            default {
                $heroBadge.Text = "ALLOWED NOW"
                $heroBadge.BackColor = $script:RoyalPalette.Success
                $heroBadge.ForeColor = $script:RoyalPalette.Ivory
                $heroNote.Text = "The crown stays calm until the evening threshold arrives."
            }
        }

        if ($status.nextStart) {
            $startDt = [datetime]$status.nextStart
            $endDt = if ($status.nextEnd) { [datetime]$status.nextEnd } else { $startDt }
            $remaining = $startDt - (Get-Date)

            if ($phase -eq "restricted") {
                $remaining = $endDt - (Get-Date)
                $heroCountdownCaption.Text = "Time until restriction ends"
            } else {
                $heroCountdownCaption.Text = "Countdown to next restriction"
            }

            if ($remaining.TotalSeconds -lt 0) {
                $heroCountdownValue.Text = "00:00"
            } elseif ($remaining.TotalHours -ge 1) {
                $heroCountdownValue.Text = "{0:00}:{1:00}:{2:00}" -f [int]$remaining.TotalHours, $remaining.Minutes, $remaining.Seconds
            } else {
                $heroCountdownValue.Text = "{0:00}:{1:00}" -f $remaining.Minutes, $remaining.Seconds
            }

            $heroWindowValue.Text = "{0}  {1} -> {2}" -f $status.activeSchedule, $startDt.ToString("dd.MM HH:mm"), $endDt.ToString("dd.MM HH:mm")
        } else {
            $heroCountdownCaption.Text = "Countdown to next restriction"
            $heroCountdownValue.Text = "--:--"
            $heroWindowValue.Text = "Window data is not available yet"
        }

        $trayText = $statusData.Phase
        if ([string]::IsNullOrWhiteSpace($trayText)) {
            $trayText = "SleepyNight"
        }
        if ($trayText.Length -gt 60) {
            $trayText = $trayText.Substring(0, 60)
        }
        $notifyIcon.Text = $trayText
    } catch {
        Write-Log -Level "ERROR" -Message ("Refresh-UiStatus failed: {0}" -f $_.Exception.Message)
    }
}

function Hide-ToTray {
    $form.Hide()
    $notifyIcon.ShowBalloonTip(2500, "SleepyNight", "The app was minimized to the tray.", [System.Windows.Forms.ToolTipIcon]::Info)
}

$menuShow.Add_Click({
    $form.Show()
    $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    $form.Activate()
})

$menuSkip.Add_Click({
    $currentConfig = Read-Config
    if (Confirm-EmergencyCode -Config $currentConfig) {
        $window = Get-RelevantWindow -Config $currentConfig -Now (Get-Date)
        $target = if ($window.InRestriction) { $window.End } else { $window.End }
        Set-SkipUntil -Until $target
        Refresh-UiStatus
    }
})

$menuClearSkip.Add_Click({
    Clear-Skip
    Refresh-UiStatus
})

$menuStart.Add_Click({
    Invoke-UiSafe -ErrorMessage "Could not start the agent." -Action {
        if (Start-AgentProcess) {
            [System.Windows.Forms.MessageBox]::Show("Agent started.")
        } else {
            [System.Windows.Forms.MessageBox]::Show("Agent is already running.")
        }
        Refresh-UiStatus
    }
})

$menuStop.Add_Click({
    Invoke-UiSafe -ErrorMessage "Could not stop the agent." -Action {
        $count = Stop-AgentProcess
        [System.Windows.Forms.MessageBox]::Show("Stopped processes: $count")
        Refresh-UiStatus
    }
})

$menuExit.Add_Click({
    $script:AllowExit = $true
    $notifyIcon.Visible = $false
    $form.Close()
})

$notifyIcon.Add_DoubleClick({
    $form.Show()
    $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    $form.Activate()
})

$saveButton.Add_Click({
    Invoke-UiSafe -ErrorMessage "Could not save the settings." -Action {
        $currentConfig = ConvertTo-Hashtable -InputObject (Read-Config)
        $newConfig = Build-ConfigFromControls -Controls $controls
        $mergedConfig = Merge-ConfigData -Defaults $currentConfig -Overrides $newConfig
        Save-ConfigWithPolicy -Config $mergedConfig -Source "PowerShell UI"
        Write-Log -Message "Settings were saved from the UI"
        [System.Windows.Forms.MessageBox]::Show("Settings saved.")
        Refresh-UiStatus
    }
})

$startButton.Add_Click({
    Invoke-UiSafe -ErrorMessage "Could not start the agent." -Action {
        if (Start-AgentProcess) {
            Write-Log -Message "Agent started from the UI"
            [System.Windows.Forms.MessageBox]::Show("Agent started.")
        } else {
            [System.Windows.Forms.MessageBox]::Show("Agent is already running.")
        }
        Refresh-UiStatus
    }
})

$stopButton.Add_Click({
    Invoke-UiSafe -ErrorMessage "Could not stop the agent." -Action {
        $count = Stop-AgentProcess
        Write-Log -Message ("Agent stopped from the UI, processes: {0}" -f $count)
        [System.Windows.Forms.MessageBox]::Show("Stopped processes: $count")
        Refresh-UiStatus
    }
})

$installButton.Add_Click({
    Invoke-UiSafe -ErrorMessage "Could not install autostart." -Action {
        Invoke-InstallTasks
        Refresh-UiStatus
    }
})

$removeButton.Add_Click({
    Invoke-UiSafe -ErrorMessage "Could not remove autostart." -Action {
        Invoke-UninstallTasks
        Refresh-UiStatus
    }
})

$skipButton.Add_Click({
    Invoke-UiSafe -ErrorMessage "Could not enable skip." -Action {
        $currentConfig = Read-Config
        if (Confirm-EmergencyCode -Config $currentConfig) {
            $window = Get-RelevantWindow -Config $currentConfig -Now (Get-Date)
            $target = if ($window.InRestriction) { $window.End } else { $window.End }
            Set-SkipUntil -Until $target
            [System.Windows.Forms.MessageBox]::Show("Skip is active until $($target.ToString('dd.MM HH:mm')).")
            Refresh-UiStatus
        }
    }
})

$clearSkipButton.Add_Click({
    Invoke-UiSafe -ErrorMessage "Could not clear the skip." -Action {
        Clear-Skip
        [System.Windows.Forms.MessageBox]::Show("Skip cleared.")
        Refresh-UiStatus
    }
})

$openLogButton.Add_Click({
    Invoke-UiSafe -ErrorMessage "Could not open the log." -Action {
        Start-Process -FilePath "notepad.exe" -ArgumentList (Get-LogPath) | Out-Null
    }
})

$refreshButton.Add_Click({
    Invoke-UiSafe -ErrorMessage "Could not refresh the status." -Action {
        Refresh-UiStatus
    }
})

$testButton.Add_Click({
    Invoke-UiSafe -ErrorMessage "Could not create a quick test." -Action {
        Create-QuickTestWindow
    }
})

$stopTestButton.Add_Click({
    Invoke-UiSafe -ErrorMessage "Could not stop the quick test." -Action {
        Stop-QuickTestWindow
    }
})

$trayButton.Add_Click({
    Invoke-UiSafe -ErrorMessage "Could not minimize to tray." -Action {
        Hide-ToTray
    }
})

$exitButton.Add_Click({
    $script:AllowExit = $true
    $notifyIcon.Visible = $false
    $form.Close()
})

$form.Add_Resize({
    if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) {
        Hide-ToTray
    }
})

$form.Add_FormClosing({
    param($sender, $args)
    if (-not $script:AllowExit) {
        $args.Cancel = $true
        Hide-ToTray
    }
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5000
$timer.Add_Tick({
    try {
        Refresh-UiStatus
    } catch {
        Write-Log -Level "ERROR" -Message ("Timer refresh failed: {0}" -f $_.Exception.Message)
    }
})
$timer.Start()

Refresh-UiStatus
[void]$form.ShowDialog()
