@testable import Fonic_HiFi
import XCTest

@MainActor
final class LibraryFilterTests: XCTestCase {
    private let sampleDate = Date()

    func testFilterTracksMatchesMultipleFields() {
        let tracks = [
            makeTrackEntity(title: "Moonlight Sonata", artist: "Beethoven", album: "Classics"),
            makeTrackEntity(title: "Electric Dreams", artist: "Synthwave Artist", album: "Neon Nights")
        ]

        let filteredByTitle = LibraryFilter.filterTracks(tracks, query: "moonlight")
        XCTAssertEqual(filteredByTitle.count, 1)
        XCTAssertEqual(filteredByTitle.first?.title, "Moonlight Sonata")

        let filteredByArtist = LibraryFilter.filterTracks(tracks, query: "Synthwave")
        XCTAssertEqual(filteredByArtist.count, 1)
        XCTAssertEqual(filteredByArtist.first?.artist, "Synthwave Artist")

        let filteredByAlbum = LibraryFilter.filterTracks(tracks, query: "NEON")
        XCTAssertEqual(filteredByAlbum.count, 1)
        XCTAssertEqual(filteredByAlbum.first?.album, "Neon Nights")
    }

    func testFilterAlbumsAppliesQuery() {
        let albums = [
            AlbumEntity(id: UUID(), title: "Classical Essentials", albumArtist: "Various Artists", trackCount: 20, artworkSha: nil, year: 2024, dateAdded: sampleDate),
            AlbumEntity(id: UUID(), title: "Neon Nights", albumArtist: "Synthwave Artist", trackCount: 12, artworkSha: nil, year: 2023, dateAdded: sampleDate)
        ]

        let filtered = LibraryFilter.filterAlbums(albums, query: "synthwave")
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.title, "Neon Nights")

        let noFilter = LibraryFilter.filterAlbums(albums, query: nil)
        XCTAssertEqual(noFilter.count, albums.count)
    }

    func testFilterArtistsMatchesNameOrSortName() {
        let artists = [
            ArtistEntity(id: UUID(), name: "Daft Punk", sortName: "punk, daft", albumCount: 5, trackCount: 60),
            ArtistEntity(id: UUID(), name: "Ólafur Arnalds", sortName: "arnalds, olafur", albumCount: 8, trackCount: 80)
        ]

        let filteredByName = LibraryFilter.filterArtists(artists, query: "olafur")
        XCTAssertEqual(filteredByName.count, 1)
        XCTAssertEqual(filteredByName.first?.name, "Ólafur Arnalds")

        let filteredBySortName = LibraryFilter.filterArtists(artists, query: "PUNK")
        XCTAssertEqual(filteredBySortName.count, 1)
        XCTAssertEqual(filteredBySortName.first?.name, "Daft Punk")
    }

    func testFilterPlaylistsMatchesNameOrDescription() {
        let playlists = [
            PlaylistEntity(
                id: UUID(),
                name: "Morning Acoustic",
                description: "Gentle acoustic tracks for mornings",
                trackCount: 25
            ),
            PlaylistEntity(
                id: UUID(),
                name: "Workout Boost",
                description: "High energy tracks to power your workout",
                trackCount: 40
            )
        ]

        let filteredByName = LibraryFilter.filterPlaylists(playlists, query: "workout")
        XCTAssertEqual(filteredByName.count, 1)
        XCTAssertEqual(filteredByName.first?.name, "Workout Boost")

        let filteredByDescription = LibraryFilter.filterPlaylists(playlists, query: "gentle")
        XCTAssertEqual(filteredByDescription.count, 1)
        XCTAssertEqual(filteredByDescription.first?.name, "Morning Acoustic")

        let noFilter = LibraryFilter.filterPlaylists(playlists, query: "")
        XCTAssertEqual(noFilter.count, playlists.count)
    }

    // MARK: - Helpers

    private func makeTrackEntity(title: String, artist: String, album: String) -> TrackEntity {
        TrackEntity(
            id: UUID(),
            title: title,
            artist: artist,
            album: album,
            albumArtist: artist,
            duration: 300,
            trackNumber: 1,
            discNumber: 1,
            genre: "Genre",
            year: 2024,
            audioFormat: "FLAC",
            artworkSha: nil,
            fileURL: URL(fileURLWithPath: "/music/\(title).flac"),
            fileSize: 10_000_000,
            bitDepth: 24,
            sampleRate: 96_000,
            channels: 2,
            bitrate: 3_000_000,
            isLossless: true,
            dateAdded: sampleDate
        )
    }
}
