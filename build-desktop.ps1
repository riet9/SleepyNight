param(
    [string]$Configuration = "Release"
)

$projectPath = Join-Path $PSScriptRoot "SleepyNight.Desktop\SleepyNight.Desktop.csproj"
$outputPath = Join-Path $PSScriptRoot "dist\SleepyNight"

if (-not (Test-Path $projectPath)) {
    throw "Desktop project not found: $projectPath"
}

$sdkList = & dotnet --list-sdks 2>$null
if (-not $sdkList) {
    throw "No .NET SDK was found. Install the .NET 8 SDK, then run this script again."
}

$env:DOTNET_CLI_HOME = Join-Path $PSScriptRoot ".dotnet-cli"
$env:APPDATA = Join-Path $PSScriptRoot ".appdata"
$env:LOCALAPPDATA = Join-Path $PSScriptRoot ".localappdata"
$env:USERPROFILE = Join-Path $PSScriptRoot ".userprofile"
$env:HOMEDRIVE = "D:"
$env:HOMEPATH = "\Programms\SleepyNight\.userprofile"
$env:NUGET_PACKAGES = Join-Path $PSScriptRoot ".nuget\packages"

New-Item -ItemType Directory -Force -Path `
    $env:DOTNET_CLI_HOME, `
    $env:APPDATA, `
    $env:LOCALAPPDATA, `
    $env:USERPROFILE, `
    $env:NUGET_PACKAGES, `
    (Join-Path $env:APPDATA "NuGet"), `
    (Join-Path $env:LOCALAPPDATA "Microsoft SDKs") | Out-Null

Copy-Item `
    -Path (Join-Path $PSScriptRoot "NuGet.Config") `
    -Destination (Join-Path $env:APPDATA "NuGet\NuGet.Config") `
    -Force

if (Test-Path $outputPath) {
    Remove-Item -LiteralPath $outputPath -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

dotnet publish $projectPath `
    -c $Configuration `
    -r win-x64 `
    --self-contained false `
    -o $outputPath `
    --configfile (Join-Path $PSScriptRoot "NuGet.Config")

if ($LASTEXITCODE -ne 0) {
    throw "Desktop build failed with exit code $LASTEXITCODE."
}

Write-Host "Desktop build published to:"
Write-Host " - $outputPath"
Write-Host "Main exe:"
Write-Host " - " (Join-Path $outputPath "SleepyNight.exe")
