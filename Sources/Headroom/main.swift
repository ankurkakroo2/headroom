import AppKit
import Foundation
import HeadroomCore
import HeadroomSystem

extension PressureState {
    var color: NSColor {
        switch self {
        case .normal: NSColor(red: 0.18, green: 0.75, blue: 0.44, alpha: 0.86)
        case .warning: NSColor(red: 0.87, green: 0.68, blue: 0.17, alpha: 0.92)
        case .critical: NSColor(red: 0.90, green: 0.28, blue: 0.30, alpha: 0.96)
        case .unknown: NSColor.systemGray
        }
    }
}

@MainActor
final class DotImageFactory {
    func image(for state: PressureState) -> NSImage {
        let size = NSSize(width: 12, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        let dotRect = NSRect(x: 2, y: 5, width: 8, height: 8)
        state.color.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
        if state.offersRelief {
            let ring = NSBezierPath(ovalIn: dotRect.insetBy(dx: -2, dy: -2))
            state.color.withAlphaComponent(0.35).setStroke()
            ring.lineWidth = 1
            ring.stroke()
        }
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

@MainActor
final class HeadroomApp: NSObject, NSApplicationDelegate {
    private let sampler = MemorySampler()
    private var topAppSampler = TopAppSampler()
    private let imageFactory = DotImageFactory()
    private let appQuitRequester = AppQuitRequester()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var timer: Timer?
    private var history = MemoryHistory()
    private var topApps: [AppMemoryItem] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem.length = 14
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleNone
        refresh()
        timer = Timer.scheduledTimer(timeInterval: 15, target: self, selector: #selector(refresh),
                                     userInfo: nil, repeats: true)
        timer?.tolerance = 3
    }

    @objc private func refresh() {
        let snapshot = sampler.sample()
        let time = HRContinuousSeconds()
        history.append(time: time, pressure: snapshot.pressure,
                       swapOutPages: snapshot.vm?.swapOutPages, pageSize: snapshot.vm?.pageSize)
        topApps = topAppSampler.sample(time: time)
        statusItem.button?.image = imageFactory.image(for: snapshot.pressure)
        statusItem.button?.toolTip = "Headroom: \(snapshot.pressure.summary)\n\(snapshot.pressure.advice)"
        statusItem.button?.setAccessibilityLabel("Headroom: \(snapshot.pressure.summary)")
        statusItem.menu = makeMenu(snapshot)
    }

    private func makeMenu(_ snapshot: MemorySnapshot) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(disabledItem(snapshot.pressure.summary))
        menu.addItem(disabledItem(snapshot.pressure.advice))
        menu.addItem(.separator())
        menu.addItem(appsMenuItem())
        if snapshot.pressure.offersRelief, let relief = reliefMenuItem() { menu.addItem(relief) }
        menu.addItem(detailsMenuItem(snapshot))
        menu.addItem(.separator())
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        let quitItem = NSMenuItem(title: "Quit Headroom", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        return menu
    }

    private func appsMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Apps by memory", action: nil, keyEquivalent: "")
        let menu = NSMenu()
        menu.addItem(disabledItem("Main-process footprint only; helpers not included"))
        menu.addItem(.separator())
        for app in topApps {
            var title = "\(displayName(app)): \(formatBytes(app.footprint.bytes))"
            if let change = app.change, change.bytes >= 1024 * 1024 {
                title += String(format: " (+%.0f MiB in %.0f s)", change.bytes / 1_048_576, change.seconds)
            }
            let row = disabledItem(title)
            row.toolTip = app.footprint.identity.bundlePath
            menu.addItem(row)
        }
        if topApps.isEmpty { menu.addItem(disabledItem("No app readings available")) }
        if topAppSampler.unavailableCount > 0 {
            menu.addItem(disabledItem("\(topAppSampler.unavailableCount) app reading(s) unavailable"))
        }
        menu.addItem(.separator())
        menu.addItem(disabledItem("Growth compares successful readings, not a leak diagnosis"))
        item.submenu = menu
        return item
    }

    private func detailsMenuItem(_ snapshot: MemorySnapshot) -> NSMenuItem {
        let item = NSMenuItem(title: "Details", action: nil, keyEquivalent: "")
        let menu = NSMenu()
        menu.addItem(disabledItem("Swap in use: \(snapshot.swapUsedBytes.map(formatBytes) ?? "unavailable")"))
        menu.addItem(disabledItem("Existing swap can remain while memory is comfortable"))
        if let activity = history.swapActivity {
            menu.addItem(disabledItem(String(format: "Recent swap-outs: %.1f MiB over %.0f s", activity.bytes / 1_048_576, activity.seconds)))
            menu.addItem(disabledItem(String(format: "Average: %.2f MiB/s (VM counter estimate)", activity.bytesPerSecond / 1_048_576)))
        } else {
            menu.addItem(disabledItem("Recent swap-outs: waiting for comparable readings"))
        }
        menu.addItem(.separator())
        menu.addItem(disabledItem(String(format: "Recent pressure: %.0f s observed (up to 5 min)", history.observedSeconds)))
        let counts = history.pressureCounts
        menu.addItem(disabledItem("Readings: \(counts[.normal, default: 0]) comfortable · \(counts[.warning, default: 0]) elevated · \(counts[.critical, default: 0]) high · \(counts[.unknown, default: 0]) unavailable"))
        menu.addItem(.separator())
        if let vm = snapshot.vm {
            menu.addItem(disabledItem("Compressed RAM (occupied): \(formatBytes(vm.compressorBytes))"))
            menu.addItem(disabledItem("Wired RAM: \(formatBytes(vm.wiredBytes))"))
            menu.addItem(disabledItem("Active pages: \(formatBytes(vm.activeBytes))"))
            menu.addItem(disabledItem("Inactive pages: \(formatBytes(vm.inactiveBytes))"))
            menu.addItem(disabledItem("Free pages (includes speculative): \(formatBytes(vm.freeBytes))"))
        } else {
            menu.addItem(disabledItem("RAM details: unavailable"))
        }
        menu.addItem(disabledItem("These are VM categories, not an available-memory budget"))
        menu.addItem(.separator())
        menu.addItem(disabledItem("Updated: \(DateFormatter.localizedString(from: snapshot.capturedAt, dateStyle: .none, timeStyle: .medium))"))
        item.submenu = menu
        return item
    }

    private func reliefMenuItem() -> NSMenuItem? {
        let apps = topApps.filter { appQuitRequester.canRequestQuit(identity: $0.footprint.identity) }
        guard !apps.isEmpty else { return nil }
        let item = NSMenuItem(title: "Quit an unused app…", action: nil, keyEquivalent: "")
        let menu = NSMenu()
        menu.addItem(disabledItem("Choose an app; you’ll be asked to confirm"))
        for app in apps {
            let row = NSMenuItem(title: "\(displayName(app)) (\(formatBytes(app.footprint.bytes)))…",
                                 action: #selector(confirmQuitApp(_:)), keyEquivalent: "")
            row.target = self
            row.representedObject = app
            menu.addItem(row)
        }
        item.submenu = menu
        return item
    }

    private func displayName(_ app: AppMemoryItem) -> String {
        topApps.filter { $0.name == app.name }.count > 1 ? "\(app.name) (PID \(app.footprint.identity.pid))" : app.name
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useMB, .useGB]
        return formatter.string(fromByteCount: Int64(clamping: bytes))
    }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func confirmQuitApp(_ sender: NSMenuItem) {
        guard let app = sender.representedObject as? AppMemoryItem else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Quit \(app.name)?"
        alert.informativeText = "This requests a normal quit, never a force quit. Save any unsaved work first. The app may ask you to save or may decline. Existing swap may not shrink right away.\n\n\(app.footprint.identity.bundlePath)\nPID \(app.footprint.identity.pid)"
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Quit \(app.name)")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        switch appQuitRequester.requestQuit(identity: app.footprint.identity) {
        case .requested:
            refresh()
        case .notFound:
            showActionFailure("The selected app stopped, restarted, or could not be safely verified. Refresh and try again.")
        case .failed:
            showActionFailure("The app did not accept the quit request. You can quit it from its own menu.")
        }
    }

    private func showActionFailure(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could not request quit"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = HeadroomApp()
app.delegate = delegate
app.run()
