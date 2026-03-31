# Navigation System

## Scope

This document describes the indoor navigation behavior implemented in the app.

Core files:

- `lib/providers/navigation_provider.dart`
- `lib/screens/navigation/navigation_screen.dart`

## Core Features

- Waypoint-based route computation
- Stair-first cross-floor routing
- Floor transition confirmation workflow
- Optional auto turn guidance
- Position and heading stabilization

## Cross-Floor Workflow

When destination floor differs from current floor:

1. Route calculation prioritizes stair transition edges.
2. As user nears the transition waypoint, app asks for target floor.
3. User moves to selected floor and taps Reached.
4. App updates floor, snaps to landing waypoint (or nearest vertical fallback), recalibrates heading, and recomputes path.

## Turn Guidance

Turn guidance can be toggled from the navigation control panel.

- Default state: disabled
- When enabled:
  - Detects upcoming turns from waypoint geometry
  - Produces messages like "Turn right in 8m"
  - Emits one haptic pulse near each unique turn
- When disabled:
  - Turn instructions and turn haptics are suppressed

## User Controls

In navigation controls:

- `Sensors` start/stop sensor streams
- `Calibrate` runs calibration flow
- `Reset` clears current position/navigation state
- `Labels` toggles room labels on map
- `Turns` enables/disables turn guidance

## Operational Notes

- If no valid staircase path exists for target floor, user sees explicit fallback guidance.
- Floor change confirmation prevents stale transition state.
- Guidance and path rendering are floor-aware to reduce map noise.
