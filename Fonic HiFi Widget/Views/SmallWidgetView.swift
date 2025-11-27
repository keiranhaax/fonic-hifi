//
//  SmallWidgetView.swift
//  Fonic HiFi Widget
//
//  Created by Claude on 11/26/25.
//

import AppIntents
import SwiftUI
import WidgetKit

/// Small widget view showing artwork and play/pause button
/// Designed to be minimal and glanceable
/// Adapts for StandBy mode with enlarged content for distance viewing
struct SmallWidgetView: View {
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: NowPlayingEntry

    /// StandBy mode detection - when background is hidden
    private var isStandByMode: Bool { !showsBackground }

    /// Adaptive sizes for StandBy mode
    private var sizes: StandBySizes { StandBySizes(showsBackground: showsBackground) }
    private var fonts: StandByFont { StandByFont(showsBackground: showsBackground) }
    private var colors: StandByColors { StandByColors(renderingMode: renderingMode) }

    var body: some View {
        VStack(spacing: sizes.spacing) {
            // Artwork with overlay play state
            ZStack(alignment: .bottomTrailing) {
                WidgetArtworkView(artworkKey: entry.trackInfo.artworkKey, size: sizes.mediumArtwork)

                // Play state indicator
                if entry.hasContent {
                    playStateIndicator
                        .padding(isStandByMode ? 6 : 4)
                }
            }

            // Track info (minimal)
            if entry.hasContent {
                VStack(spacing: 2) {
                    Text(entry.trackInfo.title)
                        .font(fonts.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(entry.trackInfo.artist)
                        .font(fonts.caption2)
                        .foregroundStyle(colors.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("Not Playing")
                    .font(fonts.caption)
                    .foregroundStyle(colors.secondary)
            }
        }
        .padding(isStandByMode ? 16 : 12)
        .widgetURL(URL(string: "fonichifi://nowplaying"))
    }

    private var playStateIndicator: some View {
        // Interactive play/pause button using App Intent
        Button(intent: PlayPauseIntent()) {
            Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: isStandByMode ? 16 : 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(isStandByMode ? 8 : 6)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    NowPlayingWidget()
} timeline: {
    NowPlayingEntry.preview
    NowPlayingEntry.placeholder
}
