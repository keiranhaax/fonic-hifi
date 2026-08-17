@testable import Fonic_HiFi
import Foundation
import XCTest

@MainActor
final class AppGroupManagerTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private var manager: AppGroupManager!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "AppGroupManagerTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        manager = AppGroupManager(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults?.removePersistentDomain(forName: suiteName)
        manager = nil
        defaults = nil
        suiteName = ""
        try await super.tearDown()
    }

    func testUpdatePlaybackStatePersistsStateAndSyncDate() {
        let state = WidgetPlaybackState(
            isPlaying: true,
            currentTime: 30,
            duration: 180,
            shuffleEnabled: true,
            repeatMode: "all",
            hasNext: true,
            hasPrevious: true
        )

        manager.updatePlaybackState(state)

        let loaded = manager.loadPlaybackState()
        XCTAssertEqual(loaded.isPlaying, state.isPlaying)
        XCTAssertEqual(loaded.currentTime, state.currentTime, accuracy: 0.0001)
        XCTAssertEqual(loaded.duration, state.duration, accuracy: 0.0001)
        XCTAssertEqual(loaded.shuffleEnabled, state.shuffleEnabled)
        XCTAssertEqual(loaded.repeatMode, state.repeatMode)
        XCTAssertEqual(loaded.hasNext, state.hasNext)
        XCTAssertEqual(loaded.hasPrevious, state.hasPrevious)
        XCTAssertEqual(loaded.playbackRate, state.playbackRate, accuracy: 0.0001)
        XCTAssertEqual(manager.loadLastUpdated(), defaults.object(forKey: WidgetConstants.Keys.lastUpdated) as? Date)
        XCTAssertNotNil(manager.lastSyncDate)
    }

    func testUpdatePlaybackStatePersistsProgressOnlyChanges() {
        let baseline = WidgetPlaybackState(
            isPlaying: true,
            currentTime: 10,
            duration: 200,
            shuffleEnabled: false,
            repeatMode: "none",
            hasNext: true,
            hasPrevious: false
        )
        manager.updatePlaybackState(baseline)

        let progressOnly = WidgetPlaybackState(
            isPlaying: true,
            currentTime: 90,
            duration: 200,
            shuffleEnabled: false,
            repeatMode: "none",
            hasNext: true,
            hasPrevious: false
        )
        XCTAssertTrue(manager.updatePlaybackState(progressOnly))

        let loaded = manager.loadPlaybackState()
        XCTAssertEqual(loaded.currentTime, progressOnly.currentTime, accuracy: 0.0001)
        XCTAssertEqual(loaded.duration, baseline.duration, accuracy: 0.0001)
    }

    func testUpdateTrackInfoSavesAndClearsData() {
        let track = makeTrackInfo(title: "One", artist: "Artist")
        manager.updateTrackInfo(track)
        XCTAssertEqual(manager.loadTrackInfo(), track)

        // Same track should be ignored and not break state.
        manager.updateTrackInfo(track)
        XCTAssertEqual(manager.loadTrackInfo(), track)

        manager.updateTrackInfo(nil)
        XCTAssertNil(manager.loadTrackInfo())
    }

    func testUpdateUpNextTracksTruncatesToFive() {
        let tracks = (0 ..< 7).map { index in
            makeTrackInfo(title: "Track-\(index)", artist: "Artist-\(index)")
        }

        manager.updateUpNextTracks(tracks)
        let loaded = manager.loadUpNextTracks()

        XCTAssertEqual(loaded.count, 5)
        XCTAssertEqual(loaded.map(\.title), tracks.prefix(5).map(\.title))
    }

    func testClearAllDataResetsPersistedWidgetState() {
        manager.updatePlaybackState(
            WidgetPlaybackState(
                isPlaying: true,
                currentTime: 11,
                duration: 99,
                shuffleEnabled: false,
                repeatMode: "none",
                hasNext: true,
                hasPrevious: true
            )
        )
        manager.updateTrackInfo(makeTrackInfo(title: "To Clear", artist: "Artist"))
        manager.updateUpNextTracks((0 ..< 3).map { makeTrackInfo(title: "Up-\($0)", artist: "Artist") })

        manager.clearAllData()

        XCTAssertEqual(manager.loadPlaybackState(), .idle)
        XCTAssertNil(manager.loadTrackInfo())
        XCTAssertTrue(manager.loadUpNextTracks().isEmpty)
        XCTAssertNil(manager.lastSyncDate)
    }

    func testRelaunchedManagerClearsPriorProcessTrackAndUpNext() throws {
        let suiteName = "AppGroupManagerTests.\(UUID().uuidString)"
        let isolatedDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { isolatedDefaults.removePersistentDomain(forName: suiteName) }

        let priorProcess = AppGroupManager(defaults: isolatedDefaults)
        let current = makeTrackInfo(title: "Prior", artist: "Artist")
        let upcoming = makeTrackInfo(title: "Upcoming", artist: "Artist")
        priorProcess.updateTrackInfo(current)
        priorProcess.updateUpNextTracks([upcoming])

        let relaunched = AppGroupManager(defaults: isolatedDefaults)
        XCTAssertEqual(relaunched.loadTrackInfo(), current)
        XCTAssertEqual(relaunched.loadUpNextTracks(), [upcoming])

        XCTAssertTrue(relaunched.updateTrackInfo(nil))
        XCTAssertTrue(relaunched.updateUpNextTracks([]))
        XCTAssertNil(relaunched.loadTrackInfo())
        XCTAssertTrue(relaunched.loadUpNextTracks().isEmpty)
    }

    func testSameTrackCanGainArtworkWithoutChangingIdentity() throws {
        let suiteName = "AppGroupManagerTests.\(UUID().uuidString)"
        let isolatedDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { isolatedDefaults.removePersistentDomain(forName: suiteName) }

        let isolatedManager = AppGroupManager(defaults: isolatedDefaults)
        let trackId = UUID()
        let placeholder = makeTrackInfo(
            id: trackId,
            title: "Track",
            artist: "Artist",
            artworkKey: nil
        )
        let resolved = makeTrackInfo(
            id: trackId,
            title: "Track",
            artist: "Artist",
            artworkKey: trackId.uuidString
        )

        XCTAssertTrue(isolatedManager.updateTrackInfo(placeholder))
        XCTAssertTrue(isolatedManager.updateTrackInfo(resolved))
        XCTAssertEqual(isolatedManager.loadTrackInfo(), resolved)
    }

    func testQueuePayloadWritesAdvancePersistedSyncDate() throws {
        let suiteName = "AppGroupManagerTests.\(UUID().uuidString)"
        let isolatedDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { isolatedDefaults.removePersistentDomain(forName: suiteName) }

        let isolatedManager = AppGroupManager(defaults: isolatedDefaults)
        XCTAssertTrue(
            isolatedManager.updateTrackInfo(
                makeTrackInfo(title: "Current", artist: "Artist")
            )
        )
        XCTAssertNotNil(
            isolatedDefaults.object(forKey: WidgetConstants.Keys.lastUpdated) as? Date
        )

        isolatedDefaults.removeObject(forKey: WidgetConstants.Keys.lastUpdated)
        XCTAssertTrue(
            isolatedManager.updateUpNextTracks([
                makeTrackInfo(title: "Next", artist: "Artist"),
            ])
        )
        XCTAssertNotNil(
            isolatedDefaults.object(forKey: WidgetConstants.Keys.lastUpdated) as? Date
        )
    }

    private func makeTrackInfo(
        id: UUID = UUID(),
        title: String,
        artist: String,
        artworkKey: String? = UUID().uuidString
    ) -> WidgetTrackInfo {
        WidgetTrackInfo(
            id: id,
            title: title,
            artist: artist,
            album: "Album",
            duration: 180,
            artworkKey: artworkKey,
            audioFormat: "FLAC",
            isLossless: true
        )
    }
}
