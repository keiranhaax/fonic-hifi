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
        service.startSession(trackId: trackId, duration: 240.0)

        #expect(service.activeSession != nil)
        #expect(service.activeSession?.trackId == trackId)
    }

    @Test("Records session on track complete")
    @MainActor
    func testCompleteSession() async throws {
        let mockActor = MockTrackDataActor()
        let service = ListeningSessionService(dataActor: mockActor)

        let trackId = UUID()
        service.startSession(trackId: trackId, duration: 240.0)

        await service.endSession(
            currentTime: 240.0,
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
        let service = ListeningSessionService(dataActor: mockActor)

        let trackId = UUID()
        service.startSession(trackId: trackId, duration: 240.0)

        await service.endSession(
            currentTime: 60.0,
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
        let service = ListeningSessionService(dataActor: mockActor)

        let trackId = UUID()
        service.startSession(trackId: trackId, duration: 200.0)

        // Listen to 60% of track
        await service.endSession(
            currentTime: 120.0,
            wasSkipped: true,
            wasCompleted: false
        )

        // Should increment because > 50%
        #expect(mockActor.incrementedTrackIds.contains(trackId))
    }
}

// Mock for testing
@MainActor
final class MockTrackDataActor: ListeningSessionRecording {
    var recordedSessions: [(trackId: UUID, wasSkipped: Bool, wasCompleted: Bool, completionPercentage: Double)] = []
    var incrementedTrackIds: Set<UUID> = []

    func recordListeningSession(
        trackId: UUID,
        startedAt: Date,
        durationListened: TimeInterval,
        trackDuration: TimeInterval,
        completionPercentage: Double,
        wasSkipped: Bool,
        wasCompleted: Bool
    ) async throws {
        recordedSessions.append((trackId, wasSkipped, wasCompleted, completionPercentage))
    }

    func incrementPlayCount(for trackId: UUID) async throws {
        incrementedTrackIds.insert(trackId)
    }
}
