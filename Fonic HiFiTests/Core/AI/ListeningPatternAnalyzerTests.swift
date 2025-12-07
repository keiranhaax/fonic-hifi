// Fonic HiFiTests/Core/AI/ListeningPatternAnalyzerTests.swift
import Foundation
import Testing
@testable import Fonic_HiFi

@Suite("ListeningPatternAnalyzer Tests")
struct ListeningPatternAnalyzerTests {

    @Test("Determines correct time period")
    func timePeriodsAreCorrect() {
        #expect(ListeningPatternAnalyzer.timePeriod(for: 7) == .morning)
        #expect(ListeningPatternAnalyzer.timePeriod(for: 14) == .afternoon)
        #expect(ListeningPatternAnalyzer.timePeriod(for: 19) == .evening)
        #expect(ListeningPatternAnalyzer.timePeriod(for: 23) == .lateNight)
        #expect(ListeningPatternAnalyzer.timePeriod(for: 3) == .lateNight)
    }

    @Test("Greeting matches time period")
    func greetingsMatchPeriod() {
        #expect(ListeningPatternAnalyzer.TimePeriod.morning.greeting == "Good Morning")
        #expect(ListeningPatternAnalyzer.TimePeriod.afternoon.greeting == "Good Afternoon")
        #expect(ListeningPatternAnalyzer.TimePeriod.evening.greeting == "Good Evening")
        #expect(ListeningPatternAnalyzer.TimePeriod.lateNight.greeting == "Late Night")
    }

    @Test("Builds context from sessions")
    func buildsContextFromSessions() {
        let trackId = UUID()
        let sessions = [
            ListeningSessionData(
                id: UUID(),
                trackId: trackId,
                startedAt: Date(),
                endedAt: nil,
                durationListened: 180,
                trackDuration: 200,
                completionPercentage: 0.9,
                wasSkipped: false,
                wasCompleted: true,
                hourOfDay: 8,
                dayOfWeek: 2
            )
        ]

        let context = ListeningPatternAnalyzer.buildContext(from: sessions)

        #expect(context.contains("morning"))
    }

    @Test("Handles empty sessions gracefully")
    func handlesEmptySessions() {
        let context = ListeningPatternAnalyzer.buildContext(from: [])
        #expect(context.contains("No listening history"))
    }
}
