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
    private let logger = Log.logger(.dataSearchCache)

    /// Maximum number of cached searches
    private let maxCacheSize: Int

    /// Timer for periodic cleanup
    private var cleanupTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(ttl: TimeInterval = 300, maxCacheSize: Int = 100) { // 5 minutes default TTL
        self.cache = [:]
        self.ttl = ttl
        self.maxCacheSize = maxCacheSize
        self.logger.info("SearchCache initialized with TTL: \(ttl)s, max size: \(maxCacheSize)")

        // Start periodic cleanup task
        Task {
            await self.startCleanupTask()
        }
    }

    deinit {
        self.cleanupTask?.cancel()
    }

    // MARK: - Public Methods

    /// Get cached search result
    public func get(_ query: String) async -> SearchResult? {
        let normalizedQuery = self.normalizeQuery(query)

        guard let result = self.cache[normalizedQuery] else {
            self.logger.debug("Cache miss for query: '\(query)'")
            return nil
        }

        // Check if expired
        if result.isExpired(ttl: self.ttl) {
            self.cache.removeValue(forKey: normalizedQuery)
            self.logger.debug("Cache expired for query: '\(query)'")
            return nil
        }

        self.logger.debug("Cache hit for query: '\(query)' (result count: \(result.totalCount))")
        return result
    }

    /// Cache search result
    public func set(_ query: String, result: SearchResult) async {
        let normalizedQuery = self.normalizeQuery(query)

        self.cache[normalizedQuery] = result
        self.logger.debug("Cached result for query: '\(query)' (result count: \(result.totalCount))")

        // Trim cache if needed
        await self.trimCacheIfNeeded()
    }

    /// Update specific result type for a query
    public func updateTracks(_ query: String, tracks: [Track]) async {
        let normalizedQuery = self.normalizeQuery(query)

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

        if let existing = self.cache[normalizedQuery], !existing.isExpired(ttl: self.ttl) {
            // Update with new tracks while preserving other results
            self.cache[normalizedQuery] = SearchResult(
                query: existing.query,
                tracks: cachedTracks,
                albums: existing.albums,
                artists: existing.artists,
                playlists: existing.playlists,
                timestamp: Date(), // Reset timestamp
            )
        } else {
            // Create new result with just tracks
            self.cache[normalizedQuery] = SearchResult(
                query: query,
                tracks: cachedTracks,
                timestamp: Date(),
            )
        }
    }

    /// Invalidate expired entries
    public func invalidateExpired() async {
        var expiredCount = 0

        for (key, result) in self.cache {
            if result.isExpired(ttl: self.ttl) {
                self.cache.removeValue(forKey: key)
                expiredCount += 1
            }
        }

        if expiredCount > 0 {
            self.logger.info("Invalidated \(expiredCount) expired cache entries")
        }
    }

    /// Clear entire cache
    public func clear() async {
        let previousSize = self.cache.count
        self.cache.removeAll()
        self.logger.info("Cleared search cache (removed \(previousSize) entries)")
    }

    /// Invalidate cache for specific query
    public func invalidate(_ query: String) async {
        let normalizedQuery = self.normalizeQuery(query)
        if self.cache.removeValue(forKey: normalizedQuery) != nil {
            self.logger.debug("Invalidated cache for query: '\(query)'")
        }
    }

    /// Get cache statistics
    public func getStatistics() async -> CacheStatistics {
        let now = Date()
        var expiredCount = 0
        var totalResults = 0
        var oldestEntry: Date?
        var newestEntry: Date?

        for result in self.cache.values {
            if result.isExpired(ttl: self.ttl) {
                expiredCount += 1
            }
            totalResults += result.totalCount

            if (oldestEntry.map { result.timestamp < $0 }) ?? true {
                oldestEntry = result.timestamp
            }

            if (newestEntry.map { result.timestamp > $0 }) ?? true {
                newestEntry = result.timestamp
            }
        }

        return CacheStatistics(
            entryCount: self.cache.count,
            expiredCount: expiredCount,
            totalCachedResults: totalResults,
            oldestEntry: oldestEntry,
            newestEntry: newestEntry,
            ttl: self.ttl,
            snapshotDate: now,
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
        self.cleanupTask = Task {
            while !Task.isCancelled {
                // Wait for half of TTL before cleaning
                try? await Task.sleep(nanoseconds: UInt64(self.ttl * 0.5 * 1_000_000_000))

                await self.invalidateExpired()
            }
        }
    }

    /// Trim cache if it exceeds maximum size
    private func trimCacheIfNeeded() async {
        guard self.cache.count > self.maxCacheSize else { return }

        // Sort by timestamp and keep most recent
        let sortedEntries = self.cache.sorted { $0.value.timestamp > $1.value.timestamp }
        let entriesToKeep = Array(sortedEntries.prefix(Int(Double(self.maxCacheSize) * 0.75)))

        self.cache = Dictionary(uniqueKeysWithValues: entriesToKeep)
        self.logger.info("Trimmed cache to \(self.cache.count) entries")
    }

    // MARK: - Cache Statistics

    public struct CacheStatistics: Sendable {
        public let entryCount: Int
        public let expiredCount: Int
        public let totalCachedResults: Int
        public let oldestEntry: Date?
        public let newestEntry: Date?
        public let ttl: TimeInterval
        public let snapshotDate: Date

        public var averageResultsPerEntry: Int {
            entryCount > 0 ? totalCachedResults / entryCount : 0
        }

        public var cacheEfficiency: Double {
            let validCount = entryCount - expiredCount
            return entryCount > 0 ? Double(validCount) / Double(entryCount) : 0
        }

        public var isEmpty: Bool { entryCount == 0 }

        public var cacheFreshnessDescription: String {
            guard let newestEntry else { return "No cache entries" }
            let age = snapshotDate.timeIntervalSince(newestEntry)
            return age < ttl ? "Fresh" : "Stale"
        }
    }
}
