//
//  LibraryStatisticsAggregator.swift
//  Fonic HiFi
//
//  Created by Droid on 10/09/25.
//

import Foundation
import SwiftData

struct LibraryStatisticsAggregate: Sendable {
    let trackCount: Int
    let albumCount: Int
    let artistCount: Int
    let playlistCount: Int
    let totalDuration: TimeInterval
    let totalFileSize: Int64
    let losslessTrackCount: Int
    let hiResTrackCount: Int
}

struct TrackAggregate: Sendable {
    var count: Int = 0
    var totalDuration: TimeInterval = 0
    var totalFileSize: Int64 = 0
    var losslessCount: Int = 0
    var hiResCount: Int = 0
}

struct LibraryStatisticsAggregator: Sendable {
    let batchSize: Int

    init(batchSize: Int = 512) {
        self.batchSize = batchSize
    }

    func compute(in context: ModelContext) throws -> LibraryStatisticsAggregate {
        let trackAggregate = try aggregateTracks(in: context)
        let albumCount = try countEntities(Album.self, in: context)
        let artistCount = try countEntities(Artist.self, in: context)
        let playlistCount = try countEntities(Playlist.self, in: context)

        return LibraryStatisticsAggregate(
            trackCount: trackAggregate.count,
            albumCount: albumCount,
            artistCount: artistCount,
            playlistCount: playlistCount,
            totalDuration: trackAggregate.totalDuration,
            totalFileSize: trackAggregate.totalFileSize,
            losslessTrackCount: trackAggregate.losslessCount,
            hiResTrackCount: trackAggregate.hiResCount
        )
    }
}

struct LibraryStatisticsCache: Sendable {
    private var cache: TimedCacheEntry<LibraryStatisticsAggregate>?
    private let aggregator: LibraryStatisticsAggregator
    private(set) var ttl: TimeInterval
    private(set) var computationCount = 0

    init(ttl: TimeInterval = 5, aggregator: LibraryStatisticsAggregator = .init()) {
        self.ttl = ttl
        self.aggregator = aggregator
    }

    mutating func statistics(in context: ModelContext, now: Date = Date()) throws -> LibraryStatisticsAggregate {
        if let cache, cache.isValid(now: now) {
            return cache.value
        }

        let aggregate = try aggregator.compute(in: context)
        computationCount += 1
        cache = TimedCacheEntry(value: aggregate, ttl: ttl, now: now)
        return aggregate
    }

    mutating func invalidate() {
        cache = nil
    }

    mutating func updateTTL(_ ttl: TimeInterval) {
        self.ttl = ttl
        cache = nil
    }
}

private extension LibraryStatisticsAggregator {
    func aggregateTracks(in context: ModelContext) throws -> TrackAggregate {
        var stats = TrackAggregate()
        var offset = 0

        let baseDescriptor = FetchDescriptor<Track>(
            sortBy: [SortDescriptor(\.id)]
        )

        while true {
            var descriptor = baseDescriptor
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = batchSize

            let batch = try context.fetch(descriptor)
            if batch.isEmpty { break }

            stats.count += batch.count
            for track in batch {
                stats.totalDuration += track.duration
                stats.totalFileSize += track.fileSize

                if track.isLossless {
                    stats.losslessCount += 1
                    if track.sampleRate > 48_000 || track.bitDepth > 16 {
                        stats.hiResCount += 1
                    }
                }
            }

            if batch.count < batchSize {
                break
            }

            offset += batch.count
        }

        return stats
    }

    func countEntities<Model: PersistentModel>(
        _ model: Model.Type,
        in context: ModelContext
    ) throws -> Int {
        var total = 0
        var offset = 0

        while true {
            var descriptor = FetchDescriptor<Model>(sortBy: [SortDescriptor(\.id)])
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = batchSize

            let batch = try context.fetch(descriptor)
            total += batch.count

            if batch.count < batchSize { break }

            offset += batch.count
        }

        return total
    }
}
