# Headroom

<div align="center">
  <img width="256" height="256" alt="image" src="https://github.com/user-attachments/assets/9d282d83-f7e0-4b39-b748-7b099e12f696" />
</div>

Headroom is a tiny native macOS menu bar app for memory pressure.

It exists because macOS “memory used” is a noisy number. Modern macOS keeps RAM full with cache, compression, and inactive pages, so a machine can show 20+ GB used while still being healthy. Headroom focuses on the signal that matters: memory pressure and swap.

The menu bar shows one quiet dot:

- Green: low pressure
- Amber: medium pressure
- Red: high pressure
- Gray: unknown

Click the dot to see a simple model:

- Memory pressure and swap used
- Buffer left before swap
- Current usage by apps and locked system memory
- Top app groups to consider closing when pressure rises

No Electron. No analytics. No network. No memory cleaning.

## Install

```bash
git clone https://github.com/ankurkakroo2/headroom.git && cd headroom && ./scripts/install.sh
```

The installer builds the app, copies it to:

```text
~/Applications/Headroom.app
```

and launches it.

## Build Locally

```bash
./scripts/build-app.sh
```

The app bundle is written to `dist/Headroom.app`.

## Measure Headroom

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
