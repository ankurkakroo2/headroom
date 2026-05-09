import XCTest
@testable import HeadroomCore

final class SwapPressurePolicyTests: XCTestCase {
    func testHighWhenSwapIsLargeAndMostlyUsed() {
        XCTAssertTrue(SwapPressurePolicy.isHigh(
            usedBytes: 9 * 1024 * 1024 * 1024,
            totalBytes: 12 * 1024 * 1024 * 1024
        ))
    }

    func testHighWhenSwapIsSevereEvenIfTotalIsLarge() {
        XCTAssertTrue(SwapPressurePolicy.isHigh(
            usedBytes: 12 * 1024 * 1024 * 1024,
            totalBytes: 32 * 1024 * 1024 * 1024
        ))
    }

    func testNotHighForSmallIncidentalSwap() {
        XCTAssertFalse(SwapPressurePolicy.isHigh(
            usedBytes: 2 * 1024 * 1024 * 1024,
            totalBytes: 4 * 1024 * 1024 * 1024
        ))
    }

    func testNotHighWithoutTotalUnlessSevere() {
        XCTAssertFalse(SwapPressurePolicy.isHigh(
            usedBytes: 8 * 1024 * 1024 * 1024,
            totalBytes: nil
        ))
    }
}
