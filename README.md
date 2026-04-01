# SleepyNight

SleepyNight is a Windows bedtime-enforcement app built with PowerShell automation and a native WinForms desktop dashboard.

The core idea is simple: after your chosen bedtime, the computer should stop being a comfortable place to keep using.

## What It Does

- runs a background agent after sign-in;
- shows warnings before the restricted window begins;
- enforces a nightly restriction window;
- supports `warn only`, `lock only`, `lock + shut down`, and `lock + sign out` modes;
- supports separate weekday and weekend schedules;
- keeps a desktop dashboard with live status, autostart controls, quick test mode, and log access;
- includes skip and schedule-change cooldown rules;
- uses a watchdog to restart the agent when needed;
- can install Windows Task Scheduler autostart tasks.

Default schedule:

- weekdays: `20:30 -> 03:00`
- weekends: `22:30 -> 04:00`

## Stack

- PowerShell for the enforcement agent, watchdog, config/state handling, and Task Scheduler integration
- C# / WinForms for the desktop dashboard
- Windows Task Scheduler for autostart and recovery tasks

## Requirements

- Windows
- PowerShell 5.1+
- .NET 8 SDK for building the desktop app

## Quick Start

Run the PowerShell UI:

```powershell
.\sleepy-night.ps1 -Ui
```

Run the desktop dashboard after building:

```powershell
.\sleepy-night.ps1 -Desktop
```

Build the desktop app:

```powershell
.\build-desktop.ps1
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

## Repo Layout

- `SleepyNight.Desktop/` - native WinForms dashboard project
- `sleepy-night-core.ps1` - shared config, state, logging, scheduler, and process helpers
- `sleepy-night-agent.ps1` - background enforcement agent
- `sleepy-night-watchdog.ps1` - watchdog / recovery script
- `sleepy-night-ui.ps1` - PowerShell UI with tray support
- `install-sleepy-night-tasks.ps1` - Task Scheduler install/remove script
- `build-desktop.ps1` - build and publish helper for the desktop app
- `sleepy-night-config.json` - persistent config defaults
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

- runtime files such as `sleepy-night.log`, `sleepy-night-state.json`, and `sleepy-night-status.json` are intentionally ignored in Git;
- autostart installation uses Task Scheduler and may trigger a Windows UAC prompt;
- the desktop app and the PowerShell scripts share the same config/state/status files.

## Roadmap

See [ROADMAP.md](ROADMAP.md).
