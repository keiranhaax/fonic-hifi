@testable import Fonic_HiFi
import Foundation
import XCTest

@MainActor
final class WidgetPlaybackStateTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "WidgetPlaybackStateTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() async throws {
        defaults?.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = ""
        try await super.tearDown()
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

    func testSaveAndLoadRoundTrip() {
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

        expected.save(to: defaults)

        guard let loaded = WidgetPlaybackState.load(from: defaults) else {
            XCTFail("Expected persisted playback state")
            return
        }
        let lastUpdated = defaults.object(forKey: WidgetConstants.Keys.lastUpdated) as? Date

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

    func testLoadOrIdleFallsBackWhenMissing() {
        defaults.removeObject(forKey: WidgetConstants.Keys.playbackState)

        XCTAssertEqual(WidgetPlaybackState.loadOrIdle(from: defaults), .idle)
    }

    func testGoldenFixtureRoundTripsTheWidgetWireContract() throws {
        let fixture = #"{"isPlaying":true,"currentTime":12.5,"duration":180,"shuffleEnabled":false,"repeatMode":"none","hasNext":true,"hasPrevious":false,"#
            + #"timestamp":"2026-08-10T12:00:00Z","playbackRate":1}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WidgetPlaybackState.self, from: Data(fixture.utf8))

        XCTAssertTrue(decoded.isPlaying)
        XCTAssertEqual(decoded.currentTime, 12.5, accuracy: 0.0001)
        XCTAssertEqual(decoded.duration, 180, accuracy: 0.0001)
        XCTAssertEqual(decoded.repeatMode, "none")
        XCTAssertTrue(decoded.hasNext)
        XCTAssertFalse(decoded.hasPrevious)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(decoded)
        let roundTripped = try decoder.decode(WidgetPlaybackState.self, from: encoded)
        XCTAssertEqual(roundTripped, decoded)
    }
}
