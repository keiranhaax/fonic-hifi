//
//  AudioEngineFacadeTests.swift
//  Fonic HiFiTests
//
//  Created by Claude on 5/27/2025.
//

import XCTest
import Combine
@testable import Fonic_HiFi

@MainActor
final class AudioEngineFacadeTests: XCTestCase {
    
    // MARK: - Properties
    
    private var facade: AudioEngineFacade!
    private var mockSessionManager: MockAudioSessionManager!
    private var mockFormatDetectionManager: MockAudioFormatDetectionManager!
    private var mockEngineFactory: MockAudioEngineFactory!
    private var mockEngine: MockAudioEngineService!
    private var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create mocks
        mockSessionManager = MockAudioSessionManager()
        mockFormatDetectionManager = MockAudioFormatDetectionManager()
        mockEngineFactory = MockAudioEngineFactory()
        mockEngine = MockAudioEngineService()
        cancellables = Set<AnyCancellable>()
        
        // Configure mock factory to return our mock engine
        mockEngineFactory.engineToReturn = mockEngine
        
        // Create facade with mocked dependencies
        facade = AudioEngineFacade(
            sessionManager: mockSessionManager,
            formatDetectionManager: mockFormatDetectionManager,
            engineFactory: mockEngineFactory
        )
    }
    
    override func tearDown() async throws {
        cancellables.removeAll()
        await facade?.shutdown()
        facade = nil
        mockEngine = nil
        mockEngineFactory = nil
        mockFormatDetectionManager = nil
        mockSessionManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() async throws {
        XCTAssertFalse(facade.isReady)
        XCTAssertFalse(facade.isPlaying)
        XCTAssertEqual(facade.currentState, .idle)
        XCTAssertNil(facade.currentTrack)
        XCTAssertNil(facade.currentEngine)
    }
    
    func testSuccessfulInitialization() async throws {
        // Given
        mockSessionManager.shouldSucceed = true
        
        // When
        try await facade.initialize()
        
        // Then
        XCTAssertTrue(facade.isReady)
        XCTAssertTrue(mockSessionManager.configureSessionCalled)
    }
    
    func testFailedInitialization() async throws {
        // Given
        mockSessionManager.shouldSucceed = false
        
        // When & Then
        do {
            try await facade.initialize()
            XCTFail("Expected initialization to fail")
        } catch {
            XCTAssertFalse(facade.isReady)
            XCTAssertTrue(mockSessionManager.configureSessionCalled)
        }
    }
    
    // MARK: - Playback Control Tests
    
    func testPlayTrackSuccess() async throws {
        // Given
        try await facade.initialize()
        let track = createTestTrack()
        let formatInfo = createTestFormatInfo()
        
        mockFormatDetectionManager.formatToReturn = formatInfo
        mockEngine.shouldSucceed = true
        
        // When
        try await facade.play(track: track)
        
        // Then
        XCTAssertEqual(facade.currentTrack?.id, track.id)
        XCTAssertTrue(facade.currentState.isPlaying)
        XCTAssertTrue(mockFormatDetectionManager.detectFormatCalled)
        XCTAssertTrue(mockEngine.loadCalled)
        XCTAssertTrue(mockEngine.playCalled)
    }
    
    func testPlayTrackFailure() async throws {
        // Given
        try await facade.initialize()
        let track = createTestTrack()
        
        mockFormatDetectionManager.shouldFail = true
        
        // When & Then
        do {
            try await facade.play(track: track)
            XCTFail("Expected play to fail")
        } catch {
            XCTAssertTrue(facade.currentState.description.contains("Error"))
        }
    }
    
    func testPausePlayback() async throws {
        // Given
        try await facade.initialize()
        let track = createTestTrack()
        try await facade.play(track: track)
        
        // When
        await facade.pause()
        
        // Then
        XCTAssertTrue(facade.currentState.isPaused)
        XCTAssertTrue(mockEngine.pauseCalled)
    }
    
    func testResumePlayback() async throws {
        // Given
        try await facade.initialize()
        let track = createTestTrack()
        try await facade.play(track: track)
        await facade.pause()
        
        // When
        try await facade.resume()
        
        // Then
        XCTAssertTrue(facade.currentState.isPlaying)
        XCTAssertEqual(mockEngine.playCallCount, 2) // Once for initial play, once for resume
    }
    
    func testStopPlayback() async throws {
        // Given
        try await facade.initialize()
        let track = createTestTrack()
        try await facade.play(track: track)
        
        // When
        await facade.stop()
        
        // Then
        XCTAssertTrue(facade.currentState.isIdle || facade.currentState == .stopped)
        XCTAssertTrue(mockEngine.stopCalled)
    }
    
    func testSeekToPosition() async throws {
        // Given
        try await facade.initialize()
        let track = createTestTrack()
        try await facade.play(track: track)
        let targetTime: TimeInterval = 30.0
        
        // When
        try await facade.seek(to: targetTime)
        
        // Then
        XCTAssertTrue(mockEngine.seekCalled)
        XCTAssertEqual(mockEngine.lastSeekTime, targetTime)
    }
    
    // MARK: - Queue Operations Tests
    
    func testEnqueueTracks() {
        // Given
        let tracks = [createTestTrack(), createTestTrack(title: "Track 2")]
        
        // When
        facade.enqueue(tracks)
        
        // Then
        XCTAssertEqual(facade.queueState.tracks.count, 2)
        XCTAssertEqual(facade.queueState.tracks[0].title, "Test Track")
        XCTAssertEqual(facade.queueState.tracks[1].title, "Track 2")
    }
    
    func testEnqueueNext() {
        // Given
        let initialTrack = createTestTrack(title: "First")
        let nextTrack = createTestTrack(title: "Next")
        facade.enqueue([initialTrack])
        
        // When
        facade.enqueueNext(nextTrack)
        
        // Then
        XCTAssertEqual(facade.queueState.tracks.count, 2)
        // The next track should be inserted after the current position
    }
    
    func testShuffleModeChange() {
        // Given
        let tracks = [createTestTrack(), createTestTrack(title: "Track 2")]
        facade.enqueue(tracks)
        
        // When
        facade.setShuffleMode(.random)
        
        // Then
        XCTAssertEqual(facade.queueState.shuffleMode, .random)
    }
    
    func testRepeatModeChange() {
        // When
        facade.setRepeatMode(.all)
        
        // Then
        XCTAssertEqual(facade.queueState.repeatMode, .all)
    }
    
    // MARK: - Validation & Diagnostics Tests
    
    func testValidatePlaybackSetup() async throws {
        // Given
        try await facade.initialize()
        let track = createTestTrack()
        facade.enqueue([track])
        
        // When
        let result = await facade.validatePlaybackSetup()
        
        // Then
        XCTAssertNotNil(result)
    }
    
    func testGetCurrentDiagnostics() async throws {
        // Given
        try await facade.initialize()
        
        // When
        let diagnostics = await facade.getCurrentDiagnostics()
        
        // Then
        XCTAssertNotNil(diagnostics)
    }
    
    func testGetCurrentMetrics() async throws {
        // Given
        try await facade.initialize()
        
        // When
        let metrics = await facade.getCurrentMetrics()
        
        // Then
        XCTAssertNotNil(metrics)
    }
    
    // MARK: - Integration Tests
    
    func testStateManagerIntegration() async throws {
        // Given
        try await facade.initialize()
        let track = createTestTrack()
        
        var stateChanges: [PlaybackState] = []
        facade.stateManager.statePublisher
            .sink { change in
                stateChanges.append(change.to)
            }
            .store(in: &cancellables)
        
        // When
        try await facade.play(track: track)
        await facade.pause()
        
        // Give some time for state changes to propagate
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertGreaterThan(stateChanges.count, 0)
        XCTAssertTrue(stateChanges.contains { $0.isPlaying })
        XCTAssertTrue(stateChanges.contains { $0.isPaused })
    }
    
    func testQueueStateIntegration() async throws {
        // Given
        try await facade.initialize()
        let track1 = createTestTrack(title: "Track 1")
        let track2 = createTestTrack(title: "Track 2")
        
        // When
        facade.enqueue([track1, track2])
        try await facade.play(track: track1)
        
        // Then
        XCTAssertEqual(facade.currentTrack?.id, track1.id)
        XCTAssertEqual(facade.queueState.currentIndex, 0)
        XCTAssertTrue(facade.queueState.hasNext)
        XCTAssertFalse(facade.queueState.hasPrevious)
    }
    
    // MARK: - Error Handling Tests
    
    func testPlayWithoutInitialization() async {
        // Given
        let track = createTestTrack()
        
        // When & Then
        do {
            try await facade.play(track: track)
            XCTFail("Expected error when playing without initialization")
        } catch {
            // Expected error
        }
    }
    
    func testResumeWithoutEngine() async {
        // Given
        try? await facade.initialize()
        
        // When & Then
        do {
            try await facade.resume()
            XCTFail("Expected error when resuming without engine")
        } catch {
            // Expected error
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestTrack(title: String = "Test Track") -> Track {
        return Track(
            id: UUID().uuidString,
            title: title,
            artist: "Test Artist",
            album: "Test Album",
            url: URL(string: "file:///test/track.flac")!,
            duration: 180.0,
            format: .flac
        )
    }
    
    private func createTestFormatInfo() -> AudioFileInfo {
        return AudioFileInfo(
            format: .flac,
            sampleRate: 96000,
            bitDepth: 24,
            channels: 2,
            bitrate: 2304000,
            duration: 180.0,
            fileSize: 50_000_000
        )
    }
}

// MARK: - Mock Classes

@MainActor
private class MockAudioSessionManager: AudioSessionManager {
    var shouldSucceed = true
    var configureSessionCalled = false
    
    override func configureSession(for configuration: AudioEngineConfiguration) async throws {
        configureSessionCalled = true
        if !shouldSucceed {
            throw AudioError.engineInitializationFailed
        }
    }
}

@MainActor
private class MockAudioFormatDetectionManager: AudioFormatDetectionManager {
    var shouldFail = false
    var detectFormatCalled = false
    var formatToReturn = AudioFileInfo(
        format: .flac,
        sampleRate: 96000,
        bitDepth: 24,
        channels: 2,
        bitrate: 2304000,
        duration: 180.0,
        fileSize: 50_000_000
    )
    
    override func detectFormat(from url: URL) async throws -> AudioFileInfo {
        detectFormatCalled = true
        if shouldFail {
            throw AudioError.fileNotFound
        }
        return formatToReturn
    }
}

@MainActor
private class MockAudioEngineFactory: AudioEngineFactory {
    var engineToReturn: AudioEngineService?
    
    override func makeEngine(
        for format: AudioFormat,
        configuration: AudioEngineConfiguration
    ) async throws -> AudioEngineService {
        guard let engine = engineToReturn else {
            throw AudioError.engineInitializationFailed
        }
        return engine
    }
}

@MainActor
private class MockAudioEngineService: AudioEngineService {
    var shouldSucceed = true
    var loadCalled = false
    var playCalled = false
    var pauseCalled = false
    var stopCalled = false
    var seekCalled = false
    var playCallCount = 0
    var lastSeekTime: TimeInterval = 0
    
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 180.0
    
    func load(url: URL) async throws {
        loadCalled = true
        if !shouldSucceed {
            throw AudioError.fileNotFound
        }
    }
    
    func play() async throws {
        playCalled = true
        playCallCount += 1
        if !shouldSucceed {
            throw AudioError.playbackFailed
        }
        isPlaying = true
    }
    
    func pause() async {
        pauseCalled = true
        isPlaying = false
    }
    
    func stop() async {
        stopCalled = true
        isPlaying = false
        currentTime = 0
    }
    
    func seek(to time: TimeInterval) async throws {
        seekCalled = true
        lastSeekTime = time
        if !shouldSucceed {
            throw AudioError.playbackFailed
        }
        currentTime = time
    }
}