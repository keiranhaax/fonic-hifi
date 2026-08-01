//
//  WidgetTrackInfo.swift
//  Fonic HiFi
//
//  Created by Claude on 11/26/25.
//

import Foundation

/// Lightweight track metadata for widget consumption
/// Designed to be compact for UserDefaults storage
public struct WidgetTrackInfo: Codable, Sendable, Hashable, Identifiable {
    /// Unique track identifier
    public let id: UUID

    /// Track title
    public let title: String

    /// Artist name
    public let artist: String

    /// Album name
    public let album: String

    /// Duration in seconds
    public let duration: TimeInterval

    /// Key for artwork in the shared cache (filename without extension)
    public let artworkKey: String?

    /// Audio format string (e.g., "FLAC", "ALAC", "MP3")
    public let audioFormat: String

    /// Whether the track is lossless
    public let isLossless: Bool

    // MARK: - Initialization

    public init(
        id: UUID,
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        artworkKey: String?,
        audioFormat: String,
        isLossless: Bool
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkKey = artworkKey
        self.audioFormat = audioFormat
        self.isLossless = isLossless
    }

    // MARK: - Computed Properties

    /// Formatted duration as MM:SS
    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Display string for artist and album
    public var artistAlbum: String {
        if album.isEmpty {
            return artist
        }
        return "\(artist) — \(album)"
    }

    /// Quality badge text
    public var qualityBadge: String? {
        guard isLossless else { return nil }
        return audioFormat.uppercased()
    }

    /// Single line display for accessory inline widget
    public var inlineDisplay: String {
        if artist.isEmpty {
            return title
        }
        return "\(title) • \(artist)"
    }

    // MARK: - Static

    /// Empty track info for placeholder state
    public static let empty = WidgetTrackInfo(
        id: UUID(),
        title: "Not Playing",
        artist: "",
        album: "",
        duration: 0,
        artworkKey: nil,
        audioFormat: "",
        isLossless: false
    )
}

// MARK: - Persistence

public extension WidgetTrackInfo {
    /// Save to App Group UserDefaults
    func save() {
        guard let defaults = UserDefaults.appGroup else { return }
        save(to: defaults)
    }

    /// Save to an explicitly provided store.
    func save(to defaults: UserDefaults) {
        let encoder = JSONEncoder()

        if let data = try? encoder.encode(self) {
            defaults.set(data, forKey: WidgetConstants.Keys.trackInfo)
        }
    }

    /// Load from App Group UserDefaults
    static func load() -> WidgetTrackInfo? {
        guard let defaults = UserDefaults.appGroup else { return nil }
        return load(from: defaults)
    }

    /// Load from an explicitly provided store.
    static func load(from defaults: UserDefaults) -> WidgetTrackInfo? {
        guard let data = defaults.data(forKey: WidgetConstants.Keys.trackInfo) else {
            return nil
        }

        return try? JSONDecoder().decode(WidgetTrackInfo.self, from: data)
    }

    /// Load or return empty state
    static func loadOrEmpty() -> WidgetTrackInfo {
        load() ?? .empty
    }

    /// Load from an explicitly provided store or return empty state.
    static func loadOrEmpty(from defaults: UserDefaults) -> WidgetTrackInfo {
        load(from: defaults) ?? .empty
    }
}

// MARK: - Up Next Tracks

public extension [WidgetTrackInfo] {
    /// Save up-next tracks to App Group UserDefaults
    func saveAsUpNext() {
        guard let defaults = UserDefaults.appGroup else { return }
        saveAsUpNext(to: defaults)
    }

    /// Save up-next tracks to an explicitly provided store.
    func saveAsUpNext(to defaults: UserDefaults) {
        let encoder = JSONEncoder()

        if let data = try? encoder.encode(self) {
            defaults.set(data, forKey: WidgetConstants.Keys.upNextTracks)
        }
    }

    /// Load up-next tracks from App Group UserDefaults
    static func loadUpNext() -> [WidgetTrackInfo] {
        guard let defaults = UserDefaults.appGroup else { return [] }
        return loadUpNext(from: defaults)
    }

    /// Load up-next tracks from an explicitly provided store.
    static func loadUpNext(from defaults: UserDefaults) -> [WidgetTrackInfo] {
        guard let data = defaults.data(forKey: WidgetConstants.Keys.upNextTracks) else {
            return []
        }

        return (try? JSONDecoder().decode([WidgetTrackInfo].self, from: data)) ?? []
    }
}
