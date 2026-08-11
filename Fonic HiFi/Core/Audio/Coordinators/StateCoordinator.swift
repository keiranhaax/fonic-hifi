//
//  StateCoordinator.swift
//  Fonic HiFi
//
//  Manages state synchronization, publisher management, and state change notifications.
//  Extracted from AudioEngineFacade to improve modularity and maintainability.
//

import Combine
import Foundation
import OSLog

@MainActor
protocol AudioStateCoordinatorOwner: AnyObject {
    var isRuntimeMonitoringEnabled: Bool { get }
    var stateCoordinatorMonitor: any AudioPerformanceMonitoring { get }

    func resume() async throws
    func pause() async
    func stop() async
    func playNext() async throws
    func playPrevious() async throws
    func seek(to time: TimeInterval) async throws
    func renegotiatePreferredSampleRate() async
    func reportPlaybackControlError(_ error: Error)
}

/// Handles state synchronization and notifications across the audio system
@MainActor
public final class StateCoordinator {
    // MARK: - Dependencies

    private let stateManager: PlaybackStateManager
    private let queueManager: AudioQueueManager
    private let sessionManager: AudioSessionManager
    private let uiStateStore: AudioUIState
    private let monitor: any AudioPerformanceMonitoring
    private weak var facade: (any AudioStateCoordinatorOwner)?

    // MARK: - State Publishing

    private var cancellables = Set<AnyCancellable>()
    private let logger = Log.logger(.audioStateCoordinator)
    private var shouldResumeAfterInterruption = false

    // MARK: - Initialization

    init(
        stateManager: PlaybackStateManager,
        queueManager: AudioQueueManager,
        sessionManager: AudioSessionManager,
        uiStateStore: AudioUIState,
        facade: any AudioStateCoordinatorOwner,
        monitor: (any AudioPerformanceMonitoring)? = nil,
    ) {
        self.stateManager = stateManager
        self.queueManager = queueManager
        self.sessionManager = sessionManager
        self.uiStateStore = uiStateStore
        self.facade = facade
        self.monitor = monitor ?? facade.stateCoordinatorMonitor

        setupStateObservation()
        setupServiceIntegrations()
    }

    // Cancellables are automatically cleaned up when the coordinator is deallocated

    // MARK: - State Access

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

    // MARK: - State Updates

    /// Update the current track without revealing playback UI prematurely.
    public func setCurrentTrack(_ track: Track?) {
        uiStateStore.setCurrentTrack(track)
    }

    /// Handle playback state changes and update UI accordingly
    public func handlePlaybackStateChange(_ change: PlaybackStateChange) {
        // Reveal the mini player only once playback is actually running.
        // Paused/idle transitions (such as restored launch state) must not
        // surface it, and it stays visible after a pause mid-session.
        if change.nextState.isPlaying {
            uiStateStore.revealMiniPlayerAfterPlaybackStarted()
        }

        // Log state transitions for debugging
        logger.debug(
            "State transition: \(change.from, privacy: .private) → \(change.nextState, privacy: .private)"
        )

        // Notify observers of state changes (handled automatically by @Observable)
    }

    // MARK: - Service Integration

    /// Setup service integrations and delegates
    private func setupServiceIntegrations() {
        logger.debug("Setting up service integrations...")

        // Session delegate for interruption handling
        sessionManager.delegate = facade as? any AudioSessionDelegate

        logger.debug("Service integrations complete")
    }

    /// Setup observation of playback state changes for UI updates
    private func setupStateObservation() {
        stateManager.statePublisher
            .sink { [weak self] change in
                // Update derived UI state when playback state changes
                self?.handlePlaybackStateChange(change)
            }
            .store(in: &cancellables)

        // Adjust monitoring based on playback state
        stateManager.statePublisher
            .map(\.nextState)
            .removeDuplicates { lhs, rhs in
                // Only care about state type changes, not time updates
                switch (lhs, rhs) {
                case (.playing, .playing), (.paused, .paused), (.stopped, .stopped), (.idle, .idle):
                    return true
                default:
                    return false
                }
            }
            .sink { [weak self] state in
                guard let self, let facade = self.facade else { return }
                let monitor = self.monitor
                Task { @MainActor in
                    guard facade.isRuntimeMonitoringEnabled else {
                        await monitor.stopMonitoring()
                        return
                    }

                    switch state {
                    case .playing:
                        // Active playback needs monitoring
                        await monitor.startMonitoring(updateInterval: 2.0)
                    case .paused:
                        // Paused - reduce monitoring frequency
                        await monitor.updateMonitoringInterval(5.0)
                    case .stopped, .idle:
                        // Stopped/idle - minimal monitoring
                        await monitor.stopMonitoring()
                    default:
                        break
                    }
                }
            }
            .store(in: &cancellables)

        // Queue state changes are captured through AudioQueueManager's observation.
        // No additional Combine observation needed here.
    }

    // Queue state changes are observed via AudioQueueManager when needed.

    // MARK: - Session Interruptions

    /// Handle audio session interruptions
    public func handleSessionInterruption(_ interruption: AudioInterruptionType) async {
        switch interruption {
        case .began:
            shouldResumeAfterInterruption = stateManager.currentState.isPlaying
            guard shouldResumeAfterInterruption else {
                logger.info("Audio session interrupted while playback was not active")
                return
            }

            logger.info("Audio session interrupted - preserving play intent and pausing")
            if let facade {
                await facade.pause()
            }
        case let .ended(shouldResume):
            let resumeWasIntended = shouldResumeAfterInterruption
            shouldResumeAfterInterruption = false
            guard shouldResume, resumeWasIntended else {
                logger.info("Audio session interruption ended without automatic resume")
                return
            }

            logger.info("Audio session interruption ended - restoring prior play intent")
            if let facade {
                do {
                    try await facade.resume()
                } catch {
                    logger.error("Failed to resume after interruption: \(error.localizedDescription, privacy: .private)")
                    facade.reportPlaybackControlError(error)
                }
            }
        }
    }

    /// Handle audio route changes
    public func handleRouteChange(_ change: AudioRouteChange) async {
        logger.info(
            "Audio route changed: \(change.currentRoute, privacy: .private) (reason: \(change.reason, privacy: .public))"
        )

        // Handle specific route change scenarios
        switch change.reason {
        case .oldDeviceUnavailable:
            logger.info("Output device became unavailable")
            // On iOS 17+ an unplug also interrupts active Now Playing sessions
            // (prefersInterruptionOnRouteDisconnect defaults to true), so the
            // interruption path may already have paused and armed the resume
            // intent before this route change arrives. Clear the intent even
            // when playback is no longer running; otherwise an interruption
            // .ended(shouldResume:) would resume onto the new route.
            shouldResumeAfterInterruption = false
            guard stateManager.currentState.isPlaying, let facade else { return }
            await facade.pause()
        case .newDeviceAvailable:
            // New device connected
            logger.info("New output device available")
            await facade?.renegotiatePreferredSampleRate()
        case .routeConfigurationChange:
            // The route may have retained the track while changing the
            // hardware clock. Re-assert the active source rate without
            // deactivating the session or changing transport state.
            await facade?.renegotiatePreferredSampleRate()
        default:
            break
        }
    }

    // MARK: - Remote Commands

    /// Handle remote control commands
    public func handleRemoteCommand(_ command: RemoteCommand) async {
        guard let facade else { return }

        switch command {
        case .play:
            do {
                try await facade.resume()
            } catch {
                logger.error("Remote play command failed: \(error.localizedDescription, privacy: .private)")
                facade.reportPlaybackControlError(error)
            }
        case .pause:
            await facade.pause()
        case .togglePlayPause:
            if stateManager.currentState.isPlaying {
                await facade.pause()
            } else {
                do {
                    try await facade.resume()
                } catch {
                    logger.error("Remote toggle command failed: \(error.localizedDescription, privacy: .private)")
                    facade.reportPlaybackControlError(error)
                }
            }
        case .stop:
            await facade.stop()
        case .nextTrack:
            do {
                try await facade.playNext()
            } catch {
                logger.error("Remote next-track command failed: \(error.localizedDescription, privacy: .private)")
                facade.reportPlaybackControlError(error)
            }
        case .previousTrack:
            do {
                try await facade.playPrevious()
            } catch {
                logger.error("Remote previous-track command failed: \(error.localizedDescription, privacy: .private)")
                facade.reportPlaybackControlError(error)
            }
        case let .seek(time):
            do {
                try await facade.seek(to: time)
            } catch {
                logger.error("Remote seek command failed: \(error.localizedDescription, privacy: .private)")
                facade.reportPlaybackControlError(error)
            }
        default:
            logger.debug("Unhandled remote command: \(command, privacy: .private)")
        }
    }
}

extension AudioEngineFacade: AudioStateCoordinatorOwner {
    var stateCoordinatorMonitor: any AudioPerformanceMonitoring {
        monitor
    }

    func renegotiatePreferredSampleRate() async {
        await renegotiatePreferredSampleRateForRoute()
    }
}
