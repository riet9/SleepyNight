param(
    [string]$TaskPrefix = "SleepyNight",
    [switch]$Uninstall
)

. (Join-Path $PSScriptRoot "sleepy-night-core.ps1")

$scriptPath = Join-Path $PSScriptRoot "sleepy-night-agent.ps1"
if (-not (Test-Path $scriptPath)) {
    throw "Main script not found: $scriptPath"
}
$watchdogScriptPath = Join-Path $PSScriptRoot "sleepy-night-watchdog.ps1"
if (-not (Test-Path $watchdogScriptPath)) {
    throw "Watchdog script not found: $watchdogScriptPath"
}
$agentLauncherPath = Join-Path $PSScriptRoot "SleepyNight Agent.vbs"
if (-not (Test-Path $agentLauncherPath)) {
    throw "Agent launcher not found: $agentLauncherPath"
}
$watchdogLauncherPath = Join-Path $PSScriptRoot "SleepyNight Watchdog.vbs"
if (-not (Test-Path $watchdogLauncherPath)) {
    throw "Watchdog launcher not found: $watchdogLauncherPath"
}

$taskNames = Get-TaskNames -TaskPrefix $TaskPrefix

if ($Uninstall) {
    Unregister-ScheduledTask -TaskName $taskNames.Agent -Confirm:$false -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskNames.Watchdog -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Removed tasks:"
    Write-Host " - $($taskNames.Agent)"
    Write-Host " - $($taskNames.Watchdog)"
    exit 0
}

$agentAction = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$agentLauncherPath`""
$watchdogAction = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$watchdogLauncherPath`""

$logonTrigger = New-ScheduledTaskTrigger -AtLogOn
$morningTrigger = New-ScheduledTaskTrigger -Daily -At "03:05"
$dayTrigger = New-ScheduledTaskTrigger -Daily -At "12:00"
$eveningTrigger = New-ScheduledTaskTrigger -Daily -At "20:20"
$watchdogTriggers = @(Get-WatchdogTimes | ForEach-Object { New-ScheduledTaskTrigger -Daily -At $_ })

$currentUser = if ($env:USERDOMAIN) { "$($env:USERDOMAIN)\$($env:USERNAME)" } else { $env:USERNAME }
$principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask `
    -TaskName $taskNames.Agent `
    -Action $agentAction `
    -Trigger @($logonTrigger, $morningTrigger, $dayTrigger, $eveningTrigger) `
    -Principal $principal `
    -Settings $settings `
    -Description "SleepyNight background agent." `
    -Force | Out-Null

Register-ScheduledTask `
    -TaskName $taskNames.Watchdog `
    -Action $watchdogAction `
    -Trigger $watchdogTriggers `
    -Principal $principal `
    -Settings $settings `
    -Description "SleepyNight watchdog restart task." `
    -Force | Out-Null

Write-Host "Installed tasks:"
Write-Host " - $($taskNames.Agent)"
Write-Host " - $($taskNames.Watchdog)"
