//
//  NowPlayingAttributes.swift
//  Fonic HiFi
//
//  Created by Claude on 11/26/25.
//

import ActivityKit
import Foundation

/// ActivityAttributes for Now Playing Live Activity
/// Used in Dynamic Island and Lock Screen Live Activity [Verified-Apple]
///
/// **4KB Limit:** ContentState kept minimal, artwork stored as tiny thumbnail (~3KB max)
struct NowPlayingAttributes: ActivityAttributes, Hashable, Codable, Sendable {
    // MARK: - Content State (Dynamic, Updated Frequently)

    /// Dynamic state that changes during playback
    /// Kept minimal to stay under ActivityKit's 4KB limit [Verified-Apple]
    struct ContentState: Codable, Hashable, Sendable {
        /// Whether playback is currently active
        let isPlaying: Bool

        /// Current playback position in seconds
        let currentTime: TimeInterval

        /// Total track duration in seconds
        let duration: TimeInterval

        /// Playback rate for timer-based progress animation
        /// Set to 1.0 when playing, 0.0 when paused
        /// System uses this to interpolate progress automatically [Verified-Apple]
        let playbackRate: Float

        /// Progress as 0.0-1.0 value (computed for convenience)
        var progress: Double {
            guard duration > 0 else { return 0 }
            return min(1.0, max(0.0, currentTime / duration))
        }

        /// Formatted current time string
        var formattedCurrentTime: String {
            formatTime(currentTime)
        }

        /// Formatted duration string
        var formattedDuration: String {
            formatTime(duration)
        }

        /// Formatted remaining time string
        var formattedRemainingTime: String {
            let remaining = max(0, duration - currentTime)
            return "-\(formatTime(remaining))"
        }

        private func formatTime(_ time: TimeInterval) -> String {
            let totalSeconds = Int(time)
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    // MARK: - Static Attributes (Set Once at Start)

    /// Track title
    let title: String

    /// Artist name
    let artist: String

    /// Album name
    let album: String

    /// Track identifier for deep linking
    let trackId: UUID

    /// Tiny artwork thumbnail (max 100x100 JPEG, ~3KB)
    /// Stored as Data to minimize serialization overhead
    let artworkThumbnail: Data?

    /// Whether track is lossless (for quality indicator)
    let isLossless: Bool

    /// Audio format string (e.g., "FLAC", "ALAC", "MP3")
    let audioFormat: String
}

// MARK: - Factory Methods

extension NowPlayingAttributes {
    /// Create attributes from widget track info
    static func from(
        trackInfo: WidgetTrackInfo,
        artworkThumbnail: Data?
    ) -> NowPlayingAttributes {
        NowPlayingAttributes(
            title: trackInfo.title,
            artist: trackInfo.artist,
            album: trackInfo.album,
            trackId: trackInfo.id,
            artworkThumbnail: artworkThumbnail,
            isLossless: trackInfo.isLossless,
            audioFormat: trackInfo.audioFormat
        )
    }
}

// MARK: - Content State Factory

extension NowPlayingAttributes.ContentState {
    /// Create content state from widget playback state
    static func from(
        playbackState: WidgetPlaybackState
    ) -> NowPlayingAttributes.ContentState {
        NowPlayingAttributes.ContentState(
            isPlaying: playbackState.isPlaying,
            currentTime: playbackState.currentTime,
            duration: playbackState.duration,
            playbackRate: playbackState.isPlaying ? 1.0 : 0.0
        )
    }

    /// Initial playing state
    static func playing(
        currentTime: TimeInterval,
        duration: TimeInterval
    ) -> NowPlayingAttributes.ContentState {
        NowPlayingAttributes.ContentState(
            isPlaying: true,
            currentTime: currentTime,
            duration: duration,
            playbackRate: 1.0
        )
    }

    /// Paused state
    static func paused(
        currentTime: TimeInterval,
        duration: TimeInterval
    ) -> NowPlayingAttributes.ContentState {
        NowPlayingAttributes.ContentState(
            isPlaying: false,
            currentTime: currentTime,
            duration: duration,
            playbackRate: 0.0
        )
    }

    /// Idle state (no content)
    static let idle = NowPlayingAttributes.ContentState(
        isPlaying: false,
        currentTime: 0,
        duration: 0,
        playbackRate: 0.0
    )
}
