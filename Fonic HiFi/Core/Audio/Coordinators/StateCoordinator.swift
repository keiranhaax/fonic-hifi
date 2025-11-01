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

/// Handles state synchronization and notifications across the audio system
@MainActor
public final class StateCoordinator {
    // MARK: - Dependencies

    private let stateManager: PlaybackStateManager
    private let queueManager: AudioQueueManager
    private let sessionManager: AudioSessionManager
    private let uiStateStore: AudioUIState
    private weak var facade: AudioEngineFacade?

    // MARK: - State Publishing

    private var cancellables = Set<AnyCancellable>()
    private let logger = Log.logger(.audioStateCoordinator)

    // MARK: - Initialization

    init(
        stateManager: PlaybackStateManager,
        queueManager: AudioQueueManager,
        sessionManager: AudioSessionManager,
        uiStateStore: AudioUIState,
        facade: AudioEngineFacade,
    ) {
        self.stateManager = stateManager
        self.queueManager = queueManager
        self.sessionManager = sessionManager
        self.uiStateStore = uiStateStore
        self.facade = facade

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

    /// Update the current track and show mini player
    public func setCurrentTrack(_ track: Track?) {
        uiStateStore.currentTrack = track
        uiStateStore.showMiniPlayer = true
    }

    /// Handle playback state changes and update UI accordingly
    public func handlePlaybackStateChange(_ change: PlaybackStateChange) {
        // Always keep mini player visible (Apple Music style)
        // Don't hide it based on state - it shows placeholder when idle
        uiStateStore.showMiniPlayer = true

        // Log state transitions for debugging
        logger.debug("State transition: \(change.from) → \(change.nextState)")

        // Notify observers of state changes (handled automatically by @Observable)
    }

    // MARK: - Service Integration

    /// Setup service integrations and delegates
    private func setupServiceIntegrations() {
        logger.debug("Setting up service integrations...")

        // Session delegate for interruption handling
        sessionManager.delegate = facade

        logger.debug("Service integrations complete")
    }

    /// Setup observation of playback state changes for UI updates
    private func setupStateObservation() {
        stateManager.statePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] change in
                // Update derived UI state when playback state changes
                self?.handlePlaybackStateChange(change)
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
            logger.info("Audio session interrupted - pausing playback")
            // Delegate to playback coordinator through facade
            if let facade {
                await facade.pause()
            }
        case let .ended(shouldResume):
            if shouldResume {
                logger.info("Audio session interruption ended - resuming playback")
                // Delegate to playback coordinator through facade
                if let facade {
                    try? await facade.resume()
                }
            }
        }
    }

    /// Handle audio route changes
    public func handleRouteChange(_ change: AudioRouteChange) {
        logger.info("Audio route changed: \(change.currentRoute) (reason: \(change.reason))")

        // Handle specific route change scenarios
        switch change.reason {
        case .oldDeviceUnavailable:
            // Headphones were unplugged, might want to pause
            logger.info("Output device became unavailable")
        case .newDeviceAvailable:
            // New device connected
            logger.info("New output device available")
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
            try? await facade.resume()
        case .pause:
            await facade.pause()
        case .stop:
            await facade.stop()
        case .nextTrack:
            try? await facade.playNext()
        case .previousTrack:
            try? await facade.playPrevious()
        case let .seek(time):
            try? await facade.seek(to: time)
        default:
            logger.debug("Unhandled remote command: \(command)")
        }
    }
}
