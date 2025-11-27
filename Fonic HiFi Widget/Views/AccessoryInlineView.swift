//
//  AccessoryInlineView.swift
//  Fonic HiFi Widget
//
//  Created by Claude on 11/26/25.
//

import SwiftUI
import WidgetKit

/// Inline Lock Screen widget showing single line "Track - Artist"
/// Widget family: `.accessoryInline` [Verified-Apple]
struct AccessoryInlineView: View {
    let entry: NowPlayingEntry

    var body: some View {
        if entry.hasContent {
            // Inline widgets support ViewThatFits for adaptive content
            ViewThatFits {
                // Full version: Icon + Track - Artist
                Label {
                    Text("\(entry.trackInfo.title) - \(entry.trackInfo.artist)")
                } icon: {
                    Image(systemName: entry.isPlaying ? "waveform" : "play.fill")
                }

                // Medium version: Track - Artist (no icon)
                Text("\(entry.trackInfo.title) - \(entry.trackInfo.artist)")

                // Short version: Track only
                Label {
                    Text(entry.trackInfo.title)
                } icon: {
                    Image(systemName: entry.isPlaying ? "waveform" : "play.fill")
                }

                // Shortest: Track title only
                Text(entry.trackInfo.title)
            }
            .widgetURL(URL(string: "fonichifi://nowplaying"))
        } else {
            Label("Fonic HiFi", systemImage: "music.note")
                .widgetURL(URL(string: "fonichifi://library"))
        }
    }
}

// MARK: - Preview

#Preview("Accessory Inline", as: .accessoryInline) {
    NowPlayingWidget()
} timeline: {
    NowPlayingEntry.preview
    NowPlayingEntry.placeholder
}
