//
//  AccessoryRectangularView.swift
//  Fonic HiFi Widget
//
//  Created by Claude on 11/26/25.
//

import AppIntents
import SwiftUI
import WidgetKit

/// Rectangular Lock Screen widget showing artwork, track info, and progress
/// Widget family: `.accessoryRectangular` [Verified-Apple]
/// Adapts for StandBy mode with enlarged content for distance viewing
struct AccessoryRectangularView: View {
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
        if entry.hasContent {
            contentView
        } else {
            emptyView
        }
    }

    private var contentView: some View {
        HStack(spacing: sizes.spacing) {
            // Mini artwork (Lock Screen supports small images)
            miniArtwork

            // Track info and progress
            VStack(alignment: .leading, spacing: isStandByMode ? 4 : 2) {
                // Track title
                Text(entry.trackInfo.title)
                    .font(fonts.title)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                // Artist
                Text(entry.trackInfo.artist)
                    .font(fonts.caption)
                    .foregroundStyle(colors.secondary)
                    .lineLimit(1)

                // Progress bar
                progressBar
            }
        }
        .widgetURL(URL(string: "fonichifi://nowplaying"))
    }

    private var miniArtwork: some View {
        Group {
            if renderingMode == .fullColor {
                // Full color mode - show actual artwork
                WidgetArtworkView(artworkKey: entry.trackInfo.artworkKey, size: sizes.smallArtwork)
            } else {
                // Vibrant/accented mode - simplified icon with StandBy scaling
                Image(systemName: entry.isPlaying ? "waveform" : "music.note")
                    .font(.system(size: isStandByMode ? 24 : 18, weight: .medium))
                    .frame(width: sizes.smallArtwork, height: sizes.smallArtwork)
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(colors.tertiary.opacity(0.4))
                    .frame(height: sizes.progressHeight - 2)

                // Progress fill
                Capsule()
                    .fill(colors.primary)
                    .frame(width: geometry.size.width * entry.progress, height: sizes.progressHeight - 2)
            }
        }
        .frame(height: sizes.progressHeight - 2)
    }

    private var emptyView: some View {
        HStack(spacing: sizes.spacing) {
            Image(systemName: "music.note")
                .font(.system(size: isStandByMode ? 26 : 20, weight: .medium))
                .frame(width: sizes.smallArtwork, height: sizes.smallArtwork)
                .opacity(0.5)

            VStack(alignment: .leading, spacing: isStandByMode ? 4 : 2) {
                Text("Fonic HiFi")
                    .font(fonts.title)
                    .fontWeight(.semibold)

                Text("Nothing playing")
                    .font(fonts.caption)
                    .foregroundStyle(colors.secondary)
            }
        }
        .widgetURL(URL(string: "fonichifi://library"))
    }
}

// MARK: - Preview

#Preview("Accessory Rectangular", as: .accessoryRectangular) {
    NowPlayingWidget()
} timeline: {
    NowPlayingEntry.preview
    NowPlayingEntry.placeholder
}
