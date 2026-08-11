# Audio & Data Audit Remediation Plan (2026-08-10)

> **For the executing agent:** Work task-by-task with the executing-plans discipline. Read the root `AGENTS.md`, `Core/Audio/AGENTS.md`, `Data/AGENTS.md`, and `Presentation/AGENTS.md` before starting a phase that touches those subtrees. Never commit, stage, or push unless the user explicitly requests it; each phase lists a *proposed* Conventional Commit boundary only.

**Goal:** Remediate every confirmed finding from the two 2026-08-09/10 audits (`docs/audits/audio-end-to-end-audit-2026-08-09.md` plus the Codex end-to-end audit) — playback correctness, user-data safety, identity/transactional integrity, session/remote lifecycle, engine parity, import pipeline, UI/widget wiring, and dead-code cleanup.

**Architecture:** Fixes are grouped into ten phases ordered by severity and dependency. Phases 1 (playback core) and 2 (user-data safety) are independent and both Critical; do them first, in either order. Later phases depend on earlier boundaries (e.g., queue UI rewiring depends on new facade APIs). Every fix extends the existing facade/controller/coordinator/actor boundaries — no new sources of truth.

**Tech stack:** Swift 6 strict concurrency, iOS 27.0 deployment, Xcode 27, AVFoundation/AVAudioEngine, AudioKit 5.6.5 (pinned), SwiftData, WidgetKit, XCTest + Swift Testing via `make` lanes.

**Approved scope decisions (2026-08-10, user-confirmed):**
1. **Delete** the dead ~2,750-line diagnostics pipeline; keep `DiagnosticsStatus` and `SignalPathSnapshot` (live).
2. Info.plist/entitlement work **approved**: widget URL scheme + `onOpenURL` handler; FLAC/APE/DSD `UTImportedTypeDeclarations`; removal of unused `aps-environment` and `NSSupportsLiveActivities`. No other plist/entitlement/signing changes are in scope.
3. Crossfade on the AVAudioEngine path: **implement a real two-node volume ramp**.
4. EQ gap: **EQ-aware engine selection** (enabled EQ forces an EQ-capable engine); no AudioKit EQ stage.

---

## Ground rules (apply to every task)

- Validation ladder per repo policy: `make lint` → `make test-focus ONLY="Fonic HiFiTests/<Class>[/test]"` → `make build` → escalate to `make test-unit` only when shared state/protocols/multiple call sites changed. `make test`, `make test-ui`, `make coverage-check` are reserved for the final phase and the UI-fixture task.
- Test-first where a regression test is expressible: write the failing test, run it, watch it fail for the right reason, implement, re-run green.
- No `print()`, no lint/check suppression, no `nonisolated(unsafe)`, no `@unchecked Sendable`, no detached tasks. Log via `Log.logger(_:)` with `LogPrivacy`.
- File-system-synchronized groups: new source/test files are auto-discovered; **do not touch `project.pbxproj`** except for the explicitly approved plist items in Phase 8 (and those live in Info.plist, not the pbxproj, unless a build-setting reference forces it — verify first).
- Clean `build/` artifacts you created at the end of each session; after UI or parallel test runs: `xcrun simctl --set testing delete all`.
- Run `git diff --check` before declaring any phase done.
- Hardware-only claims stay `UNVERIFIED` until the Phase 10 device pass. Do not claim "fixed" for audible pause/resume, gapless, route, or focus behavior from simulator evidence alone.

---

## Phase 1 — Playback correctness core (Critical C1–C4, both audits)

One scoped change to `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift` plus focused tests. Root cause: the adapter has no "resume" distinct from "start", and no single teardown for an armed gapless transition.

### Task 1.1: Failing tests for resume/pause/prepared-transition semantics

**Files:**
- Modify: `Fonic HiFiTests/AVAudioEngineAdapterTests.swift`
- Reference harness: `Fonic HiFiTests/AVAudioEngineGaplessWaveformTests.swift` (existing generated-PCM waveform harness — reuse its fixture generation)

**Step 1:** Add failing tests (generated PCM fixtures, short files, real `AVAudioFile`s):
- `testPauseResumeSchedulesTrackExactlyOnce` — load → play → pause → play; assert exactly **one** completion callback fires, total rendered duration ≈ one track length, and `currentTime` is monotonic across the resume.
- `testSeekPauseResumePreservesTimeBase` — seek(to: t) → pause → play; assert `currentTime` ≥ t (the resume must not reset `scheduledStartFrame` to 0).
- `testRepeatedPauseResumeDoesNotAccumulateSchedules` — three pause/resume cycles; still one completion.
- `testPauseDisarmsPreparedTransition` — play → `prepareNext(url:)` → pause; advance past the original boundary host time; assert the inactive player never rendered (waveform harness: output is silent after pause) and no next-track completion fires.
- `testPlayAfterPreparedTransitionStopsArmedInactivePlayer` — prepareNext → pause → play (fresh-schedule path via load); assert the armed inactive node is stopped and only one track renders.
- `testConfigureWhilePlayingDoesNotStopPlayback` — play → `configure(with:)` (changed crossfade duration); assert node still playing and schedule intact.

**Step 2:** `make test-focus ONLY="Fonic HiFiTests/AVAudioEngineAdapterTests"` — all six FAIL (double schedule / armed transition / stopped engine), for the documented reasons.

### Task 1.2: Implement resume semantics + shared teardown + non-destructive configure

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift` (`play()` ~:310, `pause()` ~:366, `seek(to:)` ~:400, `configure(with:)` ~:459, `unloadTrack()` ~:381)

**Step 1:** Add suspended-schedule state and one teardown helper:

```swift
/// True when pause() suspended a node that still owns its un-rendered schedule.
/// A resume must NOT re-schedule; doing so appends a second copy of the track.
private var isSuspendedWithPendingSchedule = false

private func invalidateArmedInactivePlayer() {
    let inactivePlayer = isPrimaryActive ? secondaryPlayerNode : primaryPlayerNode
    inactivePlayer.stop()
    preparedFile = nil
    preparedTransition = nil
    unconsumedPreparedURL = nil
    hasNextPrepared = false
}
```

**Step 2:** Rework `play()`:
- If `isSuspendedWithPendingSchedule` and the current file/generation are intact: start engine if needed, `try activePlayer.playAudio()`, clear the flag, publish `.playing`, **return** — do not touch `playbackGeneration`, `scheduledStartFrame`, or prepared state.
- Fresh-schedule path: call `invalidateArmedInactivePlayer()` (fixes C3) **before** creating the new generation and scheduling; keep existing generation-scoped completion.

**Step 3:** Rework `pause()`: set `isSuspendedWithPendingSchedule = true`, disarm the prepared transition (stop inactive player + clear bookkeeping — reuse the helper, fixes C2), then `activePlayer.pause()` and publish `.paused`. `PlaybackController.resume()` already re-arms preparation afterwards (`PlaybackController.swift:177`), so gapless recovers on resume.

**Step 4:** Clear `isSuspendedWithPendingSchedule` in `load`, `seek(to:)` (it re-schedules its own segment), `stop()`/`unloadTrack()`, and on completion callbacks for the active generation.

**Step 5:** Make `configure(with:)` non-destructive (fixes C4 — nothing in the graph derives from the stored configuration, and `engine.stop()` discards pending schedules):

```swift
public func configure(with configuration: AudioEngineConfiguration) async throws {
    self.configuration = configuration
}
```

**Step 6:** `make test-focus ONLY="Fonic HiFiTests/AVAudioEngineAdapterTests"` — green. Then `make test-focus ONLY="Fonic HiFiTests/AVAudioEngineGaplessWaveformTests"`, `make test-focus ONLY="Fonic HiFiTests/PlaybackControllerTests"`, `make test-focus ONLY="Fonic HiFiTests/StateCoordinatorInterruptionTests"` (lock-screen play and interruption-end reach this path), then `make build`.

**Proposed commit:** `fix(audio): make resume reuse the pending schedule and disarm gapless on pause`

**Hardware flag:** audible single-play on resume and silent-pause-past-boundary remain `UNVERIFIED` until Phase 10.

---

## Phase 2 — User-data safety (Critical/High, Codex #3/#4/#7 + docs Medium)

### Task 2.1: Protect the managed music root from File Manager deletion

**Files:**
- Modify: `Fonic HiFi/Core/Services/FileSystemService.swift` (`deleteItems` :175, `copyItems`, `createDirectory`)
- Modify: `Fonic HiFi/Presentation/ViewModels/FileManagerViewModel.swift`, `Fonic HiFi/Presentation/Views/Settings/FileManagerView.swift`
- Test: create `Fonic HiFiTests/FileSystemServiceTests.swift`; modify `Fonic HiFiTests/FileManagerViewModelTests.swift`

**Step 1:** Failing tests: deleting `Documents/Music`, any descendant of it, or a symlink resolving into it throws a new `FileSystemServiceError.libraryOwnedMedia`; deleting an unrelated `Documents/` file still succeeds; view model surfaces a distinct user-facing error for library-owned paths.

**Step 2:** Implement: inject the managed media root (same derivation as `FileImportProcessor` :93 — `Documents/Music`) into `FileSystemService` as a protected subtree. In `deleteItems`, after `validatedURL`, reject when `target.resolvingSymlinksInPath().standardizedFileURL` equals or is a descendant of the protected root. Guard move/overwrite destinations the same way. In the view, visually mark the Music directory as library-managed and remove it from multi-select deletion.

**Step 3:** `make test-focus ONLY="Fonic HiFiTests/FileSystemServiceTests"` and `.../FileManagerViewModelTests` — green.

> Deletion of *managed tracks* with full SwiftData/queue/playlist cleanup is deliberately **not** re-implemented here; library deletion already flows through the repository layer. This task only closes the raw-filesystem bypass.

### Task 2.2: Rebase managed URLs before quarantine/deletion in cleanup

**Files:**
- Modify: `Fonic HiFi/Data/Actors/TrackDataActor.swift` (`cleanupMissingFiles` :762)
- Reuse: `Fonic HiFi/Utils/ManagedMediaURLResolver.swift`
- Test: `Fonic HiFiTests/TrackDataActorTests.swift`

**Step 1:** Failing test: seed an in-memory store with tracks whose stored URLs use an **old container UUID** while the files exist at the current container's `Documents/Music`; run `cleanupMissingFiles` past all miss/day thresholds; assert the stored URL is repaired in place, `Track.id`, playlists, ratings, and history are untouched, and nothing is quarantined or deleted.

**Step 2:** Implement: in `cleanupMissingFiles`, when the raw stored URL is missing, resolve via `ManagedMediaURLResolver`; if the rebased file exists, persist the corrected URL (per `Data/AGENTS.md`: path repair preserves ID) and reset quarantine counters. Count a miss only when both locations are unavailable.

**Step 3:** `make test-focus ONLY="Fonic HiFiTests/TrackDataActorTests"` — green.

### Task 2.3: Read-only mutation policy for recovery/fallback modes

**Files:**
- Modify: `Fonic HiFi/Data/DataManager+Initialization.swift` (:260 ephemeral fallback, :305 "read-only" fallback), `Fonic HiFi/Data/DataManager.swift` (:38)
- Modify: import gating in `Fonic HiFi/Data/Services/LibraryImportService.swift` and the import entry point in `Fonic HiFi/Presentation/Views/Library/LibraryView.swift` (:360)
- Test: `Fonic HiFiTests/DeferredStartupWorkflowTests.swift` or a new `DataManagerRecoveryModeTests.swift`

**Step 1:** Failing tests: force production-store initialization failure; assert (a) the fallback `DataManager` rejects import, file deletion, and playlist mutation with a surfaced error, (b) no media file is copied into `Documents/Music`, (c) no second persistent store is created outside the intended location.

**Step 2:** Implement a `DataMutationPolicy` (`.normal` / `.readOnly`) carried by `DataManager` and enforced at the actor/service entry points (import service, `TrackDataActor` writes, playlist mutation). Ephemeral and last-resort fallbacks initialize `.readOnly`; the final fallback must not create a default persistent container — keep it in-memory. Disable the import UI when policy is read-only.

**Step 3:** Focused tests green; `make test-unit` for this phase (DataManager is shared state).

### Task 2.4: Freeze Schema V3 and add a real prior-store migration fixture

**Files:**
- Modify: the versioned schema definitions under `Fonic HiFi/Data/` (V3 currently references live model types)
- Test: `Fonic HiFiTests/MigrationPlanTests.swift`

**Step 1:** Snapshot V3 model definitions into immutable historical types (per `Data/AGENTS.md`). No behavior change intended — `make test-focus ONLY="Fonic HiFiTests/MigrationPlanTests"` must stay green.

**Step 2:** Add a migration test that opens a checked-in (test-fixture-generated) V1 store and migrates to current, asserting track identity and playlist survival. This is the guardrail that must exist **before** any later schema work.

**Proposed commit:** `fix(data): protect managed media, repair relocated URLs, and lock down recovery modes`

---

## Phase 3 — Release hygiene (small, high leverage; docs #18 + Metrics sink + UI-test fixture bug)

### Task 3.1: Guard UI-test fixture and reset paths with `#if DEBUG`

**Files:**
- Modify: `Fonic HiFi/FonicHiFiApp.swift` (all `ProcessInfo.arguments` UITest branches: :315, :399 `QueueState.clear()`, :403, :423, :492, :499)
- Modify: `Fonic HiFi/Utils/Logging/Metrics.swift` (:57 `setSinkForTesting`)

**Step 1:** Wrap every `-UITest*` launch-argument branch and the demo-fixture construction in `#if DEBUG`. Wrap `Metrics.setSinkForTesting` in `#if DEBUG`. UI tests build Debug (`Makefile:171`), so no coverage is lost.

**Step 2:** `make build` (Debug), then `make build-release` to prove the release binary compiles without the fixture paths. Run `make test-ui` once here to prove the UI suite still finds its fixtures.

### Task 3.2: Fix the mini-player UI-test expectation defect

**Files:**
- Modify: `Fonic HiFiUITests/LibraryNowPlayingSmokeTests.swift` (:733 `testMiniPlayerExposesSeparateSemanticActions`)

**Step 1:** The harness initializes `.playing` (`FonicHiFiApp.swift:495`), so the semantic action is correctly labeled `Pause` (`LiquidGlassMiniPlayer.swift:101`). Update the assertion to expect `Pause` (or launch with a paused fixture and expect `Play`). Covered by the Task 3.1 `make test-ui` run — 29/29 expected.

**Proposed commit:** `fix(release): compile out UI-test fixtures and test sinks from release builds`

---

## Phase 4 — Identity and transactional state (High, Codex #5/#6/#8; docs #15/#17)

### Task 4.1: Stop minting new UUIDs at the entity/queue boundaries

**Files:**
- Modify: `Fonic HiFi/Data/Models/Track.swift` (init :253 — add `id: UUID = UUID()` parameter)
- Modify: `Fonic HiFi/Domain/Entities/LibraryEntities.swift` (`asTrackRepresentation` :105 — pass the entity's stored id; copy ReplayGain, availability, favorite instead of hardcoding `isFavorite = false`)
- Modify: `Fonic HiFi/Core/Audio/Coordinators/QueueCoordinator.swift` (`createTrackFromAudioTrack` :171 — same)
- Test: `Fonic HiFiTests/QueueCoordinatorTests.swift`, `Fonic HiFiTests/SwiftDataLibraryRepositoryTests.swift`, `Fonic HiFiTests/ListeningSessionServiceTests.swift`

**Step 1:** Failing test: repository → entity → `asTrackRepresentation` → queue → facade round-trip preserves one stable `Track.id`; play-count/listening-session lookups hit the stored row; ReplayGain and favorite state survive next/previous navigation.

**Step 2:** Implement the parameter plumbing. Audit every `Track(` construction site (`rg "Track\("`) — only fixture/import sites may mint fresh IDs.

**Step 3:** Resolve favorite (and any user mutation) by durable UUID through the repository, not detached `persistentModelID`.

### Task 4.2: Introduce `PlayableTrackSnapshot` as the cross-actor currency

**Files:**
- Create: `Fonic HiFi/Domain/Entities/PlayableTrackSnapshot.swift`
- Modify: consumers in `QueueCoordinator`, `PlaybackController`, `AudioEngineFacade` launch-restoration path
- Test: extend `Fonic HiFiTests/QueueCoordinatorTests.swift`

```swift
struct PlayableTrackSnapshot: Sendable, Equatable {
    let id: UUID
    let resolvedURL: URL
    let replayGainTrack: Double?
    let replayGainAlbum: Double?
    let isAvailable: Bool
    // presentation metadata: title, artist, album, format, duration…
}
```

Replace the duplicated detached-`Track` factories (`createTrackFromAudioTrack` and the launch-restoration variant) with conversions through this one type. Uninserted sparse SwiftData models must no longer cross boundaries.

**Validation:** `make test-focus` on the three test classes above, then `make test-unit` (protocol/shared-state change).

### Task 4.3: Commit queue/UI state only after playback succeeds

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Coordinators/QueueCoordinator.swift` (:39 — peek/prepare/commit), `Fonic HiFi/Core/Audio/Engine/PlaybackController.swift` (`play` :119 — publish `.loading`/track only alongside a reversible snapshot)
- Modify: `Fonic HiFiTests/PlaybackControllerTests.swift` (:41 currently *asserts the incoherent result* — rewrite it to require restoration)
- Modify: `Fonic HiFi/Presentation/Views/Library/LibraryView.swift` (:410–421 — on failure call `reportPlaybackControlError`, clear current track, dismiss the Now Playing cover)

**Step 1:** Failing tests: inject failure at detection, load, play, and crossfade for direct play / next / previous / natural completion; assert queue index, `currentTrack`, engine state, and persisted queue all refer to the *prior* coherent state (or one coherent stopped/error state) — never a mix.

**Step 2:** Implement candidate-selection → prepare/start → atomic commit in `QueueCoordinator`; on failure restore the prior snapshot.

**Step 3:** `make test-focus ONLY="Fonic HiFiTests/PlaybackControllerTests"`, `.../QueueCoordinatorTests` — green.

### Task 4.4: Reliable SwiftUI invalidation from playback state

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift` (`setupStateBindings` :875, computed state :42, redundant `showMiniPlayer` writes :813–826)
- Modify: `Fonic HiFi/Core/Audio/Coordinators/StateCoordinator.swift` (:139 `RunLoop.main` hop)
- Test: `Fonic HiFiTests/AudioEngineFacadeOrchestratorTests.swift`, `Fonic HiFiTests/LiquidGlassMiniPlayerPresentationTests.swift`

**Step 1:** Failing test: subscribe to the facade's `objectWillChange`; drive play → pause → resume → seek → error → stop through the state manager; assert an emission per transition (today pause emits nothing).

**Step 2:** Subscribe `setupStateBindings` to `PlaybackStateManager.statePublisher` and forward through `objectWillChange` (everything is already `@MainActor`). Remove all `.receive(on: RunLoop.main)` hops (facade :877/:882/:887 and StateCoordinator :139) — `RunLoop.main` stalls during scroll tracking; the hop buys nothing on a main-actor type. Deduplicate redundant `showMiniPlayer` writes.

**Step 3:** Focused tests green; manual sim check: tap a track during scroll deceleration — Now Playing opens on the tapped track.

**Proposed commit:** `fix(playback): stable track identity, transactional queue commits, reliable state invalidation`

---

## Phase 5 — Session, remote commands, and routes (High; both audits #7–#10 / docs 7–9)

### Task 5.1: Idempotent remote-command registration + shutdown unregistration

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Services/AudioSessionManager.swift` (`enableRemoteCommands` :232 — call `disableRemoteCommands()` first)
- Modify: `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift` (`performShutdown` :499 — disable/remove owned commands **before** `sessionManager.delegate = nil`)
- Test: `Fonic HiFiTests/AudioSessionServiceTests.swift`, `Fonic HiFiTests/AudioSessionInterruptionTests.swift`

**Step 1:** Failing tests: initialize → shutdown → initialize, fire each command, assert exactly one delegate call; after shutdown assert zero.

### Task 5.2: Register `togglePlayPauseCommand` and `stopCommand`

**Files:**
- Modify: `AudioSessionManager.swift` (add targets; `RemoteCommand.togglePlayPause`/`.stop` cases already exist), `Fonic HiFi/Core/Audio/Coordinators/StateCoordinator.swift` (route `.togglePlayPause` to pause/resume from current state; `.stop` handling already exists)
- Test: `Fonic HiFiTests/StateCoordinatorTests.swift`

Headset center-button / AirPods stem / most BT car controls send `togglePlayPause`; today they are dead. **Hardware flag:** device verification in Phase 10.

### Task 5.3: Release audio focus on genuine stop and end-of-queue

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift` (explicit stop :624), the queue-exhaustion path in `StateCoordinator`/`QueueCoordinator`
- Test: session-spy coverage in `Fonic HiFiTests/AudioEngineFacadeOrchestratorTests.swift`

Deactivate with `.notifyOthersOnDeactivation` after user stop and queue exhaustion **only**. Per `Core/Audio/AGENTS.md`: never between queue tracks, never on pause or interruption. Failing tests first: stop → deactivated once; track-to-track advance → not deactivated; pause → not deactivated.

### Task 5.4: Route-change sample-rate renegotiation and recovery re-scheduling

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Engine/PlaybackController.swift` (retain active source rate; expose `renegotiatePreferredSampleRate()`), `StateCoordinator.swift` (:230–234 — handle `.newDeviceAvailable` / `.routeConfigurationChange`), `AVAudioEngineAdapter.swift` (:743–760 — recovery must capture the current frame, re-schedule the remaining segment, restore transport, and surface a health event on failure)
- Test: `Fonic HiFiTests/StateCoordinatorTests.swift` (handler wiring), `Fonic HiFiTests/AVAudioEngineAdapterTests.swift` (recovery re-schedules and keeps `currentTime`)

**Hardware flag:** USB DAC / AirPlay / unplug behavior is Phase 10; simulator proves wiring only.

**Proposed commit:** `fix(session): idempotent remote commands, focus release on stop, route renegotiation`

---

## Phase 6 — Engine parity and honest metrics (docs Highs 1–6)

### Task 6.1: ReplayGain on the AVAudioEngine path

**Files:** `AVAudioEngineAdapter.swift` (implement `applyReplayGain(_:)` → `submixNode.outputVolume = pow(10, gainDB/20)`; include gain in `hasAudioProcessing()`), `AudioEngineManager.swift` (:109 eligibility context stays honest). Tests: `AVAudioEngineAdapterTests`, `BitPerfectValidatorTests` (gain active ⇒ not bit-perfect-eligible).

### Task 6.2: Real two-node crossfade ramp on the AVAudioEngine path *(approved decision)*

**Files:** `AVAudioEngineAdapter.swift` (implement `crossfade(to:duration:)` using the existing dual player chains and submixes), test via `AVAudioEngineGaplessWaveformTests` harness.

Design constraints: generation-scoped and cancellable (a superseding request or stop/pause/seek cancels the ramp and lands on a coherent single-track state); bounded step ramp on the two submix volumes (e.g., 50 ms steps, equal-power curve); respects the pause-disarm semantics from Phase 1; ReplayGain target volume is the ramp ceiling, not 1.0. Waveform tests: overlap region contains both signals, total duration correct, cancellation mid-ramp leaves exactly one playing node at full target volume.

### Task 6.3: Implement `invalidatePreparedTransition()` in the AudioKit adapter

**Files:** `Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift` (stop inactive player, clear `pendingNextURL`/`inactiveFile`, cancel `crossfadeTask` in cleanup). Then remove the do-nothing protocol defaults in `Fonic HiFi/Core/Audio/Interfaces/AudioEngineService.swift` (:229–240) so the compiler forces both adapters to decide (`applyReplayGain`, `crossfade`, `invalidatePreparedTransition`). Tests: `AudioKitEngineAdapterTests`.

### Task 6.4: EQ-aware engine selection *(approved decision)*

**Files:** `Fonic HiFi/Core/Audio/Factory/AudioEngineType.swift` (:53), `Fonic HiFi/Core/Audio/Factory/AudioEngineFactory.swift`, `Fonic HiFi/Core/Audio/Engine/AudioEngineManager.swift` selection logic, settings read for EQ-enabled. Default config lives in `Fonic HiFi/Core/Audio/Interfaces/AudioEngineConfiguration.swift` (:55). Tests: `AudioEngineFactoryTests`, `AudioEngineTypeTests`, `AudioEngineManagerTests`.

Rule: when the user has the equalizer enabled, selection must require `supportsEQ` (forces AVAudioEngine); preserve the existing preference/performance/format precedence otherwise (`Core/Audio/AGENTS.md`: do not replace selection with a fixed format split). Toggling EQ mid-session triggers the established engine-switch path, not an in-place mutation.

### Task 6.5: Gate health predicates on metrics availability

**Files:** `Fonic HiFi/Core/Audio/Interfaces/AudioMetrics.swift` (:278–285, :341–346 — `isHealthy`/`hasCriticalIssues` must respect `engineMetricsAvailability`), `AVAudioEngineAdapter.swift` (:582–600 — report unavailable rather than fabricated zeros). Tests: `AudioMetricsTests`, `AudioMonitorTests`. Failing test first: unavailable metrics ⇒ neither healthy nor critical claims.

**Proposed commit:** `fix(audio): engine capability parity — replay gain, real crossfade, EQ-aware selection, honest metrics`

---

## Phase 7 — Import pipeline (docs Highs 10–14 + Mediums; Codex #11/#12)

### Task 7.1: Decodability gate before persistence

**Files:** `Fonic HiFi/Data/Services/MetadataExtractionService.swift` (:179–188 — replace `try?` swallowing with logged failure results), `Fonic HiFi/Core/Audio/Services/AudioFormatDetectionManager.swift` (:46 — reject zero-byte), `Fonic HiFi/Data/Actors/FileImportProcessor.swift` (enforce before SwiftData commit). Policy already expressed by `AudioFileInfo.isValid` — wire it in. Tests: `ImportValidationScenarioTests`, `MetadataExtractionServiceTests`, `AudioFileInfoTests` with zero-byte, truncated-header, corrupt-payload, nonfinite-duration, and valid-short fixtures (real audio fixtures per `Data/AGENTS.md` — never renamed text files). Also clamp `formattedDuration` (`LibraryEntities.swift:81`) against nonfinite input.

### Task 7.2: Staged atomic copy with bounded retry and relaunch cleanup

**Files:** `FileImportProcessor.swift` (`copyFile` :781 — copy to `Music/.staging-<uuid>`, validate, atomically rename; delete staging on every failure path; bound the :789–806 retry loop with a terminal surfaced failure; sweep orphaned staging files on startup). Tests: `FileImportProcessorTests` — injected partial copy, cancellation, ENOSPC, relaunch sweep.

### Task 7.3: Replace the `enqueue` spin loop with real backpressure

**Files:** `Fonic HiFi/Data/Services/LibraryImportService.swift` (:188–208). Use the existing `Fonic HiFi/Core/Audio/Services/AsyncSemaphore.swift` utility as a counting gate: capacity `concurrency * 4`, acquired before yield, released as results are consumed, drained on cancellation. Tests: `LibraryImportServiceTests` — discovery faster than processing never busy-waits (assert no `.dropped` re-offer loop), cancellation drains cleanly.

### Task 7.4: Single-pass metadata/artwork loading

**Files:** `MetadataExtractionService.swift` (:67–78, :229–231, :294–306, :375–397 — filter items by key **before** `loadValue`; load `commonMetadata` once and pass it to `parseMetadata`/`extractReplayGain`/`extractArtwork`). Tests: `MetadataExtractionServiceTests` with a spy asset asserting load counts.

### Task 7.5: Import cancellation and idempotent triggers

**Files:** `LibraryImportService.swift` (:112–122 — keep `isImporting` true until `await task.value` completes), `LibraryView.swift` (:360 — disable the import affordance while importing; already policy-gated by Task 2.3). Tests: `LibraryImportServiceTests` — cancel-then-retrigger cannot overlap pipelines.

### Task 7.6: File coordination and iCloud materialization

**Files:** `FileImportProcessor.swift` (:562–568 discovery, :791 copy). Check `ubiquitousItemDownloadingStatus`, call `startDownloadingUbiquitousItem` with a bounded wait, copy through `NSFileCoordinator`, and emit a `.failed` per-file result instead of silently skipping. Tests: unit-level for the failure surfacing; **hardware flag** for real File Provider behavior (Phase 10).

**Proposed commit:** `fix(import): decodability gate, atomic staged copies, backpressure, coordinated reads`

---

## Phase 8 — UI wiring, widget, and approved plist scope (docs #16, Mediums; Codex UI notes)

### Task 8.1: Facade queue APIs; views stop bypassing the boundary

**Files:** `QueueCoordinator.swift` + `AudioEngineFacade.swift` (add pass-through `replaceQueue`/`moveItem`/`removeItem`/`jumpToTrack`; wire the existing dead `shuffleMode`/`repeatMode` accessors), rewire `Fonic HiFi/Presentation/Views/Home/HomeView.swift` (:508, :547–550) and `Fonic HiFi/Presentation/Views/Queue/QueueView.swift` (:65, :70). Tests: `QueueCoordinatorTests`, `AudioQueueManagerTests`. `Core/Audio/AGENTS.md` explicitly forbids the current direct mutation.

### Task 8.2: Queue and album UX correctness

**Files:** `QueueView.swift` (:38 — row "playing" indicator must reflect paused state; rows tappable via the new `jumpToTrack`; add empty state), `Fonic HiFi/Presentation/Views/Home/Sections/AlbumSheetView.swift` (:97–119 — "Play" replaces the queue with the album from the tapped index; "Shuffle" sets shuffle mode through the facade). Tests: presentation tests + `QueueShuffleModeTests`.

### Task 8.3: Now Playing artwork and palette performance

**Files:** `PlaybackController.swift` (:439–458 — cache `MPMediaItemArtwork` per track id, decode off-main, honor the requested size in the handler; publish elapsed time at state transitions, fix the `Float`/`Double` rate inconsistency), `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift` (:120–122 — gradient task gets `id: track.id`), `MorphableArtwork` (no full-size decode inside `body`), palette re-extraction on track change with latest-wins cancellation. Tests: `ArtworkServiceTests`, `DominantColorServiceTests`, `NowPlayingAccessibilityTests`.

### Task 8.4: Widget — live progress, staleness, and deep link *(plist scope approved)*

**Files:**
- Modify: `Fonic HiFi/Shared/AppGroupManager.swift` (:78–88 — stop skipping time-only writes; there is no Live Activity), widget timeline views (derive elapsed via `Text(timerInterval:)`/timestamp+rate), both `WidgetPlaybackState` copies (consume `isStale` — after force-quit show a stale/paused presentation). Keep app/widget payloads wire-compatible; add the golden-fixture round-trip test the docs audit suggests.
- Modify: app `Info.plist` — add `CFBundleURLTypes` for `fonichifi`; add `.onOpenURL` routing in `FonicHiFiApp.swift`/`ContentView.swift` to open Now Playing for `fonichifi://nowplaying`.
- Tests: `WidgetPlaybackStateTests`, `WidgetTrackInfoTests`, `AppGroupManagerTests`; manual sim QA for the deep link; widget timeline behavior is Phase 10 device QA.

### Task 8.5: Plist/entitlement cleanup + document types *(approved)*

**Files:** app `Info.plist` / `.entitlements` — remove `aps-environment` (zero push code) and `NSSupportsLiveActivities` (zero ActivityKit); add `UTImportedTypeDeclarations` for FLAC (`org.xiph.flac`), APE, DSD/DSF so pickers stop producing dynamic UTIs. Do **not** add `UIFileSharingEnabled`/`LSSupportsOpeningDocumentsInPlace` (not approved). Validation: `plutil -lint`, `make build-release`, fresh install smoke via `make run`.

**Proposed commit:** `fix(ui): facade-owned queue mutations, live widget progress, deep link, honest artwork pipeline`

---

## Phase 9 — Dead code, diagnostics deletion, and debris (docs Lows; approved decision 1)

### Task 9.1: Delete the dead diagnostics pipeline

**Files:** delete `Fonic HiFi/Core/Audio/PlaybackDiagnostics/` subtree, `AudioMonitorDiagnosticsBuilder`, the dead majority of `AudioMonitorInsights`/`AudioMonitorReporter`, `AudioEngineFacade.getCurrentDiagnostics()` (:767, zero call sites), and the 16 dead `AudioMonitor` methods; trim the four monitoring protocols to their live members. Delete their test files (`PlaybackDiagnosticsTests`, `AudioMonitoringReportBuilderTests`, `AudioMonitorInsightsTests`, and dead portions of `AudioMonitorTests`/`AudioMonitoringCollectorsTests`). **Keep** `DiagnosticsStatus` and `SignalPathSnapshot` and their tests — they are live. Verify with `rg` that every deleted symbol had no production reference; `make test-unit` + `make build` after.

### Task 9.2: Targeted small fixes

- `Fonic HiFiTests/SignalPathBadgePresentationTests.swift` (:4) — add `@MainActor` (clears 3 warnings).
- `Fonic HiFi/Presentation/Views/Components/SystemVolumeSlider.swift` (:18) — remove deprecated `showsRouteButton`; use `AVRoutePickerView` alongside if route UI is still wanted.
- `ProgressTimerManager.swift` (:12–31) — explicit teardown owner (stop on facade shutdown; no orphaned timer task retaining the engine).
- `AVAudioEngineAdapter`/`AudioKitEngineAdapter` `stop()` — stop the underlying engine (battery); remove the never-removed main-mixer tap on teardown.
- Remove the 20+ numbered `#if DEBUG` step-trace logs in `load()`/`play()` **after** Phase 1 tests exist.
- Remove confirmed-dead code: `AudioMonitoringService` typealias, `DataManager.debugModelContainer()`, `ImportTransaction`, `ImportMetrics` (+ its test file), dead `AudioError` aliases, `themePalette(_:)`, `AudioSessionManager.shared`, write-only fields listed in the docs audit Low section.
- `AudioFormat.from(avAudioFormat:)` heuristic (`AudioKitEngineAdapter.swift:584–595`) — derive from the source file/UTI, not sample-rate guessing; fix the file-format vs processing-format duration division (`AVAudioEngineAdapter.swift:215–220`).
- Localize import status strings; replace the `"Import completed:"` prefix coupling (`ImportPresentationState.swift:99–104`) with a semantic flag.
- Housekeeping: delete stray `.DS_Store` files inside target roots, remove `Fonic.icon/Assets/Untitled design-3 2.svg`, add `venv/` and `audits-1/` to `.gitignore`, fix the `Log.logger(.presentation)` misuse in a Core service, UTF-16 `NSRange` fix, remove unreachable `#available(iOS 27.0, *)` else-branches in `AudioSessionManager`.
- `AudioQueueManager` observable-cache mutation during body evaluation → `@ObservationIgnored`; background queue persistence gets a background-task assertion.

**Proposed commit:** `chore(audio): delete dead diagnostics pipeline and audit debris`

---

## Phase 10 — Full validation and hardware QA

### Task 10.1: Full local validation

1. `make lint` — zero violations.
2. `make test` — full plan green; extract results, then delete the `.xcresult`.
3. `make test-ui` — 29/29.
4. `make build-release` and `make analyze`.
5. `make coverage-check`.
6. `git diff --check`; review the complete diff for scope, secrets, absolute paths.
7. Cleanup: remove created DerivedData/result bundles under `build/`; `xcrun simctl --set testing delete all`.

### Task 10.2: Hardware QA checklist (required before any "fixed" claim on these items)

On a physical device: audible single-play across pause/resume and seek-pause-resume; silence past a prepared gapless boundary while paused; one ordered transition after resume; settings changes mid-song keep audio; interruption (phone call) end behavior; headset/AirPods `togglePlayPause` and stop; Control Center/lock screen after shutdown-reinit (single command execution); audio-focus release after stop/end-of-queue (other app resumes); USB DAC / AirPlay sample-rate renegotiation mid-track and route-loss recovery; iCloud placeholder import with a real File Provider; widget progress/staleness after force-quit; widget deep link; large-library import (10k) for backpressure CPU (optionally `xcprof record --preset cpu`). Anything not exercised stays reported as `UNVERIFIED`.

---

## Dependency notes

- Phase 1 before 6.2 (crossfade builds on pause/teardown semantics) and before 9.2 (debug-log removal).
- Task 4.1/4.2 before 4.3 (transactional commit passes snapshots around).
- Task 8.1 before 8.2 (queue UX uses the new facade APIs).
- Task 2.4 (schema freeze) before any task that would touch model *schema* — none in this plan should; adding the `Track.init` id parameter (4.1) is not a schema change.
- Phases 1↔2 independent; 3 anytime; 5–9 after 1/2/4 to avoid rebasing churn in the same files.
