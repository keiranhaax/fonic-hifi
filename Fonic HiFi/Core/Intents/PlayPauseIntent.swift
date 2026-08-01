//
//  PlayPauseIntent.swift
//  Fonic HiFi
//
//  Created by Claude on 11/26/25.
//

import AppIntents
import Foundation
import OSLog

/// App Intent for toggling playback state
/// Conforms to AudioPlaybackIntent + LiveActivityIntent so it runs in the app process
/// and can directly access AudioEngineFacade [Verified-Apple]
struct PlayPauseIntent: AudioPlaybackIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Play or Pause"
    static let description = IntentDescription("Toggle playback of the current track.")

    static let openAppWhenRun: Bool = false

    private static let logger = Log.logger(.widget)

    @MainActor
    func perform() async throws -> some IntentResult {
        Self.logger.debug("PlayPauseIntent perform() called")

        guard let engine = IntentDependencyProvider.shared.audioEngine else {
            Self.logger.warning("PlayPauseIntent: AudioEngineFacade not available")
            return .result()
        }

        if engine.isPlaying {
            await engine.pause()
            Self.logger.info("PlayPauseIntent: Paused playback")
        } else {
            do {
                try await engine.resume()
                Self.logger.info("PlayPauseIntent: Resumed playback")
            } catch {
                Self.logger.error("PlayPauseIntent: Failed to resume - \(error.localizedDescription, privacy: .private)")
            }
        }

        // Sync widget state after playback change
        await IntentDependencyProvider.shared.widgetCoordinator?.syncCurrentState()

        return .result()
    }
}
