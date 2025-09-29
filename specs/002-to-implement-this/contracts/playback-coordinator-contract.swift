// Playback Coordinator Contract
// Version: 1.0
// Purpose: Define interface for coordinating playback operations with proper concurrency

import Foundation

// MARK: - Protocol Definition

@MainActor
protocol PlaybackCoordinating: Sendable {
    // Playback Control
    func play() async throws
    func pause() async
    func stop() async
    func seek(to time: TimeInterval) async throws
    func setRate(_ rate: Float) async throws

    // Track Management
    func load(_ track: Track) async throws
    func preloadNext(_ track: Track) async
    func clearPreload() async

    // Queue Operations
    func playNext() async throws
    func playPrevious() async throws
    func skipTo(index: Int) async throws

    // State Observation
    var currentState: PlaybackState { get async }
    var statePublisher: AsyncStream<PlaybackState> { get }

    // Progress Updates
    func startProgressTimer() async
    func stopProgressTimer() async
    var progressPublisher: AsyncStream<PlaybackProgress> { get }
}

// MARK: - Data Types

struct PlaybackProgress: Sendable {
    let currentTime: TimeInterval
    let duration: TimeInterval
    let bufferedTime: TimeInterval
    let isLive: Bool

    var percentComplete: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration * 100
    }

    var remainingTime: TimeInterval {
        max(0, duration - currentTime)
    }
}

struct PlaybackCapabilities: Sendable {
    let canPlay: Bool
    let canPause: Bool
    let canSeek: Bool
    let canSkipForward: Bool
    let canSkipBackward: Bool
    let supportsVariableRate: Bool
    let minRate: Float
    let maxRate: Float
}

// MARK: - Error Types

enum PlaybackError: Error, Sendable {
    case trackNotFound
    case engineNotInitialized
    case loadFailed(String)
    case seekFailed(String)
    case unsupportedFormat(AudioFormat)
    case noAudioRoute
    case queueEmpty
    case invalidQueueIndex(Int)
}

// MARK: - Notifications

struct PlaybackNotification: Sendable {
    enum Kind {
        case trackDidChange(Track?)
        case stateDidChange(PlaybackState)
        case progressDidUpdate(PlaybackProgress)
        case errorOccurred(PlaybackError)
        case queueDidChange
    }

    let kind: Kind
    let timestamp: Date
}

// MARK: - Contract Tests (These should fail initially)

final class PlaybackCoordinatorContractTests {
    @MainActor
    func testPlaybackLifecycle() async throws {
        let coordinator: PlaybackCoordinating = PlaybackCoordinator() // Should fail: not implemented

        let track = Track() // Mock track
        try await coordinator.load(track)
        try await coordinator.play()

        let state = await coordinator.currentState
        assert(state.status == .playing)

        await coordinator.pause()
        let pausedState = await coordinator.currentState
        assert(pausedState.status == .paused)
    }

    @MainActor
    func testSeekOperation() async throws {
        let coordinator: PlaybackCoordinating = PlaybackCoordinator() // Should fail: not implemented

        let track = Track() // Mock track with duration
        try await coordinator.load(track)
        try await coordinator.play()
        try await coordinator.seek(to: 30.0)

        // Verify seek completed
    }

    @MainActor
    func testQueueNavigation() async throws {
        let coordinator: PlaybackCoordinating = PlaybackCoordinator() // Should fail: not implemented

        try await coordinator.playNext()
        try await coordinator.playPrevious()
        try await coordinator.skipTo(index: 5)
    }

    @MainActor
    func testProgressUpdates() async throws {
        let coordinator: PlaybackCoordinating = PlaybackCoordinator() // Should fail: not implemented

        await coordinator.startProgressTimer()

        var progressReceived = false
        for await progress in coordinator.progressPublisher {
            progressReceived = true
            assert(progress.currentTime >= 0)
            assert(progress.duration >= 0)
            break // Just test first update
        }

        assert(progressReceived)
        await coordinator.stopProgressTimer()
    }
}
