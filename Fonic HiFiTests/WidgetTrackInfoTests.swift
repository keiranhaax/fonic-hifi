import Foundation
import XCTest

@testable import Fonic_HiFi

@MainActor
final class WidgetTrackInfoTests: XCTestCase {
    private var defaults: UserDefaults?

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaults = UserDefaults.appGroup
        defaults?.removeObject(forKey: WidgetConstants.Keys.trackInfo)
        defaults?.removeObject(forKey: WidgetConstants.Keys.upNextTracks)
    }

    override func tearDownWithError() throws {
        defaults?.removeObject(forKey: WidgetConstants.Keys.trackInfo)
        defaults?.removeObject(forKey: WidgetConstants.Keys.upNextTracks)
        defaults = nil
        try super.tearDownWithError()
    }

    func testComputedPropertiesRenderExpectedValues() {
        let info = makeTrackInfo(
            title: "Midnight",
            artist: "The Artist",
            album: "The Album",
            duration: 185,
            audioFormat: "flac",
            isLossless: true
        )

        XCTAssertEqual(info.formattedDuration, "3:05")
        XCTAssertEqual(info.artistAlbum, "The Artist — The Album")
        XCTAssertEqual(info.qualityBadge, "FLAC")
        XCTAssertEqual(info.inlineDisplay, "Midnight • The Artist")
    }

    func testComputedPropertiesHandleMissingFields() {
        let info = makeTrackInfo(
            title: "Interlude",
            artist: "",
            album: "",
            duration: 42,
            audioFormat: "aac",
            isLossless: false
        )

        XCTAssertEqual(info.artistAlbum, "")
        XCTAssertEqual(info.inlineDisplay, "Interlude")
        XCTAssertNil(info.qualityBadge)
    }

    func testSaveAndLoadRoundTrip() throws {
        guard defaults != nil else {
            throw XCTSkip("App Group defaults unavailable")
        }

        let expected = makeTrackInfo(
            title: "Round Trip",
            artist: "Verifier",
            album: "Suite",
            duration: 320,
            audioFormat: "alac",
            isLossless: true
        )

        expected.save()
        let loaded = WidgetTrackInfo.load()

        XCTAssertEqual(loaded, expected)
    }

    func testLoadOrEmptyFallsBackWhenMissing() throws {
        guard defaults != nil else {
            throw XCTSkip("App Group defaults unavailable")
        }

        defaults?.removeObject(forKey: WidgetConstants.Keys.trackInfo)

        let loaded = WidgetTrackInfo.loadOrEmpty()

        XCTAssertEqual(loaded.title, WidgetTrackInfo.empty.title)
        XCTAssertEqual(loaded.artist, WidgetTrackInfo.empty.artist)
    }

    func testUpNextSaveAndLoadRoundTrip() throws {
        guard defaults != nil else {
            throw XCTSkip("App Group defaults unavailable")
        }

        let tracks = [
            makeTrackInfo(title: "A", artist: "One", album: "X", duration: 120, audioFormat: "flac", isLossless: true),
            makeTrackInfo(title: "B", artist: "Two", album: "Y", duration: 180, audioFormat: "mp3", isLossless: false),
            makeTrackInfo(title: "C", artist: "Three", album: "Z", duration: 240, audioFormat: "alac", isLossless: true),
        ]

        tracks.saveAsUpNext()
        let loaded = [WidgetTrackInfo].loadUpNext()

        XCTAssertEqual(loaded, tracks)
    }

    func testLoadUpNextReturnsEmptyWhenUnset() throws {
        guard defaults != nil else {
            throw XCTSkip("App Group defaults unavailable")
        }

        defaults?.removeObject(forKey: WidgetConstants.Keys.upNextTracks)

        XCTAssertTrue([WidgetTrackInfo].loadUpNext().isEmpty)
    }

    private func makeTrackInfo(
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        audioFormat: String,
        isLossless: Bool
    ) -> WidgetTrackInfo {
        WidgetTrackInfo(
            id: UUID(),
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            artworkKey: UUID().uuidString,
            audioFormat: audioFormat,
            isLossless: isLossless
        )
    }
}
