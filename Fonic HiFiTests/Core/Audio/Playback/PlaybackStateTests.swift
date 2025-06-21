//
//  PlaybackStateTests.swift
//  Fonic HiFiTests
//
//  Created by Claude on 5/27/2025.
//

import XCTest
@testable import Fonic_HiFi

final class PlaybackStateTests: XCTestCase {
    
    // MARK: - State Property Tests
    
    func testIsPlayingProperty() {
        XCTAssertTrue(PlaybackState.playing(currentTime: 30, duration: 120).isPlaying)
        XCTAssertFalse(PlaybackState.paused(currentTime: 30, duration: 120).isPlaying)
        XCTAssertFalse(PlaybackState.idle.isPlaying)
        XCTAssertFalse(PlaybackState.stopped.isPlaying)
        XCTAssertFalse(PlaybackState.loading().isPlaying)
    }
    
    func testIsPausedProperty() {
        XCTAssertTrue(PlaybackState.paused(currentTime: 30, duration: 120).isPaused)
        XCTAssertFalse(PlaybackState.playing(currentTime: 30, duration: 120).isPaused)
        XCTAssertFalse(PlaybackState.idle.isPaused)
        XCTAssertFalse(PlaybackState.stopped.isPaused)
    }
    
    func testIsIdleProperty() {
        XCTAssertTrue(PlaybackState.idle.isIdle)
        XCTAssertTrue(PlaybackState.stopped.isIdle)
        XCTAssertFalse(PlaybackState.playing(currentTime: 30, duration: 120).isIdle)
        XCTAssertFalse(PlaybackState.loading().isIdle)
    }
    
    func testIsActiveProperty() {
        XCTAssertTrue(PlaybackState.playing(currentTime: 30, duration: 120).isActive)
        XCTAssertTrue(PlaybackState.paused(currentTime: 30, duration: 120).isActive)
        XCTAssertTrue(PlaybackState.loading().isActive)
        XCTAssertTrue(PlaybackState.buffering(progress: 0.5, currentTime: 30).isActive)
        XCTAssertTrue(PlaybackState.seeking(targetTime: 60, currentTime: 30).isActive)
        
        XCTAssertFalse(PlaybackState.idle.isActive)
        XCTAssertFalse(PlaybackState.stopped.isActive)
        XCTAssertFalse(PlaybackState.error(AudioError.fileNotFound(URL(fileURLWithPath: "/test")), lastKnownTime: nil).isActive)
    }
    
    // MARK: - Time and Duration Tests
    
    func testCurrentTimeProperty() {
        XCTAssertEqual(PlaybackState.playing(currentTime: 30, duration: 120).currentTime, 30)
        XCTAssertEqual(PlaybackState.paused(currentTime: 45, duration: 120).currentTime, 45)
        XCTAssertEqual(PlaybackState.buffering(progress: 0.5, currentTime: 60).currentTime, 60)
        XCTAssertEqual(PlaybackState.seeking(targetTime: 90, currentTime: 30).currentTime, 30)
        XCTAssertEqual(PlaybackState.error(AudioError.fileNotFound(URL(fileURLWithPath: "/test")), lastKnownTime: 15).currentTime, 15)
        
        XCTAssertNil(PlaybackState.idle.currentTime)
        XCTAssertNil(PlaybackState.stopped.currentTime)
        XCTAssertNil(PlaybackState.loading().currentTime)
        XCTAssertNil(PlaybackState.error(AudioError.fileNotFound(URL(fileURLWithPath: "/test")), lastKnownTime: nil).currentTime)
    }
    
    func testDurationProperty() {
        XCTAssertEqual(PlaybackState.playing(currentTime: 30, duration: 120).duration, 120)
        XCTAssertEqual(PlaybackState.paused(currentTime: 45, duration: 180).duration, 180)
        
        XCTAssertNil(PlaybackState.idle.duration)
        XCTAssertNil(PlaybackState.stopped.duration)
        XCTAssertNil(PlaybackState.loading().duration)
        XCTAssertNil(PlaybackState.buffering(progress: 0.5, currentTime: 30).duration)
    }
    
    func testProgressProperty() {
        // Loading progress
        XCTAssertEqual(PlaybackState.loading(progress: 0.75).progress, 0.75)
        
        // Buffering progress
        XCTAssertEqual(PlaybackState.buffering(progress: 0.4, currentTime: 30).progress, 0.4)
        
        // Playback progress (time-based)
        XCTAssertEqual(PlaybackState.playing(currentTime: 30, duration: 120).progress, 0.25)
        XCTAssertEqual(PlaybackState.paused(currentTime: 60, duration: 120).progress, 0.5)
        
        // Edge case: zero duration
        XCTAssertEqual(PlaybackState.playing(currentTime: 30, duration: 0).progress, 0.0)
        
        XCTAssertNil(PlaybackState.idle.progress)
        XCTAssertNil(PlaybackState.stopped.progress)
    }
    
    // MARK: - Capability Tests
    
    func testCanSeek() {
        XCTAssertTrue(PlaybackState.playing(currentTime: 30, duration: 120).canSeek)
        XCTAssertTrue(PlaybackState.paused(currentTime: 30, duration: 120).canSeek)
        
        XCTAssertFalse(PlaybackState.idle.canSeek)
        XCTAssertFalse(PlaybackState.stopped.canSeek)
        XCTAssertFalse(PlaybackState.loading().canSeek)
        XCTAssertFalse(PlaybackState.buffering(progress: 0.5, currentTime: 30).canSeek)
        XCTAssertFalse(PlaybackState.seeking(targetTime: 60, currentTime: 30).canSeek)
    }
    
    func testCanTogglePlayback() {
        XCTAssertTrue(PlaybackState.playing(currentTime: 30, duration: 120).canTogglePlayback)
        XCTAssertTrue(PlaybackState.paused(currentTime: 30, duration: 120).canTogglePlayback)
        
        XCTAssertFalse(PlaybackState.idle.canTogglePlayback)
        XCTAssertFalse(PlaybackState.stopped.canTogglePlayback)
        XCTAssertFalse(PlaybackState.loading().canTogglePlayback)
        XCTAssertFalse(PlaybackState.buffering(progress: 0.5, currentTime: 30).canTogglePlayback)
    }
    
    // MARK: - State Update Tests
    
    func testWithUpdatedTime() {
        let playingState = PlaybackState.playing(currentTime: 30, duration: 120)
        let updatedPlaying = playingState.withUpdatedTime(45)
        XCTAssertEqual(updatedPlaying, .playing(currentTime: 45, duration: 120))
        
        let pausedState = PlaybackState.paused(currentTime: 30, duration: 120)
        let updatedPaused = pausedState.withUpdatedTime(60)
        XCTAssertEqual(updatedPaused, .paused(currentTime: 60, duration: 120))
        
        let bufferingState = PlaybackState.buffering(progress: 0.5, currentTime: 30)
        let updatedBuffering = bufferingState.withUpdatedTime(45)
        XCTAssertEqual(updatedBuffering, .buffering(progress: 0.5, currentTime: 45))
        
        // State that doesn't support time updates should remain unchanged
        let idleState = PlaybackState.idle
        XCTAssertEqual(idleState.withUpdatedTime(30), .idle)
    }
    
    func testWithUpdatedDuration() {
        let playingState = PlaybackState.playing(currentTime: 30, duration: 120)
        let updatedPlaying = playingState.withUpdatedDuration(180)
        XCTAssertEqual(updatedPlaying, .playing(currentTime: 30, duration: 180))
        
        let pausedState = PlaybackState.paused(currentTime: 30, duration: 120)
        let updatedPaused = pausedState.withUpdatedDuration(240)
        XCTAssertEqual(updatedPaused, .paused(currentTime: 30, duration: 240))
        
        // State that doesn't support duration should remain unchanged
        let loadingState = PlaybackState.loading()
        XCTAssertEqual(loadingState.withUpdatedDuration(120), .loading())
    }
    
    func testWithUpdatedProgress() {
        let loadingState = PlaybackState.loading(progress: 0.3)
        let updatedLoading = loadingState.withUpdatedProgress(0.8)
        XCTAssertEqual(updatedLoading, .loading(progress: 0.8))
        
        let bufferingState = PlaybackState.buffering(progress: 0.2, currentTime: 30)
        let updatedBuffering = bufferingState.withUpdatedProgress(0.9)
        XCTAssertEqual(updatedBuffering, .buffering(progress: 0.9, currentTime: 30))
        
        // State that doesn't support progress should remain unchanged
        let playingState = PlaybackState.playing(currentTime: 30, duration: 120)
        XCTAssertEqual(playingState.withUpdatedProgress(0.5), playingState)
    }
    
    // MARK: - Transition Validation Tests
    
    func testValidTransitions() {
        // From idle
        XCTAssertTrue(PlaybackState.idle.canTransition(to: .loading()))
        XCTAssertTrue(PlaybackState.idle.canTransition(to: .error(AudioError.fileNotFound(URL(fileURLWithPath: "/test")), lastKnownTime: nil)))
        
        // From loading
        XCTAssertTrue(PlaybackState.loading().canTransition(to: .playing(currentTime: 0, duration: 120)))
        XCTAssertTrue(PlaybackState.loading().canTransition(to: .paused(currentTime: 0, duration: 120)))
        XCTAssertTrue(PlaybackState.loading().canTransition(to: .stopped))
        XCTAssertTrue(PlaybackState.loading().canTransition(to: .error(AudioError.fileNotFound(URL(fileURLWithPath: "/test")), lastKnownTime: nil)))
        
        // From playing
        XCTAssertTrue(PlaybackState.playing(currentTime: 30, duration: 120).canTransition(to: .paused(currentTime: 30, duration: 120)))
        XCTAssertTrue(PlaybackState.playing(currentTime: 30, duration: 120).canTransition(to: .stopped))
        XCTAssertTrue(PlaybackState.playing(currentTime: 30, duration: 120).canTransition(to: .buffering(progress: 0.5, currentTime: 30)))
        XCTAssertTrue(PlaybackState.playing(currentTime: 30, duration: 120).canTransition(to: .seeking(targetTime: 60, currentTime: 30)))
        
        // From paused
        XCTAssertTrue(PlaybackState.paused(currentTime: 30, duration: 120).canTransition(to: .playing(currentTime: 30, duration: 120)))
        XCTAssertTrue(PlaybackState.paused(currentTime: 30, duration: 120).canTransition(to: .stopped))
        XCTAssertTrue(PlaybackState.paused(currentTime: 30, duration: 120).canTransition(to: .seeking(targetTime: 60, currentTime: 30)))
        
        // From stopped
        XCTAssertTrue(PlaybackState.stopped.canTransition(to: .idle))
        XCTAssertTrue(PlaybackState.stopped.canTransition(to: .loading()))
        
        // Same state updates
        XCTAssertTrue(PlaybackState.loading().canTransition(to: .loading(progress: 0.5)))
        XCTAssertTrue(PlaybackState.playing(currentTime: 30, duration: 120).canTransition(to: .playing(currentTime: 45, duration: 120)))
    }
    
    func testInvalidTransitions() {
        // Cannot go from idle directly to playing
        XCTAssertFalse(PlaybackState.idle.canTransition(to: .playing(currentTime: 0, duration: 120)))
        
        // Cannot go from idle directly to paused
        XCTAssertFalse(PlaybackState.idle.canTransition(to: .paused(currentTime: 0, duration: 120)))
        
        // Cannot go from playing directly to loading
        XCTAssertFalse(PlaybackState.playing(currentTime: 30, duration: 120).canTransition(to: .loading()))
        
        // Cannot go from paused directly to loading
        XCTAssertFalse(PlaybackState.paused(currentTime: 30, duration: 120).canTransition(to: .loading()))
        
        // Cannot go from buffering to idle
        XCTAssertFalse(PlaybackState.buffering(progress: 0.5, currentTime: 30).canTransition(to: .idle))
    }
    
    // MARK: - Next State Tests
    
    func testNextPlayState() {
        // From paused
        let pausedState = PlaybackState.paused(currentTime: 30, duration: 120)
        XCTAssertEqual(pausedState.nextPlayState, .playing(currentTime: 30, duration: 120))
        
        // From stopped
        let stoppedState = PlaybackState.stopped
        XCTAssertEqual(stoppedState.nextPlayState, .loading())
        
        // From idle
        let idleState = PlaybackState.idle
        XCTAssertEqual(idleState.nextPlayState, .loading())
        
        // From playing (should return nil)
        let playingState = PlaybackState.playing(currentTime: 30, duration: 120)
        XCTAssertNil(playingState.nextPlayState)
    }
    
    func testNextPauseState() {
        // From playing
        let playingState = PlaybackState.playing(currentTime: 30, duration: 120)
        XCTAssertEqual(playingState.nextPauseState, .paused(currentTime: 30, duration: 120))
        
        // From paused (should return nil)
        let pausedState = PlaybackState.paused(currentTime: 30, duration: 120)
        XCTAssertNil(pausedState.nextPauseState)
        
        // From idle (should return nil)
        let idleState = PlaybackState.idle
        XCTAssertNil(idleState.nextPauseState)
    }
    
    func testNextStopState() {
        // Any state should be able to transition to stopped
        XCTAssertEqual(PlaybackState.playing(currentTime: 30, duration: 120).nextStopState, .stopped)
        XCTAssertEqual(PlaybackState.paused(currentTime: 30, duration: 120).nextStopState, .stopped)
        XCTAssertEqual(PlaybackState.loading().nextStopState, .stopped)
        XCTAssertEqual(PlaybackState.idle.nextStopState, .stopped)
    }
    
    // MARK: - Description Tests
    
    func testDescription() {
        XCTAssertEqual(PlaybackState.idle.description, "Idle")
        XCTAssertEqual(PlaybackState.stopped.description, "Stopped")
        XCTAssertEqual(PlaybackState.loading(progress: 0.75).description, "Loading (75%)")
        XCTAssertEqual(PlaybackState.playing(currentTime: 75, duration: 180).description, "Playing 1:15/3:00")
        XCTAssertEqual(PlaybackState.paused(currentTime: 90, duration: 240).description, "Paused 1:30/4:00")
        XCTAssertEqual(PlaybackState.buffering(progress: 0.6, currentTime: 45).description, "Buffering (60%) at 0:45")
        XCTAssertEqual(PlaybackState.seeking(targetTime: 120, currentTime: 60).description, "Seeking from 1:00 to 2:00")
        
        let errorState = PlaybackState.error(AudioError.fileNotFound(URL(fileURLWithPath: "/test")), lastKnownTime: 30)
        XCTAssertTrue(errorState.description.contains("Error"))
        XCTAssertTrue(errorState.description.contains("0:30"))
    }
    
    // MARK: - Equatable Tests
    
    func testEquality() {
        // Same states should be equal
        XCTAssertEqual(PlaybackState.idle, PlaybackState.idle)
        XCTAssertEqual(PlaybackState.stopped, PlaybackState.stopped)
        XCTAssertEqual(
            PlaybackState.playing(currentTime: 30, duration: 120),
            PlaybackState.playing(currentTime: 30, duration: 120)
        )
        XCTAssertEqual(
            PlaybackState.loading(progress: 0.5),
            PlaybackState.loading(progress: 0.5)
        )
        
        // Different states should not be equal
        XCTAssertNotEqual(PlaybackState.idle, PlaybackState.stopped)
        XCTAssertNotEqual(
            PlaybackState.playing(currentTime: 30, duration: 120),
            PlaybackState.playing(currentTime: 45, duration: 120)
        )
        XCTAssertNotEqual(
            PlaybackState.loading(progress: 0.5),
            PlaybackState.loading(progress: 0.8)
        )
    }
}