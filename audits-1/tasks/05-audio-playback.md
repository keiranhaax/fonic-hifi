# Audio Engine & Playback — AUDIT-020 … AUDIT-035

## AUDIT-020 — Normalize engine-preference handling (AVAudioEngine choice ignored)

- Status: [TODO]
- Priority: P1
- Audit sources: Model B (AUD-ENG-001)
- Audit finding IDs: AUD-ENG-001
- Category: Audio
- Severity: Medium
- Difficulty: Easy
- Risk: Low
- Scope: Localized
- Estimated effort: XS
- Implementation group: —
- Depends on: —
- Blocks: — (precedes AUDIT-021, same surface)
- Related tasks: AUDIT-021
- Affected features: engine selection
- Affected files or symbols: `AudioEngineFactory.swift:95-103` (switch handles `"AudioKit"`, `"AudioKitEngine"`, falls through for `"AVAudioEngine"`), `AudioSettingsView.swift:12,27` (stores exactly `"AVAudioEngine"`)
- Validation status: Confirmed (revalidated 2026-07-15)
- Validation evidence: cited lines

### Problem
Choosing AVAudioEngine in Settings is ignored: the stored string is not matched by the factory, so selection silently falls through to default logic.

### Likely Root Cause
String-literal mismatch between the settings surface and the factory.

### Recommended Implementation
Replace raw strings with one typed enum shared by settings and factory (single source of truth); map legacy stored values; unsupported/unknown values fall back *visibly*.

### Implementation Boundaries
Do not change engine capability logic or format routing — only preference decoding. Preserve existing preference keys (migrate values, don't rename keys).

### Acceptance Criteria
- [ ] Every stored choice selects the requested capable engine (test per value incl. legacy strings)
- [ ] Unknown values fall back with a visible/logged typed result

### Suggested Verification
`AudioEngineFactoryTests` extension; focused run.

### Risks and Regression Areas
Persisted values from existing installs — include migration mapping test.

### Notes
Ledger M-15 (first slice).

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-021 — Wire or remove the remaining inert audio settings

- Status: [TODO]
- Priority: P1
- Audit sources: Model B (AUD-CONFIG-001, UIUX-008), Model A (A-B05), WP3-018
- Audit finding IDs: CAN-024 (residual)
- Category: Audio / UX honesty
- Severity: High (source) / Medium (WP3)
- Difficulty: Moderate
- Risk: Medium
- Scope: Multi-file
- Estimated effort: M
- Implementation group: GROUP-07 (UI half depends on AUDIT-036)
- Depends on: AUDIT-020; AUDIT-036 for observation of applied state
- Blocks: —
- Related tasks: AUDIT-008 (ReplayGain data), AUDIT-028 (bit-perfect honesty)
- Affected features: Audio Settings
- Affected files or symbols: `AudioSettingsView.swift:13-15,38,54,72` (bit-perfect, buffer-size, sample-rate remain bare `@AppStorage` with no runtime application); gapless/crossfade/replay-gain already call facade updates (`:89-124`)
- Validation status: Partially fixed — in-flight work wired gapless/crossfade/replay-gain; bit-perfect/buffer/sample-rate remain inert (2026-07-15)
- Validation evidence: cited lines

### Problem
Several visible audio settings persist values that never configure the engine — users believe they changed playback behavior when nothing happened.

### Likely Root Cause
Settings UI landed ahead of engine plumbing.

### Recommended Implementation
For each remaining control: either plumb it through `AudioPlaybackSettingsStore` → facade → engine (typed applied-value source, like the in-flight gapless work) or remove the control until the capability exists. Bit-perfect toggle coordination belongs to AUDIT-028.

### Implementation Boundaries
Preserve the uncommitted `AudioPlaybackSettingsStore` work. No engine-graph redesign here.

### Acceptance Criteria
- [ ] Every visible setting demonstrably changes runtime state or is removed
- [ ] Settings applied on engine creation and engine switch (test)
- [ ] No regression in the in-flight settings tests

### Suggested Verification
`AudioPlaybackSettingsStoreTests` + facade orchestrator tests; manual settings sweep with a real track.

### Risks and Regression Areas
Engine switching path; buffer/sample-rate misapplication can break playback — device check required.

### Notes
Ledger M-15/M-19-adjacent.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-022 — Repair the format contract: inspect codecs, stop advertising unplayable formats

- Status: [TODO]
- Priority: P1
- Audit sources: Model B (AUD-FORMAT-001, AUD-FORMAT-002), Model A (A-B04)
- Audit finding IDs: AUD-FORMAT-001, AUD-FORMAT-002
- Category: Audio correctness
- Severity: Medium
- Difficulty: Moderate
- Risk: Medium
- Scope: Multi-file
- Estimated effort: M
- Implementation group: GROUP-06 (both halves ship together)
- Depends on: —
- Blocks: —
- Related tasks: AUDIT-009 (fixtures), AUDIT-028
- Affected features: import, format detection, engine routing
- Affected files or symbols: `AudioFormat.swift:102-107` (`case "m4a": return .alac`), `AudioFormatDetectionManager.swift:233-236` (loads AVAsset format descriptions but returns extension-inferred format), `AudioFormatType.swift:17-25` (advertises Ogg/Opus/WavPack/APE), `AudioEngineType.swift:49-55`, `FileManagerView.swift:426` (accepts OGG/WMA)
- Validation status: Confirmed both members (revalidated 2026-07-15)
- Validation evidence: cited lines

### Problem
Every `.m4a` is reported ALAC/lossless (AAC files get lossless badges and wrong engine eligibility), and the import/file UI advertises formats the playback stack cannot represent or play.

### Likely Root Cause
Extension-based detection retained after codec-inspection code was added; import surface lists aspirational formats.

### Recommended Implementation
Use the already-loaded format descriptions to classify M4A codec (AAC vs ALAC); align `AudioFormatType`/file-picker types with formats that have a real playable path (hide or implement the rest — FLAC native routing per ledger M-14 is a separate follow-up slice).

### Implementation Boundaries
Do not change engine selection logic beyond format facts. Real fixtures required (AAC-M4A, ALAC-M4A, FLAC, one unsupported).

### Acceptance Criteria
- [ ] AAC-M4A fixture classified AAC/lossy; ALAC-M4A classified ALAC/lossless (red before fix)
- [ ] No advertised/importable format lacks a playable path
- [ ] Existing format-detection concurrency tests stay green (preserve in-flight `FormatDetectionCoordinator` edits)

### Suggested Verification
Fixture-driven detector tests; import-to-playback smoke per format.

### Risks and Regression Areas
Bit-perfect eligibility depends on format facts (AUDIT-028); update together where they touch.

### Notes
Ledger M-14, split-ready if needed (detection first, UI surface second).

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-023 — Restore and reapply persisted EQ across engine creation and switching

- Status: [TODO]
- Priority: P1
- Audit sources: Model B (AUD-DSP-001, DCA-PART-002)
- Audit finding IDs: CAN-023
- Category: Audio / DSP
- Severity: Medium
- Difficulty: Moderate
- Risk: Medium
- Scope: Multi-file
- Estimated effort: M
- Implementation group: —
- Depends on: —
- Blocks: —
- Related tasks: AUDIT-021
- Affected features: EQ
- Affected files or symbols: `EqualizerView.swift:145` (EQ loaded only on view appear), `AudioEngineFacade.swift:75-76` (starts `.default`), no `reapplyEQConfiguration` on engine create/switch
- Validation status: Confirmed (revalidated 2026-07-15)
- Validation evidence: cited lines

### Problem
Persisted EQ takes effect only after the user opens the EQ screen; engine creation, switching, and restart play with default EQ regardless of saved settings.

### Likely Root Cause
EQ restoration was wired to the view lifecycle, not the engine lifecycle.

### Recommended Implementation
Load persisted EQ during facade initialization and reapply on every engine creation/switch; expose DSP capability failures as typed results instead of silent no-ops.

### Implementation Boundaries
No EQ algorithm/graph changes. Both engines must be covered (AudioKit + native).

### Acceptance Criteria
- [ ] Engine creation/switch/restart tests assert identical EQ state to persisted values
- [ ] Unsupported DSP returns a typed visible result, not a silent no-op

### Suggested Verification
Facade + adapter tests; audible check with a strong EQ curve on device.

### Risks and Regression Areas
Engine-switch timing; ensure reapplication doesn't glitch active playback.

### Notes
Ledger M-19. Focused tests + real-track verification required by repo rules for DSP changes.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-024 — Move sleep-timer ownership out of NowPlayingContent; fade from actual volume

- Status: [TODO]
- Priority: P2
- Audit sources: Model B (AUD-SLEEP-001, UIUX-007)
- Audit finding IDs: CAN-015
- Category: Audio / UX
- Severity: Medium
- Difficulty: Moderate
- Risk: Low
- Scope: Multi-file
- Estimated effort: M
- Implementation group: —
- Depends on: — (easier after AUDIT-036/037 but not blocked)
- Related tasks: AUDIT-037
- Affected features: sleep timer
- Affected files or symbols: `NowPlayingContent.swift:34` (`@StateObject private var sleepTimerManager`), `SleepTimerManager.swift:27,42` (fade baseline hard-coded 1.0)
- Validation status: Confirmed (revalidated 2026-07-15)
- Validation evidence: cited lines

### Problem
The sleep timer dies when Now Playing is dismissed (view-owned `@StateObject`), and fade-out starts from volume 1.0 instead of the actual current volume — jumping louder mid-fade for quiet listeners.

### Likely Root Cause
Timer manager created at view scope; fade baseline never wired to engine volume.

### Recommended Implementation
Move `SleepTimerManager` ownership to an app-level owner (facade or environment-level service); pass actual engine volume as the fade baseline and restore it after cancellation.

### Implementation Boundaries
Preserve timer UI and options. No audio-session changes.

### Acceptance Criteria
- [ ] Dismissing/reopening Now Playing preserves a running timer
- [ ] Fade starts from and restores the actual volume
- [ ] Cancel/background scenarios pass

### Suggested Verification
`SleepTimerManagerTests` (deterministic clock per AUDIT-050); manual background check.

### Notes
Ledger M-18.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-025 — Define and implement repeat-one behavior for manual Next/Previous

- Status: [TODO]
- Priority: P2
- Audit sources: Model B (AUD-QUEUE-002)
- Audit finding IDs: AUD-QUEUE-002
- Category: Playback behavior
- Severity: Medium
- Difficulty: Easy
- Risk: Low
- Scope: Localized
- Estimated effort: S
- Implementation group: —
- Depends on: micro product decision (expected: manual navigation escapes repeat-one, matching platform convention)
- Blocks: —
- Related tasks: AUDIT-037
- Affected features: queue navigation
- Affected files or symbols: `QueueCoordinator.swift:40-41,59-60`, `QueueRepeatMode.swift:81-87,101-107`
- Validation status: Confirmed (revalidated 2026-07-15) — manual next/previous uses repeat-aware methods; repeat-one returns current index
- Validation evidence: cited lines

### Problem
With repeat-one active, tapping Next/Previous replays the same track — user intent to navigate is discarded.

### Likely Root Cause
Manual navigation and natural completion share the same repeat-aware traversal.

### Recommended Implementation
Add a manual-navigation flag (or separate methods) so user-initiated next/previous advances regardless of repeat-one, while natural completion keeps repeating. Confirm the product default in the task PR description.

### Implementation Boundaries
No changes to repeat-all/shuffle semantics or persistence.

### Acceptance Criteria
- [ ] Manual next/previous advances under repeat-one (test)
- [ ] Natural completion still repeats (regression test)

### Suggested Verification
`AudioQueueManagerTests` additions.

### Notes
Ledger flagged this as needing a small product policy call; the recommended default matches Apple Music behavior.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-026 — Rebuild engine objects after media-services reset

- Status: [TODO]
- Priority: P1
- Audit sources: Model B (AUD-RESET-001)
- Audit finding IDs: AUD-RESET-001 (residual)
- Category: Audio reliability
- Severity: Medium
- Difficulty: Moderate
- Risk: Medium
- Scope: Multi-file
- Estimated effort: M
- Implementation group: —
- Depends on: — (coordinate with GROUP-05 if concurrent)
- Related tasks: AUDIT-031
- Affected features: recovery from media-services reset
- Affected files or symbols: `AudioSessionManager.swift:418-429` (reconfigures/reactivates session but never invalidates `AudioEngineManager.currentEngine`)
- Validation status: Partially fixed — session reconfiguration exists; engine-object rebuild remains missing (2026-07-15)
- Validation evidence: cited lines

### Problem
After `mediaServicesWereReset`, AVAudioEngine/AudioKit objects are invalid per Apple guidance, but only the session is reconfigured — playback resumes against dead objects.

### Likely Root Cause
Reset handler was scoped to the session manager only.

### Recommended Implementation
On reset: tear down and recreate the current engine via the factory, restore EQ/settings (AUDIT-021/023 hooks), rebuild remote commands and Now Playing, and reconcile playback state coherently (paused with position preserved).

### Implementation Boundaries
Use existing factory/facade paths; no new engine types.

### Acceptance Criteria
- [ ] Injected reset rebuilds engine, commands, and Now Playing (test with reset notification)
- [ ] State after reset is coherent (paused, correct track/position)

### Suggested Verification
Focused reset-injection test; device check by triggering media services reset (developer setting) — part of AUDIT-055 matrix.

### Notes
Ledger X-05 slice.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-027 — Diagnostics honesty: report unavailable as unavailable, bound sample buffers

- Status: [TODO]
- Priority: P2
- Audit sources: Model B (AUD-DIAG-001, DCA-PART-005, CP-012), WP4-R07
- Audit finding IDs: CAN-016, CP-012
- Category: Diagnostics
- Severity: Medium
- Difficulty: Moderate
- Risk: Low
- Scope: Multi-file
- Estimated effort: M
- Implementation group: GROUP-11
- Depends on: —
- Related tasks: AUDIT-028
- Affected features: audio diagnostics UI
- Affected files or symbols: `AudioKitEngineAdapter.swift:240-253` (hard-coded zero metrics, empty `collectMetrics()`), `AudioMonitorEngineHooks.swift:69-83` (polls the empty collector), diagnostics history buffers (unbounded, CP-012), `AVAudioEngineAdapter` direct Mach queries (WP4-R07)
- Validation status: Confirmed (revalidated 2026-07-15)
- Validation evidence: cited lines

### Problem
Diagnostics show synthetic zeros as real measurements for the AudioKit engine, retain unbounded sample history, and query Mach APIs directly from the adapter.

### Likely Root Cause
Diagnostics scaffolding landed before real collection; per-engine capability differences never modeled.

### Recommended Implementation
Represent unavailable metrics as an explicit unavailable state (never zeros); bound history buffers; inject a narrow `ProcessMetricsProviding` boundary (WP4-R07) and remove direct Mach queries from the adapter; only implement measurements with real evidence.

### Implementation Boundaries
No new measurement claims. UI may show "not available for this engine".

### Acceptance Criteria
- [ ] No synthetic zero is presented as data (test per engine)
- [ ] Buffers bounded (test)
- [ ] Metrics provider injectable and mocked in tests

### Suggested Verification
Adapter/diagnostics tests; device trace to validate sampling overhead (AUDIT-054 lane).

### Notes
Ledger H-14.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-028 — Rename bit-perfect status to eligibility; key the cache; gate claims on measurement

- Status: [TODO]
- Priority: P1
- Audit sources: Model B (AUD-BIT-001, AUD-BIT-002), Model A (A-B03)
- Audit finding IDs: AUD-BIT-001, AUD-BIT-002
- Category: Audio honesty
- Severity: Medium
- Difficulty: Moderate
- Risk: Low (code); High (claim integrity)
- Scope: Multi-file
- Estimated effort: M
- Implementation group: GROUP-11
- Depends on: —
- Related tasks: AUDIT-022 (format facts), AUDIT-055 (physical evidence)
- Affected features: bit-perfect indicator, Audio Settings
- Affected files or symbols: `BitPerfectValidator.swift:20-22,45-53` (single global cached result, not keyed by track/format/route), `AudioSettingsView.swift:38-42` (claims "ensures no digital processing"), `AudioEngineFacade.swift:582-604` (diagnostics based on validator eligibility)
- Validation status: Confirmed both members (revalidated 2026-07-15)
- Validation evidence: cited lines

### Problem
A single cached validator result is reused across tracks and routes, and the UI presents eligibility as a guarantee — violating the repo's rule that bit-perfect is a measured claim, not app state.

### Likely Root Cause
Heuristic validator built as a global; UI copy overstates.

### Recommended Implementation
Key/invalidate cached eligibility on every input (source format, engine, route, volume, DSP state); rename user-facing status to "bit-perfect eligible"; keep the actual "bit-perfect" wording gated behind measured evidence (AUDIT-055 digital-capture lane).

### Implementation Boundaries
No claim-strengthening. Copy changes must survive localization work (AUDIT-043).

### Acceptance Criteria
- [ ] Cache invalidates on each eligibility input change (tests)
- [ ] UI copy states eligibility, not guarantee
- [ ] Documented mapping of what evidence would upgrade the claim

### Suggested Verification
Validator unit tests; UI copy review; unity-graph bypass tests where feasible.

### Notes
Ledger X-07 (code-side slice; physical capture stays in AUDIT-055).

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-029 — Replace AudioKit 100 ms completion polling with an exactly-once completion callback

- Status: [TODO]
- Priority: P2
- Audit sources: Model B (CP-007), Model A (A-B10)
- Audit finding IDs: CP-007
- Category: Performance / correctness
- Severity: Medium
- Difficulty: Moderate
- Risk: Medium
- Scope: Localized
- Estimated effort: M
- Implementation group: —
- Depends on: — (coordinate with GROUP-05; completion semantics feed gapless)
- Related tasks: AUDIT-034
- Affected features: track completion, energy
- Affected files or symbols: `AudioKitEngineAdapter.swift:309-315` (0.1 s timer spawning a MainActor Task per tick), `PlaybackController.swift:276-284` (separate 0.5 s progress polling)
- Validation status: Confirmed (revalidated 2026-07-15)
- Validation evidence: cited lines

### Problem
AudioKit completion detection spawns a MainActor task every 100 ms for the whole duration of playback, duplicating centralized progress polling and wasting energy.

### Likely Root Cause
Polling chosen over AudioKit/AVAudioPlayerNode completion callbacks.

### Recommended Implementation
Use the player's completion callback (e.g. `AudioPlayer.completionHandler` / scheduling completion) for an exactly-once completion signal; keep UI progress on the existing centralized 0.5 s schedule.

### Implementation Boundaries
Completion semantics must stay identical for: natural finish, seek-near-end, stop, cancel, transition. No engine-graph changes.

### Acceptance Criteria
- [ ] Exactly one completion event per scenario above (tests)
- [ ] No 100 ms completion poll remains
- [ ] Gapless/crossfade behavior unchanged (regression suite)

### Suggested Verification
Completion-scenario tests with generated tones; energy comparison optional (AUDIT-054).

### Notes
Ledger M-16.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-030 — Serialize play requests with latest-request-wins cancellation

- Status: [TODO]
- Priority: P0
- Audit sources: Model B (AUD-ENG-002), WP3-004
- Audit finding IDs: AUD-ENG-002
- Category: Audio state machine
- Severity: High (WP3 retained)
- Difficulty: Hard
- Risk: High
- Scope: Multi-file
- Estimated effort: L
- Implementation group: GROUP-05
- Depends on: —
- Blocks: AUDIT-034
- Related tasks: AUDIT-031, AUDIT-033
- Affected features: all playback initiation
- Affected files or symbols: `AudioEngineFacade.swift:414-418` (awaits playback with no generation guard), `PlaybackController.swift:75-102` (multiple suspensions before committing queue/UI/loading state)
- Validation status: Confirmed (revalidated 2026-07-15); note in-flight facade work serialized *initialization* but not play requests
- Validation evidence: cited lines

### Problem
Rapid successive play requests interleave: a slow earlier request can commit stale engine and UI state after a newer request already won — wrong track playing, wrong Now Playing metadata.

### Likely Root Cause
Each play request runs independently across multiple suspension points with no request identity.

### Recommended Implementation
Introduce a per-request generation token owned by the facade/controller: new requests cancel in-flight ones; every state commit validates its generation; cancellation must not surface as a user-facing error (respect the in-flight `reportPlaybackControlError` work).

### Implementation Boundaries
Preserve the uncommitted facade changes. No session-ownership redesign here (AUDIT-031).

### Acceptance Criteria
- [ ] Delayed request A then fast request B always ends with B playing (race test)
- [ ] Stale A cannot clear or commit any state
- [ ] Cancellation produces no generic error UI

### Suggested Verification
Orchestrator race tests (extend `AudioEngineFacadeOrchestratorTests`); manual rapid-tap check.

### Risks and Regression Areas
Interruption/route handlers also mutate state — coordinate with AUDIT-031/032 landing order.

### Notes
Ledger X-03.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-031 — Establish one audio-session owner; separate track transition from playback teardown

- Status: [TODO]
- Priority: P0
- Audit sources: Model B (AUD-SESSION-001), Model A (A-B02), WP3-005
- Audit finding IDs: AUD-SESSION-001
- Category: Audio state machine
- Severity: High (WP3 retained)
- Difficulty: Hard
- Risk: High
- Scope: Cross-feature
- Estimated effort: L
- Implementation group: GROUP-05
- Depends on: —
- Blocks: AUDIT-032, AUDIT-034
- Related tasks: AUDIT-030, AUDIT-026
- Affected features: session lifecycle, transitions, background playback
- Affected files or symbols: `PlaybackController.swift:77-78` (central activation), `AVAudioEngineAdapter.swift:173-175` (`load()` begins with `await stop()`), `:297-300` (`stop()` deactivates via its own session manager)
- Validation status: Confirmed (revalidated 2026-07-15)
- Validation evidence: cited lines — native load deactivates a session another owner activated

### Problem
Session ownership is split: loading a track on the native engine deactivates the session mid-transition, risking audible gaps, dropped background audio, and incoherent Now Playing.

### Likely Root Cause
Adapter-level stop conflates "unload this track" with "end playback session".

### Recommended Implementation
One session owner (session manager driven by the facade/controller); adapters never activate/deactivate; introduce distinct teardown levels — track unload (no session change) vs. playback shutdown (deactivate once). AGENTS.md invariant: no deactivation between queued tracks.

### Implementation Boundaries
No behavior change to activation options/category. Adapters keep their engine duties only.

### Acceptance Criteria
- [ ] Session spy: activation before playback, zero deactivations across queued-track transitions, one deactivation at true shutdown
- [ ] Background playback survives track transitions (device check → AUDIT-055)

### Suggested Verification
Session-spy unit tests; consecutive-track device run.

### Risks and Regression Areas
Every transition path (manual, completion, crossfade, engine switch) — full playback suite required.

### Notes
Ledger X-01. Foundational for AUDIT-032/034.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-032 — Preserve interruption intent and pause on route loss

- Status: [TODO]
- Priority: P0
- Audit sources: Model B (AUD-SESSION-002), Model A (A-B01), WP3-006
- Audit finding IDs: AUD-SESSION-002
- Category: Audio reliability / privacy
- Severity: High (WP3 retained)
- Difficulty: Hard
- Risk: Medium
- Scope: Multi-file
- Estimated effort: M
- Implementation group: GROUP-05
- Depends on: AUDIT-031
- Blocks: —
- Related tasks: AUDIT-030
- Affected features: interruptions, route changes
- Affected files or symbols: `StateCoordinator.swift:173-185` (interruption end resumes solely from system flag; prior intent not recorded), `:200-204` (route loss only logs — no pause)
- Validation status: Confirmed (revalidated 2026-07-15; the uncommitted StateCoordinator changes did not address these paths)
- Validation evidence: cited lines

### Problem
Interruption recovery ignores whether the user was actually playing, and unplugging headphones (route loss) keeps playing on the speaker — an audible-privacy failure Apple explicitly says to pause on.

### Likely Root Cause
Interruption handler trusts `.shouldResume` alone; route-change handler was never finished.

### Recommended Implementation
Record play intent at interruption begin; resume only if (intent && shouldResume); on `.oldDeviceUnavailable` pause when playing and keep UI/Now Playing coherent; use OptionSet containment for interruption options.

### Implementation Boundaries
Depends on AUDIT-031's single owner. No new session categories.

### Acceptance Criteria
- [ ] Logic tests: playing/paused × interruption begin/end matrix
- [ ] Route-loss pauses only when playing; state coherent; no auto-continue on another route
- [ ] Physical headphone/Bluetooth pull test (→ AUDIT-055)

### Suggested Verification
StateCoordinator tests with injected notifications; device pull test.

### Notes
Ledger X-02.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-033 — Reconcile state when an AudioKit crossfade is cancelled

- Status: [TODO]
- Priority: P1
- Audit sources: Model B (AUD-TRANSITION-002)
- Audit finding IDs: AUD-TRANSITION-002
- Category: Audio state machine
- Severity: Medium
- Difficulty: Hard
- Risk: Medium
- Scope: Localized
- Estimated effort: M
- Implementation group: GROUP-05
- Depends on: —
- Blocks: AUDIT-034
- Related tasks: AUDIT-030
- Affected features: crossfade
- Affected files or symbols: `AudioKitEngineAdapter.swift:378-383` (`guard !Task.isCancelled else { return }` mid-fade with both players started and no swap), `:358-367`
- Validation status: Confirmed (revalidated 2026-07-15)
- Validation evidence: cited lines

### Problem
Cancelling a crossfade mid-fade exits without reconciliation: two players are live, volumes are half-faded, and current-file state doesn't match what's audible.

### Likely Root Cause
Cancellation checked but not handled — early return skips `finishCrossfade`.

### Recommended Implementation
On cancellation, deterministically reconcile to exactly one player/file/state (choose the transition target or revert to source per interaction), restore volumes, and fire completion exactly once.

### Implementation Boundaries
AudioKit adapter only; no facade API change.

### Acceptance Criteria
- [ ] Cancel at start/mid/end plus pause/seek/next each leave one active player and one coherent current track (tests)
- [ ] Completion fires exactly once per transition

### Suggested Verification
Adapter tests with generated tones; audible spot check.

### Notes
Ledger X-04.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-034 — Build a real prepared-next gapless transition state machine

- Status: [TODO]
- Priority: P1
- Audit sources: Model B (AUD-TRANSITION-001, TRV-007), Model A (A-B02)
- Audit finding IDs: AUD-TRANSITION-001, TRV-007
- Category: Audio playback quality
- Severity: Medium (functional gap; product-defining feature)
- Difficulty: Complex
- Risk: High
- Scope: Cross-feature
- Estimated effort: XL (decompose at implementation: native scheduling, AudioKit path, verification lane)
- Implementation group: GROUP-05
- Depends on: AUDIT-030, AUDIT-031, AUDIT-033
- Blocks: —
- Related tasks: AUDIT-029, AUDIT-055
- Affected features: gapless playback, crossfade
- Affected files or symbols: `AVAudioEngineAdapter.swift:374-396` (prepares inactive player but never starts/swaps), `AudioKitEngineAdapter.swift:229-231` (zero-duration crossfade = immediate stop/swap, not sample-accurate)
- Validation status: Confirmed (revalidated 2026-07-15)
- Validation evidence: cited lines

### Problem
"Gapless" currently only pre-loads the next file; no transition actually starts it sample-accurately, and the zero-duration crossfade fallback is a stop/start — audible gaps on a hi-fi player.

### Likely Root Cause
Prepared-next scaffolding landed without the scheduling half; crossfade fallback was mislabeled gapless.

### Recommended Implementation
Design a prepared-next state machine: schedule the next file on the inactive native player at the exact boundary frame (`scheduleFile` at completion sample), atomically swap active player, keep session active throughout (AUDIT-031); AudioKit path per its scheduling capabilities; never deactivate between tracks.

### Implementation Boundaries
Requires all GROUP-05 predecessors. No bit-perfect claims from this work (AUDIT-028).

### Acceptance Criteria
- [ ] Logic scheduling tests for boundary timing
- [ ] Offline waveform analysis of rendered boundary shows no gap/overlap
- [ ] Consecutive real-track device capture across formats (→ AUDIT-055)
- [ ] No session deactivation at boundary (session spy)

### Suggested Verification
Three-stage: unit scheduling → offline render analysis → device capture.

### Risks and Regression Areas
Every transition path; seek-near-end; engine switch mid-queue. Full playback regression suite mandatory.

### Notes
Ledger X-06. Hardest audio task; keep last in GROUP-05.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-035 — Fix native seek offset accounting and A-B loop robustness (reproduce first)

- Status: [TODO]
- Priority: P1
- Audit sources: Model B (AUD-SEEK-001), Model A (A-B07)
- Audit finding IDs: AUD-SEEK-001
- Category: Audio correctness
- Severity: Medium
- Difficulty: Hard
- Risk: Medium
- Scope: Multi-file
- Estimated effort: M
- Implementation group: —
- Depends on: — (reproduce-first; safe alongside GROUP-05 but don't interleave commits)
- Related tasks: AUDIT-026, AUDIT-034
- Affected features: seek, A-B loop
- Affected files or symbols: `AVAudioEngineAdapter.swift:315-331` (segment scheduled from requested frame), `:118-128` (`currentTime` reports node-relative `sampleTime` without seek base), `PlaybackController.swift:276-288` (A-B checked every 0.5 s; `try? await engine.seek` swallows failures)
- Validation status: Confirmed static (revalidated 2026-07-15); runtime symptom reproduction still required before fixing
- Validation evidence: cited lines

### Problem
After a native seek, reported `currentTime` is wrong (node-relative), so progress UI, A-B loop windows, and completion logic drift; A-B loop checks are coarse and silently swallow seek failures.

### Likely Root Cause
No seek-base offset stored alongside the scheduled segment.

### Recommended Implementation
Reproduce with a scripted seek sequence first (record failing expectations); then store the seek base frame and report `base + nodeTime`; tighten A-B boundary checking and surface loop-seek failures as typed results.

### Implementation Boundaries
Native adapter + controller only. Repeat/completion semantics unchanged.

### Acceptance Criteria
- [ ] Reproduction test fails before and passes after
- [ ] Repeated seeks then natural completion report monotonic, correct time
- [ ] A-B loop seeks failures are visible, not `try?`-swallowed

### Suggested Verification
Deterministic seek tests with generated audio; manual A-B session on device.

### Notes
Ledger X-05 (reproduce-first mandate).

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:
