import Foundation
import XCTest

@testable import Fonic_HiFi

@MainActor
final class AppGroupManagerTests: XCTestCase {
    private let manager = AppGroupManager.shared
    private var defaults: UserDefaults?

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaults = UserDefaults.appGroup

        defaults?.removeObject(forKey: WidgetConstants.Keys.playbackState)
        defaults?.removeObject(forKey: WidgetConstants.Keys.trackInfo)
        defaults?.removeObject(forKey: WidgetConstants.Keys.upNextTracks)
        defaults?.removeObject(forKey: WidgetConstants.Keys.lastUpdated)
        manager.clearAllData()
    }

    override func tearDownWithError() throws {
        manager.clearAllData()
        defaults?.removeObject(forKey: WidgetConstants.Keys.playbackState)
        defaults?.removeObject(forKey: WidgetConstants.Keys.trackInfo)
        defaults?.removeObject(forKey: WidgetConstants.Keys.upNextTracks)
        defaults?.removeObject(forKey: WidgetConstants.Keys.lastUpdated)
        defaults = nil
        try super.tearDownWithError()
    }

    func testUpdatePlaybackStatePersistsStateAndSyncDate() throws {
        guard defaults != nil else {
            throw XCTSkip("App Group defaults unavailable")
        }

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
        XCTAssertEqual(manager.loadLastUpdated(), defaults?.object(forKey: WidgetConstants.Keys.lastUpdated) as? Date)
        XCTAssertNotNil(manager.lastSyncDate)
    }

    func testUpdatePlaybackStateSkipsMeaninglessProgressOnlyChanges() throws {
        guard defaults != nil else {
            throw XCTSkip("App Group defaults unavailable")
        }

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
        manager.updatePlaybackState(progressOnly)

        let loaded = manager.loadPlaybackState()
        XCTAssertEqual(loaded.currentTime, baseline.currentTime, accuracy: 0.0001)
        XCTAssertEqual(loaded.duration, baseline.duration, accuracy: 0.0001)
    }

    func testUpdateTrackInfoSavesAndClearsData() throws {
        guard defaults != nil else {
            throw XCTSkip("App Group defaults unavailable")
        }

        let track = makeTrackInfo(title: "One", artist: "Artist")
        manager.updateTrackInfo(track)
        XCTAssertEqual(manager.loadTrackInfo(), track)

        // Same track should be ignored and not break state.
        manager.updateTrackInfo(track)
        XCTAssertEqual(manager.loadTrackInfo(), track)

        manager.updateTrackInfo(nil)
        XCTAssertNil(manager.loadTrackInfo())
    }

    func testUpdateUpNextTracksTruncatesToFive() throws {
        guard defaults != nil else {
            throw XCTSkip("App Group defaults unavailable")
        }

        let tracks = (0..<7).map { index in
            makeTrackInfo(title: "Track-\(index)", artist: "Artist-\(index)")
        }

        manager.updateUpNextTracks(tracks)
        let loaded = manager.loadUpNextTracks()

        XCTAssertEqual(loaded.count, 5)
        XCTAssertEqual(loaded.map(\.title), tracks.prefix(5).map(\.title))
    }

    func testClearAllDataResetsPersistedWidgetState() throws {
        guard defaults != nil else {
            throw XCTSkip("App Group defaults unavailable")
        }

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
        manager.updateUpNextTracks((0..<3).map { makeTrackInfo(title: "Up-\($0)", artist: "Artist") })

        manager.clearAllData()

        XCTAssertEqual(manager.loadPlaybackState(), .idle)
        XCTAssertNil(manager.loadTrackInfo())
        XCTAssertTrue(manager.loadUpNextTracks().isEmpty)
        XCTAssertNil(manager.lastSyncDate)
    }

    private func makeTrackInfo(title: String, artist: String) -> WidgetTrackInfo {
        WidgetTrackInfo(
            id: UUID(),
            title: title,
            artist: artist,
            album: "Album",
            duration: 180,
            artworkKey: UUID().uuidString,
            audioFormat: "FLAC",
            isLossless: true
        )
    }
}
