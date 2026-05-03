# Headroom Design

## Goal

Build a tiny native macOS menu bar app that answers one question: is the machine under real memory pressure?

## Decisions

- Use Swift/AppKit directly, not Electron or a full dashboard framework.
- Show a single elegant dot in the menu bar: green normal, amber warning, red critical, gray unknown.
- Avoid showing RAM-used percentage in the menu bar because it creates false alarms on macOS.
- Read `kern.memorystatus_vm_pressure_level` for the main pressure state.
- Read Mach VM statistics for the menu details: active, inactive/cache, wired, compressed, and free memory.
- Poll slowly every 15 seconds and update immediately when the user chooses Refresh.
- Use a standard menu instead of a custom popover for the first version to minimize code and runtime overhead.

## Non-Goals

- No memory cleaner.
- No analytics.
- No network calls.
- No graphs in v1.
- No launch-at-login in v1.

## Validation

- Build with `swift build -c release`.
- Package as a regular `.app` bundle.
- Launch once and confirm the process exists.
- Sample process RSS/CPU to ensure the monitor itself remains lightweight.
