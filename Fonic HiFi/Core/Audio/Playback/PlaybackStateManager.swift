//
//  PlaybackStateManager.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/2025.
//

import Combine
import Foundation
import Observation
import OSLog

/// Observable state manager for tracking and broadcasting playback state changes
@MainActor
@Observable
public final class PlaybackStateManager {
    // MARK: - Published State

    /// Current playback state
    public private(set) var currentState: PlaybackState = .idle

    /// Whether state changes should be logged
    public var loggingEnabled: Bool = false

    // MARK: - Publishers

    /// Private publisher for state changes
    private let _statePublisher = PassthroughSubject<PlaybackStateChange, Never>()

    /// Public read-only publisher for state changes (main thread guaranteed)
    public var statePublisher: AnyPublisher<PlaybackStateChange, Never> {
        _statePublisher.receive(on: RunLoop.main).eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    private var transitionValidation: Bool = true
    private let logger = Log.logger(.playback)

    // MARK: - Initialization

    public init(
        initialState: PlaybackState = .idle,
        enableTransitionValidation: Bool = true,
        enableLogging: Bool = false,
    ) {
        currentState = initialState
        transitionValidation = enableTransitionValidation
        loggingEnabled = enableLogging
    }

    // MARK: - State Management

    /// Update the current playback state
    /// - Parameter newState: The new state to transition to
    /// - Returns: Whether the transition was successful
    @discardableResult
    public func updateState(_ newState: PlaybackState) -> Bool {
        let timestamp = Date()

        // Validate transition if enabled
        if transitionValidation, !currentState.canTransition(to: newState) {
            if loggingEnabled {
                logger.warning(
                    """
                    PlaybackStateManager: Invalid transition from \(self.currentState, privacy: .public)
                    to \(newState, privacy: .public)
                    """,
                )
            }
            return false
        }

        let oldState = currentState

        // Skip if state unchanged (prevents spam from frequent time updates)
        guard oldState != newState else {
            return true
        }

        // Update current state
        currentState = newState

        // Create change event
        let change = PlaybackStateChange(
            from: oldState,
            to: newState,
            timestamp: timestamp,
        )

        // Emit notifications
        _statePublisher.send(change)

        if loggingEnabled {
            logger.debug(
                """
                PlaybackStateManager: \(oldState, privacy: .public)
                -> \(newState, privacy: .public)
                """,
            )
        }

        return true
    }

    /// Force update state without validation (use carefully)
    public func forceUpdateState(_ newState: PlaybackState) {
        let wasValidationEnabled = transitionValidation
        transitionValidation = false
        updateState(newState)
        transitionValidation = wasValidationEnabled
    }

    /// Update only time components of current state
    public func updateTime(_ currentTime: TimeInterval, duration: TimeInterval? = nil) {
        let newState: PlaybackState

        switch currentState {
        case let .playing(previousTime, existingDuration):
            let resolvedDuration = duration ?? existingDuration
            let timeDelta = abs(currentTime - previousTime)
            let durationChanged = resolvedDuration != existingDuration

            // Debounce tiny time deltas to reduce unnecessary @Observable churn.
            if timeDelta < 0.3, !durationChanged {
                return
            }

            newState = .playing(currentTime: currentTime, duration: resolvedDuration)
        case let .paused(_, existingDuration):
            newState = .paused(currentTime: currentTime, duration: duration ?? existingDuration)
        case let .buffering(progress, _):
            newState = .buffering(progress: progress, currentTime: currentTime)
        case let .seeking(target, _):
            newState = .seeking(targetTime: target, currentTime: currentTime)
        default:
            return // No time component to update
        }

        // Update without validation since it's just a time update
        let wasValidationEnabled = transitionValidation
        transitionValidation = false
        updateState(newState)
        transitionValidation = wasValidationEnabled
    }

    /// Handle engine errors
    public func handleEngineError(_ error: AudioError, currentTime: TimeInterval? = nil) {
        updateState(.error(error, lastKnownTime: currentTime))
    }
}

// MARK: - Supporting Types

/// Represents a state change event
public struct PlaybackStateChange: Sendable {
    public let from: PlaybackState
    public let nextState: PlaybackState
    public let timestamp: Date

    public init(from: PlaybackState, to nextState: PlaybackState, timestamp: Date) {
        self.from = from
        self.nextState = nextState
        self.timestamp = timestamp
    }

    public var duration: TimeInterval {
        timestamp.timeIntervalSince1970
    }
}
