import XCTest
@testable import Fonic_HiFi

@MainActor
final class HomeLoadRequestGateTests: XCTestCase {
    func testNewRequestInvalidatesOlderRequest() {
        var gate = HomeLoadRequestGate()

        let firstRequest = gate.begin()
        let secondRequest = gate.begin()

        XCTAssertFalse(gate.isCurrent(firstRequest))
        XCTAssertTrue(gate.isCurrent(secondRequest))
    }

    func testInvalidationRejectsCurrentRequest() {
        var gate = HomeLoadRequestGate()
        let request = gate.begin()

        gate.invalidate()

        XCTAssertFalse(gate.isCurrent(request))
    }

    func testNeverCompletingGreetingDoesNotBlockReadyLibraryContent() {
        var phase = HomeLoadPhase()

        phase.beginGreetingLoad()
        phase.finishLibraryLoad()

        XCTAssertEqual(phase.greeting, .loading)
        XCTAssertFalse(
            phase.blocksHomeContent,
            "Library-backed Home content must render without awaiting the model"
        )
    }

    func testUnavailableGreetingFallbackCanFinishIndependently() {
        var phase = HomeLoadPhase()

        phase.finishLibraryLoad()
        phase.beginGreetingLoad()
        phase.finishGreetingLoad()

        XCTAssertEqual(phase.library, .ready)
        XCTAssertEqual(phase.greeting, .ready)
        XCTAssertFalse(phase.blocksHomeContent)
    }
}
