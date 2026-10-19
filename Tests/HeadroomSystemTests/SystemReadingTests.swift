import XCTest
import Darwin
import HeadroomSystem

final class SystemReadingTests: XCTestCase {
    func testFootprintOfThisProcessHasStableIdentity() {
        var first = HRFootprint()
        var second = HRFootprint()
        XCTAssertTrue(HRReadFootprint(getpid(), &first))
        XCTAssertTrue(HRReadFootprint(getpid(), &second))
        XCTAssertGreaterThan(first.bytes, 0)
        XCTAssertGreaterThan(first.startTime, 0)
        XCTAssertEqual(first.startTime, second.startTime)
    }

    func testInvalidProcessDoesNotReturnAZeroReading() {
        var reading = HRFootprint()
        XCTAssertFalse(HRReadFootprint(-1, &reading))
    }

    func testContinuousClockIsFiniteAndMonotonic() {
        let first = HRContinuousSeconds()
        let second = HRContinuousSeconds()
        XCTAssertTrue(first.isFinite)
        XCTAssertGreaterThan(first, 0)
        XCTAssertGreaterThanOrEqual(second, first)
    }
}
