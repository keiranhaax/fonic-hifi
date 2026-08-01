# Data, Persistence & Import — AUDIT-008 … AUDIT-016

## AUDIT-008 — Persist extracted ReplayGain metadata

- Status: [DONE]
- Priority: P2
- Audit sources: Model B (DLP-008)
- Audit finding IDs: DLP-008
- Category: Data / audio quality
- Severity: Medium
- Difficulty: Easy
- Risk: Low
- Scope: Localized
- Estimated effort: XS
- Implementation group: GROUP-02
- Depends on: —
- Blocks: — (future replay-gain DSP work consumes it)
- Related tasks: AUDIT-009, AUDIT-021
- Affected features: import, replay gain
- Affected files or symbols: `MetadataExtractionService.swift:82-83,108-109` (track/album gain extraction), `TrackDataActor.swift:79-101` (`applyTrackMetadata` never assigns either gain)
- Validation status: Completed (2026-07-18)
- Validation evidence: ReplayGain tag fixtures are parsed, persisted to the existing Track fields, and survive save/re-fetch

### Problem
ReplayGain track and album gain values are extracted during import and then discarded, so the visible replay-gain playback setting cannot act on imported gain metadata.

### Likely Root Cause
`applyTrackMetadata` was never extended when extraction gained ReplayGain support.

### Recommended Implementation
Assign the extracted `replayGainTrack` and `replayGainAlbum` values to the existing Track model fields in `applyTrackMetadata`.

### Implementation Boundaries
No DSP behavior or schema change; persistence of the two existing fields only. Peak-tag extraction/modeling is separate future scope.

### Acceptance Criteria
- [x] Import of a fixture with ReplayGain tags persists both track and album gain values
- [x] Values survive save/re-fetch (focused test, red before green)

### Suggested Verification
Focused metadata-to-model round-trip test; `RunSomeTests` on the import/metadata suite.

### Risks and Regression Areas
Preserve the current optional-field semantics when tags are absent or malformed.

### Notes
Ledger E-10.

### Implementation Record
- Started: 2026-07-18
- Completed: 2026-07-18
- Commit: Not requested
- Verification result: ReplayGain tag fixture and persistence round-trip passed; focused suites 32/32 and full `Fonic HiFiTests` target 442/442 passed; focused SwiftLint passed. `make check-deps` remains UNVERIFIED because SwiftFormat is unavailable.

## AUDIT-009 — Fix track/disc tuple byte offsets and persist parsed totals

- Status: [DONE]
- Priority: P2
- Audit sources: Model B (DLP-009)
- Audit finding IDs: DLP-009
- Category: Data / metadata correctness
- Severity: Medium
- Difficulty: Easy
- Risk: Low
- Scope: Localized
- Estimated effort: S
- Implementation group: GROUP-02
- Depends on: —
- Blocks: —
- Related tasks: AUDIT-008
- Affected features: import metadata (track/disc numbering)
- Affected files or symbols: `MetadataExtractionService.swift:327-348` (`load(fromByteOffset:)` offsets), `TrackMetadata` (totals dropped), `TrackDataActor.swift:1061-1062`
- Validation status: Completed (2026-07-18)
- Validation evidence: AAC-M4A and ALAC-M4A fixtures parse `3/12` and `2/3`; totals persist through `TrackDataActor`

### Problem
Track/disc tuples in MP4-style metadata are read from wrong byte offsets and the parsed totals are dropped, so numbering can be wrong and "track N of M" is impossible.

### Likely Root Cause
Manual binary parsing with off-by-position offsets; `TrackMetadata` was never extended with total fields.

### Recommended Implementation
Correct the big-endian tuple offsets (verify against the MP4 `trkn`/`disk` atom layout with real fixtures), add totals to `TrackMetadata`, and persist them (schema coordination as in AUDIT-008).

### Implementation Boundaries
Metadata parsing and persistence only; no UI changes here.

### Acceptance Criteria
- [x] Fixture files with known track/disc tuples parse to exact expected values (test red before fix)
- [x] Totals persisted and retrievable

### Suggested Verification
Fixture-based unit tests with at least AAC-M4A and ALAC-M4A files; focused test run.

### Risks and Regression Areas
Existing imported libraries keep old values; consider whether a re-scan path is needed (out of scope — note only).

### Notes
Fixture-first (ledger routes this under M-14/H-13 fixtures). Group with AUDIT-008 — same files.

### Implementation Record
- Started: 2026-07-18
- Completed: 2026-07-18
- Commit: Not requested
- Verification result: AAC-M4A and ALAC-M4A production extraction fixtures passed; focused suites 32/32 and full `Fonic HiFiTests` target 442/442 passed; focused SwiftLint passed. `make check-deps` remains UNVERIFIED because SwiftFormat is unavailable.

## AUDIT-010 — Add ListeningSession to a new versioned schema and use the migration plan on first open

- Status: [DONE]
- Priority: P0
- Audit sources: Model B (DLP-002, DLP-003), WP3-008, WP3-009
- Audit finding IDs: DLP-002, DLP-003
- Category: Data / SwiftData schema
- Severity: High (source) / Medium (WP3 recalibrated — runtime exception unverified)
- Difficulty: Moderate
- Risk: Medium
- Scope: Multi-file
- Estimated effort: M
- Implementation group: GROUP-03
- Depends on: —
- Blocks: AUDIT-011, AUDIT-012
- Related tasks: AUDIT-008/009 (if they need schema fields, they ride this stage)
- Affected features: persistence, listening history
- Affected files or symbols: `Data/Migration/RecentSearchMigrationPlan.swift:150-157` (SchemaV2.models omits `ListeningSession`), `DataManager+Initialization.swift:128-146` (container first created *without* migration plan), `TrackDataActor.swift:787-798` (inserts ListeningSession)
- Validation status: Confirmed (revalidated 2026-07-15) — both defects still present
- Validation evidence: cited lines; `logger.info("Creating container without migration plan")` on the primary open path

### Problem
`TrackDataActor` inserts `ListeningSession` into a container whose active schema does not declare it, and the declared migration plan is only applied as a fallback after an unplanned open — violating the repo's schema/migration invariants and risking store-open failures on future schema changes.

### Likely Root Cause
`ListeningSession` was added as a model file without a new `VersionedSchema` snapshot; the container-creation code path predates the migration plan.

### Recommended Implementation
Create an immutable SchemaV3 snapshot including `ListeningSession` (and any fields required by AUDIT-008/009), add an ordered migration stage, and make the *primary* container-open path pass the migration plan (fallback-only ordering removed).

### Implementation Boundaries
Never delete or recreate the user store on failure. No CloudKit changes. Keep prior schema snapshots immutable.

### Acceptance Criteria
- [ ] Active schema declares every model the actors persist
- [ ] Primary open path uses the migration plan (no "without migration plan" open)
- [ ] Real prior-store (V2 on disk) → V3 migration preserves all tracks/relationships/bookmarks (test in AUDIT-012)
- [ ] ListeningSession insert succeeds against the production container config

### Suggested Verification
AUDIT-012's migration tests; focused TrackDataActor tests; full data-layer suite.

### Risks and Regression Areas
Migration ordering bugs can brick store opens — this is why AUDIT-012 lands in the same group.

### Notes
Ledger H-02. WP3 downgraded severity because SwiftData's actual runtime failure mode was unverified; the invariant violation stands regardless.

### Implementation Record
- Started: 2026-07-26
- Completed: 2026-07-26
- Commit: Not requested
- Verification result: The deployed five-entity V2 schema is preserved as an immutable snapshot and migrates through the production V2-to-V3 plan to the live six-entity schema. The disk fixture matched checksum `aPr7hl9+thrTx4zb4MWTdHmK3BIQhXisbeX6NXkXwoc=`, preserved data and relationships, accepted `ListeningSession`, and the production-container failure test passed. The simulator build succeeded.

## AUDIT-011 — Wire listening-session lifecycle: production wiring, sequencing, real listened time, retention

- Status: [DONE]
- Priority: P1
- Audit sources: Model B (DLP-004, DLP-017, DLP-019, DLP-020, CP-005), WP3-010, DCA-PART-001
- Audit finding IDs: CAN-009 (DLP-004 + DCA-PART-001), CAN-012 (DLP-019 + CP-005), DLP-017, DLP-020
- Category: Data / feature completion
- Severity: High (CAN-009 source) / Medium (WP3)
- Difficulty: Hard
- Risk: Medium
- Scope: Cross-feature (audio facade + data actor)
- Estimated effort: L
- Implementation group: GROUP-03
- Depends on: AUDIT-010
- Blocks: —
- Related tasks: AUDIT-051 (session tests)
- Affected features: listening history, recommendations input
- Affected files or symbols: `AudioEngineFacade.swift:215-216` (`configureSessionTracking` never called in production), `ListeningSessionService.swift:61-70` (unsequenced `Task { await endSession }` race), `:78-93` (`durationListened = currentTime` conflates position with time listened), `TrackDataActor.swift:798-801` (no retention bound)
- Validation status: Confirmed on all four member findings (revalidated 2026-07-15)
- Validation evidence: cited lines

### Problem
Session tracking exists but is never wired in production; if wired as-is, session replacement can race and clear the new session, "time listened" is actually playback position, and history grows unbounded.

### Likely Root Cause
Feature was landed incomplete; lifecycle design (serialization, deltas, retention) was never finished.

### Recommended Implementation
Call `configureSessionTracking` during production facade setup; serialize end/replace on the owning actor (no unstructured `Task`); accumulate actual listened deltas across play/pause/seek; enforce a retention policy (count or age bound) on insert; cover play/pause/seek/next/previous/stop/crash-relaunch.

### Implementation Boundaries
Requires AUDIT-010's schema first. Keep session writes behind `TrackDataActor`. Preserve cancellation semantics.

### Acceptance Criteria
- [x] Production playback produces exactly one bounded, correctly-timed session per listen
- [x] Rapid track transitions never lose or clear the newer session (race test)
- [x] Listened time excludes paused/seek-skipped intervals
- [x] Retention bound enforced and tested

### Suggested Verification
Focused lifecycle tests (deterministic clock, no real sleeps — coordinate with AUDIT-050 conventions); data-layer suite.

### Risks and Regression Areas
MainActor/actor hops around playback events; ensure no new synchronous MainActor persistence (relates AUDIT-041).

### Notes
Ledger H-03.

### Implementation Record
- Started: 2026-07-26
- Completed: 2026-07-26
- Commit: Not requested
- Verification result: Production now configures session tracking; facade play/pause/resume/seek/stop/navigation/completion/shutdown events drive a generation-owned lifecycle that records elapsed listening time instead of playback position. A one-year retention policy runs on insert. Six deterministic lifecycle tests plus the retention test passed in the assembled 65-test audio/data lane; rapid-transition, paused-time, seek, and retention cases had zero skips.

## AUDIT-012 — Add real prior-store migration tests

- Status: [DONE]
- Priority: P1
- Audit sources: Model B (TRV-010)
- Audit finding IDs: TRV-010
- Category: Testing / persistence
- Severity: Medium
- Difficulty: Moderate
- Risk: Low
- Scope: Multi-file (tests + fixtures)
- Estimated effort: M
- Implementation group: GROUP-03
- Depends on: AUDIT-010
- Blocks: —
- Related tasks: AUDIT-050, AUDIT-051
- Affected features: persistence integrity
- Affected files or symbols: `Fonic HiFiTests/MigrationPlanTests.swift:7-11,41` (currently in-memory current-schema only, manual backfill helper)
- Validation status: Confirmed (revalidated 2026-07-15)
- Validation evidence: cited lines — no prior-version on-disk store is created or opened through the production plan

### Problem
No test creates a real prior-version store on disk and opens it through the production migration plan, so migration regressions ship silently — unacceptable given the repo's migration invariants.

### Likely Root Cause
In-memory testing convenience.

### Recommended Implementation
Build V(prev) stores on disk in a temp directory (via the archived prior schema types), populate representative data incl. relationships and bookmarks, open through the production `ModelContainer` + migration plan, and assert full survival plus new-model insertability.

### Implementation Boundaries
Test-target only; temp directories only; never touch real user stores.

### Acceptance Criteria
- [ ] Test creates a genuine prior-store file and migrates it via the production plan
- [ ] All records, relationships, and scalar compatibility fields survive
- [ ] Test fails (red) if a migration stage is removed — prove once

### Suggested Verification
Run new tests + full data suite.

### Risks and Regression Areas
None to production; test-infrastructure complexity only.

### Notes
Lands with GROUP-03 so AUDIT-010's stage is verified the moment it exists.

### Implementation Record
- Started: 2026-07-26
- Completed: 2026-07-26
- Commit: Not requested
- Verification result: The prior-store fixture is created on disk with the deployed V2 checksum, reopened only through `FonicHiFiMigrationPlan`, and verifies scalar values, bookmarks, relationships, quarantine defaults, and new-session persistence. `MigrationPlanTests` passed 2/2.

## AUDIT-013 — Remove copied media on post-copy import failure

- Status: [DONE]
- Priority: P1
- Audit sources: Model B (DLP-005), WP3-011
- Audit finding IDs: DLP-005
- Category: Import integrity
- Severity: High (WP3 retained High)
- Difficulty: Moderate
- Risk: Medium
- Scope: Localized
- Estimated effort: M
- Implementation group: GROUP-04
- Depends on: —
- Blocks: —
- Related tasks: AUDIT-014, AUDIT-015
- Affected features: import
- Affected files or symbols: `FileImportProcessor.swift:591-603` (copy → extract → persist with no cleanup on throw)
- Validation status: Confirmed (revalidated 2026-07-15)
- Validation evidence: cited lines — metadata extraction or persistence failure after `copyFile` leaves the copied file orphaned

### Problem
A failure after the audio file is copied into the managed container leaks the copy — storage grows with unplayable orphans and duplicate-detection state diverges.

### Likely Root Cause
No `defer`/catch cleanup around the copy-extract-persist sequence.

### Recommended Implementation
Wrap post-copy steps so any failure or cancellation removes the copied file (and only that file) before rethrowing; ensure duplicate-hash bookkeeping is not polluted by the failed attempt.

### Implementation Boundaries
Never delete pre-existing destination files or user source files. Preserve partial-failure reporting semantics.

### Acceptance Criteria
- [ ] Injected failure after copy leaves zero new files in the managed container (red before fix)
- [ ] Injected cancellation likewise cleans up
- [ ] Successful imports unaffected (existing suite green)

### Suggested Verification
Focused failure-injection tests with generated audio fixtures; import suite.

### Risks and Regression Areas
Cleanup racing a concurrently-succeeding duplicate import — coordinate with AUDIT-014's claim design.

### Notes
Ledger H-04.

### Implementation Record
- Started: 2026-07-26
- Completed: 2026-07-26
- Commit: Not requested
- Verification result: Post-copy failures remove only the copied managed destination while preserving source files. Focused import, processor, and cancellation suites passed in the 97-test foundational lane; the assembled simulator build succeeded.

## AUDIT-014 — Make concurrent duplicate detection an atomic claim

- Status: [DONE]
- Priority: P1
- Audit sources: Model B (DLP-006, CP-004), WP3-015, WP4-R05
- Audit finding IDs: CAN-010
- Category: Import integrity / concurrency
- Severity: High (source) / Medium (WP3 — reproduction unverified)
- Difficulty: Hard
- Risk: Medium
- Scope: Multi-file
- Estimated effort: L
- Implementation group: GROUP-04
- Depends on: — (do after AUDIT-015; shared kernel)
- Blocks: —
- Related tasks: AUDIT-013, AUDIT-015
- Affected features: import, duplicate handling
- Affected files or symbols: `FileImportProcessor.swift:281-288,586-603` (workers get snapshots of `hashCache`; existence check and insert are separate ops); `TrackDataActor` insertion path (WP4-R05 recommends one actor-isolated insertion kernel)
- Validation status: Confirmed (revalidated 2026-07-15)
- Validation evidence: cited lines

### Problem
Two concurrent imports of the same source can both pass the existence check and both insert — duplicate tracks and duplicate managed files.

### Likely Root Cause
Check-then-insert across an actor boundary with per-worker cache snapshots; no unique claim.

### Recommended Implementation
Adopt WP4-R05's insertion kernel: one private actor-isolated no-save insertion helper that performs the final duplicate check and claim atomically inside `TrackDataActor`; losers get a typed duplicate result, not an error. Keep bounded concurrency outside the claim.

### Implementation Boundaries
Preserve save-boundary semantics, bounded concurrency, and partial-failure reporting. No schema change.

### Acceptance Criteria
- [ ] Concurrent same-source imports create exactly one file/model/relationship set (stress test)
- [ ] Loser reports duplicate, not failure
- [ ] No throughput collapse (import benchmark unchanged within tolerance)

### Suggested Verification
Concurrency stress test with N parallel imports of identical fixtures; import suite.

### Risks and Regression Areas
Serializing too much of the pipeline; keep hashing/copying parallel, claim minimal.

### Notes
Ledger H-05.

### Implementation Record
- Started: 2026-07-26
- Completed: 2026-07-26
- Commit: Not requested
- Verification result: Duplicate detection and creation now share the `TrackDataActor` save boundary and duplicate outcomes remain distinct from failures. Focused concurrent-claim/import suites passed, including the corrected duplicate-stream assertion.

## AUDIT-015 — Propagate import cancellation to producers; make AsyncSemaphore cancellation-aware

- Status: [DONE]
- Priority: P1
- Audit sources: Model B (DLP-021, CP-001, CP-002), WP3-013, WP4-R06
- Audit finding IDs: CAN-013, CP-001
- Category: Concurrency
- Severity: High (source) / Medium (WP3)
- Difficulty: Hard
- Risk: Medium
- Scope: Multi-file
- Estimated effort: L
- Implementation group: GROUP-04
- Depends on: —
- Blocks: — (precedes AUDIT-014 by group convention)
- Related tasks: AUDIT-013, AUDIT-014
- Affected features: import cancellation
- Affected files or symbols: `FileImportProcessor.swift:102-105,143-155` (unstructured producer Tasks, no `onTermination`), `AsyncSemaphore.swift:6-29` (plain continuations, no cancellation handler; cancelled waiter can be resumed by a later release)
- Validation status: Confirmed (revalidated 2026-07-15). Note: the in-flight `FormatDetectionCoordinator` change released permits after completed failures but waiting-task cancellation remains open (per ledger)
- Validation evidence: cited lines

### Problem
Cancelling an import leaves AsyncStream producers running (work and file operations continue) and semaphore waiters are cancellation-blind — violating the repo's cancellation-preservation invariant.

### Likely Root Cause
Producers launched as unstructured tasks with no lifetime tie to the consumer; semaphore built before cancellation design.

### Recommended Implementation
Per WP4-R06: retain producer task handles, cancel them from `continuation.onTermination`, stop on terminated yields, and check cancellation before scheduling/committing work. Replace `AsyncSemaphore` waiters with a tokenized design using `withTaskCancellationHandler` (do not copy the audit's racy sample — design for release/cancel races).

### Implementation Boundaries
Preserve bounded concurrency and duplicate/partial-failure semantics. Cancellation must not be converted into generic failure.

### Acceptance Criteria
- [ ] Cancel during discovery/queueing/copying/extracting/persisting terminates producers; counts stop changing
- [ ] Cancelled semaphore waiter neither leaks a continuation nor loses/over-releases a permit (race test repeated)
- [ ] Partial files cleaned per AUDIT-013 semantics

### Suggested Verification
Cancellation tests at each pipeline stage; repeated release/cancel race test; import suite.

### Risks and Regression Areas
`FormatDetectionCoordinator` also uses the semaphore — run its concurrency tests; preserve the in-flight uncommitted changes there.

### Notes
Ledger H-06 + H-07 combined (same primitive and pipeline).

### Implementation Record
- Started: 2026-07-26
- Completed: 2026-07-26
- Commit: Not requested
- Verification result: Producer cancellation propagates through discovery and processing, `AsyncSemaphore` removes cancelled waiters, and cited tests use deterministic control rather than wall-clock sleeps. The foundational 97-test lane and current import suites passed with zero skips.

## AUDIT-016 — Replace one-shot missing-file deletion with a quarantine/retry policy

- Status: [DONE]
- Priority: P1
- Audit sources: Model B (DLP-007), WP3-012
- Audit finding IDs: DLP-007
- Category: User-data safety
- Severity: High (source) / Medium (WP3 — trigger unverified)
- Difficulty: Moderate
- Risk: High (touches deletion policy)
- Scope: Multi-file
- Estimated effort: M
- Implementation group: —
- Depends on: —
- Blocks: —
- Related tasks: AUDIT-013 (managed-file lifecycle)
- Affected features: startup cleanup, library integrity
- Affected files or symbols: `FonicHiFiApp.swift:202-206` (cleanup ~3 s after launch), `TrackDataActor.swift:697-699` (`fileExists` false → immediate `modelContext.delete(track)`)
- Validation status: Confirmed (revalidated 2026-07-15)
- Validation evidence: cited lines

### Problem
One failed existence check at startup permanently deletes the track record — temporary unavailability (slow volume mount, protected-data window, transient FS state) becomes permanent library loss.

### Likely Root Cause
Cleanup treats a single point-in-time check as proof of permanent removal.

### Recommended Implementation
Mark misses as "unavailable" with a counter/timestamp (schema field rides AUDIT-010 if needed); only remove records after a policy threshold (N consecutive misses over M days) or explicit user confirmation; surface unavailable state in the library UI instead of deleting.

### Implementation Boundaries
Never delete managed media files here; records only, and only past threshold. No recovery-by-deletion patterns.

### Acceptance Criteria
- [ ] Simulated temporary unavailability never deletes records (red before fix)
- [ ] Threshold-based removal cleans relationships correctly
- [ ] Unavailable tracks visibly distinguished, not silently vanished

### Suggested Verification
Focused tests with injected FileManager behavior; library suite.

### Risks and Regression Areas
UI handling of unavailable tracks (play attempts must fail visibly — ties to AUDIT-038).

### Notes
Ledger H-09. Sequence after import-pipeline work so file-lifecycle semantics are settled.

### Implementation Record
- Started: 2026-07-26
- Completed: 2026-07-26
- Commit: Not requested
- Verification result: Missing files are quarantined and surfaced as unavailable; recovery resets the miss window; record removal requires three consecutive misses across at least seven days and cleans playlist/album/artist relationships without deleting media. Migration defaults, transient recovery, threshold cleanup, relationship cleanup, and visible/accessibility presentation tests passed.
