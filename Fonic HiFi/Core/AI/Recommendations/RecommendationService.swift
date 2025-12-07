// Fonic HiFi/Core/AI/Recommendations/RecommendationService.swift
import Foundation
import FoundationModels
import OSLog

/// Service for generating AI-powered music recommendations
@MainActor
public final class RecommendationService {

    // MARK: - Properties

    private let logger = Log.logger(.recommendations)
    private var session: LanguageModelSession?

    // MARK: - Initialization

    public init() {}

    // MARK: - Availability

    /// Check if Foundation Models is available on this device
    public func isFoundationModelsAvailable() async -> Bool {
        switch SystemLanguageModel.default.availability {
        case .available:
            return true
        case .unavailable:
            return false
        }
    }

    // MARK: - AI Recommendations

    /// Generate a time-based greeting with track recommendations
    public func generateTimeBasedGreeting(
        sessions: [ListeningSessionData],
        availableTrackIDs: [UUID],
        genres: [String]
    ) async -> TimeBasedGreeting {
        guard await isFoundationModelsAvailable() else {
            logger.info("Foundation Models unavailable, using fallback")
            return await fallbackTimeBasedGreeting(availableTrackIDs: availableTrackIDs)
        }

        do {
            let session = try await getOrCreateSession()

            let timePeriod = ListeningPatternAnalyzer.currentTimePeriod
            let listeningContext = ListeningPatternAnalyzer.buildContext(from: sessions)
            let trackContext = ListeningPatternAnalyzer.buildTrackContext(
                trackIDs: availableTrackIDs,
                genres: genres,
                recentlyPlayed: sessions.prefix(10).map(\.trackId)
            )

            let prompt = """
                Current time: \(timePeriod.greeting) (\(timePeriod.moodHint))

                \(listeningContext)

                \(trackContext)

                Generate a personalized \(timePeriod.rawValue) greeting with 5 track recommendations
                that match the mood. Use ONLY track UUIDs from the provided list.
                """

            let response = try await session.respond(
                to: prompt,
                generating: TimeBasedGreeting.self
            )

            logger.info("Generated AI greeting: \(response.content.greeting)")
            return response.content

        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .guardrailViolation:
                logger.warning("Guardrail violation, using fallback")
            case .exceededContextWindowSize:
                logger.warning("Context exceeded, using fallback")
            default:
                logger.error("AI generation failed: \(error.localizedDescription)")
            }
            return await fallbackTimeBasedGreeting(availableTrackIDs: availableTrackIDs)
        } catch {
            logger.error("AI generation failed: \(error.localizedDescription)")
            return await fallbackTimeBasedGreeting(availableTrackIDs: availableTrackIDs)
        }
    }

    /// Generate a surprise mix
    public func generateSurpriseMix(
        sessions: [ListeningSessionData],
        availableTrackIDs: [UUID],
        genres: [String]
    ) async -> SurpriseMixResult {
        guard await isFoundationModelsAvailable() else {
            logger.info("Foundation Models unavailable, using fallback for surprise mix")
            return await fallbackSurpriseMix(availableTrackIDs: availableTrackIDs)
        }

        do {
            let session = try await getOrCreateSession()

            let listeningContext = ListeningPatternAnalyzer.buildContext(from: sessions)
            let trackContext = ListeningPatternAnalyzer.buildTrackContext(
                trackIDs: availableTrackIDs,
                genres: genres,
                recentlyPlayed: sessions.prefix(10).map(\.trackId)
            )

            let prompt = """
                User pressed "Surprise Me" - they want something unexpected and delightful!

                \(listeningContext)

                \(trackContext)

                Generate a fun, surprising mix with 7 tracks. Pick tracks that are:
                - Different from what they usually listen to
                - But still likely to please them based on their patterns
                - Use ONLY track UUIDs from the provided list
                """

            let response = try await session.respond(
                to: prompt,
                generating: SurpriseMixResult.self
            )

            logger.info("Generated surprise mix: \(response.content.mixTheme)")
            return response.content

        } catch {
            logger.error("Surprise mix generation failed: \(error.localizedDescription)")
            return await fallbackSurpriseMix(availableTrackIDs: availableTrackIDs)
        }
    }

    // MARK: - Fallbacks

    /// Rule-based fallback for time-based greeting
    public func fallbackTimeBasedGreeting(availableTrackIDs: [UUID]) async -> TimeBasedGreeting {
        let timePeriod = ListeningPatternAnalyzer.currentTimePeriod
        let selectedTracks = Array(availableTrackIDs.shuffled().prefix(5))

        return TimeBasedGreeting(
            greeting: timePeriod.greeting,
            trackIDs: selectedTracks,
            moodDescription: "A mix of your favorites"
        )
    }

    /// Rule-based fallback for surprise mix
    public func fallbackSurpriseMix(availableTrackIDs: [UUID]) async -> SurpriseMixResult {
        let selectedTracks = Array(availableTrackIDs.shuffled().prefix(7))

        let themes = [
            "A random selection from your library",
            "Mix things up with these tracks",
            "Something different for you",
            "Your surprise playlist"
        ]

        return SurpriseMixResult(
            greeting: "Here's a surprise for you!",
            trackIDs: selectedTracks,
            mixTheme: themes.randomElement() ?? "Surprise mix"
        )
    }

    // MARK: - Session Management

    private func getOrCreateSession() async throws -> LanguageModelSession {
        if let existingSession = session {
            return existingSession
        }

        let newSession = LanguageModelSession(
            instructions: """
                You are a music recommendation engine for a personal music library.
                Given listening patterns, time of day, and available tracks, suggest
                personalized playlists that match the user's mood and preferences.

                Always use ONLY the track UUIDs provided in the context.
                Keep responses focused on music recommendations.
                """
        )

        self.session = newSession
        return newSession
    }
}
