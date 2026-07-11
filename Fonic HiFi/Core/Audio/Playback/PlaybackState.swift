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

// MARK: - Custom Equatable

extension PlaybackState {
    /// Time tolerance for equality comparison (100ms)
    /// Only applied to moving time values, not duration metadata
    private static let timeTolerance: TimeInterval = 0.1

    public static func == (lhs: PlaybackState, rhs: PlaybackState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.stopped, .stopped):
            return true

        case let (.loading(p1), .loading(p2)):
            return abs(p1 - p2) < 0.01

        case let (.playing(t1, d1), .playing(t2, d2)):
            // Tolerance on currentTime (moving), exact on duration (metadata)
            return abs(t1 - t2) < timeTolerance && d1 == d2

        case let (.paused(t1, d1), .paused(t2, d2)):
            // Tolerance on currentTime (moving), exact on duration (metadata)
            return abs(t1 - t2) < timeTolerance && d1 == d2

        case let (.buffering(p1, t1), .buffering(p2, t2)):
            return abs(p1 - p2) < 0.01 && abs(t1 - t2) < timeTolerance

        case let (.seeking(target1, t1), .seeking(target2, t2)):
            return abs(target1 - target2) < timeTolerance && abs(t1 - t2) < timeTolerance

        case let (.error(e1, t1), .error(e2, t2)):
            // AudioError is Equatable - compare directly
            let timesEqual: Bool
            switch (t1, t2) {
            case (nil, nil): timesEqual = true
            case let (a?, b?): timesEqual = abs(a - b) < timeTolerance
            default: timesEqual = false
            }
            return e1 == e2 && timesEqual

        default:
            return false
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
