//
//  PlaybackStateStore.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/2025.
//

import Combine
import Foundation

/// Dependency injection container and configuration for playback state management
@MainActor
public final class PlaybackStateStore {
    // MARK: - Singleton Access

    public static let shared = PlaybackStateStore()

    // MARK: - State Manager

    public let stateManager: PlaybackStateManager

    // MARK: - Configuration

    public private(set) var configuration: PlaybackStateConfiguration

    // MARK: - Publishers

    /// Combined publisher for all state-related events
    public let eventPublisher: AnyPublisher<PlaybackStateEvent, Never>

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init(
        configuration: PlaybackStateConfiguration = .default,
        initialState: PlaybackState = .idle,
    ) {
        self.configuration = configuration
        stateManager = PlaybackStateManager(
            initialState: initialState,
            enableTransitionValidation: configuration.enableTransitionValidation,
            enableLogging: configuration.enableLogging,
        )

        // Combine all publishers into a single event stream
        let stateEvents = stateManager.statePublisher
            .map { PlaybackStateEvent.stateChanged($0) }
            .eraseToAnyPublisher()

        let transitionEvents = stateManager.transitionPublisher
            .map { PlaybackStateEvent.transitionOccurred($0) }
            .eraseToAnyPublisher()

        eventPublisher = Publishers.Merge(stateEvents, transitionEvents)
            .eraseToAnyPublisher()
    }

    // MARK: - Configuration Management

    /// Update the store configuration
    public func updateConfiguration(_ newConfiguration: PlaybackStateConfiguration) {
        configuration = newConfiguration

        // Apply configuration to state manager
        stateManager.loggingEnabled = newConfiguration.enableLogging

        // Note: Transition validation can't be changed after initialization
        // as it would require recreating the state manager
    }

    // MARK: - Factory Methods

    /// Create a new state manager with custom configuration
    public static func createStateManager(
        with configuration: PlaybackStateConfiguration,
        initialState: PlaybackState = .idle,
    ) -> PlaybackStateManager {
        PlaybackStateManager(
            initialState: initialState,
            enableTransitionValidation: configuration.enableTransitionValidation,
            enableLogging: configuration.enableLogging,
        )
    }

    /// Create a new store instance with custom configuration
    public static func createStore(
        with configuration: PlaybackStateConfiguration,
        initialState: PlaybackState = .idle,
    ) -> PlaybackStateStore {
        PlaybackStateStore(
            configuration: configuration,
            initialState: initialState,
        )
    }
}

// MARK: - Configuration

/// Configuration options for playback state management
public struct PlaybackStateConfiguration: Sendable {
    /// Whether to validate state transitions
    public let enableTransitionValidation: Bool

    /// Whether to enable debug logging
    public let enableLogging: Bool

    /// Maximum number of history entries to maintain
    public let maxHistorySize: Int

    /// Whether to emit events for time updates
    public let emitTimeUpdateEvents: Bool

    /// Minimum time interval between time update events (to prevent spam)
    public let timeUpdateThrottle: TimeInterval

    public init(
        enableTransitionValidation: Bool = true,
        enableLogging: Bool = false,
        maxHistorySize: Int = 100,
        emitTimeUpdateEvents: Bool = false,
        timeUpdateThrottle: TimeInterval = 0.1,
    ) {
        self.enableTransitionValidation = enableTransitionValidation
        self.enableLogging = enableLogging
        self.maxHistorySize = maxHistorySize
        self.emitTimeUpdateEvents = emitTimeUpdateEvents
        self.timeUpdateThrottle = timeUpdateThrottle
    }

    /// Default configuration for production use
    public static let `default` = PlaybackStateConfiguration()

    /// Configuration optimized for development and debugging
    public static let debug = PlaybackStateConfiguration(
        enableTransitionValidation: true,
        enableLogging: true,
        emitTimeUpdateEvents: true,
        timeUpdateThrottle: 0.5,
    )

    /// Configuration for testing environments
    public static let testing = PlaybackStateConfiguration(
        enableTransitionValidation: false,
        enableLogging: false,
        maxHistorySize: 10,
        emitTimeUpdateEvents: false,
    )

    /// High-performance configuration with minimal overhead
    public static let performance = PlaybackStateConfiguration(
        enableTransitionValidation: false,
        enableLogging: false,
        maxHistorySize: 10,
        emitTimeUpdateEvents: false,
        timeUpdateThrottle: 1.0,
    )
}

// MARK: - Event Types

/// Unified event type for all playback state-related events
public enum PlaybackStateEvent: Sendable {
    case stateChanged(PlaybackStateChange)
    case transitionOccurred(PlaybackStateTransition)

    /// Extract the timestamp from any event type
    public var timestamp: Date {
        switch self {
        case let .stateChanged(change):
            change.timestamp
        case let .transitionOccurred(transition):
            transition.timestamp
        }
    }

    /// Extract the current state from any event type
    public var currentState: PlaybackState {
        switch self {
        case let .stateChanged(change):
            change.nextState
        case let .transitionOccurred(transition):
            transition.nextState
        }
    }

    /// Extract the previous state from any event type
    public var previousState: PlaybackState {
        switch self {
        case let .stateChanged(change):
            change.from
        case let .transitionOccurred(transition):
            transition.from
        }
    }
}

// MARK: - Convenience Extensions

public extension PlaybackStateStore {
    /// Quick access to current state
    var currentState: PlaybackState {
        stateManager.currentState
    }

    /// Quick access to previous state
    var previousState: PlaybackState {
        stateManager.previousState
    }

    /// Quick access to state history
    var history: [PlaybackStateHistoryEntry] {
        stateManager.history
    }

    /// Subscribe to state changes with a closure
    func onStateChange(_ handler: @escaping (PlaybackStateChange) -> Void) -> AnyCancellable {
        stateManager.statePublisher
            .sink(receiveValue: handler)
    }

    /// Subscribe to state transitions with a closure
    func onTransition(_ handler: @escaping (PlaybackStateTransition) -> Void) -> AnyCancellable {
        stateManager.transitionPublisher
            .sink(receiveValue: handler)
    }

    /// Subscribe to all events with a closure
    func onEvent(_ handler: @escaping (PlaybackStateEvent) -> Void) -> AnyCancellable {
        eventPublisher
            .sink(receiveValue: handler)
    }
}

// MARK: - Testing Support

#if DEBUG
    public extension PlaybackStateStore {
        /// Reset to initial state (for testing)
        func reset() {
            stateManager.forceUpdateState(.idle)
            stateManager.clearHistory()
        }

        /// Inject a specific state for testing
        func injectState(_ state: PlaybackState) {
            stateManager.forceUpdateState(state)
        }

        /// Get internal state for testing
        var testingState: (current: PlaybackState, previous: PlaybackState, historyCount: Int) {
            (
                current: stateManager.currentState,
                previous: stateManager.previousState,
                historyCount: stateManager.history.count,
            )
        }
    }
#endif
