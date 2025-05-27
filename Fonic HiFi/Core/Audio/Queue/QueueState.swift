//
//  QueueState.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/25.
//

import Foundation

/// Immutable snapshot of the audio queue state
public struct QueueState: Sendable, Equatable {
    
    // MARK: - Properties
    
    /// All tracks in the queue
    public let tracks: [Track]
    
    /// Current playing index
    public let currentIndex: Int?
    
    /// Current track being played
    public let currentTrack: Track?
    
    /// Shuffle mode setting
    public let shuffleMode: QueueShuffleMode
    
    /// Repeat mode setting
    public let repeatMode: QueueRepeatMode
    
    /// Whether there is a next track available
    public let hasNext: Bool
    
    /// Whether there is a previous track available
    public let hasPrevious: Bool
    
    /// Playback history
    public let history: [Track]
    
    /// Current shuffle sequence (if shuffled)
    public let shuffleSequence: [Int]?
    
    /// Timestamp when this state was created
    public let timestamp: Date
    
    // MARK: - Computed Properties
    
    /// Whether the queue is empty
    public var isEmpty: Bool {
        return tracks.isEmpty
    }
    
    /// Number of tracks in the queue
    public var count: Int {
        return tracks.count
    }
    
    /// Whether shuffle is currently active
    public var isShuffled: Bool {
        return shuffleMode.isActive
    }
    
    /// Whether repeat is currently active
    public var isRepeating: Bool {
        return repeatMode.isInfinite
    }
    
    /// Remaining tracks in queue after current
    public var remainingTracks: [Track] {
        guard let currentIndex = currentIndex else { return tracks }
        guard currentIndex < tracks.count - 1 else { return [] }
        return Array(tracks[(currentIndex + 1)...])
    }
    
    /// Number of remaining tracks
    public var remainingCount: Int {
        return remainingTracks.count
    }
    
    /// Total duration of all tracks in queue
    public var totalDuration: TimeInterval {
        return tracks.reduce(0) { $0 + $1.duration }
    }
    
    /// Duration of remaining tracks (including current if playing)
    public var remainingDuration: TimeInterval {
        guard let currentIndex = currentIndex else { return totalDuration }
        let remaining = tracks[currentIndex...]
        return remaining.reduce(0) { $0 + $1.duration }
    }
    
    /// Position in queue (1-based for display)
    public var position: Int? {
        guard let currentIndex = currentIndex else { return nil }
        return currentIndex + 1
    }
    
    /// Progress through queue (0.0 to 1.0)
    public var progress: Double {
        guard !tracks.isEmpty, let currentIndex = currentIndex else { return 0.0 }
        return Double(currentIndex) / Double(tracks.count)
    }
    
    // MARK: - Initialization
    
    public init(
        tracks: [Track] = [],
        currentIndex: Int? = nil,
        shuffleMode: QueueShuffleMode = .off,
        repeatMode: QueueRepeatMode = .none,
        hasNext: Bool = false,
        hasPrevious: Bool = false,
        history: [Track] = [],
        shuffleSequence: [Int]? = nil,
        timestamp: Date = Date()
    ) {
        self.tracks = tracks
        self.currentIndex = currentIndex
        self.currentTrack = currentIndex.flatMap { index in
            index >= 0 && index < tracks.count ? tracks[index] : nil
        }
        self.shuffleMode = shuffleMode
        self.repeatMode = repeatMode
        self.hasNext = hasNext
        self.hasPrevious = hasPrevious
        self.history = history
        self.shuffleSequence = shuffleSequence
        self.timestamp = timestamp
    }
    
    // MARK: - Track Access
    
    /// Get track at specific index safely
    /// - Parameter index: Index to retrieve
    /// - Returns: Track at index, nil if invalid
    public func track(at index: Int) -> Track? {
        guard index >= 0 && index < tracks.count else { return nil }
        return tracks[index]
    }
    
    /// Find index of specific track
    /// - Parameter track: Track to find
    /// - Returns: Index of track, nil if not found
    public func index(of track: Track) -> Int? {
        return tracks.firstIndex { $0.id == track.id }
    }
    
    /// Get tracks in shuffle order (if shuffled)
    public var shuffledTracks: [Track] {
        guard let shuffleSequence = shuffleSequence else { return tracks }
        return shuffleSequence.compactMap { index in
            track(at: index)
        }
    }
    
    /// Get the next track that would play
    public var nextTrack: Track? {
        guard hasNext else { return nil }
        
        if shuffleMode.isActive, let shuffleSequence = shuffleSequence {
            let nextIndex = shuffleMode.nextIndex(
                currentIndex: currentIndex,
                shuffleSequence: shuffleSequence,
                repeatMode: repeatMode
            )
            return nextIndex.flatMap { track(at: $0) }
        } else {
            let nextIndex = repeatMode.nextIndex(
                from: currentIndex,
                queueCount: tracks.count
            )
            return nextIndex.flatMap { track(at: $0) }
        }
    }
    
    /// Get the previous track that would play
    public var previousTrack: Track? {
        guard hasPrevious else { return nil }
        
        if shuffleMode.isActive, let shuffleSequence = shuffleSequence {
            let prevIndex = shuffleMode.previousIndex(
                currentIndex: currentIndex,
                shuffleSequence: shuffleSequence,
                repeatMode: repeatMode
            )
            return prevIndex.flatMap { track(at: $0) }
        } else {
            let prevIndex = repeatMode.previousIndex(
                from: currentIndex,
                queueCount: tracks.count
            )
            return prevIndex.flatMap { track(at: $0) }
        }
    }
    
    // MARK: - Queue Information
    
    /// Get formatted string for queue position
    public var positionText: String {
        guard let position = position else { return "-- of \(count)" }
        return "\(position) of \(count)"
    }
    
    /// Get formatted string for remaining tracks
    public var remainingText: String {
        let remaining = remainingCount
        if remaining == 0 {
            return "Last track"
        } else if remaining == 1 {
            return "1 track remaining"
        } else {
            return "\(remaining) tracks remaining"
        }
    }
    
    /// Get formatted string for total duration
    public var durationText: String {
        return formatDuration(totalDuration)
    }
    
    /// Get formatted string for remaining duration
    public var remainingDurationText: String {
        return formatDuration(remainingDuration)
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: QueueState, rhs: QueueState) -> Bool {
        return lhs.tracks.map(\.id) == rhs.tracks.map(\.id) &&
               lhs.currentIndex == rhs.currentIndex &&
               lhs.shuffleMode == rhs.shuffleMode &&
               lhs.repeatMode == rhs.repeatMode &&
               lhs.hasNext == rhs.hasNext &&
               lhs.hasPrevious == rhs.hasPrevious &&
               lhs.history.map(\.id) == rhs.history.map(\.id) &&
               lhs.shuffleSequence == rhs.shuffleSequence
    }
}

// MARK: - Codable

extension QueueState: Codable {
    
    private enum CodingKeys: String, CodingKey {
        case tracks
        case currentIndex
        case shuffleMode
        case repeatMode
        case hasNext
        case hasPrevious
        case history
        case shuffleSequence
        case timestamp
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.tracks = try container.decode([Track].self, forKey: .tracks)
        self.currentIndex = try container.decodeIfPresent(Int.self, forKey: .currentIndex)
        self.shuffleMode = try container.decode(QueueShuffleMode.self, forKey: .shuffleMode)
        self.repeatMode = try container.decode(QueueRepeatMode.self, forKey: .repeatMode)
        self.hasNext = try container.decode(Bool.self, forKey: .hasNext)
        self.hasPrevious = try container.decode(Bool.self, forKey: .hasPrevious)
        self.history = try container.decode([Track].self, forKey: .history)
        self.shuffleSequence = try container.decodeIfPresent([Int].self, forKey: .shuffleSequence)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        // Computed property
        self.currentTrack = currentIndex.flatMap { index in
            index >= 0 && index < tracks.count ? tracks[index] : nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(tracks, forKey: .tracks)
        try container.encodeIfPresent(currentIndex, forKey: .currentIndex)
        try container.encode(shuffleMode, forKey: .shuffleMode)
        try container.encode(repeatMode, forKey: .repeatMode)
        try container.encode(hasNext, forKey: .hasNext)
        try container.encode(hasPrevious, forKey: .hasPrevious)
        try container.encode(history, forKey: .history)
        try container.encodeIfPresent(shuffleSequence, forKey: .shuffleSequence)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

// MARK: - Debug Description

extension QueueState: CustomDebugStringProvider {
    
    public var debugDescription: String {
        let currentTrackTitle = currentTrack?.title ?? "None"
        let shuffleStatus = shuffleMode.isActive ? "On (\(shuffleMode.shortDescription))" : "Off"
        let repeatStatus = repeatMode.isInfinite ? "On (\(repeatMode.shortDescription))" : "Off"
        
        return """
        QueueState(
          tracks: \(count),
          current: \(currentIndex?.description ?? "nil") ("\(currentTrackTitle)"),
          shuffle: \(shuffleStatus),
          repeat: \(repeatStatus),
          hasNext: \(hasNext),
          hasPrevious: \(hasPrevious),
          history: \(history.count)
        )
        """
    }
} 