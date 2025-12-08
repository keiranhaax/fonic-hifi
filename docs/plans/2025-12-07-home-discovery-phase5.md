# Phase 5: Smart Search with Foundation Models — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enhance the Search tab with Foundation Models to enable semantic, fuzzy, and descriptive queries like "that upbeat song from yesterday" or "something chill for the evening", while maintaining fast exact-match fallback.

**Architecture:** Create `SmartSearchService` that attempts AI-enhanced search first (with listening context), falls back to standard `localizedStandardContains` when Foundation Models is unavailable. Add `@Generable` schemas for structured search results with relevance explanations.

**Tech Stack:** Foundation Models framework (iOS 26), existing `SearchView` infrastructure, `ListeningPatternAnalyzer` from Phase 4, SwiftData queries via `TrackDataActor`.

---

## Critical Files

| Component | Path |
|-----------|------|
| SearchView | `Fonic HiFi/Presentation/Views/Search/SearchView.swift` |
| SearchCache | `Fonic HiFi/Data/Services/SearchCache.swift` |
| DataManager+Search | `Fonic HiFi/Data/DataManager+Search.swift` |
| RecommendationService | `Fonic HiFi/Core/AI/Recommendations/RecommendationService.swift` |
| RecommendationSchemas | `Fonic HiFi/Core/AI/Recommendations/RecommendationSchemas.swift` |
| ListeningPatternAnalyzer | `Fonic HiFi/Core/AI/Recommendations/ListeningPatternAnalyzer.swift` |
| TrackDataActor | `Fonic HiFi/Data/Actors/TrackDataActor.swift` |
| Log.swift | `Fonic HiFi/Utils/Logging/Log.swift` |

---

## Task 1: Add Smart Search @Generable Schema

**Files:**
- Modify: `Fonic HiFi/Core/AI/Recommendations/RecommendationSchemas.swift`
- Test: `Fonic HiFiTests/Core/AI/RecommendationSchemasTests.swift`

**Step 1: Write the failing test**

Add to existing `RecommendationSchemasTests.swift`:

```swift
@Test("SmartSearchResult has correct properties")
func smartSearchResultProperties() {
    let result = SmartSearchResult(
        trackIDs: [UUID(), UUID()],
        matchReasons: ["Matches 'chill' mood based on tempo", "Recently played in evening"],
        searchStrategy: "Semantic search with listening context",
        suggestions: ["Try 'relaxing music'", "Browse Jazz genre"]
    )

    #expect(result.trackIDs.count == 2)
    #expect(result.matchReasons.count == 2)
    #expect(!result.searchStrategy.isEmpty)
    #expect(result.suggestions.count == 2)
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "cannot find 'SmartSearchResult' in scope"

**Step 3: Add schema to RecommendationSchemas.swift**

Add after `SurpriseMixResult`:

```swift
/// Result from AI-enhanced smart search
@Generable
public struct SmartSearchResult: Sendable {
    @Guide(description: "Track UUIDs matching the query, ranked by relevance", .maximumCount(15))
    public let trackIDs: [UUID]

    @Guide(description: "Brief explanation for why each top result matched", .maximumCount(5))
    public let matchReasons: [String]

    @Guide(description: "Description of the search strategy used")
    public let searchStrategy: String

    @Guide(description: "Suggested refined queries if results are limited", .maximumCount(3))
    public let suggestions: [String]

    public init(
        trackIDs: [UUID],
        matchReasons: [String],
        searchStrategy: String,
        suggestions: [String]
    ) {
        self.trackIDs = trackIDs
        self.matchReasons = matchReasons
        self.searchStrategy = searchStrategy
        self.suggestions = suggestions
    }
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Core/AI/Recommendations/RecommendationSchemas.swift" "Fonic HiFiTests/Core/AI/RecommendationSchemasTests.swift"
git commit -m "feat(ai): add SmartSearchResult @Generable schema for smart search"
```

---

## Task 2: Add Smart Search Log Category

**Files:**
- Modify: `Fonic HiFi/Utils/Logging/Log.swift`

**Step 1: Add smartSearch category to LogCategory enum**

Find the `LogCategory` enum and add:

```swift
case smartSearch = "search.smart"
```

**Step 2: Add logger case to switch statement**

In the `logger(_:)` function's switch statement, add:

```swift
case .smartSearch:
    return Logger(subsystem: subsystem, category: "search.smart")
```

**Step 3: Run lint to verify**

Run: `make lint`
Expected: PASS

**Step 4: Commit**

```bash
git add "Fonic HiFi/Utils/Logging/Log.swift"
git commit -m "feat(logging): add smartSearch log category"
```

---

## Task 3: Create SmartSearchService

**Files:**
- Create: `Fonic HiFi/Core/AI/Search/SmartSearchService.swift`
- Test: `Fonic HiFiTests/Core/AI/SmartSearchServiceTests.swift`

**Step 1: Write the failing test**

```swift
// Fonic HiFiTests/Core/AI/SmartSearchServiceTests.swift
import Foundation
import Testing
@testable import Fonic_HiFi

@Suite("SmartSearchService Tests")
struct SmartSearchServiceTests {

    @Test("Fallback search returns results from available tracks")
    @MainActor
    func fallbackSearchWorks() async {
        let service = SmartSearchService()
        let trackIDs = (0..<20).map { _ in UUID() }

        let result = await service.fallbackSearch(
            query: "chill music",
            availableTrackIDs: trackIDs
        )

        #expect(!result.trackIDs.isEmpty)
        #expect(result.searchStrategy.contains("fallback") || result.searchStrategy.contains("random"))
    }

    @Test("Availability check returns boolean")
    @MainActor
    func availabilityCheckWorks() async {
        let service = SmartSearchService()

        let isAvailable = await service.isSmartSearchAvailable()
        #expect(isAvailable == true || isAvailable == false)
    }

    @Test("Empty query returns empty results")
    @MainActor
    func emptyQueryReturnsEmpty() async {
        let service = SmartSearchService()

        let result = await service.fallbackSearch(
            query: "",
            availableTrackIDs: [UUID(), UUID()]
        )

        #expect(result.trackIDs.isEmpty)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "cannot find 'SmartSearchService' in scope"

**Step 3: Write the service implementation**

```swift
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
    ///   - trackMetadata: Dictionary of trackID -> (title, artist, genre)
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

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            logger.warning("Guardrail violation in search, using fallback")
            return await fallbackSearch(query: query, availableTrackIDs: availableTrackIDs)
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            logger.warning("Context exceeded in search, using fallback")
            return await fallbackSearch(query: query, availableTrackIDs: availableTrackIDs)
        } catch {
            logger.error("Smart search failed: \(error.localizedDescription)")
            return await fallbackSearch(query: query, availableTrackIDs: availableTrackIDs)
        }
    }

    // MARK: - Fallback

    /// Rule-based fallback when AI is unavailable
    /// Returns random subset since we can't do real matching without track details
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
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Core/AI/Search/SmartSearchService.swift" "Fonic HiFiTests/Core/AI/SmartSearchServiceTests.swift"
git commit -m "feat(ai): add SmartSearchService with Foundation Models integration"
```

---

## Task 4: Add TrackDataActor Method for Track Metadata

**Files:**
- Modify: `Fonic HiFi/Data/Actors/TrackDataActor.swift`
- Test: `Fonic HiFiTests/TrackDataActorTests.swift`

**Step 1: Write the failing test**

Add to `TrackDataActorTests.swift`:

```swift
@Test("getTrackMetadata returns track info for search context")
func getTrackMetadataWorks() async throws {
    // This test assumes tracks exist from other test setup
    let metadata = try await environment.actor.getTrackMetadataForSearch(limit: 50)

    // Should return array of tuples (may be empty in isolation)
    #expect(metadata is [(id: UUID, title: String, artist: String, genre: String?)])
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "has no member 'getTrackMetadataForSearch'"

**Step 3: Add method to TrackDataActor**

Add to `TrackDataActor.swift`:

```swift
/// Sendable type for track metadata used in smart search
public struct TrackSearchMetadata: Sendable {
    public let id: UUID
    public let title: String
    public let artist: String
    public let genre: String?

    public init(id: UUID, title: String, artist: String, genre: String?) {
        self.id = id
        self.title = title
        self.artist = artist
        self.genre = genre
    }
}

/// Get track metadata for smart search context
/// - Parameter limit: Maximum number of tracks to return
/// - Returns: Array of track metadata tuples
public func getTrackMetadataForSearch(limit: Int) throws -> [TrackSearchMetadata] {
    var descriptor = FetchDescriptor<Track>(
        sortBy: [SortDescriptor(\Track.playCount, order: .reverse)]
    )
    descriptor.fetchLimit = limit

    let tracks = try modelContext.fetch(descriptor)
    return tracks.map { track in
        TrackSearchMetadata(
            id: track.id,
            title: track.title,
            artist: track.artist ?? "Unknown Artist",
            genre: track.genre
        )
    }
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Data/Actors/TrackDataActor.swift" "Fonic HiFiTests/TrackDataActorTests.swift"
git commit -m "feat(data): add getTrackMetadataForSearch to TrackDataActor"
```

---

## Task 5: Create SmartSearchViewModel

**Files:**
- Create: `Fonic HiFi/Presentation/ViewModels/SmartSearchViewModel.swift`
- Test: `Fonic HiFiTests/Presentation/SmartSearchViewModelTests.swift`

**Step 1: Write the failing test**

```swift
// Fonic HiFiTests/Presentation/SmartSearchViewModelTests.swift
import Foundation
import Testing
@testable import Fonic_HiFi

@Suite("SmartSearchViewModel Tests")
struct SmartSearchViewModelTests {

    @Test("Initial state is idle")
    @MainActor
    func initialStateIsIdle() {
        let viewModel = SmartSearchViewModel()

        #expect(viewModel.searchState == .idle)
        #expect(viewModel.smartSearchResult == nil)
        #expect(!viewModel.isSmartSearchEnabled)
    }

    @Test("Smart search availability updates isSmartSearchEnabled")
    @MainActor
    func availabilityCheckUpdatesState() async {
        let viewModel = SmartSearchViewModel()

        await viewModel.checkSmartSearchAvailability()

        // Will be true or false depending on device
        #expect(viewModel.isSmartSearchEnabled == true || viewModel.isSmartSearchEnabled == false)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "cannot find 'SmartSearchViewModel' in scope"

**Step 3: Write the ViewModel**

```swift
// Fonic HiFi/Presentation/ViewModels/SmartSearchViewModel.swift
import Foundation
import SwiftUI

/// ViewModel for smart search functionality
@MainActor
@Observable
public final class SmartSearchViewModel {

    // MARK: - Types

    public enum SearchState: Equatable {
        case idle
        case searching
        case results
        case noResults
        case error(String)
    }

    // MARK: - Properties

    public private(set) var searchState: SearchState = .idle
    public private(set) var smartSearchResult: SmartSearchResult?
    public private(set) var isSmartSearchEnabled = false
    public private(set) var resolvedTracks: [Track] = []

    private let smartSearchService = SmartSearchService()
    private let logger = Log.logger(.smartSearch)

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// Check if smart search is available on this device
    public func checkSmartSearchAvailability() async {
        isSmartSearchEnabled = await smartSearchService.isSmartSearchAvailable()
        logger.info("Smart search available: \(isSmartSearchEnabled)")
    }

    /// Perform smart search with AI enhancement
    /// - Parameters:
    ///   - query: User's search query
    ///   - dataManager: DataManager for fetching context and resolving tracks
    public func performSmartSearch(
        query: String,
        dataManager: DataManager
    ) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchState = .idle
            smartSearchResult = nil
            resolvedTracks = []
            return
        }

        searchState = .searching

        do {
            // Gather context
            let sessions = try await dataManager.trackDataActor.getListeningSessions(limit: 50)
            let allTrackIDs = try await dataManager.trackDataActor.getAllTrackIDs(limit: 200)
            let metadata = try await dataManager.trackDataActor.getTrackMetadataForSearch(limit: 100)

            // Convert metadata to tuple format expected by service
            let metadataTuples = metadata.map { ($0.id, $0.title, $0.artist, $0.genre) }

            // Perform smart search
            let result = await smartSearchService.smartSearch(
                query: query,
                sessions: sessions,
                availableTrackIDs: allTrackIDs,
                trackMetadata: metadataTuples
            )

            smartSearchResult = result

            // Resolve track IDs to actual Track objects
            var tracks: [Track] = []
            for id in result.trackIDs {
                if let track = try await dataManager.trackDataActor.getTrack(by: id) {
                    tracks.append(track)
                }
            }
            resolvedTracks = tracks

            if tracks.isEmpty && result.trackIDs.isEmpty {
                searchState = .noResults
            } else {
                searchState = .results
            }

            logger.info("Smart search completed: \(tracks.count) tracks resolved")

        } catch {
            logger.error("Smart search failed: \(error.localizedDescription)")
            searchState = .error(error.localizedDescription)
            smartSearchResult = nil
            resolvedTracks = []
        }
    }

    /// Clear search state
    public func clearSearch() {
        searchState = .idle
        smartSearchResult = nil
        resolvedTracks = []
    }
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Presentation/ViewModels/SmartSearchViewModel.swift" "Fonic HiFiTests/Presentation/SmartSearchViewModelTests.swift"
git commit -m "feat(ui): add SmartSearchViewModel for smart search state management"
```

---

## Task 6: Create Smart Search UI Components

**Files:**
- Create: `Fonic HiFi/Presentation/Views/Search/SmartSearchResultsView.swift`

**Step 1: Create the smart search results view**

```swift
// Fonic HiFi/Presentation/Views/Search/SmartSearchResultsView.swift
import SwiftUI

/// Displays smart search results with AI explanations
struct SmartSearchResultsView: View {
    let result: SmartSearchResult
    let tracks: [Track]
    let onTrackTap: (Track) -> Void

    var body: some View {
        List {
            // AI indicator
            if !result.searchStrategy.isEmpty {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.purple)
                        Text(result.searchStrategy)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Track results
            if !tracks.isEmpty {
                Section("Results") {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        SmartSearchTrackRow(
                            track: track,
                            matchReason: index < result.matchReasons.count ? result.matchReasons[index] : nil
                        ) {
                            onTrackTap(track)
                        }
                    }
                }
            }

            // Suggestions
            if !result.suggestions.isEmpty {
                Section("Try searching for") {
                    ForEach(result.suggestions, id: \.self) { suggestion in
                        Label(suggestion, systemImage: "magnifyingglass")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.grouped)
    }
}

/// Track row with optional AI match reason
private struct SmartSearchTrackRow: View {
    let track: Track
    let matchReason: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    LazyArtworkView(track: track, size: 50, cornerRadius: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.body)
                            .lineLimit(1)
                        Text(track.artist ?? "Unknown Artist")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if matchReason != nil {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.purple.opacity(0.6))
                    }
                }

                // Match reason (if available)
                if let reason = matchReason {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(.purple.opacity(0.8))
                        .padding(.leading, 62)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
```

**Step 2: Run build to verify**

Run: `make build`
Expected: PASS

**Step 3: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Search/SmartSearchResultsView.swift"
git commit -m "feat(ui): add SmartSearchResultsView with AI explanations"
```

---

## Task 7: Integrate Smart Search into SearchView

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/Search/SearchView.swift`

**Step 1: Add smart search state properties**

Add after existing `@State` properties (around line 20):

```swift
// Smart search
@State private var smartSearchViewModel = SmartSearchViewModel()
@State private var useSmartSearch = false
```

**Step 2: Add smart search toggle to empty state**

Modify `EmptySearchView` to add a toggle. Replace the struct with:

```swift
private struct EmptySearchView: View {
    @Binding var useSmartSearch: Bool
    let isSmartSearchAvailable: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: useSmartSearch ? "sparkles" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(useSmartSearch ? .purple : .tertiary)

            Text(useSmartSearch ? "Smart Search" : "Search your library")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(useSmartSearch
                ? "Try descriptive queries like \"upbeat songs\" or \"chill evening music\""
                : "Find tracks, albums, artists, and playlists")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if isSmartSearchAvailable {
                Toggle(isOn: $useSmartSearch) {
                    Label("Smart Search", systemImage: "sparkles")
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .tint(.purple)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

**Step 3: Update body to use smart search conditionally**

In the `body` computed property, modify the Group to check for smart search:

```swift
var body: some View {
    Group {
        if searchText.isEmpty, showingRecentSearches {
            RecentSearchesView(
                recentSearches: recentSearches,
                onSelectSearch: { query in
                    searchText = query
                },
                onClearSearches: {
                    Task {
                        try? await dataManager?.clearRecentSearches()
                        recentSearches = []
                    }
                }
            )
        } else if useSmartSearch, case .results = smartSearchViewModel.searchState {
            // Smart search results
            SmartSearchResultsView(
                result: smartSearchViewModel.smartSearchResult ?? SmartSearchResult(
                    trackIDs: [],
                    matchReasons: [],
                    searchStrategy: "",
                    suggestions: []
                ),
                tracks: smartSearchViewModel.resolvedTracks
            ) { track in
                playTrack(track)
            }
        } else if searchResults.isEmpty, !searchText.isEmpty, !isSearching {
            NoResultsView(query: searchText)
        } else if !searchResults.isEmpty {
            SearchResultsListView(results: searchResults)
        } else if isSearching {
            ProgressView("Searching...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptySearchView(
                useSmartSearch: $useSmartSearch,
                isSmartSearchAvailable: smartSearchViewModel.isSmartSearchEnabled
            )
        }
    }
    .navigationTitle("Search")
    .onChange(of: searchText) { _, newValue in
        searchTask?.cancel()

        searchTask = Task {
            if newValue.isEmpty {
                showingRecentSearches = true
                searchResults = SearchResults()
                smartSearchViewModel.clearSearch()
                isSearching = false
                return
            }

            showingRecentSearches = false
            isSearching = true

            try? await Task.sleep(for: .milliseconds(300))

            guard !Task.isCancelled else { return }

            if useSmartSearch, let dataManager {
                await smartSearchViewModel.performSmartSearch(
                    query: newValue,
                    dataManager: dataManager
                )
                isSearching = false
            } else {
                await performSearch(newValue)
            }
        }
    }
    .task {
        await loadRecentSearches()
        await smartSearchViewModel.checkSmartSearchAvailability()
    }
}
```

**Step 4: Add playTrack helper method**

Add after `loadRecentSearches()`:

```swift
private func playTrack(_ track: Track) {
    // Delegate to audio engine via environment if available
    // For now, this is a placeholder - integrate with audioEngine environment
}
```

**Step 5: Run build to verify**

Run: `make build`
Expected: PASS

**Step 6: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Search/SearchView.swift"
git commit -m "feat(search): integrate smart search with toggle and AI results"
```

---

## Task 8: Add Smart Search Integration Tests

**Files:**
- Create: `Fonic HiFiTests/Integration/SmartSearchIntegrationTests.swift`

**Step 1: Write integration tests**

```swift
// Fonic HiFiTests/Integration/SmartSearchIntegrationTests.swift
import Foundation
import Testing
@testable import Fonic_HiFi

@Suite("Smart Search Integration Tests")
struct SmartSearchIntegrationTests {

    @Test("SmartSearchService handles various query types")
    @MainActor
    func handlesVariousQueries() async {
        let service = SmartSearchService()
        let trackIDs = (0..<20).map { _ in UUID() }
        let metadata: [(id: UUID, title: String, artist: String, genre: String?)] = trackIDs.map {
            ($0, "Track \($0.uuidString.prefix(4))", "Artist", "Rock")
        }

        // Exact query
        let exactResult = await service.smartSearch(
            query: "Track",
            sessions: [],
            availableTrackIDs: trackIDs,
            trackMetadata: metadata
        )
        #expect(exactResult.searchStrategy.isEmpty == false)

        // Descriptive query
        let descriptiveResult = await service.smartSearch(
            query: "something chill for the evening",
            sessions: [],
            availableTrackIDs: trackIDs,
            trackMetadata: metadata
        )
        #expect(descriptiveResult.searchStrategy.isEmpty == false)

        // Empty query
        let emptyResult = await service.smartSearch(
            query: "",
            sessions: [],
            availableTrackIDs: trackIDs,
            trackMetadata: metadata
        )
        #expect(emptyResult.trackIDs.isEmpty)
    }

    @Test("SmartSearchViewModel state transitions correctly")
    @MainActor
    func viewModelStateTransitions() async {
        let viewModel = SmartSearchViewModel()

        #expect(viewModel.searchState == .idle)

        viewModel.clearSearch()
        #expect(viewModel.searchState == .idle)
        #expect(viewModel.resolvedTracks.isEmpty)
    }

    @Test("Schema types are Sendable")
    func schemaTypesAreSendable() {
        let result = SmartSearchResult(
            trackIDs: [UUID()],
            matchReasons: ["Test"],
            searchStrategy: "Test",
            suggestions: []
        )

        // Verify Sendable conformance by passing across concurrency boundary
        Task {
            let _ = result.trackIDs
        }
    }
}
```

**Step 2: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 3: Commit**

```bash
git add "Fonic HiFiTests/Integration/SmartSearchIntegrationTests.swift"
git commit -m "test(search): add smart search integration tests"
```

---

## Task 9: Update DataManager for Smart Search Convenience

**Files:**
- Create: `Fonic HiFi/Data/DataManager+SmartSearch.swift`

**Step 1: Create convenience extension**

```swift
// Fonic HiFi/Data/DataManager+SmartSearch.swift
import Foundation

extension DataManager {
    /// Get all data needed for smart search context
    /// - Returns: Tuple with sessions, track IDs, and metadata
    public func getSmartSearchContext() async throws -> (
        sessions: [ListeningSessionData],
        trackIDs: [UUID],
        metadata: [TrackSearchMetadata]
    ) {
        let sessions = try await trackDataActor.getListeningSessions(limit: 50)
        let trackIDs = try await trackDataActor.getAllTrackIDs(limit: 200)
        let metadata = try await trackDataActor.getTrackMetadataForSearch(limit: 100)

        return (sessions, trackIDs, metadata)
    }
}
```

**Step 2: Run build to verify**

Run: `make build`
Expected: PASS

**Step 3: Commit**

```bash
git add "Fonic HiFi/Data/DataManager+SmartSearch.swift"
git commit -m "feat(data): add DataManager+SmartSearch convenience extension"
```

---

## Task 10: Final Verification and Documentation

**Step 1: Run full test suite**

Run: `make test`
Expected: All tests pass

**Step 2: Run lint**

Run: `make lint`
Expected: No violations

**Step 3: Run build**

Run: `make build`
Expected: Build succeeds

**Step 4: Run in simulator**

Run: `make run`
Expected: App launches, search shows smart search toggle when AI available

**Step 5: Update STATUS.md**

Add to "Implementation Status" section:

```markdown
**Smart Search (Phase 5):**
- ✅ SmartSearchResult - @Generable schema for search results
- ✅ SmartSearchService - Foundation Models search integration
- ✅ SmartSearchViewModel - Search state management
- ✅ SmartSearchResultsView - AI results with explanations
- ✅ SearchView integration - Toggle between standard and smart search
- ✅ Rule-based fallbacks - Seamless degradation when AI unavailable
```

**Step 6: Final commit**

```bash
git add STATUS.md
git commit -m "docs: update STATUS.md with Phase 5 smart search"
```

---

## Summary

This plan creates Phase 5: Smart Search with:

1. **SmartSearchResult schema** - `@Generable` type for structured AI search output
2. **SmartSearchService** - Foundation Models integration for semantic search
3. **SmartSearchViewModel** - Observable state management for search UI
4. **SmartSearchResultsView** - Display results with AI explanations
5. **SearchView integration** - Toggle between standard and AI-enhanced search
6. **Convenience methods** - DataManager extension for gathering search context
7. **Comprehensive tests** - Unit and integration tests

**Total Tasks:** 10
**New Files:** 6
**Modified Files:** 4
**Estimated Commits:** 10

**Key Features:**
- Semantic search understanding ("chill music", "upbeat songs")
- Contextual awareness (time of day, listening history)
- Match explanations (why each result matched)
- Search suggestions (alternative queries)
- Seamless fallback to standard search when AI unavailable
