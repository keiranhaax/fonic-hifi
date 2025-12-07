// Fonic HiFi/Core/AI/Search/SmartSearchService.swift
import Foundation
import FoundationModels
import OSLog

/// Service for AI-enhanced semantic search
@MainActor
public final class SmartSearchService {

    // MARK: - Properties

    private let logger = Log.logger(.smartSearch)
    private var session: LanguageModelSession?

    // MARK: - Initialization

    public init() {}

    // MARK: - Availability

    /// Check if smart search (Foundation Models) is available
    public func isSmartSearchAvailable() async -> Bool {
        switch SystemLanguageModel.default.availability {
        case .available:
            return true
        case .unavailable:
            return false
        }
    }

    // MARK: - Smart Search

    /// Perform AI-enhanced semantic search
    /// - Parameters:
    ///   - query: User's search query (can be fuzzy/descriptive)
    ///   - sessions: Recent listening sessions for context
    ///   - availableTrackIDs: All track IDs in library
    ///   - trackMetadata: Array of track metadata for context
    /// - Returns: SmartSearchResult with ranked matches and explanations
    public func smartSearch(
        query: String,
        sessions: [ListeningSessionData],
        availableTrackIDs: [UUID],
        trackMetadata: [(id: UUID, title: String, artist: String, genre: String?)]
    ) async -> SmartSearchResult {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return SmartSearchResult(
                trackIDs: [],
                matchReasons: [],
                searchStrategy: "Empty query",
                suggestions: []
            )
        }

        guard await isSmartSearchAvailable() else {
            logger.info("Foundation Models unavailable, using fallback search")
            return await fallbackSearch(query: query, availableTrackIDs: availableTrackIDs)
        }

        do {
            let session = try await getOrCreateSession()

            let listeningContext = ListeningPatternAnalyzer.buildContext(from: sessions)
            let trackContext = buildTrackMetadataContext(trackMetadata)
            let timePeriod = ListeningPatternAnalyzer.currentTimePeriod

            let prompt = """
                User search query: "\(query)"

                Current time: \(timePeriod.greeting) (\(timePeriod.moodHint))

                \(listeningContext)

                Available tracks:
                \(trackContext)

                Find tracks that match the query. Consider:
                - Exact title/artist matches
                - Fuzzy/partial matches
                - Semantic meaning (e.g., "chill" = slow tempo, "upbeat" = energetic)
                - Time context (e.g., "from yesterday" = recently played)
                - Mood descriptions

                Return ONLY track UUIDs from the provided list.
                Explain why top matches are relevant.
                Suggest refined queries if results are limited.
                """

            let response = try await session.respond(
                to: prompt,
                generating: SmartSearchResult.self
            )

            logger.info("Smart search returned \(response.content.trackIDs.count) results")
            return response.content

        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .guardrailViolation:
                logger.warning("Guardrail violation in search, using fallback")
            case .exceededContextWindowSize:
                logger.warning("Context exceeded in search, using fallback")
            default:
                logger.error("Smart search failed: \(error.localizedDescription)")
            }
            return await fallbackSearch(query: query, availableTrackIDs: availableTrackIDs)
        } catch {
            logger.error("Smart search failed: \(error.localizedDescription)")
            return await fallbackSearch(query: query, availableTrackIDs: availableTrackIDs)
        }
    }

    // MARK: - Fallback

    /// Rule-based fallback when AI is unavailable
    /// Returns empty result to let standard search handle it
    public func fallbackSearch(
        query: String,
        availableTrackIDs: [UUID]
    ) async -> SmartSearchResult {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return SmartSearchResult(
                trackIDs: [],
                matchReasons: [],
                searchStrategy: "Empty query",
                suggestions: []
            )
        }

        // In fallback mode, return empty and let standard search handle it
        // This allows SearchView to use existing localizedStandardContains search
        return SmartSearchResult(
            trackIDs: [],
            matchReasons: [],
            searchStrategy: "Smart search unavailable - use standard search fallback",
            suggestions: [
                "Try exact track or artist name",
                "Browse by genre instead"
            ]
        )
    }

    // MARK: - Context Building

    private func buildTrackMetadataContext(
        _ metadata: [(id: UUID, title: String, artist: String, genre: String?)]
    ) -> String {
        // Limit to avoid context overflow
        let limited = metadata.prefix(100)

        var context = ""
        for track in limited {
            let genre = track.genre ?? "Unknown"
            context += "- \(track.id.uuidString): \"\(track.title)\" by \(track.artist) [\(genre)]\n"
        }
        return context
    }

    // MARK: - Session Management

    private func getOrCreateSession() async throws -> LanguageModelSession {
        if let existingSession = session {
            return existingSession
        }

        let newSession = LanguageModelSession(
            instructions: """
                You are a music search engine for a personal music library.
                Given a search query and available tracks, find the best matches.

                Consider:
                - Exact matches (title, artist)
                - Fuzzy/partial matches
                - Semantic meaning (mood, tempo, genre hints)
                - Context from listening history

                Always use ONLY the track UUIDs provided.
                Explain your matches clearly and concisely.
                """
        )

        self.session = newSession
        return newSession
    }
}
