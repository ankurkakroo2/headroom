import AppKit
import Darwin
import Foundation
import HeadroomCore
import HeadroomSystem

struct MemorySampler {
    func sample() -> MemorySnapshot {
        MemorySnapshot(pressure: PressureState(level: readPressureLevel()),
                       vm: readVM(), swapUsedBytes: readSwapUsed())
    }

    private func readVM() -> VMReading? {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        var pageSize: vm_size_t = 0
        guard host_page_size(host, &pageSize) == KERN_SUCCESS, pageSize > 0 else { return nil }
        var stats = vm_statistics64()
        let expectedCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        var count = expectedCount
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(expectedCount)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS, count >= expectedCount else { return nil }
        let page = UInt64(pageSize)
        return VMReading(activeBytes: UInt64(stats.active_count) * page,
                         inactiveBytes: UInt64(stats.inactive_count) * page,
                         wiredBytes: UInt64(stats.wire_count) * page,
                         compressorBytes: UInt64(stats.compressor_page_count) * page,
                         freeBytes: UInt64(stats.free_count) * page,
                         swapOutPages: stats.swapouts, pageSize: page)
    }

    private func readPressureLevel() -> Int32? {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0,
              size == MemoryLayout<Int32>.size else { return nil }
        return level
    }

    private func readSwapUsed() -> UInt64? {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0,
              size == MemoryLayout<xsw_usage>.size else { return nil }
        return usage.xsu_used
    }
}

struct AppMemoryItem {
    let name: String
    let footprint: AppFootprint
    let change: FootprintChange?
}

// Only regular GUI apps' main processes: no guessed helper groups or RSS sums.
@MainActor
struct TopAppSampler {
    private var growth = AppGrowthTracker()
    private(set) var unavailableCount = 0

    static func footprint(for app: NSRunningApplication) -> AppFootprint? {
        guard !app.isTerminated, let url = app.bundleURL else { return nil }
        var reading = HRFootprint()
        guard HRReadFootprint(app.processIdentifier, &reading), !app.isTerminated else { return nil }
        let identity = AppIdentity(bundlePath: url.resolvingSymlinksInPath().standardizedFileURL.path,
                                   pid: app.processIdentifier, startTime: reading.startTime)
        return AppFootprint(identity: identity, bytes: reading.bytes)
    }

    mutating func sample(time: Double) -> [AppMemoryItem] {
        unavailableCount = 0
        var readings: [(name: String, footprint: AppFootprint)] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard let footprint = Self.footprint(for: app) else { unavailableCount += 1; continue }
            let name = app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent ?? "App"
            readings.append((name, footprint))
        }
        let changes = growth.update(readings.map(\.footprint), time: time)
        return readings.map {
            AppMemoryItem(name: $0.name, footprint: $0.footprint, change: changes[$0.footprint.identity])
        }.sorted {
            if $0.footprint.bytes != $1.footprint.bytes { return $0.footprint.bytes > $1.footprint.bytes }
            return $0.footprint.identity.pid < $1.footprint.identity.pid
        }.prefix(5).map { $0 }
    }
}
