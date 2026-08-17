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

    func searchTracks(_ query: String) async throws -> [Track] {
        try await collectAllSearchPages { page, pageSize in
            let result = try await searchTracks(query, page: page, pageSize: pageSize)
            return (result.tracks, result.hasMore)
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

    func searchAlbums(_ query: String) async throws -> [Album] {
        try await collectAllSearchPages { page, pageSize in
            let result = try await searchAlbums(query, page: page, pageSize: pageSize)
            return (result.albums, result.hasMore)
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
            logger.error("Failed to search artists with pagination: \(error.localizedDescription, privacy: .private)")
            throw DataManagerError.searchFailed(error)
        }
    }

    func searchArtists(_ query: String) async throws -> [Artist] {
        try await collectAllSearchPages { page, pageSize in
            let result = try await searchArtists(query, page: page, pageSize: pageSize)
            return (result.artists, result.hasMore)
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
            logger.error("Failed to search playlists with pagination: \(error.localizedDescription, privacy: .private)")
            throw DataManagerError.searchFailed(error)
        }
    }

    func searchPlaylists(_ query: String) async throws -> [Playlist] {
        try await collectAllSearchPages { page, pageSize in
            let result = try await searchPlaylists(query, page: page, pageSize: pageSize)
            return (result.playlists, result.hasMore)
        }
    }

    private func collectAllSearchPages<Model>(
        pageSize: Int = defaultPageSize,
        loadPage: (_ page: Int, _ pageSize: Int) async throws -> (items: [Model], hasMore: Bool),
    ) async throws -> [Model] {
        var allItems: [Model] = []
        var page = 0
        var hasMore = true

        while hasMore {
            try Task.checkCancellation()
            let result = try await loadPage(page, pageSize)
            allItems.append(contentsOf: result.items)
            hasMore = result.hasMore
            page += 1
        }

        return allItems
    }
}
