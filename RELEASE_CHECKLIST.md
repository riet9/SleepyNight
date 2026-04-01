# Release Checklist

## Before First Push

- confirm the GitHub repository is `public`
- confirm `MIT` is the intended license
- review `.gitignore`
- make sure `dist/`, `bin/`, `obj/`, logs, and runtime state files are not staged
- check `README.md` for final wording
- check `ROADMAP.md` and `CHANGELOG.md`

## Before Publishing A Release

- build the desktop app with `.\build-desktop.ps1`
- launch the built app and smoke-test the main UI
- verify `Install autostart` and `Repair autostart`
- verify warnings, restriction window, and quick test mode
- verify tray icon and app icon look correct
- bundle the release files you want to ship

## Suggested Release Contents

- `SleepyNight.Desktop.exe`
- required companion files from the published `dist\SleepyNight.Desktop` folder
- `README.md`
- a short release note summarizing what the app does

## Suggested First GitHub Release Title

- `v0.1.0 - First public build`
