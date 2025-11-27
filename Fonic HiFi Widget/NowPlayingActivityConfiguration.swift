//
//  NowPlayingActivityConfiguration.swift
//  Fonic HiFi Widget
//
//  Created by Claude on 11/26/25.
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Live Activity configuration for Now Playing in Dynamic Island and Lock Screen [Verified-Apple]
struct NowPlayingActivityConfiguration: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NowPlayingAttributes.self) { context in
            // Lock Screen / Banner presentation
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island regions
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(context: context)
                }
            } compactLeading: {
                // Compact leading - album art
                CompactLeadingView(context: context)
            } compactTrailing: {
                // Compact trailing - play state indicator
                CompactTrailingView(context: context)
            } minimal: {
                // Minimal - when space is very limited
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Lock Screen Live Activity View

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<NowPlayingAttributes>

    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            artworkView
                .frame(width: 56, height: 56)

            // Track info and progress
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(context.attributes.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Progress bar
                ProgressView(value: context.state.progress)
                    .tint(.primary)
            }

            Spacer()

            // Playback controls
            HStack(spacing: 16) {
                Button(intent: SkipPreviousIntent()) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)

                Button(intent: PlayPauseIntent()) {
                    Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                }
                .buttonStyle(.plain)

                Button(intent: SkipNextIntent()) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.8))
    }

    private var artworkView: some View {
        Group {
            if let artworkData = context.attributes.artworkThumbnail,
               let uiImage = UIImage(data: artworkData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Compact Views (Dynamic Island)

struct CompactLeadingView: View {
    let context: ActivityViewContext<NowPlayingAttributes>

    var body: some View {
        if let artworkData = context.attributes.artworkThumbnail,
           let uiImage = UIImage(data: artworkData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: "music.note")
                .font(.caption)
        }
    }
}

struct CompactTrailingView: View {
    let context: ActivityViewContext<NowPlayingAttributes>

    var body: some View {
        if context.state.isPlaying {
            // Animated waveform indicator
            Image(systemName: "waveform")
                .symbolEffect(.variableColor, isActive: true)
                .font(.caption)
        } else {
            Image(systemName: "pause.fill")
                .font(.caption)
        }
    }
}

// MARK: - Minimal View

struct MinimalView: View {
    let context: ActivityViewContext<NowPlayingAttributes>

    var body: some View {
        if context.state.isPlaying {
            Image(systemName: "waveform")
                .symbolEffect(.variableColor, isActive: true)
        } else {
            Image(systemName: "play.fill")
        }
    }
}

// MARK: - Expanded Views

struct ExpandedLeadingView: View {
    let context: ActivityViewContext<NowPlayingAttributes>

    var body: some View {
        // Larger artwork in expanded view
        if let artworkData = context.attributes.artworkThumbnail,
           let uiImage = UIImage(data: artworkData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.quaternary)
                Image(systemName: "music.note")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 64, height: 64)
        }
    }
}

struct ExpandedTrailingView: View {
    let context: ActivityViewContext<NowPlayingAttributes>

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            // Format badge
            if context.attributes.isLossless {
                Text(context.attributes.audioFormat)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }

            // Time remaining
            Text(context.state.formattedRemainingTime)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

struct ExpandedCenterView: View {
    let context: ActivityViewContext<NowPlayingAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(context.attributes.title)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)

            Text(context.attributes.artist)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct ExpandedBottomView: View {
    let context: ActivityViewContext<NowPlayingAttributes>

    var body: some View {
        VStack(spacing: 8) {
            // Progress bar with times
            VStack(spacing: 4) {
                ProgressView(value: context.state.progress)
                    .tint(.white)

                HStack {
                    Text(context.state.formattedCurrentTime)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(context.state.formattedDuration)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            // Playback controls
            HStack(spacing: 32) {
                Button(intent: SkipPreviousIntent()) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)

                Button(intent: PlayPauseIntent()) {
                    Image(systemName: context.state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                }
                .buttonStyle(.plain)

                Button(intent: SkipNextIntent()) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Previews

#Preview("Live Activity", as: .content, using: NowPlayingAttributes(
    title: "A Day in the Life",
    artist: "The Beatles",
    album: "Sgt. Pepper's",
    trackId: UUID(),
    artworkThumbnail: nil,
    isLossless: true,
    audioFormat: "FLAC"
)) {
    NowPlayingActivityConfiguration()
} contentStates: {
    NowPlayingAttributes.ContentState.playing(currentTime: 127, duration: 253)
    NowPlayingAttributes.ContentState.paused(currentTime: 127, duration: 253)
}
