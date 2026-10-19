public struct SwapActivity: Sendable {
    public let bytes: Double
    public let seconds: Double
    public var bytesPerSecond: Double { bytes / seconds }
}

public struct MemoryHistory: Sendable {
    private struct Sample: Sendable {
        let time: Double
        let pressure: PressureState
        let pages: UInt64?
        let pageSize: UInt64?
    }
    private var samples: [Sample] = []
    public init() {}
    public var sampleCount: Int { samples.count }
    public var observedSeconds: Double { (samples.last?.time ?? 0) - (samples.first?.time ?? 0) }
    public var pressureCounts: [PressureState: Int] {
        samples.reduce(into: [:]) { $0[$1.pressure, default: 0] += 1 }
    }
    public mutating func append(time: Double, pressure: PressureState, swapOutPages: UInt64?, pageSize: UInt64?) {
        // Callers supply continuous monotonic seconds (including sleep), never wall time.
        guard time.isFinite, time >= 0 else { samples.removeAll(); return }
        if let last = samples.last, time <= last.time || time - last.time > 45 {
            samples.removeAll()
        }
        samples.append(Sample(time: time, pressure: pressure, pages: swapOutPages, pageSize: pageSize))
        samples.removeAll { $0.time < time - 300 }
        if samples.count > 64 { samples.removeFirst(samples.count - 64) }
    }
    public var swapActivity: SwapActivity? {
        guard let last = samples.last, let end = last.pages,
              let page = last.pageSize, page > 0 else { return nil }
        var first = last
        for previous in samples.dropLast().reversed() {
            guard let pages = previous.pages, previous.pageSize == page,
                  let nextPages = first.pages, pages <= nextPages else { break }
            first = previous
        }
        guard let start = first.pages, last.time - first.time >= 1 else { return nil }
        // Convert before multiplying so extreme counters cannot overflow UInt64.
        return SwapActivity(bytes: Double(end - start) * Double(page), seconds: last.time - first.time)
    }
}
