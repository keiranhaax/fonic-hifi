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
import UIKit

/// High-level facade that coordinates all audio infrastructure components
/// Provides a unified interface for audio playback, state management, queue operations,
/// validation, and monitoring
///
/// Phase 3: Now serves as the single source of truth for all audio-related state,
/// including UI state previously managed by AppState
@MainActor
public final class AudioEngineFacade: ObservableObject {
    // MARK: - Core Services

    /// Audio session management
    public let sessionManager: AudioSessionManager

    /// Format detection and validation
    public let formatDetectionManager: AudioFormatDetectionManager

    /// Engine factory for creating appropriate audio engines
    public let engineFactory: AudioEngineFactory

    /// Current audio engine instance
    public private(set) var currentEngine: AudioEngineService?

    /// Playback state management
    public let stateManager: PlaybackStateManager

    /// Audio queue management
    public let queueManager: AudioQueueManager

    /// Bit-perfect validation
    public let validator: BitPerfectValidator

    /// Audio monitoring and metrics
    public let monitor: AudioMonitor

    /// Persistent playback settings store
    public let playbackSettingsStore: AudioPlaybackSettingsStore

    // MARK: - Published State

    /// Current playback state
    public var currentState: PlaybackState {
        stateManager.currentState
    }

    /// Current queue state
    public var queueState: QueueState {
        queueManager.queueState
    }

    /// Whether audio is currently playing
    public var isPlaying: Bool {
        currentState.isPlaying
    }

    /// Whether the facade is properly initialized and ready
    public private(set) var isReady: Bool = false

    // MARK: - UI State (merged from AppState)

    /// Currently playing track (UI representation)
    @Published public var currentTrack: Track? {
        didSet {
            let title = currentTrack?.title ?? "nil"
            print("currentTrack changed to: \(title)")
        }
    }

    /// Live diagnostics summary for the current playback session
    @Published public private(set) var diagnosticsStatus: DiagnosticsStatus = .empty

    /// Whether the mini player should be visible
    @Published public var showMiniPlayer: Bool = false

    // MARK: - Derived Properties

    /// Progress of the current track (0.0 to 1.0)
    public var playbackProgress: Double {
        currentState.progress ?? 0.0
    }

    /// Current playback time in seconds
    public var currentTime: TimeInterval {
        currentState.currentTime ?? 0.0
    }

    /// Duration of the current track in seconds
    public var duration: TimeInterval {
        currentState.duration ?? 0.0
    }

    // MARK: - Progress Management

    /// Timer manager for progress updates - no longer needs AppState binding
    let progressTimer = ProgressTimerManager()

    // MARK: - Thread Management

    /// Dedicated queue for audio operations to prevent dispatch assertion failures
    private let audioQueue = DispatchQueue(label: "com.fonichifi.audio.engine", qos: .userInitiated)

    // MARK: - Configuration

    /// Current audio engine configuration
    public private(set) var engineConfiguration: AudioEngineConfiguration

    /// Performance mode setting
    public var performanceMode: PerformanceMode {
        get { engineConfiguration.performanceMode }
        set {
            engineConfiguration = engineConfiguration.with(performanceMode: newValue)
            Task { await updateEngineConfiguration() }
        }
    }

    /// Crossfade duration convenience accessor
    public var crossfadeDuration: TimeInterval { engineConfiguration.crossfadeDuration }

    /// Replay gain mode accessor
    public var replayGainMode: ReplayGainMode { engineConfiguration.replayGainMode }

    /// Playback rate accessor
    public var playbackRate: Double { engineConfiguration.playbackRate }

    public func updateCrossfadeDuration(_ duration: TimeInterval) async {
        objectWillChange.send()
        engineConfiguration = engineConfiguration.with(crossfadeDuration: duration)
        await playbackSettingsStore.setCrossfadeDuration(duration)
    }

    public func updateReplayGainMode(_ mode: ReplayGainMode) async {
        objectWillChange.send()
        engineConfiguration = engineConfiguration.with(replayGainMode: mode)
        await playbackSettingsStore.setReplayGainMode(mode)

        if let track = currentTrack, let engine = currentEngine {
            let gain = replayGainValue(for: track, mode: mode)
            await engine.applyReplayGain(gain)
        }
    }

    public func updatePlaybackRate(_ rate: Double) async {
        objectWillChange.send()
        engineConfiguration = engineConfiguration.with(playbackRate: rate)
        await playbackSettingsStore.setPlaybackRate(rate)

        if let engine = currentEngine {
            await engine.setPlaybackRate(rate)
            if let track = currentTrack {
                let duration = await engine.duration
                await updateNowPlayingInfo(track: track, duration: duration)
            }
        }
    }

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.fonichifi.audio", category: "AudioEngineFacade")
    private var isInitialized = false

    // MARK: - Initialization

    public init(
        configuration: AudioEngineConfiguration = .default,
        sessionManager: AudioSessionManager? = nil,
        formatDetectionManager: AudioFormatDetectionManager? = nil,
        engineFactory: AudioEngineFactory? = nil,
        stateManager: PlaybackStateManager? = nil,
        queueManager: AudioQueueManager? = nil,
        validator: BitPerfectValidator? = nil,
        monitor: AudioMonitor? = nil,
        playbackSettingsStore: AudioPlaybackSettingsStore? = nil
    ) {
        engineConfiguration = configuration

        // Initialize services with dependency injection support
        self.sessionManager = sessionManager ?? AudioSessionManager()
        self.formatDetectionManager = formatDetectionManager ?? AudioFormatDetectionManager()
        self.engineFactory = engineFactory ?? AudioEngineFactory()
        self.stateManager = stateManager ?? PlaybackStateManager()
        self.queueManager = queueManager ?? AudioQueueManager()
        self.validator = validator ?? BitPerfectValidator()
        self.monitor = monitor ?? AudioMonitor()
        self.playbackSettingsStore = playbackSettingsStore ?? AudioPlaybackSettingsStore()

        logger.info("AudioEngineFacade initialized with \(configuration.performanceMode) performance mode")

        // Setup playback state observation for UI updates
        setupPlaybackStateObservation()
    }

    /// Initialize the facade and wire up all service integrations
    public func initialize() async throws {
        guard !isInitialized else {
            logger.warning("AudioEngineFacade already initialized")
            return
        }

        logger.info("Initializing AudioEngineFacade...")

        do {
            engineConfiguration = await playbackSettingsStore.configuration(merging: engineConfiguration)

            // 1. Initialize audio session
            try await sessionManager.configureAudioSession()
            logger.debug("Audio session configured")

            // 2. Setup service integrations
            await setupServiceIntegrations()
            logger.debug("Service integrations configured")

            // 3. Initialize monitoring
            await monitor.startMonitoring(updateInterval: 1.0)
            logger.debug("Audio monitoring started")

            // 4. Enable remote commands for Control Center
            await sessionManager.enableRemoteCommands()
            logger.debug("Remote commands enabled")

            // 5. Restore queue state from previous session
            if queueManager.restoreState() {
                logger.info("Queue state restored from previous session")

                // If we have a current track, update UI state
                if let currentTrack = queueManager.currentTrack {
                    self.currentTrack = Track(
                        url: currentTrack.url,
                        title: currentTrack.title,
                        artist: currentTrack.artist,
                        album: currentTrack.album,
                        audioFormat: currentTrack.audioFormat
                    )
                    showMiniPlayer = true
                    logger.info("Restored current track: \(currentTrack.title)")
                }
            } else {
                logger.debug("No saved queue state to restore")
            }

            isInitialized = true
            isReady = true

            logger.info("AudioEngineFacade initialization complete")

        } catch {
            logger.error("AudioEngineFacade initialization failed: \(error.localizedDescription)")
            isReady = false
            throw AudioError.engineInitializationFailed(reason: error.localizedDescription)
        }
    }

    /// Shutdown the facade and cleanup resources
    public func shutdown() async {
        logger.info("Shutting down AudioEngineFacade...")

        // Stop progress timer
        progressTimer.stop()

        // Stop monitoring
        await monitor.stopMonitoring()

        // Stop playback
        await stop()

        // Cleanup engine properly
        await cleanupCurrentEngine()

        // Cancel subscriptions
        cancellables.removeAll()

        isReady = false
        isInitialized = false

        logger.info("AudioEngineFacade shutdown complete")
    }

    // MARK: - Playback Control

    /// Play a specific track
    /// - Parameter track: The track to play
    public func play(track: Track) async throws {
        assertMainThread()

        guard isReady else {
            throw AudioError.engineInitializationFailed(reason: "Engine not ready")
        }

        logger.info("Playing track: \(track.title)")

        // Ensure we're on MainActor since this is a public API
        dispatchPrecondition(condition: .onQueue(.main))

        do {
            // 1. Ensure audio session is active first
            try await sessionManager.activateAudioSession()
            logger.debug("Audio session activated")

            // 2. Detect format
            let formatInfo = try await formatDetectionManager.detectFormat(at: track.url)
            logger.debug("Format detected: \(formatInfo.format.displayName)")

            // 3. Validate bit-perfect capability if needed
            if engineConfiguration.performanceMode == .quality {
                let validationResult = await validator.validateBitPerfectPlayback(
                    sourceFormat: formatInfo,
                    outputDevice: nil
                )

                if !validationResult.isValid {
                    let reason = validationResult.mismatchReason?.userFriendlyDescription ?? "Unknown"
                    logger.warning("Bit-perfect validation failed: \(reason)")
                }
            }

            // 4. Create or reconfigure engine if needed
            try await ensureEngineForFormat(formatInfo)

            // 5. Update queue - we're already on MainActor
            if queueManager.currentTrack?.id != track.id {
                queueManager.setCurrentTrack(track.toAudioTrack())
            }
            currentTrack = track
            showMiniPlayer = true
            stateManager.updateState(.loading())

            // 6. Load and play
            guard let engine = currentEngine else {
                throw AudioError.engineInitializationFailed(reason: "Engine not ready")
            }

            try await engine.load(url: track.url)
            await applyPlaybackParameters(for: track)

            try await engine.play()

            stateManager.updateState(.playing(currentTime: 0, duration: formatInfo.duration))

            // Update Now Playing info for Control Center
            await updateNowPlayingInfo(track: track, duration: formatInfo.duration)

            // Start progress timer for continuous updates (batched at 0.2s intervals)
            startProgressTracking()

            logger.info("Playback started successfully")
            await refreshDiagnostics(for: track, formatInfo: formatInfo)
            await prepareUpcomingTrack()

        } catch {
            // Handle errors - we're already on MainActor
            logger.error("Failed to play track: \(error.localizedDescription)")
            stateManager.updateState(.error(error as? AudioError ?? .playbackFailed(reason: error.localizedDescription), lastKnownTime: nil))
            throw error
        }
    }

    /// Resume playback from current position
    public func resume() async throws {
        assertMainThread()

        guard isReady else {
            throw AudioError.engineInitializationFailed(reason: "Engine not ready")
        }

        guard let engine = currentEngine else {
            throw AudioError.engineInitializationFailed(reason: "Engine not ready")
        }

        logger.info("Resuming playback")

        do {
            if let nextState = currentState.nextPlayState {
                stateManager.updateState(nextState)
            }

            if let track = currentTrack {
                await applyPlaybackParameters(for: track)
            }

            try await engine.play()

            // Update state to playing with current time
            let currentTime = await engine.currentTime
            let duration = await engine.duration
            stateManager.updateState(.playing(currentTime: currentTime, duration: duration))

            if let track = currentTrack {
                await updateNowPlayingInfo(track: track, duration: duration)
                await prepareUpcomingTrack()
                await refreshDiagnostics(for: track)
            }

            // Restart progress timer (batched at 0.2s intervals)
            startProgressTracking()

        } catch {
            logger.error("Failed to resume playback: \(error.localizedDescription)")
            stateManager.updateState(.error(error as? AudioError ?? .playbackFailed(reason: error.localizedDescription), lastKnownTime: nil))
            throw error
        }
    }

    /// Pause playback
    public func pause() async {
        assertMainThread()

        guard isReady, let engine = currentEngine else {
            logger.warning("Cannot pause: engine not ready")
            return
        }

        logger.info("Pausing playback")

        // Stop progress timer
        progressTimer.stop()

        await engine.pause()

        // Update state to paused with current time
        let currentTime = await engine.currentTime
        let duration = await engine.duration
        stateManager.updateState(.paused(currentTime: currentTime, duration: duration))
    }

    /// Stop playback completely
    public func stop() async {
        assertMainThread()

        guard let engine = currentEngine else {
            stateManager.updateState(.stopped)
            return
        }

        logger.info("Stopping playback")

        // Stop progress timer
        progressTimer.stop()

        await engine.stop()
        stateManager.updateState(.stopped)

        // Clear Now Playing info
        await clearNowPlayingInfo()

        // Clear the current track
        currentTrack = nil
        showMiniPlayer = false
        diagnosticsStatus = .empty
    }

    /// Seek to a specific time position
    /// - Parameter time: Target time in seconds
    public func seek(to time: TimeInterval) async throws {
        assertMainThread()

        guard isReady, let engine = currentEngine else {
            throw AudioError.engineInitializationFailed(reason: "Engine not ready")
        }

        guard currentState.canSeek else {
            throw AudioError.playbackFailed(reason: "Cannot seek in current state")
        }

        logger.info("Seeking to \(time)s")

        let currentTime = await engine.currentTime
        let duration = await engine.duration

        stateManager.updateState(.seeking(targetTime: time, currentTime: currentTime))

        do {
            try await engine.seek(to: time)

            // Update state based on previous playing status
            if currentState.isPlaying {
                stateManager.updateState(.playing(currentTime: time, duration: duration))
            } else {
                stateManager.updateState(.paused(currentTime: time, duration: duration))
            }

        } catch {
            logger.error("Seek failed: \(error.localizedDescription)")
            // Restore previous state
            if currentState.isPlaying {
                stateManager.updateState(.playing(currentTime: currentTime, duration: duration))
            } else {
                stateManager.updateState(.paused(currentTime: currentTime, duration: duration))
            }
            throw error
        }
    }

    // MARK: - Queue Operations

    /// Play the next track in the queue
    public func playNext() async throws {
        guard let nextTrack = queueManager.next() else {
            logger.info("No next track available")
            await stop()
            return
        }
        let track = createTrackFromAudioTrack(nextTrack)

        if crossfadeDuration > 0,
           currentState.isPlaying,
           let engine = currentEngine
        {
            queueManager.setCurrentTrack(nextTrack)
            currentTrack = track
            showMiniPlayer = true
            stateManager.updateState(.loading())

            let gain = replayGainValue(for: nextTrack, mode: replayGainMode)
            try await engine.crossfade(
                to: nextTrack.url,
                duration: crossfadeDuration,
                playbackRate: playbackRate,
                gainDB: gain
            )

            stateManager.updateState(.playing(currentTime: 0, duration: nextTrack.duration))
            await updateNowPlayingInfo(track: track, duration: nextTrack.duration)
            startProgressTracking()
            await refreshDiagnostics(for: track)
            await prepareUpcomingTrack()
            return
        }

        queueManager.setCurrentTrack(nextTrack)
        try await play(track: track)
    }

    /// Play the previous track in the queue
    public func playPrevious() async throws {
        guard let previousTrack = queueManager.previous() else {
            logger.info("No previous track available")
            return
        }

        let track = createTrackFromAudioTrack(previousTrack)

        if crossfadeDuration > 0,
           currentState.isPlaying,
           let engine = currentEngine
        {
            queueManager.setCurrentTrack(previousTrack)
            currentTrack = track
            showMiniPlayer = true
            stateManager.updateState(.loading())

            let gain = replayGainValue(for: previousTrack, mode: replayGainMode)
            try await engine.crossfade(
                to: previousTrack.url,
                duration: crossfadeDuration,
                playbackRate: playbackRate,
                gainDB: gain
            )

            stateManager.updateState(.playing(currentTime: 0, duration: previousTrack.duration))
            await updateNowPlayingInfo(track: track, duration: previousTrack.duration)
            startProgressTracking()
            await refreshDiagnostics(for: track)
            await prepareUpcomingTrack()
            return
        }

        queueManager.setCurrentTrack(previousTrack)
        try await play(track: track)
    }

    /// Add tracks to the queue
    /// - Parameter tracks: Tracks to add
    public func enqueue(_ tracks: [Track]) {
        let audioTracks = tracks.map { $0.toAudioTrack() }
        queueManager.enqueue(tracks: audioTracks)
        logger.info("Enqueued \(tracks.count) tracks")
    }

    /// Add a track to play next
    /// - Parameter track: Track to play next
    public func enqueueNext(_ track: Track) {
        queueManager.enqueueNext(tracks: [track.toAudioTrack()])
        logger.info("Enqueued next: \(track.title)")
    }

    /// Set shuffle mode
    /// - Parameter mode: Shuffle mode to set
    public func setShuffleMode(_ mode: QueueShuffleMode) {
        queueManager.shuffleMode = mode
        logger.info("Shuffle mode set to: \(mode)")
    }

    /// Set repeat mode
    /// - Parameter mode: Repeat mode to set
    public func setRepeatMode(_ mode: QueueRepeatMode) {
        queueManager.repeatMode = mode
        logger.info("Repeat mode set to: \(mode)")
    }

    // MARK: - Validation & Diagnostics

    /// Perform comprehensive validation of current playback setup
    public func validatePlaybackSetup() async -> BitPerfectValidationResult? {
        guard let currentTrack else {
            return nil
        }

        do {
            let formatInfo = try await formatDetectionManager.detectFormat(at: currentTrack.url)
            return await validator.validateBitPerfectPlayback(
                sourceFormat: formatInfo,
                outputDevice: nil
            )
        } catch {
            logger.error("Validation failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Get current diagnostics snapshot
    public func getCurrentDiagnostics() async -> PlaybackDiagnostics {
        await monitor.performDiagnosticsCheck()
    }

    /// Get current audio metrics
    public func getCurrentMetrics() async -> AudioMetrics {
        await monitor.getCurrentMetrics()
    }

    /// Refresh diagnostics for the provided track, optionally reusing detected format info
    public func refreshDiagnostics(for track: Track, formatInfo: AudioFileInfo? = nil) async {
        do {
            let info: AudioFileInfo
            if let provided = formatInfo {
                info = provided
            } else {
                info = try await formatDetectionManager.detectFormat(at: track.url)
            }
            let validation = await validator.validateBitPerfectPlayback(
                sourceFormat: info,
                outputDevice: nil
            )

            let devices = await validator.getAvailableDevicesWithCapabilities()
            let defaultDevice = devices.first(where: { $0.device.isDefault }) ?? devices.first
            var dacInfo: DACCompatibilityInfo?
            if let id = defaultDevice?.device.id {
                dacInfo = await validator.getDACCompatibility(for: id)
            }

            let metrics = await monitor.getCurrentMetrics()
            diagnosticsStatus = DiagnosticsStatus(
                track: trackSummary(for: track),
                validationResult: validation,
                device: defaultDevice?.device,
                dacInfo: dacInfo,
                metrics: metrics,
                updatedAt: Date()
            )
        } catch {
            let metrics = await monitor.getCurrentMetrics()
            diagnosticsStatus = DiagnosticsStatus(
                track: trackSummary(for: track),
                validationResult: nil,
                device: nil,
                dacInfo: nil,
                metrics: metrics,
                updatedAt: Date()
            )
            logger.warning("Diagnostics refresh failed: \(error.localizedDescription)")
        }
    }

    // MARK: - UI State Management (merged from AppState)

    /// Updates the current track and shows mini player
    public func setCurrentTrack(_ track: Track?) {
        guard let track else {
            currentTrack = nil
            showMiniPlayer = false
            diagnosticsStatus = .empty
            return
        }

        // Store the Track object directly
        currentTrack = track
        showMiniPlayer = true
    }

    /// Setup observation of playback state changes for UI updates
    private func setupPlaybackStateObservation() {
        stateManager.statePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] change in
                // Update derived UI state when playback state changes
                self?.handlePlaybackStateChange(change)
            }
            .store(in: &cancellables)
    }

    /// Handle playback state changes and update UI accordingly
    private func handlePlaybackStateChange(_ change: PlaybackStateChange) {
        // Update mini player visibility based on playback state
        switch change.to {
        case .idle, .stopped:
            showMiniPlayer = false
        case .playing, .paused, .loading, .buffering:
            showMiniPlayer = true
        default:
            break
        }

        // Trigger UI updates for derived properties
        objectWillChange.send()
    }

    /// Access to the playback state manager for advanced operations
    public var playbackManager: PlaybackStateManager {
        stateManager
    }

    // MARK: - Private Implementation

    /// Update Now Playing info for Control Center and Lock Screen
    private func updateNowPlayingInfo(track: Track, duration: TimeInterval) async {
        let nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0,
            MPNowPlayingInfoPropertyPlaybackRate: playbackRate
        ]

        await sessionManager.updateNowPlayingInfo(nowPlayingInfo)
    }

    /// Clear Now Playing info when playback stops
    private func clearNowPlayingInfo() async {
        await sessionManager.clearNowPlayingInfo()
    }

    private func setupServiceIntegrations() async {
        logger.debug("Setting up service integrations...")

        // 1. Queue manager delegate for state updates
        queueManager.delegate = QueueToStateBridge(stateManager: stateManager)

        // 2. Progress timer will be started when playback begins

        // 3. Monitor integration
        if let engine = currentEngine {
            await monitor.attachToEngine(engine)
        }

        // 4. Session delegate for interruption handling
        sessionManager.delegate = self

        // 5. Monitor audio engine preference changes
        setupPreferenceMonitoring()

        logger.debug("Service integrations complete")
    }

    private func setupPreferenceMonitoring() {
        // Observe changes to the preferred audio engine setting
        NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.handlePreferenceChange()
                }
            }
            .store(in: &cancellables)

        logger.debug("Preference monitoring configured")
    }

    private func handlePreferenceChange() async {
        let newPreference = UserDefaults.standard.string(forKey: "preferredAudioEngine") ?? "AVAudioEngine"

        // Determine current engine type
        let currentEngineType = if let engine = currentEngine {
            switch engine {
            case is AudioKitEngineAdapter:
                "AudioKit"
            case is AVAudioEngineAdapter:
                "AVAudioEngine"
            default:
                "Unknown"
            }
        } else {
            "None"
        }

        // Check if preference actually changed
        if currentEngineType == newPreference ||
            (newPreference == "AudioKitEngine" && currentEngineType == "AudioKit")
        {
            return // No change needed
        }

        logger.info("Audio engine preference changed from \(currentEngineType) to \(newPreference)")

        // If we're not idle, the engine will be recreated on the next load
        // The PlaybackCoordinator's ensureEngineForFormat will handle the switch
        let currentState = stateManager.currentState
        if !currentState.isIdle {
            logger.debug("Engine will be recreated on next playback to honor preference change")
        }
    }

    /// Cleanup current engine properly to avoid memory leaks
    private func cleanupCurrentEngine() async {
        guard let engine = currentEngine else { return }

        // Stop playback if needed
        if await engine.isPlaying {
            await engine.stop()
        }

        // Detach from monitoring
        await monitor.detachFromEngine()

        // Clear reference to allow deallocation
        currentEngine = nil

        logger.debug("Cleaned up previous audio engine")
    }

    private func ensureEngineForFormat(_ formatInfo: AudioFileInfo) async throws {
        // Check if we need a different engine type for this format
        let requiredEngineType = engineFactory.selectEngineType(
            for: formatInfo.format,
            configuration: engineConfiguration
        )

        // Check if current engine is the right type
        if let engine = currentEngine {
            let currentEngineType: AudioEngineType = engine is AudioKitEngineAdapter ? .audioKitEngine : .avAudioEngine

            if currentEngineType == requiredEngineType {
                // Current engine can handle this format
                return
            }

            // Need to switch engines - cleanup current one first
            logger.debug("Switching from \(currentEngineType) to \(requiredEngineType)")
            await cleanupCurrentEngine()
        }

        // Create new engine
        let engine = try await engineFactory.makeEngine(
            for: formatInfo.format,
            configuration: engineConfiguration
        )

        // Attach to monitoring
        await monitor.attachToEngine(engine)

        currentEngine = engine
        logger.debug("Created new audio engine for format: \(formatInfo.format.displayName)")
    }

    private func updateEngineConfiguration() async {
        guard currentEngine != nil else { return }
        logger.info("Engine configuration updated - may require recreation for some changes")
    }

    /// Set the current engine (internal use by coordinators)
    func setCurrentEngine(_ engine: AudioEngineService?) {
        assertMainThread()
        currentEngine = engine
    }

    private func handleSessionInterruption(_ interruption: AudioInterruptionType) async {
        switch interruption {
        case .began:
            logger.info("Audio session interrupted - pausing playback")
            await pause()
        case let .ended(shouldResume):
            if shouldResume {
                logger.info("Audio session interruption ended - resuming playback")
                try? await resume()
            }
        }
    }

    private func replayGainValue(for track: any TrackProtocol, mode: ReplayGainMode) -> Float {
        switch mode {
        case .off:
            0
        case .track:
            track.replayGainTrack ?? 0
        case .album:
            track.replayGainAlbum ?? track.replayGainTrack ?? 0
        }
    }

    private func applyPlaybackParameters(for track: any TrackProtocol) async {
        guard let engine = currentEngine else { return }
        await engine.setPlaybackRate(engineConfiguration.playbackRate)
        let gain = replayGainValue(for: track, mode: replayGainMode)
        await engine.applyReplayGain(gain)
    }

    private func prepareUpcomingTrack() async {
        guard engineConfiguration.enableGapless || crossfadeDuration > 0,
              let engine = currentEngine,
              let nextTrack = queueManager.getNextTrack() else { return }

        await engine.prepareNext(url: nextTrack.url)
    }

    private func startProgressTracking() {
        progressTimer.start(pollInterval: 0.2) { [weak self] in
            guard let self,
                  let engine = currentEngine,
                  currentState.isPlaying
            else {
                return
            }

            Task { @MainActor in
                async let currentTime = engine.currentTime
                async let duration = engine.duration

                let (time, dur) = await (currentTime, duration)
                self.stateManager.updateTime(time, duration: dur)
            }
        }
    }

    private func trackSummary(for track: Track) -> TrackSummary {
        TrackSummary(
            id: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album,
            format: track.audioFormat
        )
    }

    /// Helper method to create a Track from AudioTrack data
    /// This is a temporary solution for type conversion compatibility
    private func createTrackFromAudioTrack(_ audioTrack: AudioTrack) -> Track {
        let track = Track(
            url: audioTrack.url,
            title: audioTrack.title,
            artist: audioTrack.artist,
            album: audioTrack.album,
            audioFormat: audioTrack.audioFormat,
            duration: audioTrack.duration
        )
        track.replayGainTrack = audioTrack.replayGainTrack
        track.replayGainAlbum = audioTrack.replayGainAlbum
        return track
    }
}

// MARK: - AudioSessionDelegate

extension AudioEngineFacade: AudioSessionDelegate {
    public func audioSessionDidInterrupt(_ interruption: AudioInterruptionType) async {
        await handleSessionInterruption(interruption)
    }

    public func audioSessionRouteDidChange(_ change: AudioRouteChange) async {
        logger.info("Audio route changed: \(change.currentRoute) (reason: \(change.reason))")
        // Handle route changes if needed
    }

    public func audioSessionDidReceiveCommand(_ command: RemoteCommand) async {
        switch command {
        case .play:
            try? await resume()
        case .pause:
            await pause()
        case .stop:
            await stop()
        case .nextTrack:
            try? await playNext()
        case .previousTrack:
            try? await playPrevious()
        case let .seek(time):
            try? await seek(to: time)
        default:
            logger.debug("Unhandled remote command: \(command)")
        }
    }
}

// MARK: - Extensions

extension Timer {
    func store(in set: inout Set<AnyCancellable>) {
        AnyCancellable { [weak self] in
            self?.invalidate()
        }.store(in: &set)
    }
}

extension AudioError {
    static let engineNotReady = AudioError.engineInitializationFailed
    static let invalidOperation = AudioError.playbackFailed
}

// MARK: - Thread Safety Utilities

extension AudioEngineFacade {
    /// Assert that we're running on the main thread
    /// Helps catch threading issues during development
    private func assertMainThread(
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        #if DEBUG
            assert(
                Thread.isMainThread,
                "\(function) must be called on the main thread. Called from \(file):\(line)"
            )
        #endif
    }
}

extension Logger {
    init(subsystem _: String, category _: String) {
        // For now, use a simple logger
        // In production, this would be properly configured
        self.init()
    }

    func info(_ message: String) {
        print("[INFO] [\(Date())] \(message)")
    }

    func debug(_ message: String) {
        print("[DEBUG] [\(Date())] \(message)")
    }

    func warning(_ message: String) {
        print("[WARNING] [\(Date())] \(message)")
    }

    func error(_ message: String) {
        print("[ERROR] [\(Date())] \(message)")
    }
}

private struct Logger {
    init() {}
}
