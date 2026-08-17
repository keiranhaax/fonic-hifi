// Fonic HiFiTests/Core/AI/RecommendationServiceTests.swift
import Foundation
import Testing
@testable import Fonic_HiFi

@Suite("RecommendationService Tests")
struct RecommendationServiceTests {
    enum InjectedGenerationFailure: Error, CaseIterable {
        case generationFailed
        case unsupportedLocale
    }

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

    @Test("Unavailable model returns fallback without creating a provider")
    @MainActor
    func unavailableModelDoesNotCreateProvider() async throws {
        var providerCreationCount = 0
        let offeredTrackIDs = (0 ..< 8).map { _ in UUID() }
        let service = RecommendationService(
            availabilityCheck: { false },
            generationProviderFactory: {
                providerCreationCount += 1
                return StubRecommendationGenerationProvider()
            }
        )

        let greeting = try await service.generateTimeBasedGreeting(
            sessions: [],
            availableTrackIDs: offeredTrackIDs,
            genres: []
        )
        let mix = try await service.generateSurpriseMix(
            sessions: [],
            availableTrackIDs: offeredTrackIDs,
            genres: []
        )

        #expect(providerCreationCount == 0)
        #expect(greeting.trackIDs.count == 5)
        #expect(Set(greeting.trackIDs).isSubset(of: Set(offeredTrackIDs)))
        #expect(mix.trackIDs.count == 7)
        #expect(Set(mix.trackIDs).isSubset(of: Set(offeredTrackIDs)))
    }

    @Test(
        "Generation and locale failures return deterministic local fallbacks",
        arguments: InjectedGenerationFailure.allCases
    )
    @MainActor
    func generationFailuresUseFallback(_ failure: InjectedGenerationFailure) async throws {
        let offeredTrackIDs = (0 ..< 8).map { _ in UUID() }
        let service = makeService(
            greeting: { _ in throw failure },
            mix: { _ in throw failure }
        )

        let greeting = try await service.generateTimeBasedGreeting(
            sessions: [],
            availableTrackIDs: offeredTrackIDs,
            genres: []
        )
        let mix = try await service.generateSurpriseMix(
            sessions: [],
            availableTrackIDs: offeredTrackIDs,
            genres: []
        )

        #expect(Set(greeting.trackIDs).isSubset(of: Set(offeredTrackIDs)))
        #expect(Set(mix.trackIDs).isSubset(of: Set(offeredTrackIDs)))
    }

    @Test("Generated provider output is validated before publication")
    @MainActor
    func generatedOutputIsValidated() async throws {
        let offeredTrackIDs = (0 ..< 10).map { _ in UUID() }
        let outOfSetID = UUID()
        var generatedGreeting = TimeBasedGreeting(
            greeting: "Injected",
            trackIDs: [],
            moodDescription: "Injected mood"
        )
        generatedGreeting.trackIDStrings = [
            "not-a-uuid",
            outOfSetID.uuidString,
            offeredTrackIDs[0].uuidString,
            offeredTrackIDs[0].uuidString,
        ] + offeredTrackIDs.dropFirst().map(\.uuidString)

        var generatedMix = SurpriseMixResult(
            greeting: "Injected",
            trackIDs: [],
            mixTheme: "Injected theme"
        )
        generatedMix.trackIDStrings = [
            "malformed",
            outOfSetID.uuidString,
            offeredTrackIDs[0].uuidString,
            offeredTrackIDs[0].uuidString,
        ] + offeredTrackIDs.dropFirst().map(\.uuidString)

        let service = makeService(
            greeting: { _ in generatedGreeting },
            mix: { _ in generatedMix }
        )

        let greeting = try await service.generateTimeBasedGreeting(
            sessions: [],
            availableTrackIDs: offeredTrackIDs,
            genres: []
        )
        let mix = try await service.generateSurpriseMix(
            sessions: [],
            availableTrackIDs: offeredTrackIDs,
            genres: []
        )

        #expect(greeting.trackIDs == Array(offeredTrackIDs.prefix(5)))
        #expect(mix.trackIDs == Array(offeredTrackIDs.prefix(7)))
    }

    @Test("Cancellation during generation propagates without fallback publication")
    @MainActor
    func cancellationPropagates() async {
        let service = makeService(
            greeting: { _ in throw CancellationError() },
            mix: { _ in throw CancellationError() }
        )

        await #expect(throws: CancellationError.self) {
            _ = try await service.generateTimeBasedGreeting(
                sessions: [],
                availableTrackIDs: [UUID()],
                genres: []
            )
        }
        await #expect(throws: CancellationError.self) {
            _ = try await service.generateSurpriseMix(
                sessions: [],
                availableTrackIDs: [UUID()],
                genres: []
            )
        }
    }

    @Test("Greeting and mix generation are serialized for a shared provider")
    @MainActor
    func sharedProviderRequestsAreSerialized() async throws {
        var activeRequestCount = 0
        var maximumActiveRequestCount = 0
        let offeredTrackIDs = (0 ..< 8).map { _ in UUID() }

        func enterGeneration() async {
            activeRequestCount += 1
            maximumActiveRequestCount = max(maximumActiveRequestCount, activeRequestCount)
            await Task.yield()
            activeRequestCount -= 1
        }

        let service = makeService(
            greeting: { _ in
                await enterGeneration()
                return TimeBasedGreeting(
                    greeting: "Injected",
                    trackIDs: Array(offeredTrackIDs.prefix(5)),
                    moodDescription: "Injected"
                )
            },
            mix: { _ in
                await enterGeneration()
                return SurpriseMixResult(
                    greeting: "Injected",
                    trackIDs: Array(offeredTrackIDs.prefix(7)),
                    mixTheme: "Injected"
                )
            }
        )

        async let greeting = service.generateTimeBasedGreeting(
            sessions: [],
            availableTrackIDs: offeredTrackIDs,
            genres: []
        )
        async let mix = service.generateSurpriseMix(
            sessions: [],
            availableTrackIDs: offeredTrackIDs,
            genres: []
        )

        _ = try await (greeting, mix)
        #expect(maximumActiveRequestCount == 1)
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

    @MainActor
    private func makeService(
        greeting: @escaping @MainActor (String) async throws -> TimeBasedGreeting,
        mix: @escaping @MainActor (String) async throws -> SurpriseMixResult
    ) -> RecommendationService {
        let provider = StubRecommendationGenerationProvider(
            greeting: greeting,
            mix: mix
        )
        return RecommendationService(
            availabilityCheck: { true },
            generationProviderFactory: { provider }
        )
    }
}

@MainActor
private final class StubRecommendationGenerationProvider: RecommendationGenerationProviding {
    private let greeting: @MainActor (String) async throws -> TimeBasedGreeting
    private let mix: @MainActor (String) async throws -> SurpriseMixResult

    init(
        greeting: @escaping @MainActor (String) async throws -> TimeBasedGreeting = { _ in
            Issue.record("Unexpected greeting generation")
            return TimeBasedGreeting(greeting: "", trackIDs: [], moodDescription: "")
        },
        mix: @escaping @MainActor (String) async throws -> SurpriseMixResult = { _ in
            Issue.record("Unexpected mix generation")
            return SurpriseMixResult(greeting: "", trackIDs: [], mixTheme: "")
        }
    ) {
        self.greeting = greeting
        self.mix = mix
    }

    func generateGreeting(prompt: String) async throws -> TimeBasedGreeting {
        try await greeting(prompt)
    }

    func generateSurpriseMix(prompt: String) async throws -> SurpriseMixResult {
        try await mix(prompt)
    }
}
