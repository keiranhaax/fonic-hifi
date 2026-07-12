import XCTest

@testable import Fonic_HiFi

@MainActor
final class DataManagerSearchAggregationTests: XCTestCase {
    func testSearchTracksFindsSavedTitle() async throws {
        let manager = try XCTUnwrap(DataManager.makePreviewDataManager())
        let track = Track(
            url: FileManager.default.temporaryDirectory.appendingPathComponent("semantic-search.wav"),
            title: "Semantic Track",
            artist: "Semantic Artist",
            album: "Semantic Album",
            audioFormat: "WAV"
        )
        let artist = Artist(name: "Semantic Artist")
        let album = Album(title: "Semantic Album", albumArtist: "Semantic Artist")
        let playlist = Playlist(name: "Semantic Playlist")
        track.artistRelation = artist
        track.albumRelation = album
        playlist.addTrack(track.id)
        playlist.tracks = [track]
        manager.mainContext.insert(track)
        manager.mainContext.insert(artist)
        manager.mainContext.insert(album)
        manager.mainContext.insert(playlist)
        try manager.mainContext.save()

        let results = SearchResults(
            tracks: try await manager.searchTracks("Semantic"),
            albums: try await manager.searchAlbums("Semantic"),
            artists: try await manager.searchArtists("Semantic"),
            playlists: try await manager.searchPlaylists("Semantic")
        )

        XCTAssertEqual(results.tracks.map(\.title), ["Semantic Track"])
        XCTAssertEqual(results.albums.map(\.title), ["Semantic Album"])
        XCTAssertEqual(results.artists.map(\.name), ["Semantic Artist"])
        XCTAssertEqual(results.playlists.map(\.name), ["Semantic Playlist"])
    }
}
