//
//  MediumWidgetView.swift
//  Fonic HiFi Widget
//
//  Created by Claude on 11/26/25.
//

import AppIntents
import SwiftUI
import WidgetKit

/// Medium widget view showing artwork, track info, and playback controls
/// Displays one up-next track when available
/// Adapts for StandBy mode with enlarged content for distance viewing
struct MediumWidgetView: View {
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.locale) private var locale

    let entry: NowPlayingEntry

    /// StandBy mode detection - when background is hidden
    private var isStandByMode: Bool { !showsBackground }

    /// Adaptive sizes for StandBy mode
    private var sizes: StandBySizes { StandBySizes(showsBackground: showsBackground) }
    private var fonts: StandByFont { StandByFont(showsBackground: showsBackground) }
    private var colors: StandByColors { StandByColors(renderingMode: renderingMode) }

    var body: some View {
        HStack(spacing: sizes.spacing + 4) {
            // Left side: Artwork
            WidgetArtworkView(artworkKey: entry.trackInfo.artworkKey, size: sizes.mediumArtwork)

            // Right side: Track info and controls
            VStack(alignment: .leading, spacing: isStandByMode ? 8 : 6) {
                if entry.hasContent {
                    trackInfoSection
                    progressSection
                    controlsSection
                } else {
                    emptyStateView
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(isStandByMode ? 16 : 12)
        .widgetURL(URL(string: "fonichifi://nowplaying"))
    }

    // MARK: - Track Info

    private var trackInfoSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(entry.trackInfo.title)
                    .font(fonts.subtitle)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                // Quality badge (hidden in vibrant mode for cleaner look)
                if let badge = entry.trackInfo.qualityBadge, renderingMode == .fullColor {
                    Text(badge)
                        .font(.system(size: isStandByMode ? 10 : 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(colors.accent.opacity(0.2))
                        .foregroundStyle(colors.accent)
                        .clipShape(Capsule())
                }
            }

            Text(verbatim: LocalizedWidgetText.artistAlbum(
                artist: entry.trackInfo.artist,
                album: entry.trackInfo.album,
                locale: locale
            ))
                .font(fonts.caption)
                .foregroundStyle(colors.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 2) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(colors.tertiary.opacity(0.3))

                    Capsule()
                        .fill(colors.primary)
                        .frame(width: geometry.size.width * CGFloat(entry.progress))
                }
            }
            .frame(height: sizes.progressHeight - 1)

            // Time labels
            HStack {
                Text(formatTime(entry.playbackState.currentTime))
                    .font(fonts.monospacedTime(size: 9))
                    .foregroundStyle(colors.secondary)

                Spacer()

                Text("-\(formatTime(entry.playbackState.remainingTime))")
                    .font(fonts.monospacedTime(size: 9))
                    .foregroundStyle(colors.secondary)
            }
        }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        HStack(spacing: isStandByMode ? 28 : 20) {
            // Previous
            Button(intent: SkipPreviousIntent()) {
                Image(systemName: "backward.fill")
                    .font(.system(size: sizes.controlIcon))
                    .foregroundStyle(entry.playbackState.hasPrevious ? colors.primary : colors.tertiary)
            }
            .buttonStyle(.plain)
            .disabled(!entry.playbackState.hasPrevious)

            // Play/Pause
            Button(intent: PlayPauseIntent()) {
                Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: sizes.playPauseIcon))
                    .foregroundStyle(colors.primary)
            }
            .buttonStyle(.plain)

            // Next
            Button(intent: SkipNextIntent()) {
                Image(systemName: "forward.fill")
                    .font(.system(size: sizes.controlIcon))
                    .foregroundStyle(entry.playbackState.hasNext ? colors.primary : colors.tertiary)
            }
            .buttonStyle(.plain)
            .disabled(!entry.playbackState.hasNext)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: sizes.spacing) {
            Text("Nothing Playing")
                .font(fonts.subtitle)
                .fontWeight(.semibold)

            Text("Open Fonic HiFi to play music")
                .font(fonts.caption)
                .foregroundStyle(colors.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    NowPlayingWidget()
} timeline: {
    NowPlayingEntry.preview
    NowPlayingEntry.placeholder
}
