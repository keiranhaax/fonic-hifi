//
//  TrackCache.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Foundation
import OSLog

/// LRU cache for frequently accessed tracks
public actor TrackCache {

    // MARK: - Types

    struct CacheEntry: Sendable {
        let track: Track
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
        self.cache = [:]
        self.accessOrder = []
        logger.info("TrackCache initialized with max size: \(maxSize)")
    }

    // MARK: - Public Methods

    /// Get a track from cache
    public func get(_ id: UUID) async -> Track? {
        guard var entry = cache[id] else {
            logger.debug("Cache miss for track: \(id)")
            return nil
        }

        // Update access information
        entry.lastAccessed = Date()
        entry.accessCount += 1
        cache[id] = entry

        // Move to front of LRU list
        if let index = accessOrder.firstIndex(of: id) {
            accessOrder.remove(at: index)
        }
        accessOrder.insert(id, at: 0)

        logger.debug("Cache hit for track: \(id) (access count: \(entry.accessCount))")
        return entry.track
    }

    /// Add or update a track in cache
    public func set(_ track: Track) async {
        let id = track.id

        // Update existing entry or create new one
        if var entry = cache[id] {
            // Update existing entry
            entry.lastAccessed = Date()
            entry.accessCount += 1
            cache[id] = entry

            // Move to front of LRU list
            if let index = accessOrder.firstIndex(of: id) {
                accessOrder.remove(at: index)
            }
            accessOrder.insert(id, at: 0)
        } else {
            // Add new entry
            let entry = CacheEntry(
                track: track,
                lastAccessed: Date(),
                accessCount: 1
            )
            cache[id] = entry
            accessOrder.insert(id, at: 0)

            // Evict if needed
            if cache.count > maxSize {
                await evictLRU()
            }
        }

        logger.debug("Cached track: \(trackData.title) (cache size: \(self.cache.count))")
    }

    /// Evict least recently used items
    public func evictLRU() async {
        guard !accessOrder.isEmpty else { return }

        // Keep high-frequency items even if they're old
        let evictionCandidates = accessOrder.suffix(accessOrder.count / 3)
        var evictedCount = 0
        let targetSize = Int(Double(maxSize) * 0.75) // Reduce to 75% capacity

        for id in evictionCandidates {
            guard cache.count > targetSize else { break }

            // Don't evict items with high access count (>10 accesses)
            if let entry = cache[id], entry.accessCount <= 10 {
                cache.removeValue(forKey: id)
                if let index = accessOrder.firstIndex(of: id) {
                    accessOrder.remove(at: index)
                }
                evictedCount += 1
            }
        }

        logger.info("Evicted \(evictedCount) items from cache (new size: \(cache.count))")
    }

    /// Invalidate a specific track
    public func invalidate(_ id: UUID) async {
        if cache.removeValue(forKey: id) != nil {
            if let index = accessOrder.firstIndex(of: id) {
                accessOrder.remove(at: index)
            }
            logger.debug("Invalidated track: \(id)")
        }
    }

    /// Clear entire cache
    public func clear() async {
        let previousSize = cache.count
        cache.removeAll()
        accessOrder.removeAll()
        logger.info("Cleared cache (removed \(previousSize) items)")
    }

    /// Preload tracks into cache
    public func preload(_ tracks: [Track]) async {
        logger.info("Preloading \(tracks.count) tracks into cache")

        for track in tracks.prefix(maxSize) {
            let entry = CacheEntry(
                track: track,
                lastAccessed: Date(),
                accessCount: 0
            )
            cache[track.id] = entry
            accessOrder.append(track.id)
        }

        // Trim if needed
        if cache.count > maxSize {
            await evictLRU()
        }
    }

    /// Get cache statistics
    public func getStatistics() async -> CacheStatistics {
        let totalAccesses = cache.values.reduce(0) { $0 + $1.accessCount }
        let averageAccesses = cache.isEmpty ? 0 : totalAccesses / cache.count

        let oldestAccess = cache.values
            .map { $0.lastAccessed }
            .min() ?? Date()

        let newestAccess = cache.values
            .map { $0.lastAccessed }
            .max() ?? Date()

        return CacheStatistics(
            currentSize: cache.count,
            maxSize: maxSize,
            totalAccesses: totalAccesses,
            averageAccessesPerTrack: averageAccesses,
            oldestAccess: oldestAccess,
            newestAccess: newestAccess,
            fillPercentage: Double(cache.count) / Double(maxSize)
        )
    }

    // MARK: - Cache Statistics

    public struct CacheStatistics: Sendable {
        public let currentSize: Int
        public let maxSize: Int
        public let totalAccesses: Int
        public let averageAccessesPerTrack: Int
        public let oldestAccess: Date
        public let newestAccess: Date
        public let fillPercentage: Double
    }
}