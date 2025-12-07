// Fonic HiFiTests/Core/AI/RecommendationSchemasTests.swift
import Foundation
import Testing
@testable import Fonic_HiFi

@Suite("RecommendationSchemas Tests")
struct RecommendationSchemasTests {

    @Test("TimeBasedGreeting has correct properties")
    func timeBasedGreetingProperties() {
        let greeting = TimeBasedGreeting(
            greeting: "Good Morning",
            trackIDs: [UUID(), UUID()],
            moodDescription: "Start your day with energy"
        )

        #expect(greeting.greeting == "Good Morning")
        #expect(greeting.trackIDs.count == 2)
        #expect(greeting.moodDescription == "Start your day with energy")
    }

    @Test("MixDefinition has correct properties")
    func mixDefinitionProperties() {
        let mix = MixDefinition(
            name: "Chill Vibes",
            trackIDs: [UUID()],
            moodDescription: "Relaxing tracks for unwinding"
        )

        #expect(mix.name == "Chill Vibes")
        #expect(!mix.trackIDs.isEmpty)
    }

    @Test("SurpriseMixResult has correct properties")
    func surpriseMixResultProperties() {
        let result = SurpriseMixResult(
            greeting: "Here's something special",
            trackIDs: [UUID(), UUID(), UUID()],
            mixTheme: "Nostalgic favorites"
        )

        #expect(result.trackIDs.count == 3)
        #expect(result.mixTheme == "Nostalgic favorites")
    }
}
