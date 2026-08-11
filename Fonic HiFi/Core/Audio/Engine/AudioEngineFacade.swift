//
//  AudioEngineFacade.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/2025.
//

import Accessibility
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
    public let monitor: any AudioPerformanceMonitoring & PlaybackHealthEventLogging
    public let playbackSettingsStore: AudioPlaybackSettingsStore
    public let sleepTimerManager: SleepTimerManager

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
    public var isGaplessEnabled: Bool { engineManager.configuration.enableGapless }

    public private(set) var isReady: Bool = false

    // MARK: - UI State Proxies

    @Published public private(set) var currentTrack: Track?
    @Published public private(set) var showMiniPlayer: Bool = false
    @Published public private(set) var diagnosticsStatus: DiagnosticsStatus = .empty
    @Published public private(set) var playbackError: PlaybackErrorPresentation?
    @Published public private(set) var equalizerConfiguration: EqualizerConfiguration = .default
    @Published public private(set) var equalizerApplicationResult: EqualizerApplicationResult = .waitingForEngine
    @Published public var abLoopState = ABLoopState()

    public var lastPlaybackErrorMessage: String? { playbackError?.message }

    /// Recent playback-health events recorded for the diagnostics panel (oldest first).
    public var playbackHealthEvents: [PlaybackHealthEvent] {
        monitor.playbackHealthEvents
    }

    /// Pending seek position from restored queue state (used on first play after launch)
    private var pendingSeekPosition: TimeInterval?

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
    private var initializationTask: Task<Void, Error>?
    private var initializationAttemptID: UUID?
    private var lifecycleID = UUID()
    private var shutdownTask: Task<Void, Never>?
    private var playbackRequestTask: Task<Void, Error>?
    private var playbackRequestID: UUID?
    private var lastObservedQueueState: QueueState?
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
        monitor: (any AudioPerformanceMonitoring & PlaybackHealthEventLogging)? = nil,
        playbackSettingsStore: AudioPlaybackSettingsStore? = nil,
        uiStateStore: AudioUIState? = nil,
        runtimeMonitoringEnabled: Bool? = nil,
        sleepTimerManager: SleepTimerManager? = nil,
    ) {
        self.sessionManager = sessionManager ?? AudioSessionManager()
        self.formatDetectionManager = formatDetectionManager ?? AudioFormatDetectionManager()
        self.stateManager = stateManager ?? PlaybackStateManager()
        self.queueManager = queueManager ?? AudioQueueManager()
        self.validator = validator ?? BitPerfectValidator()
        let selectedMonitor = monitor ?? AudioMonitor()
        self.monitor = selectedMonitor
        if let engineFactory {
            self.engineFactory = engineFactory
        } else {
            self.engineFactory = AudioEngineFactory(
                configurationRecoveryFailureHandler: { [weak selectedMonitor] kind, detail in
                    selectedMonitor?.recordPlaybackHealthEvent(kind, detail: detail)
                }
            )
        }
        self.playbackSettingsStore = playbackSettingsStore ?? AudioPlaybackSettingsStore()
        self.sleepTimerManager = sleepTimerManager ?? SleepTimerManager()
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
        self.monitor.playbackHealthEventsPublisher
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
        self.sleepTimerManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        engineManager.equalizerApplicationResultHandler = { [weak self] result in
            self?.equalizerApplicationResult = result
        }
        _ = queueCoordinator
        _ = stateCoordinator

        // Wire up auto-advance when tracks complete
        playbackController.onTrackComplete = { [weak self] in
            guard let self else { return }

            do {
                try await self.performLatestPlaybackRequest {
                    _ = self.sessionService?.endSessionInBackground(
                        wasSkipped: false,
                        wasCompleted: true
                    )
                    let didAdvance = try await self.queueCoordinator.playNextAfterCompletion()
                    try Task.checkCancellation()
                    guard didAdvance else {
                        // Queue exhaustion is a genuine end of playback. The
                        // coordinator already stopped the engine; release
                        // audio focus only on this terminal path.
                        do {
                            try await self.sessionManager.deactivateAudioSession()
                        } catch {
                            self.logger.error(
                                "Failed to deactivate audio session at end of queue: \(error.localizedDescription, privacy: .private)"
                            )
                        }
                        return
                    }
                    await self.startSessionForCurrentQueueTrack()
                }
            } catch {
                self.logger.error("Failed to auto-advance: \(error.localizedDescription, privacy: .private)")
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

        self.sleepTimerManager.onComplete = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.pause()
            }
        }
        self.sleepTimerManager.onVolumeChange = { [weak self] volume in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.playbackController.setVolume(volume)
            }
        }

        logger.info("AudioEngineFacade initialised with configuration: \(String(describing: configuration.performanceMode), privacy: .public)")
    }

    // MARK: - Session Tracking Configuration

    /// Configure listening session tracking with the data actor
    /// - Parameter dataActor: The TrackDataActor for persisting listening sessions
    public func configureSessionTracking(dataActor: TrackDataActor) {
        self.sessionService = ListeningSessionService(dataActor: dataActor)
        logger.info("Session tracking configured")
    }

    private func startSessionForCurrentQueueTrack() async {
        guard let track = queueManager.currentTrack else { return }
        let engineDuration = if let engine = engineManager.currentEngine {
            await engine.duration
        } else {
            0.0
        }
        let duration = engineDuration > 0 ? engineDuration : track.duration
        await sessionService?.startSession(trackId: track.id, duration: duration)
    }

    // MARK: - Configuration Mutations

    public func updateCrossfadeDuration(_ duration: TimeInterval) async {
        let updated = engineManager.configuration.with(crossfadeDuration: duration)
        await engineManager.updateConfiguration(updated)
        await playbackSettingsStore.setCrossfadeDuration(duration)
        objectWillChange.send()
    }

    public func updateReplayGainMode(_ mode: ReplayGainMode) async {
        let updated = engineManager.configuration.with(replayGainMode: mode)
        await engineManager.updateConfiguration(updated)
        await playbackSettingsStore.setReplayGainMode(mode)
        await playbackController.reapplyPlaybackParameters()
        objectWillChange.send()
    }

    public func updatePlaybackRate(_ rate: Double) async {
        let updated = engineManager.configuration.with(playbackRate: rate)
        await engineManager.updateConfiguration(updated)
        await playbackSettingsStore.setPlaybackRate(rate)
        if let engine = engineManager.currentEngine {
            await engine.setPlaybackRate(rate)
        }
        await playbackController.reapplyPlaybackParameters()
        await playbackController.refreshNowPlayingMetadata()
        objectWillChange.send()
    }

    public func updateGaplessEnabled(_ enabled: Bool) async {
        let updated = engineManager.configuration.with(enableGapless: enabled)
        await engineManager.updateConfiguration(updated)
        await playbackSettingsStore.setGaplessEnabled(enabled)
        objectWillChange.send()
    }

    @discardableResult
    public func applyEQ(
        _ configuration: EqualizerConfiguration
    ) async -> EqualizerApplicationResult {
        equalizerConfiguration = configuration
        await playbackSettingsStore.setEqualizerConfiguration(configuration)
        let result = await engineManager.updateEqualizerConfiguration(configuration)
        equalizerApplicationResult = result

        logger.debug(
            "Updated EQ configuration: \(LogPrivacy.truncated(configuration.presetName ?? "Custom", limit: 32), privacy: .private)"
        )
        return result
    }

    /// Reapply the stored EQ configuration (e.g., after engine switch)
    @discardableResult
    public func reapplyEQConfiguration() async -> EqualizerApplicationResult {
        let result = await engineManager.updateEqualizerConfiguration(equalizerConfiguration)
        equalizerApplicationResult = result
        return result
    }

    // MARK: - Lifecycle

    public func initialize() async throws {
        if let shutdownTask {
            await shutdownTask.value
        }

        try Task.checkCancellation()

        if isReady {
            return
        }

        if let initializationTask {
            try await initializationTask.value
            return
        }

        let attemptID = UUID()
        let initializationLifecycleID = lifecycleID
        let task = Task { @MainActor [weak self] in
            guard let self else { throw CancellationError() }
            try await performInitialization(lifecycleID: initializationLifecycleID)
        }
        initializationTask = task
        initializationAttemptID = attemptID

        defer {
            if initializationAttemptID == attemptID {
                initializationTask = nil
                initializationAttemptID = nil
            }
        }

        try await task.value
    }

    private func performInitialization(lifecycleID initializationLifecycleID: UUID) async throws {
        try ensureInitializationIsCurrent(initializationLifecycleID)

        guard !isInitialized else {
            logger.warning("AudioEngineFacade already initialised")
            isReady = true
            return
        }

        logger.info("Initialising AudioEngineFacade…")

        do {
            let persistedEqualizerConfiguration = await playbackSettingsStore.equalizerConfiguration()
            try ensureInitializationIsCurrent(initializationLifecycleID)
            equalizerConfiguration = persistedEqualizerConfiguration
            equalizerApplicationResult = await engineManager.updateEqualizerConfiguration(
                persistedEqualizerConfiguration
            )
            try ensureInitializationIsCurrent(initializationLifecycleID)

            let mergedConfiguration = await playbackSettingsStore.configuration(merging: engineManager.configuration)
            try ensureInitializationIsCurrent(initializationLifecycleID)
            await engineManager.updateConfiguration(mergedConfiguration)
            try ensureInitializationIsCurrent(initializationLifecycleID)

            try await sessionManager.configureAudioSession()
            try ensureInitializationIsCurrent(initializationLifecycleID)
            try await setupServiceIntegrations(lifecycleID: initializationLifecycleID)
            if isRuntimeMonitoringEnabled {
                await monitor.startMonitoring(updateInterval: 2.0)
                try ensureInitializationIsCurrent(initializationLifecycleID)
            } else {
                logger.info("Runtime audio monitoring is disabled")
            }
            await sessionManager.enableRemoteCommands()
            try ensureInitializationIsCurrent(initializationLifecycleID)

            if queueManager.queueState.isEmpty, await queueManager.restoreState() {
                logger.info("Restored persisted queue state")
                if let restoredTrack = queueManager.currentTrack {
                    // Restore the last track as the launch playback surface. It
                    // remains paused until the user resumes playback.
                    uiStateStore.restorePersistedTrack(
                        PlayableTrackSnapshot(audioTrack: restoredTrack).makeDisplayTrack()
                    )

                    // Capture saved playback position for resume on first play
                    let savedPosition = queueManager.queueState.lastPlaybackPosition
                    if savedPosition > 0 {
                        pendingSeekPosition = savedPosition
                        logger.info("Restored playback position: \(savedPosition, privacy: .public)s")
                    }
                }
            }

            isInitialized = true
            isReady = true
            logger.info("AudioEngineFacade initialisation complete")
        } catch {
            if Task.isCancelled || initializationLifecycleID != lifecycleID {
                logger.info("AudioEngineFacade initialisation cancelled")
                throw CancellationError()
            }

            logger.error("AudioEngineFacade initialisation failed: \(error.localizedDescription, privacy: .private)")
            isReady = false
            throw AudioError.engineInitializationFailed(reason: error.localizedDescription)
        }
    }

    private func ensureReadyForPlayback() async throws {
        if !isReady {
            try await initialize()
        }

        guard isReady else {
            throw AudioError.engineInitializationFailed(reason: "Engine not ready")
        }
    }

    public func reportPlaybackControlError(_ error: Error) {
        guard !(error is CancellationError) else { return }

        let message = playbackErrorDescription(for: error)
        logger.error("Playback control failed: \(message, privacy: .private)")

        guard playbackError?.message != message else { return }

        playbackError = PlaybackErrorPresentation(id: UUID(), message: message)
        announcePlaybackControlError(message)
    }

    public func dismissPlaybackControlError(id: UUID) {
        guard playbackError?.id == id else { return }
        playbackError = nil
    }

    private func playbackErrorDescription(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return description
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty {
            return description
        }

        return "Playback failed. Please try again."
    }

    private func announcePlaybackControlError(_ message: String) {
        var announcement = AttributedString("Playback error: \(message)")
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
    }

    public func shutdown() async {
        if let shutdownTask {
            await shutdownTask.value
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await performShutdown()
        }
        shutdownTask = task
        await task.value
    }

    private func performShutdown() async {
        logger.info("Shutting down AudioEngineFacade…")

        lifecycleID = UUID()
        isReady = false
        sleepTimerManager.cancel(restoreVolume: false)

        let pendingInitializationTask = initializationTask
        let pendingInitializationAttemptID = initializationAttemptID
        pendingInitializationTask?.cancel()
        if let pendingInitializationTask {
            _ = await pendingInitializationTask.result
        }
        if initializationAttemptID == pendingInitializationAttemptID {
            initializationTask = nil
            initializationAttemptID = nil
        }

        await cancelPlaybackRequestAndWait()
        progressTimer.stop()
        await monitor.stopMonitoring()
        await sessionService?.endSession(
            wasSkipped: false,
            wasCompleted: false
        )
        await playbackController.stop()
        await engineManager.cleanupCurrentEngine()
        do {
            try await sessionManager.deactivateAudioSession()
        } catch {
            logger.error(
                "Failed to deactivate audio session during shutdown: \(error.localizedDescription, privacy: .private)"
            )
        }

        preferenceObserver?.invalidate()
        preferenceObserver = nil
        queueManager.delegate = nil
        // Remove all MPRemoteCommandCenter targets while the facade still owns
        // the delegate; no late command can reach a torn-down coordinator.
        await sessionManager.disableRemoteCommands()
        sessionManager.delegate = nil
        cancellables.removeAll()
        isInitialized = false
        playbackError = nil
        shutdownTask = nil

        logger.info("AudioEngineFacade shutdown complete")
    }

    // MARK: - Playback Control

    public func play(track: Track) async throws {
        assertMainThread()
        try await performLatestPlaybackRequest {
            try await self.ensureReadyForPlayback()
            try Task.checkCancellation()
            self.logger.info("Starting selected-track playback")
            let snapshot = PlayableTrackSnapshot(track: track)
            let wasAlreadyInQueue = self.queueManager.tracks.contains { $0.id == snapshot.id }
            try await self.playbackController.play(snapshot: snapshot, queueEntry: nil)
            try Task.checkCancellation()

            guard self.queueManager.setCurrentTrack(snapshot.audioTrack) else {
                await self.playbackController.stop()
                throw AudioError.playbackFailed(reason: "Unable to commit selected track to queue")
            }
            if !wasAlreadyInQueue {
                await self.playbackController.prepareUpcomingTrackForCurrentPlayback()
            }

            if let engine = self.engineManager.currentEngine {
                let duration = await engine.duration
                try Task.checkCancellation()
                await self.sessionService?.startSession(trackId: track.id, duration: duration)
            }

            if let seekPosition = self.pendingSeekPosition {
                self.pendingSeekPosition = nil
                self.logger.info("Seeking to restored position: \(seekPosition, privacy: .public)s")
                self.sessionService?.recordSeek()
                try await self.playbackController.seek(to: seekPosition)
            }
        }
    }

    public func resume() async throws {
        assertMainThread()
        try await performLatestPlaybackRequest {
            try await self.ensureReadyForPlayback()
            try Task.checkCancellation()

            if self.stateManager.currentState.isIdle,
               let track = self.uiStateStore.currentTrack {
                self.logger.info("Loading restored track before resuming playback")
                try await self.playbackController.play(
                    track: track,
                    queueEntry: self.queueManager.currentTrack
                )
                try Task.checkCancellation()

                if let engine = self.engineManager.currentEngine {
                    let duration = await engine.duration
                    try Task.checkCancellation()
                    await self.sessionService?.startSession(trackId: track.id, duration: duration)
                }

                if let seekPosition = self.pendingSeekPosition {
                    self.pendingSeekPosition = nil
                    self.logger.info("Seeking to restored position: \(seekPosition, privacy: .public)s")
                    self.sessionService?.recordSeek()
                    try await self.playbackController.seek(to: seekPosition)
                }
                self.queueManager.commitRestoredFallbackIfNeeded()
                return
            }

            try await self.playbackController.resume()
            try Task.checkCancellation()
            self.sessionService?.resumeSession()
        }
    }

    public func pause() async {
        assertMainThread()
        guard isReady else { return }
        await cancelPlaybackRequestAndWait()

        // Save current position before pausing
        if let engine = engineManager.currentEngine {
            let position = await engine.currentTime
            await queueManager.saveState(playbackPosition: position)
        }

        sessionService?.pauseSession()
        await playbackController.pause()
    }

    public func stop() async {
        assertMainThread()
        await cancelPlaybackRequestAndWait()

        await sessionService?.endSession(
            wasSkipped: false,
            wasCompleted: false
        )

        // Save position as 0 when stopping (user intended to stop)
        await queueManager.saveState(playbackPosition: 0)

        await playbackController.stop()

        do {
            try await sessionManager.deactivateAudioSession()
        } catch {
            logger.error(
                "Failed to deactivate audio session after explicit stop: \(error.localizedDescription, privacy: .private)"
            )
        }
    }

    /// Completes queue persistence before the app is suspended without changing playback state.
    public func persistQueueStateForSuspension() async {
        assertMainThread()
        if let engine = engineManager.currentEngine {
            let position = await engine.currentTime
            await queueManager.saveState(playbackPosition: position)
        } else {
            await queueManager.flushPendingPersistence()
        }
    }

    public func seek(to time: TimeInterval) async throws {
        assertMainThread()
        try await ensureReadyForPlayback()
        sessionService?.recordSeek()
        try await playbackController.seek(to: time)
    }

    public func setVolume(_ volume: Float) async {
        assertMainThread()
        guard isReady else { return }
        await playbackController.setVolume(volume)
    }

    /// Narrow route-recovery forwarding seam for StateCoordinator. Keep the
    /// controller private while allowing the coordinator to re-assert the
    /// active source rate on a MainActor-owned facade.
    func renegotiatePreferredSampleRateForRoute() async {
        await playbackController.renegotiatePreferredSampleRate()
    }

    @discardableResult
    public func startSleepTimer(seconds: Int, fadeOutDuration: Int) async -> Bool {
        assertMainThread()
        guard let engine = engineManager.currentEngine else {
            logger.warning("Cannot start sleep timer: engine not ready")
            return false
        }

        let currentVolume = await engine.volume
        sleepTimerManager.fadeOutDuration = min(max(0, fadeOutDuration), max(1, seconds))
        sleepTimerManager.start(seconds: seconds, currentVolume: currentVolume)
        return true
    }

    public func setCurrentEngine(_ engine: AudioEngineService, type: AudioEngineType? = nil, format: AudioFormat? = nil) {
        engineManager.overrideCurrentEngine(engine, type: type, format: format)
    }

    public func playNext() async throws {
        assertMainThread()
        try await performLatestPlaybackRequest {
            try await self.ensureReadyForPlayback()
            try Task.checkCancellation()
            await self.sessionService?.endSession(
                wasSkipped: true,
                wasCompleted: false
            )
            try await self.queueCoordinator.playNext()
            try Task.checkCancellation()
            await self.startSessionForCurrentQueueTrack()
        }
    }

    public func playPrevious() async throws {
        assertMainThread()
        try await performLatestPlaybackRequest {
            try await self.ensureReadyForPlayback()
            try Task.checkCancellation()
            await self.sessionService?.endSession(
                wasSkipped: true,
                wasCompleted: false
            )
            try await self.queueCoordinator.playPrevious()
            try Task.checkCancellation()
            await self.startSessionForCurrentQueueTrack()
        }
    }

    // MARK: - A-B Loop

    public func setLoopPointA() {
        abLoopState.pointA = currentTime
        let time = currentTime
        Log.logger(.playback).info("Set loop point A at \(time, privacy: .public)")
    }

    public func setLoopPointB() {
        abLoopState.pointB = currentTime
        abLoopState.isEnabled = abLoopState.isValid
        let time = currentTime
        let enabled = abLoopState.isEnabled
        Log.logger(.playback).info("Set loop point B at \(time, privacy: .public), enabled: \(enabled, privacy: .public)")
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

    public func replaceQueue(with tracks: [Track], startIndex: Int? = nil) {
        queueCoordinator.replaceQueue(with: tracks, startIndex: startIndex)
    }

    public func moveQueueItem(fromOffsets source: IndexSet, toOffset destination: Int) {
        queueCoordinator.moveItem(fromOffsets: source, toOffset: destination)
    }

    public func removeQueueItems(at offsets: IndexSet) {
        queueCoordinator.removeItem(at: offsets)
    }

    public func jumpToTrack(_ track: AudioTrack) async throws {
        try await queueCoordinator.jumpToTrack(track)
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
            return await validator.validateBitPerfectPlayback(
                sourceFormat: info,
                outputDevice: nil,
                context: await engineManager.bitPerfectEligibilityContext()
            )
        } catch {
            logger.error("Validation failed: \(error.localizedDescription, privacy: .private)")
            return nil
        }
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
            let eligibilityContext = await engineManager.bitPerfectEligibilityContext()
            let validation = await validator.validateBitPerfectPlayback(
                sourceFormat: info,
                outputDevice: nil,
                context: eligibilityContext
            )

            let devices = await validator.getAvailableDevicesWithCapabilities()
            let defaultDevice = devices.first(where: { $0.device.isDefault }) ?? devices.first
            var dacInfo: DACCompatibilityInfo?
            if let id = defaultDevice?.device.id {
                dacInfo = await validator.getDACCompatibility(for: id)
            }

            let metrics = await monitor.getCurrentMetrics()
            let updatedAt = Date()
            let status = DiagnosticsStatus(
                track: trackSummary(for: track),
                validationResult: validation,
                device: defaultDevice?.device,
                dacInfo: dacInfo,
                metrics: metrics,
                signalPath: SignalPathSnapshot(
                    sourceFormat: info,
                    context: eligibilityContext,
                    validationResult: validation,
                    device: defaultDevice?.device,
                    updatedAt: updatedAt
                ),
                updatedAt: updatedAt,
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
            logger.warning("Diagnostics refresh failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    // MARK: - UI Bridging

    public func setCurrentTrack(_ track: Track?) {
        // Clear A-B loop on track change
        if track?.id != uiStateStore.currentTrack?.id {
            abLoopState.clear()
        }

        uiStateStore.setCurrentTrack(track)
        if track == nil {
            uiStateStore.diagnosticsStatus = .empty
        }
    }

    /// Restores a library track as the paused launch surface when queue
    /// persistence cannot provide a usable current item.
    @discardableResult
    public func restoreLaunchTrack(_ track: Track) -> Bool {
        guard queueManager.currentTrack == nil,
              let resolvedURL = ManagedMediaURLResolver.resolveAvailableURL(track.url)
        else {
            return false
        }

        var snapshot = PlayableTrackSnapshot(track: track)
        snapshot = PlayableTrackSnapshot(
            id: snapshot.id,
            resolvedURL: resolvedURL,
            replayGainTrack: snapshot.replayGainTrack,
            replayGainAlbum: snapshot.replayGainAlbum,
            isAvailable: snapshot.isAvailable,
            isFavorite: snapshot.isFavorite,
            title: snapshot.title,
            artist: snapshot.artist,
            album: snapshot.album,
            audioFormat: snapshot.audioFormat,
            duration: snapshot.duration,
            sampleRate: snapshot.sampleRate,
            bitDepth: snapshot.bitDepth,
            channels: snapshot.channels,
            isLossless: snapshot.isLossless
        )

        guard queueManager.restoreFallbackTrack(snapshot.audioTrack) else { return false }

        // Keep the library model as the presentation source so extended
        // metadata (genre, bitrate, artwork, and user fields) is not lost
        // while the queue receives only the Sendable snapshot currency.
        track.url = resolvedURL
        uiStateStore.restorePersistedTrack(track)
        return true
    }

    // MARK: - Private Helpers

    private func setupStateBindings() {
        // PlaybackStateManager is MainActor-isolated, so forwarding directly
        // keeps pause/resume/seek/error transitions observable during run-loop
        // tracking instead of waiting for a deferred RunLoop hop.
        stateManager.statePublisher
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        uiStateStore.$currentTrack
            .sink { [weak self] track in
                guard let self, self.currentTrack !== track else { return }
                self.currentTrack = track
            }
            .store(in: &cancellables)

        uiStateStore.$showMiniPlayer
            .sink { [weak self] visible in
                guard let self, self.showMiniPlayer != visible else { return }
                self.showMiniPlayer = visible
            }
            .store(in: &cancellables)

        uiStateStore.$diagnosticsStatus
            .sink { [weak self] status in
                guard let self, self.diagnosticsStatus != status else { return }
                self.diagnosticsStatus = status
            }
            .store(in: &cancellables)

        lastObservedQueueState = queueManager.queueState
        queueManager.queueStatePublisher
            .sink { [weak self] state in
                guard let self else { return }
                self.objectWillChange.send()
                let previousState = self.lastObservedQueueState
                self.lastObservedQueueState = state
                let movedIntoPreviouslyPreparedTrack = state.currentTrack?.id == previousState?.nextTrack?.id
                let nextTrackChanged = state.nextTrack?.id != previousState?.nextTrack?.id
                guard nextTrackChanged, !movedIntoPreviouslyPreparedTrack else { return }
                Task { @MainActor [weak self] in
                    guard let self, let engine = self.engineManager.currentEngine else { return }
                    await engine.invalidatePreparedTransition()
                }
            }
            .store(in: &cancellables)
    }

    private func ensureInitializationIsCurrent(_ initializationLifecycleID: UUID) throws {
        try Task.checkCancellation()
        guard initializationLifecycleID == lifecycleID else {
            throw CancellationError()
        }
    }

    func performLatestPlaybackRequest(
        _ operation: @escaping @MainActor () async throws -> Void
    ) async throws {
        let supersededTask = playbackRequestTask
        supersededTask?.cancel()

        let requestID = UUID()
        let task = Task { @MainActor in
            if let supersededTask {
                _ = await supersededTask.result
            }
            try Task.checkCancellation()
            try await operation()
            try Task.checkCancellation()
        }
        playbackRequestTask = task
        playbackRequestID = requestID

        defer {
            if playbackRequestID == requestID {
                playbackRequestTask = nil
                playbackRequestID = nil
            }
        }

        do {
            try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
        } catch is CancellationError {
            // A newer playback command owns the state machine now. Supersession
            // is an expected control-flow event, not a user-facing failure.
            guard playbackRequestID != requestID else {
                throw CancellationError()
            }
        }
    }

    private func cancelPlaybackRequestAndWait() async {
        guard let task = playbackRequestTask else { return }
        let requestID = playbackRequestID
        task.cancel()
        _ = await task.result
        if playbackRequestID == requestID {
            playbackRequestTask = nil
            playbackRequestID = nil
        }
    }

    private func setupServiceIntegrations(lifecycleID initializationLifecycleID: UUID) async throws {
        if cancellables.isEmpty {
            setupStateBindings()
        }

        queueManager.delegate = FacadeQueueDelegateBridge(stateManager: stateManager)
        if let engine = engineManager.currentEngine {
            await monitor.attachToEngine(engine)
            try ensureInitializationIsCurrent(initializationLifecycleID)
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

        logger.info("Audio engine preference changed from \(current, privacy: .public) to \(preferred, privacy: .private)")

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
        await stateCoordinator.handleRouteChange(change)
    }

    public func audioSessionDidReceiveCommand(_ command: RemoteCommand) async {
        await stateCoordinator.handleRemoteCommand(command)
    }

    public func audioSessionMediaServicesWereReset() async {
        monitor.recordPlaybackHealthEvent(.mediaServicesResetDetected)

        let preservedPosition = stateManager.currentState.currentTime
            ?? queueManager.queueState.lastPlaybackPosition

        // AVFoundation guarantees that pre-reset engine objects are invalid.
        // Drop the reference before any fallible recovery work so later commands
        // can never resume the stale object.
        await engineManager.discardEngineAfterMediaServicesReset()

        guard isReady,
              let track = uiStateStore.currentTrack else {
            return
        }

        let preservedDuration = stateManager.currentState.duration ?? track.duration
        stateManager.forceUpdateState(
            .paused(currentTime: preservedPosition, duration: preservedDuration)
        )
        await queueManager.saveState(playbackPosition: preservedPosition)
        sessionService?.pauseSession()

        let queueEntry = queueManager.currentTrack

        do {
            let info = try await formatDetectionManager.detectFormat(at: track.url)
            let recoveredPosition = min(
                max(0, preservedPosition),
                max(0, info.duration)
            )
            await sessionManager.setPreferredSampleRate(info.sampleRate)
            try await playbackController.recoverAfterMediaServicesReset(
                track: track,
                queueEntry: queueEntry,
                info: info,
                preservedPosition: recoveredPosition
            )
            await queueManager.saveState(playbackPosition: recoveredPosition)
            monitor.recordPlaybackHealthEvent(
                .mediaServicesResetRecoverySucceeded,
                detail: "position=\(String(format: "%.3f", recoveredPosition))"
            )
            logger.notice("Recovered paused playback after media-services reset")
        } catch {
            stateManager.forceUpdateState(
                .paused(currentTime: preservedPosition, duration: preservedDuration)
            )
            // Error descriptions can embed file paths; record the stable type
            // name only so the health timeline stays privacy-safe.
            monitor.recordPlaybackHealthEvent(
                .mediaServicesResetRecoveryFailed,
                detail: "reason=\(String(describing: type(of: error)))"
            )
            logger.error(
                "Failed to rebuild playback after media-services reset: \(error.localizedDescription, privacy: .private)"
            )
            reportPlaybackControlError(error)
        }
    }
}

// MARK: - Supporting Types

public struct PlaybackErrorPresentation: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let message: String
}

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
