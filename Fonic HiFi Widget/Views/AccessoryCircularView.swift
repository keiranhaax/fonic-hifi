//
//  AccessoryCircularView.swift
//  Fonic HiFi Widget
//
//  Created by Claude on 11/26/25.
//

import AppIntents
import SwiftUI
import WidgetKit

/// Circular Lock Screen widget showing progress ring and play/pause indicator
/// Widget family: `.accessoryCircular` [Verified-Apple]
/// Adapts for StandBy mode with thicker strokes for visibility
struct AccessoryCircularView: View {
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: NowPlayingEntry

    /// StandBy mode detection - when background is hidden
    private var isStandByMode: Bool { !showsBackground }

    /// Adaptive stroke width for StandBy visibility
    private var strokeWidth: CGFloat { isStandByMode ? 5 : 3 }

    /// Adaptive icon size for StandBy visibility
    private var iconSize: CGFloat { isStandByMode ? 24 : 18 }

    var body: some View {
        ZStack {
            // Progress ring background
            Circle()
                .stroke(lineWidth: strokeWidth)
                .opacity(0.3)

            // Progress ring fill
            if entry.hasContent {
                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            // Center content - play/pause icon
            centerContent
        }
        .widgetURL(URL(string: "fonichifi://nowplaying"))
    }

    private var centerContent: some View {
        Group {
            if entry.hasContent {
                // Play/pause indicator with app icon style
                Image(systemName: entry.isPlaying ? "waveform" : "play.fill")
                    .font(.system(size: iconSize, weight: .medium))
                    .symbolEffect(.variableColor, isActive: entry.isPlaying)
            } else {
                // No content - show app icon style
                Image(systemName: "waveform")
                    .font(.system(size: iconSize, weight: .medium))
                    .opacity(0.5)
            }
        }
    }
}

// MARK: - Preview

#Preview("Accessory Circular", as: .accessoryCircular) {
    NowPlayingWidget()
} timeline: {
    NowPlayingEntry.preview
    NowPlayingEntry.placeholder
}
