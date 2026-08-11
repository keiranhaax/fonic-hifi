//
//  NowPlayingEntry.swift
//  Fonic HiFi Widget
//
//  Created by Claude on 11/26/25.
//

import Foundation
import WidgetKit

/// Timeline entry containing playback state and track info for widget display
struct NowPlayingEntry: TimelineEntry {
    /// Date for this timeline entry
    let date: Date

    /// Current playback state
    let playbackState: WidgetPlaybackState

    /// Currently playing track info
    let trackInfo: WidgetTrackInfo

    /// Up-next tracks (for large widget)
    let upNextTracks: [WidgetTrackInfo]

    /// Whether any content is available
    var hasContent: Bool {
        trackInfo.id != WidgetTrackInfo.empty.id
    }

    /// Whether playback is active
    var isPlaying: Bool {
        playbackState.isPlaying && !playbackState.isStale
    }

    /// Progress as 0.0-1.0 value
    var progress: Double {
        playbackState.progress
    }

    // MARK: - Static Factories

    /// Create entry from App Group data
    static func fromAppGroup() -> NowPlayingEntry {
        NowPlayingEntry(
            date: Date(),
            playbackState: WidgetPlaybackState.loadOrIdle(),
            trackInfo: WidgetTrackInfo.loadOrEmpty(),
            upNextTracks: [WidgetTrackInfo].loadUpNext()
        )
    }

    /// Empty placeholder entry
    static let placeholder = NowPlayingEntry(
        date: Date(),
        playbackState: .idle,
        trackInfo: .empty,
        upNextTracks: []
    )

    /// Preview entry with sample data
    static let preview = NowPlayingEntry(
        date: Date(),
        playbackState: WidgetPlaybackState(
            isPlaying: true,
            currentTime: 127,
            duration: 253,
            shuffleEnabled: false,
            repeatMode: "none",
            hasNext: true,
            hasPrevious: true
        ),
        trackInfo: WidgetTrackInfo(
            id: UUID(),
            title: "A Day in the Life",
            artist: "The Beatles",
            album: "Sgt. Pepper's Lonely Hearts Club Band",
            duration: 253,
            artworkKey: nil,
            audioFormat: "FLAC",
            isLossless: true
        ),
        upNextTracks: [
            WidgetTrackInfo(
                id: UUID(),
                title: "Good Vibrations",
                artist: "The Beach Boys",
                album: "Smiley Smile",
                duration: 218,
                artworkKey: nil,
                audioFormat: "ALAC",
                isLossless: true
            ),
            WidgetTrackInfo(
                id: UUID(),
                title: "Purple Haze",
                artist: "Jimi Hendrix",
                album: "Are You Experienced",
                duration: 170,
                artworkKey: nil,
                audioFormat: "FLAC",
                isLossless: true
            ),
            WidgetTrackInfo(
                id: UUID(),
                title: "Respect",
                artist: "Aretha Franklin",
                album: "I Never Loved a Man",
                duration: 147,
                artworkKey: nil,
                audioFormat: "MP3",
                isLossless: false
            )
        ]
    )
}
