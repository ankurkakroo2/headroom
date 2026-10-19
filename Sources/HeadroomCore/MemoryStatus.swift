import Foundation

public enum PressureState: String, Sendable {
    case normal, warning, critical, unknown

    public init(level: Int32?) {
        // This sysctl returns dispatch pressure flags, not internal XNU levels.
        switch level {
        case 1: self = .normal
        case 2: self = .warning
        case 4: self = .critical
        default: self = .unknown
        }
    }

    public var summary: String {
        switch self {
        case .normal: "Memory is comfortable"
        case .warning: "Memory is under pressure"
        case .critical: "Memory pressure is high"
        case .unknown: "Memory pressure is unavailable"
        }
    }

    public var advice: String {
        switch self {
        case .normal: "No action needed"
        case .warning: "If your Mac feels slow, quit an app you’re not using"
        case .critical: "Save your work and quit apps you’re not using"
        case .unknown: "Try refreshing; no action is suggested without a reading"
        }
    }

    public var offersRelief: Bool { self == .warning || self == .critical }
}

// Raw VM categories, not an estimate of available RAM. Categories may overlap.
public struct VMReading: Sendable {
    public let activeBytes: UInt64
    public let inactiveBytes: UInt64
    public let wiredBytes: UInt64
    public let compressorBytes: UInt64
    public let freeBytes: UInt64 // Already includes speculative pages.
    public let swapOutPages: UInt64 // Cumulative counter, NOT current swap usage.
    public let pageSize: UInt64

    public init(activeBytes: UInt64, inactiveBytes: UInt64, wiredBytes: UInt64,
                compressorBytes: UInt64, freeBytes: UInt64, swapOutPages: UInt64, pageSize: UInt64) {
        self.activeBytes = activeBytes
        self.inactiveBytes = inactiveBytes
        self.wiredBytes = wiredBytes
        self.compressorBytes = compressorBytes
        self.freeBytes = freeBytes
        self.swapOutPages = swapOutPages
        self.pageSize = pageSize
    }
}

public struct MemorySnapshot: Sendable {
    public let pressure: PressureState
    public let vm: VMReading?
    public let swapUsedBytes: UInt64?
    public let capturedAt: Date

    public init(pressure: PressureState, vm: VMReading?, swapUsedBytes: UInt64?, capturedAt: Date = Date()) {
        self.pressure = pressure
        self.vm = vm
        self.swapUsedBytes = swapUsedBytes
        self.capturedAt = capturedAt
    }
}
