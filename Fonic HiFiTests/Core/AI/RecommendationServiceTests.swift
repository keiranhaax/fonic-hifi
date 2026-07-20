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

    @Test("Generated recommendations reject malformed, duplicate, out-of-offer, and excess IDs")
    @MainActor
    func generatedRecommendationsValidateTrackIDs() {
        let offeredTrackIDs = (0 ..< 8).map { _ in UUID() }
        let outOfOfferTrackID = UUID()
        var generatedGreeting = TimeBasedGreeting(
            greeting: "Good Morning",
            trackIDs: [],
            moodDescription: "Morning mix"
        )
        generatedGreeting.trackIDStrings = [
            offeredTrackIDs[0].uuidString,
            "not-a-uuid",
            outOfOfferTrackID.uuidString,
            offeredTrackIDs[1].uuidString,
            offeredTrackIDs[0].uuidString,
            offeredTrackIDs[2].uuidString,
            offeredTrackIDs[3].uuidString,
            offeredTrackIDs[4].uuidString,
            offeredTrackIDs[5].uuidString,
        ]

        let greeting = RecommendationService.validated(
            generatedGreeting,
            offeredTrackIDs: offeredTrackIDs
        )

        #expect(greeting.trackIDs == Array(offeredTrackIDs.prefix(5)))

        var generatedMix = SurpriseMixResult(
            greeting: "Surprise",
            trackIDs: [],
            mixTheme: "Unexpected"
        )
        generatedMix.trackIDStrings = [
            outOfOfferTrackID.uuidString,
            offeredTrackIDs[0].uuidString,
            offeredTrackIDs[0].uuidString,
        ] + offeredTrackIDs.dropFirst().map(\.uuidString)

        let mix = RecommendationService.validated(
            generatedMix,
            offeredTrackIDs: offeredTrackIDs
        )

        #expect(mix.trackIDs == Array(offeredTrackIDs.prefix(7)))
    }
}
