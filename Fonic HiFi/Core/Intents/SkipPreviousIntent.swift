//
//  SkipPreviousIntent.swift
//  Fonic HiFi
//
//  Created by Claude on 11/26/25.
//

import AppIntents
import Foundation
import OSLog

/// App Intent for skipping to the previous track
/// Conforms to AudioPlaybackIntent + LiveActivityIntent so it runs in the app process
struct SkipPreviousIntent: AudioPlaybackIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip to Previous Track"
    static let description = IntentDescription("Skip to the previous track in the queue.")

    static let openAppWhenRun: Bool = false

    private static let logger = Log.logger(.widget)

    @MainActor
    func perform() async throws -> some IntentResult {
        Self.logger.debug("SkipPreviousIntent perform() called")

        guard let engine = IntentDependencyProvider.shared.audioEngine else {
            Self.logger.warning("SkipPreviousIntent: AudioEngineFacade not available")
            return .result()
        }

        // Check if there's a previous track available
        guard engine.queueState.hasPrevious else {
            Self.logger.info("SkipPreviousIntent: No previous track available")
            return .result()
        }

        do {
            try await engine.playPrevious()
            Self.logger.info("SkipPreviousIntent: Skipped to previous track")
        } catch {
            Self.logger.error("SkipPreviousIntent: Failed to skip - \(error.localizedDescription)")
        }

        // Sync widget state after track change
        await IntentDependencyProvider.shared.widgetCoordinator?.syncCurrentState()

        return .result()
    }
}
