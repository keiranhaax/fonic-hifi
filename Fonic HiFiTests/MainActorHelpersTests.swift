@testable import Fonic_HiFi
import XCTest

@MainActor
final class MainActorHelpersTests: XCTestCase {
    func testAssertIsolatedOnMainActorDoesNotFail() {
        XCTAssertNoThrow(MainActor.assertIsolated())
    }

    func testLogContextRunsOnMainActor() {
        XCTAssertNoThrow(MainActor.logContext(message: "Verifying main actor"))
    }

    func testDebugLogThreadContextRunsOnMainThread() {
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertNoThrow(debugLogThreadContext("Testing"))
    }
}
