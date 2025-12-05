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

    func testTimerCountsDown() async throws {
        let manager = SleepTimerManager()

        manager.start(seconds: 3)

        // Wait 1.5 seconds
        try await Task.sleep(for: .milliseconds(1500))

        // Should have counted down by ~1-2 seconds
        XCTAssertTrue(manager.isActive)
        XCTAssertLessThanOrEqual(manager.remainingSeconds, 2)
        XCTAssertGreaterThanOrEqual(manager.remainingSeconds, 1)

        manager.stop()
    }

    func testTimerTriggersOnComplete() async throws {
        let manager = SleepTimerManager()
        var didComplete = false

        manager.onComplete = {
            didComplete = true
        }

        manager.start(seconds: 1)

        // Wait for timer to complete
        try await Task.sleep(for: .milliseconds(1500))

        XCTAssertTrue(didComplete, "onComplete should have been called")
        XCTAssertFalse(manager.isActive)
        XCTAssertEqual(manager.remainingSeconds, 0)
    }

    func testFadeOutCallsVolumeCallback() async throws {
        let manager = SleepTimerManager()
        var volumeChanges: [Float] = []

        manager.onVolumeChange = { volume in
            volumeChanges.append(volume)
        }
        manager.fadeOutDuration = 2  // 2 second fade

        manager.start(seconds: 3, currentVolume: 1.0)

        // Wait for fade-out to begin (starts at 2 seconds remaining)
        try await Task.sleep(for: .milliseconds(2500))

        // Should have at least one volume change
        XCTAssertFalse(volumeChanges.isEmpty, "Should have volume changes during fade")
        if let lastVolume = volumeChanges.last {
            XCTAssertLessThan(lastVolume, 1.0, "Volume should decrease during fade")
        }

        manager.stop()
    }
}
