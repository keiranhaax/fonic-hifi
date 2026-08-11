//
//  QueueCoordinator.swift
//  Fonic HiFi
//
//  Manages queue operations including navigation, shuffle, repeat modes, and enqueueing.
//  Extracted from AudioEngineFacade to improve modularity and maintainability.
//

import Foundation
import OSLog

/// Handles all queue-related operations
@MainActor
public final class QueueCoordinator {
    // MARK: - Dependencies

    private let queueManager: AudioQueueManager
    private let stateManager: PlaybackStateManager
    private let engineManager: AudioEngineManager
    private let playbackController: PlaybackQueueHandling
    private let logger = Log.logger(.audioQueueCoordinator)

    // MARK: - Initialization

    init(
        queueManager: AudioQueueManager,
        stateManager: PlaybackStateManager,
        engineManager: AudioEngineManager,
        playbackController: PlaybackQueueHandling,
    ) {
        self.queueManager = queueManager
        self.stateManager = stateManager
        self.engineManager = engineManager
        self.playbackController = playbackController
    }

    // MARK: - Queue Navigation

    /// Play the next track in the queue
    @discardableResult
    public func playNext() async throws -> Bool {
        try await playNext(
            queueManager.peekNextManually(),
            expectedCurrentID: queueManager.currentTrack?.id
        )
    }

    /// Play the repeat-aware next track after natural completion.
    @discardableResult
    func playNextAfterCompletion() async throws -> Bool {
        try await playNext(
            queueManager.peekNextAfterCompletion(),
            expectedCurrentID: queueManager.currentTrack?.id
        )
    }

    private func playNext(
        _ nextTrack: AudioTrack?,
        expectedCurrentID: UUID?
    ) async throws -> Bool {
        guard let nextTrack else {
            logger.info("No next track available")
            await playbackController.stop()
            return false
        }

        let snapshot = PlayableTrackSnapshot(audioTrack: nextTrack)
        if engineManager.configuration.crossfadeDuration > 0,
           stateManager.currentState.isPlaying {
            try await playbackController.crossfade(to: snapshot, queueEntry: nextTrack)
        } else {
            try await playbackController.play(snapshot: snapshot, queueEntry: nextTrack)
        }

        guard queueManager.commitNext(nextTrack, expectedCurrentID: expectedCurrentID) else {
            await playbackController.stop()
            throw AudioError.playbackFailed(reason: "Queue changed during playback")
        }
        return true
    }

    /// Play the previous track in the queue
    public func playPrevious() async throws {
        let expectedCurrentID = queueManager.currentTrack?.id
        guard let previousTrack = queueManager.peekPreviousManually() else {
            logger.info("No previous track available")
            return
        }

        let snapshot = PlayableTrackSnapshot(audioTrack: previousTrack)
        if engineManager.configuration.crossfadeDuration > 0,
           stateManager.currentState.isPlaying {
            try await playbackController.crossfade(to: snapshot, queueEntry: previousTrack)
        } else {
            try await playbackController.play(snapshot: snapshot, queueEntry: previousTrack)
        }

        guard queueManager.commitPrevious(previousTrack, expectedCurrentID: expectedCurrentID) else {
            await playbackController.stop()
            throw AudioError.playbackFailed(reason: "Queue changed during playback")
        }
    }

    // MARK: - Queue Management

    /// Add tracks to the queue
    /// - Parameter tracks: Tracks to add
    public func enqueue(_ tracks: [Track]) {
        let audioTracks = tracks.map { $0.toAudioTrack() }
        queueManager.enqueue(tracks: audioTracks)
        logger.info("Enqueued \(tracks.count, privacy: .public) tracks")
    }

    /// Add a track to play next
    /// - Parameter track: Track to play next
    public func enqueueNext(_ track: Track) {
        queueManager.enqueueNext(tracks: [track.toAudioTrack()])
        logger.info("Enqueued selected track to play next")
    }

    /// Replace the queue and optionally select the starting item.
    /// Queue mutation remains owned by the coordinator so views cannot bypass
    /// playback state propagation.
    public func replaceQueue(with tracks: [Track], startIndex: Int? = nil) {
        queueManager.replaceQueue(
            with: tracks.map { $0.toAudioTrack() },
            startIndex: startIndex
        )
    }

    /// Reorder items in the up-next portion of the queue.
    public func moveItem(fromOffsets source: IndexSet, toOffset destination: Int) {
        queueManager.moveRemaining(fromOffsets: source, toOffset: destination)
    }

    /// Remove items from the up-next portion of the queue.
    public func removeItem(at offsets: IndexSet) {
        queueManager.removeRemaining(at: offsets)
    }

    /// Start a queued item and commit it only after playback has started.
    public func jumpToTrack(_ track: AudioTrack) async throws {
        guard queueManager.tracks.contains(where: { $0.id == track.id }) else {
            throw AudioError.playbackFailed(reason: "Track is not in the queue")
        }

        let expectedCurrentID = queueManager.currentTrack?.id
        try await playbackController.play(
            snapshot: PlayableTrackSnapshot(audioTrack: track),
            queueEntry: track
        )

        guard queueManager.setCurrentTrack(track),
              queueManager.currentTrack?.id == track.id
        else {
            await playbackController.stop()
            throw AudioError.playbackFailed(reason: "Queue changed during playback")
        }

        if expectedCurrentID != track.id {
            logger.info("Jumped to queued track")
        }
    }

    // MARK: - Queue Modes

    /// Set shuffle mode
    /// - Parameter mode: Shuffle mode to set
    public func setShuffleMode(_ mode: QueueShuffleMode) {
        queueManager.shuffleMode = mode
        logger.info("Shuffle mode set to: \(String(describing: mode), privacy: .public)")
    }

    /// Set repeat mode
    /// - Parameter mode: Repeat mode to set
    public func setRepeatMode(_ mode: QueueRepeatMode) {
        queueManager.repeatMode = mode
        logger.info("Repeat mode set to: \(String(describing: mode), privacy: .public)")
    }

    /// Get the current shuffle mode
    public var shuffleMode: QueueShuffleMode {
        queueManager.shuffleMode
    }

    /// Get the current repeat mode
    public var repeatMode: QueueRepeatMode {
        queueManager.repeatMode
    }

    // MARK: - Queue State

    /// Get the current queue state
    public var queueState: QueueState {
        queueManager.queueState
    }

    /// Get the current track
    public var currentTrack: AudioTrack? {
        queueManager.currentTrack
    }

    /// Get the upcoming tracks
    public var upcomingTracks: [AudioTrack] {
        // Get tracks after current index
        guard let currentIndex = queueManager.currentIndex else {
            return Array(queueManager.tracks)
        }
        let nextIndex = currentIndex + 1
        guard nextIndex < queueManager.tracks.count else {
            return []
        }
        return Array(queueManager.tracks[nextIndex...])
    }

    /// Get the previous tracks (history)
    public var previousTracks: [AudioTrack] {
        // Use the history property from AudioQueueManager
        queueManager.history
    }

    /// Check if there's a next track available
    public var hasNext: Bool {
        queueManager.hasNext
    }

    /// Check if there's a previous track available
    public var hasPrevious: Bool {
        queueManager.hasPrevious
    }

}
