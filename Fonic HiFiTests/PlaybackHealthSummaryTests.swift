import Foundation
import XCTest
@testable import Fonic_HiFi

@MainActor
final class PlaybackHealthSummaryTests: XCTestCase {
    func testSummaryCountsEachRecordedOutcome() {
        let events = [
            PlaybackHealthEvent(kind: .mediaServicesResetDetected, timestamp: Date()),
            PlaybackHealthEvent(kind: .mediaServicesResetRecoverySucceeded, timestamp: Date()),
            PlaybackHealthEvent(kind: .mediaServicesResetDetected, timestamp: Date()),
            PlaybackHealthEvent(kind: .mediaServicesResetRecoveryFailed, timestamp: Date()),
            PlaybackHealthEvent(kind: .audioEngineConfigurationRecoveryFailed, timestamp: Date()),
        ]

        let summary = PlaybackHealthSummary(events: events)

        XCTAssertEqual(summary.totalEvents, 5)
        XCTAssertEqual(summary.resetsDetected, 2)
        XCTAssertEqual(summary.recoveriesSucceeded, 1)
        XCTAssertEqual(summary.recoveriesFailed, 2)
    }
}
