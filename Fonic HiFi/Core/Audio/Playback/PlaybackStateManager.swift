//
//  PlaybackStateManager.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/2025.
//

import Foundation
import Observation
import Combine

/// Observable state manager for tracking and broadcasting playback state changes
@MainActor
@Observable
public final class PlaybackStateManager {
    
    // MARK: - Published State
    
    /// Current playback state
    public private(set) var currentState: PlaybackState = .idle
    
    /// Previous state for transition tracking
    public private(set) var previousState: PlaybackState = .idle
    
    /// Timestamp of the last state change
    public private(set) var lastStateChange: Date = Date()
    
    /// Whether state changes should be logged
    public var loggingEnabled: Bool = false
    
    // MARK: - Publishers
    
    /// Publisher for state changes
    public let statePublisher = PassthroughSubject<PlaybackStateChange, Never>()
    
    /// Publisher for state transition events
    public let transitionPublisher = PassthroughSubject<PlaybackStateTransition, Never>()
    
    // MARK: - Private Properties
    
    private var stateHistory: [PlaybackStateHistoryEntry] = []
    private let maxHistorySize: Int = 100
    private var transitionValidation: Bool = true
    
    // MARK: - Initialization
    
    public init(
        initialState: PlaybackState = .idle,
        enableTransitionValidation: Bool = true,
        enableLogging: Bool = false
    ) {
        self.currentState = initialState
        self.previousState = initialState
        self.transitionValidation = enableTransitionValidation
        self.loggingEnabled = enableLogging
        
        addToHistory(state: initialState, timestamp: Date())
    }
    
    // MARK: - State Management
    
    /// Update the current playback state
    /// - Parameter newState: The new state to transition to
    /// - Returns: Whether the transition was successful
    @discardableResult
    public func updateState(_ newState: PlaybackState) -> Bool {
        let timestamp = Date()
        
        // Validate transition if enabled
        if transitionValidation && !currentState.canTransition(to: newState) {
            if loggingEnabled {
                print("PlaybackStateManager: Invalid transition from \(currentState) to \(newState)")
            }
            return false
        }
        
        // Store previous state
        let oldState = currentState
        previousState = oldState
        
        // Update current state
        currentState = newState
        lastStateChange = timestamp
        
        // Add to history
        addToHistory(state: newState, timestamp: timestamp)
        
        // Create change event
        let change = PlaybackStateChange(
            from: oldState,
            to: newState,
            timestamp: timestamp
        )
        
        let transition = PlaybackStateTransition(
            from: oldState,
            to: newState,
            timestamp: timestamp,
            isValid: true
        )
        
        // Emit notifications
        statePublisher.send(change)
        transitionPublisher.send(transition)
        
        if loggingEnabled {
            print("PlaybackStateManager: \(oldState) -> \(newState)")
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
        case .playing(_, let existingDuration):
            newState = .playing(currentTime: currentTime, duration: duration ?? existingDuration)
        case .paused(_, let existingDuration):
            newState = .paused(currentTime: currentTime, duration: duration ?? existingDuration)
        case .buffering(let progress, _):
            newState = .buffering(progress: progress, currentTime: currentTime)
        case .seeking(let target, _):
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
    
    /// Update progress for loading/buffering states
    public func updateProgress(_ progress: Double) {
        let newState: PlaybackState
        
        switch currentState {
        case .loading:
            newState = .loading(progress: progress)
        case .buffering(_, let time):
            newState = .buffering(progress: progress, currentTime: time)
        default:
            return // No progress component to update
        }
        
        let wasValidationEnabled = transitionValidation
        transitionValidation = false
        updateState(newState)
        transitionValidation = wasValidationEnabled
    }
    
    // MARK: - State Queries
    
    /// Check if the current state matches any of the provided states
    public func isInState(_ states: PlaybackState...) -> Bool {
        return states.contains { state in
            switch (currentState, state) {
            case (.idle, .idle), (.stopped, .stopped):
                return true
            case (.loading, .loading), (.playing, .playing), (.paused, .paused):
                return true
            case (.buffering, .buffering), (.seeking, .seeking), (.error, .error):
                return true
            default:
                return false
            }
        }
    }
    
    /// Get the duration the current state has been active
    public var currentStateDuration: TimeInterval {
        return Date().timeIntervalSince(lastStateChange)
    }
    
    /// Whether the current state allows playback control
    public var canControlPlayback: Bool {
        return currentState.canTogglePlayback
    }
    
    /// Whether the current state allows seeking
    public var canSeek: Bool {
        return currentState.canSeek
    }
    
    // MARK: - History Management
    
    /// Get the state history
    public var history: [PlaybackStateHistoryEntry] {
        return stateHistory
    }
    
    /// Clear the state history
    public func clearHistory() {
        stateHistory.removeAll()
        addToHistory(state: currentState, timestamp: lastStateChange)
    }
    
    /// Get the last N state changes
    public func recentHistory(count: Int) -> [PlaybackStateHistoryEntry] {
        let startIndex = max(0, stateHistory.count - count)
        return Array(stateHistory[startIndex...])
    }
    
    private func addToHistory(state: PlaybackState, timestamp: Date) {
        let entry = PlaybackStateHistoryEntry(
            state: state,
            timestamp: timestamp
        )
        
        stateHistory.append(entry)
        
        // Trim history if it exceeds max size
        if stateHistory.count > maxHistorySize {
            stateHistory.removeFirst(stateHistory.count - maxHistorySize)
        }
    }
    
    // MARK: - Integration Helpers
    
    /// Sync state from an audio engine
    public func syncFromEngine(_ engine: AudioEngineService) async {
        let isPlaying = await engine.isPlaying
        let currentTime = await engine.currentTime
        let duration = await engine.duration
        
        let newState: PlaybackState
        if isPlaying {
            newState = .playing(currentTime: currentTime, duration: duration)
        } else if currentTime > 0 {
            newState = .paused(currentTime: currentTime, duration: duration)
        } else {
            newState = .stopped
        }
        
        updateState(newState)
    }
    
    /// Handle engine state changes
    public func handleEngineStateChange(
        isPlaying: Bool,
        currentTime: TimeInterval,
        duration: TimeInterval,
        isBuffering: Bool = false,
        bufferProgress: Double = 0.0
    ) {
        let newState: PlaybackState
        
        if isBuffering {
            newState = .buffering(progress: bufferProgress, currentTime: currentTime)
        } else if isPlaying {
            newState = .playing(currentTime: currentTime, duration: duration)
        } else if currentTime > 0 {
            newState = .paused(currentTime: currentTime, duration: duration)
        } else {
            newState = .stopped
        }
        
        updateState(newState)
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
    public let to: PlaybackState
    public let timestamp: Date
    
    public var duration: TimeInterval {
        return timestamp.timeIntervalSince1970
    }
}

/// Represents a state transition event with validation info
public struct PlaybackStateTransition: Sendable {
    public let from: PlaybackState
    public let to: PlaybackState
    public let timestamp: Date
    public let isValid: Bool
    
    public var isInvalid: Bool { !isValid }
}

/// Historical state entry
public struct PlaybackStateHistoryEntry: Sendable, Identifiable {
    public let id = UUID()
    public let state: PlaybackState
    public let timestamp: Date
    
    public var age: TimeInterval {
        return Date().timeIntervalSince(timestamp)
    }
}

// MARK: - Convenience Extensions

extension PlaybackStateManager {
    /// Quick state transitions
    public func transitionToPlaying(currentTime: TimeInterval = 0, duration: TimeInterval = 0) {
        updateState(.playing(currentTime: currentTime, duration: duration))
    }
    
    public func transitionToPaused(currentTime: TimeInterval = 0, duration: TimeInterval = 0) {
        updateState(.paused(currentTime: currentTime, duration: duration))
    }
    
    public func transitionToLoading(progress: Double = 0) {
        updateState(.loading(progress: progress))
    }
    
    public func transitionToStopped() {
        updateState(.stopped)
    }
    
    public func transitionToIdle() {
        updateState(.idle)
    }
    
    public func transitionToBuffering(progress: Double, currentTime: TimeInterval = 0) {
        updateState(.buffering(progress: progress, currentTime: currentTime))
    }
    
    public func transitionToSeeking(targetTime: TimeInterval, currentTime: TimeInterval = 0) {
        updateState(.seeking(targetTime: targetTime, currentTime: currentTime))
    }
    
    public func transitionToError(_ error: AudioError, lastKnownTime: TimeInterval? = nil) {
        updateState(.error(error, lastKnownTime: lastKnownTime))
    }
}