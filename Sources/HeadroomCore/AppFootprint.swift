public struct AppIdentity: Hashable, Sendable {
    public let bundlePath: String
    public let pid: Int32
    public let startTime: UInt64
    public init(bundlePath: String, pid: Int32, startTime: UInt64) {
        self.bundlePath = bundlePath
        self.pid = pid
        self.startTime = startTime
    }
}

public struct AppFootprint: Sendable {
    public let identity: AppIdentity
    public let bytes: UInt64
    public init(identity: AppIdentity, bytes: UInt64) {
        self.identity = identity
        self.bytes = bytes
    }
}

public struct FootprintChange: Sendable {
    public let bytes: Double
    public let seconds: Double
}

public enum QuitEligibility {
    public static func allows(selected: AppIdentity, current: AppIdentity?,
                              isRegular: Bool, isSelf: Bool, isProtected: Bool) -> Bool {
        selected == current && isRegular && !isSelf && !isProtected
    }
}

public struct AppGrowthTracker: Sendable {
    private var previous: [AppIdentity: UInt64] = [:]
    private var previousTime: Double?
    public init() {}

    public mutating func update(_ readings: [AppFootprint], time: Double) -> [AppIdentity: FootprintChange] {
        guard time.isFinite, time >= 0 else {
            previous.removeAll()
            previousTime = nil
            return [:]
        }
        var current: [AppIdentity: UInt64] = [:]
        for reading in readings { current[reading.identity] = reading.bytes }
        defer { previous = current; previousTime = time }
        guard let previousTime, time - previousTime >= 1, time - previousTime <= 45 else { return [:] }
        return current.reduce(into: [:]) { changes, entry in
            guard let before = previous[entry.key] else { return }
            let delta = entry.value >= before ? Double(entry.value - before) : -Double(before - entry.value)
            changes[entry.key] = FootprintChange(bytes: delta, seconds: time - previousTime)
        }
    }
}
