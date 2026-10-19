# Headroom

<div align="center">
  <img width="256" height="256" alt="Headroom icon" src="https://github.com/user-attachments/assets/9d282d83-f7e0-4b39-b748-7b099e12f696" />
</div>

Headroom is a tiny native macOS menu bar app that answers: **does memory need my attention right now?**

Its quiet dot follows macOS memory pressure, not how full RAM looks:

- **Green:** memory is comfortable. No action needed.
- **Amber:** memory is under pressure. If your Mac feels slow, quit an app you’re not using.
- **Red:** pressure is high. Save your work and quit unused apps.
- **Gray:** pressure could not be read. Headroom does not guess.

Click for advice, **Apps by memory**, and a **Details** submenu. There are no notifications, automatic quits, memory cleaners, analytics, or runtime network requests. Sampling runs every 15 seconds with timer tolerance; Refresh takes another reading.

## What the numbers mean

**Pressure comes first.** Existing swap can remain after a busy workload ends. Large accumulated swap alone does not change the dot, trigger a warning, or offer quit actions. Headroom does not treat allocated swap space as a fixed capacity or recommend restarting just to clear it.

**There is no “buffer before swap” or “available RAM” estimate.** Compressed RAM is occupied, not spare memory. The kernel’s free-page count already includes speculative pages. Details shows individual VM categories without adding overlapping cache/purgeable categories into a misleading total. Failed pressure, VM, or swap reads show unavailable, not fabricated zeros. Active pages are not labeled as app memory.

**Recent activity is separate from accumulated swap.** Details includes changes in the kernel’s cumulative swap-out page counter and an average over the actual observed interval. This is a VM-counter byte estimate, not measured disk throughput or a prediction. A real zero means the counter did not increase; an unavailable rate means there are not yet comparable readings.

**History is short and local.** Pressure readings and swap counters live only in memory, for up to five minutes and at most 64 samples. Readings are counts, not a continuous pressure graph; short spikes between polls can be missed. Startup, missing VM readings, counter resets, page-size changes, and long gaps require a new swap baseline. Continuous monotonic time includes sleep and ignores wall-clock changes. Gaps over 45 seconds reset history; intervals under one second do not produce rates. Nothing is saved to disk.

## Apps and safe quit requests

**Apps by memory** lists up to five regular GUI apps by their main process’s physical footprint (`proc_pid_rusage`, not `ps` RSS). **Helpers, browser tabs, background daemons, and command-line tools are not included.** This is deliberately not a whole-app/group total and may differ substantially from Activity Monitor. Apps whose readings are denied or disappear are omitted and counted as unavailable.

A growth annotation compares two consecutive successful samples of the same bundle path, PID, and process start time, separated by 1–45 seconds. Missing apps, restarts, PID reuse, and gaps do not produce growth claims. Growth below 1 MiB is not annotated; an increase is not a leak diagnosis. Collection covers all eligible apps before selecting the largest five, so entering or leaving the displayed list does not manufacture growth.

When pressure is elevated, **Quit an unused app…** offers eligible apps from that list. It defaults to Cancel and shows the selected app’s path and PID. After confirmation, Headroom rechecks the exact process identity, excludes itself and protected system apps, and asks the app to quit normally. It never force-quits anything. An app may prompt to save, decline, or take time to exit. Quitting does not guarantee immediate swap reduction.

## Install

Requires macOS 14 or newer and a Swift 6 toolchain (for example, Xcode 16 command-line tools).

```bash
git clone https://github.com/ankurkakroo2/headroom.git
cd headroom
./scripts/install.sh
```

The installer builds the app, copies it to `~/Applications/Headroom.app`, and launches it.

## Build and test

```bash
swift test
./scripts/build-app.sh
```

The release bundle is written to `dist/Headroom.app` and signed ad hoc for local use, not notarized distribution. The macOS GitHub Actions workflow runs tests, builds that bundle, checks its plist/resources/executable, and verifies its signature. A passing build does not replace hands-on menu, accessibility, sleep/wake, or quit-dialog testing.

Linux with Swift 6 can run `swift test` for platform-independent policy/history/identity tests only. Linux does **not** build or validate AppKit or Darwin calls. macOS additionally runs live process-footprint and clock smoke tests.

```bash
./scripts/measure.sh
```

Use the measurement script on a Mac to inspect Headroom’s own overhead. API details and Apple source references are in [Measurement notes](docs/measurement-notes.md).
