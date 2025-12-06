//
//  QueueState.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/25.
//

import Foundation
import OSLog

/// Immutable snapshot of the audio queue state
public struct QueueState: Sendable, Equatable {
    // MARK: - Properties

    /// All tracks in the queue
    public let tracks: [AudioTrack]

    /// Current playing index
    public let currentIndex: Int?

    /// Current track being played
    public let currentTrack: AudioTrack?

    /// Shuffle mode setting
    public let shuffleMode: QueueShuffleMode

    /// Repeat mode setting
    public let repeatMode: QueueRepeatMode

    /// Whether there is a next track available
    public let hasNext: Bool

    /// Whether there is a previous track available
    public let hasPrevious: Bool

    /// Playback history
    public let history: [AudioTrack]

    /// Current shuffle sequence (if shuffled)
    public let shuffleSequence: [Int]?

    /// Timestamp when this state was created
    public let timestamp: Date

    /// Last playback position in seconds (for resume functionality)
    public let lastPlaybackPosition: TimeInterval

    // MARK: - Computed Properties

    /// Whether the queue is empty
    public var isEmpty: Bool {
        tracks.isEmpty
    }

    /// Number of tracks in the queue
    public var count: Int {
        tracks.count
    }

    /// Whether shuffle is currently active
    public var isShuffled: Bool {
        shuffleMode.isActive
    }

    /// Whether repeat is currently active
    public var isRepeating: Bool {
        repeatMode.isInfinite
    }

    /// Remaining tracks in queue after current
    public var remainingTracks: [AudioTrack] {
        guard let currentIndex else { return tracks }
        guard currentIndex < tracks.count - 1 else { return [] }
        return Array(tracks[(currentIndex + 1)...])
    }

    /// Number of remaining tracks
    public var remainingCount: Int {
        remainingTracks.count
    }

    /// Total duration of all tracks in queue
    public var totalDuration: TimeInterval {
        tracks.reduce(0) { $0 + $1.duration }
    }

    /// Duration of remaining tracks (including current if playing)
    public var remainingDuration: TimeInterval {
        guard let currentIndex else { return totalDuration }
        let remaining = tracks[currentIndex...]
        return remaining.reduce(0) { $0 + $1.duration }
    }

    /// Position in queue (1-based for display)
    public var position: Int? {
        guard let currentIndex else { return nil }
        return currentIndex + 1
    }

    /// Progress through queue (0.0 to 1.0)
    public var progress: Double {
        guard !tracks.isEmpty, let currentIndex else { return 0.0 }
        return Double(currentIndex) / Double(tracks.count)
    }

    // MARK: - Initialization

    public init(
        tracks: [AudioTrack] = [],
        currentIndex: Int? = nil,
        shuffleMode: QueueShuffleMode = .off,
        repeatMode: QueueRepeatMode = .none,
        hasNext: Bool = false,
        hasPrevious: Bool = false,
        history: [AudioTrack] = [],
        shuffleSequence: [Int]? = nil,
        timestamp: Date = Date(),
        lastPlaybackPosition: TimeInterval = 0,
    ) {
        self.tracks = tracks
        self.currentIndex = currentIndex
        currentTrack = currentIndex.flatMap { index in
            index >= 0 && index < tracks.count ? tracks[index] : nil
        }
        self.shuffleMode = shuffleMode
        self.repeatMode = repeatMode
        self.hasNext = hasNext
        self.hasPrevious = hasPrevious
        self.history = history
        self.shuffleSequence = shuffleSequence
        self.timestamp = timestamp
        self.lastPlaybackPosition = lastPlaybackPosition
    }

    // MARK: - Track Access

    /// Get track at specific index safely
    /// - Parameter index: Index to retrieve
    /// - Returns: Track at index, nil if invalid
    public func track(at index: Int) -> AudioTrack? {
        guard index >= 0, index < tracks.count else { return nil }
        return tracks[index]
    }

    /// Find index of specific track
    /// - Parameter track: Track to find
    /// - Returns: Index of track, nil if not found
    public func index(of track: AudioTrack) -> Int? {
        tracks.firstIndex { $0.id == track.id }
    }

    /// Get tracks in shuffle order (if shuffled)
    public var shuffledTracks: [AudioTrack] {
        guard let shuffleSequence else { return tracks }
        return shuffleSequence.compactMap { index in
            track(at: index)
        }
    }

    /// Get the next track that would play
    public var nextTrack: AudioTrack? {
        guard hasNext else { return nil }

        if shuffleMode.isActive, let shuffleSequence {
            let nextIndex = shuffleMode.nextIndex(
                currentIndex: currentIndex,
                shuffleSequence: shuffleSequence,
                repeatMode: repeatMode,
            )
            return nextIndex.flatMap { track(at: $0) }
        } else {
            let nextIndex = repeatMode.nextIndex(
                from: currentIndex,
                queueCount: tracks.count,
            )
            return nextIndex.flatMap { track(at: $0) }
        }
    }

    /// Get the previous track that would play
    public var previousTrack: AudioTrack? {
        guard hasPrevious else { return nil }

        if shuffleMode.isActive, let shuffleSequence {
            let prevIndex = shuffleMode.previousIndex(
                currentIndex: currentIndex,
                shuffleSequence: shuffleSequence,
                repeatMode: repeatMode,
            )
            return prevIndex.flatMap { track(at: $0) }
        } else {
            let prevIndex = repeatMode.previousIndex(
                from: currentIndex,
                queueCount: tracks.count,
            )
            return prevIndex.flatMap { track(at: $0) }
        }
    }

    // MARK: - Queue Information

    /// Get formatted string for queue position
    public var positionText: String {
        guard let position else { return "-- of \(count)" }
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
        formatDuration(totalDuration)
    }

    /// Get formatted string for remaining duration
    public var remainingDurationText: String {
        formatDuration(remainingDuration)
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
        lhs.tracks.map(\.id) == rhs.tracks.map(\.id) &&
            lhs.currentIndex == rhs.currentIndex &&
            lhs.shuffleMode == rhs.shuffleMode &&
            lhs.repeatMode == rhs.repeatMode &&
            lhs.hasNext == rhs.hasNext &&
            lhs.hasPrevious == rhs.hasPrevious &&
            lhs.history.map(\.id) == rhs.history.map(\.id) &&
            lhs.shuffleSequence == rhs.shuffleSequence &&
            abs(lhs.lastPlaybackPosition - rhs.lastPlaybackPosition) < 0.001
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
        case lastPlaybackPosition
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let tracks = try container.decode([AudioTrack].self, forKey: .tracks)
        let currentIndex = try container.decodeIfPresent(Int.self, forKey: .currentIndex)

        self.tracks = tracks
        self.currentIndex = currentIndex
        shuffleMode = try container.decode(QueueShuffleMode.self, forKey: .shuffleMode)
        repeatMode = try container.decode(QueueRepeatMode.self, forKey: .repeatMode)
        hasNext = try container.decode(Bool.self, forKey: .hasNext)
        hasPrevious = try container.decode(Bool.self, forKey: .hasPrevious)
        history = try container.decode([AudioTrack].self, forKey: .history)
        shuffleSequence = try container.decodeIfPresent([Int].self, forKey: .shuffleSequence)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        lastPlaybackPosition = try container.decodeIfPresent(TimeInterval.self, forKey: .lastPlaybackPosition) ?? 0

        // Compute current track
        currentTrack = currentIndex.flatMap { index in
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
        try container.encode(lastPlaybackPosition, forKey: .lastPlaybackPosition)
    }
}

// MARK: - Persistence

public extension QueueState {
    private static let logger = Log.logger(.audioQueueState)
    /// UserDefaults key for storing queue state
    private static let persistenceKey = "com.fonichifi.queue.state"

    /// Save queue state to UserDefaults
    func save() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        UserDefaults.standard.set(data, forKey: Self.persistenceKey)
    }

    /// Load queue state from UserDefaults
    /// - Returns: Saved queue state, or nil if not found or invalid
    static func load() -> QueueState? {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let state = try decoder.decode(QueueState.self, from: data)
            // Validate that the state is still recent (within 24 hours)
            if abs(state.timestamp.timeIntervalSinceNow) < 86400 {
                return state
            }
        } catch {
            logger.error(
                "Failed to decode queue state: \(error.localizedDescription, privacy: .public)",
            )
        }

        return nil
    }

    /// Clear saved queue state
    static func clear() {
        UserDefaults.standard.removeObject(forKey: persistenceKey)
    }

    /// Create a persistence-safe version of the queue state
    /// This excludes tracks that may no longer be available
    func validateForPersistence() -> QueueState {
        // Filter out tracks that no longer exist on disk
        let validTracks = tracks.filter { track in
            FileManager.default.fileExists(atPath: track.url.path)
        }

        // Adjust current index if needed
        let validCurrentIndex: Int? = if let currentTrack,
                                         let newIndex = validTracks.firstIndex(where: { $0.id == currentTrack.id }) {
            newIndex
        } else {
            nil
        }

        // Adjust shuffle sequence if needed
        let validShuffleSequence: [Int]? = if let shuffleSequence {
            shuffleSequence.filter { $0 < validTracks.count }
        } else {
            nil
        }

        let hasNext = { () -> Bool in
            guard let index = validCurrentIndex else { return false }
            return index < validTracks.count - 1
        }()

        let hasPrevious = { () -> Bool in
            guard let index = validCurrentIndex else { return false }
            return index > 0
        }()

        return QueueState(
            tracks: validTracks,
            currentIndex: validCurrentIndex,
            shuffleMode: shuffleMode,
            repeatMode: repeatMode,
            hasNext: hasNext,
            hasPrevious: hasPrevious,
            history: history.filter { track in
                FileManager.default.fileExists(atPath: track.url.path)
            },
            shuffleSequence: validShuffleSequence,
            timestamp: Date(),
        )
    }
}

// MARK: - Debug Description

extension QueueState: CustomDebugStringConvertible {
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
