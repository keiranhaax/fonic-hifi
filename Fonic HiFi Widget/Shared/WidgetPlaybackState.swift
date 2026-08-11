//
//  WidgetPlaybackState.swift
//  Fonic HiFi Widget
//
//  Standalone copy for widget extension (no main app dependencies)
//

import Foundation

/// Lightweight playback state for widget consumption
/// Designed to be compact for UserDefaults storage
public struct WidgetPlaybackState: Codable, Sendable, Hashable {
    /// Whether audio is currently playing
    public let isPlaying: Bool

    /// Current playback time in seconds
    public let currentTime: TimeInterval

    /// Total duration in seconds
    public let duration: TimeInterval

    /// Whether shuffle mode is enabled
    public let shuffleEnabled: Bool

    /// Repeat mode as string ("none", "one", "all")
    public let repeatMode: String

    /// Whether there's a next track available
    public let hasNext: Bool

    /// Whether there's a previous track available
    public let hasPrevious: Bool

    /// Timestamp when this state was captured
    public let timestamp: Date

    /// Playback rate for Live Activity interpolation (1.0 = normal speed)
    public let playbackRate: Float

    // MARK: - Initialization

    public init(
        isPlaying: Bool,
        currentTime: TimeInterval,
        duration: TimeInterval,
        shuffleEnabled: Bool,
        repeatMode: String,
        hasNext: Bool,
        hasPrevious: Bool,
        timestamp: Date = Date(),
        playbackRate: Float = 1.0
    ) {
        self.isPlaying = isPlaying
        self.currentTime = currentTime
        self.duration = duration
        self.shuffleEnabled = shuffleEnabled
        self.repeatMode = repeatMode
        self.hasNext = hasNext
        self.hasPrevious = hasPrevious
        self.timestamp = timestamp
        self.playbackRate = playbackRate
    }

    // MARK: - Computed Properties

    /// Progress as a value from 0.0 to 1.0
    public var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(projectedCurrentTime / duration, 0), 1)
    }

    /// Remaining time in seconds
    public var remainingTime: TimeInterval {
        max(duration - projectedCurrentTime, 0)
    }

    /// Current position projected from the last app update while playing.
    /// A stale snapshot never advances after the app has been force-quit.
    public var projectedCurrentTime: TimeInterval {
        guard duration > 0 else { return currentTime }
        guard isPlaying, !isStale else { return min(max(currentTime, 0), duration) }
        let elapsed = max(Date().timeIntervalSince(timestamp), 0) * TimeInterval(playbackRate)
        return min(max(currentTime + elapsed, 0), duration)
    }

    /// Whether the track is at the beginning
    public var isAtBeginning: Bool {
        currentTime < 1.0
    }

    /// Whether the track is near the end
    public var isNearEnd: Bool {
        remainingTime < 5.0
    }

    /// Age of this state snapshot
    public var age: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }

    /// Whether this state is stale (older than 5 minutes)
    public var isStale: Bool {
        age > 300
    }

    // MARK: - Static

    /// Empty/idle state
    public static let idle = WidgetPlaybackState(
        isPlaying: false,
        currentTime: 0,
        duration: 0,
        shuffleEnabled: false,
        repeatMode: "none",
        hasNext: false,
        hasPrevious: false
    )
}

// MARK: - Persistence

public extension WidgetPlaybackState {
    /// Save to App Group UserDefaults
    func save() {
        guard let defaults = UserDefaults.appGroup else { return }
        save(to: defaults)
    }

    /// Save to an explicitly provided store.
    func save(to defaults: UserDefaults) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(self) {
            defaults.set(data, forKey: WidgetConstants.Keys.playbackState)
            defaults.set(Date(), forKey: WidgetConstants.Keys.lastUpdated)
        }
    }

    /// Load from App Group UserDefaults
    static func load() -> WidgetPlaybackState? {
        guard let defaults = UserDefaults.appGroup else { return nil }
        return load(from: defaults)
    }

    /// Load from an explicitly provided store.
    static func load(from defaults: UserDefaults) -> WidgetPlaybackState? {
        guard let data = defaults.data(forKey: WidgetConstants.Keys.playbackState) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try? decoder.decode(WidgetPlaybackState.self, from: data)
    }

    /// Load or return idle state
    static func loadOrIdle() -> WidgetPlaybackState {
        load() ?? .idle
    }

    /// Load from an explicitly provided store or return idle state.
    static func loadOrIdle(from defaults: UserDefaults) -> WidgetPlaybackState {
        load(from: defaults) ?? .idle
    }
}
