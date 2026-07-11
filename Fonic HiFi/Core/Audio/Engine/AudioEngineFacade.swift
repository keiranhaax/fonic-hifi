//
//  AudioEngineFacade.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/2025.
//

import AVFoundation
import Combine
import Foundation
import MediaPlayer
import Observation
import OSLog
import UIKit

/// High-level facade that composes the modular audio subsystems introduced in Phase 2C.
/// Responsibilities:
///  - Wire audio session, queue, diagnostics, and playback state managers
///  - Delegate engine lifecycle to `AudioEngineManager`
///  - Forward playback commands through `PlaybackController`
///  - Surface UI-facing state via `AudioUIState`
@MainActor
public final class AudioEngineFacade: ObservableObject {
    // MARK: - Core Services

    public let sessionManager: AudioSessionManager
    public let formatDetectionManager: AudioFormatDetectionManager
    public let engineFactory: AudioEngineFactory
    public let stateManager: PlaybackStateManager
    public let queueManager: AudioQueueManager
    public let validator: BitPerfectValidator
    public let monitor: any AudioPerformanceMonitoring & AudioDiagnosticsReporting
    public let playbackSettingsStore: AudioPlaybackSettingsStore

    /// Listening session tracking service
    private var sessionService: ListeningSessionService?

    // MARK: - Derived Read-Only State

    public var currentState: PlaybackState { stateCoordinator.currentState }
    public var queueState: QueueState { stateCoordinator.queueState }
    public var isPlaying: Bool { currentState.isPlaying }
    public var playbackProgress: Double { currentState.progress ?? 0.0 }
    public var currentTime: TimeInterval { currentState.currentTime ?? 0.0 }
    public var duration: TimeInterval { currentState.duration ?? 0.0 }

    public var performanceMode: PerformanceMode {
        get { engineManager.configuration.performanceMode }
        set {
            let updated = engineManager.configuration.with(performanceMode: newValue)
            Task { [weak self] in
                guard let self else { return }
                await engineManager.updateConfiguration(updated)
            }
        }
    }

    public var crossfadeDuration: TimeInterval { engineManager.configuration.crossfadeDuration }
    public var replayGainMode: ReplayGainMode { engineManager.configuration.replayGainMode }
    public var playbackRate: Double { engineManager.configuration.playbackRate }

    public private(set) var isReady: Bool = false

    // MARK: - UI State Proxies

    @Published public private(set) var currentTrack: Track?
    @Published public private(set) var showMiniPlayer: Bool = false
    @Published public private(set) var diagnosticsStatus: DiagnosticsStatus = .empty
    @Published public var abLoopState = ABLoopState()

    /// Pending seek position from restored queue state (used on first play after launch)
    private var pendingSeekPosition: TimeInterval?

    /// Current EQ configuration (stored for reapplication on engine switch)
    private var currentEQConfiguration: EqualizerConfiguration = .default

    // MARK: - Components

    private let progressTimer = ProgressTimerManager()
    private let uiStateStore: AudioUIState
    private let engineManager: AudioEngineManager
    private lazy var playbackController: PlaybackController = .init(
        sessionManager: sessionManager,
        formatDetectionManager: formatDetectionManager,
        validator: validator,
        stateManager: stateManager,
        queueManager: queueManager,
        engineManager: engineManager,
        progressTimer: progressTimer,
        uiState: uiStateStore,
        diagnosticsHandler: { [weak self] track, info in
            guard let self else { return }
            await refreshDiagnostics(for: track, formatInfo: info)
        },
    )

    private lazy var queueCoordinator: QueueCoordinator = .init(
        queueManager: queueManager,
        stateManager: stateManager,
        engineManager: engineManager,
        playbackController: playbackController,
    )

    private lazy var stateCoordinator: StateCoordinator = .init(
        stateManager: stateManager,
        queueManager: queueManager,
        sessionManager: sessionManager,
        uiStateStore: uiStateStore,
        facade: self,
    )

    private var cancellables = Set<AnyCancellable>()
    private let logger = Log.logger(.audioEngineFacade)
    private var isInitialized = false
    private var lastHandledPreference: String?
    private var preferenceObserver: NSKeyValueObservation?
    private static let runtimeMonitoringDefaultsKey = "audioRuntimeMonitoringEnabled"
    private let runtimeMonitoringEnabledOverride: Bool?

    var isRuntimeMonitoringEnabled: Bool {
        if let runtimeMonitoringEnabledOverride {
            return runtimeMonitoringEnabledOverride
        }
        if UserDefaults.standard.object(forKey: Self.runtimeMonitoringDefaultsKey) != nil {
            return UserDefaults.standard.bool(forKey: Self.runtimeMonitoringDefaultsKey)
        }
        #if DEBUG
            return true
        #else
            return false
        #endif
    }

    // MARK: - Initialization

    public init(
        configuration: AudioEngineConfiguration = .default,
        sessionManager: AudioSessionManager? = nil,
        formatDetectionManager: AudioFormatDetectionManager? = nil,
        engineFactory: AudioEngineFactory? = nil,
        stateManager: PlaybackStateManager? = nil,
        queueManager: AudioQueueManager? = nil,
        validator: BitPerfectValidator? = nil,
        monitor: (any AudioPerformanceMonitoring & AudioDiagnosticsReporting)? = nil,
        playbackSettingsStore: AudioPlaybackSettingsStore? = nil,
        uiStateStore: AudioUIState? = nil,
        runtimeMonitoringEnabled: Bool? = nil,
    ) {
        self.sessionManager = sessionManager ?? AudioSessionManager()
        self.formatDetectionManager = formatDetectionManager ?? AudioFormatDetectionManager()
        self.engineFactory = engineFactory ?? AudioEngineFactory()
        self.stateManager = stateManager ?? PlaybackStateManager()
        self.queueManager = queueManager ?? AudioQueueManager()
        self.validator = validator ?? BitPerfectValidator()
        self.monitor = monitor ?? AudioMonitor()
        self.playbackSettingsStore = playbackSettingsStore ?? AudioPlaybackSettingsStore()
        self.uiStateStore = uiStateStore ?? AudioUIState()
        runtimeMonitoringEnabledOverride = runtimeMonitoringEnabled
        engineManager = AudioEngineManager(
            configuration: configuration,
            engineFactory: self.engineFactory,
            monitor: self.monitor,
        )

        currentTrack = self.uiStateStore.currentTrack
        showMiniPlayer = self.uiStateStore.showMiniPlayer
        diagnosticsStatus = self.uiStateStore.diagnosticsStatus

        setupStateBindings()
        _ = queueCoordinator
        _ = stateCoordinator

        // Wire up auto-advance when tracks complete
        playbackController.onTrackComplete = { [weak self] in
            guard let self else { return }

            // Record completed listening session
            if let engine = self.engineManager.currentEngine {
                let currentTime = await engine.currentTime
                await self.sessionService?.endSession(
                    currentTime: currentTime,
                    wasSkipped: false,
                    wasCompleted: true
                )
            }

            do {
                try await self.queueCoordinator.playNext()
            } catch {
                self.logger.error("Failed to auto-advance: \(error.localizedDescription)")
                self.stateManager.updateState(.stopped)
            }
        }

        // Wire up A-B loop checking
        playbackController.loopCheckHandler = { [weak self] currentTime in
            guard let self,
                  self.abLoopState.isEnabled,
                  let pointA = self.abLoopState.pointA,
                  let pointB = self.abLoopState.pointB,
                  currentTime >= pointB else { return nil }
            return pointA
        }

        logger.info("AudioEngineFacade initialised with configuration: \(String(describing: configuration.performanceMode))")
    }

    // MARK: - Session Tracking Configuration

    /// Configure listening session tracking with the data actor
    /// - Parameter dataActor: The TrackDataActor for persisting listening sessions
    public func configureSessionTracking(dataActor: TrackDataActor) {
        self.sessionService = ListeningSessionService(dataActor: dataActor)
        logger.info("Session tracking configured")
    }

    // MARK: - Configuration Mutations

    public func updateCrossfadeDuration(_ duration: TimeInterval) async {
        objectWillChange.send()
        let updated = engineManager.configuration.with(crossfadeDuration: duration)
        await engineManager.updateConfiguration(updated)
        await playbackSettingsStore.setCrossfadeDuration(duration)
    }

    public func updateReplayGainMode(_ mode: ReplayGainMode) async {
        objectWillChange.send()
        let updated = engineManager.configuration.with(replayGainMode: mode)
        await engineManager.updateConfiguration(updated)
        await playbackSettingsStore.setReplayGainMode(mode)
        await playbackController.reapplyPlaybackParameters()
    }

    public func updatePlaybackRate(_ rate: Double) async {
        objectWillChange.send()
        let updated = engineManager.configuration.with(playbackRate: rate)
        await engineManager.updateConfiguration(updated)
        await playbackSettingsStore.setPlaybackRate(rate)
        if let engine = engineManager.currentEngine {
            await engine.setPlaybackRate(rate)
        }
        await playbackController.reapplyPlaybackParameters()
        await playbackController.refreshNowPlayingMetadata()
    }

    public func updateGaplessEnabled(_ enabled: Bool) async {
        objectWillChange.send()
        let updated = engineManager.configuration.with(enableGapless: enabled)
        await engineManager.updateConfiguration(updated)
        await playbackSettingsStore.setGaplessEnabled(enabled)
    }

    public func applyEQ(_ configuration: EqualizerConfiguration) async {
        objectWillChange.send()
        currentEQConfiguration = configuration

        guard let engine = engineManager.currentEngine else { return }

        if await engine.supportsEQ {
            await engine.applyEQ(configuration)
            logger.debug("Applied EQ configuration: \(LogPrivacy.truncated(configuration.presetName ?? "Custom", limit: 32))")
        } else {
            logger.warning("Current engine does not support EQ")
        }
    }

    /// Reapply the stored EQ configuration (e.g., after engine switch)
    public func reapplyEQConfiguration() async {
        await applyEQ(currentEQConfiguration)
    }

    // MARK: - Lifecycle

    public func initialize() async throws {
        guard !isInitialized else {
            logger.warning("AudioEngineFacade already initialised")
            return
        }

        logger.info("Initialising AudioEngineFacade…")

        do {
            let mergedConfiguration = await playbackSettingsStore.configuration(merging: engineManager.configuration)
            await engineManager.updateConfiguration(mergedConfiguration)

            try await sessionManager.configureAudioSession()
            await setupServiceIntegrations()
            if isRuntimeMonitoringEnabled {
                await monitor.startMonitoring(updateInterval: 2.0)
            } else {
                logger.info("Runtime audio monitoring is disabled")
            }
            await sessionManager.enableRemoteCommands()

            if queueManager.restoreState() {
                logger.info("Restored persisted queue state")
                if let restoredTrack = queueManager.currentTrack {
                    uiStateStore.currentTrack = createTrackFromAudioTrack(restoredTrack)
                    uiStateStore.showMiniPlayer = true

                    // Capture saved playback position for resume on first play
                    let savedPosition = queueManager.queueState.lastPlaybackPosition
                    if savedPosition > 0 {
                        pendingSeekPosition = savedPosition
                        logger.info("Restored playback position: \(savedPosition)s")
                    }
                }
            }

            isInitialized = true
            isReady = true
            logger.info("AudioEngineFacade initialisation complete")
        } catch {
            logger.error("AudioEngineFacade initialisation failed: \(error.localizedDescription)")
            isReady = false
            throw AudioError.engineInitializationFailed(reason: error.localizedDescription)
        }
    }

    public func shutdown() async {
        logger.info("Shutting down AudioEngineFacade…")

        progressTimer.stop()
        await monitor.stopMonitoring()
        await playbackController.stop()
        await engineManager.cleanupCurrentEngine()

        cancellables.removeAll()
        isInitialized = false
        isReady = false

        logger.info("AudioEngineFacade shutdown complete")
    }

    // MARK: - Playback Control

    public func play(track: Track) async throws {
        assertMainThread()
        guard isReady else { throw AudioError.engineInitializationFailed(reason: "Engine not ready") }
        logger.info("Playing track: \(track.title, privacy: .public)")
        try await playbackController.play(track: track)

        // Start listening session after successful play
        if let engine = engineManager.currentEngine {
            let duration = await engine.duration
            sessionService?.startSession(trackId: track.id, duration: duration)
        }

        // Apply pending seek position from restored state (first play after launch)
        if let seekPosition = pendingSeekPosition {
            pendingSeekPosition = nil
            logger.info("Seeking to restored position: \(seekPosition)s")
            try await playbackController.seek(to: seekPosition)
        }
    }

    public func resume() async throws {
        assertMainThread()
        guard isReady else { throw AudioError.engineInitializationFailed(reason: "Engine not ready") }
        try await playbackController.resume()
    }

    public func pause() async {
        assertMainThread()
        guard isReady else { return }

        // Save current position before pausing
        if let engine = engineManager.currentEngine {
            let position = await engine.currentTime
            queueManager.saveState(playbackPosition: position)
        }

        await playbackController.pause()
    }

    public func stop() async {
        assertMainThread()

        // End listening session without completion
        if let engine = engineManager.currentEngine {
            let currentTime = await engine.currentTime
            await sessionService?.endSession(
                currentTime: currentTime,
                wasSkipped: false,
                wasCompleted: false
            )
        }

        // Save position as 0 when stopping (user intended to stop)
        queueManager.saveState(playbackPosition: 0)

        await playbackController.stop()
    }

    public func seek(to time: TimeInterval) async throws {
        assertMainThread()
        guard isReady else { throw AudioError.engineInitializationFailed(reason: "Engine not ready") }
        try await playbackController.seek(to: time)
    }

    public func setVolume(_ volume: Float) async {
        assertMainThread()
        guard isReady else { return }
        await playbackController.setVolume(volume)
    }

    public func setCurrentEngine(_ engine: AudioEngineService, type: AudioEngineType? = nil, format: AudioFormat? = nil) {
        engineManager.overrideCurrentEngine(engine, type: type, format: format)
    }

    public func playNext() async throws {
        // End current session as skipped before changing track
        if let engine = engineManager.currentEngine {
            let currentTime = await engine.currentTime
            await sessionService?.endSession(
                currentTime: currentTime,
                wasSkipped: true,
                wasCompleted: false
            )
        }

        try await queueCoordinator.playNext()
    }

    public func playPrevious() async throws {
        // End current session as skipped before changing track
        if let engine = engineManager.currentEngine {
            let currentTime = await engine.currentTime
            await sessionService?.endSession(
                currentTime: currentTime,
                wasSkipped: true,
                wasCompleted: false
            )
        }

        try await queueCoordinator.playPrevious()
    }

    // MARK: - A-B Loop

    public func setLoopPointA() {
        abLoopState.pointA = currentTime
        let time = currentTime
        Log.logger(.playback).info("Set loop point A at \(time)")
    }

    public func setLoopPointB() {
        abLoopState.pointB = currentTime
        abLoopState.isEnabled = abLoopState.isValid
        let time = currentTime
        let enabled = abLoopState.isEnabled
        Log.logger(.playback).info("Set loop point B at \(time), enabled: \(enabled)")
    }

    public func clearLoop() {
        abLoopState.clear()
        Log.logger(.playback).info("Cleared A-B loop")
    }

    // MARK: - Queue Operations

    public func enqueue(_ tracks: [Track]) {
        queueCoordinator.enqueue(tracks)
    }

    public func enqueueNext(_ track: Track) {
        queueCoordinator.enqueueNext(track)
    }

    public func setShuffleMode(_ mode: QueueShuffleMode) {
        queueCoordinator.setShuffleMode(mode)
    }

    public func setRepeatMode(_ mode: QueueRepeatMode) {
        queueCoordinator.setRepeatMode(mode)
    }

    // MARK: - Diagnostics & Monitoring

    public func validatePlaybackSetup() async -> BitPerfectValidationResult? {
        guard let track = uiStateStore.currentTrack else { return nil }
        do {
            let info = try await formatDetectionManager.detectFormat(at: track.url)
            return await validator.validateBitPerfectPlayback(sourceFormat: info, outputDevice: nil)
        } catch {
            logger.error("Validation failed: \(error.localizedDescription)")
            return nil
        }
    }

    public func getCurrentDiagnostics() async -> PlaybackDiagnostics {
        await monitor.performDiagnosticsCheck()
    }

    public func getCurrentMetrics() async -> AudioMetrics {
        await monitor.getCurrentMetrics()
    }

    public func refreshDiagnostics(for track: Track, formatInfo: AudioFileInfo? = nil) async {
        do {
            let info: AudioFileInfo = if let formatInfo {
                formatInfo
            } else {
                try await formatDetectionManager.detectFormat(at: track.url)
            }
            let validation = await validator.validateBitPerfectPlayback(sourceFormat: info, outputDevice: nil)

            let devices = await validator.getAvailableDevicesWithCapabilities()
            let defaultDevice = devices.first(where: { $0.device.isDefault }) ?? devices.first
            var dacInfo: DACCompatibilityInfo?
            if let id = defaultDevice?.device.id {
                dacInfo = await validator.getDACCompatibility(for: id)
            }

            let metrics = await monitor.getCurrentMetrics()
            let status = DiagnosticsStatus(
                track: trackSummary(for: track),
                validationResult: validation,
                device: defaultDevice?.device,
                dacInfo: dacInfo,
                metrics: metrics,
                updatedAt: Date(),
            )
            uiStateStore.diagnosticsStatus = status
            diagnosticsStatus = status
        } catch {
            let metrics = await monitor.getCurrentMetrics()
            let status = DiagnosticsStatus(
                track: trackSummary(for: track),
                validationResult: nil,
                device: nil,
                dacInfo: nil,
                metrics: metrics,
                updatedAt: Date(),
            )
            uiStateStore.diagnosticsStatus = status
            diagnosticsStatus = status
            logger.warning("Diagnostics refresh failed: \(error.localizedDescription)")
        }
    }

    // MARK: - UI Bridging

    public func setCurrentTrack(_ track: Track?) {
        // Clear A-B loop on track change
        if track?.id != uiStateStore.currentTrack?.id {
            abLoopState.clear()
        }

        uiStateStore.currentTrack = track
        if track == nil {
            uiStateStore.showMiniPlayer = false
            uiStateStore.diagnosticsStatus = .empty
        } else {
            uiStateStore.showMiniPlayer = true
        }
    }

    // MARK: - Private Helpers

    private func setupStateBindings() {
        uiStateStore.$currentTrack
            .receive(on: RunLoop.main)
            .sink { [weak self] track in self?.currentTrack = track }
            .store(in: &cancellables)

        uiStateStore.$showMiniPlayer
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in self?.showMiniPlayer = visible }
            .store(in: &cancellables)

        uiStateStore.$diagnosticsStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] status in self?.diagnosticsStatus = status }
            .store(in: &cancellables)
    }

    private func setupServiceIntegrations() async {
        queueManager.delegate = FacadeQueueDelegateBridge(stateManager: stateManager)
        if let engine = engineManager.currentEngine {
            await monitor.attachToEngine(engine)
        }
        sessionManager.delegate = self
        setupPreferenceMonitoring()
    }

    private func setupPreferenceMonitoring() {
        // Use KVO on SPECIFIC key - does NOT fire for volume, shuffle, repeat, etc.
        preferenceObserver = UserDefaults.standard.observe(
            \.preferredAudioEngine,
            options: [.new, .old]
        ) { [weak self] _, change in
            // Skip if value unchanged (redundant notification)
            guard change.oldValue != change.newValue else { return }

            Task { @MainActor [weak self] in
                await self?.handlePreferenceChange()
            }
        }
    }

    private func handlePreferenceChange() async {
        let preferred = UserDefaults.standard.string(forKey: "preferredAudioEngine") ?? "AVAudioEngine"

        // De-dup: skip if we already handled this preference value
        guard preferred != lastHandledPreference else { return }
        lastHandledPreference = preferred

        let current = engineManager.currentEngineType?.rawValue ?? "None"

        // No change needed if preference matches current engine
        guard preferred != current else { return }

        logger.info("Audio engine preference changed from \(current) to \(preferred)")

        if stateManager.currentState.isIdle {
            // Idle: safe to invalidate immediately
            engineManager.invalidateCurrentEngine()
        } else {
            // PLAYING/PAUSED: defer to next track load via manager flag
            engineManager.setPendingEngineSwitch()
        }
    }

    private func trackSummary(for track: Track) -> TrackSummary {
        TrackSummary(
            id: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album,
            format: track.audioFormat,
        )
    }

    private func createTrackFromAudioTrack(_ audioTrack: AudioTrack) -> Track {
        let track = Track(
            url: audioTrack.url,
            title: audioTrack.title,
            artist: audioTrack.artist,
            album: audioTrack.album,
            audioFormat: audioTrack.audioFormat,
            duration: audioTrack.duration,
        )
        track.replayGainTrack = audioTrack.replayGainTrack
        track.replayGainAlbum = audioTrack.replayGainAlbum
        return track
    }

    private func assertMainThread(
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function,
    ) {
        #if DEBUG
            assert(Thread.isMainThread, "\(function) must run on main thread. Called from \(file):\(line)")
        #endif
    }
}

// MARK: - AudioSessionDelegate

extension AudioEngineFacade: AudioSessionDelegate {
    public func audioSessionDidInterrupt(_ interruption: AudioInterruptionType) async {
        await stateCoordinator.handleSessionInterruption(interruption)
    }

    public func audioSessionRouteDidChange(_ change: AudioRouteChange) async {
        stateCoordinator.handleRouteChange(change)
    }

    public func audioSessionDidReceiveCommand(_ command: RemoteCommand) async {
        await stateCoordinator.handleRemoteCommand(command)
    }
}

// MARK: - Supporting Types

private final class FacadeQueueDelegateBridge: AudioQueueDelegate {
    private let stateManager: PlaybackStateManager

    init(stateManager: PlaybackStateManager) {
        self.stateManager = stateManager
    }

    func audioQueue(_: AudioQueue, didChangeCurrentTrack _: AudioTrack?, at _: Int?) {
        // Facade manages state transitions directly via PlaybackController
    }

    func audioQueue(_: AudioQueue, didEncounterError error: AudioError) {
        stateManager.handleEngineError(error)
    }
}

extension AudioError {
    static let engineNotReady = AudioError.engineInitializationFailed
    static let invalidOperation = AudioError.playbackFailed
}
