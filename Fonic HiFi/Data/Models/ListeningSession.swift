// Fonic HiFi/Data/Models/ListeningSession.swift
import Foundation
import SwiftData

/// Records a single listening session for a track
@Model
public final class ListeningSession {
    /// Unique identifier
    public var id: UUID

    /// The track that was played (stored as UUID for cross-actor safety)
    public var trackId: UUID

    /// When the session started
    public var startedAt: Date

    /// When the session ended (nil if still playing)
    public var endedAt: Date?

    /// Total seconds of audio listened
    public var durationListened: TimeInterval

    /// Total duration of the track in seconds
    public var trackDuration: TimeInterval

    /// Percentage of track completed (0.0-1.0)
    public var completionPercentage: Double

    /// Whether user manually skipped
    public var wasSkipped: Bool

    /// Whether track played to natural completion
    public var wasCompleted: Bool

    /// Hour of day (0-23) for time-based patterns
    public var hourOfDay: Int

    /// Day of week (1=Sunday, 7=Saturday) for weekly patterns
    public var dayOfWeek: Int

    public init(
        trackId: UUID,
        startedAt: Date,
        durationListened: TimeInterval,
        trackDuration: TimeInterval,
        completionPercentage: Double,
        wasSkipped: Bool,
        wasCompleted: Bool
    ) {
        self.id = UUID()
        self.trackId = trackId
        self.startedAt = startedAt
        self.endedAt = nil
        self.durationListened = durationListened
        self.trackDuration = trackDuration
        self.completionPercentage = completionPercentage
        self.wasSkipped = wasSkipped
        self.wasCompleted = wasCompleted

        // Calculate time patterns from startedAt
        let calendar = Calendar.current
        self.hourOfDay = calendar.component(.hour, from: startedAt)
        self.dayOfWeek = calendar.component(.weekday, from: startedAt)
    }
}

/// Sendable value type for transferring session data across actor boundaries
public struct ListeningSessionData: Sendable {
    public let id: UUID
    public let trackId: UUID
    public let startedAt: Date
    public let endedAt: Date?
    public let durationListened: TimeInterval
    public let trackDuration: TimeInterval
    public let completionPercentage: Double
    public let wasSkipped: Bool
    public let wasCompleted: Bool
    public let hourOfDay: Int
    public let dayOfWeek: Int

    public init(from model: ListeningSession) {
        self.id = model.id
        self.trackId = model.trackId
        self.startedAt = model.startedAt
        self.endedAt = model.endedAt
        self.durationListened = model.durationListened
        self.trackDuration = model.trackDuration
        self.completionPercentage = model.completionPercentage
        self.wasSkipped = model.wasSkipped
        self.wasCompleted = model.wasCompleted
        self.hourOfDay = model.hourOfDay
        self.dayOfWeek = model.dayOfWeek
    }

    /// Memberwise initializer for testing and direct construction
    public init(
        id: UUID,
        trackId: UUID,
        startedAt: Date,
        endedAt: Date?,
        durationListened: TimeInterval,
        trackDuration: TimeInterval,
        completionPercentage: Double,
        wasSkipped: Bool,
        wasCompleted: Bool,
        hourOfDay: Int,
        dayOfWeek: Int
    ) {
        self.id = id
        self.trackId = trackId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationListened = durationListened
        self.trackDuration = trackDuration
        self.completionPercentage = completionPercentage
        self.wasSkipped = wasSkipped
        self.wasCompleted = wasCompleted
        self.hourOfDay = hourOfDay
        self.dayOfWeek = dayOfWeek
    }
}
