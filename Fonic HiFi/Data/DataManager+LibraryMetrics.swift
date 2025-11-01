//
//  DataManager+LibraryMetrics.swift
//  Fonic HiFi
//
//  Created by Droid on 10/07/25.
//

import Foundation
import SwiftData

// MARK: - Library Metrics & Pagination

@MainActor
public extension DataManager {
    static let defaultPageSize = 100

    func getLibraryStatistics() async throws -> LibraryStatistics {
        let now = Date()

        do {
            let aggregate = try libraryStatisticsCache.statistics(in: mainContext, now: now)

            let statistics = LibraryStatistics(
                trackCount: aggregate.trackCount,
                albumCount: aggregate.albumCount,
                artistCount: aggregate.artistCount,
                playlistCount: aggregate.playlistCount,
                totalDuration: aggregate.totalDuration,
                totalFileSize: aggregate.totalFileSize,
                losslessTrackCount: aggregate.losslessTrackCount,
                hiResTrackCount: aggregate.hiResTrackCount
            )
            return statistics
        } catch {
            logger.error("Failed to get library statistics: \(error.localizedDescription)")
            throw DataManagerError.fetchFailed(error)
        }
    }

    func fetchTracks(
        predicate: Predicate<Track>? = nil,
        sortBy: [SortDescriptor<Track>] = [SortDescriptor(\.dateAdded, order: .reverse)],
        page: Int = 0,
        pageSize: Int = defaultPageSize,
    ) async throws -> (tracks: [Track], hasMore: Bool) {
        let descriptor = FetchDescriptor<Track>(
            predicate: predicate,
            sortBy: sortBy,
        )

        let fetch = PaginatedModelFetch(
            descriptor: descriptor,
            page: page,
            pageSize: pageSize,
        )

        do {
            let result = try fetch.execute(in: mainContext)
            return (result.items, result.hasMore)
        } catch {
            logger.error("Failed to fetch tracks with pagination: \(error.localizedDescription)")
            throw DataManagerError.fetchFailed(error)
        }
    }

    func fetchAlbums(
        predicate: Predicate<Album>? = nil,
        sortBy: [SortDescriptor<Album>] = [SortDescriptor(\.title)],
        page: Int = 0,
        pageSize: Int = defaultPageSize,
    ) async throws -> (albums: [Album], hasMore: Bool) {
        let descriptor = FetchDescriptor<Album>(
            predicate: predicate,
            sortBy: sortBy,
        )

        let fetch = PaginatedModelFetch(
            descriptor: descriptor,
            page: page,
            pageSize: pageSize,
        )

        do {
            let result = try fetch.execute(in: mainContext)
            return (result.items, result.hasMore)
        } catch {
            logger.error("Failed to fetch albums with pagination: \(error.localizedDescription)")
            throw DataManagerError.fetchFailed(error)
        }
    }

    func fetchAllTracksInBatches(
        batchSize: Int = defaultPageSize,
    ) async throws -> [Track] {
        var allTracks: [Track] = []
        var page = 0
        var hasMore = true

        while hasMore {
            let result = try await fetchTracks(page: page, pageSize: batchSize)
            allTracks.append(contentsOf: result.tracks)
            hasMore = result.hasMore
            page += 1
        }

        return allTracks
    }
}

// MARK: - Supporting Types

public struct LibraryStatistics: Sendable {
    public let trackCount: Int
    public let albumCount: Int
    public let artistCount: Int
    public let playlistCount: Int
    public let totalDuration: TimeInterval
    public let totalFileSize: Int64
    public let losslessTrackCount: Int
    public let hiResTrackCount: Int

    public var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }

    public var formattedTotalFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalFileSize)
    }

    public var losslessPercentage: Double {
        guard trackCount > 0 else { return 0 }
        return Double(losslessTrackCount) / Double(trackCount) * 100
    }

    public var hiResPercentage: Double {
        guard trackCount > 0 else { return 0 }
        return Double(hiResTrackCount) / Double(trackCount) * 100
    }
}
