# Headroom

Headroom is a tiny native macOS menu bar app for memory pressure.

It intentionally avoids showing scary RAM-used percentages. The menu bar shows one dot:

- Green: normal
- Amber: warning
- Red: critical
- Gray: unknown

Click the dot to see compact memory buckets: active, inactive/cache, wired, compressed, free, and swap.

## Build

```bash
./scripts/build-app.sh
```

The app bundle is written to:

```text
dist/Headroom.app
```

## Run

```bash
open dist/Headroom.app
```

## Measure Headroom Itself

```bash
./scripts/measure.sh
```

## Constraints

- Native Swift/AppKit
- No Electron
- No network
- No analytics
- No memory cleaning
- Slow polling by default
