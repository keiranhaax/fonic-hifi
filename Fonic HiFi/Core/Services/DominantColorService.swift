//
//  DominantColorService.swift
//  Fonic HiFi
//
//  Centralized color extraction service shared between mini player and NowPlayingView.
//  Ensures consistent colors during transitions and prevents duplicate extraction work.
//

import SwiftUI

/// Centralized service for extracting and caching dominant colors from album artwork.
/// Shared between mini player and expanded NowPlayingView to ensure color consistency.
@MainActor
final class DominantColorService: ObservableObject {
    /// Shared singleton instance
    static let shared = DominantColorService()

    /// Current dominant color extracted from the active track's artwork
    @Published private(set) var dominantColor: Color = .accentColor

    /// Track ID of the currently extracted color (for cache validation)
    @Published private(set) var currentTrackID: UUID?

    // MARK: - Private State

    private var colorCache: [UUID: Color] = [:]
    private var isExtractingColor = false
    private let maxCacheSize = 50

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Extract dominant color for the given track.
    /// Uses cache if available, otherwise extracts asynchronously.
    func extractColor(for track: Track?) async {
        guard let track else {
            dominantColor = .accentColor
            currentTrackID = nil
            return
        }

        // Skip if already extracted for this track
        guard track.id != currentTrackID else { return }

        // Check cache first
        if let cached = colorCache[track.id] {
            withAnimation(.easeInOut(duration: 0.5)) {
                dominantColor = cached
                currentTrackID = track.id
            }
            return
        }

        // Guard concurrent extractions
        guard !isExtractingColor else { return }
        isExtractingColor = true
        defer { isExtractingColor = false }

        // No artwork - use default
        guard let artworkData = track.artwork else {
            dominantColor = .accentColor
            currentTrackID = track.id
            return
        }

        // Extract on background thread
        let extractedColor = await Task.detached(priority: .utility) {
            UIImage(data: artworkData)?.fastAverageColor ?? Color.accentColor
        }.value

        // Cache result
        colorCache[track.id] = extractedColor
        maintainCacheSize()

        // Apply with animation
        withAnimation(.easeInOut(duration: 0.5)) {
            dominantColor = extractedColor
            currentTrackID = track.id
        }
    }

    /// Clear the cache and reset to default color
    func reset() {
        colorCache.removeAll()
        currentTrackID = nil
        dominantColor = .accentColor
    }

    // MARK: - Private Helpers

    private func maintainCacheSize() {
        guard colorCache.count > maxCacheSize else { return }

        let overflow = colorCache.count - maxCacheSize
        let keysToRemove = Array(colorCache.keys.prefix(overflow))
        keysToRemove.forEach { colorCache.removeValue(forKey: $0) }
    }
}
