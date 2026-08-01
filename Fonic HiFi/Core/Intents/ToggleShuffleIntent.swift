//
//  ToggleShuffleIntent.swift
//  Fonic HiFi
//
//  Created by Claude on 11/26/25.
//

import AppIntents
import Foundation
import OSLog

/// App Intent for toggling shuffle mode
/// Conforms to LiveActivityIntent so it runs in the app process
struct ToggleShuffleIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Toggle Shuffle"
    static let description = IntentDescription("Toggle shuffle mode for the playback queue.")

    static let openAppWhenRun: Bool = false

    private static let logger = Log.logger(.widget)

    @MainActor
    func perform() async throws -> some IntentResult {
        Self.logger.debug("ToggleShuffleIntent perform() called")

        guard let engine = IntentDependencyProvider.shared.audioEngine else {
            Self.logger.warning("ToggleShuffleIntent: AudioEngineFacade not available")
            return .result()
        }

        // Toggle shuffle mode (off -> random -> smart -> off)
        let currentMode = engine.queueState.shuffleMode
        let newMode: QueueShuffleMode = currentMode.isActive ? .off : .random

        engine.setShuffleMode(newMode)

        Self.logger.info("ToggleShuffleIntent: Shuffle mode set to \(newMode.isActive ? "on" : "off", privacy: .public)")

        // Sync widget state after shuffle change
        await IntentDependencyProvider.shared.widgetCoordinator?.syncCurrentState()

        return .result()
    }
}
