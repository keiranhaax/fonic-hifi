//
//  ArtworkService.swift
//  Fonic HiFi
//
//  Lazy artwork loading service with background fetching and caching.
//  Uses ModelActor for background SwiftData access to avoid main-thread blocking.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Background Fetcher

/// Background actor for fetching artwork from SwiftData without blocking the main thread.
@ModelActor
public actor ArtworkFetcher {
    /// Fetch artwork for a track by UUID
    public func fetchTrackArtwork(trackId: UUID) -> Data? {
        let descriptor = FetchDescriptor<Track>(
            predicate: #Predicate<Track> { track in
                track.id == trackId
            }
        )
        return try? modelContext.fetch(descriptor).first?.artwork
    }

    /// Fetch artwork for an album by UUID.
    /// Falls back to querying tracks by album name since relationships may not be populated.
    public func fetchAlbumArtwork(albumId: UUID) -> Data? {
        let albumDescriptor = FetchDescriptor<Album>(
            predicate: #Predicate<Album> { album in
                album.id == albumId
            }
        )

        guard let album = try? modelContext.fetch(albumDescriptor).first else {
            return nil
        }

        // Try album's own artwork first
        if let artwork = album.artwork {
            return artwork
        }

        // Fall back to querying tracks by album name (since relationships may not be linked)
        return fetchArtworkByAlbumName(title: album.title, artist: album.albumArtist)
    }

    /// Fetch artwork by album title and artist name.
    /// Useful when Album.id isn't available or when using SwiftData models directly.
    public func fetchArtworkByAlbumName(title: String, artist: String) -> Data? {
        let descriptor = FetchDescriptor<Track>(
            predicate: #Predicate<Track> { track in
                track.album == title && track.albumArtist == artist && track.artwork != nil
            }
        )
        return try? modelContext.fetch(descriptor).first?.artwork
    }
}

// MARK: - Main Thread Service

/// Main-thread service for loading artwork with caching.
/// Uses ArtworkFetcher for background SwiftData access.
@MainActor
public final class ArtworkService: ObservableObject {
    // MARK: - Cache

    private var cache: [String: Data] = [:]
    private let maxCacheSize = 100

    // MARK: - Fetcher

    private let fetcher: ArtworkFetcher

    // MARK: - Initialization

    public init(container: ModelContainer) {
        self.fetcher = ArtworkFetcher(modelContainer: container)
    }

    // MARK: - Public API

    /// Load artwork for a track by UUID (background fetch, cached)
    public func artwork(for trackId: UUID) async -> Data? {
        let key = "track:\(trackId)"

        if let cached = cache[key] {
            return cached
        }

        let artwork = await fetcher.fetchTrackArtwork(trackId: trackId)

        if let artwork {
            maintainCacheSize()
            cache[key] = artwork
        }

        return artwork
    }

    /// Load artwork for an album by UUID (background fetch, cached)
    public func albumArtwork(for albumId: UUID) async -> Data? {
        let key = "album:\(albumId)"

        if let cached = cache[key] {
            return cached
        }

        let artwork = await fetcher.fetchAlbumArtwork(albumId: albumId)

        if let artwork {
            maintainCacheSize()
            cache[key] = artwork
        }

        return artwork
    }

    /// Load artwork by album title and artist (for views using SwiftData models directly)
    public func albumArtwork(title: String, artist: String) async -> Data? {
        let key = "album:\(title):\(artist)"

        if let cached = cache[key] {
            return cached
        }

        let artwork = await fetcher.fetchArtworkByAlbumName(title: title, artist: artist)

        if let artwork {
            maintainCacheSize()
            cache[key] = artwork
        }

        return artwork
    }

    /// Clear the cache
    public func clearCache() {
        cache.removeAll()
    }

    /// Load artwork data for widget caching (alias for artwork(for:))
    /// Used by WidgetDataCoordinator to populate the widget artwork cache
    public func loadArtworkData(forTrackId trackId: UUID) async -> Data? {
        await artwork(for: trackId)
    }

    // MARK: - Private Helpers

    private func maintainCacheSize() {
        guard cache.count >= maxCacheSize else { return }

        let keysToRemove = Array(cache.keys.prefix(maxCacheSize / 4))
        keysToRemove.forEach { cache.removeValue(forKey: $0) }
    }
}
