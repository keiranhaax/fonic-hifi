@testable import Fonic_HiFi
import SwiftData
import XCTest

final class TrackDataActorTests: XCTestCase {
    func testCreateTrackPersistsMetadata() async throws {
        let environment = try makeEnvironment(testCase: self)
        let fileURL = try makeTemporaryFile(named: "metadatatest.flac", testCase: self)
        let metadata = makeMetadata(url: fileURL)

        _ = try await environment.actor.createTrack(from: metadata)
        guard let resolvedIdentifier = try await environment.actor.trackExists(for: fileURL) else {
            XCTFail("Expected track to exist after creation")
            return
        }

        let stored = try await environment.actor.getTrackMetadata(for: resolvedIdentifier)

        XCTAssertEqual(stored.title, metadata.title)
        XCTAssertEqual(stored.artist, metadata.artist)
        XCTAssertEqual(stored.album, metadata.album)
        XCTAssertEqual(stored.audioFormat, metadata.audioFormat)
        XCTAssertEqual(stored.sampleRate, metadata.sampleRate)
        XCTAssertEqual(stored.bitDepth, metadata.bitDepth)
        XCTAssertEqual(stored.channels, metadata.channels)
        XCTAssertTrue(stored.isLossless)
    }

    func testCreateTracksStoresAllEntries() async throws {
        let environment = try makeEnvironment(testCase: self)
        let first = try makeTemporaryFile(named: "batch-one.flac", testCase: self)
        let second = try makeTemporaryFile(named: "batch-two.flac", testCase: self)

        let identifiers = try await environment.actor.createTracks(from: [
            makeMetadata(url: first, title: "One"),
            makeMetadata(url: second, title: "Two"),
        ])

        XCTAssertEqual(identifiers.count, 2)
        let count = try await environment.actor.getTracksCount()
        XCTAssertEqual(count, 2)
    }

    func testTrackExistsMatchesSourceURLAndBookmark() async throws {
        let environment = try makeEnvironment(testCase: self)
        let fileURL = try makeTemporaryFile(named: "duplicate-check.flac", testCase: self)
        let bookmark = try fileURL.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        let metadata = makeMetadata(url: fileURL).withSourceInfo(
            sourceURL: fileURL,
            sourceBookmark: bookmark
        )

        let identifier = try await environment.actor.createTrack(from: metadata)

        let matchByURL = try await environment.actor.trackExists(for: fileURL)
        XCTAssertEqual(matchByURL, identifier)

        let matchByBookmark = try await environment.actor.trackExists(for: fileURL, bookmark: bookmark)
        XCTAssertEqual(matchByBookmark, identifier)
    }

    func testDeleteTrackRemovesEntry() async throws {
        let environment = try makeEnvironment(testCase: self)
        let fileURL = try makeTemporaryFile(named: "delete-track.flac", testCase: self)
        let metadata = makeMetadata(url: fileURL)

        _ = try await environment.actor.createTrack(from: metadata)
        guard let resolvedIdentifier = try await environment.actor.trackExists(for: fileURL) else {
            XCTFail("Expected track to exist before deletion")
            return
        }

        try await environment.actor.deleteTrack(resolvedIdentifier)

        let exists = try await environment.actor.trackExists(for: fileURL)
        XCTAssertNil(exists)
    }

    func testCleanupMissingFilesRemovesEntries() async throws {
        let environment = try makeEnvironment(testCase: self)
        let fileURL = try makeTemporaryFile(named: "orphaned.flac", testCase: self)

        _ = try await environment.actor.createTrack(from: makeMetadata(url: fileURL))
        try FileManager.default.removeItem(at: fileURL)

        let removed = try await environment.actor.cleanupMissingFiles()
        XCTAssertEqual(removed, 1)

        let exists = try await environment.actor.trackExists(for: fileURL)
        XCTAssertNil(exists)
    }

    func testWithSourceInfoPopulatesHashes() {
        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("hash-source.flac")
        let bookmark = Data([0x01, 0x02, 0x03])
        let metadata = makeMetadata(url: fileURL).withSourceInfo(
            sourceURL: fileURL,
            sourceBookmark: bookmark
        )

        XCTAssertNotNil(metadata.sourceURLHash)
        XCTAssertNotNil(metadata.sourceBookmarkHash)
    }

    func testToggleFavorite() async throws {
        // Given
        let environment = try makeEnvironment(testCase: self)
        let fileURL = try makeTemporaryFile(named: "favorite-test.flac", testCase: self)
        let metadata = makeMetadata(url: fileURL)

        let trackId = try await environment.actor.createTrack(from: metadata)

        // When - toggle favorite on
        try await environment.actor.toggleFavorite(trackId: trackId)

        // Then - should be favorite
        let afterFirstToggle = try await environment.actor.getTrackMetadata(for: trackId)
        XCTAssertTrue(afterFirstToggle.isFavorite == true, "Track should be marked as favorite after first toggle")

        // When - toggle favorite off
        try await environment.actor.toggleFavorite(trackId: trackId)

        // Then - should not be favorite
        let afterSecondToggle = try await environment.actor.getTrackMetadata(for: trackId)
        XCTAssertTrue(afterSecondToggle.isFavorite == false, "Track should not be favorite after second toggle")
    }
}

// MARK: - Helpers

private struct TrackActorEnvironment {
    let actor: TrackDataActor
    let container: ModelContainer
}

private func makeEnvironment(testCase: XCTestCase) throws -> TrackActorEnvironment {
    let schema = Schema([Track.self])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let actor = TrackDataActor(modelContainer: container)

    return TrackActorEnvironment(actor: actor, container: container)
}

private func makeMetadata(url: URL, title: String = "Sample Title") -> TrackMetadata {
    TrackMetadata(
        url: url,
        title: title,
        artist: "Sample Artist",
        album: "Sample Album",
        audioFormat: "FLAC",
        duration: 240,
        sampleRate: 96_000,
        bitDepth: 24,
        bitrate: 320,
        channels: 2,
        isLossless: true,
        lyrics: "Lyrics",
        comment: "Comment",
        sourceURL: url
    )
}

private func makeTemporaryFile(named name: String, testCase: XCTestCase) throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent(name)
    try Data([0x00, 0x01, 0x02, 0x03]).write(to: url)

    testCase.addTeardownBlock {
        try? FileManager.default.removeItem(at: directory)
    }

    return url
}
