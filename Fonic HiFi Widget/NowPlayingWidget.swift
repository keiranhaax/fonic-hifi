//
//  NowPlayingWidget.swift
//  Fonic HiFi Widget
//
//  Created by Claude on 11/26/25.
//

import SwiftUI
import WidgetKit

/// Now Playing widget with interactive playback controls
/// Supports home screen and Lock Screen widget families [Verified-Apple]
struct NowPlayingWidget: Widget {
    let kind: String = WidgetConstants.WidgetKind.nowPlaying

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: NowPlayingTimelineProvider()
        ) { entry in
            NowPlayingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .supportedFamilies([
            // Home Screen widgets
            .systemSmall,
            .systemMedium,
            .systemLarge,
            // Lock Screen widgets
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
        .configurationDisplayName("Now Playing")
        .description("See what's playing and control playback.")
    }
}

// MARK: - Main Widget View

/// Adaptive view that renders different layouts based on widget family
struct NowPlayingWidgetView: View {
    @Environment(\.widgetFamily) var family

    let entry: NowPlayingEntry

    var body: some View {
        switch family {
        // Home Screen widgets
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        // Lock Screen widgets
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        case .accessoryInline:
            AccessoryInlineView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    NowPlayingWidget()
} timeline: {
    NowPlayingEntry.preview
    NowPlayingEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    NowPlayingWidget()
} timeline: {
    NowPlayingEntry.preview
    NowPlayingEntry.placeholder
}

#Preview("Large", as: .systemLarge) {
    NowPlayingWidget()
} timeline: {
    NowPlayingEntry.preview
    NowPlayingEntry.placeholder
}

// MARK: - Lock Screen Widget Previews

#Preview("Accessory Circular", as: .accessoryCircular) {
    NowPlayingWidget()
} timeline: {
    NowPlayingEntry.preview
    NowPlayingEntry.placeholder
}

#Preview("Accessory Rectangular", as: .accessoryRectangular) {
    NowPlayingWidget()
} timeline: {
    NowPlayingEntry.preview
    NowPlayingEntry.placeholder
}

#Preview("Accessory Inline", as: .accessoryInline) {
    NowPlayingWidget()
} timeline: {
    NowPlayingEntry.preview
    NowPlayingEntry.placeholder
}
