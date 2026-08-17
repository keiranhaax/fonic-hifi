@testable import Fonic_HiFi
import Foundation
import XCTest

@MainActor
final class WidgetTrackInfoTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "WidgetTrackInfoTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() async throws {
        defaults?.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = ""
        try await super.tearDown()
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

    func testSaveAndLoadRoundTrip() {
        let expected = makeTrackInfo(
            title: "Round Trip",
            artist: "Verifier",
            album: "Suite",
            duration: 320,
            audioFormat: "alac",
            isLossless: true
        )

        expected.save(to: defaults)
        let loaded = WidgetTrackInfo.load(from: defaults)

        XCTAssertEqual(loaded, expected)
    }

    func testLoadOrEmptyFallsBackWhenMissing() {
        defaults.removeObject(forKey: WidgetConstants.Keys.trackInfo)

        let loaded = WidgetTrackInfo.loadOrEmpty(from: defaults)

        XCTAssertEqual(loaded.title, WidgetTrackInfo.empty.title)
        XCTAssertEqual(loaded.artist, WidgetTrackInfo.empty.artist)
    }

    func testUpNextSaveAndLoadRoundTrip() {
        let tracks = [
            makeTrackInfo(title: "A", artist: "One", album: "X", duration: 120, audioFormat: "flac", isLossless: true),
            makeTrackInfo(title: "B", artist: "Two", album: "Y", duration: 180, audioFormat: "mp3", isLossless: false),
            makeTrackInfo(title: "C", artist: "Three", album: "Z", duration: 240, audioFormat: "alac", isLossless: true),
        ]

        tracks.saveAsUpNext(to: defaults)
        let loaded = [WidgetTrackInfo].loadUpNext(from: defaults)

        XCTAssertEqual(loaded, tracks)
    }

    func testLoadUpNextReturnsEmptyWhenUnset() {
        defaults.removeObject(forKey: WidgetConstants.Keys.upNextTracks)

        XCTAssertTrue([WidgetTrackInfo].loadUpNext(from: defaults).isEmpty)
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
