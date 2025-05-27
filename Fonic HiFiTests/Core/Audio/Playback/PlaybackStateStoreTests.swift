//
//  PlaybackStateStoreTests.swift
//  Fonic HiFiTests
//
//  Created by Claude on 5/27/2025.
//

import XCTest
import Combine
@testable import Fonic_HiFi

@MainActor
final class PlaybackStateStoreTests: XCTestCase {
    
    private var store: PlaybackStateStore!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        store = PlaybackStateStore.createStore(with: .testing)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() async throws {
        cancellables.removeAll()
        store = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testDefaultInitialization() {
        let defaultStore = PlaybackStateStore()
        XCTAssertEqual(defaultStore.currentState, .idle)
        XCTAssertTrue(defaultStore.configuration.enableTransitionValidation)
        XCTAssertFalse(defaultStore.configuration.enableLogging)
    }
    
    func testCustomConfiguration() {
        let config = PlaybackStateConfiguration.debug
        let customStore = PlaybackStateStore.createStore(with: config, initialState: .stopped)
        
        XCTAssertEqual(customStore.currentState, .stopped)
        XCTAssertEqual(customStore.configuration.enableLogging, config.enableLogging)
        XCTAssertEqual(customStore.configuration.enableTransitionValidation, config.enableTransitionValidation)
    }
    
    func testSingletonAccess() {
        let singleton1 = PlaybackStateStore.shared
        let singleton2 = PlaybackStateStore.shared
        XCTAssertTrue(singleton1 === singleton2)
    }
    
    // MARK: - Configuration Tests
    
    func testConfigurationTypes() {
        // Default configuration
        let defaultConfig = PlaybackStateConfiguration.default
        XCTAssertTrue(defaultConfig.enableTransitionValidation)
        XCTAssertFalse(defaultConfig.enableLogging)
        XCTAssertEqual(defaultConfig.maxHistorySize, 100)
        XCTAssertFalse(defaultConfig.emitTimeUpdateEvents)
        
        // Debug configuration
        let debugConfig = PlaybackStateConfiguration.debug
        XCTAssertTrue(debugConfig.enableTransitionValidation)
        XCTAssertTrue(debugConfig.enableLogging)
        XCTAssertTrue(debugConfig.emitTimeUpdateEvents)
        
        // Testing configuration
        let testingConfig = PlaybackStateConfiguration.testing
        XCTAssertFalse(testingConfig.enableTransitionValidation)
        XCTAssertFalse(testingConfig.enableLogging)
        XCTAssertEqual(testingConfig.maxHistorySize, 10)
        
        // Performance configuration
        let perfConfig = PlaybackStateConfiguration.performance
        XCTAssertFalse(perfConfig.enableTransitionValidation)
        XCTAssertFalse(perfConfig.enableLogging)
        XCTAssertEqual(perfConfig.maxHistorySize, 10)
        XCTAssertEqual(perfConfig.timeUpdateThrottle, 1.0)
    }
    
    func testUpdateConfiguration() {
        let newConfig = PlaybackStateConfiguration(enableLogging: true)
        store.updateConfiguration(newConfig)
        
        XCTAssertEqual(store.configuration.enableLogging, true)
        XCTAssertEqual(store.stateManager.loggingEnabled, true)
    }
    
    // MARK: - State Access Tests
    
    func testQuickStateAccess() {
        store.stateManager.forceUpdateState(.playing(currentTime: 30, duration: 120))
        
        XCTAssertEqual(store.currentState, .playing(currentTime: 30, duration: 120))
        XCTAssertEqual(store.previousState, .idle)
        XCTAssertGreaterThan(store.history.count, 0)
    }
    
    // MARK: - Event Publisher Tests
    
    func testEventPublisher() {
        let expectation = XCTestExpectation(description: "Event received")
        var receivedEvent: PlaybackStateEvent?
        
        store.eventPublisher
            .sink { event in
                receivedEvent = event
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        store.stateManager.updateState(.loading())
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedEvent)
        
        switch receivedEvent {
        case .stateChanged(let change):
            XCTAssertEqual(change.from, .idle)
            XCTAssertEqual(change.to, .loading())
        case .transitionOccurred(let transition):
            XCTAssertEqual(transition.from, .idle)
            XCTAssertEqual(transition.to, .loading())
        case .none:
            XCTFail("No event received")
        }
    }
    
    func testMultipleEventTypes() {
        let stateChangeExpectation = XCTestExpectation(description: "State change event")
        let transitionExpectation = XCTestExpectation(description: "Transition event")
        
        var stateChangeReceived = false
        var transitionReceived = false
        
        store.eventPublisher
            .sink { event in
                switch event {
                case .stateChanged:
                    stateChangeReceived = true
                    stateChangeExpectation.fulfill()
                case .transitionOccurred:
                    transitionReceived = true
                    transitionExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        store.stateManager.updateState(.loading())
        
        wait(for: [stateChangeExpectation, transitionExpectation], timeout: 1.0)
        XCTAssertTrue(stateChangeReceived)
        XCTAssertTrue(transitionReceived)
    }
    
    // MARK: - Convenience Subscription Tests
    
    func testOnStateChange() {
        let expectation = XCTestExpectation(description: "State change callback")
        var receivedChange: PlaybackStateChange?
        
        let subscription = store.onStateChange { change in
            receivedChange = change
            expectation.fulfill()
        }
        
        store.stateManager.updateState(.loading())
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedChange)
        XCTAssertEqual(receivedChange?.from, .idle)
        XCTAssertEqual(receivedChange?.to, .loading())
        
        subscription.cancel()
    }
    
    func testOnTransition() {
        let expectation = XCTestExpectation(description: "Transition callback")
        var receivedTransition: PlaybackStateTransition?
        
        let subscription = store.onTransition { transition in
            receivedTransition = transition
            expectation.fulfill()
        }
        
        store.stateManager.updateState(.loading())
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedTransition)
        XCTAssertEqual(receivedTransition?.from, .idle)
        XCTAssertEqual(receivedTransition?.to, .loading())
        XCTAssertTrue(receivedTransition?.isValid == true)
        
        subscription.cancel()
    }
    
    func testOnEvent() {
        let expectation = XCTestExpectation(description: "Event callback")
        expectation.expectedFulfillmentCount = 2 // Both state change and transition events
        var eventCount = 0
        
        let subscription = store.onEvent { event in
            eventCount += 1
            expectation.fulfill()
        }
        
        store.stateManager.updateState(.loading())
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(eventCount, 2)
        
        subscription.cancel()
    }
    
    // MARK: - Factory Method Tests
    
    func testCreateStateManager() {
        let config = PlaybackStateConfiguration.debug
        let manager = PlaybackStateStore.createStateManager(
            with: config,
            initialState: .paused(currentTime: 30, duration: 120)
        )
        
        XCTAssertEqual(manager.currentState, .paused(currentTime: 30, duration: 120))
        XCTAssertEqual(manager.loggingEnabled, config.enableLogging)
    }
    
    func testCreateStore() {
        let config = PlaybackStateConfiguration.performance
        let customStore = PlaybackStateStore.createStore(
            with: config,
            initialState: .stopped
        )
        
        XCTAssertEqual(customStore.currentState, .stopped)
        XCTAssertEqual(customStore.configuration.enableLogging, config.enableLogging)
        XCTAssertEqual(customStore.configuration.enableTransitionValidation, config.enableTransitionValidation)
    }
    
    // MARK: - Event Type Tests
    
    func testPlaybackStateEventProperties() {
        let change = PlaybackStateChange(
            from: .idle,
            to: .playing(currentTime: 30, duration: 120),
            timestamp: Date()
        )
        let stateEvent = PlaybackStateEvent.stateChanged(change)
        
        XCTAssertEqual(stateEvent.currentState, .playing(currentTime: 30, duration: 120))
        XCTAssertEqual(stateEvent.previousState, .idle)
        XCTAssertEqual(stateEvent.timestamp, change.timestamp)
        
        let transition = PlaybackStateTransition(
            from: .paused(currentTime: 30, duration: 120),
            to: .playing(currentTime: 30, duration: 120),
            timestamp: Date(),
            isValid: true
        )
        let transitionEvent = PlaybackStateEvent.transitionOccurred(transition)
        
        XCTAssertEqual(transitionEvent.currentState, .playing(currentTime: 30, duration: 120))
        XCTAssertEqual(transitionEvent.previousState, .paused(currentTime: 30, duration: 120))
        XCTAssertEqual(transitionEvent.timestamp, transition.timestamp)
    }
    
    // MARK: - Testing Support Tests
    
    #if DEBUG
    func testResetFunctionality() {
        store.stateManager.forceUpdateState(.playing(currentTime: 30, duration: 120))
        XCTAssertEqual(store.currentState, .playing(currentTime: 30, duration: 120))
        
        store.reset()
        XCTAssertEqual(store.currentState, .idle)
        XCTAssertEqual(store.history.count, 1) // Only the reset state
    }
    
    func testInjectState() {
        let testState = PlaybackState.buffering(progress: 0.7, currentTime: 45)
        store.injectState(testState)
        XCTAssertEqual(store.currentState, testState)
    }
    
    func testTestingState() {
        store.stateManager.forceUpdateState(.playing(currentTime: 30, duration: 120))
        store.stateManager.forceUpdateState(.paused(currentTime: 45, duration: 120))
        
        let testingState = store.testingState
        XCTAssertEqual(testingState.current, .paused(currentTime: 45, duration: 120))
        XCTAssertEqual(testingState.previous, .playing(currentTime: 30, duration: 120))
        XCTAssertGreaterThan(testingState.historyCount, 2)
    }
    #endif
    
    // MARK: - Integration Tests
    
    func testStoreStateManagerIntegration() {
        // Verify that store's state manager properly updates store's quick access properties
        XCTAssertEqual(store.currentState, store.stateManager.currentState)
        XCTAssertEqual(store.previousState, store.stateManager.previousState)
        XCTAssertEqual(store.history.count, store.stateManager.history.count)
        
        store.stateManager.updateState(.loading())
        
        XCTAssertEqual(store.currentState, store.stateManager.currentState)
        XCTAssertEqual(store.previousState, store.stateManager.previousState)
        XCTAssertEqual(store.history.count, store.stateManager.history.count)
    }
    
    func testConfigurationPersistence() {
        let originalConfig = store.configuration
        let newConfig = PlaybackStateConfiguration(
            enableLogging: !originalConfig.enableLogging,
            maxHistorySize: originalConfig.maxHistorySize + 50
        )
        
        store.updateConfiguration(newConfig)
        
        XCTAssertEqual(store.configuration.enableLogging, newConfig.enableLogging)
        XCTAssertEqual(store.configuration.maxHistorySize, newConfig.maxHistorySize)
        XCTAssertNotEqual(store.configuration.enableLogging, originalConfig.enableLogging)
    }
}