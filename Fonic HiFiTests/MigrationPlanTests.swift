@testable import Fonic_HiFi
import CoreData
import Foundation
import OSLog
import SwiftData
import XCTest

@MainActor
final class MigrationPlanTests: XCTestCase {
    private enum Fixture {
        static let trackID = UUID(uuid: (0x10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        static let albumID = UUID(uuid: (0x20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
        static let artistID = UUID(uuid: (0x30, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3))
        static let playlistID = UUID(uuid: (0x40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4))
        static let sessionID = UUID(uuid: (0x50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5))
        static let bookmark = Data([0x46, 0x4F, 0x4E, 0x49, 0x43])
        static let sourceURLString = "file:///Volumes/Archive/fixture-track.flac"
        static let addedAt = Date(timeIntervalSince1970: 1_700_000_000)
        static let sessionStartedAt = Date(timeIntervalSince1970: 1_700_003_600)
        static let deployedV2Checksum = "aPr7hl9+thrTx4zb4MWTdHmK3BIQhXisbeX6NXkXwoc="
        // Captured from the deterministic current V3 disk fixture. Keeping the
        // live model types top-level is the compatibility contract for this
        // same-version store; renaming or nesting them requires a new schema.
        static let deployedV3Checksum = "5Bw51194pNM5NyACQZqFxLDN9ya7NJzE5aix6blIEE4="
    }

    func testProductionMigrationPlanPreservesShippedSchemaVersions() {
        XCTAssertEqual(SchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        XCTAssertEqual(SchemaV2.versionIdentifier, Schema.Version(2, 0, 0))
        XCTAssertEqual(SchemaV3.versionIdentifier, Schema.Version(3, 0, 0))
        XCTAssertEqual(FonicHiFiMigrationPlan.schemas.count, 3)
        XCTAssertEqual(FonicHiFiMigrationPlan.stages.count, 2)
    }

    func testV2DiskStoreMigratesLibraryRelationshipsAndAcceptsSessions() throws {
        let storeURL = try makeStoreURL(testName: #function)

        try createV2Store(at: storeURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
        try assertV2FixtureMatchesDeployedSchema(at: storeURL)

        let container = try openCurrentStore(at: storeURL)
        try assertMigratedLibrary(in: container.mainContext)
        try assertListeningSessionCanBePersisted(in: container.mainContext)
    }

    func testCurrentV3DiskStoreMatchesFrozenTopLevelSchema() throws {
        let storeURL = try makeStoreURL(testName: #function)

        try createV3Store(at: storeURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
        try assertV3FixtureMatchesDeployedSchema(at: storeURL)

        let container = try openCurrentStore(at: storeURL)
        try assertV3Fixture(in: container.mainContext)
    }

    func testV1DiskStoreMigratesTrackIdentityAndPlaylist() throws {
        let storeURL = try makeStoreURL(testName: #function)

        try createV1Store(at: storeURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))

        let container = try openCurrentStore(at: storeURL)
        let context = container.mainContext
        let tracks = try context.fetch(FetchDescriptor<Track>())
        let playlists = try context.fetch(FetchDescriptor<Playlist>())
        let recentSearches = try context.fetch(FetchDescriptor<RecentSearch>())

        let track = try XCTUnwrap(tracks.first)
        let playlist = try XCTUnwrap(playlists.first)

        XCTAssertEqual(tracks.count, 1)
        XCTAssertEqual(playlists.count, 1)
        XCTAssertTrue(recentSearches.isEmpty)
        XCTAssertEqual(track.id, Fixture.trackID)
        XCTAssertEqual(track.title, "V1 Fixture Track")
        XCTAssertEqual(track.rating, 4)
        XCTAssertEqual(track.playCount, 3)
        XCTAssertEqual(track.userTags, ["v1", "fixture"])
        XCTAssertEqual(track.albumRelation?.id, Fixture.albumID)
        XCTAssertEqual(track.artistRelation?.id, Fixture.artistID)
        XCTAssertTrue(track.playlists.contains { $0.id == Fixture.playlistID })

        XCTAssertEqual(playlist.id, Fixture.playlistID)
        XCTAssertEqual(playlist.trackIds, [Fixture.trackID])
        XCTAssertTrue(playlist.tracks.contains { $0.id == Fixture.trackID })

        try assertListeningSessionCanBePersisted(in: context)
    }

    func testProductionContainerFailureDoesNotReturnUnmarkedFallback() throws {
        let storeURL = try makeStoreURL(testName: #function)
        let unknownSchema = Schema([RecentSearch.self])
        let unknownConfiguration = configuration(for: unknownSchema, at: storeURL)

        do {
            let unknownContainer = try ModelContainer(
                for: unknownSchema,
                configurations: [unknownConfiguration]
            )
            unknownContainer.mainContext.insert(RecentSearch(query: "Unknown schema fixture"))
            try unknownContainer.mainContext.save()
        }

        let schema = Schema(versionedSchema: SchemaV3.self)
        let configuration = ModelConfiguration(
            "UnknownMigrationFixture",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        XCTAssertThrowsError(
            try DataManager.buildContainer(
                schema: schema,
                configuration: configuration,
                logger: Log.logger(.dataManagerInit)
            )
        )
    }

    private func makeStoreURL(testName: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FonicMigrationTests", isDirectory: true)
            .appendingPathComponent("\(testName)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }

        return directory.appendingPathComponent("Library.store")
    }

    private func configuration(for schema: Schema, at storeURL: URL) -> ModelConfiguration {
        ModelConfiguration(
            "MigrationFixture",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
    }

    private func createV2Store(at storeURL: URL) throws {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration(for: schema, at: storeURL)]
        )
        let context = container.mainContext

        let artist = SchemaV2.Artist(name: "Fixture Artist")
        artist.id = Fixture.artistID
        artist.genres = ["Ambient"]

        let album = SchemaV2.Album(title: "Fixture Album", albumArtist: artist.name, totalTracks: 1)
        album.id = Fixture.albumID
        album.dateAdded = Fixture.addedAt

        let track = SchemaV2.Track(
            url: storeURL.deletingLastPathComponent().appendingPathComponent("fixture-track.flac"),
            title: "Fixture Track",
            artist: artist.name,
            album: album.title,
            audioFormat: "FLAC",
            duration: 245,
            sampleRate: 96_000,
            bitDepth: 24,
            channels: 2,
            isLossless: true
        )
        track.id = Fixture.trackID
        track.dateAdded = Fixture.addedAt
        track.sourceURLBookmark = Fixture.bookmark
        track.sourceURLString = Fixture.sourceURLString
        track.sourceURLHash = "v2-url-hash"
        track.sourceBookmarkHash = "v2-bookmark-hash"
        track.rating = 5
        track.playCount = 7
        track.userTags = ["migration", "fixture"]

        let playlist = SchemaV2.Playlist(name: "Fixture Playlist")
        playlist.id = Fixture.playlistID
        playlist.trackIds = [track.id]
        playlist.dateCreated = Fixture.addedAt
        playlist.dateModified = Fixture.addedAt

        let recentSearch = SchemaV2.RecentSearch(query: "Fixture", timestamp: Fixture.addedAt, resultCount: 1)

        context.insert(artist)
        context.insert(album)
        context.insert(track)
        context.insert(playlist)
        context.insert(recentSearch)

        track.artistRelation = artist
        track.albumRelation = album
        playlist.tracks = [track]
        album.artistRelation = artist

        try context.save()
    }

    private func createV3Store(at storeURL: URL) throws {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration(for: schema, at: storeURL)]
        )
        let context = container.mainContext

        let artist = Artist(name: "V3 Fixture Artist", primaryGenre: "Ambient", country: "US", formationYear: 1999)
        artist.id = Fixture.artistID
        artist.genres = ["Ambient", "Electronic"]
        artist.isActive = true

        let album = Album(title: "V3 Fixture Album", albumArtist: artist.name, totalTracks: 1)
        album.id = Fixture.albumID
        album.dateAdded = Fixture.addedAt
        album.rating = 4
        album.isFavorite = true
        album.playCount = 2
        album.userTags = ["v3", "fixture"]

        let trackURL = URL(fileURLWithPath: "/Volumes/Archive/v3-fixture-track.flac")
        let track = Track(
            id: Fixture.trackID,
            url: trackURL,
            title: "V3 Fixture Track",
            artist: artist.name,
            album: album.title,
            audioFormat: "FLAC",
            duration: 245,
            sampleRate: 96_000,
            bitDepth: 24,
            channels: 2,
            isLossless: true
        )
        track.dateAdded = Fixture.addedAt
        track.dateModified = Fixture.addedAt
        track.sourceURLBookmark = Fixture.bookmark
        track.sourceURLString = Fixture.sourceURLString
        track.sourceURLHash = "v3-url-hash"
        track.sourceBookmarkHash = "v3-bookmark-hash"
        track.rating = 5
        track.playCount = 7
        track.isFavorite = true
        track.userTags = ["migration", "fixture"]

        let playlist = Playlist(name: "V3 Fixture Playlist")
        playlist.id = Fixture.playlistID
        playlist.trackIds = [track.id]
        playlist.dateCreated = Fixture.addedAt
        playlist.dateModified = Fixture.addedAt
        playlist.playCount = 3
        playlist.isFavorite = true
        playlist.userTags = ["v3", "fixture"]

        let recentSearch = RecentSearch(query: "V3 Fixture", timestamp: Fixture.addedAt, resultCount: 1)

        let session = ListeningSession(
            trackId: Fixture.trackID,
            startedAt: Fixture.sessionStartedAt,
            durationListened: 120,
            trackDuration: 245,
            completionPercentage: 120.0 / 245.0,
            wasSkipped: false,
            wasCompleted: false
        )
        session.id = Fixture.sessionID
        session.endedAt = Fixture.sessionStartedAt.addingTimeInterval(120)
        session.hourOfDay = 10
        session.dayOfWeek = 3

        context.insert(artist)
        context.insert(album)
        context.insert(track)
        context.insert(playlist)
        context.insert(recentSearch)
        context.insert(session)

        track.artistRelation = artist
        track.albumRelation = album
        playlist.tracks = [track]
        album.artistRelation = artist

        try context.save()
    }

    private func createV1Store(at storeURL: URL) throws {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration(for: schema, at: storeURL)]
        )
        let context = container.mainContext

        let artist = SchemaV1.Artist(name: "V1 Fixture Artist")
        artist.id = Fixture.artistID
        artist.genres = ["Ambient"]

        let album = SchemaV1.Album(
            title: "V1 Fixture Album",
            albumArtist: artist.name,
            totalTracks: 1
        )
        album.id = Fixture.albumID
        album.dateAdded = Fixture.addedAt

        let track = SchemaV1.Track(
            url: storeURL.deletingLastPathComponent().appendingPathComponent("v1-fixture-track.flac"),
            title: "V1 Fixture Track",
            artist: artist.name,
            album: album.title,
            audioFormat: "FLAC",
            duration: 180,
            sampleRate: 44_100,
            bitDepth: 16,
            channels: 2,
            isLossless: true
        )
        track.id = Fixture.trackID
        track.dateAdded = Fixture.addedAt
        track.sourceURLBookmark = Fixture.bookmark
        track.sourceURLString = Fixture.sourceURLString
        track.rating = 4
        track.playCount = 3
        track.userTags = ["v1", "fixture"]

        let playlist = SchemaV1.Playlist(name: "V1 Fixture Playlist")
        playlist.id = Fixture.playlistID
        playlist.trackIds = [track.id]
        playlist.dateCreated = Fixture.addedAt
        playlist.dateModified = Fixture.addedAt

        context.insert(artist)
        context.insert(album)
        context.insert(track)
        context.insert(playlist)

        track.artistRelation = artist
        track.albumRelation = album
        playlist.tracks = [track]
        album.artistRelation = artist

        try context.save()
    }

    private func openCurrentStore(at storeURL: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV3.self)
        return try ModelContainer(
            for: schema,
            migrationPlan: FonicHiFiMigrationPlan.self,
            configurations: [configuration(for: schema, at: storeURL)]
        )
    }

    private func assertV2FixtureMatchesDeployedSchema(at storeURL: URL) throws {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )
        XCTAssertEqual(
            metadata["NSStoreModelVersionChecksumKey"] as? String,
            Fixture.deployedV2Checksum
        )
    }

    private func assertV3FixtureMatchesDeployedSchema(at storeURL: URL) throws {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )
        XCTAssertEqual(
            metadata["NSStoreModelVersionChecksumKey"] as? String,
            Fixture.deployedV3Checksum
        )
    }

    private func assertV3Fixture(in context: ModelContext) throws {
        let tracks = try context.fetch(FetchDescriptor<Track>())
        let albums = try context.fetch(FetchDescriptor<Album>())
        let artists = try context.fetch(FetchDescriptor<Artist>())
        let playlists = try context.fetch(FetchDescriptor<Playlist>())
        let recentSearches = try context.fetch(FetchDescriptor<RecentSearch>())
        let sessions = try context.fetch(FetchDescriptor<ListeningSession>())

        let track = try XCTUnwrap(tracks.first)
        let album = try XCTUnwrap(albums.first)
        let artist = try XCTUnwrap(artists.first)
        let playlist = try XCTUnwrap(playlists.first)
        let session = try XCTUnwrap(sessions.first)

        XCTAssertEqual(tracks.count, 1)
        XCTAssertEqual(albums.count, 1)
        XCTAssertEqual(artists.count, 1)
        XCTAssertEqual(playlists.count, 1)
        XCTAssertEqual(recentSearches.count, 1)
        XCTAssertEqual(sessions.count, 1)

        XCTAssertEqual(track.id, Fixture.trackID)
        XCTAssertEqual(track.sourceURLBookmark, Fixture.bookmark)
        XCTAssertEqual(track.sourceURLString, Fixture.sourceURLString)
        XCTAssertEqual(track.sourceURLHash, "v3-url-hash")
        XCTAssertEqual(track.sourceBookmarkHash, "v3-bookmark-hash")
        XCTAssertEqual(track.rating, 5)
        XCTAssertEqual(track.playCount, 7)
        XCTAssertTrue(track.isFavorite)
        XCTAssertEqual(track.userTags, ["migration", "fixture"])

        XCTAssertEqual(album.id, Fixture.albumID)
        XCTAssertEqual(album.rating, 4)
        XCTAssertTrue(album.isFavorite)
        XCTAssertEqual(album.playCount, 2)
        XCTAssertEqual(album.userTags, ["v3", "fixture"])

        XCTAssertEqual(artist.id, Fixture.artistID)
        XCTAssertEqual(artist.genres, ["Ambient", "Electronic"])
        XCTAssertEqual(artist.country, "US")
        XCTAssertEqual(artist.formationYear, 1999)

        XCTAssertEqual(playlist.id, Fixture.playlistID)
        XCTAssertEqual(playlist.trackIds, [Fixture.trackID])
        XCTAssertEqual(playlist.playCount, 3)
        XCTAssertTrue(playlist.isFavorite)
        XCTAssertEqual(playlist.userTags, ["v3", "fixture"])

        XCTAssertEqual(track.albumRelation?.id, Fixture.albumID)
        XCTAssertEqual(track.artistRelation?.id, Fixture.artistID)
        XCTAssertTrue(track.playlists.contains { $0.id == Fixture.playlistID })
        XCTAssertTrue(album.tracks.contains { $0.id == Fixture.trackID })
        XCTAssertEqual(album.artistRelation?.id, Fixture.artistID)
        XCTAssertTrue(artist.albums.contains { $0.id == Fixture.albumID })
        XCTAssertTrue(artist.tracks.contains { $0.id == Fixture.trackID })
        XCTAssertTrue(playlist.tracks.contains { $0.id == Fixture.trackID })

        XCTAssertEqual(recentSearches.first?.query, "V3 Fixture")
        XCTAssertEqual(recentSearches.first?.resultCount, 1)
        XCTAssertEqual(session.id, Fixture.sessionID)
        XCTAssertEqual(session.trackId, Fixture.trackID)
        XCTAssertEqual(session.durationListened, 120)
        XCTAssertEqual(session.endedAt, Fixture.sessionStartedAt.addingTimeInterval(120))
        XCTAssertEqual(session.hourOfDay, 10)
        XCTAssertEqual(session.dayOfWeek, 3)
    }

    private func assertMigratedLibrary(in context: ModelContext) throws {
        let tracks = try context.fetch(FetchDescriptor<Track>())
        let albums = try context.fetch(FetchDescriptor<Album>())
        let artists = try context.fetch(FetchDescriptor<Artist>())
        let playlists = try context.fetch(FetchDescriptor<Playlist>())
        let recentSearches = try context.fetch(FetchDescriptor<RecentSearch>())
        let sessions = try context.fetch(FetchDescriptor<ListeningSession>())

        let track = try XCTUnwrap(tracks.first)
        let album = try XCTUnwrap(albums.first)
        let artist = try XCTUnwrap(artists.first)
        let playlist = try XCTUnwrap(playlists.first)

        XCTAssertEqual(tracks.count, 1)
        XCTAssertEqual(albums.count, 1)
        XCTAssertEqual(artists.count, 1)
        XCTAssertEqual(playlists.count, 1)
        XCTAssertEqual(recentSearches.count, 1)
        XCTAssertTrue(sessions.isEmpty)

        XCTAssertEqual(track.id, Fixture.trackID)
        XCTAssertEqual(track.title, "Fixture Track")
        XCTAssertEqual(track.sourceURLBookmark, Fixture.bookmark)
        XCTAssertEqual(track.sourceURLString, Fixture.sourceURLString)
        XCTAssertEqual(track.rating, 5)
        XCTAssertEqual(track.playCount, 7)
        XCTAssertEqual(track.userTags, ["migration", "fixture"])
        XCTAssertEqual(track.sourceURLHash, "v2-url-hash")
        XCTAssertEqual(track.sourceBookmarkHash, "v2-bookmark-hash")
        XCTAssertEqual(track.unavailableCheckCount, 0)
        XCTAssertNil(track.unavailableSince)
        XCTAssertNil(track.availabilityLastCheckedAt)
        XCTAssertTrue(track.fileAvailability.isAvailable)

        XCTAssertEqual(album.id, Fixture.albumID)
        XCTAssertEqual(artist.id, Fixture.artistID)
        XCTAssertEqual(playlist.id, Fixture.playlistID)
        XCTAssertEqual(playlist.trackIds, [Fixture.trackID])

        XCTAssertEqual(track.albumRelation?.id, Fixture.albumID)
        XCTAssertEqual(track.artistRelation?.id, Fixture.artistID)
        XCTAssertTrue(track.playlists.contains { $0.id == Fixture.playlistID })
        XCTAssertTrue(album.tracks.contains { $0.id == Fixture.trackID })
        XCTAssertEqual(album.artistRelation?.id, Fixture.artistID)
        XCTAssertTrue(artist.albums.contains { $0.id == Fixture.albumID })
        XCTAssertTrue(artist.tracks.contains { $0.id == Fixture.trackID })
        XCTAssertTrue(playlist.tracks.contains { $0.id == Fixture.trackID })

        XCTAssertEqual(recentSearches.first?.query, "Fixture")
        XCTAssertEqual(recentSearches.first?.resultCount, 1)
    }

    private func assertListeningSessionCanBePersisted(in context: ModelContext) throws {
        let session = ListeningSession(
            trackId: Fixture.trackID,
            startedAt: Fixture.sessionStartedAt,
            durationListened: 120,
            trackDuration: 245,
            completionPercentage: 120.0 / 245.0,
            wasSkipped: false,
            wasCompleted: false
        )
        session.id = Fixture.sessionID
        session.endedAt = Fixture.sessionStartedAt.addingTimeInterval(120)
        context.insert(session)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<ListeningSession>())
        let persistedSession = try XCTUnwrap(sessions.first)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(persistedSession.id, Fixture.sessionID)
        XCTAssertEqual(persistedSession.trackId, Fixture.trackID)
        XCTAssertEqual(persistedSession.durationListened, 120)
        XCTAssertEqual(persistedSession.endedAt, Fixture.sessionStartedAt.addingTimeInterval(120))
    }
}
