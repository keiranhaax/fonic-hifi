//
//  AudioQueue.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import Foundation

/// Modes for shuffling queue playback
public enum ShuffleMode: String, CaseIterable, Sendable {
    case off = "off"
    case on = "on"
}

/// Modes for repeating queue playback
public enum RepeatMode: String, CaseIterable, Sendable {
    case off = "off"
    case all = "all"
    case one = "one"
}

/// Protocol defining the interface for audio queue management
@MainActor
public protocol AudioQueue: Sendable {
    
    // MARK: - Properties
    
    /// All tracks currently in the queue
    var tracks: [Track] { get async }
    
    /// Index of the currently playing track
    var currentIndex: Int? { get async }
    
    /// Currently playing track
    var currentTrack: Track? { get async }
    
    /// Number of tracks in the queue
    var count: Int { get async }
    
    /// Current shuffle mode
    var shuffleMode: ShuffleMode { get async }
    
    /// Current repeat mode
    var repeatMode: RepeatMode { get async }
    
    // MARK: - Queue Management
    
    /// Add a single track to the queue
    /// - Parameter track: Track to add
    func enqueue(_ track: Track) async
    
    /// Add multiple tracks to the queue
    /// - Parameter tracks: Array of tracks to add
    func enqueue(_ tracks: [Track]) async
    
    /// Insert a track at a specific position
    /// - Parameters:
    ///   - track: Track to insert
    ///   - index: Position to insert at
    func insert(_ track: Track, at index: Int) async
    
    /// Remove a track from the queue
    /// - Parameter index: Index of track to remove
    /// - Returns: The removed track, if any
    @discardableResult
    func dequeue(at index: Int) async -> Track?
    
    /// Move a track from one position to another
    /// - Parameters:
    ///   - sourceIndex: Current position
    ///   - destinationIndex: Target position
    func move(from sourceIndex: Int, to destinationIndex: Int) async
    
    /// Clear all tracks from the queue
    func clear() async
    
    // MARK: - Playback Navigation
    
    /// Get the next track based on current position and repeat/shuffle settings
    /// - Returns: Next track and its index, or nil if none
    func next() async -> (track: Track, index: Int)?
    
    /// Get the previous track
    /// - Returns: Previous track and its index, or nil if none
    func previous() async -> (track: Track, index: Int)?
    
    /// Jump to a specific track in the queue
    /// - Parameter index: Index to jump to
    /// - Returns: The track at that index
    func jump(to index: Int) async -> Track?
    
    // MARK: - Playback Modes
    
    /// Set shuffle mode
    /// - Parameter mode: New shuffle mode
    func setShuffleMode(_ mode: ShuffleMode) async
    
    /// Set repeat mode
    /// - Parameter mode: New repeat mode
    func setRepeatMode(_ mode: RepeatMode) async
    
    // MARK: - Queue Manipulation
    
    /// Shuffle the current queue (maintains current track position)
    func shuffle() async
    
    /// Sort the queue by a given criteria
    /// - Parameter sortBy: Sort criteria
    func sort(by sortBy: TrackSortCriteria) async
}

/// Criteria for sorting tracks in the queue
public enum TrackSortCriteria: String, CaseIterable, Sendable {
    case title = "title"
    case artist = "artist"
    case album = "album"
    case duration = "duration"
    case dateAdded = "dateAdded"
    case trackNumber = "trackNumber"
}