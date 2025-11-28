//
//  WidgetConstants.swift
//  Fonic HiFi Widget
//
//  Standalone copy for widget extension (no main app dependencies)
//

import Foundation

/// Constants shared between the main app and widget extension
public enum WidgetConstants {
    /// App Group identifier for shared data
    public static let appGroupIdentifier = "group.ai.keiranlabs.Fonic-HiFi"

    /// UserDefaults keys for shared state
    public enum Keys {
        public static let playbackState = "widget.playbackState"
        public static let trackInfo = "widget.trackInfo"
        public static let upNextTracks = "widget.upNextTracks"
        public static let lastUpdated = "widget.lastUpdated"
    }

    /// Widget kinds for identification
    public enum WidgetKind {
        public static let nowPlaying = "NowPlayingWidget"
    }

    /// Artwork cache configuration
    public enum ArtworkCache {
        /// Directory name within App Group container
        public static let directoryName = "WidgetArtwork"

        /// Maximum cache size in bytes (50MB)
        public static let maxCacheSize: Int64 = 50 * 1024 * 1024

        /// Thumbnail size for widget artwork
        public static let thumbnailSize: CGFloat = 200

        /// JPEG compression quality for thumbnails
        public static let compressionQuality: CGFloat = 0.7

        /// Live Activity thumbnail size (must be tiny for 4KB limit)
        public static let liveActivityThumbnailSize: CGFloat = 100

        /// Live Activity compression quality
        public static let liveActivityCompressionQuality: CGFloat = 0.6
    }

    /// Timeline refresh configuration
    public enum Timeline {
        /// Minimum interval between timeline reloads (seconds)
        public static let minimumRefreshInterval: TimeInterval = 60

        /// Debounce interval for state changes before triggering reload
        public static let debounceInterval: TimeInterval = 0.5
    }
}

/// Shared UserDefaults accessor for App Group
public extension UserDefaults {
    /// Returns the shared UserDefaults for the App Group
    static var appGroup: UserDefaults? {
        UserDefaults(suiteName: WidgetConstants.appGroupIdentifier)
    }
}

/// Shared container URL accessor
public extension FileManager {
    /// Returns the shared container URL for the App Group
    var appGroupContainerURL: URL? {
        containerURL(forSecurityApplicationGroupIdentifier: WidgetConstants.appGroupIdentifier)
    }

    /// Returns the artwork cache directory URL within the App Group container
    var widgetArtworkCacheURL: URL? {
        guard let containerURL = appGroupContainerURL else { return nil }
        return containerURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
            .appendingPathComponent(WidgetConstants.ArtworkCache.directoryName, isDirectory: true)
    }
}
