# Widget, Testing, Cleanup & Cross-Cutting Programs — AUDIT-048 … AUDIT-056

## AUDIT-048 — Guard the app/widget shared-contract mirror against drift

- Status: [TODO]
- Priority: P2
- Audit sources: Model B (DCA-DUP-001), WP4-R08, WP5 (CLN-006)
- Audit finding IDs: DCA-DUP-001, WP4-R08, CLN-006
- Category: Widget / project structure
- Severity: Medium
- Difficulty: Easy
- Risk: Low
- Scope: Multi-file
- Estimated effort: S
- Implementation group: GROUP-12
- Depends on: —
- Blocks: AUDIT-049
- Related tasks: AUDIT-003 (widget build config), AUDIT-043 (widget strings)
- Affected features: widget data contract
- Affected files or symbols: `Fonic HiFi/Shared/{WidgetConstants,WidgetPlaybackState,WidgetTrackInfo}.swift` vs `Fonic HiFi Widget/Shared/` mirrors (all three pairs currently differ in header comments only — bodies verified behaviorally identical on 2026-07-15), `project.pbxproj:79-104,183-185,236-248`
- Validation status: Confirmed (revalidated 2026-07-15 via `diff` of all three pairs)
- Validation evidence: `diff` shows comment-only divergence today; nothing prevents behavioral divergence tomorrow

### Problem
Three shared-data contract files are maintained as manual copies in app and widget targets. Any one-sided edit silently breaks the wire format between app and widget (App Group payloads), and the header drift shows edits already land on one side only.

### Likely Root Cause
Widget extension was given standalone copies to avoid cross-target dependencies; no guard was added.

### Recommended Implementation
Per WP4-R08, in two steps: (1) immediately add a semantic drift guard — a unit test or CI script that fails when the mirrored files' type bodies diverge, plus bidirectional round-trip fixtures (app-encode→widget-decode, widget-encode→app-decode, legacy-payload decode); (2) then compile one neutral shared source into both targets (shared file with dual target membership, or a tiny local package). Step 2 requires Xcode target-membership changes — a genuine project-configuration change, in scope per AGENTS.md §3.

### Implementation Boundaries
Preserve exactly: App Group identifier, UserDefaults keys, widget kind, Codable fields/defaults/date strategy, legacy payload compatibility. Do not touch widget design, timeline policy, App Intents, artwork cache policy, or bundle identifiers.

### Acceptance Criteria
- [ ] Round-trip fixture tests pass in both directions plus a legacy stored payload
- [ ] Drift in a mirrored contract fails CI (or the unified source removes the mirror entirely)
- [ ] Both app and widget targets build cleanly; no duplicate symbols

### Suggested Verification
App + widget target builds; new contract tests; decode a pre-change persisted App Group payload.

### Risks and Regression Areas
Wire format between installed app versions and the widget; target-membership mistakes can break the extension build (that is why the drift guard lands first).

### Notes
AGENTS.md explicitly allows unification only intentionally — this task is that intentional unification. Keep step 1 even if step 2 is deferred.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-049 — Replace poll-driven widget sync with event-driven updates; move artwork/file work off MainActor

- Status: [TODO]
- Priority: P2
- Audit sources: Model B (AUD-WIDGET-001, DLP-016, CP-006 → CAN-017; CP-009)
- Audit finding IDs: CAN-017, CP-009
- Category: Widget / performance
- Severity: Medium
- Difficulty: Hard
- Risk: Medium
- Scope: Cross-feature
- Estimated effort: L
- Implementation group: GROUP-12
- Depends on: AUDIT-048 (contract guard before changing payload production)
- Blocks: —
- Related tasks: AUDIT-036 (observation boundary), AUDIT-054 (CP-009 app-side profiling)
- Affected features: widget freshness, main-thread load
- Affected files or symbols: `WidgetDataCoordinator.swift:72-95` (500 ms `while !Task.isCancelled` poll of `queueManager.queueState` with `Task.sleep`), `WidgetDataCoordinator.swift:206-252` and `WidgetArtworkCache.swift:12-15,53-84,207-303` (`@MainActor` artwork processing and file maintenance), `AppGroupManager.swift:50-64`
- Validation status: Confirmed (revalidated 2026-07-15; poll loop and MainActor isolation both present)
- Validation evidence: cited lines

### Problem
Widget state is kept fresh by a permanent 500 ms MainActor polling loop; queue changes between polls are stale, and artwork resizing/JPEG encoding plus App Group file maintenance run on the MainActor, competing with UI work.

### Likely Root Cause
Queue manager exposes no change stream, so the coordinator polls; the cache inherited MainActor isolation from its call sites.

### Recommended Implementation
Expose a queue-change publisher/AsyncSequence from the established queue-state owner (coordinate with AUDIT-036's observation work) and drive `handleQueueStateChange` from it; delete the poll loop. Move artwork decode/resize/encode and file maintenance to a non-main executor (actor or detached worker with explicit hops back), preserving cancellation. Coalesce bursts so `WidgetCenter.reloadTimelines` is not spammed.

### Implementation Boundaries
Do not change payload shape, App Group keys, or timeline policy (AUDIT-048 guards these). Widget must still fail safely when app-side data is absent (AGENTS.md widget rules).

### Acceptance Criteria
- [ ] Queue/track changes propagate to the shared payload without polling (test with a driven state stream)
- [ ] No periodic wake-ups when playback state is idle
- [ ] Artwork processing verified off the main thread (assertion or test)
- [ ] Widget renders placeholder/stale-data states unchanged

### Suggested Verification
App + widget builds; coordinator unit tests with a scripted state stream; Instruments main-thread check while playing (feeds AUDIT-054); widget snapshot/timeline manual pass.

### Risks and Regression Areas
Missed transitions the poll used to catch eventually (ensure the event source covers queue reorder/replace); artwork cache races once off MainActor — keep single-owner semantics.

### Notes
Poll interval comments in code ("5x slower than 100ms") show the loop is a workaround, not a design.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-050 — Test hygiene: deterministic clocks, isolated shared state, honest skip policy

- Status: [TODO]
- Priority: P2
- Audit sources: Model B (TRV-004, TRV-015 → CAN-026; TRV-005, TRV-008, TRV-009)
- Audit finding IDs: CAN-026, TRV-005, TRV-008, TRV-009
- Category: Testing
- Severity: Medium
- Difficulty: Moderate
- Risk: Low
- Scope: Multi-file (tests + narrow seams)
- Estimated effort: M
- Implementation group: GROUP-10
- Depends on: —
- Blocks: — (conventions consumed by AUDIT-011, 024, 047, 051)
- Related tasks: AUDIT-051, AUDIT-047, AUDIT-005 (CI gates)
- Affected features: test suite reliability
- Affected files or symbols: `Fonic HiFiTests/AudioKitEngineAdapterTests.swift:9,24,41,72,88,108,126,140` (eight `XCTSkip("AudioKit engine failed to initialize…")` converting failures into green skips), `Fonic HiFiTests/SleepTimerManagerTests.swift:26,47,66` (1.5–2.5 s real sleeps), `Fonic HiFiTests/PlaybackStateManagerTests.swift:27,48,79,97` (100 ms sleeps), `QueueState.swift:327-365` / `AudioQueueManager.swift:655-665` (tests share real UserDefaults/sandbox state)
- Validation status: Confirmed (revalidated 2026-07-15)
- Validation evidence: cited lines

### Problem
Three compounding defects make the suite slow and untrustworthy: environment failures become passing skips (a broken AudioKit init produces a green run), real sleeps make timer/async tests scheduler-dependent and add seconds per test, and tests mutate shared process state (real UserDefaults suite) so order can affect results.

### Likely Root Cause
No injectable clock; no per-test defaults isolation; skips used as a shortcut for unavailable prerequisites.

### Recommended Implementation
Establish suite-wide conventions once: (1) inject a clock/scheduler into `SleepTimerManager`, `PlaybackStateManager`, and similar timer owners; replace sleeps with controlled advancement; (2) route queue persistence through an injected `UserDefaults(suiteName:)` (or the `QueueStatePersisting` seam from AUDIT-041) with per-test unique suites and teardown; (3) skip policy: a skip is legal only for a genuinely environment-dependent capability, must state the exact reason, and CI must report skip counts so silent erosion is visible — engine-init failure in the standard environment becomes a failure, not a skip.

### Implementation Boundaries
Test-only plus narrow injection seams; no behavior changes to production logic beyond adding injectable dependencies with production defaults. Coordinate the persistence seam with AUDIT-041 rather than duplicating it.

### Acceptance Criteria
- [ ] No `Task.sleep`-based synchronization remains in the cited tests; suite time drops measurably
- [ ] Tests pass in random order and in parallel (shared-state isolation verified)
- [ ] Skip inventory documented; unjustified skips converted to failures or capability-gated tests
- [ ] CI surfaces skip counts (with AUDIT-005)

### Suggested Verification
Full test target twice with `-parallel-testing-enabled` and randomized order; compare durations; review CI skip report.

### Risks and Regression Areas
Clock injection touches production initializers — keep defaults identical; overly strict skip policy could redden CI on legitimately capability-limited runners (document the allowed list).

### Notes
Do this before or alongside AUDIT-047/051 — both consume these conventions. Ledger cross-ref: WP3 CAN-026 retained at Medium.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-051 — Real integration and scale test lanes (real media bytes, production-shaped stores)

- Status: [TODO]
- Priority: P2
- Audit sources: Model B (TRV-006, TRV-011)
- Audit finding IDs: TRV-006, TRV-011
- Category: Testing
- Severity: Medium
- Difficulty: Moderate
- Risk: Low
- Scope: Multi-file (tests)
- Estimated effort: M
- Implementation group: GROUP-10
- Depends on: AUDIT-050 (conventions), AUDIT-012 (shares prior-store fixture tooling)
- Blocks: —
- Related tasks: AUDIT-017 (10k-track comparisons), AUDIT-010/011 (session flows to cover)
- Affected features: integration/perf confidence
- Affected files or symbols: `ImportTestFixtures.swift:40-64,145-165` (fake bytes, fake metadata), `ImportPlaybackIntegrationTests.swift:37-64,69-112,115-164` (test-only controller instead of production playback path), `ImportValidationScenarioTests.swift:6-27`, `LibraryStatisticsPerformanceTests.swift:8-16,25-29,68-86` (in-memory store, no stable metric baseline)
- Validation status: Confirmed (revalidated 2026-07-15)
- Validation evidence: cited lines

### Problem
The "integration" lane imports fake bytes with fabricated metadata into a test-only controller, so the real decode→persist→queue→play chain is never exercised; perf tests run against in-memory stores with no stable baseline, so regressions at library scale are invisible.

### Likely Root Cause
Fixtures predate generated-media tooling; performance tests were written for speed, not representativeness.

### Recommended Implementation
Generate small real audio files (AVFoundation-rendered tones in real containers: m4a/wav/flac as supported) as fixtures; run import→metadata→persist→queue→play through the production facade path in the simulator lane. For scale: on-disk SwiftData store fixture at a documented track count, measured with `XCTMetric`/Swift Testing time limits and a recorded baseline. Generated tones are explicitly valid for logic tests per AGENTS.md; hardware claims stay in AUDIT-055.

### Implementation Boundaries
Tests and fixture tooling only. Do not repurpose `music-file/` user media without confirmation; do not claim gapless/hardware behavior from this lane.

### Acceptance Criteria
- [ ] Integration test imports real encoded audio and reaches playing state via production components
- [ ] Metadata assertions come from real extraction, not fixture echoes
- [ ] Scale tests run against an on-disk store with a recorded, thresholded baseline
- [ ] Lane runtime stays within an agreed CI budget

### Suggested Verification
Run new lanes locally and in CI; confirm they fail when an import stage is deliberately broken (mutation check).

### Risks and Regression Areas
CI time growth — keep fixture files tiny and cache generated media; flaky thresholds — use generous initial budgets and tighten with data.

### Notes
Fills the gap that let AUDIT-013/014/015-class defects ship despite a "green" suite.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-052 — Dead-code and unreachable-file triage behind an Xcode-verified gate

- Status: [TODO]
- Priority: P3
- Audit sources: Model B (DCA-DEAD-001 residual, DCA-DEAD-002), WP5 (CLN-003, CLN-004, CLN-005 residual)
- Audit finding IDs: DCA-DEAD-002, CLN-003, CLN-004
- Category: Cleanup
- Severity: Low
- Difficulty: Moderate
- Risk: Medium
- Scope: Multi-file
- Estimated effort: M
- Implementation group: —
- Depends on: —
- Blocks: —
- Related tasks: AUDIT-002 (tracked artifacts), AUDIT-053 (docs)
- Affected features: none (removal only)
- Affected files or symbols: WP5 register lists 18 production-unreachable files (CLN-003) and 61 unreferenced symbol roots (CLN-004), e.g. `AudioKitEngineAdapter.swift:389-408`, `FileImportProcessor.swift:536-542,556-577`; several DCA-DEAD-001 files already gone (see `01-resolved-findings.md` row 25)
- Validation status: Partially confirmed — lexical evidence only; the audits themselves flag "Xcode gate required". A prior spot-check found some listed items no longer exist, and an earlier queue-coordinator dead-method claim did not reproduce (`rg` for `removeFromQueue|moveInQueue|insertInQueue` under `Core/Audio` returned nothing), so each entry needs individual re-verification.
- Validation evidence: WP5 register + spot checks above

### Problem
Dead files and symbols inflate build time and mislead maintenance, but the inventory is stale and lexically derived — file-system-synchronized groups mean "not lexically referenced" is not proof of "not compiled/used".

### Likely Root Cause
Iterative refactors left orphans; no periodic reachability audit.

### Recommended Implementation
Three-step gate per item: (1) regenerate the inventory against the current tree (the audit list is from `459db9b`); (2) verify via Xcode — target membership, build after removal, full test run; (3) remove in small per-subsystem commits. Anything intentionally retained (planned API) gets wired or explicitly documented instead of deleted. Never remove test doubles, previews, or in-flight-work files (see protected list in `00-README.md`).

### Implementation Boundaries
Removal only — no behavior changes, no "while I'm here" refactors. Skip anything touched by the user's uncommitted work.

### Acceptance Criteria
- [ ] Regenerated inventory recorded with per-item disposition (remove/wire/keep-documented)
- [ ] Clean build + full green tests after each removal batch
- [ ] No removed symbol referenced by tests, previews, or the widget target

### Suggested Verification
Full-suite run and app+widget builds per batch; `rg` sweep for each removed symbol before deletion.

### Risks and Regression Areas
Reflection-free Swift makes lexical checks mostly safe, but SwiftUI previews, `@objc` selectors, and Interface-less runtime lookups are the classic false-negative sources — check each.

### Notes
Deliberately last-priority: zero user value, nonzero regression risk. Do not run during active feature work in the same files.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-053 — Documentation index: reconcile stale, duplicated, and contradictory docs

- Status: [TODO]
- Priority: P3
- Audit sources: WP5 (CLN-008, CLN-015), Model B (doc-drift observations)
- Audit finding IDs: CLN-008, CLN-015
- Category: Documentation
- Severity: Low
- Difficulty: Easy
- Risk: Low
- Scope: Multi-file (docs only)
- Estimated effort: S
- Implementation group: —
- Depends on: —
- Blocks: —
- Related tasks: AUDIT-002 (removes the duplicate-copy docs; this task organizes what remains)
- Affected features: none (docs)
- Affected files or symbols: 215 tracked Markdown docs across competing roots (`.factory/docs` 27, `docs/plans` 11, `Files/**` 98, root 9); `CLAUDE.md:46-53` links four `docs/references/` targets that exist locally but are **untracked** (broken for any fresh clone — decide with the user whether to track them); `summary.md` reports a stale 172-file architecture (the four target roots currently contain 288 Swift files); `Files-analysis.md`, `EQ.md` unindexed at root
- Validation status: Confirmed structurally (tracked-document and target-root counts re-checked 2026-07-15; `docs/references/` link targets exist untracked)
- Validation evidence: `git ls-files` scoped counts, target-root `rg --files -g '*.swift'`, and WP5 CLN-008 evidence block

### Problem
Documentation is fragmented across five roots with contradictory or stale content and broken links, so agents and humans revalidate everything from scratch (AGENTS.md already mandates distrust of `README.md`/`STATUS.md`/`Files/` claims — this task reduces why).

### Likely Root Cause
Successive plan generations accreted without an index or archival policy.

### Recommended Implementation
Per WP5: create one documentation index with explicit statuses (authoritative / active plan / historical / generated research / raw input); archive stale generated analyses after mapping unique requirements into current docs; move `EQ.md` under the reference tree only after validating its code claims; fix or remove `CLAUDE.md`'s broken links; keep `Files/` as the historical archive (CLN-014 — do not delete wholesale). Small, individually revertible commits with a before/after path map.

### Implementation Boundaries
Docs only. No source, config, or asset changes. Do not delete `Files/` content; archive/index instead.

### Acceptance Criteria
- [ ] One index lists every doc root with status labels
- [ ] No broken internal doc links (checked by script or manual sweep)
- [ ] Root-level strays (`EQ.md`, `Files-analysis.md`, `summary.md`) relocated or explicitly indexed
- [ ] Unique requirements from archived docs demonstrably mapped forward

### Suggested Verification
Link check across docs; `git diff --stat` confined to docs; AGENTS.md path references still valid.

### Risks and Regression Areas
Agent workflows referencing old paths (e.g. `.factory/docs`, `CLAUDE.md` links) — update references in the same commit as each move.

### Notes
Coordinate ordering with AUDIT-002 so files aren't moved and then deleted (or vice versa) in conflicting commits.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-054 — Performance program: profile first, then fix measured MainActor/allocation hotspots

- Status: [TODO]
- Priority: P2
- Audit sources: Model B (CP-008, CP-009 app half, CP-010, CP-011, CP-013, CP-016)
- Audit finding IDs: CP-008, CP-009 (app-side, with AUDIT-049), CP-010, CP-011, CP-013, CP-016
- Category: Performance
- Severity: Medium
- Difficulty: Hard
- Risk: Medium
- Scope: Cross-feature
- Estimated effort: XL (phased; each phase M or smaller)
- Implementation group: —
- Depends on: AUDIT-017/018 (library data layer stabilizes first), AUDIT-036 (observation boundary) — profiling unstable code wastes traces
- Blocks: —
- Related tasks: AUDIT-041 (queue persistence off MainActor), AUDIT-046 (Home first paint), AUDIT-049, AUDIT-051 (scale baselines)
- Affected features: Home/Search responsiveness, artwork memory, list scrolling, startup
- Affected files or symbols: `SearchView.swift:79-113,123-168` + `DataManager+Search.swift:11-12,37-202` (synchronous SwiftData work on MainActor, CP-008); `ArtworkService.swift:64-157` + `LazyArtworkView.swift:28-153` (entry-count cache limit, not memory cost, CP-010); `LibraryView.swift:195-281` + `QueueView.swift:31-49` (arrays materialized per body evaluation, CP-011); `LibraryView.swift:378-417` + `LibraryEntities.swift:80-91` (formatters/sorts rebuilt in render paths, CP-016); `FonicHiFiApp.swift:202-231` (three unowned fire-and-forget startup `Task {}` blocks with sleeps — cancellation-blind, CP-013)
- Validation status: Confirmed statically (CP-013 re-verified 2026-07-15: three unstructured Tasks present); runtime impact of all items unmeasured — the audit itself requires traces before code changes
- Validation evidence: cited lines

### Problem
Six statically identified performance smells (MainActor SwiftData work, unbounded-by-cost artwork cache, per-body array materialization, render-path formatter/sort rebuilds, unowned startup tasks) plausibly degrade responsiveness and memory at library scale, but none has measured runtime impact yet — fixing unmeasured smells risks churn without benefit.

### Likely Root Cause
Convenience-first implementations that never met a profiler.

### Recommended Implementation
Phase 0 (gate for everything else): Instruments traces — Time Profiler + SwiftUI + Allocations — on a 5–10k-track on-disk store (fixture from AUDIT-051) covering launch, Home, Search typing, Library scroll, queue mutation. Rank the six items by measured cost. Then fix only what the traces convict, one phase per subsystem: move search/SwiftData work behind the repository/actor boundary (CP-008); cost-based artwork cache with `NSCache` totalCostLimit semantics (CP-010); memoize/derive collections outside `body` (CP-011/016); make startup tasks owned and cancellable — store handles, structured concurrency, cancellation on scene teardown (CP-013 — this one is a correctness fix and may proceed without a trace). Re-trace after each phase.

### Implementation Boundaries
No speculative rewrites of untraced code; no architecture changes beyond the established repository/actor boundaries; CP-009's widget half belongs to AUDIT-049.

### Acceptance Criteria
- [ ] Baseline and post-phase traces recorded with the scenario list above
- [ ] Each shipped fix shows a measured improvement (main-thread time, memory, or hitch rate)
- [ ] Startup tasks are owned, cancellable, and cancellation-tested
- [ ] No regression in the AUDIT-051 scale baselines

### Suggested Verification
Instruments on device (simulator traces acceptable for relative main-thread comparisons; memory claims need device); AUDIT-051 perf lane before/after.

### Risks and Regression Areas
Moving search off MainActor touches actor isolation (strict concurrency — no `@unchecked Sendable` shortcuts per AGENTS.md); cache-policy changes affect artwork UX under memory pressure.

### Notes
Explicitly an umbrella: decompose into per-phase tasks after Phase 0 ranks the work. XL estimate reflects the program, not one change.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-055 — Physical-device media acceptance and release-evidence lane

- Status: [BLOCKED]
- Priority: P1 (release gate) — blocked on physical devices + release owner
- Audit sources: Model B (TRV-016, A11YTEST-001, TRV-012 → CAN-020), ledger X-08
- Audit finding IDs: TRV-016, CAN-020
- Category: Verification / release
- Severity: High (for release claims)
- Difficulty: Complex (coordination, not code)
- Risk: Low (evidence-gathering; no code changes)
- Scope: Cross-feature
- Estimated effort: XL
- Implementation group: —
- Depends on: implementations it verifies — notably AUDIT-026 (media reset), AUDIT-028 (bit-perfect claims), AUDIT-031/032 (session/route), AUDIT-034 (gapless); consumes AUDIT-047's on-device AI check
- Blocks: any "release-ready", "gapless", or "bit-perfect" claim
- Related tasks: AUDIT-004/007 (release configuration/privacy answers), AUDIT-005 (future CI evidence, blocked), AUDIT-057 (CI retirement)
- Affected features: none directly (verification lane)
- Affected files or symbols: `Makefile` simulator-only lanes; no active hosted workflow or device matrix
- Validation status: Confirmed — no device lane exists; AGENTS.md §7 requires device evidence for exactly these behaviors
- Validation evidence: cited config; repo verification matrix

### Problem
The product's highest-risk behaviors — background audio, interruptions, route changes (Bluetooth/USB DAC/AirPlay), gapless and high-resolution output, bit-perfect claims, Apple Intelligence features, VoiceOver/Dynamic Type/locale behavior, widget on device — have no recorded physical-device verification lane. The repository provides simulator/static checks but no device evidence establishing these behaviors.

### Likely Root Cause
No physical-device test program was ever established.

### Recommended Implementation
Define a repeatable acceptance matrix (owner + device set required): interruption/route/background scenarios per AGENTS.md §7; consecutive real-track gapless capture; digital-output capture for any bit-perfect wording (with AUDIT-028's eligibility rename); Apple Intelligence supported-path checks (AUDIT-047); VoiceOver/Dynamic Type/RTL/locale pass (CAN-020); widget timeline/stale-data behavior on device. Record results as release evidence artifacts; wire summary reporting into CI only if CI is intentionally reintroduced.

### Implementation Boundaries
Evidence and process only — findings feed back as new tasks, not ad-hoc fixes inside this lane.

### Acceptance Criteria
- [ ] Written matrix with per-scenario pass/fail and device/OS identity
- [ ] Every marketing-sensitive claim (gapless, bit-perfect, background) mapped to a recorded evidence item
- [ ] Accessibility pass recorded on device
- [ ] Re-run procedure documented so the lane is repeatable per release

### Suggested Verification
The lane is itself verification; review completeness against AGENTS.md §7.

### Risks and Regression Areas
None to code; the risk is organizational (unowned lane → stale evidence).

### Notes
[BLOCKED]: requires physical devices (incl. USB DAC/Bluetooth targets) and a human release owner. Everything else in this backlog can proceed; final release claims cannot.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-056 — Untrack or remove the full Claude agent tree

- Status: [DONE]
- Priority: P3
- Audit sources: Owner follow-up after AUDIT-002 (broader than CAN-006 residual)
- Audit finding IDs: —
- Category: Repository hygiene
- Severity: Low
- Difficulty: Easy
- Risk: Low
- Scope: Localized
- Estimated effort: S
- Implementation group: GROUP-01 (related post-002 cleanup)
- Depends on: AUDIT-002 (DONE — `settings.local.json` already untracked)
- Blocks: —
- Related tasks: AUDIT-002, AUDIT-053
- Affected features: none (agent tooling docs only)
- Affected files or symbols: root `CLAUDE.md`; tracked `.claude/**` (commands, reference, skills); `sample/AppleMusicBottomBar/.claude/**`; `.gitignore` Claude rules. The active `.agents/skills/ios-simulator-skill/CLAUDE.md` bundle documentation is explicitly preserved.
- Validation status: Completed 2026-07-16 — local deletion and index removal are staged
- Validation evidence: root `.claude/`, sample `.claude/`, and root `CLAUDE.md` are absent from disk and the index; the active `.agents` skill-bundle guide remains

### Problem
AUDIT-002 only untracked machine-local Claude settings, not the project’s tracked Claude agent documentation tree. That tree is still in the index and can confuse readers who want a Claude-free repository, or reintroduce machine-local churn if ignore rules stay partial.

### Likely Root Cause
AUDIT-002 was intentionally scoped to CAN-006 residual artifacts (settings, logs, xcuserdata, stale copies, empty AppIcon), not a full agent-tooling retirement.

### Recommended Implementation
1. Chosen: untrack-and-delete-local for `.claude/**`, root `CLAUDE.md`, and the sample `.claude`; preserve the active `.agents` skill-bundle guide.
2. Ensure any still-needed project guidance already lives under `AGENTS.md` / `docs/references` before removing Claude-specific docs.
3. Stage `git rm --cached` (or full `git rm`) for the chosen paths; expand `.gitignore` to cover `.claude/` wholesale if local tooling will remain.
4. Leave AUDIT-053 files (`EQ.md`, `Files-analysis.md`, `summary.md`) and the `Files/` archive alone.

### Implementation Boundaries
No app/source behavior changes. Do not rewrite history. Do not touch AUDIT-053 or `Files/`. Prefer index-only removal when local Claude tooling is still useful.

### Acceptance Criteria
- [x] Chosen scope is recorded (delete locally and remove from tracking; preserve `.agents` skill documentation)
- [x] `git ls-files` returns no remaining in-scope Claude agent paths
- [x] Needed project guidance remains available via `AGENTS.md` / `docs/references`
- [x] `.gitignore` excludes `.claude/` directories and root `CLAUDE.md`

### Suggested Verification
`git ls-files | rg -i 'claude'`; `git check-ignore -v .claude/probe`; `git diff --cached --check`.

### Risks and Regression Areas
Historical Claude-specific guidance leaves the working tree; current project guidance remains in `AGENTS.md` and `docs/references`. The active `.agents` skill bundle is preserved.

### Notes
Created 2026-07-16 when finishing AUDIT-002 under owner choice: “strict AUDIT-002 now; open a separate follow-up task for full Claude purge later.” Local deletion and scoped staging were approved and completed the same day.

### Implementation Record
- Started: 2026-07-16
- Completed: 2026-07-16
- Commit: Not requested
- Verification result: MATCH — requested files absent from disk and index; directory-wide ignore rules match; active `.agents` skill documentation preserved; staged and unstaged diff checks pass
