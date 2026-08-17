//
//  PlaybackHealthEventLogging.swift
//  Fonic HiFi
//
//  Focused interface for recording and reading playback-health events.
//

import Combine
import Foundation

@MainActor
public protocol PlaybackHealthEventLogging: AnyObject, Sendable {
    /// Recent playback-health events, ordered oldest to newest.
    var playbackHealthEvents: [PlaybackHealthEvent] { get }

    /// Emits the complete bounded event timeline on the main actor after each append.
    var playbackHealthEventsPublisher: AnyPublisher<[PlaybackHealthEvent], Never> { get }

    /// Append a playback-health event. Details must stay privacy-safe:
    /// numeric positions, engine identifiers, and stable reason codes only.
    func recordPlaybackHealthEvent(_ kind: PlaybackHealthEvent.Kind, detail: String?)
}

public extension PlaybackHealthEventLogging {
    func recordPlaybackHealthEvent(_ kind: PlaybackHealthEvent.Kind) {
        recordPlaybackHealthEvent(kind, detail: nil)
    }
}
