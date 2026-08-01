@testable import Fonic_HiFi
import Foundation
import SwiftData
import XCTest

@MainActor
final class DataManagerPaginationTests: XCTestCase {
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(SchemaV3.models)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none,
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeDataManager(container: ModelContainer) async -> DataManager {
        await MainActor.run {
            DataManager(container: container, isFallback: false)
        }
    }

    func testFetchTracksUsesOffsetPagination() async throws {
        let container = try makeInMemoryContainer()
        let dataManager = await makeDataManager(container: container)

        try await MainActor.run {
            for index in 0 ..< 120 {
                let track = Track(
                    url: URL(fileURLWithPath: "/tmp/track-\(index).flac"),
                    title: String(format: "Track-%03d", index),
                    artist: "Artist-\(index % 5)",
                    album: "Album-\(index % 3)",
                    audioFormat: "FLAC",
                    duration: TimeInterval(index),
                )
                track.dateAdded = Date().addingTimeInterval(TimeInterval(index))
                dataManager.mainContext.insert(track)
            }
            try dataManager.mainContext.save()
        }

        let firstPage = try await dataManager.fetchTracks(
            predicate: nil,
            sortBy: [SortDescriptor(\.title)],
            page: 0,
            pageSize: 25,
        )
        XCTAssertEqual(firstPage.tracks.count, 25)
        XCTAssertTrue(firstPage.hasMore)
        XCTAssertEqual(firstPage.tracks.first?.title, "Track-000")
        XCTAssertEqual(firstPage.tracks.last?.title, "Track-024")

        let secondPage = try await dataManager.fetchTracks(
            predicate: nil,
            sortBy: [SortDescriptor(\.title)],
            page: 1,
            pageSize: 25,
        )
        XCTAssertEqual(secondPage.tracks.count, 25)
        XCTAssertTrue(secondPage.hasMore)
        XCTAssertEqual(secondPage.tracks.first?.title, "Track-025")
        XCTAssertEqual(secondPage.tracks.last?.title, "Track-049")

        let finalPage = try await dataManager.fetchTracks(
            predicate: nil,
            sortBy: [SortDescriptor(\.title)],
            page: 4,
            pageSize: 25,
        )
        XCTAssertEqual(finalPage.tracks.count, 20)
        XCTAssertFalse(finalPage.hasMore)
        XCTAssertEqual(finalPage.tracks.first?.title, "Track-100")
        XCTAssertEqual(finalPage.tracks.last?.title, "Track-119")
    }

    func testSearchArtistsRespectsPagination() async throws {
        let container = try makeInMemoryContainer()
        let dataManager = await makeDataManager(container: container)

        try await MainActor.run {
            for index in 0 ..< 60 {
                let artist = Artist(name: String(format: "Artist-%03d", index))
                dataManager.mainContext.insert(artist)
            }
            try dataManager.mainContext.save()
        }

        let firstPage = try await dataManager.searchArtists("Artist", page: 0, pageSize: 15)
        XCTAssertEqual(firstPage.artists.count, 15)
        XCTAssertTrue(firstPage.hasMore)
        XCTAssertEqual(firstPage.artists.first?.name, "Artist-000")
        XCTAssertEqual(firstPage.artists.last?.name, "Artist-014")

        let thirdPage = try await dataManager.searchArtists("Artist", page: 2, pageSize: 15)
        XCTAssertEqual(thirdPage.artists.count, 15)
        XCTAssertTrue(thirdPage.hasMore)
        XCTAssertEqual(thirdPage.artists.first?.name, "Artist-030")
        XCTAssertEqual(thirdPage.artists.last?.name, "Artist-044")

        let finalPage = try await dataManager.searchArtists("Artist", page: 3, pageSize: 15)
        XCTAssertEqual(finalPage.artists.count, 15)
        XCTAssertFalse(finalPage.hasMore)
        XCTAssertEqual(finalPage.artists.first?.name, "Artist-045")
        XCTAssertEqual(finalPage.artists.last?.name, "Artist-059")
    }

    func testSearchPlaylistsRespectsPagination() async throws {
        let container = try makeInMemoryContainer()
        let dataManager = await makeDataManager(container: container)

        try await MainActor.run {
            for index in 0 ..< 40 {
                let playlist = Playlist(name: String(format: "Playlist-%03d", index))
                dataManager.mainContext.insert(playlist)
            }
            try dataManager.mainContext.save()
        }

        let firstPage = try await dataManager.searchPlaylists("Playlist", page: 0, pageSize: 10)
        XCTAssertEqual(firstPage.playlists.count, 10)
        XCTAssertTrue(firstPage.hasMore)
        XCTAssertEqual(firstPage.playlists.first?.name, "Playlist-000")
        XCTAssertEqual(firstPage.playlists.last?.name, "Playlist-009")

        let middlePage = try await dataManager.searchPlaylists("Playlist", page: 2, pageSize: 10)
        XCTAssertEqual(middlePage.playlists.count, 10)
        XCTAssertTrue(middlePage.hasMore)
        XCTAssertEqual(middlePage.playlists.first?.name, "Playlist-020")
        XCTAssertEqual(middlePage.playlists.last?.name, "Playlist-029")

        let finalPage = try await dataManager.searchPlaylists("Playlist", page: 3, pageSize: 10)
        XCTAssertEqual(finalPage.playlists.count, 10)
        XCTAssertFalse(finalPage.hasMore)
        XCTAssertEqual(finalPage.playlists.first?.name, "Playlist-030")
        XCTAssertEqual(finalPage.playlists.last?.name, "Playlist-039")
    }

    func testCompleteTrackSearchHasNoHiddenResultCap() async throws {
        let container = try makeInMemoryContainer()
        let dataManager = await makeDataManager(container: container)

        try await MainActor.run {
            for index in 0 ..< 125 {
                let track = Track(
                    url: URL(fileURLWithPath: "/tmp/search-track-\(index).flac"),
                    title: String(format: "Needle-%03d", index),
                    artist: "Search Artist",
                    album: "Search Album",
                    audioFormat: "FLAC",
                    duration: 180,
                )
                dataManager.mainContext.insert(track)
            }
            try dataManager.mainContext.save()
        }

        let matches: [Track] = try await dataManager.searchTracks("Needle")

        XCTAssertEqual(matches.count, 125)
        XCTAssertEqual(matches.first?.title, "Needle-000")
        XCTAssertEqual(matches.last?.title, "Needle-124")
    }

    func testLibraryInvalidationAdvancesOneRevision() async throws {
        let container = try makeInMemoryContainer()
        let dataManager = await makeDataManager(container: container)

        XCTAssertEqual(dataManager.libraryRevision, 0)

        dataManager.invalidateLibrary()

        XCTAssertEqual(dataManager.libraryRevision, 1)
    }
}
