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
import OSLog

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
    private enum PlayerSlot: Sendable, Equatable {
        case primary
        case secondary
    }

    private var playbackGeneration: UUID?
    private var pendingCompletion: (generation: UUID, slot: PlayerSlot)?

    @Published public private(set) var _isPlaying = false
    @Published public private(set) var _currentTime: TimeInterval = 0
    @Published public private(set) var _duration: TimeInterval = 0
    @Published public private(set) var _volume: Float = 1.0

    private var configuration: AudioEngineConfiguration = .default
    private var crossfadeTask: Task<Void, Never>?
    private var crossfadeGeneration: UUID?
    private var crossfadeSleeper: @MainActor (Swift.Duration) async throws -> Void = {
        try await Task.sleep(for: $0)
    }
    private var currentPlaybackRate: Double = 1.0
    private var currentGainDB: Float = 0

    // MARK: - AudioEngineService Properties

    public var currentTime: TimeInterval {
        get async {
            _isPlaying ? activePlayer.currentTime : _currentTime
        }
    }
    public var duration: TimeInterval { get async { _duration } }
    public var isPlaying: Bool { get async { _isPlaying } }
    public var volume: Float { get async { _volume } }

    public var audioFormat: AudioFormat? {
        get async {
            guard let url = currentFile?.url else { return nil }
            return AudioFormat.from(url: url) ?? .unknown
        }
    }

    public var isBitPerfect: Bool {
        get async {
            // Unified engine contract: loaded track, no engine-side processing,
            // unity volume, and no detectable file-to-output rate conversion.
            // Performance mode is a preference, not signal-path evidence.
            guard let file = currentFile else { return false }
            let outputSampleRate = engine.avEngine.outputNode.outputFormat(forBus: 0).sampleRate
            return file.processingFormat.sampleRate == outputSampleRate &&
                currentPlaybackRate == 1 &&
                abs(currentGainDB) < .ulpOfOne &&
                _volume == 1
        }
    }

    public func playbackFormatEvidence() async -> AudioEngineFormatEvidence? {
        let outputFormat = engine.avEngine.outputNode.outputFormat(forBus: 0)
        return AudioEngineFormatEvidence(
            isTrackLoaded: currentFile != nil,
            loadedSampleRate: currentFile?.processingFormat.sampleRate,
            loadedChannelCount: currentFile.map { Int($0.processingFormat.channelCount) },
            engineOutputSampleRate: outputFormat.sampleRate > 0 ? outputFormat.sampleRate : nil,
            engineOutputChannelCount: outputFormat.channelCount > 0 ? Int(outputFormat.channelCount) : nil,
            hasEngineProcessing: currentPlaybackRate != 1 || abs(currentGainDB) >= .ulpOfOne
        )
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
            Log.logger(.audioEngine).error("AudioKit initialization failed: \(error.localizedDescription, privacy: .private)")
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

        cancelCrossfade(rearmSourceCompletion: false)
        invalidatePlaybackCompletion()
        activePlayer.stop()
        inactivePlayer.stop()
        _isPlaying = false

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
        armPlaybackCompletion(for: activePlayerSlot)
        activePlayer.play()
        _isPlaying = true
    }

    public func pause() async {
        cancelCrossfade(rearmSourceCompletion: false)
        _currentTime = activePlayer.currentTime
        invalidatePlaybackCompletion()
        activePlayer.pause()
        inactivePlayer.pause()
        _isPlaying = false
    }

    public func stop() async {
        cancelCrossfade(rearmSourceCompletion: false)
        invalidatePlaybackCompletion()
        activePlayer.stop()
        inactivePlayer.stop()
        engine.stop()
        _isPlaying = false
        _currentTime = 0
    }

    public func seek(to time: TimeInterval) async throws {
        guard currentFile != nil else {
            throw AudioError.playbackFailed(reason: "No file loaded")
        }

        // ✅ Restart engine if stopped before seeking
        try restartEngineIfNeeded()

        let wasPlaying = _isPlaying
        let targetTime = min(max(0, time), _duration)
        cancelCrossfade(rearmSourceCompletion: false)
        invalidatePlaybackCompletion()
        activePlayer.stop()
        _currentTime = targetTime

        guard targetTime < _duration else {
            _isPlaying = false
            if wasPlaying {
                completionHandler?()
            }
            return
        }

        armPlaybackCompletion(for: activePlayerSlot)
        activePlayer.play(from: targetTime)
        if wasPlaying {
            _isPlaying = true
        } else {
            activePlayer.pause()
            invalidatePlaybackCompletion()
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

    /// Cancel any transition and discard the inactive prepared track without
    /// disturbing the currently audible source player.
    public func invalidatePreparedTransition() async {
        cancelCrossfade(rearmSourceCompletion: true)
        inactivePlayer.stop()
        inactivePlayer.volume = 0
        inactiveFile = nil
        pendingNextURL = nil
    }

    public func consumePreparedTransition(to url: URL) async -> PreparedTrackTransition {
        guard pendingNextURL == url, let preparedFile = inactiveFile else {
            return .none
        }

        do {
            try restartEngineIfNeeded()
        } catch {
            return .none
        }

        invalidatePlaybackCompletion()
        activePlayer.stop()
        swap(&activePlayer, &inactivePlayer)
        swap(&activePitch, &inactivePitch)
        currentFile = preparedFile
        inactiveFile = nil
        pendingNextURL = nil
        _duration = Double(preparedFile.length) / preparedFile.fileFormat.sampleRate
        _currentTime = 0
        applyPlaybackRate(currentPlaybackRate)
        applyReplayGainImmediately(currentGainDB)
        activePlayer.volume = AUValue(_volume)
        inactivePlayer.volume = 0
        armPlaybackCompletion(for: activePlayerSlot)
        activePlayer.play()
        _isPlaying = true
        return .preloadedFallback
    }

    public func setPlaybackRate(_ rate: Double) async {
        currentPlaybackRate = rate
        applyPlaybackRate(rate)
    }

    public func applyReplayGain(_ gainDB: Float) async {
        currentGainDB = gainDB
        applyReplayGainImmediately(gainDB)
    }

    public var supportsEQ: Bool {
        get async { false }
    }

    public func crossfade(to url: URL, duration: TimeInterval, playbackRate: Double, gainDB: Float) async throws {
        cancelCrossfade(rearmSourceCompletion: true)

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
        armPlaybackCompletion(for: inactivePlayerSlot)
        inactivePlayer.play()
        _isPlaying = true
        let generation = UUID()
        crossfadeGeneration = generation

        if duration <= 0 {
            await finishCrossfade(with: nextFile, generation: generation)
            return
        }

        crossfadeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await performCrossfade(
                with: nextFile,
                duration: duration,
                generation: generation
            )
        }
    }

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
            Log.logger(.audioEngine).error("Failed to restart AudioKit engine: \(error.localizedDescription, privacy: .private)")
            throw AudioError.engineInitializationFailed(
                reason: "Failed to restart AudioKit engine after interruption: \(error.localizedDescription)",
            )
        }
    }

    // MARK: - Completion Handler

    /// Set a completion handler for when playback finishes
    public func setCompletionHandler(_ handler: @escaping () -> Void) {
        completionHandler = handler
    }

    private func cleanup() {
        invalidatePlaybackCompletion()
        engine.stop()
    }

    private var activePlayerSlot: PlayerSlot {
        activePlayer === primaryPlayer ? .primary : .secondary
    }

    private var inactivePlayerSlot: PlayerSlot {
        inactivePlayer === primaryPlayer ? .primary : .secondary
    }

    private func armPlaybackCompletion(for slot: PlayerSlot) {
        invalidatePlaybackCompletion()
        let generation = UUID()
        playbackGeneration = generation

        let callback = Self.makeCompletionCallback(
            owner: self,
            generation: generation,
            slot: slot
        )

        switch slot {
        case .primary:
            primaryPlayer.completionHandler = callback
        case .secondary:
            secondaryPlayer.completionHandler = callback
        }
    }

    private func invalidatePlaybackCompletion() {
        playbackGeneration = nil
        pendingCompletion = nil
        primaryPlayer.completionHandler = nil
        secondaryPlayer.completionHandler = nil
    }

    private nonisolated static func makeCompletionCallback(
        owner: AudioKitEngineAdapter,
        generation: UUID,
        slot: PlayerSlot
    ) -> AVAudioNodeCompletionHandler {
        { [weak owner] in
            Task { @MainActor [weak owner] in
                owner?.handlePlaybackCompletion(generation: generation, slot: slot)
            }
        }
    }

    private func handlePlaybackCompletion(generation: UUID, slot: PlayerSlot) {
        guard playbackGeneration == generation else { return }
        guard activePlayerSlot == slot else {
            pendingCompletion = (generation, slot)
            return
        }

        deliverPlaybackCompletion(generation: generation)
    }

    private func deliverPlaybackCompletion(generation: UUID) {
        guard playbackGeneration == generation else { return }
        invalidatePlaybackCompletion()
        _currentTime = _duration
        _isPlaying = false
        completionHandler?()
    }

    private func applyPlaybackRate(_ rate: Double) {
        let value = AUValue(rate)
        activePitch.rate = value
        inactivePitch.rate = value
    }

    private func applyReplayGainImmediately(_ gainDB: Float) {
        mixer.volume = AUValue(pow(10, gainDB / 20))
    }

    private func finishCrossfade(
        with file: AVAudioFile,
        generation: UUID
    ) async {
        guard crossfadeGeneration == generation else { return }
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
        crossfadeGeneration = nil

        if let pendingCompletion,
           pendingCompletion.generation == playbackGeneration,
           pendingCompletion.slot == activePlayerSlot {
            deliverPlaybackCompletion(generation: pendingCompletion.generation)
        }
    }

    private func performCrossfade(
        with file: AVAudioFile,
        duration: TimeInterval,
        generation: UUID
    ) async {
        let steps = max(1, Int(duration / 0.02))
        let interval = duration / Double(steps)
        let activeStart = activePlayer.volume
        let inactiveStart = inactivePlayer.volume
        let inactiveTarget = AUValue(_volume)

        for step in 1 ... steps {
            guard !Task.isCancelled, crossfadeGeneration == generation else {
                reconcileCancelledCrossfade(generation: generation)
                return
            }
            let progress = AUValue(step) / AUValue(steps)
            activePlayer.volume = activeStart * (1 - progress)
            inactivePlayer.volume = inactiveStart + (inactiveTarget - inactiveStart) * progress
            do {
                try await crossfadeSleeper(Swift.Duration.seconds(max(interval, 0)))
            } catch {
                reconcileCancelledCrossfade(generation: generation)
                return
            }
        }

        await finishCrossfade(with: file, generation: generation)
    }

    private func cancelCrossfade(rearmSourceCompletion: Bool) {
        guard crossfadeTask != nil || crossfadeGeneration != nil else { return }

        crossfadeTask?.cancel()
        crossfadeTask = nil
        crossfadeGeneration = nil
        inactivePlayer.stop()
        activePlayer.volume = AUValue(_volume)
        inactivePlayer.volume = 0
        inactiveFile = nil
        pendingNextURL = nil
        pendingCompletion = nil

        if rearmSourceCompletion, _isPlaying {
            armPlaybackCompletion(for: activePlayerSlot)
        } else {
            invalidatePlaybackCompletion()
        }
    }

    private func reconcileCancelledCrossfade(generation: UUID) {
        guard crossfadeGeneration == generation else { return }
        crossfadeTask = nil
        crossfadeGeneration = nil
        inactivePlayer.stop()
        activePlayer.volume = AUValue(_volume)
        inactivePlayer.volume = 0
        inactiveFile = nil
        pendingNextURL = nil
        pendingCompletion = nil

        if _isPlaying {
            armPlaybackCompletion(for: activePlayerSlot)
        } else {
            invalidatePlaybackCompletion()
        }
    }

    var activePlayerCountForTesting: Int {
        [primaryPlayer, secondaryPlayer].count(where: \.isPlaying)
    }

    var currentFileURLForTesting: URL? {
        currentFile?.url
    }

    var playerVolumesForTesting: (active: AUValue, inactive: AUValue) {
        (activePlayer.volume, inactivePlayer.volume)
    }

    func setCrossfadeSleeperForTesting(
        _ sleeper: @escaping @MainActor (Swift.Duration) async throws -> Void
    ) {
        crossfadeSleeper = sleeper
    }

}
