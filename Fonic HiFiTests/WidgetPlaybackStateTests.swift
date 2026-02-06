import Foundation
import XCTest

@testable import Fonic_HiFi

@MainActor
final class WidgetPlaybackStateTests: XCTestCase {
    private var defaults: UserDefaults?

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaults = UserDefaults.appGroup
        defaults?.removeObject(forKey: WidgetConstants.Keys.playbackState)
        defaults?.removeObject(forKey: WidgetConstants.Keys.lastUpdated)
    }

    override func tearDownWithError() throws {
        defaults?.removeObject(forKey: WidgetConstants.Keys.playbackState)
        defaults?.removeObject(forKey: WidgetConstants.Keys.lastUpdated)
        defaults = nil
        try super.tearDownWithError()
    }

    func testComputedPropertiesClampAndClassifyState() {
        let recent = WidgetPlaybackState(
            isPlaying: true,
            currentTime: 50,
            duration: 200,
            shuffleEnabled: true,
            repeatMode: "all",
            hasNext: true,
            hasPrevious: true
        )

        XCTAssertEqual(recent.progress, 0.25, accuracy: 0.0001)
        XCTAssertEqual(recent.remainingTime, 150, accuracy: 0.0001)
        XCTAssertFalse(recent.isAtBeginning)
        XCTAssertFalse(recent.isNearEnd)
        XCTAssertFalse(recent.isStale)
    }

    func testComputedPropertiesHandleBoundaryValues() {
        let beginning = WidgetPlaybackState(
            isPlaying: true,
            currentTime: -5,
            duration: 0,
            shuffleEnabled: false,
            repeatMode: "none",
            hasNext: false,
            hasPrevious: false
        )
        XCTAssertEqual(beginning.progress, 0)
        XCTAssertEqual(beginning.remainingTime, 5)
        XCTAssertTrue(beginning.isAtBeginning)

        let ending = WidgetPlaybackState(
            isPlaying: true,
            currentTime: 195,
            duration: 198,
            shuffleEnabled: false,
            repeatMode: "one",
            hasNext: false,
            hasPrevious: true
        )
        XCTAssertTrue(ending.isNearEnd)

        let staleTimestamp = Date().addingTimeInterval(-301)
        let stale = WidgetPlaybackState(
            isPlaying: false,
            currentTime: 0,
            duration: 10,
            shuffleEnabled: false,
            repeatMode: "none",
            hasNext: false,
            hasPrevious: false,
            timestamp: staleTimestamp
        )
        XCTAssertTrue(stale.isStale)
        XCTAssertGreaterThan(stale.age, 300)
    }

    func testSaveAndLoadRoundTrip() throws {
        guard defaults != nil else {
            throw XCTSkip("App Group defaults unavailable")
        }

        let expected = WidgetPlaybackState(
            isPlaying: true,
            currentTime: 73,
            duration: 180,
            shuffleEnabled: true,
            repeatMode: "all",
            hasNext: true,
            hasPrevious: true,
            playbackRate: 1.25
        )

        expected.save()

        guard let loaded = WidgetPlaybackState.load() else {
            XCTFail("Expected persisted playback state")
            return
        }
        let lastUpdated = defaults?.object(forKey: WidgetConstants.Keys.lastUpdated) as? Date

        XCTAssertEqual(loaded.isPlaying, expected.isPlaying)
        XCTAssertEqual(loaded.currentTime, expected.currentTime, accuracy: 0.0001)
        XCTAssertEqual(loaded.duration, expected.duration, accuracy: 0.0001)
        XCTAssertEqual(loaded.shuffleEnabled, expected.shuffleEnabled)
        XCTAssertEqual(loaded.repeatMode, expected.repeatMode)
        XCTAssertEqual(loaded.hasNext, expected.hasNext)
        XCTAssertEqual(loaded.hasPrevious, expected.hasPrevious)
        XCTAssertEqual(loaded.playbackRate, expected.playbackRate, accuracy: 0.0001)
        XCTAssertEqual(loaded.timestamp.timeIntervalSince(expected.timestamp), 0, accuracy: 1.0)
        XCTAssertNotNil(lastUpdated)
    }

    func testLoadOrIdleFallsBackWhenMissing() throws {
        guard defaults != nil else {
            throw XCTSkip("App Group defaults unavailable")
        }

        defaults?.removeObject(forKey: WidgetConstants.Keys.playbackState)

        XCTAssertEqual(WidgetPlaybackState.loadOrIdle(), .idle)
    }
}
