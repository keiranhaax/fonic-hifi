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
    public func playNext() async throws {
        try await playNext(queueManager.nextManually())
    }

    /// Play the repeat-aware next track after natural completion.
    func playNextAfterCompletion() async throws {
        try await playNext(queueManager.next())
    }

    private func playNext(_ nextTrack: AudioTrack?) async throws {
        guard let nextTrack else {
            logger.info("No next track available")
            await playbackController.stop()
            return
        }

        queueManager.setCurrentTrack(nextTrack)

        let track = createTrackFromAudioTrack(nextTrack)
        if engineManager.configuration.crossfadeDuration > 0,
           stateManager.currentState.isPlaying {
            try await playbackController.crossfade(to: nextTrack, displayTrack: track)
        } else {
            try await playbackController.play(track: track, queueEntry: nextTrack)
        }
    }

    /// Play the previous track in the queue
    public func playPrevious() async throws {
        guard let previousTrack = queueManager.previousManually() else {
            logger.info("No previous track available")
            return
        }

        queueManager.setCurrentTrack(previousTrack)

        let track = createTrackFromAudioTrack(previousTrack)
        if engineManager.configuration.crossfadeDuration > 0,
           stateManager.currentState.isPlaying {
            try await playbackController.crossfade(to: previousTrack, displayTrack: track)
        } else {
            try await playbackController.play(track: track, queueEntry: previousTrack)
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

    // MARK: - Private Helpers

    /// Helper method to create a Track from AudioTrack data
    /// This is a temporary solution for type conversion compatibility
    private func createTrackFromAudioTrack(_ audioTrack: AudioTrack) -> Track {
        let track = Track(
            url: audioTrack.url,
            title: audioTrack.title,
            artist: audioTrack.artist,
            album: audioTrack.album,
            audioFormat: audioTrack.audioFormat,
            duration: audioTrack.duration,
        )
        track.replayGainTrack = audioTrack.replayGainTrack
        track.replayGainAlbum = audioTrack.replayGainAlbum
        return track
    }
}
