import XCTest
@testable import HeadroomCore

final class MemoryStatusTests: XCTestCase {
    func testPressureFirstAdviceDoesNotDependOnAccumulatedSwap() {
        let snapshot = MemorySnapshot(pressure: .normal, vm: nil, swapUsedBytes: UInt64.max)
        XCTAssertEqual(snapshot.pressure.summary, "Memory is comfortable")
        XCTAssertEqual(snapshot.pressure.advice, "No action needed")
        XCTAssertFalse(snapshot.pressure.offersRelief)
        XCTAssertNil(snapshot.vm, "Failed VM reads must not become zero")
    }

    func testOnlyKnownPressureLevelsAreMapped() {
        XCTAssertEqual(PressureState(level: 1), .normal)
        XCTAssertEqual(PressureState(level: 2), .warning)
        XCTAssertEqual(PressureState(level: 4), .critical)
        for level: Int32? in [nil, 0, 3, 8, -1] {
            XCTAssertEqual(PressureState(level: level), .unknown)
        }
        XCTAssertTrue(PressureState.warning.offersRelief)
        XCTAssertTrue(PressureState.critical.offersRelief)
        XCTAssertFalse(PressureState.unknown.offersRelief)
    }
}
