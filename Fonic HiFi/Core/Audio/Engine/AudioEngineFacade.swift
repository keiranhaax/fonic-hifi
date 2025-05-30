//
//  AudioEngineFacade.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/2025.
//

import Foundation
import Observation
import Combine
import AVFoundation

/// High-level facade that coordinates all audio infrastructure components
/// Provides a unified interface for audio playback, state management, queue operations, 
/// validation, and monitoring
@MainActor
@Observable
public final class AudioEngineFacade: ObservableObject, Sendable {
    
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
    
    // MARK: - Published State
    
    /// Current playback state
    public var currentState: PlaybackState {
        stateManager.currentState
    }
    
    /// Current queue state
    public var queueState: QueueState {
        queueManager.queueState
    }
    
    /// Current track being played
    public var currentTrack: AudioTrack? {
        queueManager.currentTrack
    }
    
    /// Whether audio is currently playing
    public var isPlaying: Bool {
        currentState.isPlaying
    }
    
    /// Whether the facade is properly initialized and ready
    public private(set) var isReady: Bool = false
    
    // MARK: - Publishers for AppState Binding
    
    /// Timer manager for progress updates
    internal let progressTimerManager = ProgressTimerManager()
    
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
        monitor: AudioMonitor? = nil
    ) {
        self.engineConfiguration = configuration
        
        // Initialize services with dependency injection support
        self.sessionManager = sessionManager ?? AudioSessionManager()
        self.formatDetectionManager = formatDetectionManager ?? AudioFormatDetectionManager()
        self.engineFactory = engineFactory ?? AudioEngineFactory()
        self.stateManager = stateManager ?? PlaybackStateManager()
        self.queueManager = queueManager ?? AudioQueueManager()
        self.validator = validator ?? BitPerfectValidator()
        self.monitor = monitor ?? AudioMonitor()
        
        logger.info("AudioEngineFacade initialized with \(configuration.performanceMode) performance mode")
    }
    
    /// Initialize the facade and wire up all service integrations
    public func initialize() async throws {
        guard !isInitialized else {
            logger.warning("AudioEngineFacade already initialized")
            return
        }
        
        logger.info("Initializing AudioEngineFacade...")
        
        do {
            // 1. Initialize audio session
            try await sessionManager.configureAudioSession()
            logger.debug("Audio session configured")
            
            // 2. Setup service integrations
            await setupServiceIntegrations()
            logger.debug("Service integrations configured")
            
            // 3. Initialize monitoring
            await monitor.startMonitoring(updateInterval: 1.0)
            logger.debug("Audio monitoring started")
            
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
        
        // Stop monitoring
        await monitor.stopMonitoring()
        
        // Stop playback
        await stop()
        
        // Cleanup engine
        if let engine = currentEngine {
            await monitor.detachFromEngine()
            currentEngine = nil
        }
        
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
                    logger.warning("Bit-perfect validation failed: \(validationResult.mismatchReason?.userFriendlyDescription ?? "Unknown")")
                }
            }
            
            // 4. Create or reconfigure engine if needed
            try await ensureEngineForFormat(formatInfo)
            
            // 5. Update queue - we're already on MainActor
            if queueManager.currentTrack?.id != track.id {
                queueManager.setCurrentTrack(track.toAudioTrack())
            }
            stateManager.updateState(.loading())
            
            // 6. Load and play
            guard let engine = currentEngine else {
                throw AudioError.engineInitializationFailed(reason: "Engine not ready")
            }
            
            try await engine.load(url: track.url)
            stateManager.updateState(.playing(currentTime: 0, duration: formatInfo.duration))
            
            try await engine.play()
            
            logger.info("Playback started successfully")
            
        } catch {
            // Handle errors - we're already on MainActor
            logger.error("Failed to play track: \(error.localizedDescription)")
            stateManager.updateState(.error(error as? AudioError ?? .playbackFailed(reason: error.localizedDescription), lastKnownTime: nil))
            throw error
        }
    }
    
    /// Resume playback from current position
    public func resume() async throws {
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
            
            try await engine.play()
            
            // Update state to playing with current time
            let currentTime = await engine.currentTime
            let duration = await engine.duration
            stateManager.updateState(.playing(currentTime: currentTime, duration: duration))
            
        } catch {
            logger.error("Failed to resume playback: \(error.localizedDescription)")
            stateManager.updateState(.error(error as? AudioError ?? .playbackFailed(reason: error.localizedDescription), lastKnownTime: nil))
            throw error
        }
    }
    
    /// Pause playback
    public func pause() async {
        guard isReady, let engine = currentEngine else {
            logger.warning("Cannot pause: engine not ready")
            return
        }
        
        logger.info("Pausing playback")
        
        await engine.pause()
        
        // Update state to paused with current time
        let currentTime = await engine.currentTime
        let duration = await engine.duration
        stateManager.updateState(.paused(currentTime: currentTime, duration: duration))
    }
    
    /// Stop playback completely
    public func stop() async {
        guard let engine = currentEngine else {
            stateManager.updateState(.stopped)
            return
        }
        
        logger.info("Stopping playback")
        
        await engine.stop()
        stateManager.updateState(.stopped)
    }
    
    /// Seek to a specific time position
    /// - Parameter time: Target time in seconds
    public func seek(to time: TimeInterval) async throws {
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
        
        queueManager.setCurrentTrack(nextTrack)
        
        // Convert AudioTrack back to Track for engine compatibility
        // For now, we'll create a temporary Track from AudioTrack data
        // In a real implementation, you'd want to maintain a mapping or store full Track objects
        let track = createTrackFromAudioTrack(nextTrack)
        try await play(track: track)
    }
    
    /// Play the previous track in the queue
    public func playPrevious() async throws {
        guard let previousTrack = queueManager.previous() else {
            logger.info("No previous track available")
            return
        }
        
        queueManager.setCurrentTrack(previousTrack)
        
        // Convert AudioTrack back to Track for engine compatibility
        let track = createTrackFromAudioTrack(previousTrack)
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
        guard let currentTrack = currentTrack else {
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
        return await monitor.performDiagnosticsCheck()
    }
    
    /// Get current audio metrics
    public func getCurrentMetrics() async -> AudioMetrics {
        return await monitor.getCurrentMetrics()
    }
    
    // MARK: - Private Implementation
    
    private func setupServiceIntegrations() async {
        logger.debug("Setting up service integrations...")
        
        // 1. Queue manager delegate for state updates
        queueManager.delegate = QueueToStateBridge(stateManager: stateManager)
        
        // 2. State manager updates from playback timer
        setupPlaybackTimeUpdates()
        
        // 3. Monitor integration
        if let engine = currentEngine {
            await monitor.attachToEngine(engine)
        }
        
        // 4. Session delegate for interruption handling
        sessionManager.delegate = self
        
        logger.debug("Service integrations complete")
    }
    
    private func ensureEngineForFormat(_ formatInfo: AudioFileInfo) async throws {
        // Check if current engine can handle this format
        if let engine = currentEngine {
            // For now, assume AVAudioEngine can handle all our supported formats
            // In the future, we might need format-specific engines
            return
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
        guard let engine = currentEngine else { return }
        
        // For now, we'll recreate the engine with new configuration
        // In a more sophisticated implementation, we might support runtime reconfiguration
        logger.info("Engine configuration updated - may require recreation for some changes")
    }
    
    private func setupPlaybackTimeUpdates() {
        // Set up a timer to periodically update playback time in state manager
        // Use DispatchQueue.main.async to ensure timer callback is on main thread
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            // Timer callbacks can run on background threads, so explicitly dispatch to main
            DispatchQueue.main.async {
                guard let self = self else { return }
                Task { @MainActor in
                    guard let engine = self.currentEngine,
                          self.currentState.isPlaying else {
                        return
                    }
                    
                    let currentTime = await engine.currentTime
                    let duration = await engine.duration
                    self.stateManager.updateTime(currentTime, duration: duration)
                }
            }
        }
        
        // Store timer for cleanup
        AnyCancellable {
            timer.invalidate()
        }.store(in: &cancellables)
    }
    
    private func handleSessionInterruption(_ interruption: AudioInterruptionType) async {
        switch interruption {
        case .began:
            logger.info("Audio session interrupted - pausing playback")
            await pause()
        case .ended(let shouldResume):
            if shouldResume {
                logger.info("Audio session interruption ended - resuming playback")
                try? await resume()
            }
        }
    }
    
    /// Helper method to create a Track from AudioTrack data
    /// This is a temporary solution for type conversion compatibility
    private func createTrackFromAudioTrack(_ audioTrack: AudioTrack) -> Track {
        return Track(
            url: audioTrack.url,
            title: audioTrack.title,
            artist: audioTrack.artist,
            album: audioTrack.album,
            audioFormat: audioTrack.audioFormat,
            duration: audioTrack.duration
        )
    }
}

// MARK: - Supporting Types

/// Bridge to connect queue changes to state updates
private class QueueToStateBridge: AudioQueueDelegate {
    private let stateManager: PlaybackStateManager
    
    init(stateManager: PlaybackStateManager) {
        self.stateManager = stateManager
    }
    
    func audioQueue(_ queue: AudioQueue, didChangeCurrentTrack track: AudioTrack?, at index: Int?) {
        // Queue changed, but we don't automatically change state here
        // The facade will handle this through explicit play commands
    }
    
    func audioQueue(_ queue: AudioQueue, didEncounterError error: AudioError) {
        // Forward queue errors to state manager
        stateManager.handleEngineError(error)
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
        case .seek(let time):
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

extension Logger {
    init(subsystem: String, category: String) {
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