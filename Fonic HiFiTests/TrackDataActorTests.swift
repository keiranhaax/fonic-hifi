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

    // MARK: - Listening Sessions

    func testRecordListeningSession() async throws {
        let environment = try makeEnvironment(testCase: self)
        let trackId = UUID()

        try await environment.actor.recordListeningSession(
            trackId: trackId,
            startedAt: Date(),
            durationListened: 120.0,
            trackDuration: 240.0,
            completionPercentage: 0.5,
            wasSkipped: false,
            wasCompleted: false
        )

        let sessions = try await environment.actor.getListeningSessions(limit: 10)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.trackId, trackId)
    }

    func testGetRecentSessions() async throws {
        let environment = try makeEnvironment(testCase: self)
        let trackId1 = UUID()
        let trackId2 = UUID()

        try await environment.actor.recordListeningSession(
            trackId: trackId1,
            startedAt: Date().addingTimeInterval(-3600),
            durationListened: 60.0,
            trackDuration: 180.0,
            completionPercentage: 0.33,
            wasSkipped: false,
            wasCompleted: false
        )

        try await environment.actor.recordListeningSession(
            trackId: trackId2,
            startedAt: Date(),
            durationListened: 120.0,
            trackDuration: 240.0,
            completionPercentage: 0.5,
            wasSkipped: false,
            wasCompleted: true
        )

        let sessions = try await environment.actor.getListeningSessions(limit: 10)
        XCTAssertEqual(sessions.count, 2)
        // Most recent first
        XCTAssertEqual(sessions.first?.trackId, trackId2)
    }

    // MARK: - AI Recommendations Support

    func testGetSessionsByHourRangeReturnsFilteredSessions() async throws {
        let environment = try makeEnvironment(testCase: self)

        // Create session at 8am (morning)
        guard let morningDate = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) else {
            XCTFail("Could not create morning date")
            return
        }
        try await environment.actor.recordListeningSession(
            trackId: UUID(),
            startedAt: morningDate,
            durationListened: 120,
            trackDuration: 200,
            completionPercentage: 0.6,
            wasSkipped: false,
            wasCompleted: false
        )

        // Create session at 3pm (afternoon)
        guard let afternoonDate = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date()) else {
            XCTFail("Could not create afternoon date")
            return
        }
        try await environment.actor.recordListeningSession(
            trackId: UUID(),
            startedAt: afternoonDate,
            durationListened: 180,
            trackDuration: 200,
            completionPercentage: 0.9,
            wasSkipped: false,
            wasCompleted: true
        )

        let morningSessions = try await environment.actor.getSessionsByHourRange(startHour: 5, endHour: 12, limit: 10)

        XCTAssertEqual(morningSessions.count, 1)
        XCTAssertTrue(morningSessions.allSatisfy { (5..<12).contains($0.hourOfDay) })
    }

    func testGetAllTrackIDsReturnsTrackUUIDs() async throws {
        let environment = try makeEnvironment(testCase: self)

        // Create some tracks
        let file1 = try makeTemporaryFile(named: "track1.flac", testCase: self)
        let file2 = try makeTemporaryFile(named: "track2.flac", testCase: self)

        _ = try await environment.actor.createTrack(from: makeMetadata(url: file1, title: "Track One"))
        _ = try await environment.actor.createTrack(from: makeMetadata(url: file2, title: "Track Two"))

        let trackIDs = try await environment.actor.getAllTrackIDs(limit: 100)

        XCTAssertEqual(trackIDs.count, 2)
    }

    func testGetAllUniqueGenresReturnsDistinctGenres() async throws {
        let environment = try makeEnvironment(testCase: self)

        let file1 = try makeTemporaryFile(named: "rock1.flac", testCase: self)
        let file2 = try makeTemporaryFile(named: "jazz1.flac", testCase: self)
        let file3 = try makeTemporaryFile(named: "rock2.flac", testCase: self)

        _ = try await environment.actor.createTrack(from: makeMetadata(url: file1, title: "Rock Song", genre: "Rock"))
        _ = try await environment.actor.createTrack(from: makeMetadata(url: file2, title: "Jazz Song", genre: "Jazz"))
        _ = try await environment.actor.createTrack(from: makeMetadata(url: file3, title: "Another Rock", genre: "Rock"))

        let genres = try await environment.actor.getUniqueGenres()

        XCTAssertEqual(genres.count, 2)
        XCTAssertTrue(genres.contains("Rock"))
        XCTAssertTrue(genres.contains("Jazz"))
    }
}

// MARK: - Helpers

private struct TrackActorEnvironment {
    let actor: TrackDataActor
    let container: ModelContainer
}

private func makeEnvironment(testCase: XCTestCase) throws -> TrackActorEnvironment {
    let schema = Schema([Track.self, ListeningSession.self])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let actor = TrackDataActor(modelContainer: container)

    return TrackActorEnvironment(actor: actor, container: container)
}

private func makeMetadata(url: URL, title: String = "Sample Title", genre: String? = nil) -> TrackMetadata {
    TrackMetadata(
        url: url,
        title: title,
        artist: "Sample Artist",
        album: "Sample Album",
        genre: genre,
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
