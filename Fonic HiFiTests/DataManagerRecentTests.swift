@testable import Fonic_HiFi
import Foundation
import SwiftData
import XCTest

@MainActor
final class DataManagerRecentTests: XCTestCase {
    private var container: ModelContainer!
    private var manager: DataManager!
    private var temporaryDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()

        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        let schema = Schema([
            Track.self,
            Album.self,
            Artist.self,
            Playlist.self,
            RecentSearch.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        manager = DataManager(container: container, isFallback: false)
    }

    override func tearDown() async throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        manager = nil
        container = nil
        temporaryDirectory = nil
        try await super.tearDown()
    }

    func testGetRecentlyAddedTracksReturnsNewestFirst() async throws {
        let baseDate = Date()
        for index in 0..<5 {
            try insertTrack(
                name: "Track-\(index)",
                dateAdded: baseDate.addingTimeInterval(Double(index) * 60)
            )
        }
        try manager.mainContext.save()

        let recent = try await manager.getRecentlyAddedTracks(limit: 3)
        XCTAssertEqual(recent.count, 3)
        XCTAssertEqual(recent.first?.title, "Track-4")
        XCTAssertEqual(recent.map(\.title), ["Track-4", "Track-3", "Track-2"])
    }

    func testGetRecentlyPlayedTracksFiltersByPlaybackDate() async throws {
        let baseDate = Date()

        try insertTrack(
            name: "NeverPlayed",
            dateAdded: baseDate,
            lastPlayed: nil
        )

        try insertTrack(
            name: "Yesterday",
            dateAdded: baseDate,
            lastPlayed: baseDate.addingTimeInterval(-86_400)
        )

        try insertTrack(
            name: "Today",
            dateAdded: baseDate,
            lastPlayed: baseDate
        )

        try manager.mainContext.save()

        let played = try await manager.getRecentlyPlayedTracks(limit: 5)
        XCTAssertEqual(played.count, 2)
        XCTAssertEqual(played.map(\.title), ["Today", "Yesterday"])
    }

    func testRecentSearchDelegationFlowsThroughActor() async throws {
        try await manager.addRecentSearch("ambient")
        try await manager.addRecentSearch("jazz")
        try await manager.updateSearchResultCount(query: "jazz", count: 8)

        var searches = try await manager.getRecentSearches(limit: 10)
        XCTAssertEqual(searches.count, 2)
        XCTAssertEqual(searches.first?.query, "jazz")
        XCTAssertEqual(searches.first?.resultCount, 8)

        try await manager.clearRecentSearches()
        searches = try await manager.getRecentSearches(limit: 5)
        XCTAssertTrue(searches.isEmpty)
    }

    func testGetAllArtistsReturnsSortedByName() async throws {
        try insertArtist(name: "Zeppelin")
        try insertArtist(name: "ABBA")
        try insertArtist(name: "Metallica")
        try manager.mainContext.save()

        let artists = try await manager.getAllArtists(limit: 10)
        XCTAssertEqual(artists.count, 3)
        XCTAssertEqual(artists.map { $0.name }, ["ABBA", "Metallica", "Zeppelin"])
    }

    func testGetUniqueGenresReturnsDistinctGenresSorted() async throws {
        try insertTrack(name: "Track1", dateAdded: Date(), genre: "Rock")
        try insertTrack(name: "Track2", dateAdded: Date(), genre: "Jazz")
        try insertTrack(name: "Track3", dateAdded: Date(), genre: "Rock") // Duplicate
        try insertTrack(name: "Track4", dateAdded: Date(), genre: "Electronic")
        try insertTrack(name: "Track5", dateAdded: Date(), genre: nil) // No genre
        try manager.mainContext.save()

        let genres = try await manager.getUniqueGenres()
        XCTAssertEqual(genres, ["Electronic", "Jazz", "Rock"])
    }

    func testGetAllAlbumsReturnsSortedByDateAdded() async throws {
        let baseDate = Date()
        try insertAlbum(title: "Old Album", dateAdded: baseDate.addingTimeInterval(-3600))
        try insertAlbum(title: "New Album", dateAdded: baseDate)
        try insertAlbum(title: "Mid Album", dateAdded: baseDate.addingTimeInterval(-1800))
        try manager.mainContext.save()

        let albums = try await manager.getAllAlbums(limit: 10)
        XCTAssertEqual(albums.count, 3)
        XCTAssertEqual(albums.map { $0.title }, ["New Album", "Mid Album", "Old Album"])
    }

    private func insertAlbum(title: String, dateAdded: Date = Date()) throws {
        let album = Album(title: title, albumArtist: "Artist")
        album.dateAdded = dateAdded
        manager.mainContext.insert(album)
    }

    private func insertArtist(name: String) throws {
        let artist = Artist(name: name)
        manager.mainContext.insert(artist)
    }

    private func insertTrack(
        name: String,
        dateAdded: Date,
        lastPlayed: Date? = nil,
        genre: String? = nil
    ) throws {
        let url = temporaryDirectory.appendingPathComponent("\(name).flac")
        let data = Data(repeating: 0xAB, count: 2048)
        try data.write(to: url)

        let track = Track(
            url: url,
            title: name,
            artist: "Artist",
            album: "Album",
            audioFormat: "FLAC",
            duration: 180,
            sampleRate: 96_000,
            bitDepth: 24,
            channels: 2,
            isLossless: true
        )

        track.dateAdded = dateAdded
        track.lastPlayed = lastPlayed
        track.genre = genre
        manager.mainContext.insert(track)
    }
}
