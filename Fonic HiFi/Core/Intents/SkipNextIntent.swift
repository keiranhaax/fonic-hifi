//
//  SkipNextIntent.swift
//  Fonic HiFi
//
//  Created by Claude on 11/26/25.
//

import AppIntents
import Foundation
import OSLog

/// App Intent for skipping to the next track
/// Conforms to AudioPlaybackIntent + LiveActivityIntent so it runs in the app process
struct SkipNextIntent: AudioPlaybackIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip to Next Track"
    static let description = IntentDescription("Skip to the next track in the queue.")

    static let openAppWhenRun: Bool = false

    private static let logger = Log.logger(.widget)

    @MainActor
    func perform() async throws -> some IntentResult {
        Self.logger.debug("SkipNextIntent perform() called")

        guard let engine = IntentDependencyProvider.shared.audioEngine else {
            Self.logger.warning("SkipNextIntent: AudioEngineFacade not available")
            return .result()
        }

        // Check if there's a next track available
        guard engine.queueState.hasNext else {
            Self.logger.info("SkipNextIntent: No next track available")
            return .result()
        }

        do {
            try await engine.playNext()
            Self.logger.info("SkipNextIntent: Skipped to next track")
        } catch {
            Self.logger.error("SkipNextIntent: Failed to skip - \(error.localizedDescription, privacy: .private)")
        }

        // Sync widget state after track change
        await IntentDependencyProvider.shared.widgetCoordinator?.syncCurrentState()

        return .result()
    }
}
