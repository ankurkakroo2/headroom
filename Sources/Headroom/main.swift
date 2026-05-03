import AppKit
import Darwin
import Foundation

enum PressureState: String {
    case normal = "Normal"
    case warning = "Warning"
    case critical = "Critical"
    case unknown = "Unknown"

    var color: NSColor {
        switch self {
        case .normal:
            return NSColor(red: 0.18, green: 0.75, blue: 0.44, alpha: 0.86)
        case .warning:
            return NSColor(red: 0.87, green: 0.68, blue: 0.17, alpha: 0.92)
        case .critical:
            return NSColor(red: 0.90, green: 0.28, blue: 0.30, alpha: 0.96)
        case .unknown:
            return NSColor.systemGray
        }
    }
}

struct MemorySnapshot {
    let pressure: PressureState
    let pressureLevel: Int32?
    let activeBytes: UInt64
    let inactiveBytes: UInt64
    let speculativeBytes: UInt64
    let wiredBytes: UInt64
    let compressorBytes: UInt64
    let freeBytes: UInt64
    let purgeableBytes: UInt64
    let swapUsedBytes: UInt64?
    let swapTotalBytes: UInt64?
    let capturedAt: Date

    var cacheBytes: UInt64 {
        inactiveBytes + speculativeBytes + purgeableBytes
    }

    var appAndSystemBytes: UInt64 {
        activeBytes + wiredBytes + compressorBytes
    }

    var fastHeadroomBytes: UInt64 {
        cacheBytes + freeBytes
    }

    var beforeSwapBufferBytes: UInt64 {
        fastHeadroomBytes + compressorBytes
    }

    var statusSummary: String {
        switch pressure {
        case .normal:
            return "Low"
        case .warning:
            return "Medium"
        case .critical:
            return "High"
        case .unknown:
            return "Unknown"
        }
    }

    var plainEnglish: String {
        switch pressure {
        case .normal:
            return "No action needed"
        case .warning:
            return "Close a heavy app soon"
        case .critical:
            return "Close heavy apps now"
        case .unknown:
            return "Unable to read pressure"
        }
    }
}

final class MemorySampler {
    func sample() -> MemorySnapshot {
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        let pressureLevel = readPressureLevel()
        let pressure = pressureState(for: pressureLevel)

        guard result == KERN_SUCCESS else {
            let swapUsage = readSwapUsage()
            return MemorySnapshot(
                pressure: pressure,
                pressureLevel: pressureLevel,
                activeBytes: 0,
                inactiveBytes: 0,
                speculativeBytes: 0,
                wiredBytes: 0,
                compressorBytes: 0,
                freeBytes: 0,
                purgeableBytes: 0,
                swapUsedBytes: swapUsage?.usedBytes,
                swapTotalBytes: swapUsage?.totalBytes,
                capturedAt: Date()
            )
        }

        let swapUsage = readSwapUsage()
        let page = UInt64(pageSize)
        return MemorySnapshot(
            pressure: pressure,
            pressureLevel: pressureLevel,
            activeBytes: UInt64(stats.active_count) * page,
            inactiveBytes: UInt64(stats.inactive_count) * page,
            speculativeBytes: UInt64(stats.speculative_count) * page,
            wiredBytes: UInt64(stats.wire_count) * page,
            compressorBytes: UInt64(stats.compressor_page_count) * page,
            freeBytes: UInt64(stats.free_count) * page,
            purgeableBytes: UInt64(stats.purgeable_count) * page,
            swapUsedBytes: swapUsage?.usedBytes,
            swapTotalBytes: swapUsage?.totalBytes,
            capturedAt: Date()
        )
    }

    private func readPressureLevel() -> Int32? {
        var level = Int32(0)
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0)
        return result == 0 ? level : nil
    }

    private func pressureState(for level: Int32?) -> PressureState {
        guard let level else { return .unknown }
        switch level {
        case 0, 1:
            return .normal
        case 2:
            return .warning
        default:
            return .critical
        }
    }

    private func readSwapUsage() -> (usedBytes: UInt64, totalBytes: UInt64)? {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = sysctlbyname("vm.swapusage", &usage, &size, nil, 0)
        guard result == 0 else { return nil }
        return (usage.xsu_used, usage.xsu_total)
    }
}

final class DotImageFactory {
    func image(for state: PressureState) -> NSImage {
        let size = NSSize(width: 12, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let dotRect = NSRect(x: 2, y: 5, width: 8, height: 8)
        let dot = NSBezierPath(ovalIn: dotRect)
        state.color.setFill()
        dot.fill()

        if state == .warning || state == .critical {
            let ringRect = dotRect.insetBy(dx: -2, dy: -2)
            let ring = NSBezierPath(ovalIn: ringRect)
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
    private let imageFactory = DotImageFactory()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var timer: Timer?
    private var latestSnapshot: MemorySnapshot?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        refresh()
        timer = Timer.scheduledTimer(
            timeInterval: 15,
            target: self,
            selector: #selector(refresh),
            userInfo: nil,
            repeats: true
        )
    }

    private func configureStatusItem() {
        statusItem.length = 14
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.toolTip = "Headroom"
        statusItem.menu = makeMenu()
    }

    @objc private func refresh() {
        latestSnapshot = sampler.sample()
        if let snapshot = latestSnapshot {
            statusItem.button?.image = imageFactory.image(for: snapshot.pressure)
            statusItem.button?.toolTip = "Memory pressure: \(snapshot.statusSummary)"
        }
        statusItem.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        if let snapshot = latestSnapshot {
            menu.addItem(disabledItem("Memory pressure: \(snapshot.statusSummary)"))
            if let swapUsedBytes = snapshot.swapUsedBytes {
                menu.addItem(disabledItem("Swap used: \(formatBytes(swapUsedBytes))"))
            } else {
                menu.addItem(disabledItem("Swap used: unavailable"))
            }
            if snapshot.pressure != .normal {
                menu.addItem(disabledItem(snapshot.plainEnglish))
            }

            menu.addItem(spacerItem())
            menu.addItem(headerItem("Buffer (\(formatBytes(snapshot.beforeSwapBufferBytes)))"))
            menu.addItem(disabledItem("Fast buffer: \(formatBytes(snapshot.fastHeadroomBytes))"))
            menu.addItem(grandchildItem("Files/cache: \(formatBytes(snapshot.cacheBytes))"))
            menu.addItem(grandchildItem("Truly free: \(formatBytes(snapshot.freeBytes))"))
            menu.addItem(disabledItem("Compressed buffer: \(formatBytes(snapshot.compressorBytes))"))

            menu.addItem(spacerItem())
            menu.addItem(headerItem("Usage (\(formatBytes(snapshot.activeBytes + snapshot.wiredBytes)))"))
            menu.addItem(disabledItem("Apps active now: \(formatBytes(snapshot.activeBytes))"))
            menu.addItem(disabledItem("System locked: \(formatBytes(snapshot.wiredBytes))"))

            menu.addItem(spacerItem())
            menu.addItem(disabledItem("Updated: \(formatDate(snapshot.capturedAt))"))
        } else {
            menu.addItem(disabledItem("Memory pressure: Unknown"))
            menu.addItem(disabledItem("Unable to read pressure"))
        }

        menu.addItem(spacerItem())
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Headroom", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func childItem(_ title: String) -> NSMenuItem {
        disabledItem("      \(title)")
    }

    private func grandchildItem(_ title: String) -> NSMenuItem {
        disabledItem("      \(title)")
    }

    private func spacerItem() -> NSMenuItem {
        let item = NSMenuItem(title: " ", action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func headerItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title.uppercased(), action: nil, keyEquivalent: "")
        item.isEnabled = false
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        item.attributedTitle = NSAttributedString(string: title.uppercased(), attributes: attributes)
        return item
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.includesUnit = true
        formatter.includesCount = true
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = HeadroomApp()
app.delegate = delegate
app.run()
