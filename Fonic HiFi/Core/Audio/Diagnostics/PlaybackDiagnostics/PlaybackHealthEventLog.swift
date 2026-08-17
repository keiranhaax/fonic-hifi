//
//  PlaybackHealthEventLog.swift
//  Fonic HiFi
//
//  Bounded playback-health event log feeding the diagnostics panel (F4).
//

import Combine
import Foundation

/// A single playback-health event for the diagnostics panel.
///
/// Event details must stay privacy-safe: numeric positions, engine
/// identifiers, and stable reason codes only. Never include track titles,
/// file paths, URLs, or error descriptions that may embed them.
public struct PlaybackHealthEvent: Sendable, Equatable, Identifiable {
    /// Stable event codes recorded on the playback-health timeline.
    public enum Kind: String, Sendable, Equatable {
        /// AVFoundation reset media services; the engine rebuild flow started.
        case mediaServicesResetDetected
        /// Recovery rebuilt the engine and restored the track paused at the preserved position.
        case mediaServicesResetRecoverySucceeded
        /// Recovery failed; playback stays paused at the preserved position and the error is surfaced.
        case mediaServicesResetRecoveryFailed
        /// AVAudioEngine route/configuration recovery failed after transport capture.
        case audioEngineConfigurationRecoveryFailed
    }

    public let id: UUID
    public let kind: Kind
    public let timestamp: Date

    /// Privacy-safe summary (for example `position=37.042` or `reason=AudioError`).
    public let detail: String?

    public init(
        id: UUID = UUID(),
        kind: Kind,
        timestamp: Date,
        detail: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.timestamp = timestamp
        self.detail = detail
    }
}

/// Bounded, MainActor-owned store of recent playback-health events.
///
/// Once `capacity` is exceeded the oldest events are dropped first.
/// Persistence and panel presentation layer on top of `events`.
@MainActor
public final class PlaybackHealthEventLog {
    /// Default number of retained events.
    public static let defaultCapacity = 200

    private let capacity: Int
    private let nowProvider: @Sendable () -> Date
    private let eventsSubject = CurrentValueSubject<[PlaybackHealthEvent], Never>([])

    public init(
        capacity: Int = PlaybackHealthEventLog.defaultCapacity,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.capacity = max(1, capacity)
        self.nowProvider = nowProvider
    }

    /// Recorded events ordered oldest to newest.
    public var events: [PlaybackHealthEvent] {
        eventsSubject.value
    }

    /// Emits the complete bounded event timeline after every append.
    public var eventsPublisher: AnyPublisher<[PlaybackHealthEvent], Never> {
        eventsSubject.eraseToAnyPublisher()
    }

    /// Append an event, trimming the oldest entries beyond capacity.
    public func record(_ kind: PlaybackHealthEvent.Kind, detail: String? = nil) {
        var updatedEvents = eventsSubject.value
        updatedEvents.append(
            PlaybackHealthEvent(kind: kind, timestamp: nowProvider(), detail: detail)
        )
        if updatedEvents.count > capacity {
            updatedEvents.removeFirst(updatedEvents.count - capacity)
        }
        eventsSubject.send(updatedEvents)
    }
}
