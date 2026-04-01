param(
    [switch]$Install,
    [switch]$Ui,
    [switch]$Desktop,
    [switch]$Uninstall
)

if ($Install) {
    & (Join-Path $PSScriptRoot "install-sleepy-night-tasks.ps1")
    exit $LASTEXITCODE
}

if ($Uninstall) {
    & (Join-Path $PSScriptRoot "install-sleepy-night-tasks.ps1") -Uninstall
    exit $LASTEXITCODE
}

if ($Ui) {
    & (Join-Path $PSScriptRoot "sleepy-night-ui.ps1")
    exit $LASTEXITCODE
}

if ($Desktop) {
    $desktopExe = Join-Path $PSScriptRoot "dist\SleepyNight.Desktop\SleepyNight.Desktop.exe"
    if (-not (Test-Path $desktopExe)) {
        throw "Desktop exe not found. Build it first with .\build-desktop.ps1"
    }

    Start-Process -FilePath $desktopExe -WorkingDirectory $PSScriptRoot | Out-Null
    exit 0
}

& (Join-Path $PSScriptRoot "sleepy-night-agent.ps1")
