//
//  TrackCache.swift
//  Fonic HiFi
//
//  Created by Claude on 9/26/25.
//

import Foundation
import os.log

/// LRU cache for track data with actor isolation
public actor TrackCache {
    // MARK: - Types

    /// Simplified track data for cache storage
    public struct TrackCacheData: Sendable {
        public let id: UUID
        public let title: String
        public let artist: String
        public let album: String
        public let duration: TimeInterval
        public let url: URL
        public let fileSize: Int64

        public init(
            id: UUID,
            title: String,
            artist: String,
            album: String,
            duration: TimeInterval,
            url: URL,
            fileSize: Int64,
        ) {
            self.id = id
            self.title = title
            self.artist = artist
            self.album = album
            self.duration = duration
            self.url = url
            self.fileSize = fileSize
        }
    }

    struct CacheEntry: Sendable {
        let trackData: TrackCacheData
        var lastAccessed: Date
        var accessCount: Int
    }

    // MARK: - Properties

    private var cache: [UUID: CacheEntry]
    private let maxSize: Int
    private let logger = Logger(subsystem: "com.fonichifi.cache", category: "TrackCache")

    // LRU tracking
    private var accessOrder: [UUID]

    // MARK: - Initialization

    public init(maxSize: Int = 1000) {
        self.maxSize = maxSize
        cache = [:]
        accessOrder = []
        logger.info("TrackCache initialized with max size: \(maxSize)")
    }

    // MARK: - Public Methods

    /// Add or update a track in the cache
    public func addTrack(_ trackData: TrackCacheData) async {
        let id = trackData.id

        // Update access order
        accessOrder.removeAll { $0 == id }
        accessOrder.append(id)

        // Add or update entry
        cache[id] = CacheEntry(
            trackData: trackData,
            lastAccessed: Date(),
            accessCount: 1,
        )

        // Evict if needed
        await evictIfNeeded()

        logger.debug("Added track to cache: \(trackData.title)")
    }

    /// Get a track from the cache
    public func getTrack(_ id: UUID) async -> TrackCacheData? {
        guard var entry = cache[id] else {
            logger.debug("Cache miss for track ID: \(id)")
            return nil
        }

        // Update access info
        entry.lastAccessed = Date()
        entry.accessCount += 1
        cache[id] = entry

        // Update access order for LRU
        accessOrder.removeAll { $0 == id }
        accessOrder.append(id)

        logger.debug("Cache hit for track: \(entry.trackData.title)")
        return entry.trackData
    }

    /// Remove a track from the cache
    public func removeTrack(_ id: UUID) async {
        cache.removeValue(forKey: id)
        accessOrder.removeAll { $0 == id }
        logger.debug("Removed track from cache: \(id)")
    }

    /// Clear all cached tracks
    public func clear() async {
        cache.removeAll()
        accessOrder.removeAll()
        logger.info("Cleared all tracks from cache")
    }

    /// Get current cache statistics
    public func getStatistics() async -> CacheStatistics {
        let totalSize = cache.values.reduce(0) { $0 + $1.trackData.fileSize }
        let avgAccessCount = cache.values.isEmpty ? 0.0 :
            Double(cache.values.reduce(0) { $0 + $1.accessCount }) / Double(cache.count)

        return CacheStatistics(
            count: cache.count,
            totalSizeBytes: totalSize,
            averageAccessCount: avgAccessCount,
            maxSize: maxSize,
        )
    }

    // MARK: - Private Methods

    /// Evict least recently used items if cache is full
    private func evictIfNeeded() async {
        guard cache.count > maxSize else { return }

        let itemsToEvict = cache.count - maxSize
        let idsToEvict = accessOrder.prefix(itemsToEvict)

        for id in idsToEvict {
            cache.removeValue(forKey: id)
            logger.debug("Evicted track from cache: \(id)")
        }

        // Remove evicted IDs from access order
        accessOrder.removeFirst(itemsToEvict)

        logger.info("Evicted \(itemsToEvict) items from cache")
    }

    /// Prune cache based on age
    public func pruneOldEntries(olderThan age: TimeInterval) async {
        let cutoffDate = Date().addingTimeInterval(-age)
        var idsToRemove: [UUID] = []

        for (id, entry) in cache {
            if entry.lastAccessed < cutoffDate {
                idsToRemove.append(id)
            }
        }

        for id in idsToRemove {
            cache.removeValue(forKey: id)
            accessOrder.removeAll { $0 == id }
        }

        if !idsToRemove.isEmpty {
            logger.info("Pruned \(idsToRemove.count) old entries from cache")
        }
    }

    // MARK: - Batch Operations

    /// Add multiple tracks at once
    public func addTracks(_ tracks: [TrackCacheData]) async {
        for trackData in tracks {
            await addTrack(trackData)
        }
    }

    /// Get multiple tracks at once
    public func getTracks(_ ids: [UUID]) async -> [UUID: TrackCacheData] {
        var results: [UUID: TrackCacheData] = [:]
        for id in ids {
            if let trackData = await getTrack(id) {
                results[id] = trackData
            }
        }
        return results
    }

    // MARK: - Cache Statistics

    public struct CacheStatistics: Sendable {
        public let count: Int
        public let totalSizeBytes: Int64
        public let averageAccessCount: Double
        public let maxSize: Int

        public var fillPercentage: Double {
            Double(count) / Double(maxSize) * 100
        }

        public var formattedTotalSize: String {
            ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
        }
    }
}
