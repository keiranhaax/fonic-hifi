@testable import Fonic_HiFi
import Foundation
import SwiftData
import XCTest

@MainActor
final class SwiftDataLibraryRepositoryTests: XCTestCase {
    func testTrackProjectionPreservesIdentityAndPlaybackMetadata() {
        let id = UUID()
        let track = Track(
            id: id,
            url: URL(fileURLWithPath: "/tmp/projection.flac"),
            title: "Projection",
            artist: "Artist",
            album: "Album",
            audioFormat: "FLAC",
            duration: 180,
            sampleRate: 96_000,
            bitDepth: 24,
            channels: 2,
            isLossless: true,
        )
        track.replayGainTrack = -4
        track.replayGainAlbum = -2
        track.isFavorite = true

        let entity = TrackEntity(track: track)
        let representation = entity.asTrackRepresentation()

        XCTAssertEqual(entity.id, id)
        XCTAssertEqual(representation.id, id)
        XCTAssertEqual(representation.replayGainTrack, -4)
        XCTAssertEqual(representation.replayGainAlbum, -2)
        XCTAssertTrue(representation.isFavorite)
    }

    func testTenThousandTrackStoreReturnsPrefetchedAlbumAndArtistCounts() async throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: storeDirectory)
        }

        let schema = Schema(SchemaV3.models)
        let configuration = ModelConfiguration(
            "RepositoryFixture",
            schema: schema,
            url: storeDirectory.appendingPathComponent("Library.store"),
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let artists = (0 ..< 50).map { index in
            Artist(name: String(format: "Artist-%03d", index))
        }
        let albums = (0 ..< 100).map { index in
            let album = Album(
                title: String(format: "Album-%03d", index),
                albumArtist: artists[index % artists.count].name
            )
            album.artistRelation = artists[index % artists.count]
            return album
        }

        artists.forEach(context.insert)
        albums.forEach(context.insert)

        for index in 0 ..< 10000 {
            let track = Track(
                url: URL(fileURLWithPath: "/tmp/repository-track-\(index).flac"),
                title: String(format: "Track-%05d", index),
                artist: artists[index % artists.count].name,
                album: albums[index % albums.count].title,
                audioFormat: "FLAC",
                duration: 180
            )
            track.artistRelation = artists[index % artists.count]
            track.albumRelation = albums[index % albums.count]
            context.insert(track)
        }
        try context.save()

        let repository = SwiftDataLibraryRepository(container: container)
        let albumPage = try await repository.albums(page: 0, pageSize: 25, searchQuery: nil)
        let artistPage = try await repository.artists(page: 0, pageSize: 25, searchQuery: nil)

        XCTAssertEqual(albumPage.items.count, 25)
        XCTAssertTrue(albumPage.hasMore)
        XCTAssertNil(albumPage.totalCount)
        XCTAssertTrue(albumPage.items.allSatisfy { $0.trackCount == 100 })

        XCTAssertEqual(artistPage.items.count, 25)
        XCTAssertTrue(artistPage.hasMore)
        XCTAssertNil(artistPage.totalCount)
        XCTAssertTrue(artistPage.items.allSatisfy { $0.trackCount == 200 })
        XCTAssertTrue(artistPage.items.allSatisfy { $0.albumCount == 2 })
    }
}
