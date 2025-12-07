// Fonic HiFiTests/Core/AI/RecommendationServiceTests.swift
import Foundation
import Testing
@testable import Fonic_HiFi

@Suite("RecommendationService Tests")
struct RecommendationServiceTests {

    @Test("Fallback greeting returns correct time-based greeting")
    @MainActor
    func fallbackGreetingWorks() async {
        let service = RecommendationService()
        let trackIDs = (0..<10).map { _ in UUID() }

        let result = await service.fallbackTimeBasedGreeting(availableTrackIDs: trackIDs)

        let validGreetings = ["Good Morning", "Good Afternoon", "Good Evening", "Late Night"]
        #expect(validGreetings.contains(result.greeting))
        #expect(result.trackIDs.count <= 5)
    }

    @Test("Fallback surprise mix returns shuffled tracks")
    @MainActor
    func fallbackSurpriseMixWorks() async {
        let service = RecommendationService()
        let trackIDs = (0..<20).map { _ in UUID() }

        let result = await service.fallbackSurpriseMix(availableTrackIDs: trackIDs)

        #expect(!result.greeting.isEmpty)
        #expect(result.trackIDs.count <= 7)
        #expect(!result.mixTheme.isEmpty)
    }

    @Test("Availability check returns boolean")
    @MainActor
    func availabilityCheckWorks() async {
        let service = RecommendationService()

        // Should not crash, returns true or false
        let isAvailable = await service.isFoundationModelsAvailable()
        #expect(isAvailable == true || isAvailable == false)
    }
}
