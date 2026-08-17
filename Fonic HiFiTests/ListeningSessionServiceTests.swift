// Fonic HiFiTests/ListeningSessionServiceTests.swift
import Foundation
import Testing

@testable import Fonic_HiFi

@Suite("ListeningSessionService Tests")
struct ListeningSessionServiceTests {
    @Test("Starts session on track play")
    @MainActor
    func testStartSession() async throws {
        let mockActor = MockTrackDataActor()
        let service = ListeningSessionService(dataActor: mockActor)

        let trackId = UUID()
        await service.startSession(trackId: trackId, duration: 240.0)

        #expect(service.activeSession != nil)
        #expect(service.activeSession?.trackId == trackId)
    }

    @Test("Records session on track complete")
    @MainActor
    func testCompleteSession() async throws {
        let mockActor = MockTrackDataActor()
        var now = Date(timeIntervalSince1970: 1_000)
        let service = makeService(mockActor: mockActor, now: { now })

        let trackId = UUID()
        await service.startSession(trackId: trackId, duration: 240.0)
        now.addTimeInterval(240)

        await service.endSession(
            wasSkipped: false,
            wasCompleted: true
        )

        #expect(service.activeSession == nil)
        #expect(mockActor.recordedSessions.count == 1)
        #expect(mockActor.recordedSessions.first?.wasCompleted == true)
        #expect(mockActor.incrementedTrackIds.contains(trackId))
    }

    @Test("Records skip with partial listen")
    @MainActor
    func testSkipSession() async throws {
        let mockActor = MockTrackDataActor()
        var now = Date(timeIntervalSince1970: 1_000)
        let service = makeService(mockActor: mockActor, now: { now })

        let trackId = UUID()
        await service.startSession(trackId: trackId, duration: 240.0)
        now.addTimeInterval(60)

        await service.endSession(
            wasSkipped: true,
            wasCompleted: false
        )

        #expect(mockActor.recordedSessions.first?.wasSkipped == true)
        #expect(mockActor.recordedSessions.first?.completionPercentage == 0.25)
        // Should NOT increment play count for skips under threshold
        #expect(mockActor.incrementedTrackIds.isEmpty)
    }

    @Test("Increments play count when over 50% listened")
    @MainActor
    func testPlayCountThreshold() async throws {
        let mockActor = MockTrackDataActor()
        var now = Date(timeIntervalSince1970: 1_000)
        let service = makeService(mockActor: mockActor, now: { now })

        let trackId = UUID()
        await service.startSession(trackId: trackId, duration: 200.0)
        now.addTimeInterval(120)

        // Listen to 60% of track
        await service.endSession(
            wasSkipped: true,
            wasCompleted: false
        )

        // Should increment because > 50%
        #expect(mockActor.incrementedTrackIds.contains(trackId))
    }

    @Test("Paused time and seek-skipped position are excluded from listened duration")
    @MainActor
    func pausedAndSeekedTimeAreExcluded() async throws {
        let mockActor = MockTrackDataActor()
        var now = Date(timeIntervalSince1970: 1_000)
        let service = makeService(mockActor: mockActor, now: { now })
        let trackId = UUID()

        await service.startSession(trackId: trackId, duration: 300)
        now.addTimeInterval(20)
        service.pauseSession()
        now.addTimeInterval(100)
        service.resumeSession()
        now.addTimeInterval(10)
        service.recordSeek()
        now.addTimeInterval(5)
        await service.endSession(wasSkipped: true, wasCompleted: false)

        let session = try #require(mockActor.recordedSessions.first)
        #expect(session.durationListened == 35)
        #expect(session.completionPercentage == 35.0 / 300.0)
    }

    @Test("An older transition cannot overwrite a newer active session")
    @MainActor
    func rapidTransitionsRetainNewestSession() async throws {
        let mockActor = MockTrackDataActor()
        mockActor.shouldBlockRecording = true
        var now = Date(timeIntervalSince1970: 1_000)
        let service = makeService(mockActor: mockActor, now: { now })
        let firstTrackID = UUID()
        let secondTrackID = UUID()
        let newestTrackID = UUID()

        await service.startSession(trackId: firstTrackID, duration: 300)
        now.addTimeInterval(12)

        let olderTransition = Task { @MainActor in
            await service.startSession(trackId: secondTrackID, duration: 300)
        }
        await mockActor.waitForRecordAttempt()
        await service.startSession(trackId: newestTrackID, duration: 300)
        mockActor.releaseBlockedRecording()
        await olderTransition.value

        #expect(service.activeSession?.trackId == newestTrackID)
        #expect(mockActor.recordedSessions.map(\.trackId) == [firstTrackID])
    }

    @MainActor
    private func makeService(
        mockActor: MockTrackDataActor,
        now: @escaping () -> Date
    ) -> ListeningSessionService {
        ListeningSessionService(
            dataActor: mockActor,
            minimumSessionDuration: 10,
            now: now
        )
    }
}

// Mock for testing
@MainActor
final class MockTrackDataActor: ListeningSessionRecording {
    typealias RecordedSession = (
        trackId: UUID,
        durationListened: TimeInterval,
        wasSkipped: Bool,
        wasCompleted: Bool,
        completionPercentage: Double
    )

    var recordedSessions: [RecordedSession] = []
    var incrementedTrackIds: Set<UUID> = []
    var shouldBlockRecording = false
    private var didAttemptRecord = false
    private var recordAttemptContinuation: CheckedContinuation<Void, Never>?
    private var recordReleaseContinuation: CheckedContinuation<Void, Never>?

    func recordListeningSession(
        trackId: UUID,
        startedAt: Date,
        durationListened: TimeInterval,
        trackDuration: TimeInterval,
        completionPercentage: Double,
        wasSkipped: Bool,
        wasCompleted: Bool
    ) async throws {
        didAttemptRecord = true
        recordAttemptContinuation?.resume()
        recordAttemptContinuation = nil

        if shouldBlockRecording {
            await withCheckedContinuation { continuation in
                recordReleaseContinuation = continuation
            }
        }

        recordedSessions.append(
            (trackId, durationListened, wasSkipped, wasCompleted, completionPercentage)
        )
    }

    func incrementPlayCount(for trackId: UUID) async throws {
        incrementedTrackIds.insert(trackId)
    }

    func waitForRecordAttempt() async {
        guard !didAttemptRecord else { return }
        await withCheckedContinuation { continuation in
            recordAttemptContinuation = continuation
        }
    }

    func releaseBlockedRecording() {
        shouldBlockRecording = false
        recordReleaseContinuation?.resume()
        recordReleaseContinuation = nil
    }
}
