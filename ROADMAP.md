# SleepyNight Roadmap

This roadmap is split into practical steps so the project can keep improving without losing its core purpose: bedtime enforcement that is simple, reliable, and hard to ignore.

## Current Foundation

Already in place:

- Windows bedtime enforcement agent
- desktop dashboard UI
- weekday / weekend scheduling
- warning pipeline before restriction starts
- lock / shut down / sign out modes
- autostart install, remove, and repair flows
- watchdog-based recovery
- skip cooldown and schedule-change cooldown rules
- quick test mode with restore of the main schedule

## Near Term

### Reliability

- make the watchdog status even more explicit in the UI
- add a one-click `Run health check` action
- log autostart repair attempts and outcomes more clearly
- improve error messages for Task Scheduler and permission issues

### UX / Product Polish

- refine the dashboard layout and spacing further
- improve small-size icon rendering for tray and title bar
- add a stronger restricted-state visual mode / overlay
- make disabled button states and hover states more polished
- simplify the left information rail even more

### Quality of Life

- export / import config
- restore last-known-good config
- add a `What happens tonight` summary with exact warning times
- show next skip availability and next schedule-change availability more prominently

## Mid Term

### Scheduling

- support custom schedules per day of week
- support exception days / one-night extensions
- support a softer enforcement ramp like `lock only` for the first phase and `shut down` later

### Notifications

- replace basic warnings with richer in-app warning windows
- improve notification text and countdown formatting
- add a more intentional restricted overlay experience

### Observability

- better built-in log viewer with filtering
- event categories such as `warning`, `lock`, `shutdown`, `watchdog`, `autostart`
- easier troubleshooting summary for common failures

## Long Term

### Hardening

- stronger anti-bypass enforcement
- deeper startup resilience beyond the current watchdog model
- optional service-based or more privileged runtime path, if needed

### Distribution

- installer package for easier setup
- signed executable and polished release packaging
- versioned releases with changelog

### Product Finish

- onboarding flow for first launch
- app settings backup / sync story
- accessibility pass for contrast, keyboard flow, and scaling

## Guiding Principle

Every future improvement should still protect the main promise:

- bedtime arrives
- the restriction window starts on time
- the computer becomes inconvenient to keep using
- the rule stays understandable and manageable from one clear UI
