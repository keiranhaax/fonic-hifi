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

    func testCreateTrackPersistsNumberTotalsAndReplayGain() async throws {
        let environment = try makeEnvironment(testCase: self)
        let fileURL = try makeTemporaryFile(named: "numbering-replaygain.flac", testCase: self)
        let metadata = makeMetadata(
            url: fileURL,
            trackNumber: 3,
            totalTracks: 12,
            discNumber: 2,
            totalDiscs: 3,
            replayGainTrack: -6.5,
            replayGainAlbum: -4.25
        )

        let identifier = try await environment.actor.createTrack(from: metadata)
        let refetchingActor = TrackDataActor(modelContainer: environment.container)
        let stored = try await refetchingActor.getTrackMetadata(for: identifier)

        XCTAssertEqual(stored.trackNumber, 3)
        XCTAssertEqual(stored.totalTracks, 12)
        XCTAssertEqual(stored.discNumber, 2)
        XCTAssertEqual(stored.totalDiscs, 3)
        XCTAssertEqual(try XCTUnwrap(stored.replayGainTrack), -6.5, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(stored.replayGainAlbum), -4.25, accuracy: 0.001)
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

    func testCreateTrackCreatesAlbumAndArtistRelationships() async throws {
        let environment = try makeEnvironment(testCase: self)
        let fileURL = try makeTemporaryFile(named: "relationship-link.flac", testCase: self)

        _ = try await environment.actor.createTrack(from: makeMetadata(url: fileURL))

        let context = ModelContext(environment.container)
        let tracks = try context.fetch(FetchDescriptor<Track>())
        XCTAssertEqual(tracks.count, 1)

        guard let track = tracks.first else {
            XCTFail("Expected one stored track")
            return
        }

        XCTAssertNotNil(track.albumRelation)
        XCTAssertNotNil(track.artistRelation)
        XCTAssertEqual(track.albumRelation?.title, "Sample Album")
        XCTAssertEqual(track.artistRelation?.name, "Sample Artist")
        XCTAssertEqual(track.albumRelation?.artistRelation?.name, "Sample Artist")
    }

    func testBackfillAlbumArtistRelationshipsPopulatesMissingRelations() async throws {
        let environment = try makeEnvironment(testCase: self)
        let fileURL = try makeTemporaryFile(named: "legacy-track.flac", testCase: self)

        let context = ModelContext(environment.container)
        let legacyTrack = Track(
            url: fileURL,
            title: "Legacy Track",
            artist: "Legacy Artist",
            album: "Legacy Album",
            audioFormat: "FLAC",
            duration: 180,
            sampleRate: 44_100,
            bitDepth: 16,
            channels: 2,
            isLossless: true
        )
        context.insert(legacyTrack)
        try context.save()

        let result = try await environment.actor.backfillAlbumArtistRelationships(batchSize: 1)
        XCTAssertEqual(result.scannedTracks, 1)
        XCTAssertEqual(result.updatedTracks, 1)
        XCTAssertEqual(result.createdAlbums, 1)
        XCTAssertEqual(result.createdArtists, 1)

        let reloadedTracks = try context.fetch(FetchDescriptor<Track>())
        guard let track = reloadedTracks.first else {
            XCTFail("Expected backfilled track")
            return
        }
        XCTAssertNotNil(track.albumRelation)
        XCTAssertNotNil(track.artistRelation)
        XCTAssertEqual(track.albumRelation?.artistRelation?.name, "Legacy Artist")
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

    func testCleanupMissingFilesQuarantinesTransientMissAndRecovers() async throws {
        let environment = try makeEnvironment(testCase: self)
        let fileURL = try makeTemporaryFile(named: "transient-miss.flac", testCase: self)
        let firstCheck = Date(timeIntervalSince1970: 1_700_000_000)

        _ = try await environment.actor.createTrack(from: makeMetadata(url: fileURL))

        let removedAfterMiss = try await environment.actor.cleanupMissingFiles(
            checker: TrackFileAvailabilityChecker { _ in false },
            now: firstCheck
        )
        XCTAssertEqual(removedAfterMiss, 0)

        var context = ModelContext(environment.container)
        var stored = try XCTUnwrap(context.fetch(FetchDescriptor<Track>()).first)
        XCTAssertEqual(stored.unavailableCheckCount, 1)
        XCTAssertEqual(stored.unavailableSince, firstCheck)
        XCTAssertEqual(stored.availabilityLastCheckedAt, firstCheck)
        XCTAssertFalse(stored.fileAvailability.isAvailable)

        let removedAfterRecovery = try await environment.actor.cleanupMissingFiles(
            checker: TrackFileAvailabilityChecker { _ in true },
            now: firstCheck.addingTimeInterval(24 * 60 * 60)
        )
        XCTAssertEqual(removedAfterRecovery, 0)

        context = ModelContext(environment.container)
        stored = try XCTUnwrap(context.fetch(FetchDescriptor<Track>()).first)
        XCTAssertEqual(stored.unavailableCheckCount, 0)
        XCTAssertNil(stored.unavailableSince)
        XCTAssertNil(stored.availabilityLastCheckedAt)
        XCTAssertTrue(stored.fileAvailability.isAvailable)
    }

    func testCleanupMissingFilesRequiresCountAndDurationThreshold() async throws {
        let environment = try makeEnvironment(testCase: self)
        let fileURL = try makeTemporaryFile(named: "threshold.flac", testCase: self)
        let firstCheck = Date(timeIntervalSince1970: 1_700_000_000)
        let unavailable = TrackFileAvailabilityChecker { _ in false }
        let policy = MissingFileQuarantinePolicy(
            requiredConsecutiveMisses: 3,
            minimumUnavailableDuration: 7 * 24 * 60 * 60
        )

        _ = try await environment.actor.createTrack(from: makeMetadata(url: fileURL))

        let firstRemovalCount = try await environment.actor.cleanupMissingFiles(
            checker: unavailable,
            policy: policy,
            now: firstCheck
        )
        XCTAssertEqual(firstRemovalCount, 0)

        let secondRemovalCount = try await environment.actor.cleanupMissingFiles(
            checker: unavailable,
            policy: policy,
            now: firstCheck.addingTimeInterval(24 * 60 * 60)
        )
        XCTAssertEqual(secondRemovalCount, 0)

        let recentThirdRemovalCount = try await environment.actor.cleanupMissingFiles(
            checker: unavailable,
            policy: policy,
            now: firstCheck.addingTimeInterval(6 * 24 * 60 * 60)
        )
        XCTAssertEqual(
            recentThirdRemovalCount,
            0,
            "The miss count alone must not remove a recently unavailable record"
        )

        let expiredRemovalCount = try await environment.actor.cleanupMissingFiles(
            checker: unavailable,
            policy: policy,
            now: firstCheck.addingTimeInterval(8 * 24 * 60 * 60)
        )
        XCTAssertEqual(expiredRemovalCount, 1)

        let context = ModelContext(environment.container)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Track>()).isEmpty)
    }

    func testCleanupMissingFilesRemovesRelationshipReferencesAfterThreshold() async throws {
        let environment = try makeEnvironment(testCase: self)
        let fileURL = try makeTemporaryFile(named: "relationship-cleanup.flac", testCase: self)
        _ = try await environment.actor.createTrack(from: makeMetadata(url: fileURL))

        let setupContext = ModelContext(environment.container)
        let track = try XCTUnwrap(setupContext.fetch(FetchDescriptor<Track>()).first)
        let playlist = Playlist(name: "Cleanup Fixture")
        playlist.trackIds = [track.id]
        playlist.tracks = [track]
        setupContext.insert(playlist)
        try setupContext.save()

        let removed = try await environment.actor.cleanupMissingFiles(
            checker: TrackFileAvailabilityChecker { _ in false },
            policy: MissingFileQuarantinePolicy(
                requiredConsecutiveMisses: 1,
                minimumUnavailableDuration: 0
            ),
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertEqual(removed, 1)

        let verificationContext = ModelContext(environment.container)
        XCTAssertTrue(try verificationContext.fetch(FetchDescriptor<Track>()).isEmpty)

        let storedPlaylist = try XCTUnwrap(
            verificationContext.fetch(FetchDescriptor<Playlist>()).first
        )
        XCTAssertTrue(storedPlaylist.tracks.isEmpty)
        XCTAssertTrue(storedPlaylist.trackIds.isEmpty)

        let storedAlbum = try XCTUnwrap(
            verificationContext.fetch(FetchDescriptor<Album>()).first
        )
        let storedArtist = try XCTUnwrap(
            verificationContext.fetch(FetchDescriptor<Artist>()).first
        )
        XCTAssertTrue(storedAlbum.tracks.isEmpty)
        XCTAssertTrue(storedArtist.tracks.isEmpty)
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
        let firstToggle = try await environment.actor.toggleFavorite(trackId: trackId)

        // Then - should be favorite
        XCTAssertTrue(firstToggle, "Toggle should return the persisted favorite state")
        let afterFirstToggle = try await environment.actor.getTrackMetadata(for: trackId)
        XCTAssertTrue(afterFirstToggle.isFavorite == true, "Track should be marked as favorite after first toggle")

        // When - toggle favorite off
        let secondToggle = try await environment.actor.toggleFavorite(trackId: trackId)

        // Then - should not be favorite
        XCTAssertFalse(secondToggle, "Toggle should return the persisted favorite state")
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

    func testListeningSessionRetentionRemovesSessionsOlderThanOneYear() async throws {
        let environment = try makeEnvironment(testCase: self)
        let expiredTrackID = UUID()
        let currentTrackID = UUID()

        try await environment.actor.recordListeningSession(
            trackId: expiredTrackID,
            startedAt: Date().addingTimeInterval(-(366 * 24 * 60 * 60)),
            durationListened: 60,
            trackDuration: 180,
            completionPercentage: 1.0 / 3.0,
            wasSkipped: false,
            wasCompleted: false
        )
        try await environment.actor.recordListeningSession(
            trackId: currentTrackID,
            startedAt: Date(),
            durationListened: 120,
            trackDuration: 180,
            completionPercentage: 2.0 / 3.0,
            wasSkipped: false,
            wasCompleted: false
        )

        let sessions = try await environment.actor.getListeningSessions(limit: 10)
        XCTAssertEqual(sessions.map(\.trackId), [currentTrackID])
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

    func testGetTrackMetadataForSearchReturnsMetadata() async throws {
        let environment = try makeEnvironment(testCase: self)

        let file1 = try makeTemporaryFile(named: "search1.flac", testCase: self)
        let file2 = try makeTemporaryFile(named: "search2.flac", testCase: self)

        _ = try await environment.actor.createTrack(from: makeMetadata(url: file1, title: "Song One", genre: "Rock"))
        _ = try await environment.actor.createTrack(from: makeMetadata(url: file2, title: "Song Two", genre: "Jazz"))

        let metadata = try await environment.actor.getTrackMetadataForSearch(limit: 50)

        XCTAssertEqual(metadata.count, 2)
        XCTAssertTrue(metadata.allSatisfy { !$0.title.isEmpty })
        XCTAssertTrue(metadata.allSatisfy { !$0.artist.isEmpty })
    }

    func testGetNeglectedTrackIDsFiltersOptionalPlaybackDatesBeforeLimiting() async throws {
        let environment = try makeEnvironment(testCase: self)
        let context = ModelContext(environment.container)
        let cutoff = Date().addingTimeInterval(-(31 * 24 * 60 * 60))

        let neverPlayed = makeTrack(title: "Never Played", playCount: 5, lastPlayed: nil)
        let neglected = makeTrack(title: "Neglected", playCount: 4, lastPlayed: cutoff)
        let recent = makeTrack(title: "Recent", playCount: 10, lastPlayed: .now)
        let unfamiliar = makeTrack(title: "Unfamiliar", playCount: 1, lastPlayed: cutoff)

        for track in [neverPlayed, neglected, recent, unfamiliar] {
            context.insert(track)
        }
        try context.save()

        let ids = try await environment.actor.getNeglectedTrackIds(
            daysSinceLastPlay: 30,
            minimumPlayCount: 2,
            limit: 2
        )

        XCTAssertEqual(ids, [neverPlayed.id, neglected.id])
    }
}

// MARK: - Helpers

private struct TrackActorEnvironment {
    let actor: TrackDataActor
    let container: ModelContainer
}

private func makeEnvironment(testCase: XCTestCase) throws -> TrackActorEnvironment {
    let schema = Schema([Track.self, Artist.self, Album.self, Playlist.self, ListeningSession.self])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let actor = TrackDataActor(modelContainer: container)

    return TrackActorEnvironment(actor: actor, container: container)
}

private func makeMetadata(
    url: URL,
    title: String = "Sample Title",
    genre: String? = nil,
    trackNumber: Int? = nil,
    totalTracks: Int? = nil,
    discNumber: Int? = nil,
    totalDiscs: Int? = nil,
    replayGainTrack: Float? = nil,
    replayGainAlbum: Float? = nil
) -> TrackMetadata {
    TrackMetadata(
        url: url,
        title: title,
        artist: "Sample Artist",
        album: "Sample Album",
        genre: genre,
        trackNumber: trackNumber,
        totalTracks: totalTracks,
        discNumber: discNumber,
        totalDiscs: totalDiscs,
        audioFormat: "FLAC",
        duration: 240,
        sampleRate: 96_000,
        bitDepth: 24,
        bitrate: 320,
        channels: 2,
        isLossless: true,
        lyrics: "Lyrics",
        comment: "Comment",
        sourceURL: url,
        replayGainTrack: replayGainTrack,
        replayGainAlbum: replayGainAlbum
    )
}

private func makeTrack(
    title: String,
    playCount: Int,
    lastPlayed: Date?
) -> Track {
    let track = Track(
        url: URL(filePath: "/tmp/\(title).flac"),
        title: title,
        artist: "Test Artist",
        album: "Test Album",
        audioFormat: "FLAC"
    )
    track.playCount = playCount
    track.lastPlayed = lastPlayed
    return track
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
