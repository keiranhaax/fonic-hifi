//
//  AudioKitEngineAdapter.swift
//  Fonic HiFi
//
//  Created by Claude on 5/30/25.
//

@preconcurrency import AudioKit
import AVFoundation
import Combine
import Foundation

/// AudioKit-based implementation of AudioEngineService with native scheduling
@MainActor
public final class AudioKitEngineAdapter: NSObject, AudioEngineService, ObservableObject {
    // MARK: - AudioKit Components

    private let engine = AudioEngine()
    private let primaryPlayer = AudioPlayer()
    private let secondaryPlayer = AudioPlayer()
    private let primaryPitch: TimePitch
    private let secondaryPitch: TimePitch
    private let mixer = Mixer()

    private var activePlayer: AudioPlayer
    private var inactivePlayer: AudioPlayer
    private var activePitch: TimePitch
    private var inactivePitch: TimePitch

    // MARK: - State Management

    private var currentFile: AVAudioFile?
    private var inactiveFile: AVAudioFile?
    private var pendingNextURL: URL?

    /// Completion handler for when playback finishes
    private var completionHandler: (() -> Void)?

    @Published public private(set) var _isPlaying = false
    @Published public private(set) var _currentTime: TimeInterval = 0
    @Published public private(set) var _duration: TimeInterval = 0
    @Published public private(set) var _volume: Float = 1.0

    private var updateTimer: Timer?
    private var configuration: AudioEngineConfiguration = .default
    private var crossfadeTask: Task<Void, Never>?
    private var currentPlaybackRate: Double = 1.0
    private var currentGainDB: Float = 0

    // MARK: - AudioEngineService Properties

    public var currentTime: TimeInterval { get async { _currentTime } }
    public var duration: TimeInterval { get async { _duration } }
    public var isPlaying: Bool { get async { _isPlaying } }
    public var volume: Float { get async { _volume } }

    public var audioFormat: AudioFormat? {
        get async {
            guard let file = currentFile else { return nil }
            return AudioFormat.from(avAudioFormat: file.fileFormat)
        }
    }

    public var isBitPerfect: Bool {
        get async {
            configuration.performanceMode == .quality && abs(currentGainDB) < .ulpOfOne
        }
    }

    // MARK: - Initialization

    public private(set) var isInitialized: Bool = false

    override public init() {
        primaryPitch = TimePitch(primaryPlayer)
        secondaryPitch = TimePitch(secondaryPlayer)
        activePlayer = primaryPlayer
        inactivePlayer = secondaryPlayer
        activePitch = primaryPitch
        inactivePitch = secondaryPitch
        super.init()
        do {
            try setupAudioKitEngine()
        } catch {
            Log.logger(.audioEngine).error("AudioKit initialization failed: \(error.localizedDescription)")
        }
    }

    public func checkInitialization() throws {
        guard isInitialized else {
            throw AudioError.engineInitializationFailed(
                reason: "AudioKit engine failed to initialize. Audio system may not be available.",
            )
        }
    }

    @MainActor deinit {
        cleanup()
    }

    // MARK: - AudioEngineService Implementation

    public func load(url: URL) async throws {
        try checkInitialization()

        crossfadeTask?.cancel()
        activePlayer.stop()
        inactivePlayer.stop()

        do {
            let avFile = try AVAudioFile(forReading: url)
            currentFile = avFile
            inactiveFile = nil
            pendingNextURL = nil
            try activePlayer.load(file: avFile)
            _duration = Double(avFile.length) / avFile.fileFormat.sampleRate
            _currentTime = 0
        } catch {
            throw AudioError.decodingFailed(reason: "Failed to load file: \(error.localizedDescription)")
        }
    }

    public func play() async throws {
        try checkInitialization()
        guard currentFile != nil else {
            throw AudioError.playbackFailed(reason: "No file loaded")
        }

        // ✅ Restart engine if stopped (e.g., after audio session interruption)
        // This fixes the "AudioPlayer's engine must be running before playback" error
        // that occurs after phone calls, Siri, or device lock
        try restartEngineIfNeeded()

        applyPlaybackRate(currentPlaybackRate)
        applyReplayGainImmediately(currentGainDB)

        activePlayer.volume = AUValue(_volume)
        activePlayer.play()
        _isPlaying = true
        startProgressPolling()
    }

    public func pause() async {
        crossfadeTask?.cancel()
        activePlayer.pause()
        inactivePlayer.pause()
        _isPlaying = false
        stopProgressPolling()
    }

    public func stop() async {
        crossfadeTask?.cancel()
        activePlayer.stop()
        inactivePlayer.stop()
        _isPlaying = false
        _currentTime = 0
        stopProgressPolling()
    }

    public func seek(to time: TimeInterval) async throws {
        guard currentFile != nil else {
            throw AudioError.playbackFailed(reason: "No file loaded")
        }

        // ✅ Restart engine if stopped before seeking
        try restartEngineIfNeeded()

        activePlayer.play(from: time)
        _currentTime = time

        if !_isPlaying {
            activePlayer.pause()
        }
    }

    public func setVolume(_ volume: Float) async {
        let clamped = max(0.0, min(1.0, volume))
        activePlayer.volume = AUValue(clamped)
        inactivePlayer.volume = AUValue(clamped)
        _volume = clamped
    }

    public func configure(with configuration: AudioEngineConfiguration) async throws {
        self.configuration = configuration
    }

    public func prepareNext(url: URL) async {
        pendingNextURL = url
        if let file = try? AVAudioFile(forReading: url) {
            inactivePlayer.stop()
            inactiveFile = file
            try? inactivePlayer.load(file: file)
        }
    }

    public func setPlaybackRate(_ rate: Double) async {
        currentPlaybackRate = rate
        applyPlaybackRate(rate)
    }

    public func applyReplayGain(_ gainDB: Float) async {
        currentGainDB = gainDB
        applyReplayGainImmediately(gainDB)
    }

    public func crossfade(to url: URL, duration: TimeInterval, playbackRate: Double, gainDB: Float) async throws {
        crossfadeTask?.cancel()

        let nextFile: AVAudioFile = if pendingNextURL == url, let prepared = inactiveFile {
            prepared
        } else {
            try AVAudioFile(forReading: url)
        }

        try inactivePlayer.load(file: nextFile)
        inactiveFile = nextFile
        pendingNextURL = nil

        currentPlaybackRate = playbackRate
        currentGainDB = gainDB
        applyPlaybackRate(playbackRate)
        applyReplayGainImmediately(gainDB)

        inactivePlayer.volume = 0
        inactivePlayer.play()
        _isPlaying = true
        startProgressPolling()

        if duration <= 0 {
            await finishCrossfade(with: nextFile)
            return
        }

        crossfadeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await performCrossfade(with: nextFile, duration: duration)
        }
    }

    public func getMetrics() async -> AudioMetrics {
        AudioMetrics(
            cpuUsage: 0.0,
            memoryUsage: 0,
            bufferUnderruns: 0,
            decodingLatency: 0.0,
            bufferFillLevel: 1.0,
            droppedFrames: 0,
            renderLatency: 0.0,
            timestamp: Date(),
        )
    }

    public func collectMetrics() async {}

    // MARK: - Private Methods

    private func setupAudioKitEngine() throws {
        mixer.addInput(primaryPitch)
        mixer.addInput(secondaryPitch)
        engine.output = mixer

        do {
            try engine.start()
            isInitialized = true
        } catch {
            isInitialized = false
            throw AudioError.engineInitializationFailed(
                reason: "AudioKit failed to start: \(error.localizedDescription)",
            )
        }
    }

    // MARK: - Engine State Management

    /// Restarts the AudioKit engine if it has stopped
    ///
    /// This is necessary after audio session interruptions (phone calls, Siri, etc.)
    /// because AVAudioEngine (which AudioKit wraps) automatically stops when interrupted.
    ///
    /// Per Apple documentation: "When the audio engine's I/O unit observes a change to the
    /// audio input or output hardware's channel count or sample rate, the audio engine stops,
    /// uninitializes itself, and issues a configuration change notification."
    ///
    /// - Throws: AudioError.engineInitializationFailed if restart fails
    private func restartEngineIfNeeded() throws {
        // Check if engine needs restart
        // Note: AudioKit's AudioEngine may not expose isRunning directly
        // We rely on isInitialized flag and attempt start if needed
        guard isInitialized else {
            Log.logger(.audioEngine).error("Engine not initialized - cannot restart")
            throw AudioError.engineInitializationFailed(
                reason: "AudioKit engine was never initialized",
            )
        }

        // Attempt to start the engine
        // If already running, AudioKit should handle this gracefully
        do {
            try engine.start()
            Log.logger(.audioEngine).debug("AudioKit engine start called (may already be running)")
        } catch {
            Log.logger(.audioEngine).error("Failed to restart AudioKit engine: \(error.localizedDescription)")
            throw AudioError.engineInitializationFailed(
                reason: "Failed to restart AudioKit engine after interruption: \(error.localizedDescription)",
            )
        }
    }

    private func startProgressPolling() {
        stopProgressPolling()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.updateProgress()
            }
        }
    }

    private func stopProgressPolling() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updateProgress() async {
        guard _isPlaying else { return }
        _currentTime = activePlayer.currentTime
        _duration = activePlayer.duration

        if _currentTime >= _duration {
            _isPlaying = false
            stopProgressPolling()
            completionHandler?()
        }
    }

    // MARK: - Completion Handler

    /// Set a completion handler for when playback finishes
    public func setCompletionHandler(_ handler: @escaping () -> Void) {
        completionHandler = handler
    }

    private func cleanup() {
        stopProgressPolling()
        engine.stop()
    }

    private func applyPlaybackRate(_ rate: Double) {
        let value = AUValue(rate)
        activePitch.rate = value
        inactivePitch.rate = value
    }

    private func applyReplayGainImmediately(_ gainDB: Float) {
        mixer.volume = AUValue(pow(10, gainDB / 20))
    }

    private func finishCrossfade(with file: AVAudioFile) async {
        activePlayer.stop()
        swap(&activePlayer, &inactivePlayer)
        swap(&activePitch, &inactivePitch)
        activePlayer.volume = AUValue(_volume)
        inactivePlayer.volume = 0
        currentFile = file
        inactiveFile = nil
        _duration = Double(file.length) / file.fileFormat.sampleRate
        _currentTime = 0
        crossfadeTask = nil
    }

    private func performCrossfade(with file: AVAudioFile, duration: TimeInterval) async {
        let steps = max(1, Int(duration / 0.02))
        let interval = duration / Double(steps)
        let activeStart = activePlayer.volume
        let inactiveStart = inactivePlayer.volume
        let inactiveTarget = AUValue(_volume)

        for step in 1 ... steps {
            guard !Task.isCancelled else { return }
            let progress = AUValue(step) / AUValue(steps)
            activePlayer.volume = activeStart * (1 - progress)
            inactivePlayer.volume = inactiveStart + (inactiveTarget - inactiveStart) * progress
            try? await Task.sleep(nanoseconds: UInt64(max(interval, 0) * 1_000_000_000))
        }

        await finishCrossfade(with: file)
    }

}

// MARK: - AudioFormat Extension

extension AudioFormat {
    static func from(avAudioFormat: AVAudioFormat) -> AudioFormat {
        let sampleRate = avAudioFormat.sampleRate
        let channels = avAudioFormat.channelCount

        if sampleRate > 48000 || channels > 2 {
            return .flac
        } else {
            return .aac
        }
    }
}
