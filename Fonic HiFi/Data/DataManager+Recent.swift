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

    func getUniqueGenres() async throws -> [String] {
        let descriptor = FetchDescriptor<Track>()

        do {
            let tracks = try mainContext.fetch(descriptor)
            let genres = Set(tracks.compactMap(\.genre))
            return genres.sorted()
        } catch {
            logger.error("Failed to get unique genres: \(error.localizedDescription)")
            throw DataManagerError.fetchFailed(error)
        }
    }

    func getAllAlbums(limit: Int = 50) async throws -> [Album] {
        var descriptor = FetchDescriptor<Album>(
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        do {
            return try mainContext.fetch(descriptor)
        } catch {
            logger.error("Failed to get albums: \(error.localizedDescription)")
            throw DataManagerError.fetchFailed(error)
        }
    }

    // MARK: - Listening History

    /// Get tracks with recent incomplete sessions for "Continue Listening"
    /// - Parameter limit: Maximum number of tracks to return
    /// - Returns: Array of tracks that were recently started but not completed
    func getContinueListeningTracks(limit: Int = 3) async throws -> [Track] {
        // Get recent sessions that weren't completed
        let sessions = try await trackDataActor.getListeningSessions(limit: 50)

        // Filter to sessions that weren't completed and have >10% but <90% progress
        let incompleteSessionTrackIds = Array(sessions
            .filter { !$0.wasCompleted && $0.completionPercentage > 0.1 && $0.completionPercentage < 0.9 }
            .prefix(limit)
            .map { $0.trackId })

        // Fetch the actual tracks using mainContext (already on MainActor)
        return try fetchTracks(by: incompleteSessionTrackIds)
    }

    /// Get neglected tracks for "Rediscover" section
    /// - Parameter limit: Maximum number of tracks to return
    /// - Returns: Array of tracks that user knows but hasn't played recently
    func getRediscoverTracks(limit: Int = 10) async throws -> [Track] {
        let neglectedIds = try await trackDataActor.getNeglectedTrackIds(
            daysSinceLastPlay: 30,
            minimumPlayCount: 2,
            limit: limit
        )

        // Fetch the actual tracks using mainContext (already on MainActor)
        return try fetchTracks(by: neglectedIds)
    }

    /// Helper to fetch tracks by UUIDs using mainContext
    private func fetchTracks(by ids: [UUID]) throws -> [Track] {
        guard !ids.isEmpty else { return [] }

        let descriptor = FetchDescriptor<Track>(
            predicate: #Predicate<Track> { track in
                ids.contains(track.id)
            }
        )

        let allTracks = try mainContext.fetch(descriptor)

        // Preserve order from original IDs
        var trackMap: [UUID: Track] = [:]
        for track in allTracks {
            trackMap[track.id] = track
        }

        return ids.compactMap { trackMap[$0] }
    }
}
