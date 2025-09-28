import Foundation

enum LibraryFilter {
    static func filterTracks(_ tracks: [TrackEntity], query: String?) -> [TrackEntity] {
        guard let query, !query.isEmpty else { return tracks }
        return tracks.filter { entity in
            entity.title.localizedCaseInsensitiveContains(query) ||
                entity.artist.localizedCaseInsensitiveContains(query) ||
                entity.album.localizedCaseInsensitiveContains(query)
        }
    }

    static func filterAlbums(_ albums: [AlbumEntity], query: String?) -> [AlbumEntity] {
        guard let query, !query.isEmpty else { return albums }
        return albums.filter { entity in
            entity.title.localizedCaseInsensitiveContains(query) ||
                entity.albumArtist.localizedCaseInsensitiveContains(query)
        }
    }

    static func filterArtists(_ artists: [ArtistEntity], query: String?) -> [ArtistEntity] {
        guard let query, !query.isEmpty else { return artists }
        return artists.filter { entity in
            entity.name.localizedCaseInsensitiveContains(query) ||
                entity.sortName.localizedCaseInsensitiveContains(query)
        }
    }

    static func filterPlaylists(_ playlists: [PlaylistEntity], query: String?) -> [PlaylistEntity] {
        guard let query, !query.isEmpty else { return playlists }
        return playlists.filter { entity in
            entity.name.localizedCaseInsensitiveContains(query) ||
                (entity.description?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
}
