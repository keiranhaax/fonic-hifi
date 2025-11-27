//
//  WidgetIntents.swift
//  Fonic HiFi Widget
//
//  Stub declarations for intents used by widget buttons.
//  The actual implementations live in the main app and run in the app process.
//  Widget extension only needs these declarations to use Button(intent:).
//

import AppIntents
import Foundation

// MARK: - Play/Pause Intent

/// Stub for PlayPauseIntent - actual implementation in main app
struct PlayPauseIntent: AudioPlaybackIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Play or Pause"
    static let description = IntentDescription("Toggle playback of the current track.")
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        // This implementation won't be called - iOS routes to the main app
        .result()
    }
}

// MARK: - Skip Next Intent

/// Stub for SkipNextIntent - actual implementation in main app
struct SkipNextIntent: AudioPlaybackIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip to Next Track"
    static let description = IntentDescription("Skip to the next track in the queue.")
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}

// MARK: - Skip Previous Intent

/// Stub for SkipPreviousIntent - actual implementation in main app
struct SkipPreviousIntent: AudioPlaybackIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip to Previous Track"
    static let description = IntentDescription("Skip to the previous track in the queue.")
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}

// MARK: - Toggle Shuffle Intent

/// Stub for ToggleShuffleIntent - actual implementation in main app
struct ToggleShuffleIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Toggle Shuffle"
    static let description = IntentDescription("Toggle shuffle mode for the playback queue.")
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}
