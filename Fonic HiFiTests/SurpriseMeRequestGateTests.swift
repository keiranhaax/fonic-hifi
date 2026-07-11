@testable import Fonic_HiFi
import XCTest

@MainActor
final class SurpriseMeRequestGateTests: XCTestCase {
    func testRejectsReentryUntilRequestFinishes() {
        var gate = SurpriseMeRequestGate()

        XCTAssertTrue(gate.begin())
        XCTAssertTrue(gate.isRunning)
        XCTAssertFalse(gate.begin())

        gate.finish()

        XCTAssertFalse(gate.isRunning)
        XCTAssertTrue(gate.begin())
    }
}
