import XCTest
@testable import HeadroomCore

final class AppFootprintTests: XCTestCase {
    private let app = AppIdentity(bundlePath: "/Applications/Editor.app", pid: 42, startTime: 100)

    func testUnreliableIntervalsNeverProduceGrowth() {
        for time in [0.0, -1, 0.5, 46, .nan, .infinity] {
            var tracker = AppGrowthTracker()
            _ = tracker.update([AppFootprint(identity: app, bytes: 100)], time: 0)
            XCTAssertTrue(tracker.update([AppFootprint(identity: app, bytes: 180)], time: time).isEmpty)
            if !time.isFinite {
                XCTAssertTrue(tracker.update([AppFootprint(identity: app, bytes: 200)], time: 15).isEmpty)
            }
        }
    }

    func testFailedOrMissingAppReadRequiresTwoNewSuccessfulSamples() {
        var tracker = AppGrowthTracker()
        _ = tracker.update([AppFootprint(identity: app, bytes: 100)], time: 0)
        _ = tracker.update([], time: 15)
        XCTAssertTrue(tracker.update([AppFootprint(identity: app, bytes: 180)], time: 30).isEmpty)
        XCTAssertEqual(tracker.update([AppFootprint(identity: app, bytes: 200)], time: 45)[app]?.bytes, 20)
    }

    func testRestartPIDReuseAndSameNamedAppsAreDifferentIdentities() {
        let others = [
            AppIdentity(bundlePath: app.bundlePath, pid: 43, startTime: app.startTime),
            AppIdentity(bundlePath: app.bundlePath, pid: app.pid, startTime: 101),
            AppIdentity(bundlePath: "/Other/Editor.app", pid: app.pid, startTime: app.startTime)
        ]
        for other in others {
            var tracker = AppGrowthTracker()
            _ = tracker.update([AppFootprint(identity: app, bytes: 100)], time: 0)
            XCTAssertTrue(tracker.update([AppFootprint(identity: other, bytes: 180)], time: 15).isEmpty)
            XCTAssertFalse(QuitEligibility.allows(selected: app, current: other,
                                                  isRegular: true, isSelf: false, isProtected: false))
        }
    }

    func testQuitRequiresExactIdentityAndEligibleApplication() {
        XCTAssertTrue(QuitEligibility.allows(selected: app, current: app,
                                             isRegular: true, isSelf: false, isProtected: false))
        XCTAssertFalse(QuitEligibility.allows(selected: app, current: nil,
                                              isRegular: true, isSelf: false, isProtected: false))
        for flags in [(false, false, false), (true, true, false), (true, false, true)] {
            XCTAssertFalse(QuitEligibility.allows(selected: app, current: app,
                                                  isRegular: flags.0, isSelf: flags.1, isProtected: flags.2))
        }
    }

    func testFootprintDecreaseDoesNotUnderflow() {
        var tracker = AppGrowthTracker()
        _ = tracker.update([AppFootprint(identity: app, bytes: UInt64.max)], time: 0)
        let change = tracker.update([AppFootprint(identity: app, bytes: 0)], time: 15)[app]
        XCTAssertEqual(change?.bytes, -Double(UInt64.max))
    }

    func testGrowthUsesSameProcessFootprintAndElapsedTime() throws {
        var tracker = AppGrowthTracker()
        XCTAssertTrue(tracker.update([AppFootprint(identity: app, bytes: 100)], time: 0).isEmpty)
        let changes = tracker.update([AppFootprint(identity: app, bytes: 180)], time: 20)
        let change = try XCTUnwrap(changes[app])
        XCTAssertEqual(change.bytes, 80)
        XCTAssertEqual(change.seconds, 20)
    }
}
