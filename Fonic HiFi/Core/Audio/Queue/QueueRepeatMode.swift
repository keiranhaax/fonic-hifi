//
//  QueueRepeatMode.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/25.
//

import Foundation

/// Enumeration of repeat modes for the audio queue
public enum QueueRepeatMode: String, CaseIterable, Sendable {
    
    /// No repeat - stop at end of queue
    case none = "none"
    
    /// Repeat the entire queue
    case all = "all"
    
    /// Repeat only the current track
    case one = "one"
    
    // MARK: - Properties
    
    /// Human-readable description of the repeat mode
    public var description: String {
        switch self {
        case .none:
            return "No Repeat"
        case .all:
            return "Repeat All"
        case .one:
            return "Repeat One"
        }
    }
    
    /// Short description for UI display
    public var shortDescription: String {
        switch self {
        case .none:
            return "Off"
        case .all:
            return "All"
        case .one:
            return "One"
        }
    }
    
    /// Symbol name for UI icons (SF Symbols)
    public var symbolName: String {
        switch self {
        case .none:
            return "repeat"
        case .all:
            return "repeat.circle"
        case .one:
            return "repeat.1.circle"
        }
    }
    
    /// Whether this mode causes infinite playback
    public var isInfinite: Bool {
        switch self {
        case .none:
            return false
        case .all, .one:
            return true
        }
    }
    
    // MARK: - Navigation Logic
    
    /// Determines if there should be a next track given current state
    /// - Parameters:
    ///   - currentIndex: Current track index
    ///   - queueCount: Total number of tracks in queue
    ///   - isShuffled: Whether queue is shuffled
    /// - Returns: Whether there is a next track
    public func hasNext(currentIndex: Int?, queueCount: Int, isShuffled: Bool) -> Bool {
        guard queueCount > 0 else { return false }
        guard let currentIndex = currentIndex else { return queueCount > 0 }
        
        switch self {
        case .none:
            return currentIndex < queueCount - 1
        case .all:
            return true // Always has next in repeat all mode
        case .one:
            return true // Current track repeats infinitely
        }
    }
    
    /// Determines if there should be a previous track given current state
    /// - Parameters:
    ///   - currentIndex: Current track index
    ///   - queueCount: Total number of tracks in queue
    ///   - isShuffled: Whether queue is shuffled
    /// - Returns: Whether there is a previous track
    public func hasPrevious(currentIndex: Int?, queueCount: Int, isShuffled: Bool) -> Bool {
        guard queueCount > 0 else { return false }
        guard let currentIndex = currentIndex else { return false }
        
        switch self {
        case .none:
            return currentIndex > 0
        case .all:
            return true // Always has previous in repeat all mode
        case .one:
            return true // Current track repeats infinitely
        }
    }
    
    /// Calculates the next index to play
    /// - Parameters:
    ///   - currentIndex: Current track index
    ///   - queueCount: Total number of tracks in queue
    ///   - shuffleSequence: Shuffle sequence if shuffled (nil if not shuffled)
    /// - Returns: Next index to play, nil if no next track
    public func nextIndex(
        from currentIndex: Int?,
        queueCount: Int,
        shuffleSequence: [Int]? = nil
    ) -> Int? {
        guard queueCount > 0 else { return nil }
        
        switch self {
        case .none:
            guard let currentIndex = currentIndex else { return 0 }
            let nextIndex = currentIndex + 1
            return nextIndex < queueCount ? nextIndex : nil
            
        case .all:
            guard let currentIndex = currentIndex else { return 0 }
            let nextIndex = currentIndex + 1
            return nextIndex < queueCount ? nextIndex : 0 // Wrap to beginning
            
        case .one:
            return currentIndex // Stay on same track
        }
    }
    
    /// Calculates the previous index to play
    /// - Parameters:
    ///   - currentIndex: Current track index
    ///   - queueCount: Total number of tracks in queue
    ///   - shuffleSequence: Shuffle sequence if shuffled (nil if not shuffled)
    /// - Returns: Previous index to play, nil if no previous track
    public func previousIndex(
        from currentIndex: Int?,
        queueCount: Int,
        shuffleSequence: [Int]? = nil
    ) -> Int? {
        guard queueCount > 0 else { return nil }
        guard let currentIndex = currentIndex else { return nil }
        
        switch self {
        case .none:
            let previousIndex = currentIndex - 1
            return previousIndex >= 0 ? previousIndex : nil
            
        case .all:
            let previousIndex = currentIndex - 1
            return previousIndex >= 0 ? previousIndex : queueCount - 1 // Wrap to end
            
        case .one:
            return currentIndex // Stay on same track
        }
    }
    
    // MARK: - Cycling
    
    /// Get the next repeat mode in cycle (for UI toggling)
    public var next: QueueRepeatMode {
        switch self {
        case .none:
            return .all
        case .all:
            return .one
        case .one:
            return .none
        }
    }
    
    /// Get the previous repeat mode in cycle (for UI toggling)
    public var previous: QueueRepeatMode {
        switch self {
        case .none:
            return .one
        case .all:
            return .none
        case .one:
            return .all
        }
    }
}

// MARK: - Codable

extension QueueRepeatMode: Codable {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        guard let mode = QueueRepeatMode(rawValue: rawValue) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid QueueRepeatMode: \(rawValue)"
                )
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

extension QueueRepeatMode: Equatable, Hashable {
    
    public static func == (lhs: QueueRepeatMode, rhs: QueueRepeatMode) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
} 