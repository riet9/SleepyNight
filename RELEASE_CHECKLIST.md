# Release Checklist

## Before First Push

- confirm the GitHub repository is `public`
- confirm `MIT` is the intended license
- review `.gitignore`
- make sure `dist/`, `release/`, `bin/`, `obj/`, logs, and runtime state files are not staged
- check `README.md`, `ROADMAP.md`, and `CHANGELOG.md`

## Before Publishing A Release

- run `./build-release.ps1`
- launch `dist\SleepyNight\SleepyNight.exe`
- smoke-test the dashboard
- verify `Install autostart` and `Repair autostart`
- verify warnings, restriction window, and quick test mode
- verify tray icon, app icon, and desktop launcher behavior
- inspect `release\SleepyNight-v0.1.0\` before uploading

## Suggested Release Contents

- `release\SleepyNight-v0.1.0.zip`
- release notes for `v0.1.0`
- optional screenshots for the GitHub release page

## Suggested First GitHub Release Title

- `v0.1.0 - First public build`
