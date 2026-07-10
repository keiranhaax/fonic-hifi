//
//  NowPlayingTimelineProvider.swift
//  Fonic HiFi Widget
//
//  Created by Claude on 11/26/25.
//

import Foundation
import WidgetKit

/// Timeline provider that reads playback state from App Group
/// Uses a standard TimelineProvider; button interactivity is supplied by App Intents.
struct NowPlayingTimelineProvider: TimelineProvider {
    typealias Entry = NowPlayingEntry

    // MARK: - TimelineProvider

    /// Placeholder for widget gallery
    func placeholder(in context: Context) -> NowPlayingEntry {
        .placeholder
    }

    /// Snapshot for widget gallery preview
    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        if context.isPreview {
            completion(.preview)
        } else {
            completion(.fromAppGroup())
        }
    }

    /// Generate timeline entries
    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        let entry = NowPlayingEntry.fromAppGroup()

        // Determine next refresh time based on playback state
        let refreshDate: Date
        if entry.isPlaying {
            // During playback, refresh more frequently for progress updates
            // But not too often - iOS limits reloads (~40-70/day)
            refreshDate = Date().addingTimeInterval(60)
        } else {
            // When paused/stopped, refresh less frequently
            refreshDate = Date().addingTimeInterval(300)
        }

        let timeline = Timeline(
            entries: [entry],
            policy: .after(refreshDate)
        )

        completion(timeline)
    }
}
