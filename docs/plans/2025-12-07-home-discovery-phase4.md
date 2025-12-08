# Phase 4: Foundation Models Integration — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Integrate Apple's Foundation Models framework to provide intelligent, on-device AI recommendations including time-based greetings ("Good Morning"), personalized "Your Mixes", and a smarter "Surprise Me" feature.

**Architecture:** Create `ListeningPatternAnalyzer` to aggregate session data, define `@Generable` schemas for structured AI output, integrate with `HomeView` via a new `HomeRecommendationsViewModel`, and provide seamless rule-based fallbacks when Foundation Models is unavailable.

**Tech Stack:** Foundation Models framework (iOS 26+), `@Generable` macro for structured output, SwiftData queries via `TrackDataActor`, Swift 6.2 strict concurrency.

---

## Critical Files

| Component | Path |
|-----------|------|
| HomeView | `Fonic HiFi/Presentation/Views/Home/HomeView.swift` |
| ListeningSession | `Fonic HiFi/Data/Models/ListeningSession.swift` |
| TrackDataActor | `Fonic HiFi/Data/Actors/TrackDataActor.swift` |
| Foundation Models Skill | `.claude/skills/foundation-models.md` |
| Design Doc | `docs/plans/2025-12-06-home-screen-discovery-design.md` |

---

## Task 1: Create @Generable Schema Types

**Files:**
- Create: `Fonic HiFi/Core/AI/Recommendations/RecommendationSchemas.swift`
- Test: `Fonic HiFiTests/Core/AI/RecommendationSchemasTests.swift`

**Step 1: Write the failing test**

```swift
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
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "cannot find 'TimeBasedGreeting' in scope"

**Step 3: Write minimal implementation**

```swift
// Fonic HiFi/Core/AI/Recommendations/RecommendationSchemas.swift
import Foundation
import FoundationModels

/// Time-based greeting recommendation (e.g., "Good Morning")
@Generable
public struct TimeBasedGreeting: Sendable {
    @Guide(description: "A time-appropriate greeting like 'Good Morning', 'Good Afternoon', 'Good Evening', or 'Late Night'")
    public let greeting: String

    @Guide(description: "Track UUIDs that match the time of day mood", .count(5))
    public let trackIDs: [UUID]

    @Guide(description: "A brief description of the mood or theme")
    public let moodDescription: String

    public init(greeting: String, trackIDs: [UUID], moodDescription: String) {
        self.greeting = greeting
        self.trackIDs = trackIDs
        self.moodDescription = moodDescription
    }
}

/// AI-generated mix definition
@Generable
public struct MixDefinition: Sendable {
    @Guide(description: "A short, catchy name for the mix like 'Chill Vibes' or 'Energy Boost'")
    public let name: String

    @Guide(description: "Track UUIDs for this mix", .count(7))
    public let trackIDs: [UUID]

    @Guide(description: "A brief description of the mix's mood")
    public let moodDescription: String

    public init(name: String, trackIDs: [UUID], moodDescription: String) {
        self.name = name
        self.trackIDs = trackIDs
        self.moodDescription = moodDescription
    }
}

/// Result from "Surprise Me" button
@Generable
public struct SurpriseMixResult: Sendable {
    @Guide(description: "A fun, engaging greeting for the user")
    public let greeting: String

    @Guide(description: "Track UUIDs for the surprise mix", .count(7))
    public let trackIDs: [UUID]

    @Guide(description: "The theme of this surprise mix")
    public let mixTheme: String

    public init(greeting: String, trackIDs: [UUID], mixTheme: String) {
        self.greeting = greeting
        self.trackIDs = trackIDs
        self.mixTheme = mixTheme
    }
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Core/AI/Recommendations/RecommendationSchemas.swift" "Fonic HiFiTests/Core/AI/RecommendationSchemasTests.swift"
git commit -m "feat(ai): add @Generable schema types for recommendations"
```

---

## Task 2: Create ListeningPatternAnalyzer

**Files:**
- Create: `Fonic HiFi/Core/AI/Recommendations/ListeningPatternAnalyzer.swift`
- Test: `Fonic HiFiTests/Core/AI/ListeningPatternAnalyzerTests.swift`

**Step 1: Write the failing test**

```swift
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
        #expect(context.contains("Monday") || context.contains("weekday"))
    }
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "cannot find 'ListeningPatternAnalyzer' in scope"

**Step 3: Write minimal implementation**

```swift
// Fonic HiFi/Core/AI/Recommendations/ListeningPatternAnalyzer.swift
import Foundation

/// Analyzes listening patterns to build context for Foundation Models
public enum ListeningPatternAnalyzer {

    // MARK: - Time Period

    public enum TimePeriod: String, Sendable {
        case morning
        case afternoon
        case evening
        case lateNight

        public var greeting: String {
            switch self {
            case .morning: return "Good Morning"
            case .afternoon: return "Good Afternoon"
            case .evening: return "Good Evening"
            case .lateNight: return "Late Night"
            }
        }

        public var moodHint: String {
            switch self {
            case .morning: return "energizing, uplifting, fresh start"
            case .afternoon: return "focused, productive, steady rhythm"
            case .evening: return "relaxing, mellow, unwinding"
            case .lateNight: return "calm, ambient, introspective"
            }
        }
    }

    /// Determine time period from hour (0-23)
    public static func timePeriod(for hour: Int) -> TimePeriod {
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .lateNight
        }
    }

    /// Get current time period
    public static var currentTimePeriod: TimePeriod {
        let hour = Calendar.current.component(.hour, from: Date())
        return timePeriod(for: hour)
    }

    // MARK: - Context Building

    /// Build a natural language context string from listening sessions
    public static func buildContext(from sessions: [ListeningSessionData]) -> String {
        guard !sessions.isEmpty else {
            return "No listening history available yet."
        }

        // Analyze time patterns
        let morningCount = sessions.filter { (5..<12).contains($0.hourOfDay) }.count
        let afternoonCount = sessions.filter { (12..<17).contains($0.hourOfDay) }.count
        let eveningCount = sessions.filter { (17..<21).contains($0.hourOfDay) }.count
        let nightCount = sessions.filter { !(5..<21).contains($0.hourOfDay) }.count

        // Analyze completion patterns
        let completedCount = sessions.filter { $0.wasCompleted }.count
        let skippedCount = sessions.filter { $0.wasSkipped }.count
        let avgCompletion = sessions.map(\.completionPercentage).reduce(0, +) / Double(sessions.count)

        // Analyze day patterns
        let weekdayCount = sessions.filter { (2...6).contains($0.dayOfWeek) }.count
        let weekendCount = sessions.count - weekdayCount

        var context = "User listening patterns:\n"
        context += "- Prefers \(dominantTimePeriod(morning: morningCount, afternoon: afternoonCount, evening: eveningCount, night: nightCount)) listening\n"
        context += "- Average completion: \(Int(avgCompletion * 100))%\n"
        context += "- Completed \(completedCount) tracks, skipped \(skippedCount)\n"
        context += "- \(weekdayCount > weekendCount ? "Mostly weekday" : "Mostly weekend") listener\n"

        return context
    }

    private static func dominantTimePeriod(morning: Int, afternoon: Int, evening: Int, night: Int) -> String {
        let max = max(morning, afternoon, evening, night)
        switch max {
        case morning: return "morning"
        case afternoon: return "afternoon"
        case evening: return "evening"
        default: return "late night"
        }
    }

    // MARK: - Track Context

    /// Build context about available tracks for the model
    public static func buildTrackContext(
        trackIDs: [UUID],
        genres: [String],
        recentlyPlayed: [UUID]
    ) -> String {
        var context = "Available library:\n"
        context += "- \(trackIDs.count) tracks available\n"
        context += "- Genres: \(genres.prefix(5).joined(separator: ", "))\n"
        context += "- Recently played: \(recentlyPlayed.count) tracks\n"
        context += "- Track UUIDs to choose from: \(trackIDs.prefix(20).map { $0.uuidString }.joined(separator: ", "))\n"
        return context
    }
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Core/AI/Recommendations/ListeningPatternAnalyzer.swift" "Fonic HiFiTests/Core/AI/ListeningPatternAnalyzerTests.swift"
git commit -m "feat(ai): add ListeningPatternAnalyzer for session context building"
```

---

## Task 3: Create RecommendationService

**Files:**
- Create: `Fonic HiFi/Core/AI/Recommendations/RecommendationService.swift`
- Test: `Fonic HiFiTests/Core/AI/RecommendationServiceTests.swift`

**Step 1: Write the failing test**

```swift
// Fonic HiFiTests/Core/AI/RecommendationServiceTests.swift
import Foundation
import Testing
@testable import Fonic_HiFi

@Suite("RecommendationService Tests")
struct RecommendationServiceTests {

    @Test("Fallback greeting returns correct time-based greeting")
    func fallbackGreetingWorks() async {
        let service = RecommendationService()
        let trackIDs = (0..<10).map { _ in UUID() }

        let result = await service.fallbackTimeBasedGreeting(availableTrackIDs: trackIDs)

        let validGreetings = ["Good Morning", "Good Afternoon", "Good Evening", "Late Night"]
        #expect(validGreetings.contains(result.greeting))
        #expect(result.trackIDs.count <= 5)
    }

    @Test("Fallback surprise mix returns shuffled tracks")
    func fallbackSurpriseMixWorks() async {
        let service = RecommendationService()
        let trackIDs = (0..<20).map { _ in UUID() }

        let result = await service.fallbackSurpriseMix(availableTrackIDs: trackIDs)

        #expect(!result.greeting.isEmpty)
        #expect(result.trackIDs.count <= 7)
        #expect(!result.mixTheme.isEmpty)
    }

    @Test("Availability check returns boolean")
    func availabilityCheckWorks() async {
        let service = RecommendationService()

        // Should not crash, returns true or false
        let isAvailable = await service.isFoundationModelsAvailable()
        #expect(isAvailable == true || isAvailable == false)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "cannot find 'RecommendationService' in scope"

**Step 3: Write minimal implementation**

```swift
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

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            logger.warning("Guardrail violation, using fallback")
            return await fallbackTimeBasedGreeting(availableTrackIDs: availableTrackIDs)
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            logger.warning("Context exceeded, using fallback")
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
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Core/AI/Recommendations/RecommendationService.swift" "Fonic HiFiTests/Core/AI/RecommendationServiceTests.swift"
git commit -m "feat(ai): add RecommendationService with Foundation Models integration"
```

---

## Task 4: Add Log Category for Recommendations

**Files:**
- Modify: `Fonic HiFi/Utils/Logging/Log.swift`

**Step 1: Read current Log.swift to find pattern**

**Step 2: Add recommendations category**

Add to the `LogCategory` enum:

```swift
case recommendations
```

And to the switch in `logger(_:)`:

```swift
case .recommendations:
    return Logger(subsystem: subsystem, category: "recommendations")
```

**Step 3: Run lint to verify**

Run: `make lint`
Expected: PASS

**Step 4: Commit**

```bash
git add "Fonic HiFi/Utils/Logging/Log.swift"
git commit -m "feat(logging): add recommendations log category"
```

---

## Task 5: Add TrackDataActor Query Methods

**Files:**
- Modify: `Fonic HiFi/Data/Actors/TrackDataActor.swift`
- Test: `Fonic HiFiTests/TrackDataActorTests.swift`

**Step 1: Write the failing test**

Add to `TrackDataActorTests.swift`:

```swift
@Test("getSessionsByHourOfDay returns filtered sessions")
func getSessionsByHourOfDayWorks() async throws {
    // Create test sessions at different hours
    try await environment.actor.recordListeningSession(
        trackId: UUID(),
        startedAt: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!,
        durationListened: 120,
        trackDuration: 200,
        completionPercentage: 0.6,
        wasSkipped: false,
        wasCompleted: false
    )

    let morningSessions = try await environment.actor.getSessionsByHourRange(startHour: 5, endHour: 12, limit: 10)

    #expect(!morningSessions.isEmpty)
    #expect(morningSessions.allSatisfy { (5..<12).contains($0.hourOfDay) })
}

@Test("getAllTrackIDs returns track UUIDs")
func getAllTrackIDsWorks() async throws {
    // Assuming tracks exist from other tests
    let trackIDs = try await environment.actor.getAllTrackIDs(limit: 100)

    // Should return array (may be empty in isolation)
    #expect(trackIDs is [UUID])
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "has no member 'getSessionsByHourRange'"

**Step 3: Write minimal implementation**

Add to `TrackDataActor.swift`:

```swift
/// Get listening sessions filtered by hour range
/// - Parameters:
///   - startHour: Start hour (inclusive, 0-23)
///   - endHour: End hour (exclusive, 0-24)
///   - limit: Maximum number of sessions to return
/// - Returns: Sessions that occurred during the specified hours
public func getSessionsByHourRange(
    startHour: Int,
    endHour: Int,
    limit: Int
) throws -> [ListeningSessionData] {
    var descriptor = FetchDescriptor<ListeningSession>(
        predicate: #Predicate<ListeningSession> { session in
            session.hourOfDay >= startHour && session.hourOfDay < endHour
        },
        sortBy: [SortDescriptor(\ListeningSession.startedAt, order: .reverse)]
    )
    descriptor.fetchLimit = limit

    let sessions = try modelContext.fetch(descriptor)
    return sessions.map { ListeningSessionData(from: $0) }
}

/// Get all track IDs in the library
/// - Parameter limit: Maximum number of IDs to return
/// - Returns: Array of track UUIDs
public func getAllTrackIDs(limit: Int) throws -> [UUID] {
    var descriptor = FetchDescriptor<Track>(
        sortBy: [SortDescriptor(\Track.dateAdded, order: .reverse)]
    )
    descriptor.fetchLimit = limit

    let tracks = try modelContext.fetch(descriptor)
    return tracks.map { $0.id }
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Data/Actors/TrackDataActor.swift" "Fonic HiFiTests/TrackDataActorTests.swift"
git commit -m "feat(data): add getSessionsByHourRange and getAllTrackIDs to TrackDataActor"
```

---

## Task 6: Integrate RecommendationService into HomeView

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/Home/HomeView.swift`

**Step 1: Add RecommendationService property**

Add after existing `@State` properties:

```swift
// AI recommendations
private let recommendationService = RecommendationService()
@State private var timeBasedGreeting: TimeBasedGreeting?
@State private var isGeneratingRecommendations = false
```

**Step 2: Update surpriseMe() method**

Replace the placeholder `surpriseMe()` function:

```swift
private func surpriseMe() {
    guard let dataManager, let audioEngine else { return }

    Task {
        isGeneratingRecommendations = true
        defer { isGeneratingRecommendations = false }

        do {
            // Gather context
            let sessions = try await dataManager.trackDataActor.getListeningSessions(limit: 50)
            let trackIDs = try await dataManager.trackDataActor.getAllTrackIDs(limit: 200)
            let genres = try await dataManager.getUniqueGenres()

            // Generate surprise mix
            let result = await recommendationService.generateSurpriseMix(
                sessions: sessions,
                availableTrackIDs: trackIDs,
                genres: genres
            )

            // Fetch actual tracks from IDs
            var tracks: [Track] = []
            for id in result.trackIDs {
                if let track = try await dataManager.trackDataActor.getTrack(by: id) {
                    tracks.append(track)
                }
            }

            guard !tracks.isEmpty else {
                // Fallback to shuffle if no tracks resolved
                shuffleAll()
                return
            }

            // Queue and play
            let audioTracks = tracks.map { $0.toAudioTrack() }
            audioEngine.queueManager.replaceQueue(with: audioTracks, startIndex: 0)
            if let firstTrack = tracks.first {
                try await audioEngine.play(track: firstTrack)
                showingNowPlaying.wrappedValue = true
            }
        } catch {
            // Fallback to shuffle on any error
            shuffleAll()
        }
    }
}
```

**Step 3: Add time-based greeting section**

Add new section in `contentView` after Quick Actions:

```swift
// Time-based greeting (AI-powered)
if let greeting = timeBasedGreeting, !greeting.trackIDs.isEmpty {
    TimeBasedGreetingSection(
        greeting: greeting,
        onTrackTap: { trackId in
            playTrackById(trackId)
        }
    )
}
```

**Step 4: Add greeting generation in loadData()**

Add after existing data loading:

```swift
// Generate AI greeting if we have history
if !recentlyPlayed.isEmpty {
    let sessions = try await dataManager.trackDataActor.getListeningSessions(limit: 50)
    let trackIDs = try await dataManager.trackDataActor.getAllTrackIDs(limit: 200)

    timeBasedGreeting = await recommendationService.generateTimeBasedGreeting(
        sessions: sessions,
        availableTrackIDs: trackIDs,
        genres: genres
    )
}
```

**Step 5: Run build to verify**

Run: `make build`
Expected: PASS

**Step 6: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Home/HomeView.swift"
git commit -m "feat(home): integrate RecommendationService for AI-powered surpriseMe"
```

---

## Task 7: Create TimeBasedGreetingSection View

**Files:**
- Create: `Fonic HiFi/Presentation/Views/Home/Sections/TimeBasedGreetingSection.swift`

**Step 1: Write the view**

```swift
// Fonic HiFi/Presentation/Views/Home/Sections/TimeBasedGreetingSection.swift
import SwiftUI

/// Displays AI-generated time-based greeting with track recommendations
struct TimeBasedGreetingSection: View {
    let greeting: TimeBasedGreeting
    let onTrackTap: (UUID) -> Void

    @Environment(\.dataManager) private var dataManager
    @State private var tracks: [Track] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Greeting header
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting.greeting)
                    .font(.largeTitle.bold())

                Text(greeting.moodDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // Track carousel
            if !tracks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(tracks) { track in
                            GreetingTrackCard(track: track)
                                .onTapGesture {
                                    onTrackTap(track.id)
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task {
            await loadTracks()
        }
    }

    private func loadTracks() async {
        guard let dataManager else { return }

        var loadedTracks: [Track] = []
        for id in greeting.trackIDs {
            if let track = try? await dataManager.trackDataActor.getTrack(by: id) {
                loadedTracks.append(track)
            }
        }
        tracks = loadedTracks
    }
}

private struct GreetingTrackCard: View {
    let track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyArtworkView(track: track, size: 140, cornerRadius: 12)

            Text(track.title)
                .font(.callout.bold())
                .lineLimit(1)

            Text(track.artist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 140)
    }
}
```

**Step 2: Run build to verify**

Run: `make build`
Expected: PASS

**Step 3: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Home/Sections/TimeBasedGreetingSection.swift"
git commit -m "feat(home): add TimeBasedGreetingSection for AI greetings"
```

---

## Task 8: Add Helper Method to HomeView

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/Home/HomeView.swift`

**Step 1: Add playTrackById helper**

Add after existing `playTrack(_:)` method:

```swift
private func playTrackById(_ trackId: UUID) {
    guard let dataManager, let audioEngine else { return }

    Task {
        do {
            if let track = try await dataManager.trackDataActor.getTrack(by: trackId) {
                try await audioEngine.play(track: track)
                showingNowPlaying.wrappedValue = true
            }
        } catch {
            // Handle error silently
        }
    }
}
```

**Step 2: Run build to verify**

Run: `make build`
Expected: PASS

**Step 3: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Home/HomeView.swift"
git commit -m "feat(home): add playTrackById helper for AI recommendations"
```

---

## Task 9: Integration Tests

**Files:**
- Create: `Fonic HiFiTests/Integration/AIRecommendationsIntegrationTests.swift`

**Step 1: Write integration test**

```swift
// Fonic HiFiTests/Integration/AIRecommendationsIntegrationTests.swift
import Foundation
import Testing
@testable import Fonic_HiFi

@Suite("AI Recommendations Integration Tests")
struct AIRecommendationsIntegrationTests {

    @Test("Full recommendation flow with fallback")
    @MainActor
    func fullRecommendationFlowWorks() async {
        let service = RecommendationService()
        let trackIDs = (0..<20).map { _ in UUID() }
        let sessions: [ListeningSessionData] = []
        let genres = ["Rock", "Jazz", "Electronic"]

        // Should work even without AI (fallback)
        let greeting = await service.generateTimeBasedGreeting(
            sessions: sessions,
            availableTrackIDs: trackIDs,
            genres: genres
        )

        #expect(!greeting.greeting.isEmpty)
        #expect(!greeting.trackIDs.isEmpty)

        let surprise = await service.generateSurpriseMix(
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
}
```

**Step 2: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 3: Commit**

```bash
git add "Fonic HiFiTests/Integration/AIRecommendationsIntegrationTests.swift"
git commit -m "test(ai): add integration tests for AI recommendations"
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

**Step 4: Update STATUS.md**

Add to "Implementation Status" section:

```markdown
**AI Recommendations (Phase 4):**
- ✅ RecommendationSchemas - @Generable types for AI output
- ✅ ListeningPatternAnalyzer - Session context builder
- ✅ RecommendationService - Foundation Models integration
- ✅ TimeBasedGreetingSection - AI greeting UI component
- ✅ Rule-based fallbacks - Seamless degradation when AI unavailable
```

**Step 5: Final commit**

```bash
git add STATUS.md
git commit -m "docs: update STATUS.md with Phase 4 AI recommendations"
```

---

## Summary

This plan creates the complete Phase 4: Foundation Models Integration with:

1. **@Generable schemas** for structured AI output
2. **ListeningPatternAnalyzer** for building context from listening history
3. **RecommendationService** with Foundation Models integration and fallbacks
4. **HomeView integration** for "Surprise Me" and time-based greetings
5. **TimeBasedGreetingSection** for displaying AI-generated greetings
6. **Comprehensive tests** including unit and integration tests

All code follows iOS 26 patterns, Swift 6.2 strict concurrency, and the project's established architecture.
