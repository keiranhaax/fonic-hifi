// Fonic HiFi/Core/Audio/Analytics/ListeningSessionService.swift
import Foundation
import OSLog

/// Protocol for session recording (enables testing with mock)
public protocol ListeningSessionRecording: Sendable {
    func recordListeningSession(
        trackId: UUID,
        startedAt: Date,
        durationListened: TimeInterval,
        trackDuration: TimeInterval,
        completionPercentage: Double,
        wasSkipped: Bool,
        wasCompleted: Bool
    ) async throws

    func incrementPlayCount(for trackId: UUID) async throws
}

/// Tracks listening sessions and persists them via TrackDataActor
@MainActor
public final class ListeningSessionService {
    // MARK: - Dependencies

    private let dataActor: ListeningSessionRecording
    private let logger = Log.logger(.audioAnalytics)

    // MARK: - Active Session State

    /// Currently active listening session
    public private(set) var activeSession: ActiveSession?

    /// Minimum completion percentage to count as a "play"
    private let playCountThreshold: Double = 0.5

    /// Minimum seconds to record a session at all
    private let minimumSessionDuration: TimeInterval = 10.0

    // MARK: - Types

    public struct ActiveSession {
        let trackId: UUID
        let startedAt: Date
        let trackDuration: TimeInterval
    }

    // MARK: - Initialization

    public init(dataActor: ListeningSessionRecording) {
        self.dataActor = dataActor
    }

    // MARK: - Session Lifecycle

    /// Start tracking a new listening session
    /// - Parameters:
    ///   - trackId: UUID of the track being played
    ///   - duration: Total duration of the track in seconds
    public func startSession(trackId: UUID, duration: TimeInterval) {
        // End any existing session first
        if activeSession != nil {
            Task {
                await endSession(currentTime: 0, wasSkipped: true, wasCompleted: false)
            }
        }

        activeSession = ActiveSession(
            trackId: trackId,
            startedAt: Date(),
            trackDuration: duration
        )

        logger.debug("Started listening session")
    }

    /// End the current listening session and persist it
    /// - Parameters:
    ///   - currentTime: Current playback position when session ended
    ///   - wasSkipped: Whether user manually skipped
    ///   - wasCompleted: Whether track played to natural completion
    public func endSession(
        currentTime: TimeInterval,
        wasSkipped: Bool,
        wasCompleted: Bool
    ) async {
        guard let session = activeSession else {
            logger.debug("No active session to end")
            return
        }

        activeSession = nil

        let durationListened = currentTime
        let completionPercentage = session.trackDuration > 0
            ? min(1.0, durationListened / session.trackDuration)
            : 0.0

        // Only record sessions that lasted at least minimum duration
        guard durationListened >= minimumSessionDuration else {
            logger.debug("Session too short to record: \(durationListened)s")
            return
        }

        do {
            // Record the session
            try await dataActor.recordListeningSession(
                trackId: session.trackId,
                startedAt: session.startedAt,
                durationListened: durationListened,
                trackDuration: session.trackDuration,
                completionPercentage: completionPercentage,
                wasSkipped: wasSkipped,
                wasCompleted: wasCompleted
            )

            // Increment play count if user listened to enough of the track
            if completionPercentage >= playCountThreshold || wasCompleted {
                try await dataActor.incrementPlayCount(for: session.trackId)
                logger.debug("Incremented play count after listening session")
            }

            logger.info("Recorded session: \(Int(completionPercentage * 100))% of track, skipped=\(wasSkipped), completed=\(wasCompleted)")
        } catch {
            logger.error("Failed to record listening session: \(error.localizedDescription)")
        }
    }

    /// Cancel the current session without recording
    public func cancelSession() {
        if activeSession != nil {
            logger.debug("Cancelled listening session")
            activeSession = nil
        }
    }
}
