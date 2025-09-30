//
//  AudioQueue.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/25.
//

import Foundation

/// Protocol defining queue operations for audio playback management
@MainActor
public protocol AudioQueue: AnyObject, Sendable {
    // MARK: - Queue State

    /// All tracks in the queue
    var tracks: [AudioTrack] { get }

    /// Current playing index
    var currentIndex: Int? { get }

    /// Current track being played
    var currentTrack: AudioTrack? { get }

    /// Shuffle mode setting
    var shuffleMode: QueueShuffleMode { get set }

    /// Repeat mode setting
    var repeatMode: QueueRepeatMode { get set }

    /// Whether there is a next track available
    var hasNext: Bool { get }

    /// Whether there is a previous track available
    var hasPrevious: Bool { get }

    /// Playback history (last 50 tracks by default)
    var history: [AudioTrack] { get }

    // MARK: - Queue Operations

    /// Add a track to the end of the queue
    /// - Parameter track: Track to add
    func enqueue(track: AudioTrack)

    /// Add multiple tracks to the end of the queue
    /// - Parameter tracks: Tracks to add
    func enqueue(tracks: [AudioTrack])

    /// Add a track to play next (after current track)
    /// - Parameter track: Track to play next
    func enqueueNext(track: AudioTrack)

    /// Add tracks to play next (after current track)
    /// - Parameter tracks: Tracks to play next
    func enqueueNext(tracks: [AudioTrack])

    /// Add a track to play later (at end of queue)
    /// - Parameter track: Track to play later
    func enqueueLater(track: AudioTrack)

    /// Add tracks to play later (at end of queue)
    /// - Parameter tracks: Tracks to play later
    func enqueueLater(tracks: [AudioTrack])

    /// Remove track at specified index
    /// - Parameter index: Index to remove
    /// - Returns: The removed track, if any
    @discardableResult
    func remove(at index: Int) -> AudioTrack?

    /// Remove specific track from queue
    /// - Parameter track: Track to remove
    /// - Returns: Whether track was found and removed
    @discardableResult
    func remove(track: AudioTrack) -> Bool

    /// Move track from one position to another
    /// - Parameters:
    ///   - fromIndex: Source index
    ///   - toIndex: Destination index
    func move(from fromIndex: Int, to toIndex: Int)

    /// Clear all tracks from queue
    func clear()

    /// Clear history
    func clearHistory()

    // MARK: - Navigation

    /// Get the next track to play
    /// - Returns: Next track, respecting shuffle and repeat modes
    func next() -> AudioTrack?

    /// Get the previous track to play
    /// - Returns: Previous track, respecting shuffle and repeat modes
    func previous() -> AudioTrack?

    /// Set current track by index
    /// - Parameter index: Index to set as current
    /// - Returns: Whether the index was valid and set
    @discardableResult
    func setCurrentIndex(_ index: Int?) -> Bool

    /// Set current track by track reference
    /// - Parameter track: Track to set as current
    /// - Returns: Whether the track was found and set
    @discardableResult
    func setCurrentTrack(_ track: AudioTrack?) -> Bool

    // MARK: - Queue Manipulation

    /// Replace entire queue with new tracks
    /// - Parameters:
    ///   - tracks: New tracks for the queue
    ///   - startIndex: Index to start playing from
    func replaceQueue(with tracks: [AudioTrack], startIndex: Int?)

    /// Insert tracks at specific position
    /// - Parameters:
    ///   - tracks: Tracks to insert
    ///   - index: Position to insert at
    func insert(tracks: [AudioTrack], at index: Int)

    /// Shuffle the queue while preserving current track
    func shuffle()

    /// Restore original order (undo shuffle)
    func restoreOrder()

    // MARK: - Queue State

    /// Get the current queue state
    var queueState: QueueState { get }
}

// MARK: - Default Implementations

public extension AudioQueue {
    /// Convenience method to enqueue single track using array method
    func enqueue(track: AudioTrack) {
        enqueue(tracks: [track])
    }

    /// Convenience method to enqueue next single track using array method
    func enqueueNext(track: AudioTrack) {
        enqueueNext(tracks: [track])
    }

    /// Convenience method to enqueue later single track using array method
    func enqueueLater(track: AudioTrack) {
        enqueueLater(tracks: [track])
    }

    /// Check if queue is empty
    var isEmpty: Bool {
        tracks.isEmpty
    }

    /// Get queue size
    var count: Int {
        tracks.count
    }

    /// Get track at specific index safely
    func track(at index: Int) -> AudioTrack? {
        guard index >= 0, index < tracks.count else { return nil }
        return tracks[index]
    }

    /// Find index of specific track
    func index(of track: AudioTrack) -> Int? {
        tracks.firstIndex { $0.id == track.id }
    }
}

// MARK: - Queue Delegate Protocol

/// Delegate protocol for queue change notifications
@MainActor
public protocol AudioQueueDelegate: AnyObject, Sendable {
    /// Called when the queue tracks change
    /// - Parameters:
    ///   - queue: The audio queue
    ///   - tracks: New tracks array
    func audioQueue(_ queue: AudioQueue, didUpdateTracks tracks: [AudioTrack])

    /// Called when the current track changes
    /// - Parameters:
    ///   - queue: The audio queue
    ///   - track: New current track (nil if none)
    ///   - index: New current index (nil if none)
    func audioQueue(_ queue: AudioQueue, didChangeCurrentTrack track: AudioTrack?, at index: Int?)

    /// Called when shuffle mode changes
    /// - Parameters:
    ///   - queue: The audio queue
    ///   - shuffleMode: New shuffle mode
    func audioQueue(_ queue: AudioQueue, didChangeShuffleMode shuffleMode: QueueShuffleMode)

    /// Called when repeat mode changes
    /// - Parameters:
    ///   - queue: The audio queue
    ///   - repeatMode: New repeat mode
    func audioQueue(_ queue: AudioQueue, didChangeRepeatMode repeatMode: QueueRepeatMode)

    /// Called when a track is added to history
    /// - Parameters:
    ///   - queue: The audio queue
    ///   - track: Track added to history
    func audioQueue(_ queue: AudioQueue, didAddToHistory track: AudioTrack)

    /// Called when an error occurs in queue operations
    /// - Parameters:
    ///   - queue: The audio queue
    ///   - error: The error that occurred
    func audioQueue(_ queue: AudioQueue, didEncounterError error: AudioError)
}

// MARK: - Default Delegate Implementations

public extension AudioQueueDelegate {
    func audioQueue(_: AudioQueue, didUpdateTracks _: [AudioTrack]) {}
    func audioQueue(_: AudioQueue, didChangeCurrentTrack _: AudioTrack?, at _: Int?) {}
    func audioQueue(_: AudioQueue, didChangeShuffleMode _: QueueShuffleMode) {}
    func audioQueue(_: AudioQueue, didChangeRepeatMode _: QueueRepeatMode) {}
    func audioQueue(_: AudioQueue, didAddToHistory _: AudioTrack) {}
    func audioQueue(_: AudioQueue, didEncounterError _: AudioError) {}
}
