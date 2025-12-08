# Phase 3: Listening History Tracking - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Track listening sessions to enable "Continue Listening" and "Rediscover" sections, recording when users play, skip, or complete tracks.

**Architecture:** Create a `ListeningSession` SwiftData model to record individual play sessions. A `ListeningSessionService` observes playback events and persists sessions via `TrackDataActor`. Home screen sections query this data.

**Tech Stack:** SwiftData, Swift 6.2 concurrency (@MainActor), existing TrackDataActor pattern

---

## Critical Files

**Create:**
- `Fonic HiFi/Data/Models/ListeningSession.swift` - SwiftData model
- `Fonic HiFi/Core/Audio/Analytics/ListeningSessionService.swift` - Session tracking service
- `Fonic HiFi/Presentation/Views/Home/Sections/ContinueListeningSection.swift` - UI section
- `Fonic HiFi/Presentation/Views/Home/Sections/RediscoverSection.swift` - UI section
- `Fonic HiFiTests/ListeningSessionServiceTests.swift` - Service tests
- `Fonic HiFiTests/ListeningSessionTests.swift` - Model tests

**Modify:**
- `Fonic HiFi/Data/Actors/TrackDataActor.swift` - Add session CRUD methods
- `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift` - Wire up service
- `Fonic HiFi/Presentation/Views/Home/HomeView.swift` - Add new sections
- `Fonic HiFi/Data/DataManager+Recent.swift` - Add query methods

---

## Task 1: Create ListeningSession SwiftData Model

**Files:**
- Create: `Fonic HiFi/Data/Models/ListeningSession.swift`
- Test: `Fonic HiFiTests/ListeningSessionTests.swift`

**Step 1: Write the failing test**

```swift
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
        let date = calendar.date(from: components)!

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
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "cannot find 'ListeningSession' in scope"

**Step 3: Write the model implementation**

```swift
// Fonic HiFi/Data/Models/ListeningSession.swift
import Foundation
import SwiftData

/// Records a single listening session for a track
@Model
public final class ListeningSession {
    /// Unique identifier
    public var id: UUID

    /// The track that was played (stored as UUID for cross-actor safety)
    public var trackId: UUID

    /// When the session started
    public var startedAt: Date

    /// When the session ended (nil if still playing)
    public var endedAt: Date?

    /// Total seconds of audio listened
    public var durationListened: TimeInterval

    /// Total duration of the track in seconds
    public var trackDuration: TimeInterval

    /// Percentage of track completed (0.0-1.0)
    public var completionPercentage: Double

    /// Whether user manually skipped
    public var wasSkipped: Bool

    /// Whether track played to natural completion
    public var wasCompleted: Bool

    /// Hour of day (0-23) for time-based patterns
    public var hourOfDay: Int

    /// Day of week (1=Sunday, 7=Saturday) for weekly patterns
    public var dayOfWeek: Int

    public init(
        trackId: UUID,
        startedAt: Date,
        durationListened: TimeInterval,
        trackDuration: TimeInterval,
        completionPercentage: Double,
        wasSkipped: Bool,
        wasCompleted: Bool
    ) {
        self.id = UUID()
        self.trackId = trackId
        self.startedAt = startedAt
        self.endedAt = nil
        self.durationListened = durationListened
        self.trackDuration = trackDuration
        self.completionPercentage = completionPercentage
        self.wasSkipped = wasSkipped
        self.wasCompleted = wasCompleted

        // Calculate time patterns from startedAt
        let calendar = Calendar.current
        self.hourOfDay = calendar.component(.hour, from: startedAt)
        self.dayOfWeek = calendar.component(.weekday, from: startedAt)
    }
}

/// Sendable value type for transferring session data across actor boundaries
public struct ListeningSessionData: Sendable {
    public let id: UUID
    public let trackId: UUID
    public let startedAt: Date
    public let endedAt: Date?
    public let durationListened: TimeInterval
    public let trackDuration: TimeInterval
    public let completionPercentage: Double
    public let wasSkipped: Bool
    public let wasCompleted: Bool
    public let hourOfDay: Int
    public let dayOfWeek: Int

    public init(from model: ListeningSession) {
        self.id = model.id
        self.trackId = model.trackId
        self.startedAt = model.startedAt
        self.endedAt = model.endedAt
        self.durationListened = model.durationListened
        self.trackDuration = model.trackDuration
        self.completionPercentage = model.completionPercentage
        self.wasSkipped = model.wasSkipped
        self.wasCompleted = model.wasCompleted
        self.hourOfDay = model.hourOfDay
        self.dayOfWeek = model.dayOfWeek
    }
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Data/Models/ListeningSession.swift" "Fonic HiFiTests/ListeningSessionTests.swift"
git commit -m "feat(data): add ListeningSession SwiftData model for history tracking"
```

---

## Task 2: Add TrackDataActor Session Methods

**Files:**
- Modify: `Fonic HiFi/Data/Actors/TrackDataActor.swift`
- Test: `Fonic HiFiTests/TrackDataActorTests.swift` (add to existing)

**Step 1: Write the failing tests**

Add to existing `TrackDataActorTests.swift`:

```swift
// Add to Fonic HiFiTests/TrackDataActorTests.swift

@Test("Records listening session")
func testRecordListeningSession() async throws {
    let trackId = UUID()

    try await actor.recordListeningSession(
        trackId: trackId,
        startedAt: Date(),
        durationListened: 120.0,
        trackDuration: 240.0,
        completionPercentage: 0.5,
        wasSkipped: false,
        wasCompleted: false
    )

    let sessions = try await actor.getListeningSessions(limit: 10)
    #expect(sessions.count == 1)
    #expect(sessions.first?.trackId == trackId)
}

@Test("Gets recent listening sessions")
func testGetRecentSessions() async throws {
    let trackId1 = UUID()
    let trackId2 = UUID()

    try await actor.recordListeningSession(
        trackId: trackId1,
        startedAt: Date().addingTimeInterval(-3600),
        durationListened: 60.0,
        trackDuration: 180.0,
        completionPercentage: 0.33,
        wasSkipped: false,
        wasCompleted: false
    )

    try await actor.recordListeningSession(
        trackId: trackId2,
        startedAt: Date(),
        durationListened: 120.0,
        trackDuration: 240.0,
        completionPercentage: 0.5,
        wasSkipped: false,
        wasCompleted: true
    )

    let sessions = try await actor.getListeningSessions(limit: 10)
    #expect(sessions.count == 2)
    // Most recent first
    #expect(sessions.first?.trackId == trackId2)
}

@Test("Gets neglected tracks for rediscover")
func testGetNeglectedTracks() async throws {
    // This requires tracks to exist - will test with integration test
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "has no member 'recordListeningSession'"

**Step 3: Add methods to TrackDataActor**

Add to `Fonic HiFi/Data/Actors/TrackDataActor.swift` after line 422 (after `updatePlaybackStats`):

```swift
// MARK: - Listening Sessions

/// Record a new listening session
public func recordListeningSession(
    trackId: UUID,
    startedAt: Date,
    durationListened: TimeInterval,
    trackDuration: TimeInterval,
    completionPercentage: Double,
    wasSkipped: Bool,
    wasCompleted: Bool
) throws {
    let session = ListeningSession(
        trackId: trackId,
        startedAt: startedAt,
        durationListened: durationListened,
        trackDuration: trackDuration,
        completionPercentage: completionPercentage,
        wasSkipped: wasSkipped,
        wasCompleted: wasCompleted
    )
    session.endedAt = Date()

    modelContext.insert(session)

    do {
        try modelContext.save()
        logger.debug("Recorded listening session for track: \(trackId)")
    } catch {
        logger.error("Failed to record listening session: \(error.localizedDescription)")
        throw TrackDataError.insertFailed(error)
    }
}

/// Get recent listening sessions
/// - Parameter limit: Maximum number of sessions to return
/// - Returns: Array of session data sorted by startedAt descending
public func getListeningSessions(limit: Int) throws -> [ListeningSessionData] {
    var descriptor = FetchDescriptor<ListeningSession>(
        sortBy: [SortDescriptor(\ListeningSession.startedAt, order: .reverse)]
    )
    descriptor.fetchLimit = limit

    let sessions = try modelContext.fetch(descriptor)
    return sessions.map { ListeningSessionData(from: $0) }
}

/// Get the most recent session for a specific track
/// - Parameter trackId: UUID of the track
/// - Returns: Most recent session data or nil
public func getLastSession(for trackId: UUID) throws -> ListeningSessionData? {
    var descriptor = FetchDescriptor<ListeningSession>(
        predicate: #Predicate<ListeningSession> { session in
            session.trackId == trackId
        },
        sortBy: [SortDescriptor(\ListeningSession.startedAt, order: .reverse)]
    )
    descriptor.fetchLimit = 1

    let sessions = try modelContext.fetch(descriptor)
    return sessions.first.map { ListeningSessionData(from: $0) }
}

/// Get tracks that haven't been played recently (for Rediscover section)
/// - Parameters:
///   - daysSinceLastPlay: Minimum days since last play
///   - minimumPlayCount: Minimum play count to qualify as "known"
///   - limit: Maximum number of tracks to return
/// - Returns: Array of track IDs that qualify as neglected
public func getNeglectedTrackIds(
    daysSinceLastPlay: Int,
    minimumPlayCount: Int,
    limit: Int
) throws -> [UUID] {
    let cutoffDate = Calendar.current.date(
        byAdding: .day,
        value: -daysSinceLastPlay,
        to: Date()
    ) ?? Date()

    var descriptor = FetchDescriptor<Track>(
        predicate: #Predicate<Track> { track in
            track.playCount >= minimumPlayCount &&
            (track.lastPlayed == nil || track.lastPlayed! < cutoffDate)
        },
        sortBy: [SortDescriptor(\Track.playCount, order: .reverse)]
    )
    descriptor.fetchLimit = limit

    let tracks = try modelContext.fetch(descriptor)
    return tracks.map { $0.id }
}

/// Increment play count and update last played for a track
/// - Parameter trackId: UUID of the track
public func incrementPlayCount(for trackId: UUID) throws {
    var descriptor = FetchDescriptor<Track>(
        predicate: #Predicate<Track> { track in
            track.id == trackId
        }
    )
    descriptor.fetchLimit = 1

    guard let track = try modelContext.fetch(descriptor).first else {
        logger.warning("Track not found for play count increment: \(trackId)")
        return
    }

    track.playCount += 1
    track.lastPlayed = Date()

    do {
        try modelContext.save()
        logger.debug("Incremented play count for: \(track.title) (now \(track.playCount))")
    } catch {
        logger.error("Failed to increment play count: \(error.localizedDescription)")
        throw TrackDataError.updateFailed(error)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Data/Actors/TrackDataActor.swift" "Fonic HiFiTests/TrackDataActorTests.swift"
git commit -m "feat(data): add listening session CRUD methods to TrackDataActor"
```

---

## Task 3: Create ListeningSessionService

**Files:**
- Create: `Fonic HiFi/Core/Audio/Analytics/ListeningSessionService.swift`
- Test: `Fonic HiFiTests/ListeningSessionServiceTests.swift`

**Step 1: Write the failing test**

```swift
// Fonic HiFiTests/ListeningSessionServiceTests.swift
import Foundation
import Testing

@testable import Fonic_HiFi

@Suite("ListeningSessionService Tests")
struct ListeningSessionServiceTests {
    @Test("Starts session on track play")
    @MainActor
    func testStartSession() async throws {
        let mockActor = MockTrackDataActor()
        let service = ListeningSessionService(dataActor: mockActor)

        let trackId = UUID()
        service.startSession(trackId: trackId, duration: 240.0)

        #expect(service.activeSession != nil)
        #expect(service.activeSession?.trackId == trackId)
    }

    @Test("Records session on track complete")
    @MainActor
    func testCompleteSession() async throws {
        let mockActor = MockTrackDataActor()
        let service = ListeningSessionService(dataActor: mockActor)

        let trackId = UUID()
        service.startSession(trackId: trackId, duration: 240.0)

        await service.endSession(
            currentTime: 240.0,
            wasSkipped: false,
            wasCompleted: true
        )

        #expect(service.activeSession == nil)
        #expect(mockActor.recordedSessions.count == 1)
        #expect(mockActor.recordedSessions.first?.wasCompleted == true)
        #expect(mockActor.incrementedTrackIds.contains(trackId))
    }

    @Test("Records skip with partial listen")
    @MainActor
    func testSkipSession() async throws {
        let mockActor = MockTrackDataActor()
        let service = ListeningSessionService(dataActor: mockActor)

        let trackId = UUID()
        service.startSession(trackId: trackId, duration: 240.0)

        await service.endSession(
            currentTime: 60.0,
            wasSkipped: true,
            wasCompleted: false
        )

        #expect(mockActor.recordedSessions.first?.wasSkipped == true)
        #expect(mockActor.recordedSessions.first?.completionPercentage == 0.25)
        // Should NOT increment play count for skips under threshold
        #expect(mockActor.incrementedTrackIds.isEmpty)
    }

    @Test("Increments play count when over 50% listened")
    @MainActor
    func testPlayCountThreshold() async throws {
        let mockActor = MockTrackDataActor()
        let service = ListeningSessionService(dataActor: mockActor)

        let trackId = UUID()
        service.startSession(trackId: trackId, duration: 200.0)

        // Listen to 60% of track
        await service.endSession(
            currentTime: 120.0,
            wasSkipped: true,
            wasCompleted: false
        )

        // Should increment because > 50%
        #expect(mockActor.incrementedTrackIds.contains(trackId))
    }
}

// Mock for testing
@MainActor
final class MockTrackDataActor: ListeningSessionRecording {
    var recordedSessions: [(trackId: UUID, wasSkipped: Bool, wasCompleted: Bool, completionPercentage: Double)] = []
    var incrementedTrackIds: Set<UUID> = []

    func recordListeningSession(
        trackId: UUID,
        startedAt: Date,
        durationListened: TimeInterval,
        trackDuration: TimeInterval,
        completionPercentage: Double,
        wasSkipped: Bool,
        wasCompleted: Bool
    ) async throws {
        recordedSessions.append((trackId, wasSkipped, wasCompleted, completionPercentage))
    }

    func incrementPlayCount(for trackId: UUID) async throws {
        incrementedTrackIds.insert(trackId)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "cannot find 'ListeningSessionService' in scope"

**Step 3: Write the service implementation**

```swift
// Fonic HiFi/Core/Audio/Analytics/ListeningSessionService.swift
import Foundation
import OSLog

/// Protocol for session recording (enables testing with mock)
public protocol ListeningSessionRecording: Sendable {
    func recordListeningSession(
        trackId: UUID,
        startedAt: Date,
        durationListened: TimeInterval,
        trackDuration: TimeInterval,
        completionPercentage: Double,
        wasSkipped: Bool,
        wasCompleted: Bool
    ) async throws

    func incrementPlayCount(for trackId: UUID) async throws
}

/// Tracks listening sessions and persists them via TrackDataActor
@MainActor
public final class ListeningSessionService {
    // MARK: - Dependencies

    private let dataActor: ListeningSessionRecording
    private let logger = Log.logger(.audioAnalytics)

    // MARK: - Active Session State

    /// Currently active listening session
    public private(set) var activeSession: ActiveSession?

    /// Minimum completion percentage to count as a "play"
    private let playCountThreshold: Double = 0.5

    /// Minimum seconds to record a session at all
    private let minimumSessionDuration: TimeInterval = 10.0

    // MARK: - Types

    public struct ActiveSession {
        let trackId: UUID
        let startedAt: Date
        let trackDuration: TimeInterval
    }

    // MARK: - Initialization

    public init(dataActor: ListeningSessionRecording) {
        self.dataActor = dataActor
    }

    // MARK: - Session Lifecycle

    /// Start tracking a new listening session
    /// - Parameters:
    ///   - trackId: UUID of the track being played
    ///   - duration: Total duration of the track in seconds
    public func startSession(trackId: UUID, duration: TimeInterval) {
        // End any existing session first
        if activeSession != nil {
            Task {
                await endSession(currentTime: 0, wasSkipped: true, wasCompleted: false)
            }
        }

        activeSession = ActiveSession(
            trackId: trackId,
            startedAt: Date(),
            trackDuration: duration
        )

        logger.debug("Started listening session for track: \(trackId)")
    }

    /// End the current listening session and persist it
    /// - Parameters:
    ///   - currentTime: Current playback position when session ended
    ///   - wasSkipped: Whether user manually skipped
    ///   - wasCompleted: Whether track played to natural completion
    public func endSession(
        currentTime: TimeInterval,
        wasSkipped: Bool,
        wasCompleted: Bool
    ) async {
        guard let session = activeSession else {
            logger.debug("No active session to end")
            return
        }

        activeSession = nil

        let durationListened = currentTime
        let completionPercentage = session.trackDuration > 0
            ? min(1.0, durationListened / session.trackDuration)
            : 0.0

        // Only record sessions that lasted at least minimum duration
        guard durationListened >= minimumSessionDuration else {
            logger.debug("Session too short to record: \(durationListened)s")
            return
        }

        do {
            // Record the session
            try await dataActor.recordListeningSession(
                trackId: session.trackId,
                startedAt: session.startedAt,
                durationListened: durationListened,
                trackDuration: session.trackDuration,
                completionPercentage: completionPercentage,
                wasSkipped: wasSkipped,
                wasCompleted: wasCompleted
            )

            // Increment play count if user listened to enough of the track
            if completionPercentage >= playCountThreshold || wasCompleted {
                try await dataActor.incrementPlayCount(for: session.trackId)
                logger.debug("Incremented play count for: \(session.trackId)")
            }

            logger.info("Recorded session: \(Int(completionPercentage * 100))% of track, skipped=\(wasSkipped), completed=\(wasCompleted)")
        } catch {
            logger.error("Failed to record listening session: \(error.localizedDescription)")
        }
    }

    /// Cancel the current session without recording
    public func cancelSession() {
        if activeSession != nil {
            logger.debug("Cancelled listening session")
            activeSession = nil
        }
    }
}
```

**Step 4: Add logging category**

Add to `Fonic HiFi/Utils/Logging/Log.swift` in the LogCategory enum:

```swift
case audioAnalytics = "audio.analytics"
```

**Step 5: Make TrackDataActor conform to protocol**

Add to `Fonic HiFi/Data/Actors/TrackDataActor.swift`:

```swift
extension TrackDataActor: ListeningSessionRecording {}
```

**Step 6: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 7: Commit**

```bash
git add "Fonic HiFi/Core/Audio/Analytics/ListeningSessionService.swift" \
        "Fonic HiFiTests/ListeningSessionServiceTests.swift" \
        "Fonic HiFi/Utils/Logging/Log.swift" \
        "Fonic HiFi/Data/Actors/TrackDataActor.swift"
git commit -m "feat(audio): add ListeningSessionService for history tracking"
```

---

## Task 4: Wire ListeningSessionService into AudioEngineFacade

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift`
- Modify: `Fonic HiFi/Core/Audio/Coordinators/QueueCoordinator.swift`

**Step 1: Add service property to AudioEngineFacade**

In `AudioEngineFacade.swift`, add after line 50 (properties section):

```swift
/// Listening session tracking service
private let sessionService: ListeningSessionService
```

**Step 2: Initialize service in init**

In `AudioEngineFacade.swift` init, after line 142 (after playbackController setup):

```swift
self.sessionService = ListeningSessionService(dataActor: trackDataActor)
```

**Step 3: Start session when track plays**

In `AudioEngineFacade.swift`, modify the `play(track:)` method (around line 292). Add after successful play:

```swift
// Start listening session
if let duration = await engineManager.currentEngine?.duration {
    sessionService.startSession(trackId: track.id, duration: duration)
}
```

**Step 4: End session on track complete**

In `AudioEngineFacade.swift`, modify the `onTrackComplete` handler (line 153). Before calling `playNext()`:

```swift
// Record completed session
if let engine = self.engineManager.currentEngine {
    let currentTime = await engine.currentTime
    await self.sessionService.endSession(
        currentTime: currentTime,
        wasSkipped: false,
        wasCompleted: true
    )
}
```

**Step 5: End session on manual skip**

In `QueueCoordinator.swift`, add session service dependency and end session on skip.

Add property:
```swift
private let sessionService: ListeningSessionService?
```

Modify init to accept optional sessionService.

In `playNext()` and `playPrevious()`, before playing new track:
```swift
// End current session as skip
if let sessionService {
    await sessionService.endSession(
        currentTime: 0, // We don't have easy access to current time here
        wasSkipped: true,
        wasCompleted: false
    )
}
```

**Step 6: End session on stop**

In `AudioEngineFacade.swift` `stop()` method:

```swift
// End session without completion
if let engine = engineManager.currentEngine {
    let currentTime = await engine.currentTime
    await sessionService.endSession(
        currentTime: currentTime,
        wasSkipped: false,
        wasCompleted: false
    )
}
```

**Step 7: Run build to verify compilation**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 8: Commit**

```bash
git add "Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift" \
        "Fonic HiFi/Core/Audio/Coordinators/QueueCoordinator.swift"
git commit -m "feat(audio): integrate ListeningSessionService with playback lifecycle"
```

---

## Task 5: Add DataManager Query Methods

**Files:**
- Modify: `Fonic HiFi/Data/DataManager+Recent.swift`

**Step 1: Add Continue Listening query**

Add to `DataManager+Recent.swift`:

```swift
/// Get tracks with recent incomplete sessions for "Continue Listening"
/// - Parameter limit: Maximum number of tracks to return
/// - Returns: Array of tracks that were recently started but not completed
public func getContinueListeningTracks(limit: Int) async throws -> [Track] {
    // Get recent sessions that weren't completed
    let sessions = try await trackDataActor.getListeningSessions(limit: 50)

    // Filter to sessions that weren't completed and have >10% progress
    let incompleteSessionTrackIds = sessions
        .filter { !$0.wasCompleted && $0.completionPercentage > 0.1 && $0.completionPercentage < 0.9 }
        .prefix(limit)
        .map { $0.trackId }

    // Fetch the actual tracks
    var tracks: [Track] = []
    for trackId in incompleteSessionTrackIds {
        if let track = try await trackDataActor.getTrack(by: trackId) {
            tracks.append(track)
        }
    }

    return tracks
}

/// Get neglected tracks for "Rediscover" section
/// - Parameter limit: Maximum number of tracks to return
/// - Returns: Array of tracks that user knows but hasn't played recently
public func getRediscoverTracks(limit: Int) async throws -> [Track] {
    let neglectedIds = try await trackDataActor.getNeglectedTrackIds(
        daysSinceLastPlay: 30,
        minimumPlayCount: 2,
        limit: limit
    )

    var tracks: [Track] = []
    for trackId in neglectedIds {
        if let track = try await trackDataActor.getTrack(by: trackId) {
            tracks.append(track)
        }
    }

    return tracks
}
```

**Step 2: Add helper method to TrackDataActor if needed**

If `getTrack(by: UUID)` doesn't exist, add to `TrackDataActor.swift`:

```swift
/// Get a track by its UUID
public func getTrack(by id: UUID) throws -> Track? {
    var descriptor = FetchDescriptor<Track>(
        predicate: #Predicate<Track> { track in
            track.id == id
        }
    )
    descriptor.fetchLimit = 1
    return try modelContext.fetch(descriptor).first
}
```

**Step 3: Run build**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add "Fonic HiFi/Data/DataManager+Recent.swift" "Fonic HiFi/Data/Actors/TrackDataActor.swift"
git commit -m "feat(data): add Continue Listening and Rediscover query methods"
```

---

## Task 6: Create ContinueListeningSection UI

**Files:**
- Create: `Fonic HiFi/Presentation/Views/Home/Sections/ContinueListeningSection.swift`

**Step 1: Create the section component**

```swift
// Fonic HiFi/Presentation/Views/Home/Sections/ContinueListeningSection.swift
import SwiftUI

/// Displays tracks with incomplete listening sessions
struct ContinueListeningSection: View {
    let tracks: [Track]
    let onPlay: (Track) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue Listening")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(tracks.prefix(3)) { track in
                    ContinueListeningRow(track: track) {
                        onPlay(track)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

/// Individual row for a continue listening track
private struct ContinueListeningRow: View {
    let track: Track
    let onTap: () -> Void

    @Environment(\.artworkService) private var artworkService

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                LazyArtworkView(track: track, size: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text(track.artist ?? "Unknown Artist")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
```

**Step 2: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Home/Sections/ContinueListeningSection.swift"
git commit -m "feat(ui): add ContinueListeningSection component"
```

---

## Task 7: Create RediscoverSection UI

**Files:**
- Create: `Fonic HiFi/Presentation/Views/Home/Sections/RediscoverSection.swift`

**Step 1: Create the section component**

```swift
// Fonic HiFi/Presentation/Views/Home/Sections/RediscoverSection.swift
import SwiftUI

/// Displays neglected tracks the user might want to rediscover
struct RediscoverSection: View {
    let tracks: [Track]
    let onPlay: (Track) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rediscover")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("You haven't played these in a while")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(tracks) { track in
                        RediscoverCard(track: track) {
                            onPlay(track)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

/// Card for a rediscover track
private struct RediscoverCard: View {
    let track: Track
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                LazyArtworkView(track: track, size: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text(track.artist ?? "Unknown Artist")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 120, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}
```

**Step 2: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Home/Sections/RediscoverSection.swift"
git commit -m "feat(ui): add RediscoverSection component"
```

---

## Task 8: Integrate Sections into HomeView

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/Home/HomeView.swift`

**Step 1: Add state properties**

Add after line 26 (after `favoriteAlbums`):

```swift
// Continue/Rediscover state
@State private var continueListening: [Track] = []
@State private var rediscoverTracks: [Track] = []
```

**Step 2: Add sections to contentView**

In `contentView`, add after QuickActionsSection (around line 73):

```swift
// Continue Listening (if has incomplete sessions)
if !continueListening.isEmpty {
    ContinueListeningSection(tracks: continueListening) { track in
        playTrack(track)
    }
}
```

Add before the closing of VStack (around line 121):

```swift
// Rediscover (if has neglected tracks)
if !rediscoverTracks.isEmpty {
    RediscoverSection(tracks: rediscoverTracks) { track in
        playTrack(track)
    }
}
```

**Step 3: Update isEmpty check**

Modify `isEmpty` computed property (line 59):

```swift
private var isEmpty: Bool {
    recentlyAdded.isEmpty && artists.isEmpty && genres.isEmpty && albums.isEmpty &&
    recentlyPlayed.isEmpty && mostListened.isEmpty && favoriteAlbums.isEmpty &&
    continueListening.isEmpty && rediscoverTracks.isEmpty
}
```

**Step 4: Load data in loadData()**

Add to `loadData()` after line 145:

```swift
// History-based sections
continueListening = try await dataManager.getContinueListeningTracks(limit: 3)
rediscoverTracks = try await dataManager.getRediscoverTracks(limit: 10)
```

**Step 5: Run build and test**

Run: `make build && make test`
Expected: BUILD SUCCEEDED, tests pass

**Step 6: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Home/HomeView.swift"
git commit -m "feat(home): integrate Continue Listening and Rediscover sections"
```

---

## Task 9: Run Full Test Suite and Verify

**Step 1: Run all tests**

Run: `make test`
Expected: All 311+ tests pass

**Step 2: Run linting**

Run: `make lint`
Expected: No violations

**Step 3: Run in simulator**

Run: `make run`
Expected: App launches, home screen shows new sections when history exists

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat(home): complete Phase 3 - Listening History Tracking

- Add ListeningSession SwiftData model for tracking play sessions
- Add ListeningSessionService to record play/skip/complete events
- Integrate session tracking with AudioEngineFacade lifecycle
- Add Continue Listening section for incomplete sessions
- Add Rediscover section for neglected tracks
- Wire up TrackDataActor with session CRUD methods
- Update Track.playCount and lastPlayed on qualified listens"
```

---

## Summary

**Total Tasks:** 9
**New Files:** 6
**Modified Files:** 5
**Estimated Commits:** 9

**Key Integration Points:**
1. `AudioEngineFacade.play()` → starts session
2. `PlaybackController.onTrackComplete` → ends session (completed)
3. `QueueCoordinator.playNext/Previous()` → ends session (skipped)
4. `AudioEngineFacade.stop()` → ends session (stopped)

**Testing Strategy:**
- Unit tests for ListeningSession model
- Unit tests for ListeningSessionService with mock
- Integration via existing playback tests
- Manual verification in simulator
