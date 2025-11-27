//
//  LargeWidgetView.swift
//  Fonic HiFi Widget
//
//  Created by Claude on 11/26/25.
//

import AppIntents
import SwiftUI
import WidgetKit

/// Large widget view showing full now playing and up-next queue
/// Displays up to 4 upcoming tracks
/// Adapts for StandBy mode with enlarged content for distance viewing
struct LargeWidgetView: View {
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
        VStack(spacing: sizes.spacing + 4) {
            // Now playing section
            nowPlayingSection

            Divider()
                .opacity(renderingMode == .vibrant ? 0.5 : 1.0)

            // Up next section
            upNextSection
        }
        .padding(isStandByMode ? 16 : 12)
        .widgetURL(URL(string: "fonichifi://nowplaying"))
    }

    // MARK: - Now Playing Section

    private var nowPlayingSection: some View {
        HStack(spacing: sizes.spacing + 4) {
            // Artwork
            WidgetArtworkView(artworkKey: entry.trackInfo.artworkKey, size: sizes.mediumArtwork)

            // Track info and controls
            VStack(alignment: .leading, spacing: isStandByMode ? 8 : 6) {
                if entry.hasContent {
                    // Track info
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(entry.trackInfo.title)
                                .font(fonts.title)
                                .lineLimit(1)

                            // Quality badge (hidden in vibrant mode)
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

                        Text(entry.trackInfo.artistAlbum)
                            .font(fonts.subtitle)
                            .foregroundStyle(colors.secondary)
                            .lineLimit(1)
                    }

                    // Progress bar
                    progressSection

                    // Controls
                    controlsSection
                } else {
                    emptyStateView
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 2) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(colors.tertiary.opacity(0.3))

                    Capsule()
                        .fill(colors.primary)
                        .frame(width: geometry.size.width * CGFloat(entry.progress))
                }
            }
            .frame(height: sizes.progressHeight)

            HStack {
                Text(formatTime(entry.playbackState.currentTime))
                    .font(fonts.monospacedTime(size: 10))
                    .foregroundStyle(colors.secondary)

                Spacer()

                Text("-\(formatTime(entry.playbackState.remainingTime))")
                    .font(fonts.monospacedTime(size: 10))
                    .foregroundStyle(colors.secondary)
            }
        }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        HStack(spacing: isStandByMode ? 32 : 24) {
            // Shuffle
            Button(intent: ToggleShuffleIntent()) {
                Image(systemName: "shuffle")
                    .font(.system(size: isStandByMode ? 16 : 12))
                    .foregroundStyle(entry.playbackState.shuffleEnabled ? colors.accent : colors.secondary)
            }
            .buttonStyle(.plain)

            // Previous
            Button(intent: SkipPreviousIntent()) {
                Image(systemName: "backward.fill")
                    .font(.system(size: sizes.controlIcon + 2))
                    .foregroundStyle(entry.playbackState.hasPrevious ? colors.primary : colors.tertiary)
            }
            .buttonStyle(.plain)
            .disabled(!entry.playbackState.hasPrevious)

            // Play/Pause
            Button(intent: PlayPauseIntent()) {
                Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: sizes.playPauseIcon + 4))
                    .foregroundStyle(colors.primary)
            }
            .buttonStyle(.plain)

            // Next
            Button(intent: SkipNextIntent()) {
                Image(systemName: "forward.fill")
                    .font(.system(size: sizes.controlIcon + 2))
                    .foregroundStyle(entry.playbackState.hasNext ? colors.primary : colors.tertiary)
            }
            .buttonStyle(.plain)
            .disabled(!entry.playbackState.hasNext)

            // Repeat mode indicator
            Image(systemName: repeatIcon)
                .font(.system(size: isStandByMode ? 16 : 12))
                .foregroundStyle(entry.playbackState.repeatMode != "none" ? colors.accent : colors.secondary)
        }
    }

    private var repeatIcon: String {
        switch entry.playbackState.repeatMode {
        case "one":
            return "repeat.1"
        default:
            return "repeat"
        }
    }

    // MARK: - Up Next Section

    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: sizes.spacing) {
            Text("Up Next")
                .font(fonts.caption)
                .fontWeight(.semibold)
                .foregroundStyle(colors.secondary)
                .textCase(.uppercase)

            if entry.upNextTracks.isEmpty {
                Text("Queue is empty")
                    .font(fonts.caption)
                    .foregroundStyle(colors.tertiary)
                    .padding(.vertical, 4)
            } else {
                // Show fewer tracks in StandBy mode for better readability
                let trackCount = isStandByMode ? 3 : 4
                ForEach(entry.upNextTracks.prefix(trackCount)) { track in
                    upNextRow(for: track)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func upNextRow(for track: WidgetTrackInfo) -> some View {
        HStack(spacing: sizes.spacing) {
            // Small artwork
            WidgetArtworkView(artworkKey: track.artworkKey, size: sizes.smallArtwork)

            // Track info
            VStack(alignment: .leading, spacing: 1) {
                Text(track.title)
                    .font(fonts.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(track.artist)
                    .font(fonts.caption2)
                    .foregroundStyle(colors.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Duration
            Text(track.formattedDuration)
                .font(fonts.caption2)
                .foregroundStyle(colors.tertiary)
                .monospacedDigit()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: sizes.spacing) {
            Text("Nothing Playing")
                .font(fonts.title)

            Text("Open Fonic HiFi to play music")
                .font(fonts.subtitle)
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

#Preview(as: .systemLarge) {
    NowPlayingWidget()
} timeline: {
    NowPlayingEntry.preview
    NowPlayingEntry.placeholder
}
