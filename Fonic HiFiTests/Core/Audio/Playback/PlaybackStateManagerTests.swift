//
//  PlaybackStateManagerTests.swift
//  Fonic HiFiTests
//
//  Created by Claude on 5/27/2025.
//

import XCTest
import Combine
@testable import Fonic_HiFi

@MainActor
final class PlaybackStateManagerTests: XCTestCase {
    
    private var stateManager: PlaybackStateManager!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        stateManager = PlaybackStateManager(enableLogging: false)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() async throws {
        cancellables.removeAll()
        stateManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertEqual(stateManager.currentState, .idle)
        XCTAssertEqual(stateManager.previousState, .idle)
        XCTAssertEqual(stateManager.history.count, 1)
    }
    
    func testCustomInitialState() {
        let customManager = PlaybackStateManager(initialState: .stopped)
        XCTAssertEqual(customManager.currentState, .stopped)
        XCTAssertEqual(customManager.previousState, .stopped)
    }
    
    // MARK: - State Transition Tests
    
    func testValidTransitions() {
        // idle -> loading
        XCTAssertTrue(stateManager.updateState(.loading()))
        XCTAssertEqual(stateManager.currentState, .loading())
        XCTAssertEqual(stateManager.previousState, .idle)
        
        // loading -> playing
        XCTAssertTrue(stateManager.updateState(.playing(currentTime: 0, duration: 120)))
        XCTAssertEqual(stateManager.currentState, .playing(currentTime: 0, duration: 120))
        XCTAssertEqual(stateManager.previousState, .loading())
        
        // playing -> paused
        XCTAssertTrue(stateManager.updateState(.paused(currentTime: 30, duration: 120)))
        XCTAssertEqual(stateManager.currentState, .paused(currentTime: 30, duration: 120))
        
        // paused -> playing
        XCTAssertTrue(stateManager.updateState(.playing(currentTime: 30, duration: 120)))
        XCTAssertEqual(stateManager.currentState, .playing(currentTime: 30, duration: 120))
        
        // playing -> stopped
        XCTAssertTrue(stateManager.updateState(.stopped))
        XCTAssertEqual(stateManager.currentState, .stopped)
    }
    
    func testInvalidTransitions() {
        // idle -> playing (should be invalid without loading first)
        XCTAssertFalse(stateManager.updateState(.playing(currentTime: 0, duration: 120)))
        XCTAssertEqual(stateManager.currentState, .idle) // Should remain unchanged
        
        // stopped -> playing (should be invalid without loading first)
        stateManager.forceUpdateState(.stopped)
        XCTAssertFalse(stateManager.updateState(.playing(currentTime: 0, duration: 120)))
        XCTAssertEqual(stateManager.currentState, .stopped)
    }
    
    func testForceUpdateState() {
        // Force an invalid transition
        stateManager.forceUpdateState(.playing(currentTime: 30, duration: 120))
        XCTAssertEqual(stateManager.currentState, .playing(currentTime: 30, duration: 120))
        XCTAssertEqual(stateManager.previousState, .idle)
    }
    
    // MARK: - Time Update Tests
    
    func testTimeUpdateInPlayingState() {
        stateManager.forceUpdateState(.playing(currentTime: 0, duration: 120))
        
        stateManager.updateTime(30)
        XCTAssertEqual(stateManager.currentState, .playing(currentTime: 30, duration: 120))
        
        stateManager.updateTime(45, duration: 150)
        XCTAssertEqual(stateManager.currentState, .playing(currentTime: 45, duration: 150))
    }
    
    func testTimeUpdateInPausedState() {
        stateManager.forceUpdateState(.paused(currentTime: 30, duration: 120))
        
        stateManager.updateTime(45)
        XCTAssertEqual(stateManager.currentState, .paused(currentTime: 45, duration: 120))
    }
    
    func testTimeUpdateInNonTimeState() {
        stateManager.updateTime(30) // Should not change idle state
        XCTAssertEqual(stateManager.currentState, .idle)
    }
    
    // MARK: - Progress Update Tests
    
    func testProgressUpdateInLoadingState() {
        stateManager.forceUpdateState(.loading())
        
        stateManager.updateProgress(0.5)
        XCTAssertEqual(stateManager.currentState, .loading(progress: 0.5))
        
        stateManager.updateProgress(1.0)
        XCTAssertEqual(stateManager.currentState, .loading(progress: 1.0))
    }
    
    func testProgressUpdateInBufferingState() {
        stateManager.forceUpdateState(.buffering(progress: 0.2, currentTime: 30))
        
        stateManager.updateProgress(0.8)
        XCTAssertEqual(stateManager.currentState, .buffering(progress: 0.8, currentTime: 30))
    }
    
    func testProgressUpdateInNonProgressState() {
        stateManager.updateProgress(0.5) // Should not change idle state
        XCTAssertEqual(stateManager.currentState, .idle)
    }
    
    // MARK: - State Query Tests
    
    func testIsInState() {
        stateManager.forceUpdateState(.playing(currentTime: 30, duration: 120))
        
        XCTAssertTrue(stateManager.isInState(.playing))
        XCTAssertFalse(stateManager.isInState(.paused))
        XCTAssertFalse(stateManager.isInState(.idle, .stopped))
    }
    
    func testCanControlPlayback() {
        // Can control in playing state
        stateManager.forceUpdateState(.playing(currentTime: 30, duration: 120))
        XCTAssertTrue(stateManager.canControlPlayback)
        
        // Can control in paused state
        stateManager.forceUpdateState(.paused(currentTime: 30, duration: 120))
        XCTAssertTrue(stateManager.canControlPlayback)
        
        // Cannot control in idle state
        stateManager.forceUpdateState(.idle)
        XCTAssertFalse(stateManager.canControlPlayback)
    }
    
    func testCanSeek() {
        // Can seek in playing state
        stateManager.forceUpdateState(.playing(currentTime: 30, duration: 120))
        XCTAssertTrue(stateManager.canSeek)
        
        // Can seek in paused state
        stateManager.forceUpdateState(.paused(currentTime: 30, duration: 120))
        XCTAssertTrue(stateManager.canSeek)
        
        // Cannot seek in loading state
        stateManager.forceUpdateState(.loading())
        XCTAssertFalse(stateManager.canSeek)
    }
    
    // MARK: - History Tests
    
    func testHistoryTracking() {
        XCTAssertEqual(stateManager.history.count, 1) // Initial state
        
        stateManager.updateState(.loading())
        XCTAssertEqual(stateManager.history.count, 2)
        
        stateManager.forceUpdateState(.playing(currentTime: 0, duration: 120))
        XCTAssertEqual(stateManager.history.count, 3)
        
        let recentHistory = stateManager.recentHistory(count: 2)
        XCTAssertEqual(recentHistory.count, 2)
        XCTAssertEqual(recentHistory.last?.state, .playing(currentTime: 0, duration: 120))
    }
    
    func testClearHistory() {
        stateManager.updateState(.loading())
        stateManager.forceUpdateState(.playing(currentTime: 0, duration: 120))
        XCTAssertEqual(stateManager.history.count, 3)
        
        stateManager.clearHistory()
        XCTAssertEqual(stateManager.history.count, 1) // Current state remains
        XCTAssertEqual(stateManager.history.first?.state, .playing(currentTime: 0, duration: 120))
    }
    
    // MARK: - Publisher Tests
    
    func testStatePublisher() {
        let expectation = XCTestExpectation(description: "State change published")
        var receivedChange: PlaybackStateChange?
        
        stateManager.statePublisher
            .sink { change in
                receivedChange = change
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        stateManager.updateState(.loading())
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedChange)
        XCTAssertEqual(receivedChange?.from, .idle)
        XCTAssertEqual(receivedChange?.to, .loading())
    }
    
    func testTransitionPublisher() {
        let expectation = XCTestExpectation(description: "Transition published")
        var receivedTransition: PlaybackStateTransition?
        
        stateManager.transitionPublisher
            .sink { transition in
                receivedTransition = transition
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        stateManager.updateState(.loading())
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedTransition)
        XCTAssertEqual(receivedTransition?.from, .idle)
        XCTAssertEqual(receivedTransition?.to, .loading())
        XCTAssertTrue(receivedTransition?.isValid == true)
    }
    
    // MARK: - Convenience Method Tests
    
    func testConvenienceTransitions() {
        stateManager.transitionToLoading(progress: 0.5)
        XCTAssertEqual(stateManager.currentState, .loading(progress: 0.5))
        
        stateManager.transitionToPlaying(currentTime: 30, duration: 120)
        XCTAssertEqual(stateManager.currentState, .playing(currentTime: 30, duration: 120))
        
        stateManager.transitionToPaused(currentTime: 45, duration: 120)
        XCTAssertEqual(stateManager.currentState, .paused(currentTime: 45, duration: 120))
        
        stateManager.transitionToStopped()
        XCTAssertEqual(stateManager.currentState, .stopped)
        
        stateManager.transitionToIdle()
        XCTAssertEqual(stateManager.currentState, .idle)
    }
    
    func testErrorTransition() {
        let error = AudioError.engineInitializationFailed
        stateManager.transitionToError(error, lastKnownTime: 30)
        
        if case .error(let receivedError, let time) = stateManager.currentState {
            XCTAssertEqual(receivedError, error)
            XCTAssertEqual(time, 30)
        } else {
            XCTFail("Expected error state")
        }
    }
    
    // MARK: - Engine Integration Tests
    
    func testHandleEngineStateChange() {
        // Test playing state
        stateManager.handleEngineStateChange(
            isPlaying: true,
            currentTime: 30,
            duration: 120
        )
        XCTAssertEqual(stateManager.currentState, .playing(currentTime: 30, duration: 120))
        
        // Test paused state with time
        stateManager.handleEngineStateChange(
            isPlaying: false,
            currentTime: 45,
            duration: 120
        )
        XCTAssertEqual(stateManager.currentState, .paused(currentTime: 45, duration: 120))
        
        // Test stopped state (no time)
        stateManager.handleEngineStateChange(
            isPlaying: false,
            currentTime: 0,
            duration: 120
        )
        XCTAssertEqual(stateManager.currentState, .stopped)
        
        // Test buffering state
        stateManager.handleEngineStateChange(
            isPlaying: false,
            currentTime: 30,
            duration: 120,
            isBuffering: true,
            bufferProgress: 0.7
        )
        XCTAssertEqual(stateManager.currentState, .buffering(progress: 0.7, currentTime: 30))
    }
    
    func testHandleEngineError() {
        let error = AudioError.fileNotFound
        
        stateManager.handleEngineError(error, currentTime: 45)
        
        if case .error(let receivedError, let time) = stateManager.currentState {
            XCTAssertEqual(receivedError, error)
            XCTAssertEqual(time, 45)
        } else {
            XCTFail("Expected error state")
        }
    }
    
    // MARK: - Current State Duration Tests
    
    func testCurrentStateDuration() async {
        let initialTime = stateManager.currentStateDuration
        XCTAssertGreaterThanOrEqual(initialTime, 0)
        
        // Wait a bit and check duration increased
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        let laterTime = stateManager.currentStateDuration
        XCTAssertGreaterThan(laterTime, initialTime)
    }
}