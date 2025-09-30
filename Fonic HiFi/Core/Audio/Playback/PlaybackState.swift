//
//  PlaybackState.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/2025.
//

import Foundation

/// Comprehensive playback state with associated data
public enum PlaybackState: Sendable, Equatable, CustomStringConvertible {
    /// Engine is idle, no track loaded
    case idle

    /// Loading track or preparing for playback
    case loading(progress: Double = 0.0)

    /// Currently playing audio
    case playing(currentTime: TimeInterval, duration: TimeInterval)

    /// Playback is paused
    case paused(currentTime: TimeInterval, duration: TimeInterval)

    /// Playback has been stopped
    case stopped

    /// Buffering data (for streaming)
    case buffering(progress: Double, currentTime: TimeInterval)

    /// Seeking to a new position
    case seeking(targetTime: TimeInterval, currentTime: TimeInterval)

    /// An error occurred during playback
    case error(AudioError, lastKnownTime: TimeInterval?)

    // MARK: - Computed Properties

    /// Whether audio is actively playing
    public var isPlaying: Bool {
        if case .playing = self { return true }
        return false
    }

    /// Whether playback is paused
    public var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }

    /// Whether the engine is idle or stopped
    public var isIdle: Bool {
        switch self {
        case .idle, .stopped:
            true
        default:
            false
        }
    }

    /// Whether the state represents an active operation
    public var isActive: Bool {
        switch self {
        case .idle, .stopped, .error:
            false
        default:
            true
        }
    }

    /// Current playback time if available
    public var currentTime: TimeInterval? {
        switch self {
        case let .playing(time, _), let .paused(time, _):
            time
        case let .buffering(_, time), let .seeking(_, time):
            time
        case let .error(_, time):
            time
        default:
            nil
        }
    }

    /// Track duration if available
    public var duration: TimeInterval? {
        switch self {
        case let .playing(_, duration), let .paused(_, duration):
            duration
        default:
            nil
        }
    }

    /// Progress percentage (0.0 - 1.0) if available
    public var progress: Double? {
        switch self {
        case let .loading(progress), let .buffering(progress, _):
            progress
        case let .playing(current, duration), let .paused(current, duration):
            duration > 0 ? current / duration : 0.0
        default:
            nil
        }
    }

    /// Whether the state allows seeking
    public var canSeek: Bool {
        switch self {
        case .playing, .paused:
            true
        default:
            false
        }
    }

    /// Whether the state allows play/pause toggle
    public var canTogglePlayback: Bool {
        switch self {
        case .playing, .paused:
            true
        default:
            false
        }
    }

    /// Human-readable description of the current state
    public var description: String {
        switch self {
        case .idle:
            return "Idle"
        case let .loading(progress):
            return "Loading (\(Int(progress * 100))%)"
        case let .playing(current, duration):
            return "Playing \(formatTime(current))/\(formatTime(duration))"
        case let .paused(current, duration):
            return "Paused \(formatTime(current))/\(formatTime(duration))"
        case .stopped:
            return "Stopped"
        case let .buffering(progress, current):
            return "Buffering (\(Int(progress * 100))%) at \(formatTime(current))"
        case let .seeking(target, current):
            return "Seeking from \(formatTime(current)) to \(formatTime(target))"
        case let .error(error, time):
            let timeStr = time.map { " at \(formatTime($0))" } ?? ""
            return "Error: \(error.localizedDescription)\(timeStr)"
        }
    }

    // MARK: - Helper Methods

    /// Create a new state with updated time while preserving other data
    public func withUpdatedTime(_ newTime: TimeInterval) -> PlaybackState {
        switch self {
        case let .playing(_, duration):
            .playing(currentTime: newTime, duration: duration)
        case let .paused(_, duration):
            .paused(currentTime: newTime, duration: duration)
        case let .buffering(progress, _):
            .buffering(progress: progress, currentTime: newTime)
        case let .seeking(target, _):
            .seeking(targetTime: target, currentTime: newTime)
        default:
            self
        }
    }

    /// Create a new state with updated duration while preserving other data
    public func withUpdatedDuration(_ newDuration: TimeInterval) -> PlaybackState {
        switch self {
        case let .playing(current, _):
            .playing(currentTime: current, duration: newDuration)
        case let .paused(current, _):
            .paused(currentTime: current, duration: newDuration)
        default:
            self
        }
    }

    /// Create a new state with updated progress while preserving other data
    public func withUpdatedProgress(_ newProgress: Double) -> PlaybackState {
        switch self {
        case .loading:
            .loading(progress: newProgress)
        case let .buffering(_, time):
            .buffering(progress: newProgress, currentTime: time)
        default:
            self
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - State Transitions

public extension PlaybackState {
    /// Whether a transition to the given state is valid
    func canTransition(to newState: PlaybackState) -> Bool {
        switch (self, newState) {
        // From idle
        case (.idle, .loading), (.idle, .error):
            true

        // From loading
        case (.loading, .playing), (.loading, .paused), (.loading, .stopped), (.loading, .error):
            true

        // From playing
        case (.playing, .paused), (.playing, .stopped), (.playing, .buffering), (.playing, .seeking), (.playing, .error):
            true

        // From paused
        case (.paused, .playing), (.paused, .stopped), (.paused, .seeking), (.paused, .error):
            true

        // From stopped
        case (.stopped, .idle), (.stopped, .loading), (.stopped, .error):
            true

        // From buffering
        case (.buffering, .playing), (.buffering, .paused), (.buffering, .stopped), (.buffering, .error):
            true

        // From seeking
        case (.seeking, .playing), (.seeking, .paused), (.seeking, .stopped), (.seeking, .error):
            true

        // From error
        case (.error, .idle), (.error, .loading), (.error, .stopped):
            true

        // Same state updates (time/progress changes)
        case (.loading, .loading), (.playing, .playing), (.paused, .paused), (.buffering, .buffering), (.seeking, .seeking):
            true

        default:
            false
        }
    }

    /// Get the next logical state for a play command
    var nextPlayState: PlaybackState? {
        switch self {
        case let .paused(time, duration):
            .playing(currentTime: time, duration: duration)
        case .stopped, .idle:
            .loading()
        default:
            nil
        }
    }

    /// Get the next logical state for a pause command
    var nextPauseState: PlaybackState? {
        switch self {
        case let .playing(time, duration):
            .paused(currentTime: time, duration: duration)
        default:
            nil
        }
    }

    /// Get the next logical state for a stop command
    var nextStopState: PlaybackState {
        .stopped
    }
}
