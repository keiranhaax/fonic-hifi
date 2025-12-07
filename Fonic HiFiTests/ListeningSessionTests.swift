// Fonic HiFiTests/ListeningSessionTests.swift
import Foundation
import SwiftData
import Testing

@testable import Fonic_HiFi

@Suite("ListeningSession Model Tests")
struct ListeningSessionTests {
    @Test("Creates session with required properties")
    func testCreateSession() throws {
        let trackId = UUID()
        let session = ListeningSession(
            trackId: trackId,
            startedAt: Date(),
            durationListened: 120.0,
            trackDuration: 240.0,
            completionPercentage: 0.5,
            wasSkipped: false,
            wasCompleted: false
        )

        #expect(session.trackId == trackId)
        #expect(session.durationListened == 120.0)
        #expect(session.completionPercentage == 0.5)
        #expect(session.wasSkipped == false)
    }

    @Test("Calculates hour and day of week from startedAt")
    func testTimePatterns() throws {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 7
        components.hour = 14
        components.minute = 30
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date from components")
            return
        }

        let session = ListeningSession(
            trackId: UUID(),
            startedAt: date,
            durationListened: 60.0,
            trackDuration: 180.0,
            completionPercentage: 0.33,
            wasSkipped: false,
            wasCompleted: false
        )

        #expect(session.hourOfDay == 14)
        #expect(session.dayOfWeek == 1) // Sunday = 1
    }
}
