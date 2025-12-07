//
//  DataManager+Recent.swift
//  Fonic HiFi
//
//  Created by Droid on 10/07/25.
//

import Foundation
import SwiftData

@MainActor
public extension DataManager {
    func addRecentSearch(_ query: String) async throws {
        try await recentSearchesActor.addSearch(query)
    }

    func getRecentSearches(limit: Int = 10) async throws -> [RecentSearchData] {
        try await recentSearchesActor.getRecentSearches(limit: limit)
    }

    func clearRecentSearches() async throws {
        try await recentSearchesActor.clearAllSearches()
    }

    func updateSearchResultCount(query: String, count: Int) async throws {
        try await recentSearchesActor.updateResultCount(for: query, count: count)
    }

    func getRecentlyAddedTracks(limit: Int = 50) async throws -> [Track] {
        var descriptor = FetchDescriptor<Track>(
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)],
        )
        descriptor.fetchLimit = limit

        do {
            return try mainContext.fetch(descriptor)
        } catch {
            logger.error("Failed to get recently added tracks: \(error.localizedDescription)")
            throw DataManagerError.fetchFailed(error)
        }
    }

    func getRecentlyPlayedTracks(limit: Int = 50) async throws -> [Track] {
        var descriptor = FetchDescriptor<Track>(
            predicate: #Predicate<Track> { track in
                track.lastPlayed != nil
            },
            sortBy: [SortDescriptor(\.lastPlayed, order: .reverse)],
        )
        descriptor.fetchLimit = limit

        do {
            return try mainContext.fetch(descriptor)
        } catch {
            logger.error("Failed to get recently played tracks: \(error.localizedDescription)")
            throw DataManagerError.fetchFailed(error)
        }
    }

    func getMostListenedTracks(limit: Int = 50) async throws -> [Track] {
        var descriptor = FetchDescriptor<Track>(
            predicate: #Predicate<Track> { track in
                track.playCount > 0
            },
            sortBy: [SortDescriptor(\.playCount, order: .reverse)],
        )
        descriptor.fetchLimit = limit

        do {
            return try mainContext.fetch(descriptor)
        } catch {
            logger.error("Failed to get most listened tracks: \(error.localizedDescription)")
            throw DataManagerError.fetchFailed(error)
        }
    }

    func getFavoriteAlbums(limit: Int = 50) async throws -> [Album] {
        var descriptor = FetchDescriptor<Album>(
            predicate: #Predicate<Album> { album in
                album.isFavorite == true
            },
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)],
        )
        descriptor.fetchLimit = limit

        do {
            return try mainContext.fetch(descriptor)
        } catch {
            logger.error("Failed to get favorite albums: \(error.localizedDescription)")
            throw DataManagerError.fetchFailed(error)
        }
    }

    func getAllArtists(limit: Int = 50) async throws -> [Artist] {
        var descriptor = FetchDescriptor<Artist>(
            sortBy: [SortDescriptor(\.sortName, order: .forward)]
        )
        descriptor.fetchLimit = limit

        do {
            return try mainContext.fetch(descriptor)
        } catch {
            logger.error("Failed to get artists: \(error.localizedDescription)")
            throw DataManagerError.fetchFailed(error)
        }
    }
}
