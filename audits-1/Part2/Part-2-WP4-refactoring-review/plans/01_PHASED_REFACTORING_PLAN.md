# Fonic HiFi Work Package 4 phased refactoring plan

Repository baseline: `main` at `459db9bfd18d17960e8fd2ff8defc4701085532e`.

Status: assessment and plan only. No source change is included.

## Non-negotiable implementation guardrails

1. Obtain explicit approval before starting Phase 2 because it changes core state ownership.
2. Work on one retained opportunity per branch or commit. Do not combine unrelated cleanup.
3. Build and run targeted tests after every opportunity, then run the full unit/UI suite before merging.
4. Preserve public behavior, user-facing copy, navigation, layout, visual design, persistence keys, Codable fields, App Intent names, widget kinds, and audio behavior unless a separately approved defect fix requires a change.
5. Do not broadly reformat files. Keep diffs mechanical and reviewable.
6. Do not change audio graph wiring, engine selection, gapless scheduling, EQ behavior, shuffle algorithms, repeat semantics, or SwiftData schema as collateral work.
7. If a characterization test exposes existing behavior that appears wrong, record it. Do not silently change the expected behavior inside a refactor.
8. Run Xcode, simulator, and device checks on macOS. The Linux review environment cannot validate Apple SDK compilation or runtime behavior.

## Phase 0 — Approval and characterization baseline

### Purpose

Freeze the current observable behavior before moving ownership boundaries.

### Required work

1. Clean-build the app, widget, unit tests, and UI tests with the repository’s supported Xcode 26 toolchain.
2. Run the existing suite and archive the `.xcresult` and test summary.
3. Add characterization tests only. Do not refactor in this phase.
4. Record baseline queue delegate counts, queue persistence writes, Now Playing state after external intent changes, library overlapping request behavior, import cancellation, file-manager operation outcomes, adapter metrics, and app/widget payload round trips.

### Exit gate

- Existing test result is archived.
- New characterization tests pass against the unrefactored baseline, or any test that intentionally demonstrates an existing defect is clearly marked and not used as a false green gate.
- Repository is clean before the first refactor branch.

## Phase 1 — Small seams with narrow blast radius

### 1A. WP4-R07 — Process-metrics provider extraction

#### Change

- Add a narrow `ProcessMetricsProviding` protocol near the diagnostics layer. It should return the CPU and resident-memory values needed by `AudioMetrics`.
- Make the existing system metrics implementation satisfy that protocol, directly or through a small adapter.
- Inject the provider into `AVAudioEngineAdapter.init`, preserving the existing default so production call sites do not change.
- Replace `getCurrentCPUUsage()` and `getCurrentMemoryUsage()` in `AVAudioEngineAdapter` with the injected provider.
- Remove the adapter’s direct Mach import only after no adapter code needs it.

#### Primary files

- `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift`
- `Fonic HiFi/Core/Audio/Diagnostics/SystemMetricsCollector.swift`
- A new narrowly named metrics protocol/adapter file if needed
- `Fonic HiFiTests/AVAudioEngineAdapterTests.swift`
- `Fonic HiFiTests/AudioMonitoringCollectorsTests.swift`

#### Preserve

- `AudioEngineService.getMetrics()` signature
- Existing `AudioMetrics` field meanings and units
- Buffer-underrun accounting and timestamps

#### Do not touch

- AVAudioEngine graph, player nodes, EQ, gapless preparation, scheduling, or session behavior

#### Tests

- Inject a deterministic metrics stub and assert exact CPU/memory propagation.
- Preserve nonnegative runtime smoke coverage for the real collector.
- Assert no Mach query remains in `AVAudioEngineAdapter`.

#### Rollback

Restore the two private adapter helpers and default initializer. No persisted data changes are involved.

### 1B. WP4-R05 — Track insertion kernel

#### Change

- Introduce one private actor-isolated helper that constructs and inserts a `Track`, applies all `TrackMetadata`, and links album/artist relationships without saving.
- Have `createTrack(from:)` call it once and then save.
- Have `createTracks(from:)` call it for every item with shared artist/album caches and then save once.
- Keep error types and save boundaries unchanged.
- Only after parity tests pass, move pure supporting types and pure normalization logic into focused files. Do not split persistence into new actors in this phase.

#### Primary files

- `Fonic HiFi/Data/Actors/TrackDataActor.swift`
- Optional new pure helper/support files
- `Fonic HiFiTests/TrackDataActorTests.swift`

#### Preserve

- Single-create save semantics
- Batch atomic save semantics
- Artist/album lookup and caching behavior
- Persistent identifiers, relationship linking, source hashes, metadata fields, and error mapping

#### Do not touch

- SwiftData schema, migration plan, model annotations, cleanup behavior, listening-session storage, or public method signatures

#### Tests

- Parameterize a parity matrix across single and batch creation.
- Compare every persisted metadata field and relationship.
- Test unknown artist/album normalization and existing artist/album reuse.
- Force save failure and verify the same public error category as baseline.

#### Rollback

Inline the helper back into the two public methods. No schema or migration change is allowed, so rollback remains source-only.

### 1C. WP4-R06 — AsyncStream producer ownership

#### Change

- Replace each anonymous producer `Task` in `FileImportProcessor` stream builders with an owned task handle.
- Set `continuation.onTermination` to cancel that task.
- Stop producing when cancellation is observed or `yield` reports `.terminated`.
- Preserve buffering policy and result ordering.
- Keep the outer `LibraryImportService` task ownership intact, but verify cancellation propagates through discovery, queue, child tasks, file copy, metadata extraction, and persistence checkpoints.

#### Primary files

- `Fonic HiFi/Data/Actors/FileImportProcessor.swift`
- `Fonic HiFi/Data/Services/LibraryImportService.swift` only if required for explicit propagation
- `Fonic HiFiTests/FileImportProcessorTests.swift`
- `Fonic HiFiTests/ImportPipelineTests.swift`
- `Fonic HiFiTests/LibraryImportServiceTests.swift`

#### Preserve

- Stream element type, ordering by completion, duplicate result semantics, security-scope balancing, concurrency limit, metrics, and public service progress

#### Do not touch

- File naming policy, SwiftData schema, metadata extraction, or duplicate identity rules

#### Tests

- Consumer exits after the first element; assert the producer stops.
- Cancel during discovery and during full concurrency; assert no new work starts after the cancellation boundary.
- Assert every started security scope is stopped.
- Assert no post-cancellation track is created and no extra result is yielded.
- Keep existing success, duplicate, mixed-result, and nested-directory tests green.

#### Rollback

Restore the old stream builders. This phase must not alter persisted formats.

## Phase 2 — Core state ownership, explicit approval required

### 2A. WP4-R02 — Queue mutation transaction and persistence seam

#### Change

- Introduce a small `QueueStatePersisting` boundary with load, schedule/save, flush, and clear operations.
- Inject it into `AudioQueueManager`, preserving a production default.
- Replace notification-owned persistence with one mutation-finalization path. A logical public operation should:
  1. mutate queue fields;
  2. recalculate navigation state once;
  3. emit only the delegate events whose values changed;
  4. emit one immutable queue snapshot;
  5. request persistence once.
- Move expensive file validation and encoding off the MainActor through the persistence boundary.
- Preserve the current persistence key and decode format for the first implementation. A storage-format migration is a separate decision.

#### Primary files

- `Fonic HiFi/Core/Audio/Queue/AudioQueueManager.swift`
- `Fonic HiFi/Core/Audio/Queue/QueueState.swift`
- A new queue persistence protocol/implementation
- `Fonic HiFiTests/AudioQueueManagerTests.swift`
- `Fonic HiFiTests/QueueStateTests.swift`
- `Fonic HiFiTests/QueueCoordinatorTests.swift`

#### Preserve

- Queue ordering, current-index updates, shuffle/repeat results, history behavior, delegate event meaning, restoration window, persistence key, Codable schema, and public queue API

#### Do not touch

- Playback engine, crossfade/gapless logic, App Intents, widget payload schema, or UI layout

#### Tests

- Inject a spy persister.
- Assert `replaceQueue`, `clear`, `remove`, `move`, `insert`, and current-index changes produce exactly one persistence request per logical operation.
- Assert delegate event counts and order remain at the characterized baseline unless separately approved.
- Assert missing-file validation occurs at the chosen restore/maintenance boundary, not on the MainActor hot mutation path.
- Force persistence failures and confirm queue memory state remains usable while the error is recorded.
- Profile 100, 1,000, and 10,000 lightweight entries on device.

#### Rollback

Keep an adapter that implements the new protocol with the old synchronous `QueueState.save/load/clear` functions until the branch is stable. If needed, revert the injected boundary without changing the persisted payload.

### 2B. WP4-R01 — Unified audio presentation state

#### Change

- Define one `@MainActor @Observable` presentation model containing only UI-consumed state: current track, playback phase/time/duration, queue control state, playback rate, volume if the engine owns it, A-B loop state, mini-player visibility, and diagnostics summary.
- Make `AudioEngineFacade` expose that model or become the observable model itself. Do not keep the same value in `PlaybackStateManager`, `AudioUIState`, facade `@Published` properties, `@AppStorage`, and view-local `@State` simultaneously.
- Inject the observable model with type-based `.environment(model)` and read it with `@Environment(Model.self)` where deployment support allows. If the app keeps `ObservableObject`, use `@EnvironmentObject`/`@ObservedObject` consistently instead. Do not mix both systems for the same fields.
- Derive Now Playing shuffle, repeat, speed, favorite, queue, play/pause, current time, and duration from the authoritative store.
- Keep persistence in the queue/settings/data owners, not in views.
- Split `NowPlayingContent` into state-light subviews only after the observation boundary works and characterization tests pass.

#### Primary files

- `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift`
- `Fonic HiFi/Core/Audio/Engine/AudioUIState.swift`
- `Fonic HiFi/Core/Audio/Coordinators/StateCoordinator.swift`
- `Fonic HiFi/Core/Audio/Playback/PlaybackStateManager.swift`
- `Fonic HiFi/Presentation/Environment/AudioEnvironment.swift`
- `Fonic HiFi/ContentView.swift`
- `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift`
- `Fonic HiFi/Presentation/Views/NowPlaying/LiquidGlassMiniPlayer.swift`
- `Fonic HiFi/Presentation/Views/Queue/QueueView.swift`
- Direct audio-setting and track-row consumers
- Facade/state/queue/UI tests

#### Preserve

- Every public playback command and engine behavior
- App Intent and widget control behavior
- Current user defaults and queue/settings persistence
- Current UI hierarchy, copy, transitions, appearance, and control semantics

#### Do not touch

- Audio graph, engine selection, EQ, gapless/crossfade, widget schema, or visual design

#### Tests

- Open Now Playing, change shuffle through `ToggleShuffleIntent`, and assert the displayed state updates.
- Restore nondefault repeat and speed, then assert menu/checkmark/control state matches without local initialization.
- Mutate queue from intent/widget/service paths and assert QueueView and mini-player update.
- Assert unrelated diagnostic updates do not invalidate every playback row using the SwiftUI Cause & Effect instrument.
- Test favorite success and failure without optimistic state divergence.
- Run playback controls, Control Center, interruption, route, and restoration scenarios on device.

#### Rollback

Migrate one state slice at a time behind compatibility accessors. Keep the old façade properties until each consumer and test has moved; remove them only in a final cleanup commit.

## Phase 3 — Active UI/data flows

### 3A. WP4-R03 — Library section state and request ownership

#### Change

- Replace the parallel array/state fields with one typed per-section state abstraction, or retain typed storage but make each section own an in-flight task/request generation.
- Mark stored state loading before suspension.
- On refresh/query change, cancel the prior request or increment a generation token; apply a response only if it still matches the latest section/query/generation.
- Model load phase explicitly: idle, initial loading, loaded, paging, failed.
- Render the full-screen overlay only for initial loading of an empty section. Keep pagination inline.
- Move debounce/request ownership into the view model so view disappearance and query changes have one cancellation owner.

#### Primary files

- `Fonic HiFi/Presentation/ViewModels/Library/LibraryViewModel.swift`
- `Fonic HiFi/Presentation/Views/Library/LibraryView.swift`
- `Fonic HiFiTests/LibraryViewModelTests.swift`
- Targeted UI tests for pagination/loading behavior

#### Preserve

- Four tabs, search behavior, page size/prefetch threshold, item identity, selection sheets, import/create actions, error text, and row/grid appearance

#### Do not touch

- Repository query semantics, SwiftData schema, navigation design, or library UI styling

#### Tests

- Complete query A after query B and assert A cannot overwrite B.
- Start two page requests at the same threshold and assert one repository call.
- Load two sections concurrently and assert independent phase state.
- Cancel on query/tab change and assert stale errors/results are ignored.
- Assert initial load blocks as characterized and pagination leaves existing content interactive.

#### Rollback

Keep repository/use-case interfaces unchanged. Revert only the view-model state implementation and view phase rendering if needed.

### 3B. WP4-R04 — File manager model and service

#### Change

- Create a filesystem protocol for list, metadata, copy, delete, create-directory, parent/root containment, and unique-destination behavior.
- Implement it in a non-view service/actor.
- Move operation state into an observable `FileManagerViewModel` with explicit loading and error/result states.
- Keep the SwiftUI view responsible only for presentation, selection binding, and user intent forwarding.
- Replace root-view-controller alert presentation with SwiftUI-owned folder-name state and an alert/dialog binding. Preserve the same action and copy.
- Return structured partial-failure results for batch delete/copy so selection is cleared only for successful items or according to explicitly approved behavior.

#### Primary files

- `Fonic HiFi/Presentation/Views/Settings/FileManagerView.swift`
- New filesystem protocol/service
- New `FileManagerViewModel.swift`
- New unit tests and targeted UI tests

#### Preserve

- Settings entry point, current root directory, sorting/filtering, file importer types, batch actions, unique-copy naming, security-scope behavior, and visible copy

#### Do not touch

- Library import pipeline, managed music-container naming, app navigation, or visual design

#### Tests

- Deterministic in-memory/temp-directory listing, sort, search, parent bounds, create, copy collision, delete success/partial failure, and security-scope balancing.
- Cancellation during copy/list refresh.
- UI test for folder-name prompt, selection, delete confirmation, and surfaced errors.

#### Rollback

Keep a default service adapter matching existing FileManager behavior. The view can temporarily call that adapter directly if the model migration must be reverted.

## Phase 4 — Cross-target contract

### 4A. WP4-R08 — Canonical widget contract

#### Change

Choose one of these after checking Xcode target membership:

1. Preferred: place the three contract files in a neutral shared directory and compile the same files into app and widget targets.
2. Alternative: create a tiny local Swift package used by both targets if target membership cannot safely share files.
3. Temporary fallback only: keep two copies but add a deterministic semantic-diff CI check and bidirectional fixture tests.

The canonical contract must include `WidgetConstants`, `WidgetPlaybackState`, and `WidgetTrackInfo`. Preserve every key, field, default, date strategy, and App Group identifier.

#### Primary files

- The six existing app/widget shared contract files
- `Fonic HiFi.xcodeproj/project.pbxproj`
- App/widget contract tests and CI configuration if the fallback is selected

#### Preserve

- App Group identifier
- UserDefaults keys
- Widget kind
- Codable field names and defaults
- ISO-8601 date strategy for playback state
- Existing payload compatibility

#### Do not touch

- Widget design, timeline policy, App Intents, Live Activity behavior, artwork cache policy, or bundle identifiers

#### Tests

- App encode to widget decode and widget encode to app decode using fixed fixtures.
- Decode a checked-in legacy fixture.
- Build both targets from a clean checkout.
- Confirm no duplicate-symbol errors and exactly one source of contract truth.

#### Rollback

Retain the original six files until both targets build and fixtures pass. If shared membership fails, restore the files and enable the semantic-diff guard as the temporary safety net.

## Final integration gate

1. Clean-build Debug and Release for app and widget.
2. Run all unit and UI tests.
3. Run SwiftLint strict and Xcode Analyze.
4. Run Thread Sanitizer for import/library concurrency tests where supported.
5. Use SwiftUI Instruments Cause & Effect for Now Playing, Queue, and Library pagination.
6. Use Time Profiler and File Activity for queue mutations at scale.
7. Test physical-device playback, Control Center, interruptions, route changes, queue restore, app/widget payload exchange, file import cancellation, and file-manager operations.
8. Compare public API, persisted keys, Codable fixtures, screenshots, accessibility labels, and behavior against Phase 0.
9. Merge only when each phase has its own passing evidence and rollback point.

## Recommended first implementation slice

After explicit approval, start with WP4-R07. It is isolated, covered by existing tests, and does not change persisted data or audio graph behavior. Then complete WP4-R05 and WP4-R06 before moving to the approval-gated queue and presentation-state phases.
