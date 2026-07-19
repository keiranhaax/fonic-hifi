# Fonic HiFi production audit continuation

## Part 2 — Work Package 4: Refactoring review

Repository: https://github.com/keiranhaax/fonic-hifi
Branch: `main`
Reviewed commit: `459db9bfd18d17960e8fd2ff8defc4701085532e`
Review mode: read-only static inspection and refactoring planning
Source changes: none
Date: 2026-07-11

## TLDR

Eight safe, high-value refactoring opportunities were retained. The highest-priority work is to establish one observable audio presentation-state boundary, separate queue mutation from persistence side effects, and give each Library section explicit request ownership. These are not cosmetic file splits: current ownership is fragmented across Observation, Combine, custom environment values, local SwiftUI state, `@AppStorage`, notification helpers, and unowned tasks. Six tempting candidates were rejected or deferred because they were size-only, appeared orphaned/test-only, or would create unacceptable audio regression risk without Xcode/device validation.

No repository file was modified. No minimal validation patch was necessary.

## Scope and continuation baseline

This session executed only Work Package 4. It did not restart the original production audit and did not complete Foundation Models review, cross-domain deduplication, Critical/High re-verification, or project cleanup.

The supplied checkpoint archive was inspected first. It contains ten completed domain reports and package manifests from a clean static audit at commit `459db9bfd18d17960e8fd2ff8defc4701085532e`. It explicitly states that cross-domain synthesis and independent Critical/High verification were unfinished. No standalone refactoring work package was present.

The repository was cloned read-only. Current `main` matched the checkpoint commit exactly and the worktree was clean. The checkout contains 593 files excluding `.git`, including 325 Swift files and 60,262 physical Swift lines. The app, widget, unit-test, and UI-test trees are present.

Previous reports were used only to locate candidate paths. Every retained opportunity below was re-read in the repository and checked against active call sites and available tests.

## Method

1. Verified the input ZIP hash, contents, manifests, and recorded repository revision.
2. Verified the live checkout revision and clean state.
3. Generated a mechanical inventory of all Swift files: size, declarations, state wrappers, task spawns, error blocks, SwiftUI update modifiers, and direct singleton I/O.
4. Generated symbol/reference counts across product and tests.
5. Traced active roots before treating a large or complex file as worth refactoring.
6. Read candidate source, direct collaborators, and relevant tests.
7. Checked exact app/widget contract parity.
8. Applied Axiom iOS audit, SwiftUI, Swift Concurrency, and Testing guidance.
9. Checked current official Apple documentation where Observation and AsyncStream behavior affected the recommendation.
10. Ran a 23-check static verification script against the exact commit.
11. Rejected size-only, orphaned, test-only, and broad device-sensitive proposals.

One narrow SwiftUI sub-agent was attempted after a durable checkpoint. It returned no usable source analysis. No delegated claim was accepted; all findings are from lead review and direct evidence.

## Outcome summary

| ID | Opportunity | Priority | Value | Risk | Effort | Status |
|---|---|---:|---:|---:|---:|---|
| WP4-R01 | Consolidate SwiftUI audio presentation state | P0 | Very high | High | Large | Retained |
| WP4-R02 | Separate queue mutation, notifications, and persistence | P0 | Very high | Medium | Medium-Large | Retained |
| WP4-R03 | Give each Library section request ownership and a load phase | P0 | High | Medium | Medium | Retained |
| WP4-R04 | Move filesystem operations out of FileManagerView | P1 | High | Medium | Medium | Retained |
| WP4-R05 | Create one TrackDataActor insertion kernel before splitting | P1 | High | Medium | Medium | Retained |
| WP4-R06 | Own AsyncStream producer lifetime and cancellation | P1 | High | Medium | Medium | Retained |
| WP4-R07 | Centralize process metrics behind an injectable provider | P1 | Medium-High | Low-Medium | Small | Retained |
| WP4-R08 | Compile one canonical app/widget contract | P1 | High | Medium | Medium | Retained |

Disposition of screened candidates:

- Retained: 8
- Rejected: 4
- Deferred to Work Package 5: 2
- Merged into another opportunity: 0
- Downgraded: 0
- Source changes made: 0

## Retained opportunities

### WP4-R01 — Consolidate the SwiftUI audio presentation-state boundary

**Priority:** P0
**Confidence:** Confirmed by active source and test-boundary evidence
**Value:** Very high
**Risk:** High because it changes a core ownership boundary
**Implementation approval:** Required before source changes

#### Evidence

The app root injects `AudioEngineFacade` through a custom environment value:

- `Fonic HiFi/FonicHiFiApp.swift:103-110`
- `Fonic HiFi/Presentation/Environment/AudioEnvironment.swift:14-23,88-96`

```swift
struct AudioEngineKey: EnvironmentKey {
    static let defaultValue: AudioEngineFacade? = nil
}

var audioEngine: AudioEngineFacade? {
    get { self[AudioEngineKey.self] }
    set { self[AudioEngineKey.self] = newValue }
}
```

`AudioEngineFacade` mixes computed state from other observable owners with a manually proxied `@Published` subset:

- `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:40-45,64-69,555-569`

```swift
public var currentState: PlaybackState { stateCoordinator.currentState }
public var queueState: QueueState { stateCoordinator.queueState }
public var isPlaying: Bool { currentState.isPlaying }
public var playbackProgress: Double { currentState.progress ?? 0.0 }
```

```swift
@Published public private(set) var currentTrack: Track?
@Published public private(set) var showMiniPlayer: Bool = false
@Published public private(set) var diagnosticsStatus: DiagnosticsStatus = .empty
@Published public var abLoopState = ABLoopState()
```

`NowPlayingContent` then adds separate local/defaults mirrors for state already owned by the engine, queue, settings store, or data actor:

- `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:23-50,250-280,439-507,660-699`

```swift
@State private var isFavorite = false
@State private var playbackSpeed: Double = 1.0
@AppStorage("isShuffleEnabled") private var isShuffleEnabled: Bool = false
@AppStorage("repeatMode") private var repeatModeRawValue: String = QueueRepeatMode.none.rawValue
```

```swift
let newMode: QueueShuffleMode = isShuffleEnabled ? .off : .random
audioService.setShuffleMode(newMode)
isShuffleEnabled = newMode != .off
```

Queue UI reads nested queue state through the same custom environment object:

- `Fonic HiFi/Presentation/Views/Queue/QueueView.swift:11,31-49`

```swift
if let current = audioService?.queueManager.queueState.currentTrack { ... }
let remaining = audioService?.queueManager.queueState.remainingTracks ?? []
```

`PlaybackStateManager` and `AudioQueueManager` use Observation, `AudioUIState` and the facade use `ObservableObject`/Combine, and views receive the facade as a custom environment value. The same user-facing state therefore crosses several observation systems and is mirrored in views.

#### Why this refactor is high value

- Establishes one source of truth for primary playback controls.
- Gives SwiftUI an explicit dependency on the properties it renders.
- Removes persistence from view-local defaults where an engine/settings owner already exists.
- Makes external changes from App Intents, Control Center, queue restoration, and services testable at the presentation boundary.
- Enables smaller subviews without passing stale copies.

#### Recommended boundary

Create one `@MainActor @Observable` presentation model containing only UI-consumed state. Either expose it from the facade or make the facade the observable model. Inject it by observable type with `.environment(model)` and read it with `@Environment(Model.self)`, or use one consistent `ObservableObject` path if the project chooses not to migrate yet. Do not keep the same property in Observation, Combine, local `@State`, and `@AppStorage` simultaneously.

Migrate one state slice at a time behind compatibility accessors. Remove legacy proxies only after every consumer and test has moved.

#### Preserve

- Playback commands and engine behavior
- Queue/repeat/shuffle semantics
- App Intents, widget controls, persistence keys, restored settings
- Current UI composition, copy, appearance, transitions, and accessibility labels

#### Do not touch

Audio graph, engine selection, EQ, gapless/crossfade, widget payload schema, or visual design.

#### Validation

- Change shuffle from `ToggleShuffleIntent` while Now Playing is open; UI and queue must agree.
- Restore nondefault repeat and rate; controls and menu checkmarks must agree on first render.
- Mutate queue externally; QueueView and mini-player must refresh.
- Favorite persistence failure must not leave optimistic view state behind.
- Use SwiftUI Instruments Cause & Effect to prove unrelated state does not invalidate the entire Now Playing hierarchy.
- Run device checks for Control Center, interruptions, routes, restoration, and background transitions.

#### Limitation

Exact SwiftUI invalidation and iOS 26 runtime behavior are **UNVERIFIED — needs Xcode/simulator/device check**.

---

### WP4-R02 — Separate queue mutation from notification and persistence side effects

**Priority:** P0
**Confidence:** Confirmed by source and existing tests
**Value:** Very high
**Risk:** Medium

#### Evidence

A logical queue operation can call both notification helpers:

- `Fonic HiFi/Core/Audio/Queue/AudioQueueManager.swift:326-343`

```swift
currentIndex = startIndex
markNavigationStateDirty()
notifyTracksChanged()
notifyCurrentTrackChanged()
```

Both helpers persist:

- `AudioQueueManager.swift:653-665`

```swift
private func notifyTracksChanged() {
    delegate?.audioQueue(self, didUpdateTracks: tracks)
    saveState()
}

private func notifyCurrentTrackChanged() {
    delegate?.audioQueue(self, didChangeCurrentTrack: currentTrack, at: currentIndex)
    saveState()
}
```

Persistence performs full snapshot work, file checks, JSON encoding, and a `UserDefaults` write:

- `Fonic HiFi/Core/Audio/Queue/QueueState.swift:321-326,359-405`

```swift
let data = try encoder.encode(self)
UserDefaults.standard.set(data, forKey: Self.persistenceKey)
```

```swift
let validTracks = tracks.filter { track in
    FileManager.default.fileExists(atPath: track.url.path)
}
```

The manager is `@MainActor`, so this side-effect chain runs on the same actor as queue controls and SwiftUI-facing state.

#### Why this refactor is high value

- Prevents one logical mutation from causing multiple complete persistence passes.
- Makes mutation event order and persistence count observable in tests.
- Separates a latency-sensitive queue owner from filesystem validation and encoding.
- Creates a stable snapshot boundary that WP4-R01 can observe.

#### Recommended boundary

Inject a `QueueStatePersisting` collaborator. Route every public mutation through one finalization path that recalculates navigation once, emits only changed delegate events, creates one immutable snapshot, and requests one persistence operation. Preserve the current persistence key and Codable payload in the first pass. Move format/storage migration to a separate decision.

#### Preserve

Queue ordering, current index, shuffle/repeat behavior, history, delegate semantics, 24-hour restoration rule, persistence key, and Codable fields.

#### Validation

- Persistence spy: exactly one request for replace, clear, remove, move, insert, and current-index operations.
- Delegate spy: characterized event count/order remains stable.
- Persistence failure: in-memory queue remains usable and error is recorded.
- Device Time Profiler and File Activity with 100, 1,000, and 10,000 entries.
- Force quit and restore the final coalesced state.

#### Limitation

Main-thread latency magnitude is **UNVERIFIED — needs Instruments/device check**. The repeated synchronous path is statically confirmed.

---

### WP4-R03 — Give each Library section explicit request ownership and load phase

**Priority:** P0
**Confidence:** Confirmed by active source and test gaps
**Value:** High
**Risk:** Medium

#### Evidence

Each section stores a value-type pagination state:

- `Fonic HiFi/Presentation/ViewModels/Library/LibraryViewModel.swift:33-44`

`fetchPage` receives that state by value and marks only a local copy loading before suspension:

- `LibraryViewModel.swift:143-188`

```swift
if state.isLoading { return state }
var nextState = state
...
nextState.isLoading = true
isLoadingSection = section
let page = try await loader(targetPage, effectiveQuery)
...
return nextState
```

The owning `trackState`, `albumState`, `artistState`, or `playlistState` is assigned only after the awaited function returns. A second request can observe the old stored state while the first request’s `isLoading` exists only in `nextState`. There is no request generation or in-flight task identity preventing an older response from committing after a newer query.

The view owns separate tab and search tasks:

- `Fonic HiFi/Presentation/Views/Library/LibraryView.swift:162-177,336-369`

One global `isLoadingSection` also drives both full-screen and tail loading UI:

- `LibraryView.swift:140-144,195-288,301-309`

#### Why this refactor is high value

- Gives request cancellation and stale-response rejection one owner.
- Prevents duplicate page requests at prefetch thresholds.
- Separates initial loading from pagination without changing UI structure.
- Simplifies the four parallel state branches and makes race tests possible.

#### Recommended boundary

Model per-section phase explicitly: idle, initial loading, loaded, paging, failed. Store an in-flight task or monotonically increasing request generation per section/query. Set stored loading state before suspension. Apply a response only if it matches the latest section/query/generation. Move search debounce/request ownership into the view model.

#### Preserve

Tabs, search text behavior, page size, prefetch threshold, item identity, import/create actions, details, error messages, and visual layout.

#### Validation

- Query A completes after B: A must not overwrite B.
- Two threshold triggers: one repository call.
- Independent simultaneous section loads.
- Cancellation on query/tab change.
- Initial load may show its overlay; paging leaves existing content interactive.

#### Limitation

Actual request overlap timing is **UNVERIFIED — needs executable async tests under Xcode**. The absence of stored request ownership is statically confirmed.

---

### WP4-R04 — Move filesystem operations and operation state out of FileManagerView

**Priority:** P1
**Confidence:** Confirmed by active source and no direct tests
**Value:** High
**Risk:** Medium

#### Evidence

The active Settings route creates `FileManagerView`:

- `Fonic HiFi/Presentation/Views/Settings/SettingsView.swift:112-123`

The view owns ten state properties, sorting/filtering, directory navigation, FileManager calls, security-scope handling, detached copy tasks, delete/create logic, error logging, and UIKit presentation:

- `Fonic HiFi/Presentation/Views/Settings/FileManagerView.swift:25-55,195-233,265-275,303-395`

```swift
let contents = try FileManager.default.contentsOfDirectory(...)
```

```swift
try FileManager.default.removeItem(at: item.url)
```

```swift
Task.detached(priority: .utility) { ... try fm.copyItem(...) }
```

```swift
if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
   let rootViewController = windowScene.windows.first?.rootViewController {
    rootViewController.present(alert, animated: true)
}
```

No tracked test references `FileManagerView`.

#### Why this refactor is high value

- Makes file operations deterministic and testable without rendering UI.
- Gives errors and partial batch outcomes a user-facing state instead of logs only.
- Removes detached-task and security-scope lifecycle from a view.
- Replaces root-controller discovery with SwiftUI-owned presentation state.

#### Recommended boundary

Create a filesystem protocol/service or actor and an observable `FileManagerViewModel`. The view should bind to state and forward user intents. Preserve current names and actions. Return structured outcomes for list/copy/delete/create operations.

#### Preserve

Root directory, sort/filter behavior, file importer types, unique-copy naming, security-scope balancing, selection, confirmation, visible copy, and Settings navigation.

#### Validation

Use a temporary-directory or in-memory test double for list, sort, search, root containment, create, collision naming, delete success/partial failure, copy cancellation, and security-scope balance. Add UI tests for folder prompt, selection, delete confirmation, and surfaced errors.

#### Limitation

File-provider and security-scope behavior are **UNVERIFIED — needs simulator/device check**.

---

### WP4-R05 — Create one TrackDataActor insertion kernel before splitting responsibilities

**Priority:** P1
**Confidence:** Confirmed by source and characterization tests
**Value:** High
**Risk:** Medium

#### Evidence

`TrackDataActor.swift` contains 1,218 lines, 39 function declarations, and public groups for creation, queries, updates, listening sessions, and recommendation support. It has 32 token references across 13 product/test files.

Single and batch creation duplicate the same persisted mapping and relationship work:

- `Fonic HiFi/Data/Actors/TrackDataActor.swift:262-311`
- `TrackDataActor.swift:318-370`

Both paths resolve artist/album names, construct `Track`, call `applyTrackMetadata`, insert the model, and call `linkAlbumArtistRelationships`. They differ primarily in cache lifetime and save boundary.

#### Why this refactor is high value

- Prevents single and batch import metadata from drifting.
- Reduces the riskiest duplication before attempting a broader actor split.
- Preserves the existing ModelActor isolation boundary.
- Uses existing single, batch, and relationship tests as characterization coverage.

#### Recommended boundary

First create one private actor-isolated insertion helper that does not save. Keep public single and batch methods and their current save semantics. After parity tests pass, move pure metadata/support types and normalization logic into focused files. Do not create several ModelActors or change schema in this work.

#### Preserve

Single save, batch save, relationship caching, persistent identifiers, source hashes, metadata fields, logging category, and error mapping.

#### Validation

Parameterize single/batch parity across all fields, unknown values, existing relationships, artwork, source identity, favorite state, and save failure. Keep SwiftData schema and migrations unchanged.

#### Limitation

Macro expansion and strict-concurrency compilation are **UNVERIFIED — needs Xcode build**.

---

### WP4-R06 — Own AsyncStream producer lifetime and cancellation

**Priority:** P1
**Confidence:** Confirmed by source and current Swift documentation
**Value:** High
**Risk:** Medium

#### Evidence

Three stream builders spawn producer tasks without retaining them or assigning `continuation.onTermination`:

- `Fonic HiFi/Data/Actors/FileImportProcessor.swift:102-105`
- `FileImportProcessor.swift:143-155`
- `FileImportProcessor.swift:237-256`

```swift
AsyncStream { continuation in
    Task { await self.emitDiscoveredFiles(from: urls, to: continuation) }
}
```

The outer `LibraryImportService` owns an import task and discovery task, but the processing/discovery stream producers remain independently spawned:

- `Fonic HiFi/Data/Services/LibraryImportService.swift:49,90-105,193-237`

Existing processor tests cover success, duplicates, mixed outcomes, directory discovery, async sequence input, and aggregation. They do not terminate a consumer early or assert producer cancellation.

Apple documents `AsyncStream.Continuation.onTermination` as the cancellation cleanup hook and demonstrates stopping the underlying producer from that callback.

#### Why this refactor is high value

- Aligns cancellation ownership from UI/service through stream producers.
- Makes “cancel” mean no new work after a defined boundary.
- Reduces hidden background work and post-cancellation persistence risk.
- Creates testable producer lifetime semantics.

#### Recommended boundary

Retain each producer task, cancel it from `onTermination`, stop on `.terminated`, and check cancellation before scheduling/committing work. Preserve current buffering and completion-order behavior.

#### Preserve

Public stream types, concurrency limit, completion ordering, duplicate result semantics, security-scope balance, metrics, and service progress.

#### Validation

Exit after first element, cancel during discovery, cancel at full concurrency, assert no new work begins, assert no post-cancel track is committed, and assert all security scopes close. Use controllable extractor/copy/persistence doubles.

#### Limitation

Cancellation timing through SwiftData and file-provider I/O is **UNVERIFIED — needs Xcode tests/device check**.

---

### WP4-R07 — Use one injectable process-metrics provider

**Priority:** P1 and recommended first implementation slice
**Confidence:** Confirmed by duplicate system responsibility and tests
**Value:** Medium-High
**Risk:** Low-Medium

#### Evidence

`AVAudioEngineAdapter.getMetrics()` calls two private Mach-backed helpers:

- `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:404-417,585-634`

```swift
let cpuUsage = getCurrentCPUUsage()
let memoryUsage = getCurrentMemoryUsage()
```

The adapter has two `task_info` calls. `SystemMetricsCollector.swift:301-350` already owns CPU/memory collection and has its own `task_info` query plus delta-based CPU calculation.

The adapter’s CPU helper derives a percentage from resident memory:

```swift
return Float(info.resident_size) / Float(1024 * 1024 * 1024) * 100
```

This is both a duplicate responsibility and a poor test seam. `AVAudioEngineAdapterTests` only asserts nonnegative metrics; collector tests already exist.

#### Why this refactor is high value

- Removes OS process probes from the audio graph adapter.
- Establishes one definition and unit for process metrics.
- Enables exact deterministic adapter tests.
- Has no persisted-data or audio-graph change.

#### Recommended boundary

Add a narrow `ProcessMetricsProviding` protocol or adapter around the existing collector. Inject it into the adapter with a production default. Keep `AudioEngineService.getMetrics()` unchanged.

#### Preserve

AudioMetrics fields/units, buffer-underrun count, timestamp, engine API, and all audio behavior.

#### Validation

Inject known CPU/memory values and assert exact mapping. Keep real collector smoke tests. Verify the adapter no longer contains Mach queries. Run the full adapter/EQ/gapless tests.

#### Limitation

Real metric fidelity remains **UNVERIFIED — needs device comparison with Instruments**.

---

### WP4-R08 — Compile one canonical app/widget shared-data contract

**Priority:** P1
**Confidence:** Confirmed by exact comparison and project structure
**Value:** High
**Risk:** Medium because target membership changes

#### Evidence

These app/widget pairs are identical from line 8 onward; only header comments differ:

- `Fonic HiFi/Shared/WidgetConstants.swift`
- `Fonic HiFi Widget/Shared/WidgetConstants.swift`
- `Fonic HiFi/Shared/WidgetPlaybackState.swift`
- `Fonic HiFi Widget/Shared/WidgetPlaybackState.swift`
- `Fonic HiFi/Shared/WidgetTrackInfo.swift`
- `Fonic HiFi Widget/Shared/WidgetTrackInfo.swift`

`Fonic HiFi.xcodeproj/project.pbxproj:79-104,183-185,236-248` shows separate file-system-synchronized app and widget roots. This avoids duplicate symbols today but allows the two schemas and keys to drift independently.

#### Why this refactor is high value

- Makes contract drift a compile-time/source-control issue.
- Removes three duplicated executable schemas.
- Preserves a small, explicit integration boundary between app and widget.

#### Recommended boundary

Prefer one neutral shared directory whose files compile in both targets. If synchronized-folder target membership cannot represent that safely, use a tiny local Swift package. As a temporary fallback only, keep the copies and add semantic-diff CI plus bidirectional fixed fixtures.

#### Preserve

App Group identifier, UserDefaults keys, widget kind, Codable fields/defaults, date strategy, payload compatibility, widget UI, intents, and timeline behavior.

#### Validation

Build both targets, run app-to-widget and widget-to-app fixed-fixture round trips, decode a legacy fixture, and confirm one canonical source with no duplicate symbols.

#### Limitation

Target membership and extension compilation are **UNVERIFIED — needs Xcode build**.

## Rejected and deferred candidates

### RC-01 — Split the two largest diagnostics model files

**Disposition:** Rejected.

`PlaybackDiagnosticModels.swift` is 1,252 lines but contains 60 data/enum declarations and no executable functions, tasks, file I/O, or state wrappers. `AudioMonitoringService.swift` is 910 lines but contains 34 data/enum declarations and no executable functions. Splitting may improve navigation, but size alone does not justify Work Package 4 churn.

### RC-02 — Broadly decompose AVAudioEngineAdapter

**Disposition:** Rejected for this work package.

The audio graph, format reconnect, dual-player gapless path, EQ graph, completion callbacks, and device behavior are tightly coupled and high risk. Only the isolated process-metrics extraction in WP4-R07 has a safe boundary. Broader work requires Xcode, audio fixtures, Instruments, and physical-device tests.

### RC-03 — Move LibraryView private types into separate files

**Disposition:** Rejected as a standalone recommendation.

`LibraryView.swift` is 818 lines with 14 types, but file moves alone do not improve request ownership or testability. Component extraction is acceptable only as a mechanical part of WP4-R03 and must not change identity or behavior.

### RC-04 — Extract the smart-playlist evaluator now

**Disposition:** Deferred to Work Package 5.

`PlaylistDetailView` is referenced only by `PlaylistListView` and `SearchPlaylistResultsView`. `PlaylistListView` has no external constructor call beyond its preview, and `SearchPlaylistResultsView` has no external reference. The first decision is whether this path is obsolete. Refactoring potentially removable code would be waste.

### RC-05 — Consolidate ImportSession with FileImportProcessor

**Disposition:** Deferred to Work Package 5.

`ImportSession` has no production constructor call; tests construct it. The active import service constructs `FileImportProcessor`. Cleanup/reachability must decide whether `ImportSession` survives before consolidation is designed.

### RC-06 — Split GlassModifiers.swift because it is large

**Disposition:** Rejected.

It is an aggregation of small named modifiers without the state, I/O, concurrency, or testability coupling required for a high-value recommendation.

## Recommended order

1. Phase 0 characterization baseline.
2. WP4-R07 process-metrics provider.
3. WP4-R05 TrackDataActor insertion kernel.
4. WP4-R06 AsyncStream producer ownership.
5. WP4-R02 queue mutation/persistence seam.
6. WP4-R01 unified audio presentation state.
7. WP4-R03 Library request ownership/load phase.
8. WP4-R04 FileManager model/service.
9. WP4-R08 canonical widget contract.

WP4-R02 should precede WP4-R01 because the presentation store needs a stable queue snapshot/event boundary. WP4-R07 is the safest first implementation slice and can validate the repository’s refactor workflow before core state changes.

The full agent-ready sequence, file boundaries, preserve/do-not-touch rules, tests, and rollback guidance are in `plans/01_PHASED_REFACTORING_PLAN.md`.

## Verification performed

### Passed

- Exact checkpoint/archive SHA-256 verification.
- Exact repository commit match.
- Clean worktree before, during, and after review.
- Mechanical inventory across 325 Swift files and 60,262 lines.
- Symbol/reference mapping.
- Exact body comparison for all three app/widget contract pairs.
- 23 of 23 targeted static evidence assertions.
- `git diff --check`.
- `git diff --exit-code`.
- Python compilation of the analysis/verification scripts.

### Attempted but unavailable

- `make check-deps`: failed before execution because `make` is unavailable.
- `make lint`: failed before execution because `make` is unavailable.
- Swift/SwiftLint/SwiftFormat: unavailable.
- Xcode, `xcodebuild`, `xcrun`, simulator, and Apple SDKs: unavailable.

No build, test, lint, Xcode Analyze, Thread Sanitizer, simulator, device, Instruments, signing, TestFlight, or App Store validation is claimed.

## Important limitations

1. This was a static, Linux-based review at one exact commit.
2. No Apple SDK compilation or macro expansion was available.
3. Runtime performance magnitude, SwiftUI invalidation, cancellation timing, file-provider behavior, audio behavior, and cross-target membership remain unverified.
4. Prior reports were not comprehensively deduplicated or Critical/High re-verified because those are separate work packages.
5. The inherited `.claude/skills/ios-simulator-skill` gitlink has no matching `.gitmodules` entry. It was recorded but not changed; cleanup belongs to Work Package 5.
6. No prior report or ZIP content is included in this deliverable.

## Official sources consulted

Accessed 2026-07-11:

1. Apple, Managing model data in your app
   https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app
2. Apple, Optimize SwiftUI performance with Instruments, WWDC25 session 306
   https://developer.apple.com/videos/play/wwdc2025/306/
3. Apple, AsyncStream
   https://developer.apple.com/documentation/swift/asyncstream
4. Apple, AsyncStream.Continuation.onTermination
   https://developer.apple.com/documentation/swift/asyncstream/continuation/ontermination

## Next-session recommendation

Set `CURRENT WORK PACKAGE` to **5**. Work Package 5 should first resolve reachability/cleanup decisions for the orphaned smart-playlist presentation path and test-only `ImportSession`, then assess the inherited malformed gitlink and other project clutter. Do not implement the refactoring plan until Keiran explicitly approves source changes.
