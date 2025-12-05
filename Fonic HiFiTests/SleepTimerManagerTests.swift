@testable import Fonic_HiFi
import Combine
import XCTest

@MainActor
final class SleepTimerManagerTests: XCTestCase {

    func testStartTimerSetsActiveState() async throws {
        let manager = SleepTimerManager()

        XCTAssertFalse(manager.isActive)
        XCTAssertEqual(manager.remainingSeconds, 0)

        manager.start(seconds: 60)

        XCTAssertTrue(manager.isActive)
        XCTAssertEqual(manager.remainingSeconds, 60)
    }
}
