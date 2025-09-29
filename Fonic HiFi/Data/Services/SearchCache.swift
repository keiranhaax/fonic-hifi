//
//  SearchCache.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Foundation
import OSLog

/// Cache for search results with TTL expiration
public actor SearchCache {
    // MARK: - Types

    /// Simplified track data for cache storage
    public struct CachedTrack: Sendable {
        public let id: UUID
        public let title: String
        public let artist: String
        public let album: String
        public let duration: TimeInterval
    }

    /// Simplified album data for cache storage
    public struct CachedAlbum: Sendable {
        public let id: UUID
        public let title: String
        public let artistName: String
        public let trackCount: Int
    }

    /// Simplified artist data for cache storage
    public struct CachedArtist: Sendable {
        public let id: UUID
        public let name: String
        public let albumCount: Int
        public let trackCount: Int
    }

    /// Simplified playlist data for cache storage
    public struct CachedPlaylist: Sendable {
        public let id: UUID
        public let name: String
        public let trackCount: Int
    }

    public struct SearchResult: Sendable {
        public let query: String
        public let tracks: [CachedTrack]
        public let albums: [CachedAlbum]
        public let artists: [CachedArtist]
        public let playlists: [CachedPlaylist]
        public let timestamp: Date

        public init(
            query: String,
            tracks: [CachedTrack] = [],
            albums: [CachedAlbum] = [],
            artists: [CachedArtist] = [],
            playlists: [CachedPlaylist] = [],
            timestamp: Date = Date(),
        ) {
            self.query = query
            self.tracks = tracks
            self.albums = albums
            self.artists = artists
            self.playlists = playlists
            self.timestamp = timestamp
        }

        /// Check if result is expired
        public func isExpired(ttl: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }

        /// Check if result is empty
        public var isEmpty: Bool {
            tracks.isEmpty && albums.isEmpty && artists.isEmpty && playlists.isEmpty
        }

        /// Total result count
        public var totalCount: Int {
            tracks.count + albums.count + artists.count + playlists.count
        }
    }

    // MARK: - Properties

    private var cache: [String: SearchResult]
    private let ttl: TimeInterval
    private let logger = Logger(subsystem: "com.fonichifi.cache", category: "SearchCache")

    /// Maximum number of cached searches
    private let maxCacheSize: Int

    /// Timer for periodic cleanup
    private var cleanupTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(ttl: TimeInterval = 300, maxCacheSize: Int = 100) { // 5 minutes default TTL
        cache = [:]
        self.ttl = ttl
        self.maxCacheSize = maxCacheSize
        logger.info("SearchCache initialized with TTL: \(ttl)s, max size: \(maxCacheSize)")

        // Start periodic cleanup task
        Task {
            await startCleanupTask()
        }
    }

    deinit {
        cleanupTask?.cancel()
    }

    // MARK: - Public Methods

    /// Get cached search result
    public func get(_ query: String) async -> SearchResult? {
        let normalizedQuery = normalizeQuery(query)

        guard let result = cache[normalizedQuery] else {
            logger.debug("Cache miss for query: '\(query)'")
            return nil
        }

        // Check if expired
        if result.isExpired(ttl: ttl) {
            cache.removeValue(forKey: normalizedQuery)
            logger.debug("Cache expired for query: '\(query)'")
            return nil
        }

        logger.debug("Cache hit for query: '\(query)' (result count: \(result.totalCount))")
        return result
    }

    /// Cache search result
    public func set(_ query: String, result: SearchResult) async {
        let normalizedQuery = normalizeQuery(query)

        // Don't cache empty results
        guard !result.isEmpty else {
            logger.debug("Skipping cache for empty result: '\(query)'")
            return
        }

        cache[normalizedQuery] = result
        logger.debug("Cached result for query: '\(query)' (result count: \(result.totalCount))")

        // Trim cache if needed
        await trimCacheIfNeeded()
    }

    /// Update specific result type for a query
    public func updateTracks(_ query: String, tracks: [Track]) async {
        let normalizedQuery = normalizeQuery(query)

        // Convert Track objects to CachedTrack
        let cachedTracks = tracks.map { track in
            CachedTrack(
                id: track.id,
                title: track.title,
                artist: track.artist,
                album: track.album,
                duration: track.duration,
            )
        }

        if var existing = cache[normalizedQuery], !existing.isExpired(ttl: ttl) {
            // Update with new tracks while preserving other results
            cache[normalizedQuery] = SearchResult(
                query: existing.query,
                tracks: cachedTracks,
                albums: existing.albums,
                artists: existing.artists,
                playlists: existing.playlists,
                timestamp: Date(), // Reset timestamp
            )
        } else {
            // Create new result with just tracks
            cache[normalizedQuery] = SearchResult(
                query: query,
                tracks: cachedTracks,
                timestamp: Date(),
            )
        }
    }

    /// Invalidate expired entries
    public func invalidateExpired() async {
        let now = Date()
        var expiredCount = 0

        for (key, result) in cache {
            if result.isExpired(ttl: ttl) {
                cache.removeValue(forKey: key)
                expiredCount += 1
            }
        }

        if expiredCount > 0 {
            logger.info("Invalidated \(expiredCount) expired cache entries")
        }
    }

    /// Clear entire cache
    public func clear() async {
        let previousSize = cache.count
        cache.removeAll()
        logger.info("Cleared search cache (removed \(previousSize) entries)")
    }

    /// Invalidate cache for specific query
    public func invalidate(_ query: String) async {
        let normalizedQuery = normalizeQuery(query)
        if cache.removeValue(forKey: normalizedQuery) != nil {
            logger.debug("Invalidated cache for query: '\(query)'")
        }
    }

    /// Get cache statistics
    public func getStatistics() async -> CacheStatistics {
        let now = Date()
        var expiredCount = 0
        var totalResults = 0
        var oldestEntry: Date?
        var newestEntry: Date?

        for result in cache.values {
            if result.isExpired(ttl: ttl) {
                expiredCount += 1
            }
            totalResults += result.totalCount

            if oldestEntry == nil || result.timestamp < oldestEntry! {
                oldestEntry = result.timestamp
            }
            if newestEntry == nil || result.timestamp > newestEntry! {
                newestEntry = result.timestamp
            }
        }

        return CacheStatistics(
            entryCount: cache.count,
            expiredCount: expiredCount,
            totalCachedResults: totalResults,
            oldestEntry: oldestEntry ?? now,
            newestEntry: newestEntry ?? now,
            ttl: ttl,
        )
    }

    // MARK: - Private Methods

    /// Normalize query for consistent caching
    private func normalizeQuery(_ query: String) -> String {
        query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    /// Start periodic cleanup task
    private func startCleanupTask() {
        cleanupTask = Task {
            while !Task.isCancelled {
                // Wait for half of TTL before cleaning
                try? await Task.sleep(nanoseconds: UInt64(ttl * 0.5 * 1_000_000_000))

                await invalidateExpired()
            }
        }
    }

    /// Trim cache if it exceeds maximum size
    private func trimCacheIfNeeded() async {
        guard cache.count > maxCacheSize else { return }

        // Sort by timestamp and keep most recent
        let sortedEntries = cache.sorted { $0.value.timestamp > $1.value.timestamp }
        let entriesToKeep = Array(sortedEntries.prefix(Int(Double(maxCacheSize) * 0.75)))

        cache = Dictionary(uniqueKeysWithValues: entriesToKeep)
        logger.info("Trimmed cache to \(cache.count) entries")
    }

    // MARK: - Cache Statistics

    public struct CacheStatistics: Sendable {
        public let entryCount: Int
        public let expiredCount: Int
        public let totalCachedResults: Int
        public let oldestEntry: Date
        public let newestEntry: Date
        public let ttl: TimeInterval

        public var averageResultsPerEntry: Int {
            entryCount > 0 ? totalCachedResults / entryCount : 0
        }

        public var cacheEfficiency: Double {
            let validCount = entryCount - expiredCount
            return entryCount > 0 ? Double(validCount) / Double(entryCount) : 0
        }
    }
}
