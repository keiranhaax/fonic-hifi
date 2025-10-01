# Fonic HiFi Core Audio Improvement Plan

## Overview
This document consolidates the results of a comprehensive review of Fonic HiFi’s audio playback subsystem. It targets consumption-ready guidance for engineers improving the Swift 6 Core/Audio stack, with emphasis on thread safety, queue management, playback state transitions, and data handling. Recommendations are grouped by urgency and scope, covering both tactical fixes and strategic refactors aligned with modern audio application design on Apple platforms.

---

## Immediate Remediation Roadmap

### 1. Restore Sandbox-Compatible Metadata Extraction
**Files:** `Data/Services/MetadataExtractionService.swift`, `Data/Services/LibraryImportService.swift`
- `extractTrackMetadata` currently fails when `startAccessingSecurityScopedResource()` returns `false`, which is the case for files already inside the app container. Treat sandbox access as optional and call `stopAccessing…` only when access was granted.
- Normalize duplicate detection to the copied destination URL (or persisted bookmark) before invoking `trackDataActor.trackExists`. Present logic compares the source URL, so every import duplicates content.
- **Code Pattern:**
  ```swift
  public func extractTrackMetadata(from url: URL) async throws -> TrackMetadata {
      let needsSecurityScope = url.startAccessingSecurityScopedResource()
      defer { if needsSecurityScope { url.stopAccessingSecurityScopedResource() } }
      // continue with metadata extraction…
  }
  ```

### 2. Move Import & Metadata Work Off the Main Actor
**Files:** `LibraryImportService.swift`
- `LibraryImportService` is marked `@MainActor`, so the `TaskGroup` in `processBatch` still writes files and performs SwiftData saves on the main queue.
- Extract the heavy work into `actor`/`Task.detached` blocks, returning UI updates via `MainActor.run { … }` to prevent UI freezes during bulk imports.

### 3. Fix Queue ↔ Track Bridging Type Safety
**Files:** `AudioQueueManager.swift`, `QueueCoordinator.swift`
- Playback queue converts `Track` → `LegacyTrack`. `QueueCoordinator` then reconstitutes a `Track` using a convenience initializer that re-fetches metadata without relationships.
- Persist the original `Track` reference (e.g., store `PersistentIdentifier`) to prevent data loss and ensure queue operations keep parity with SwiftData entities.
- Add guard assertions for queue bounds to harden against invalid index mutations in shuffle/restore logic.

### 4. Normalize Playback State Transitions
**Files:** `PlaybackStateManager.swift`, `PlaybackState.swift`
- `updateTime` and `updateProgress` bypass validation by disabling `transitionValidation`. Introduce scoped helpers to enforce allowable transitions while still supporting time/progress updates.
- Prevent `.duration` returning `nil` for loading/buffering cases to simplify UI calculations; extend `PlaybackState` with safe defaults.
- **Code Pattern:**
  ```swift
  private func transition(_ next: PlaybackState, allowingSame: Bool = false) -> Bool {
      guard allowingSame || currentState != next else { return true }
      guard currentState.canTransition(to: next) else { return false }
      commitTransition(next)
      return true
  }
  ```

### 5. Aggregate Library Statistics off the Main Context
**Files:** `DataManager.swift`, `Data/Extensions/SwiftDataPagination.swift`
- `getLibraryStatistics` fetches entire tables on the main context. Replace with background-context aggregate queries using SwiftData’s `fetchCount` and `@QueryProperty` equivalent patterns.
- Update `PaginatedFetchDescriptor.count` to rely on `ModelContext.fetchCount` rather than fetching every record into memory.

---

## Performance Optimization Opportunities

### Thread Safety & Concurrency
- Guarantee all audio engine calls hop through a dedicated `TaskQueue` or serial `DispatchQueue` to avoid mixed `DispatchQueue.main` assertions (`AudioEngineFacade.play`, `resume`, `seek`).
- Replace manual `Task` polling in `ProgressTimerManager` with `AsyncStream` or `Clock`-based timers to respect cooperative cancellation and reduce CPU wakeups.

### Queue Management Efficiency
- Cache `shuffleSequence` using a lightweight struct that tracks visited indices to eliminate recalculating on every `hasNext` query.
- Persist queue state—including shuffle/repeat modes—via SwiftData to survive app restarts.
- Implement `remove(track:)` and `replaceQueue` operations using `OrderedSet` semantics to minimize repeated linear scans.

### Playback State Pipeline
- Centralize state transition rules in `PlaybackState` (e.g., `mutating func advance(to: PlaybackEvent)`), enabling deterministic state changes from engine callbacks, remote commands, and queue operations.
- Introduce unit tests using synthetic state machines to verify no invalid transitions slip through when `transitionValidation` is enabled.

### Engine Monitoring
- The bespoke `Logger` type in `AudioEngineFacade` masks `os.Logger`. Replace stub with `os.Logger(subsystem:category:)` to enable Unified Logging and reduce console spam.
- `AudioMonitor` currently emits placeholder metrics; either wire real AVAudioSession/AudioToolbox data or temporarily disable heavy polling to conserve resources.

---

## Data Handling & Persistence Enhancements

### SwiftData Usage
- Separate read/write contexts: create a background `ModelContext` for imports and heavy analytics to keep UI responsive.
- Persist derived metrics (duration, file size) outside of in-memory calculations to support incremental updates without re-fetching all tracks.
- Store security-scoped bookmarks for external libraries so imports can refresh metadata without user re-selection.

### Export & Backup
- Use streaming JSON encoding for `exportLibraryData` to avoid holding the full track array in memory. Consider chunking via `JSONEncoder` with custom `Sequence` wrappers.
- Provide background task support for exports (apply `BGProcessingTaskRequest`) to guarantee completion when the app moves to background.

---

## Architectural Refinements (Medium to Long Term)

### Modular Coordinators
- The `PlaybackCoordinator`, `QueueCoordinator`, and `StateCoordinator` files are not wired into the `AudioEngineFacade`. Decide between fully integrating them or consolidating to reduce dead code. A cohesive dependency injection graph should surface the façade only as a UI API wrapper.

### Engine Factory & Session Ownership
- Align `AudioSessionManager.configureAudioSession()` with the current engine type. Today it assumes AudioKit manages the session, yet `AudioEngineFactory` may emit `AVAudioEngineAdapter`. Centralize session lifecycle ownership (configure, activate, deactivate) in one place to avoid mismatched categories.

### Testing & Telemetry
- Establish XCTest/Swift Testing coverage for `PlaybackStateManager`, `AudioQueueManager`, and import flows, mirroring the runtime directory structure (`Fonic HiFiTests/Core/Audio/…`).
- Instrument telemetry for queue transitions, underruns, and decoder failures, enabling data-driven tuning of buffer sizes and format selection heuristics.

### UI Feedback & Responsiveness
- Expose async status via `@Published` on the façade for initialization and playback progress; combine with SwiftUI’s `.task(id:)` to automatically refresh UI without manual `.task` closures.
- Add guardrails around `.showMiniPlayer` toggling to avoid flicker when state oscillates between buffering and playing.

---

## Implementation Checklist

| Priority | Area | Task | Owner | Status |
| --- | --- | --- | --- | --- |
| P0 | Imports | Fix security-scoped access handling | Audio Platform | ☐ |
| P0 | Imports | Normalize duplicate detection against copied URL | Audio Platform | ☐ |
| P0 | Concurrency | Move import processing off `@MainActor` | Audio Platform | ☐ |
| P1 | Data | Aggregate statistics using background context | Data Platform | ☐ |
| P1 | Queue | Preserve original `Track` identity in queues | Audio Platform | ☐ |
| P1 | State | Gate transitions through vetted helper API | Audio Platform | ☐ |
| P2 | Monitoring | Replace stub logging/metrics with structured logging | Infra | ☐ |
| P2 | Testing | Add regression tests for `PlaybackStateManager`, `AudioQueueManager`, and import flows | QA | ☐ |
| P3 | Architecture | Reconcile coordinator wiring or remove dead code | Architecture | ☐ |

---

## Appendix: Recommended Code Patterns

### Background Import Pipeline
```swift
actor ImportWorker {
    func copyAndExtract(_ url: URL) async throws -> ProcessedTrack {
        let copiedURL = try copyIntoAppContainer(url)
        let metadata = try await metadataExtractor.extractTrackMetadata(from: copiedURL)
        return ProcessedTrack(url: copiedURL, metadata: metadata)
    }
}

@MainActor
final class LibraryImportService: ObservableObject {
    private let worker = ImportWorker()

    func importFiles(from urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask { [weak self] in
                    guard let self else { return }
                    do {
                        let processed = try await self.worker.copyAndExtract(url)
                        try await self.trackDataActor.createTrack(from: processed.metadata)
                        await MainActor.run { self.filesProcessed += 1 }
                    } catch {
                        await MainActor.run { self.importErrors.append(.init(url: url, error: error, message: "Failed")) }
                    }
                }
            }
        }
    }
}
```

### Centralized State Transition
```swift
enum PlaybackEvent {
    case load, play, pause, stop, seek(TimeInterval), buffer(Double)
}

extension PlaybackState {
    func nextState(for event: PlaybackEvent) -> PlaybackState? {
        switch (self, event) {
        case (.idle, .load): return .loading()
        case (.loading, .play): return .playing(currentTime: 0, duration: 0)
        case (.playing, .pause): return .paused(currentTime: currentTime ?? 0, duration: duration ?? 0)
        case (.playing, .seek(let t)): return .seeking(targetTime: t, currentTime: currentTime ?? 0)
        // Continue enumerating valid transitions…
        default: return nil
        }
    }
}
```

---

## Closing Notes
- Tightening thread confinement, improving queue persistence, and rationalizing state management will immediately elevate playback stability and UX polish.
- Longer-term, weaving in automated tests and accurate telemetry will enable confident evolution of the audio stack, including future engine swaps and hardware integration.
- The recommendations here are intentionally scoped to the Core/Audio subsystem; cross-functional changes (UI, analytics, automation) should be planned alongside but tracked separately.
