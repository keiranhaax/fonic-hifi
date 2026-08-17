@testable import Fonic_HiFi
import Combine
import XCTest

@MainActor
final class SleepTimerManagerTests: XCTestCase {

    func testStartTimerSetsActiveState() async {
        let clock = ControlledTestClock()
        let manager = SleepTimerManager(clock: clock)

        XCTAssertFalse(manager.isActive)
        XCTAssertEqual(manager.remainingSeconds, 0)

        manager.start(seconds: 60, currentVolume: 0.8)

        XCTAssertTrue(manager.isActive)
        XCTAssertEqual(manager.remainingSeconds, 60)
    }

    func testTimerCountsDown() async throws {
        let clock = ControlledTestClock()
        var now = Date(timeIntervalSinceReferenceDate: 0)
        let manager = SleepTimerManager(clock: clock, now: { now })

        manager.start(seconds: 3, currentVolume: 0.8)
        try await clock.waitUntilSleeperCount()

        now.addTimeInterval(1)
        clock.advance(by: .seconds(1))
        try await clock.waitUntilSleeperCount()

        XCTAssertTrue(manager.isActive)
        XCTAssertEqual(manager.remainingSeconds, 2)

        manager.stop()
    }

    func testTimerTriggersOnComplete() async throws {
        let clock = ControlledTestClock()
        var now = Date(timeIntervalSinceReferenceDate: 0)
        let manager = SleepTimerManager(clock: clock, now: { now })
        var didComplete = false
        let (completionEvents, completionContinuation) = AsyncStream<Void>.makeStream()

        manager.onComplete = {
            didComplete = true
            completionContinuation.yield()
            completionContinuation.finish()
        }

        manager.start(seconds: 1, currentVolume: 0.8)
        try await clock.waitUntilSleeperCount()

        now.addTimeInterval(1)
        clock.advance(by: .seconds(1))
        for await _ in completionEvents {
            break
        }

        XCTAssertTrue(didComplete, "onComplete should have been called")
        XCTAssertFalse(manager.isActive)
        XCTAssertEqual(manager.remainingSeconds, 0)

        // Finish the post-completion volume-restoration sleep before teardown.
        try await clock.waitUntilSleeperCount()
        clock.advance(by: .milliseconds(500))
    }

    func testFadeOutCallsVolumeCallback() async throws {
        let clock = ControlledTestClock()
        var now = Date(timeIntervalSinceReferenceDate: 0)
        let manager = SleepTimerManager(clock: clock, now: { now })
        var volumeChanges: [Float] = []

        manager.onVolumeChange = { volume in
            volumeChanges.append(volume)
        }
        manager.fadeOutDuration = 2  // 2 second fade

        manager.start(seconds: 3, currentVolume: 0.4)
        try await clock.waitUntilSleeperCount()

        now.addTimeInterval(1)
        clock.advance(by: .seconds(1))
        try await clock.waitUntilSleeperCount()

        now.addTimeInterval(1)
        clock.advance(by: .seconds(1))
        try await clock.waitUntilSleeperCount()

        XCTAssertEqual(volumeChanges, [0.4, 0.2])

        manager.stop()
        XCTAssertEqual(volumeChanges, [0.4, 0.2, 0.4])
    }

    func testElapsedBackgroundTimeIsReflectedOnNextTick() async throws {
        let clock = ControlledTestClock()
        var now = Date(timeIntervalSinceReferenceDate: 0)
        let manager = SleepTimerManager(clock: clock, now: { now })
        var volumeChanges: [Float] = []
        manager.onVolumeChange = { volumeChanges.append($0) }
        manager.fadeOutDuration = 10

        manager.start(seconds: 60, currentVolume: 0.4)
        try await clock.waitUntilSleeperCount()

        now.addTimeInterval(55)
        clock.advance(by: .seconds(1))
        try await clock.waitUntilSleeperCount()

        XCTAssertEqual(manager.remainingSeconds, 5)
        XCTAssertEqual(volumeChanges, [0.2])

        manager.stop()
    }

    func testFacadeOwnsInjectedTimerAcrossPresentations() {
        let manager = SleepTimerManager()
        let facade = AudioEngineFacade(
            runtimeMonitoringEnabled: false,
            sleepTimerManager: manager
        )

        let firstPresentation = facade.sleepTimerManager
        firstPresentation.start(seconds: 60, currentVolume: 0.8)
        let reopenedPresentation = facade.sleepTimerManager

        XCTAssertTrue(firstPresentation === reopenedPresentation)
        XCTAssertTrue(reopenedPresentation.isActive)

        reopenedPresentation.cancel(restoreVolume: false)
    }
}
