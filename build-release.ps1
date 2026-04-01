param(
    [string]$Version = "0.1.0",
    [string]$Configuration = "Release"
)

$releaseRoot = Join-Path $PSScriptRoot "release"
$packageName = "SleepyNight-v$Version"
$packageRoot = Join-Path $releaseRoot $packageName
$zipPath = Join-Path $releaseRoot ("$packageName.zip")
$distRoot = Join-Path $PSScriptRoot "dist\SleepyNight"
$imagesRoot = Join-Path $PSScriptRoot "Images"

& (Join-Path $PSScriptRoot "build-desktop.ps1") -Configuration $Configuration
if ($LASTEXITCODE -ne 0) {
    throw "Desktop build failed."
}

if (Test-Path $packageRoot) {
    Remove-Item -LiteralPath $packageRoot -Recurse -Force
}
if (Test-Path $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $packageRoot "dist\SleepyNight") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $packageRoot "Images") | Out-Null

Copy-Item -Path (Join-Path $distRoot '*') -Destination (Join-Path $packageRoot 'dist\SleepyNight') -Recurse -Force
Copy-Item -Path (Join-Path $imagesRoot 'sn_bg.png') -Destination (Join-Path $packageRoot 'Images') -Force
Copy-Item -Path (Join-Path $imagesRoot 'IconSleepyNight.ico') -Destination (Join-Path $packageRoot 'Images') -Force
Copy-Item -Path (Join-Path $imagesRoot 'IconSleepyNight.png') -Destination (Join-Path $packageRoot 'Images') -Force

$rootFiles = @(
    'README.md',
    'LICENSE',
    'CHANGELOG.md',
    'sleepy-night.ps1',
    'sleepy-night-ui.ps1',
    'sleepy-night-agent.ps1',
    'sleepy-night-watchdog.ps1',
    'sleepy-night-core.ps1',
    'sleepy-night-config.json',
    'install-sleepy-night-tasks.ps1',
    'SleepyNight.vbs',
    'SleepyNight UI.vbs',
    'SleepyNight Agent.vbs',
    'SleepyNight Watchdog.vbs'
)

foreach ($file in $rootFiles) {
    Copy-Item -Path (Join-Path $PSScriptRoot $file) -Destination $packageRoot -Force
}

Compress-Archive -Path (Join-Path $packageRoot '*') -DestinationPath $zipPath -Force

Write-Host "Release package created:"
Write-Host " - $packageRoot"
Write-Host " - $zipPath"
