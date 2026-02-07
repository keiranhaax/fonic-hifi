//
//  DominantColorService.swift
//  Fonic HiFi
//
//  Centralized color extraction service that provides ThemePalette
//  for full-app artwork-reactive theming.
//

import SwiftUI

/// Centralized service for extracting dominant colors and generating theme palettes.
/// Shared across the app to ensure color consistency during transitions.
@MainActor
final class DominantColorService: ObservableObject {
    /// Shared singleton instance
    static let shared = DominantColorService()

    /// Current theme palette derived from the active track's artwork
    @Published private(set) var palette: ThemePalette = .neutral

    /// Current dominant color (for backward compatibility)
    var dominantColor: Color { palette.dominant }

    /// Track ID of the currently extracted color (for cache validation)
    @Published private(set) var currentTrackID: UUID?

    // MARK: - Private State

    private var colorCache: [UUID: Color] = [:]
    private var isExtractingColor = false
    private let maxCacheSize = 50

    /// Current color scheme for palette adaptation
    private var currentColorScheme: ColorScheme = .dark

    /// Whether artwork theming is enabled
    private var themingEnabled: Bool = true

    /// Whether theming is enabled for light mode specifically
    private var lightModeThemingEnabled: Bool = true

    /// The raw dominant color before palette derivation
    private var rawDominantColor: Color = .accentColor

    /// Animation duration for palette transitions
    private let transitionDuration: Double = 2.5

    // MARK: - Initialization

    private init() {
        rebuildPalette()
    }

    // MARK: - Public API

    /// Update the current color scheme (call from views observing colorScheme)
    func updateColorScheme(_ colorScheme: ColorScheme) {
        guard colorScheme != currentColorScheme else { return }
        currentColorScheme = colorScheme
        withAnimation(.easeInOut(duration: transitionDuration)) {
            rebuildPalette()
        }
    }

    /// Update whether theming is globally enabled
    func updateThemingEnabled(_ enabled: Bool) {
        guard enabled != themingEnabled else { return }
        themingEnabled = enabled
        withAnimation(.easeInOut(duration: transitionDuration)) {
            rebuildPalette()
        }
    }

    /// Update whether theming is enabled for light mode
    func updateLightModeThemingEnabled(_ enabled: Bool) {
        guard enabled != lightModeThemingEnabled else { return }
        lightModeThemingEnabled = enabled
        withAnimation(.easeInOut(duration: transitionDuration)) {
            rebuildPalette()
        }
    }

    /// Extract dominant color for the given track.
    /// Uses cache if available, otherwise extracts asynchronously.
    func extractColor(for track: Track?) async {
        guard let track else {
            rawDominantColor = .accentColor
            currentTrackID = nil
            withAnimation(.easeInOut(duration: transitionDuration)) {
                rebuildPalette()
            }
            return
        }

        // Skip if already extracted for this track
        guard track.id != currentTrackID else { return }

        // Check cache first
        if let cached = colorCache[track.id] {
            rawDominantColor = cached
            currentTrackID = track.id
            withAnimation(.easeInOut(duration: transitionDuration)) {
                rebuildPalette()
            }
            return
        }

        // Guard concurrent extractions
        guard !isExtractingColor else { return }
        isExtractingColor = true
        defer { isExtractingColor = false }

        // No artwork - use default
        guard let artworkData = track.artwork else {
            rawDominantColor = .accentColor
            currentTrackID = track.id
            withAnimation(.easeInOut(duration: transitionDuration)) {
                rebuildPalette()
            }
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
        rawDominantColor = extractedColor
        currentTrackID = track.id
        withAnimation(.easeInOut(duration: transitionDuration)) {
            rebuildPalette()
        }
    }

    /// Extract dominant color for the given album.
    /// Uses cache if available, otherwise extracts asynchronously.
    func extractColor(for album: Album?) async {
        guard let album else {
            rawDominantColor = .accentColor
            currentTrackID = nil
            withAnimation(.easeInOut(duration: transitionDuration)) {
                rebuildPalette()
            }
            return
        }

        // Check cache first (reusing same cache as tracks)
        if let cached = colorCache[album.id] {
            rawDominantColor = cached
            currentTrackID = album.id
            withAnimation(.easeInOut(duration: transitionDuration)) {
                rebuildPalette()
            }
            return
        }

        // Guard concurrent extractions
        guard !isExtractingColor else { return }
        isExtractingColor = true
        defer { isExtractingColor = false }

        // No artwork - use default
        guard let artworkData = album.artwork else {
            rawDominantColor = .accentColor
            currentTrackID = album.id
            withAnimation(.easeInOut(duration: transitionDuration)) {
                rebuildPalette()
            }
            return
        }

        // Extract on background thread
        let extractedColor = await Task.detached(priority: .utility) {
            UIImage(data: artworkData)?.fastAverageColor ?? Color.accentColor
        }.value

        // Cache result
        colorCache[album.id] = extractedColor
        maintainCacheSize()

        // Apply with animation
        rawDominantColor = extractedColor
        currentTrackID = album.id
        withAnimation(.easeInOut(duration: transitionDuration)) {
            rebuildPalette()
        }
    }

    /// Clear the cache and reset to default color
    func reset() {
        colorCache.removeAll()
        currentTrackID = nil
        rawDominantColor = .accentColor
        rebuildPalette()
    }

    /// Pre-compute and cache album colors without updating the active palette.
    func prewarmColorCache(for albums: [Album]) async {
        for album in albums {
            await prewarmColorCache(for: album)
        }
    }

    // MARK: - Private Helpers

    private func rebuildPalette() {
        // Check if theming should be active
        let shouldApplyTheming: Bool = {
            guard themingEnabled else { return false }
            guard currentTrackID != nil else { return false }
            if currentColorScheme == .light && !lightModeThemingEnabled {
                return false
            }
            return true
        }()

        if shouldApplyTheming {
            palette = ThemePalette(dominant: rawDominantColor, colorScheme: currentColorScheme)
        } else {
            palette = ThemePalette.neutral(for: currentColorScheme)
        }
    }

    private func maintainCacheSize() {
        guard colorCache.count > maxCacheSize else { return }

        let overflow = colorCache.count - maxCacheSize
        let keysToRemove = Array(colorCache.keys.prefix(overflow))
        keysToRemove.forEach { colorCache.removeValue(forKey: $0) }
    }

    private func prewarmColorCache(for album: Album) async {
        if colorCache[album.id] != nil {
            return
        }

        guard let artworkData = album.artwork else {
            colorCache[album.id] = .accentColor
            maintainCacheSize()
            return
        }

        let extractedColor = await Task.detached(priority: .utility) {
            UIImage(data: artworkData)?.fastAverageColor ?? Color.accentColor
        }.value

        colorCache[album.id] = extractedColor
        maintainCacheSize()
    }
}
