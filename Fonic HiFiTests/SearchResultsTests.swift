@testable import Fonic_HiFi
import XCTest

final class SearchResultsTests: XCTestCase {
    func testEmptyResultsReportNoContent() {
        let results = SearchResults()

        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(results.totalCount, 0)
        XCTAssertFalse(results.hasTrackResults)
        XCTAssertFalse(results.hasAlbumResults)
        XCTAssertFalse(results.hasArtistResults)
        XCTAssertFalse(results.hasPlaylistResults)
    }

    func testResultsExposeCountsPerCategory() {
        let track = Track(url: URL(fileURLWithPath: "/tmp/track.flac"), title: "Song", artist: "Artist", album: "Album", audioFormat: "FLAC", duration: 180, sampleRate: 96_000, bitDepth: 24, channels: 2, isLossless: true)
        let album = Album(title: "Album", albumArtist: "Artist")
        let artist = Artist(name: "Artist")
        let playlist = Playlist(name: "Favorites")

        let results = SearchResults(tracks: [track], albums: [album], artists: [artist], playlists: [playlist])

        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results.totalCount, 4)
        XCTAssertTrue(results.hasTrackResults)
        XCTAssertTrue(results.hasAlbumResults)
        XCTAssertTrue(results.hasArtistResults)
        XCTAssertTrue(results.hasPlaylistResults)
    }
}
