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
    private let playCountThreshold: Double

    /// Minimum seconds to record a session at all
    private let minimumSessionDuration: TimeInterval

    private let now: () -> Date
    private var sessionGeneration: UInt = 0

    // MARK: - Types

    public struct ActiveSession {
        let trackId: UUID
        let startedAt: Date
        let trackDuration: TimeInterval
        fileprivate var durationListened: TimeInterval
        fileprivate var resumedAt: Date?
    }

    // MARK: - Initialization

    public init(dataActor: ListeningSessionRecording) {
        self.dataActor = dataActor
        playCountThreshold = 0.5
        minimumSessionDuration = 10
        now = Date.init
    }

    init(
        dataActor: ListeningSessionRecording,
        playCountThreshold: Double = 0.5,
        minimumSessionDuration: TimeInterval = 10,
        now: @escaping () -> Date
    ) {
        self.dataActor = dataActor
        self.playCountThreshold = playCountThreshold
        self.minimumSessionDuration = minimumSessionDuration
        self.now = now
    }

    // MARK: - Session Lifecycle

    /// Start tracking a new listening session
    /// - Parameters:
    ///   - trackId: UUID of the track being played
    ///   - duration: Total duration of the track in seconds
    public func startSession(trackId: UUID, duration: TimeInterval) async {
        sessionGeneration &+= 1
        let generation = sessionGeneration

        if let previousSession = takeActiveSession() {
            await persist(
                previousSession,
                wasSkipped: true,
                wasCompleted: false
            )
        }

        guard generation == sessionGeneration else { return }
        let startedAt = now()
        activeSession = ActiveSession(
            trackId: trackId,
            startedAt: startedAt,
            trackDuration: duration,
            durationListened: 0,
            resumedAt: startedAt
        )

        logger.debug("Started listening session")
    }

    /// Accrue listening time and suspend tracking while playback is paused.
    public func pauseSession() {
        guard var session = activeSession else { return }
        accrueListeningTime(in: &session)
        session.resumedAt = nil
        activeSession = session
    }

    /// Resume time accounting without changing the playback position.
    public func resumeSession() {
        guard var session = activeSession, session.resumedAt == nil else { return }
        session.resumedAt = now()
        activeSession = session
    }

    /// Seeking changes position, not actual time listened, so it must not accrue skipped media.
    public func recordSeek() {
        guard var session = activeSession else { return }
        let wasPlaying = session.resumedAt != nil
        accrueListeningTime(in: &session)
        session.resumedAt = wasPlaying ? now() : nil
        activeSession = session
    }

    /// End the current listening session and persist it
    /// - Parameters:
    ///   - wasSkipped: Whether user manually skipped
    ///   - wasCompleted: Whether track played to natural completion
    public func endSession(
        wasSkipped: Bool,
        wasCompleted: Bool
    ) async {
        guard let persistenceTask = endSessionInBackground(
            wasSkipped: wasSkipped,
            wasCompleted: wasCompleted
        ) else { return }
        await persistenceTask.value
    }

    /// Ends the active session synchronously from the facade's point of view,
    /// then persists it without delaying the next playback transition.
    @discardableResult
    func endSessionInBackground(
        wasSkipped: Bool,
        wasCompleted: Bool
    ) -> Task<Void, Never>? {
        sessionGeneration &+= 1
        guard let session = takeActiveSession() else {
            logger.debug("No active session to end")
            return nil
        }

        return Task { @MainActor in
            await persist(
                session,
                wasSkipped: wasSkipped,
                wasCompleted: wasCompleted
            )
        }
    }

    private func persist(
        _ activeSession: ActiveSession,
        wasSkipped: Bool,
        wasCompleted: Bool
    ) async {
        var session = activeSession
        accrueListeningTime(in: &session)
        let durationListened = session.trackDuration > 0
            ? min(session.durationListened, session.trackDuration)
            : session.durationListened
        let completionPercentage = session.trackDuration > 0
            ? min(1.0, durationListened / session.trackDuration)
            : 0.0

        // Only record sessions that lasted at least minimum duration
        guard durationListened >= minimumSessionDuration else {
            logger.debug("Session too short to record: \(durationListened, privacy: .private)s")
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

            let completionPercent = Int(completionPercentage * 100)
            logger.info("Recorded session: \(completionPercent, privacy: .private)% of track, skipped=\(wasSkipped, privacy: .private), completed=\(wasCompleted, privacy: .private)")
        } catch {
            logger.error("Failed to record listening session: \(error.localizedDescription, privacy: .private)")
        }
    }

    /// Cancel the current session without recording
    public func cancelSession() {
        if activeSession != nil {
            sessionGeneration &+= 1
            logger.debug("Cancelled listening session")
            activeSession = nil
        }
    }

    private func takeActiveSession() -> ActiveSession? {
        let session = activeSession
        activeSession = nil
        return session
    }

    private func accrueListeningTime(in session: inout ActiveSession) {
        guard let resumedAt = session.resumedAt else { return }
        let timestamp = now()
        session.durationListened += max(0, timestamp.timeIntervalSince(resumedAt))
        session.resumedAt = timestamp
    }
}
