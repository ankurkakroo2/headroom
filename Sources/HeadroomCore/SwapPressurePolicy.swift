import Foundation

public enum SwapPressurePolicy {
    public static let highAbsoluteBytes: UInt64 = 8 * 1024 * 1024 * 1024
    public static let severeAbsoluteBytes: UInt64 = 12 * 1024 * 1024 * 1024
    public static let highUsageRatio = 0.60

    public static func isHigh(usedBytes: UInt64?, totalBytes: UInt64?) -> Bool {
        guard let usedBytes, usedBytes > 0 else { return false }

        if usedBytes >= severeAbsoluteBytes {
            return true
        }

        guard let totalBytes, totalBytes > 0 else { return false }
        let usageRatio = Double(usedBytes) / Double(totalBytes)
        return usedBytes >= highAbsoluteBytes && usageRatio >= highUsageRatio
    }
}
