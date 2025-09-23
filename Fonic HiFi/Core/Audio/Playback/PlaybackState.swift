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
            return true
        default:
            return false
        }
    }
    
    /// Whether the state represents an active operation
    public var isActive: Bool {
        switch self {
        case .idle, .stopped, .error:
            return false
        default:
            return true
        }
    }
    
    /// Current playback time if available
    public var currentTime: TimeInterval? {
        switch self {
        case .playing(let time, _), .paused(let time, _):
            return time
        case .buffering(_, let time), .seeking(_, let time):
            return time
        case .error(_, let time):
            return time
        default:
            return nil
        }
    }
    
    /// Track duration if available
    public var duration: TimeInterval? {
        switch self {
        case .playing(_, let duration), .paused(_, let duration):
            return duration
        default:
            return nil
        }
    }
    
    /// Progress percentage (0.0 - 1.0) if available
    public var progress: Double? {
        switch self {
        case .loading(let progress), .buffering(let progress, _):
            return progress
        case .playing(let current, let duration), .paused(let current, let duration):
            return duration > 0 ? current / duration : 0.0
        default:
            return nil
        }
    }
    
    /// Whether the state allows seeking
    public var canSeek: Bool {
        switch self {
        case .playing, .paused:
            return true
        default:
            return false
        }
    }
    
    /// Whether the state allows play/pause toggle
    public var canTogglePlayback: Bool {
        switch self {
        case .playing, .paused:
            return true
        default:
            return false
        }
    }
    
    /// Human-readable description of the current state
    public var description: String {
        switch self {
        case .idle:
            return "Idle"
        case .loading(let progress):
            return "Loading (\(Int(progress * 100))%)"
        case .playing(let current, let duration):
            return "Playing \(formatTime(current))/\(formatTime(duration))"
        case .paused(let current, let duration):
            return "Paused \(formatTime(current))/\(formatTime(duration))"
        case .stopped:
            return "Stopped"
        case .buffering(let progress, let current):
            return "Buffering (\(Int(progress * 100))%) at \(formatTime(current))"
        case .seeking(let target, let current):
            return "Seeking from \(formatTime(current)) to \(formatTime(target))"
        case .error(let error, let time):
            let timeStr = time.map { " at \(formatTime($0))" } ?? ""
            return "Error: \(error.localizedDescription)\(timeStr)"
        }
    }
    
    // MARK: - Helper Methods
    
    /// Create a new state with updated time while preserving other data
    public func withUpdatedTime(_ newTime: TimeInterval) -> PlaybackState {
        switch self {
        case .playing(_, let duration):
            return .playing(currentTime: newTime, duration: duration)
        case .paused(_, let duration):
            return .paused(currentTime: newTime, duration: duration)
        case .buffering(let progress, _):
            return .buffering(progress: progress, currentTime: newTime)
        case .seeking(let target, _):
            return .seeking(targetTime: target, currentTime: newTime)
        default:
            return self
        }
    }
    
    /// Create a new state with updated duration while preserving other data
    public func withUpdatedDuration(_ newDuration: TimeInterval) -> PlaybackState {
        switch self {
        case .playing(let current, _):
            return .playing(currentTime: current, duration: newDuration)
        case .paused(let current, _):
            return .paused(currentTime: current, duration: newDuration)
        default:
            return self
        }
    }
    
    /// Create a new state with updated progress while preserving other data
    public func withUpdatedProgress(_ newProgress: Double) -> PlaybackState {
        switch self {
        case .loading:
            return .loading(progress: newProgress)
        case .buffering(_, let time):
            return .buffering(progress: newProgress, currentTime: time)
        default:
            return self
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

extension PlaybackState {
    /// Whether a transition to the given state is valid
    public func canTransition(to newState: PlaybackState) -> Bool {
        switch (self, newState) {
        // From idle
        case (.idle, .loading), (.idle, .error):
            return true
            
        // From loading
        case (.loading, .playing), (.loading, .paused), (.loading, .stopped), (.loading, .error):
            return true
            
        // From playing
        case (.playing, .paused), (.playing, .stopped), (.playing, .buffering), (.playing, .seeking), (.playing, .error):
            return true
            
        // From paused
        case (.paused, .playing), (.paused, .stopped), (.paused, .seeking), (.paused, .error):
            return true
            
        // From stopped
        case (.stopped, .idle), (.stopped, .loading), (.stopped, .error):
            return true
            
        // From buffering
        case (.buffering, .playing), (.buffering, .paused), (.buffering, .stopped), (.buffering, .error):
            return true
            
        // From seeking
        case (.seeking, .playing), (.seeking, .paused), (.seeking, .stopped), (.seeking, .error):
            return true
            
        // From error
        case (.error, .idle), (.error, .loading), (.error, .stopped):
            return true
            
        // Same state updates (time/progress changes)
        case (.loading, .loading), (.playing, .playing), (.paused, .paused), (.buffering, .buffering), (.seeking, .seeking):
            return true
            
        default:
            return false
        }
    }
    
    /// Get the next logical state for a play command
    public var nextPlayState: PlaybackState? {
        switch self {
        case .paused(let time, let duration):
            return .playing(currentTime: time, duration: duration)
        case .stopped, .idle:
            return .loading()
        default:
            return nil
        }
    }
    
    /// Get the next logical state for a pause command
    public var nextPauseState: PlaybackState? {
        switch self {
        case .playing(let time, let duration):
            return .paused(currentTime: time, duration: duration)
        default:
            return nil
        }
    }
    
    /// Get the next logical state for a stop command
    public var nextStopState: PlaybackState {
        return .stopped
    }
}