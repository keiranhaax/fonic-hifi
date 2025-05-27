//
//  AudioQueueManagerTests.swift
//  Fonic HiFiTests
//
//  Created by Claude on 5/27/25.
//

import XCTest
@testable import Fonic_HiFi

@MainActor
final class AudioQueueManagerTests: XCTestCase {
    
    var queueManager: AudioQueueManager!
    var mockDelegate: MockAudioQueueDelegate!
    
    override func setUp() {
        super.setUp()
        mockDelegate = MockAudioQueueDelegate()
        queueManager = AudioQueueManager(maxHistorySize: 10, delegate: mockDelegate)
    }
    
    override func tearDown() {
        queueManager = nil
        mockDelegate = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createMockTracks(count: Int, prefix: String = "Track") -> [Track] {
        return (1...count).map { index in
            Track(
                title: "\(prefix) \(index)",
                artist: "Artist \(index)",
                album: "Album \(index / 3 + 1)", // Groups tracks into albums
                url: URL(fileURLWithPath: "/test/\(prefix.lowercased())_\(index).mp3"),
                duration: TimeInterval(180 + index * 10), // Varying durations
                format: .mp3
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertEqual(queueManager.tracks.count, 0)
        XCTAssertNil(queueManager.currentIndex)
        XCTAssertNil(queueManager.currentTrack)
        XCTAssertEqual(queueManager.shuffleMode, .off)
        XCTAssertEqual(queueManager.repeatMode, .none)
        XCTAssertFalse(queueManager.hasNext)
        XCTAssertFalse(queueManager.hasPrevious)
        XCTAssertEqual(queueManager.history.count, 0)
    }
    
    // MARK: - Basic Queue Operations Tests
    
    func testEnqueue() {
        let tracks = createMockTracks(count: 3)
        
        queueManager.enqueue(tracks: tracks)
        
        XCTAssertEqual(queueManager.tracks.count, 3)
        XCTAssertEqual(queueManager.tracks[0].title, "Track 1")
        XCTAssertEqual(queueManager.tracks[2].title, "Track 3")
        XCTAssertEqual(mockDelegate.tracksUpdateCount, 1)
    }
    
    func testEnqueueSingleTrack() {
        let track = createMockTracks(count: 1)[0]
        
        queueManager.enqueue(track: track)
        
        XCTAssertEqual(queueManager.tracks.count, 1)
        XCTAssertEqual(queueManager.tracks[0].title, "Track 1")
    }
    
    func testEnqueueNext() {
        let initialTracks = createMockTracks(count: 3)
        let nextTracks = createMockTracks(count: 2, prefix: "Next")
        
        queueManager.enqueue(tracks: initialTracks)
        queueManager.setCurrentIndex(1) // Set to second track
        queueManager.enqueueNext(tracks: nextTracks)
        
        XCTAssertEqual(queueManager.tracks.count, 5)
        XCTAssertEqual(queueManager.tracks[2].title, "Next 1") // After current
        XCTAssertEqual(queueManager.tracks[3].title, "Next 2")
        XCTAssertEqual(queueManager.currentIndex, 1) // Should remain unchanged
    }
    
    func testEnqueueLater() {
        let initialTracks = createMockTracks(count: 2)
        let laterTracks = createMockTracks(count: 2, prefix: "Later")
        
        queueManager.enqueue(tracks: initialTracks)
        queueManager.enqueueLater(tracks: laterTracks)
        
        XCTAssertEqual(queueManager.tracks.count, 4)
        XCTAssertEqual(queueManager.tracks[2].title, "Later 1") // At end
        XCTAssertEqual(queueManager.tracks[3].title, "Later 2")
    }
    
    func testRemoveAtIndex() {
        let tracks = createMockTracks(count: 4)
        queueManager.enqueue(tracks: tracks)
        queueManager.setCurrentIndex(2)
        
        let removed = queueManager.remove(at: 1)
        
        XCTAssertNotNil(removed)
        XCTAssertEqual(removed?.title, "Track 2")
        XCTAssertEqual(queueManager.tracks.count, 3)
        XCTAssertEqual(queueManager.currentIndex, 1) // Adjusted down
    }
    
    func testRemoveCurrentTrack() {
        let tracks = createMockTracks(count: 3)
        queueManager.enqueue(tracks: tracks)
        queueManager.setCurrentIndex(1)
        
        let removed = queueManager.remove(at: 1)
        
        XCTAssertNotNil(removed)
        XCTAssertEqual(queueManager.tracks.count, 2)
        XCTAssertEqual(queueManager.currentIndex, 1) // Index unchanged, different track
        XCTAssertEqual(queueManager.currentTrack?.title, "Track 3")
    }
    
    func testRemoveByTrack() {
        let tracks = createMockTracks(count: 3)
        queueManager.enqueue(tracks: tracks)
        
        let success = queueManager.remove(track: tracks[1])
        
        XCTAssertTrue(success)
        XCTAssertEqual(queueManager.tracks.count, 2)
        XCTAssertFalse(queueManager.tracks.contains { $0.id == tracks[1].id })
    }
    
    func testMoveTrack() {
        let tracks = createMockTracks(count: 4)
        queueManager.enqueue(tracks: tracks)
        queueManager.setCurrentIndex(1)
        
        queueManager.move(from: 0, to: 2) // Move first track to third position
        
        XCTAssertEqual(queueManager.tracks[0].title, "Track 2")
        XCTAssertEqual(queueManager.tracks[1].title, "Track 3")
        XCTAssertEqual(queueManager.tracks[2].title, "Track 1")
        XCTAssertEqual(queueManager.currentIndex, 0) // Adjusted for moved track
    }
    
    func testClear() {
        let tracks = createMockTracks(count: 3)
        queueManager.enqueue(tracks: tracks)
        queueManager.setCurrentIndex(1)
        
        queueManager.clear()
        
        XCTAssertEqual(queueManager.tracks.count, 0)
        XCTAssertNil(queueManager.currentIndex)
        XCTAssertNil(queueManager.currentTrack)
    }
    
    // MARK: - Navigation Tests
    
    func testSetCurrentIndex() {
        let tracks = createMockTracks(count: 3)
        queueManager.enqueue(tracks: tracks)
        
        let success = queueManager.setCurrentIndex(1)
        
        XCTAssertTrue(success)
        XCTAssertEqual(queueManager.currentIndex, 1)
        XCTAssertEqual(queueManager.currentTrack?.title, "Track 2")
        XCTAssertEqual(mockDelegate.currentTrackChangeCount, 1)
    }
    
    func testSetCurrentTrack() {
        let tracks = createMockTracks(count: 3)
        queueManager.enqueue(tracks: tracks)
        
        let success = queueManager.setCurrentTrack(tracks[2])
        
        XCTAssertTrue(success)
        XCTAssertEqual(queueManager.currentIndex, 2)
        XCTAssertEqual(queueManager.currentTrack?.id, tracks[2].id)
    }
    
    func testNext() {
        let tracks = createMockTracks(count: 3)
        queueManager.enqueue(tracks: tracks)
        queueManager.setCurrentIndex(0)
        
        let nextTrack = queueManager.next()
        
        XCTAssertNotNil(nextTrack)
        XCTAssertEqual(queueManager.currentIndex, 1)
        XCTAssertEqual(nextTrack?.title, "Track 2")
        XCTAssertEqual(queueManager.history.count, 1) // Previous track added to history
        XCTAssertEqual(queueManager.history[0].title, "Track 1")
    }
    
    func testPrevious() {
        let tracks = createMockTracks(count: 3)
        queueManager.enqueue(tracks: tracks)
        queueManager.setCurrentIndex(2)
        
        let previousTrack = queueManager.previous()
        
        XCTAssertNotNil(previousTrack)
        XCTAssertEqual(queueManager.currentIndex, 1)
        XCTAssertEqual(previousTrack?.title, "Track 2")
    }
    
    func testNavigationWithRepeatNone() {
        let tracks = createMockTracks(count: 2)
        queueManager.enqueue(tracks: tracks)
        queueManager.repeatMode = .none
        queueManager.setCurrentIndex(1) // Last track
        
        XCTAssertFalse(queueManager.hasNext)
        XCTAssertTrue(queueManager.hasPrevious)
        
        let nextTrack = queueManager.next()
        XCTAssertNil(nextTrack)
    }
    
    func testNavigationWithRepeatAll() {
        let tracks = createMockTracks(count: 2)
        queueManager.enqueue(tracks: tracks)
        queueManager.repeatMode = .all
        queueManager.setCurrentIndex(1) // Last track
        
        XCTAssertTrue(queueManager.hasNext)
        XCTAssertTrue(queueManager.hasPrevious)
        
        let nextTrack = queueManager.next()
        XCTAssertNotNil(nextTrack)
        XCTAssertEqual(queueManager.currentIndex, 0) // Wrapped to beginning
    }
    
    func testNavigationWithRepeatOne() {
        let tracks = createMockTracks(count: 2)
        queueManager.enqueue(tracks: tracks)
        queueManager.repeatMode = .one
        queueManager.setCurrentIndex(0)
        
        XCTAssertTrue(queueManager.hasNext)
        XCTAssertTrue(queueManager.hasPrevious)
        
        let nextTrack = queueManager.next()
        XCTAssertNotNil(nextTrack)
        XCTAssertEqual(queueManager.currentIndex, 0) // Same track
    }
    
    // MARK: - Shuffle Tests
    
    func testShuffleActivation() {
        let tracks = createMockTracks(count: 5)
        queueManager.enqueue(tracks: tracks)
        queueManager.setCurrentIndex(2)
        let originalTrackId = queueManager.currentTrack?.id
        
        queueManager.shuffleMode = .random
        
        XCTAssertTrue(queueManager.shuffleMode.isActive)
        XCTAssertEqual(queueManager.currentTrack?.id, originalTrackId) // Current track preserved
        XCTAssertEqual(queueManager.tracks.count, 5) // All tracks still present
        XCTAssertEqual(mockDelegate.shuffleModeChangeCount, 1)
    }
    
    func testShuffleOff() {
        let tracks = createMockTracks(count: 5)
        queueManager.enqueue(tracks: tracks)
        queueManager.setCurrentIndex(2)
        queueManager.shuffleMode = .random
        let currentTrackId = queueManager.currentTrack?.id
        
        queueManager.shuffleMode = .off
        
        XCTAssertFalse(queueManager.shuffleMode.isActive)
        XCTAssertEqual(queueManager.currentTrack?.id, currentTrackId) // Current track preserved
        XCTAssertEqual(queueManager.tracks[0].title, "Track 1") // Original order restored
    }
    
    func testSmartShuffle() {
        let tracks = createMockTracks(count: 6) // Will have 2 albums with 3 tracks each
        queueManager.enqueue(tracks: tracks)
        queueManager.shuffleMode = .smart
        
        XCTAssertTrue(queueManager.shuffleMode.isActive)
        XCTAssertEqual(queueManager.tracks.count, 6)
        
        // Note: Smart shuffle randomness makes it hard to test specific order,
        // but we can verify all tracks are still present
        let originalIds = Set(tracks.map(\.id))
        let shuffledIds = Set(queueManager.tracks.map(\.id))
        XCTAssertEqual(originalIds, shuffledIds)
    }
    
    func testRestoreOrder() {
        let tracks = createMockTracks(count: 3)
        queueManager.enqueue(tracks: tracks)
        queueManager.shuffleMode = .random
        
        queueManager.restoreOrder()
        
        XCTAssertFalse(queueManager.shuffleMode.isActive)
        XCTAssertEqual(queueManager.tracks[0].title, "Track 1")
        XCTAssertEqual(queueManager.tracks[1].title, "Track 2")
        XCTAssertEqual(queueManager.tracks[2].title, "Track 3")
    }
    
    // MARK: - History Tests
    
    func testHistoryManagement() {
        let tracks = createMockTracks(count: 5)
        queueManager.enqueue(tracks: tracks)
        queueManager.setCurrentIndex(0)
        
        // Move through several tracks
        queueManager.next() // Track 1 -> Track 2
        queueManager.next() // Track 2 -> Track 3
        queueManager.next() // Track 3 -> Track 4
        
        XCTAssertEqual(queueManager.history.count, 3)
        XCTAssertEqual(queueManager.history[0].title, "Track 3") // Most recent first
        XCTAssertEqual(queueManager.history[1].title, "Track 2")
        XCTAssertEqual(queueManager.history[2].title, "Track 1")
    }
    
    func testHistoryMaxSize() {
        let tracks = createMockTracks(count: 15)
        queueManager.enqueue(tracks: tracks)
        queueManager.setCurrentIndex(0)
        
        // Move through all tracks to fill history beyond max size (10)
        for _ in 1..<15 {
            queueManager.next()
        }
        
        XCTAssertEqual(queueManager.history.count, 10) // Capped at max size
    }
    
    func testClearHistory() {
        let tracks = createMockTracks(count: 3)
        queueManager.enqueue(tracks: tracks)
        queueManager.setCurrentIndex(0)
        queueManager.next()
        
        XCTAssertEqual(queueManager.history.count, 1)
        
        queueManager.clearHistory()
        
        XCTAssertEqual(queueManager.history.count, 0)
    }
    
    // MARK: - Queue State Tests
    
    func testQueueState() {
        let tracks = createMockTracks(count: 3)
        queueManager.enqueue(tracks: tracks)
        queueManager.setCurrentIndex(1)
        queueManager.shuffleMode = .random
        queueManager.repeatMode = .all
        
        let state = queueManager.queueState
        
        XCTAssertEqual(state.tracks.count, 3)
        XCTAssertEqual(state.currentIndex, 1)
        XCTAssertEqual(state.currentTrack?.id, queueManager.currentTrack?.id)
        XCTAssertEqual(state.shuffleMode, .random)
        XCTAssertEqual(state.repeatMode, .all)
        XCTAssertTrue(state.isShuffled)
        XCTAssertTrue(state.isRepeating)
    }
    
    // MARK: - Complex Integration Tests
    
    func testComplexScenario() {
        // Test a complex real-world scenario
        let tracks = createMockTracks(count: 10)
        
        // Add tracks and start playing
        queueManager.enqueue(tracks: Array(tracks[0..<5]))
        queueManager.setCurrentIndex(2)
        
        // Add more tracks to play next
        queueManager.enqueueNext(tracks: Array(tracks[5..<7]))
        XCTAssertEqual(queueManager.tracks.count, 7)
        
        // Enable shuffle
        queueManager.shuffleMode = .smart
        XCTAssertTrue(queueManager.shuffleMode.isActive)
        
        // Move to next track
        let nextTrack = queueManager.next()
        XCTAssertNotNil(nextTrack)
        XCTAssertEqual(queueManager.history.count, 1)
        
        // Enable repeat all
        queueManager.repeatMode = .all
        XCTAssertTrue(queueManager.hasNext)
        XCTAssertTrue(queueManager.hasPrevious)
        
        // Remove a track
        queueManager.remove(at: 0)
        XCTAssertEqual(queueManager.tracks.count, 6)
        
        // Verify state consistency
        let issues = queueManager.validateState()
        XCTAssertEqual(issues.count, 0, "State should be consistent: \(issues)")
    }
    
    // MARK: - Edge Cases
    
    func testEmptyQueueNavigation() {
        XCTAssertNil(queueManager.next())
        XCTAssertNil(queueManager.previous())
        XCTAssertFalse(queueManager.hasNext)
        XCTAssertFalse(queueManager.hasPrevious)
    }
    
    func testSingleTrackQueue() {
        let tracks = createMockTracks(count: 1)
        queueManager.enqueue(tracks: tracks)
        queueManager.setCurrentIndex(0)
        
        // With no repeat
        queueManager.repeatMode = .none
        XCTAssertFalse(queueManager.hasNext)
        XCTAssertFalse(queueManager.hasPrevious)
        
        // With repeat one
        queueManager.repeatMode = .one
        XCTAssertTrue(queueManager.hasNext)
        XCTAssertTrue(queueManager.hasPrevious)
        
        let nextTrack = queueManager.next()
        XCTAssertEqual(nextTrack?.id, tracks[0].id) // Same track
        XCTAssertEqual(queueManager.currentIndex, 0)
    }
    
    func testInvalidOperations() {
        let tracks = createMockTracks(count: 3)
        queueManager.enqueue(tracks: tracks)
        
        // Invalid index operations
        XCTAssertFalse(queueManager.setCurrentIndex(-1))
        XCTAssertFalse(queueManager.setCurrentIndex(10))
        XCTAssertNil(queueManager.remove(at: -1))
        XCTAssertNil(queueManager.remove(at: 10))
        
        // Move operations that should be ignored
        queueManager.move(from: 0, to: 0) // Same position
        queueManager.move(from: -1, to: 1) // Invalid from
        queueManager.move(from: 1, to: -1) // Invalid to
    }
}

// MARK: - Mock Delegate

@MainActor
class MockAudioQueueDelegate: AudioQueueDelegate {
    var tracksUpdateCount = 0
    var currentTrackChangeCount = 0
    var shuffleModeChangeCount = 0
    var repeatModeChangeCount = 0
    var historyAddCount = 0
    
    var lastUpdatedTracks: [Track] = []
    var lastCurrentTrack: Track?
    var lastCurrentIndex: Int?
    var lastShuffleMode: QueueShuffleMode?
    var lastRepeatMode: QueueRepeatMode?
    var lastHistoryTrack: Track?
    
    func audioQueue(_ queue: AudioQueue, didUpdateTracks tracks: [Track]) {
        tracksUpdateCount += 1
        lastUpdatedTracks = tracks
    }
    
    func audioQueue(_ queue: AudioQueue, didChangeCurrentTrack track: Track?, at index: Int?) {
        currentTrackChangeCount += 1
        lastCurrentTrack = track
        lastCurrentIndex = index
    }
    
    func audioQueue(_ queue: AudioQueue, didChangeShuffleMode shuffleMode: QueueShuffleMode) {
        shuffleModeChangeCount += 1
        lastShuffleMode = shuffleMode
    }
    
    func audioQueue(_ queue: AudioQueue, didChangeRepeatMode repeatMode: QueueRepeatMode) {
        repeatModeChangeCount += 1
        lastRepeatMode = repeatMode
    }
    
    func audioQueue(_ queue: AudioQueue, didAddToHistory track: Track) {
        historyAddCount += 1
        lastHistoryTrack = track
    }
} 