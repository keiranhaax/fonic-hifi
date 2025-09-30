//
//  QueueShuffleMode.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/25.
//

import Foundation

/// Enumeration of shuffle modes for the audio queue
public enum QueueShuffleMode: String, CaseIterable, Sendable {
    /// No shuffle - play in original order
    case off

    /// Simple random shuffle
    case random

    /// Smart shuffle that avoids artist/album repetition
    case smart

    // MARK: - Properties

    /// Human-readable description of the shuffle mode
    public var description: String {
        switch self {
        case .off:
            "No Shuffle"
        case .random:
            "Random Shuffle"
        case .smart:
            "Smart Shuffle"
        }
    }

    /// Short description for UI display
    public var shortDescription: String {
        switch self {
        case .off:
            "Off"
        case .random:
            "Random"
        case .smart:
            "Smart"
        }
    }

    /// Symbol name for UI icons (SF Symbols)
    public var symbolName: String {
        switch self {
        case .off:
            "shuffle"
        case .random:
            "shuffle.circle"
        case .smart:
            "shuffle.circle.fill"
        }
    }

    /// Whether this mode is considered active (not off)
    public var isActive: Bool {
        self != .off
    }

    /// Whether this mode requires smart logic
    public var requiresSmartLogic: Bool {
        self == .smart
    }

    // MARK: - Shuffle Generation

    /// Generate a shuffle sequence for the given tracks
    /// - Parameters:
    ///   - trackCount: Number of tracks to shuffle
    ///   - currentIndex: Current playing index (to preserve if needed)
    ///   - tracks: Track array for smart shuffle logic (optional)
    /// - Returns: Array of indices representing the shuffle order
    public func generateShuffleSequence(
        trackCount: Int,
        currentIndex: Int? = nil,
        tracks: [some TrackProtocol]? = nil,
    ) -> [Int] {
        guard trackCount > 0 else { return [] }

        switch self {
        case .off:
            return Array(0 ..< trackCount) // Original order

        case .random:
            return generateRandomShuffle(trackCount: trackCount, currentIndex: currentIndex)

        case .smart:
            if let tracks {
                return generateSmartShuffle(tracks: tracks, currentIndex: currentIndex)
            } else {
                // Fallback to random if no track data available
                return generateRandomShuffle(trackCount: trackCount, currentIndex: currentIndex)
            }
        }
    }

    /// Generate a simple random shuffle
    private func generateRandomShuffle(trackCount: Int, currentIndex: Int?) -> [Int] {
        var indices = Array(0 ..< trackCount)

        // Shuffle the array
        for i in stride(from: indices.count - 1, through: 1, by: -1) {
            let randomIndex = Int.random(in: 0 ... i)
            indices.swapAt(i, randomIndex)
        }

        // If there's a current track, try to keep it first
        if let currentIndex,
           let shuffledPosition = indices.firstIndex(of: currentIndex)
        {
            indices.swapAt(0, shuffledPosition)
        }

        return indices
    }

    /// Generate a smart shuffle that avoids artist/album clustering
    private func generateSmartShuffle(tracks: [some TrackProtocol], currentIndex: Int?) -> [Int] {
        let trackCount = tracks.count
        guard trackCount > 1 else { return Array(0 ..< trackCount) }

        var result: [Int] = []
        var remaining = Set(0 ..< trackCount)

        // Start with current track if available
        if let currentIndex, remaining.contains(currentIndex) {
            result.append(currentIndex)
            remaining.remove(currentIndex)
        }

        while !remaining.isEmpty {
            let candidates = remaining.filter { candidateIndex in
                isGoodNextChoice(
                    candidateIndex: candidateIndex,
                    after: result.last,
                    tracks: tracks,
                    remaining: remaining,
                )
            }

            let nextIndex: Int = if !candidates.isEmpty {
                // Choose randomly from good candidates
                candidates.randomElement()!
            } else {
                // No good candidates, pick any remaining
                remaining.randomElement()!
            }

            result.append(nextIndex)
            remaining.remove(nextIndex)
        }

        return result
    }

    /// Check if a track is a good choice to play next in smart shuffle
    private func isGoodNextChoice(
        candidateIndex: Int,
        after lastIndex: Int?,
        tracks: [some TrackProtocol],
        remaining: Set<Int>,
    ) -> Bool {
        guard let lastIndex else { return true }

        let lastTrack = tracks[lastIndex]
        let candidateTrack = tracks[candidateIndex]

        // Avoid same artist consecutively
        if lastTrack.artist == candidateTrack.artist, !lastTrack.artist.isEmpty {
            // Allow if it's the only artist left
            let otherArtistExists = remaining.contains { index in
                tracks[index].artist != candidateTrack.artist
            }
            if otherArtistExists { return false }
        }

        // Avoid same album consecutively
        if lastTrack.album == candidateTrack.album, !lastTrack.album.isEmpty {
            // Allow if it's the only album left
            let otherAlbumExists = remaining.contains { index in
                tracks[index].album != candidateTrack.album
            }
            if otherAlbumExists { return false }
        }

        return true
    }

    // MARK: - Cycling

    /// Get the next shuffle mode in cycle (for UI toggling)
    public var next: QueueShuffleMode {
        switch self {
        case .off:
            .random
        case .random:
            .smart
        case .smart:
            .off
        }
    }

    /// Get the previous shuffle mode in cycle (for UI toggling)
    public var previous: QueueShuffleMode {
        switch self {
        case .off:
            .smart
        case .random:
            .off
        case .smart:
            .random
        }
    }

    // MARK: - Navigation Logic

    /// Determines the next index in the shuffle sequence
    /// - Parameters:
    ///   - currentIndex: Current position in queue
    ///   - shuffleSequence: The shuffle sequence array
    ///   - repeatMode: Current repeat mode
    /// - Returns: Next index to play, nil if no next
    public func nextIndex(
        currentIndex: Int?,
        shuffleSequence: [Int],
        repeatMode: QueueRepeatMode,
    ) -> Int? {
        guard !shuffleSequence.isEmpty else { return nil }

        if !isActive {
            // Not shuffled, use regular next logic
            return repeatMode.nextIndex(
                from: currentIndex,
                queueCount: shuffleSequence.count,
            )
        }

        guard let currentIndex else {
            return shuffleSequence.first
        }

        // Find current position in shuffle sequence
        guard let currentPosition = shuffleSequence.firstIndex(of: currentIndex) else {
            return shuffleSequence.first
        }

        let nextPosition = currentPosition + 1

        if nextPosition < shuffleSequence.count {
            return shuffleSequence[nextPosition]
        } else {
            // End of shuffle sequence
            switch repeatMode {
            case .none:
                return nil
            case .all:
                return shuffleSequence.first // Restart shuffle
            case .one:
                return currentIndex // Stay on same track
            }
        }
    }

    /// Determines the previous index in the shuffle sequence
    /// - Parameters:
    ///   - currentIndex: Current position in queue
    ///   - shuffleSequence: The shuffle sequence array
    ///   - repeatMode: Current repeat mode
    /// - Returns: Previous index to play, nil if no previous
    public func previousIndex(
        currentIndex: Int?,
        shuffleSequence: [Int],
        repeatMode: QueueRepeatMode,
    ) -> Int? {
        guard !shuffleSequence.isEmpty else { return nil }

        if !isActive {
            // Not shuffled, use regular previous logic
            return repeatMode.previousIndex(
                from: currentIndex,
                queueCount: shuffleSequence.count,
            )
        }

        guard let currentIndex else { return nil }

        // Find current position in shuffle sequence
        guard let currentPosition = shuffleSequence.firstIndex(of: currentIndex) else {
            return nil
        }

        let previousPosition = currentPosition - 1

        if previousPosition >= 0 {
            return shuffleSequence[previousPosition]
        } else {
            // Beginning of shuffle sequence
            switch repeatMode {
            case .none:
                return nil
            case .all:
                return shuffleSequence.last // Go to end of shuffle
            case .one:
                return currentIndex // Stay on same track
            }
        }
    }
}

// MARK: - Codable

extension QueueShuffleMode: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        guard let mode = QueueShuffleMode(rawValue: rawValue) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid QueueShuffleMode: \(rawValue)",
                ),
            )
        }

        self = mode
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - Equatable & Hashable

extension QueueShuffleMode: Equatable, Hashable {
    public static func == (lhs: QueueShuffleMode, rhs: QueueShuffleMode) -> Bool {
        lhs.rawValue == rhs.rawValue
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}
