// Fonic HiFiTests/Integration/AIRecommendationsIntegrationTests.swift
import Foundation
import Testing
@testable import Fonic_HiFi

@Suite("AI Recommendations Integration Tests")
struct AIRecommendationsIntegrationTests {

    @Test("Full recommendation flow with fallback")
    @MainActor
    func fullRecommendationFlowWorks() async throws {
        let service = RecommendationService()
        let trackIDs = (0..<20).map { _ in UUID() }
        let sessions: [ListeningSessionData] = []
        let genres = ["Rock", "Jazz", "Electronic"]

        // Should work even without AI (fallback)
        let greeting = try await service.generateTimeBasedGreeting(
            sessions: sessions,
            availableTrackIDs: trackIDs,
            genres: genres
        )

        #expect(!greeting.greeting.isEmpty)
        #expect(!greeting.trackIDs.isEmpty)

        let surprise = try await service.generateSurpriseMix(
            sessions: sessions,
            availableTrackIDs: trackIDs,
            genres: genres
        )

        #expect(!surprise.greeting.isEmpty)
        #expect(!surprise.trackIDs.isEmpty)
    }

    @Test("Pattern analyzer handles empty sessions")
    func patternAnalyzerHandlesEmptySessions() {
        let context = ListeningPatternAnalyzer.buildContext(from: [])
        #expect(context.contains("No listening history"))
    }

    @Test("Pattern analyzer builds context with sessions")
    func patternAnalyzerBuildsContextWithSessions() {
        let sessions = [
            ListeningSessionData(
                id: UUID(),
                trackId: UUID(),
                startedAt: Date(),
                endedAt: nil,
                durationListened: 180,
                trackDuration: 200,
                completionPercentage: 0.9,
                wasSkipped: false,
                wasCompleted: true,
                hourOfDay: 9,
                dayOfWeek: 3
            ),
            ListeningSessionData(
                id: UUID(),
                trackId: UUID(),
                startedAt: Date(),
                endedAt: nil,
                durationListened: 120,
                trackDuration: 200,
                completionPercentage: 0.6,
                wasSkipped: false,
                wasCompleted: false,
                hourOfDay: 10,
                dayOfWeek: 4
            )
        ]

        let context = ListeningPatternAnalyzer.buildContext(from: sessions)

        #expect(context.contains("morning"))
        #expect(context.contains("Average completion"))
    }

    @Test("Fallback returns tracks from available pool")
    @MainActor
    func fallbackReturnsTracksFromPool() async {
        let service = RecommendationService()
        let knownIDs = (0..<10).map { _ in UUID() }

        let greeting = await service.fallbackTimeBasedGreeting(availableTrackIDs: knownIDs)

        // All returned IDs should be from our pool
        for returnedID in greeting.trackIDs {
            #expect(knownIDs.contains(returnedID))
        }
    }

    @Test("Time period classification is correct")
    func timePeriodClassificationWorks() {
        // Morning: 5-11
        #expect(ListeningPatternAnalyzer.timePeriod(for: 5) == .morning)
        #expect(ListeningPatternAnalyzer.timePeriod(for: 11) == .morning)

        // Afternoon: 12-16
        #expect(ListeningPatternAnalyzer.timePeriod(for: 12) == .afternoon)
        #expect(ListeningPatternAnalyzer.timePeriod(for: 16) == .afternoon)

        // Evening: 17-20
        #expect(ListeningPatternAnalyzer.timePeriod(for: 17) == .evening)
        #expect(ListeningPatternAnalyzer.timePeriod(for: 20) == .evening)

        // Late night: 21-4
        #expect(ListeningPatternAnalyzer.timePeriod(for: 21) == .lateNight)
        #expect(ListeningPatternAnalyzer.timePeriod(for: 0) == .lateNight)
        #expect(ListeningPatternAnalyzer.timePeriod(for: 4) == .lateNight)
    }
}
