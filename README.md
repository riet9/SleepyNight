# SleepyNight

SleepyNight is a Windows bedtime-enforcement app with a native desktop dashboard, a background agent, and watchdog-based recovery.

The goal is simple: when bedtime starts, the computer should stop being an easy place to keep using.

## Features

- nightly restriction windows
- separate weekday and weekend schedules
- warning pipeline before restriction starts
- `warn only`, `lock only`, `lock + shut down`, and `lock + sign out` modes
- desktop dashboard with live status, quick test mode, and tray support
- skip cooldown and schedule-change cooldown rules
- autostart install, remove, and repair flows
- watchdog-based recovery
- shared config, state, and log system between PowerShell and desktop UI

Default schedule:

- weekdays: `20:30 -> 03:00`
- weekends: `22:30 -> 04:00`

## Tech Stack

- PowerShell for the agent, watchdog, config/state handling, and Task Scheduler integration
- C# / WinForms for the desktop dashboard
- Windows Task Scheduler for startup and recovery automation

## Requirements

- Windows
- PowerShell 5.1+
- .NET 8 SDK for building the desktop app

## Quick Start

Run the PowerShell UI:

```powershell
.\sleepy-night.ps1 -Ui
```

Build the desktop app:

```powershell
.\build-desktop.ps1
```

Run the desktop app:

```powershell
.\sleepy-night.ps1 -Desktop
```

Install autostart tasks as Administrator:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install-sleepy-night-tasks.ps1
```

Remove autostart tasks:

```powershell
.\install-sleepy-night-tasks.ps1 -Uninstall
```

## Release Build

Create a release-ready package and zip:

```powershell
.\build-release.ps1
```

This produces:

- `dist\SleepyNight\SleepyNight.exe`
- `release\SleepyNight-v0.1.0\`
- `release\SleepyNight-v0.1.0.zip`

## Repo Layout

- `SleepyNight.Desktop/` - WinForms desktop dashboard project
- `sleepy-night-core.ps1` - shared config, state, logging, scheduler, and process helpers
- `sleepy-night-agent.ps1` - background enforcement agent
- `sleepy-night-watchdog.ps1` - watchdog / recovery script
- `sleepy-night-ui.ps1` - PowerShell UI with tray support
- `install-sleepy-night-tasks.ps1` - Task Scheduler install/remove script
- `build-desktop.ps1` - publish the desktop app into `dist/`
- `build-release.ps1` - build and stage a GitHub-release-ready package
- `Images/` - UI assets, background, and icon source files

## Main UI Actions

- save settings
- start or stop the agent
- install, remove, or repair autostart
- skip tonight
- clear skip
- open the log
- minimize to tray
- run a quick safe test window

## Notes

- runtime files such as `sleepy-night.log`, `sleepy-night-state.json`, and `sleepy-night-status.json` are intentionally ignored in Git
- autostart installation uses Task Scheduler and may trigger a Windows UAC prompt
- the desktop app and the PowerShell scripts share the same config/state/status files

## Roadmap

See [ROADMAP.md](ROADMAP.md).
