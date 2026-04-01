. (Join-Path $PSScriptRoot "sleepy-night-core.ps1")

Initialize-SleepyNightFiles

$config = Read-Config
$state = ConvertTo-Hashtable -InputObject (Read-State)
$status = Read-Status
$now = Get-Date

if (-not $config.watchdogEnabled) {
    Update-WatchdogSnapshot -State "disabled" -Reason "Watchdog is disabled" -Now $now
    exit 0
}

if (-not $config.enabled) {
    Update-WatchdogSnapshot -State "idle" -Reason "Protection is disabled" -Now $now
    exit 0
}

$health = Get-AgentHealthStatus -Config $config -Status $status
if (-not $health.ShouldRestart) {
    Update-WatchdogSnapshot -State "healthy" -Reason "Agent is healthy" -Now $now
    exit 0
}

$cooldownSeconds = Get-WatchdogRepairCooldownSeconds -Config $config
$lastRepairAt = $null
if ($null -ne $state["lastWatchdogRepairAt"] -and -not [string]::IsNullOrWhiteSpace([string]$state["lastWatchdogRepairAt"])) {
    $lastRepairAt = [datetime]$state["lastWatchdogRepairAt"]
}

if ($null -ne $lastRepairAt) {
    $nextRepairAt = $lastRepairAt.AddSeconds($cooldownSeconds)
    if ($now -lt $nextRepairAt) {
        $remaining = [int][Math]::Ceiling(($nextRepairAt - $now).TotalSeconds)
        Update-WatchdogSnapshot -State "cooldown" -Reason ("Repair cooldown is active for {0} more second(s). Last issue: {1}" -f $remaining, $health.Reason) -Now $now
        exit 0
    }
}

if ($health.ProcessAlive -and -not $health.HeartbeatHealthy) {
    $stoppedCount = Stop-AgentProcess
    if ($stoppedCount -gt 0) {
        Write-Log -Message ("Watchdog stopped {0} stale agent process(es)" -f $stoppedCount) -Level "WARN"
        Start-Sleep -Seconds 2
    }
}

$started = Start-AgentProcess
if ($started) {
    $reason = "Watchdog restarted the background agent because {0}" -f $health.Reason.ToLowerInvariant()
    Write-Log -Message $reason -Level "WARN"
    Update-WatchdogSnapshot -State "restarted" -Reason $reason -Now $now -RepairAt $now
    exit 0
}

$finalHealth = Get-AgentHealthStatus -Config $config -Status (Read-Status)
if (-not $finalHealth.ShouldRestart) {
    Update-WatchdogSnapshot -State "healthy" -Reason "Agent is healthy" -Now $now
    exit 0
}

$failedReason = "Watchdog detected an unhealthy agent but could not restart it: {0}" -f $health.Reason
Write-Log -Message $failedReason -Level "ERROR"
Update-WatchdogSnapshot -State "warning" -Reason $failedReason -Now $now
exit 1
