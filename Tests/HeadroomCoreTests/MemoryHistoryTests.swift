import XCTest
@testable import HeadroomCore

final class MemoryHistoryTests: XCTestCase {
    func testHistoryIsBoundedByFiveMinutesAndSampleCount() {
        var history = MemoryHistory()
        for time in stride(from: 0, through: 600, by: 15) {
            history.append(time: Double(time), pressure: time < 300 ? .critical : .normal,
                           swapOutPages: UInt64(time), pageSize: 4096)
        }
        XCTAssertEqual(history.observedSeconds, 300)
        XCTAssertEqual(history.sampleCount, 21)
        XCTAssertNil(history.pressureCounts[.critical])
        XCTAssertEqual(history.swapActivity?.seconds, 300)
        for time in 601...1000 {
            history.append(time: Double(time) / 100 + 600, pressure: .normal,
                           swapOutPages: UInt64(time), pageSize: 4096)
        }
        XCTAssertLessThanOrEqual(history.sampleCount, 64)
    }

    func testGapsAndInvalidTimesRestartHistory() {
        for badTime in [10.0, 9, 100, .nan, .infinity, -.infinity] {
            var history = MemoryHistory()
            history.append(time: 10, pressure: .critical, swapOutPages: 100, pageSize: 4096)
            history.append(time: badTime, pressure: .normal, swapOutPages: 110, pageSize: 4096)
            XCTAssertNil(history.swapActivity)
            XCTAssertNil(history.pressureCounts[.critical])
            XCTAssertTrue(history.observedSeconds.isFinite)
            history.append(time: 115, pressure: .normal, swapOutPages: 130, pageSize: 4096)
            if badTime == 100 { XCTAssertEqual(history.swapActivity?.bytes, 81920) }
        }
    }

    func testFailedVMReadBreaksSwapContinuityButKeepsPressure() {
        var history = MemoryHistory()
        history.append(time: 0, pressure: .warning, swapOutPages: 10, pageSize: 4096)
        history.append(time: 15, pressure: .unknown, swapOutPages: nil, pageSize: nil)
        history.append(time: 30, pressure: .normal, swapOutPages: 100, pageSize: 4096)
        XCTAssertNil(history.swapActivity)
        XCTAssertEqual(history.pressureCounts[.warning], 1)
        XCTAssertEqual(history.pressureCounts[.unknown], 1)
        history.append(time: 45, pressure: .normal, swapOutPages: 101, pageSize: 4096)
        XCTAssertEqual(history.swapActivity?.bytes, 4096)
        XCTAssertEqual(history.swapActivity?.seconds, 15)
    }

    func testCounterResetOrPageSizeChangeStartsANewBaseline() {
        for page: UInt64 in [0, 4096, 16384] {
            var history = MemoryHistory()
            history.append(time: 0, pressure: .normal, swapOutPages: 100, pageSize: 4096)
            history.append(time: 15, pressure: .normal, swapOutPages: page == 4096 ? 1 : 110, pageSize: page)
            XCTAssertNil(history.swapActivity)
            history.append(time: 30, pressure: .normal, swapOutPages: page == 4096 ? 2 : 111, pageSize: page)
            if page == 0 { XCTAssertNil(history.swapActivity) }
            else { XCTAssertEqual(history.swapActivity?.bytes, Double(page)) }
        }
    }

    func testSubsecondRefreshDoesNotProduceARate() {
        var history = MemoryHistory()
        history.append(time: 0, pressure: .normal, swapOutPages: 1, pageSize: 4096)
        history.append(time: 0.001, pressure: .normal, swapOutPages: UInt64.max, pageSize: 4096)
        XCTAssertNil(history.swapActivity)
        history.append(time: 15, pressure: .normal, swapOutPages: UInt64.max, pageSize: 4096)
        XCTAssertTrue(history.swapActivity?.bytes.isFinite == true)
    }

    func testSwapRateUsesCounterDeltaAndActualElapsedTime() throws {
        var history = MemoryHistory()
        history.append(time: 10, pressure: .normal, swapOutPages: 100, pageSize: 4096)
        XCTAssertNil(history.swapActivity)
        history.append(time: 30, pressure: .warning, swapOutPages: 120, pageSize: 4096)
        let activity = try XCTUnwrap(history.swapActivity)
        XCTAssertEqual(activity.bytes, 81920)
        XCTAssertEqual(activity.seconds, 20)
        XCTAssertEqual(activity.bytesPerSecond, 4096)
        XCTAssertEqual(history.pressureCounts[.normal], 1)
        XCTAssertEqual(history.pressureCounts[.warning], 1)
    }
}
