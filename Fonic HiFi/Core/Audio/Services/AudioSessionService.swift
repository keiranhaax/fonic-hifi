//
//  AudioSessionService.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import AVFoundation
import Foundation

/// Types of audio interruptions that can occur
public enum AudioInterruptionType: Sendable {
    case began
    case ended(shouldResume: Bool)
}

/// Reasons for audio route changes
public enum AudioRouteChangeReason: Sendable {
    case newDeviceAvailable
    case oldDeviceUnavailable
    case categoryChange
    case override
    case wakeFromSleep
    case noSuitableRouteForCategory
    case routeConfigurationChange
    case unknown

    /// Initialize from AVAudioSession route change reason
    init(from reason: AVAudioSession.RouteChangeReason) {
        switch reason {
        case .newDeviceAvailable:
            self = .newDeviceAvailable
        case .oldDeviceUnavailable:
            self = .oldDeviceUnavailable
        case .categoryChange:
            self = .categoryChange
        case .override:
            self = .override
        case .wakeFromSleep:
            self = .wakeFromSleep
        case .noSuitableRouteForCategory:
            self = .noSuitableRouteForCategory
        case .routeConfigurationChange:
            self = .routeConfigurationChange
        default:
            self = .unknown
        }
    }
}

/// Information about an audio route change
public struct AudioRouteChange: Sendable {
    public let reason: AudioRouteChangeReason
    public let previousRoute: String?
    public let currentRoute: String
}

/// Protocol defining audio session management capabilities
@MainActor
public protocol AudioSessionService: Sendable {
    // MARK: - Configuration

    /// Configure the audio session for music playback
    /// - Throws: AudioError if configuration fails
    func configureAudioSession() async throws

    /// Activate the audio session
    /// - Throws: AudioError if activation fails
    func activateAudioSession() async throws

    /// Set the preferred hardware sample rate.
    /// The system may choose a different active sample rate depending on route capabilities.
    /// - Parameter sampleRate: Preferred sample rate in Hz.
    func setPreferredSampleRate(_ sampleRate: Double) async

    /// Deactivate the audio session
    /// - Throws: AudioError if deactivation fails
    func deactivateAudioSession() async throws

    // MARK: - Session State

    /// Check if the audio session is currently active
    var isSessionActive: Bool { get async }

    /// Get the current audio route
    var currentRoute: String { get async }

    /// Check if background audio is configured
    var isBackgroundAudioEnabled: Bool { get async }

    // MARK: - Interruption Handling

    /// Handle audio session interruptions (calls, alarms, etc.)
    /// - Parameter interruption: Type of interruption
    func handleInterruption(_ interruption: AudioInterruptionType) async

    /// Handle audio route changes (headphones, Bluetooth, etc.)
    /// - Parameter change: Route change information
    func handleRouteChange(_ change: AudioRouteChange) async

    // MARK: - Now Playing

    /// Update Now Playing info for Control Center and lock screen
    /// - Parameter info: Dictionary of now playing information
    func updateNowPlayingInfo(_ info: [String: Any]) async

    /// Clear Now Playing info
    func clearNowPlayingInfo() async

    // MARK: - Remote Commands

    /// Enable remote control commands (play, pause, skip, etc.)
    func enableRemoteCommands() async

    /// Disable remote control commands
    func disableRemoteCommands() async

    // MARK: - Audio Output

    /// Get available audio output routes
    /// - Returns: Array of available output devices
    func getAvailableOutputs() async -> [AudioDevice]

    /// Set preferred audio output
    /// - Parameter device: The audio device to use
    /// - Throws: AudioError if selection fails
    func setPreferredOutput(_ device: AudioDevice) async throws
}

/// Delegate for audio session events
@MainActor
public protocol AudioSessionDelegate: AnyObject {
    /// Called when an interruption occurs
    func audioSessionDidInterrupt(_ interruption: AudioInterruptionType) async

    /// Called when the audio route changes
    func audioSessionRouteDidChange(_ change: AudioRouteChange) async

    /// Called when a remote command is received
    func audioSessionDidReceiveCommand(_ command: RemoteCommand) async
}

/// Remote control commands
public enum RemoteCommand: Sendable {
    case play
    case pause
    case stop
    case togglePlayPause
    case nextTrack
    case previousTrack
    case seekForward
    case seekBackward
    case changePlaybackRate(Float)
    case seek(to: TimeInterval)
    case skipForward(TimeInterval)
    case skipBackward(TimeInterval)
    case changeRepeatMode
    case changeShuffleMode
    case like
    case dislike
    case bookmark
}

// MARK: - CustomStringConvertible Conformance

extension AudioRouteChangeReason: CustomStringConvertible {
    public var description: String {
        switch self {
        case .newDeviceAvailable:
            "newDeviceAvailable"
        case .oldDeviceUnavailable:
            "oldDeviceUnavailable"
        case .categoryChange:
            "categoryChange"
        case .override:
            "override"
        case .wakeFromSleep:
            "wakeFromSleep"
        case .noSuitableRouteForCategory:
            "noSuitableRouteForCategory"
        case .routeConfigurationChange:
            "routeConfigurationChange"
        case .unknown:
            "unknown"
        }
    }
}

extension RemoteCommand: CustomStringConvertible {
    public var description: String {
        switch self {
        case .play:
            "play"
        case .pause:
            "pause"
        case .stop:
            "stop"
        case .togglePlayPause:
            "togglePlayPause"
        case .nextTrack:
            "nextTrack"
        case .previousTrack:
            "previousTrack"
        case .seekForward:
            "seekForward"
        case .seekBackward:
            "seekBackward"
        case let .changePlaybackRate(rate):
            "changePlaybackRate(\(rate))"
        case let .seek(time):
            "seek(to: \(time))"
        case let .skipForward(interval):
            "skipForward(\(interval))"
        case let .skipBackward(interval):
            "skipBackward(\(interval))"
        case .changeRepeatMode:
            "changeRepeatMode"
        case .changeShuffleMode:
            "changeShuffleMode"
        case .like:
            "like"
        case .dislike:
            "dislike"
        case .bookmark:
            "bookmark"
        }
    }
}
