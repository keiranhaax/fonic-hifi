//
//  AudioEngineService.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import Foundation

/// Describes the transition that was adopted for a previously prepared track.
///
/// Only `renderBoundary` represents an engine-scheduled gapless boundary.
/// `preloadedFallback` avoids redundant decoding but still starts the track
/// after the prior completion callback and must not be presented as gapless
/// evidence.
public enum PreparedTrackTransition: Sendable, Equatable {
    case none
    case preloadedFallback
    case renderBoundary

    public var wasAdopted: Bool {
        self != .none
    }
}

/// Core protocol defining the interface for all audio playback engines.
/// Implementations may use AVAudioEngine, AudioKit, or other vetted engines
/// based on format requirements and performance characteristics.
@MainActor
public protocol AudioEngineService: Sendable {
    // MARK: - Properties

    /// Current playback time in seconds
    var currentTime: TimeInterval { get async }

    /// Total duration of the current track in seconds
    var duration: TimeInterval { get async }

    /// Indicates whether audio is currently playing
    var isPlaying: Bool { get async }

    /// Current volume level (0.0 to 1.0)
    var volume: Float { get async }

    /// Current audio format being played
    var audioFormat: AudioFormat? { get async }

    /// Indicates whether the current software configuration is eligible for
    /// bit-perfect playback. This is not physical-output measurement.
    var isBitPerfect: Bool { get async }

    /// Declares whether this engine can provide measured diagnostics.
    var metricsAvailability: AudioMetricsAvailability { get }

    // MARK: - Playback Control

    /// Load and prepare a track for playback
    /// - Parameter url: The file URL of the audio track
    /// - Throws: `AudioError` if the track cannot be loaded
    func load(url: URL) async throws

    /// Start or resume playback
    /// - Throws: `AudioError` if playback cannot be started
    func play() async throws

    /// Pause playback
    func pause() async

    /// Stop playback and reset to the beginning
    func stop() async

    /// Seek to a specific time
    /// - Parameter time: Target time in seconds
    /// - Throws: `AudioError` if seek fails
    func seek(to time: TimeInterval) async throws

    /// Set the playback volume
    /// - Parameter volume: Volume level (0.0 to 1.0)
    func setVolume(_ volume: Float) async

    /// Adjust playback rate multiplier
    /// - Parameter rate: Playback speed (1.0 = normal)
    func setPlaybackRate(_ rate: Double) async

    /// Apply replay gain offset in decibels
    /// - Parameter gainDB: Gain change in dB
    func applyReplayGain(_ gainDB: Float) async

    // MARK: - Advanced Features

    /// Configure the engine for specific requirements
    /// - Parameter configuration: Engine configuration settings
    /// - Throws: `AudioError` if configuration fails
    func configure(with configuration: AudioEngineConfiguration) async throws

    /// Prepare the next track for gapless playback
    /// - Parameter url: The file URL of the next track
    func prepareNext(url: URL) async

    /// Invalidate any next-track preparation after the queue changes.
    func invalidatePreparedTransition() async

    /// Adopt a previously prepared next track.
    ///
    /// - Returns: The quality of the adopted transition. Callers must not treat
    ///   a `.preloadedFallback` result as render-boundary gapless evidence.
    func consumePreparedTransition(to url: URL) async -> PreparedTrackTransition

    /// Crossfade to the given track with configurable parameters
    /// - Parameters:
    ///   - url: File URL of the next track
    ///   - duration: Crossfade duration in seconds
    ///   - playbackRate: Playback speed for the next track
    ///   - gainDB: Replay gain offset in decibels
    func crossfade(to url: URL, duration: TimeInterval, playbackRate: Double, gainDB: Float) async throws

    /// Get the currently available measured audio metrics.
    ///
    /// Engines that declare `.unavailable` return `nil`; callers must not
    /// substitute zero-valued metrics and present them as measurements.
    func availableMetrics() async -> AudioMetrics?

    /// Collect and store audio metrics for analysis
    func collectMetrics() async

    /// Set a completion handler to be called when playback finishes naturally
    /// - Parameter handler: Closure to invoke when track ends
    func setCompletionHandler(_ handler: @escaping () -> Void)

    // MARK: - Equalizer

    /// Apply equalizer configuration to the audio output
    /// Default implementation is no-op for engines that don't support EQ
    func applyEQ(_ configuration: EqualizerConfiguration) async throws

    /// Whether this engine supports EQ processing
    var supportsEQ: Bool { get async }
}

/// Extension providing default implementations
public extension AudioEngineService {
    /// Default implementation returns false for bit-perfect
    var isBitPerfect: Bool {
        get async { false }
    }

    var metricsAvailability: AudioMetricsAvailability {
        .unavailable
    }

    func availableMetrics() async -> AudioMetrics? {
        nil
    }

    /// Default implementation does nothing for prepareNext
    func prepareNext(url _: URL) async {
        // Optional implementation
    }

    func invalidatePreparedTransition() async {
        // Optional implementation
    }

    func consumePreparedTransition(to _: URL) async -> PreparedTrackTransition {
        .none
    }

    /// Default playback rate setter does nothing
    func setPlaybackRate(_: Double) async {
        // Optional implementation
    }

    /// Default replay gain application does nothing
    func applyReplayGain(_: Float) async {
        // Optional implementation
    }

    /// Default crossfade loads and plays the new track immediately
    func crossfade(to url: URL, duration _: TimeInterval, playbackRate: Double, gainDB: Float) async throws {
        try await load(url: url)
        await setPlaybackRate(playbackRate)
        await applyReplayGain(gainDB)
        try await play()
    }

    /// Default implementation does nothing for collectMetrics
    func collectMetrics() async {
        // Optional implementation
    }

    /// Default implementation does nothing for setCompletionHandler
    func setCompletionHandler(_: @escaping () -> Void) {
        // Optional implementation
    }

    /// Default implementation does nothing for applyEQ
    func applyEQ(_: EqualizerConfiguration) async throws {
        // Default no-op for engines that don't support EQ
    }

    /// Default implementation returns false for supportsEQ
    var supportsEQ: Bool {
        get async { false }
    }
}
