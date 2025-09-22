//
//  QueueCoordinator.swift
//  Fonic HiFi
//
//  Manages queue operations including navigation, shuffle, repeat modes, and enqueueing.
//  Extracted from AudioEngineFacade to improve modularity and maintainability.
//

import Foundation
import os.log

/// Handles all queue-related operations
@MainActor
public final class QueueCoordinator {
  
  // MARK: - Dependencies
  
  private let queueManager: AudioQueueManager
  private let playbackCoordinator: PlaybackCoordinator
  private weak var facade: AudioEngineFacade?
  
  private let logger = Logger(subsystem: "com.fonichifi.audio", category: "QueueCoordinator")
  
  // MARK: - Initialization
  
  init(
    queueManager: AudioQueueManager,
    playbackCoordinator: PlaybackCoordinator,
    facade: AudioEngineFacade
  ) {
    self.queueManager = queueManager
    self.playbackCoordinator = playbackCoordinator
    self.facade = facade
  }
  
  // MARK: - Queue Navigation
  
  /// Play the next track in the queue
  public func playNext() async throws {
    guard let nextTrack = queueManager.next() else {
      logger.info("No next track available")
      await playbackCoordinator.stop()
      return
    }
    
    queueManager.setCurrentTrack(nextTrack)
    
    // Convert AudioTrack back to Track for engine compatibility
    let track = createTrackFromAudioTrack(nextTrack)
    try await playbackCoordinator.play(track: track)
  }
  
  /// Play the previous track in the queue
  public func playPrevious() async throws {
    guard let previousTrack = queueManager.previous() else {
      logger.info("No previous track available")
      return
    }
    
    queueManager.setCurrentTrack(previousTrack)
    
    // Convert AudioTrack back to Track for engine compatibility
    let track = createTrackFromAudioTrack(previousTrack)
    try await playbackCoordinator.play(track: track)
  }
  
  // MARK: - Queue Management
  
  /// Add tracks to the queue
  /// - Parameter tracks: Tracks to add
  public func enqueue(_ tracks: [Track]) {
    let audioTracks = tracks.map { $0.toAudioTrack() }
    queueManager.enqueue(tracks: audioTracks)
    logger.info("Enqueued \(tracks.count) tracks")
  }
  
  /// Add a track to play next
  /// - Parameter track: Track to play next
  public func enqueueNext(_ track: Track) {
    queueManager.enqueueNext(tracks: [track.toAudioTrack()])
    logger.info("Enqueued next: \(track.title)")
  }
  
  /// Clear the current queue
  public func clearQueue() {
    queueManager.clear()
    logger.info("Queue cleared")
  }
  
  /// Remove a track from the queue
  /// - Parameter trackId: ID of the track to remove
  public func removeFromQueue(trackId: String) {
    // Note: This would need to be implemented in AudioQueueManager
    logger.info("Removing track \(trackId) from queue")
  }
  
  // MARK: - Queue Modes
  
  /// Set shuffle mode
  /// - Parameter mode: Shuffle mode to set
  public func setShuffleMode(_ mode: QueueShuffleMode) {
    queueManager.shuffleMode = mode
    logger.info("Shuffle mode set to: \(String(describing: mode))")
  }
  
  /// Set repeat mode
  /// - Parameter mode: Repeat mode to set
  public func setRepeatMode(_ mode: QueueRepeatMode) {
    queueManager.repeatMode = mode
    logger.info("Repeat mode set to: \(String(describing: mode))")
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
  
  // MARK: - Queue Persistence
  
  /// Save the current queue state
  public func saveQueueState() async {
    // This could be implemented to persist queue to disk
    logger.info("Saving queue state")
  }
  
  /// Restore a previously saved queue state
  public func restoreQueueState() async {
    // This could be implemented to restore queue from disk
    logger.info("Restoring queue state")
  }
  
  // MARK: - Private Helpers
  
  /// Helper method to create a Track from AudioTrack data
  /// This is a temporary solution for type conversion compatibility
  private func createTrackFromAudioTrack(_ audioTrack: AudioTrack) -> Track {
    return Track(
      url: audioTrack.url,
      title: audioTrack.title,
      artist: audioTrack.artist,
      album: audioTrack.album,
      audioFormat: audioTrack.audioFormat,
      duration: audioTrack.duration
    )
  }
}