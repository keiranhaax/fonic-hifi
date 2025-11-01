//
//  DataManager+Search.swift
//  Fonic HiFi
//
//  Created by Droid on 10/07/25.
//

import Foundation
import SwiftData

@MainActor
public extension DataManager {
    func searchTracks(
        _ query: String,
        page: Int = 0,
        pageSize: Int = defaultPageSize,
    ) async throws -> (tracks: [Track], hasMore: Bool) {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return ([], false) }

        let predicate = #Predicate<Track> { track in
            track.title.localizedStandardContains(searchQuery) ||
                track.artist.localizedStandardContains(searchQuery) ||
                track.album.localizedStandardContains(searchQuery) ||
                (track.albumArtist?.localizedStandardContains(searchQuery) ?? false) ||
                (track.genre?.localizedStandardContains(searchQuery) ?? false)
        }

        return try await fetchTracks(
            predicate: predicate,
            sortBy: [SortDescriptor(\.title)],
            page: page,
            pageSize: pageSize,
        )
    }

    func searchTracks(_ query: String, limit: Int = 100) async throws -> [Track] {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return [] }

        var descriptor = FetchDescriptor<Track>(
            predicate: #Predicate<Track> { track in
                track.title.localizedStandardContains(searchQuery) ||
                    track.artist.localizedStandardContains(searchQuery) ||
                    track.album.localizedStandardContains(searchQuery) ||
                    (track.albumArtist?.localizedStandardContains(searchQuery) ?? false) ||
                    (track.genre?.localizedStandardContains(searchQuery) ?? false)
            },
            sortBy: [SortDescriptor(\.title)],
        )
        descriptor.fetchLimit = limit

        do {
            return try mainContext.fetch(descriptor)
        } catch {
            logger.error("Failed to search tracks: \(error.localizedDescription)")
            throw DataManagerError.searchFailed(error)
        }
    }

    func searchAlbums(
        _ query: String,
        page: Int = 0,
        pageSize: Int = defaultPageSize,
    ) async throws -> (albums: [Album], hasMore: Bool) {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return ([], false) }

        let predicate = #Predicate<Album> { album in
            album.title.localizedStandardContains(searchQuery) ||
                album.albumArtist.localizedStandardContains(searchQuery)
        }

        return try await fetchAlbums(
            predicate: predicate,
            sortBy: [SortDescriptor(\.title)],
            page: page,
            pageSize: pageSize,
        )
    }

    func searchAlbums(_ query: String, limit: Int = 50) async throws -> [Album] {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return [] }

        var descriptor = FetchDescriptor<Album>(
            predicate: #Predicate<Album> { album in
                album.title.localizedStandardContains(searchQuery) ||
                    album.albumArtist.localizedStandardContains(searchQuery)
            },
            sortBy: [SortDescriptor(\.title)],
        )
        descriptor.fetchLimit = limit

        do {
            return try mainContext.fetch(descriptor)
        } catch {
            logger.error("Failed to search albums: \(error.localizedDescription)")
            throw DataManagerError.searchFailed(error)
        }
    }

    func searchArtists(
        _ query: String,
        page: Int = 0,
        pageSize: Int = defaultPageSize,
    ) async throws -> (artists: [Artist], hasMore: Bool) {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return ([], false) }

        let descriptor = FetchDescriptor<Artist>(
            predicate: #Predicate<Artist> { artist in
                artist.name.localizedStandardContains(searchQuery) ||
                    artist.sortName.localizedStandardContains(searchQuery)
            },
            sortBy: [SortDescriptor(\.sortName)],
        )

        do {
            let fetch = PaginatedModelFetch(
                descriptor: descriptor,
                page: page,
                pageSize: pageSize,
            )
            let result = try fetch.execute(in: mainContext)
            return (result.items, result.hasMore)
        } catch {
            logger.error("Failed to search artists with pagination: \(error.localizedDescription)")
            throw DataManagerError.searchFailed(error)
        }
    }

    func searchArtists(_ query: String, limit: Int = 50) async throws -> [Artist] {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return [] }

        var descriptor = FetchDescriptor<Artist>(
            predicate: #Predicate<Artist> { artist in
                artist.name.localizedStandardContains(searchQuery) ||
                    artist.sortName.localizedStandardContains(searchQuery)
            },
            sortBy: [SortDescriptor(\.sortName)],
        )
        descriptor.fetchLimit = limit

        do {
            return try mainContext.fetch(descriptor)
        } catch {
            logger.error("Failed to search artists: \(error.localizedDescription)")
            throw DataManagerError.searchFailed(error)
        }
    }

    func searchPlaylists(
        _ query: String,
        page: Int = 0,
        pageSize: Int = defaultPageSize,
    ) async throws -> (playlists: [Playlist], hasMore: Bool) {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return ([], false) }

        let descriptor = FetchDescriptor<Playlist>(
            predicate: #Predicate<Playlist> { playlist in
                playlist.name.localizedStandardContains(searchQuery) ||
                    playlist.playlistDescription?.localizedStandardContains(searchQuery) ?? false
            },
            sortBy: [SortDescriptor(\.name)],
        )

        do {
            let fetch = PaginatedModelFetch(
                descriptor: descriptor,
                page: page,
                pageSize: pageSize,
            )
            let result = try fetch.execute(in: mainContext)
            return (result.items, result.hasMore)
        } catch {
            logger.error("Failed to search playlists with pagination: \(error.localizedDescription)")
            throw DataManagerError.searchFailed(error)
        }
    }

    func searchPlaylists(_ query: String, limit: Int = 50) async throws -> [Playlist] {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return [] }

        var descriptor = FetchDescriptor<Playlist>(
            predicate: #Predicate<Playlist> { playlist in
                playlist.name.localizedStandardContains(searchQuery) ||
                    playlist.playlistDescription?.localizedStandardContains(searchQuery) ?? false
            },
            sortBy: [SortDescriptor(\.name)],
        )
        descriptor.fetchLimit = limit

        do {
            return try mainContext.fetch(descriptor)
        } catch {
            logger.error("Failed to search playlists: \(error.localizedDescription)")
            throw DataManagerError.searchFailed(error)
        }
    }
}
