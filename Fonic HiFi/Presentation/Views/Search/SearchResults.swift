//
//  SearchResults.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Foundation

/// Value type containing aggregated search results
struct SearchResults: Equatable {
    let tracks: [Track]
    let albums: [Album]
    let artists: [Artist]
    let playlists: [Playlist]

    /// Initialize with search results for all content types
    init(
        tracks: [Track] = [],
        albums: [Album] = [],
        artists: [Artist] = [],
        playlists: [Playlist] = []
    ) {
        self.tracks = tracks
        self.albums = albums
        self.artists = artists
        self.playlists = playlists
    }

    /// Whether all results are empty
    var isEmpty: Bool {
        tracks.isEmpty &&
        albums.isEmpty &&
        artists.isEmpty &&
        playlists.isEmpty
    }

    /// Total number of results across all types
    var totalCount: Int {
        tracks.count + albums.count + artists.count + playlists.count
    }

    /// Check if there are results for a specific type
    var hasTrackResults: Bool { !tracks.isEmpty }
    var hasAlbumResults: Bool { !albums.isEmpty }
    var hasArtistResults: Bool { !artists.isEmpty }
    var hasPlaylistResults: Bool { !playlists.isEmpty }
}