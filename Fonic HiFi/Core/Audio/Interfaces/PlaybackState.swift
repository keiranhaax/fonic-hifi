//
//  PlaybackState.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import Foundation

/// Represents all possible states of audio playback
public enum PlaybackState: Equatable, Sendable {
    /// No track loaded, initial state
    case idle
    
    /// Track is being loaded/prepared
    case loading
    
    /// Audio is currently playing
    case playing
    
    /// Playback is paused
    case paused
    
    /// Audio is being buffered (for future streaming support)
    case buffering(progress: Double)
    
    /// Seeking to a specific position
    case seeking
    
    /// Playback stopped (different from paused - position reset)
    case stopped
    
    /// An error occurred during playback
    case error(AudioError)
    
    /// Convenience properties for state checking
    public var isActive: Bool {
        switch self {
        case .playing, .buffering, .seeking:
            return true
        default:
            return false
        }
    }
    
    public var canPlay: Bool {
        switch self {
        case .paused, .stopped:
            return true
        default:
            return false
        }
    }
    
    public var canPause: Bool {
        switch self {
        case .playing, .buffering:
            return true
        default:
            return false
        }
    }
    
    public var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
}

/// Represents transitions between playback states
public enum PlaybackStateTransition: Sendable {
    case play
    case pause
    case stop
    case seek(to: TimeInterval)
    case load(url: URL)
    case error(AudioError)
    case bufferingUpdate(progress: Double)
    
    /// Validates if a transition is allowed from the current state
    /// - Parameter from: Current playback state
    /// - Returns: true if transition is valid
    public func isValid(from state: PlaybackState) -> Bool {
        switch (self, state) {
        case (.play, .paused), (.play, .stopped), (.play, .idle):
            return true
        case (.pause, .playing), (.pause, .buffering):
            return true
        case (.stop, _):
            return !state.isError && state != .idle
        case (.seek, .playing), (.seek, .paused):
            return true
        case (.load, .idle), (.load, .stopped), (.load, .error):
            return true
        case (.error, _):
            return true
        case (.bufferingUpdate, .buffering):
            return true
        default:
            return false
        }
    }
}