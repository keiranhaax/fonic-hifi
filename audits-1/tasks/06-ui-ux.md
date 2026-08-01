# UI/UX, State Ownership & Accessibility — AUDIT-036 … AUDIT-043

## AUDIT-036 — Fix the app-wide observation boundary for the audio facade

- Status: [DONE]
- Priority: P0
- Audit sources: Model B (UIUX-001), Model A (A-F01), WP3-016, WP4-R01
- Audit finding IDs: UIUX-001, WP4-R01
- Category: Architecture / UI state
- Severity: High (WP3 retained)
- Difficulty: Complex
- Risk: High
- Scope: Architectural
- Estimated effort: L
- Implementation group: GROUP-07
- Depends on: —
- Blocks: AUDIT-037, AUDIT-038; unblocks the UI half of AUDIT-021
- Related tasks: AUDIT-018
- Affected features: every audio-consuming view
- Affected files or symbols: `AudioEnvironment.swift:14-22` (facade stored as plain custom `EnvironmentKey` value), `ContentView.swift:14` (`@Environment(\.audioEngine)`), `FonicHiFiApp.swift:103-110`, consumers across NowPlaying/Queue/Home
- Validation status: Confirmed (revalidated 2026-07-15) — `@Published` changes do not invalidate consumers reading the custom environment value
- Validation evidence: cited lines

### Problem
The ObservableObject facade is injected as an unobserved custom environment value, so view updates depend on incidental invalidation — stale track/artwork/progress/error rendering is structurally possible everywhere.

### Likely Root Cause
Custom environment key chosen for optionality; observation semantics lost.

### Recommended Implementation
Per WP4-R01: either use `@EnvironmentObject`/`@StateObject` end-to-end, or (preferred per WP4) introduce one MainActor observable presentation model and migrate views one state slice at a time; remove local/defaults mirrors only after consumers use the authoritative owner. Do not mix observation paradigms in one view graph (AGENTS.md).

### Implementation Boundaries
Preserve playback commands, engine behavior, queue/settings persistence, App Intent/widget controls, current UI structure and appearance. Do not touch the audio graph.

### Acceptance Criteria
- [x] Focused invalidation test: track/artwork/error/import changes update consumers
- [x] External changes (widget/App Intent/remote) update Now Playing and mini player
- [x] No view retains a stale copy of facade state after migration
- [x] Build + facade suites green; in-flight banner work preserved

### Suggested Verification
Invalidation tests; SwiftUI Cause & Effect instrumentation; device playback/interruption/restore smoke.

### Risks and Regression Areas
Every audio-consuming screen. Migrate slice-by-slice with checkpoints; WP4 flagged this approval-required.

### Notes
Ledger M-11. The single highest-leverage UI task: AUDIT-037/038 and half of AUDIT-021 are wasted effort without it.

### Implementation Record
- Started: 2026-07-26
- Completed: 2026-07-26
- Commit: Not requested
- Verification result: The shared facade is now observed by its consumers, including queue mutation and environment propagation paths. Focused observation/facade tests passed and the assembled simulator build succeeded.

## AUDIT-037 — Make Now Playing/mini-player state authoritative; gate visibility; add dismissal and accessory adaptation

- Status: [DONE]
- Priority: P1
- Audit sources: Model B (UIUX-002, UIUX-003, UIUX-004, UIUX-005), Model A (A-F11/F13), WP3-017
- Audit finding IDs: UIUX-002, UIUX-003, UIUX-004, UIUX-005
- Category: UI state / UX
- Severity: High (UIUX-002 source) / Medium
- Difficulty: Moderate
- Risk: Medium
- Scope: Multi-file
- Estimated effort: M
- Implementation group: GROUP-07
- Depends on: AUDIT-036
- Blocks: —
- Related tasks: AUDIT-024, AUDIT-040
- Affected features: Now Playing, mini player, tab accessory
- Affected files or symbols: `NowPlayingContent.swift:30,40-42` (local `@State playbackSpeed`, `@AppStorage` shuffle/repeat mirrors), `ContentView.swift:59-62` (accessory shown whenever service exists; no `tabViewBottomAccessoryPlacement` read), `LiquidGlassMiniPlayer.swift:53` ("Not Playing" rendering), `NowPlayingContent.swift:193-215` (no dismissal control)
- Validation status: Confirmed all four members (revalidated 2026-07-15)
- Validation evidence: cited lines

### Problem
Now Playing mirrors shuffle/repeat/speed in local state that drifts from the queue manager; the mini player renders with no track; the tab accessory ignores inline placement; full-screen Now Playing has no visible dismissal control.

### Likely Root Cause
State mirrored because observation was broken (AUDIT-036); visibility/dismissal polish never done.

### Recommended Implementation
Split into three patches: (1) delete duplicated state, read/write through the authoritative owner; (2) gate the accessory/mini player on an authoritative current track; (3) add an explicit dismiss control and adapt the accessory via `tabViewBottomAccessoryPlacement`.

### Implementation Boundaries
Requires AUDIT-036. Layout/Dynamic-Type overhaul is AUDIT-040, not here.

### Acceptance Criteria
- [x] External/remote changes to shuffle/repeat/speed reflect immediately in Now Playing (test)
- [x] Mini player hidden with no track; appears on first load
- [x] Visible, accessible dismissal control (44 pt, labeled)
- [x] Accessory renders correctly in both placements

### Suggested Verification
State-coherence tests; UI smoke portrait/landscape; VoiceOver pass on new control.

### Notes
Ledger M-13.

### Implementation Record
- Started: 2026-07-26
- Completed: 2026-07-26
- Commit: Not requested
- Verification result: Now Playing reads authoritative facade state, the mini player is gated on a current track, the full-screen surface has an accessible dismissal control, and the tab accessory adapts to placement. Focused presentation tests passed and the simulator build succeeded.

## AUDIT-038 — Surface remaining silent failures and observe import progress

- Status: [DONE]
- Priority: P1
- Audit sources: Model B (UIUX-009, UIUX-010), WP1 (FMA-004 partial), WP3-019, WP3-020
- Audit finding IDs: CAN-022 (residual), UIUX-010 (residual)
- Category: UX / error handling
- Severity: High (WP3 retained both)
- Difficulty: Moderate
- Risk: Medium
- Scope: Cross-feature
- Estimated effort: M
- Implementation group: GROUP-07
- Depends on: AUDIT-036
- Blocks: —
- Related tasks: AUDIT-016 (unavailable tracks), AUDIT-045
- Affected features: Home, Search, File Manager, import
- Affected files or symbols: `HomeView.swift:246-248,321-323` (playback/load failures silent), `SearchView.swift:213-218` (standard search failure → empty state), `FileManagerView.swift:304-305` (picker failure log-only), `ImportProgressView.swift:12,20-22` (import service consumed via unobserved custom environment), `LibraryView.swift:167-170` (presentation race)
- Validation status: Partially fixed — playback-error banner and Smart Search error UI exist in-flight; Home/standard-Search/File-Manager/import-observation paths confirmed open (2026-07-15)
- Validation evidence: cited lines

### Problem
Outside the new playback banner, core failures still collapse into silence or false emptiness: users can't distinguish "no results" from "search failed", picker errors vanish, and import progress observation depends on a broken boundary.

### Likely Root Cause
No typed user-visible error state per surface; observation boundary defect (AUDIT-036) hid progress.

### Recommended Implementation
One surface per patch: typed, recoverable error state for Home load/play, standard Search, File Manager picker, and import progress/end-of-import errors; make `LibraryImportService` properly observed; fix the sheet-presentation race by driving presentation from observed state.

### Implementation Boundaries
Preserve the uncommitted `PlaybackErrorBanner` work; reuse its patterns and `DesignTokens`. Distinguishable success/empty/error is required; no new design system.

### Acceptance Criteria
- [x] Failure injection on each surface produces visible, recoverable state
- [x] Empty vs error visually and accessibly distinct
- [x] Import progress renders live during an import; completion errors listed
- [x] No presentation race (deterministic sheet trigger)

### Suggested Verification
Per-surface failure-injection tests; manual import of a mixed-validity batch.

### Notes
Ledger M-12.

### Implementation Record
- Started: 2026-07-26
- Completed: 2026-07-26
- Commit: Not requested
- Verification result: Home, standard Search, File Manager, and import surfaces now expose distinct progress, empty, and recoverable failure states through observed presentation state. Focused failure-surface tests passed and the assembled simulator build succeeded.

## AUDIT-039 — Wire genre pill destinations

- Status: [DONE]
- Priority: P2
- Audit sources: Model B (UIUX-012)
- Audit finding IDs: UIUX-012 (residual)
- Category: UX completeness
- Severity: Medium
- Difficulty: Easy
- Risk: Low
- Scope: Localized
- Estimated effort: S
- Implementation group: —
- Depends on: —
- Related tasks: AUDIT-038
- Affected features: Home browse
- Affected files or symbols: `GenresSection`, `GenreTracksView`, `HomeView.selectedGenre`
- Validation status: Completed (2026-07-20)
- Validation evidence: focused Home UI regression plus a Debug iPhone 17 Pro (iOS 27.0) simulator build

### Problem
Genre pills look tappable but do nothing — the last remaining dead browse affordance.

### Likely Root Cause
Destination screen/filter was never wired.

### Recommended Implementation
Make pills semantic buttons navigating to a genre-filtered library/track list (reuse existing library filtering; no new design).

### Implementation Boundaries
No new navigation patterns; follow the album/artist card wiring just landed.

### Acceptance Criteria
- [x] Tapping a genre shows that genre's tracks
- [x] Pills are buttons with labels (VoiceOver activatable)

### Suggested Verification
UI test activating a pill by label; navigation postcondition.

### Notes
Ledger M-10 residue.

### Implementation Record
- Started: 2026-07-20
- Completed: 2026-07-20
- Commit: This commit (`fix(ui): wire genre destinations`)
- Verification result: Red UI regression failed because the seeded `Electronic` genre was not a button. The focused Home UI test then passed 1/1, activating the labeled 44-point genre button and verifying the `Electronic` destination showed exactly its seeded track; the Debug simulator build succeeded; SwiftLint reported 0 violations in 288 files; `git diff --check` passed. SwiftFormat 0.62.1 passed `GenresSection.swift`; `HomeView.swift` and the shared UI-test file retain only the same pre-existing formatting findings reproduced from `HEAD`, with no new task-introduced findings.

## AUDIT-040 — Adaptive Now Playing layout and non-color state differentiation

- Status: [DONE]
- Priority: P2
- Audit sources: Model B (UIUX-006, A11Y-006, A11Y-008), Model A (A-F10/F11/F13)
- Audit finding IDs: CAN-025, A11Y-008 (residual)
- Category: Accessibility / layout
- Severity: Medium
- Difficulty: Moderate
- Risk: Medium
- Scope: Localized
- Estimated effort: M
- Implementation group: —
- Depends on: — (do after AUDIT-037 to avoid re-layout churn)
- Related tasks: AUDIT-037
- Affected features: Now Playing
- Affected files or symbols: `NowPlayingContent.swift:65-98` (fixed stack + constrained spacers), `:102-106` (width-derived artwork), `:469-471,577-581` (shuffle/repeat-all differ only by opacity)
- Validation status: Confirmed CAN-025; A11Y-008 partially fixed (accessibility values exist; visual differentiation missing) — 2026-07-15
- Validation evidence: cited lines

### Problem
Now Playing clips or crowds at short heights and large Dynamic Type sizes; shuffle/repeat-all states are visually communicated only by opacity/color.

### Likely Root Cause
Fixed layout tuned for one geometry; symbol states unstyled.

### Recommended Implementation
Adopt an adaptive contract (`ViewThatFits`/ScrollView at AX sizes/short heights); differentiate active shuffle/repeat-all with a non-color cue (badge, fill variant, or background shape) honoring Differentiate Without Color.

### Implementation Boundaries
Preserve visual design language and glass effects; no state-ownership changes (AUDIT-037 owns those).

### Acceptance Criteria
- [x] No clipped/overlapping controls in the focused AX5 smallest-iPhone portrait/landscape evidence accepted for the supported private-app configuration
- [x] Shuffle/repeat states distinguishable without color/opacity alone
- [x] Reduce Motion/Transparency still honored

### Suggested Verification
Screenshot matrix (light/dark × sizes); accessibility audit tooling.

### Notes
Ledger M-13/X-08 visual slice.

Owner disposition (2026-08-01): Comprehensive accessibility matrices are not required for this private, single-user app. The existing focused automated and visual coverage is accepted as sufficient for the supported configuration; this disposition does not claim that the unrecorded exhaustive matrix was run.

### Implementation Record
- Started: 2026-07-28
- Completed: 2026-08-01
- Commit: Not requested
- Verification result: DONE BY OWNER-ACCEPTED SCOPE — Now Playing has compact/adaptive composition, minimum touch targets, and symbol/shape state cues that do not rely on color; Reduce Motion/Transparency behavior remains covered. A fresh iOS 27 iPhone 17e AX5 portrait/landscape initial-viewport lane passed 1/1 with two retained screenshots under `build/AuditEvidence/2026-07-29T12-05-17-0400/AUDIT-040/ax5-guard/`. XcodeBuildMCP hierarchy capture is unavailable because Xcode 27 lacks its legacy `SimulatorKit.framework`. Dark appearance, complete scroll-surface reachability, VoiceOver order, Differentiate Without Color, Reduce Motion, and Reduce Transparency review across all eight plan cells were not recorded and are not required for the supported private-app configuration.

## AUDIT-041 — Separate queue mutation from persistence/notification; move persistence off MainActor

- Status: [TODO]
- Priority: P1
- Audit sources: Model B (CP-003), Model A (A-B06), WP3-014, WP4-R02
- Audit finding IDs: CP-003, WP4-R02
- Category: Performance / architecture
- Severity: High (source) / Medium (WP3 — latency unmeasured)
- Difficulty: Hard
- Risk: Medium
- Scope: Multi-file
- Estimated effort: L
- Implementation group: —
- Depends on: — (profile first; sequence after E-07 queue-edit stability, already landed)
- Related tasks: AUDIT-017, AUDIT-054
- Affected features: queue editing responsiveness
- Affected files or symbols: `AudioQueueManager.swift:326-343,570-665` (mutation → full-queue synchronous persist on MainActor), `QueueState.swift:321-326,359-405`
- Validation status: Confirmed static cost (WP3-014); user-visible latency unmeasured — trace baseline required before/after
- Validation evidence: WP4-R02 evidence lines

### Problem
Every queue mutation synchronously serializes and persists the full queue on the MainActor — a scaling cliff for large queues and a source of duplicated side effects per logical mutation.

### Likely Root Cause
Persistence bolted onto each mutation instead of a finalize step.

### Recommended Implementation
Per WP4-R02: inject `QueueStatePersisting`; finalize each logical mutation once (recalculate → notify → one snapshot → one persistence request); move serialization/IO off MainActor via a safe owner; coalesce rapid mutations.

### Implementation Boundaries
Preserve queue order/index behavior, shuffle/repeat semantics, delegate event meaning, persistence key/payload, and restore behavior. Characterize delegate event order with tests before refactoring.

### Acceptance Criteria
- [x] One persistence request per logical mutation (test)
- [ ] MainActor performs no file stat/encode/write for queue persistence (trace)
- [x] Force-quit restore unchanged
- [ ] Before/after trace at queue scale recorded

### Suggested Verification
Characterization tests → refactor → Time Profiler/File Activity on device at 1k-track queue.

### Notes
Ledger H-08 (profile-first mandate).

### Implementation Record
- Started: 2026-07-28
- Completed:
- Commit: Not requested
- Verification result: IMPLEMENTED SLICE — queue snapshots now flow through an injected actor-owned persister, rapid mutations coalesce, and characterization tests assert one request per logical mutation plus stable queue semantics. On 2026-07-29 a fresh isolated current-state lane passed all 26 `AudioQueueManagerTests` as part of a 38/38 focused run. The Xcode 27 `xctrace` CPU Profiler probe hung after its five-second limit and the resulting 40 KB trace failed export with `Document Missing Template Error`; no reusable 1,000-track app fixture exists, and HEAD is not a queue-only baseline because the live 207-entry worktree contains multiple independent slices. The previous 592/592 unit and force-quit restore evidence remains green, but MainActor/file-activity and valid per-slice before/after traces are still missing, so the task remains TODO.

## AUDIT-042 — Extract FileManagerView state and filesystem I/O into a service + view model

- Status: [TODO]
- Priority: P2
- Audit sources: Model B (CP-015), WP4-R04
- Audit finding IDs: CP-015, WP4-R04
- Category: Architecture / performance
- Severity: Medium
- Difficulty: Moderate
- Risk: Medium
- Scope: Multi-file
- Estimated effort: M
- Implementation group: —
- Depends on: —
- Related tasks: AUDIT-038 (picker errors), AUDIT-006 (logging in this file)
- Affected features: File Manager (Settings)
- Affected files or symbols: `FileManagerView.swift:25-55,195-233,265-275,303-395` (synchronous UI-context I/O, uncancellable detached copy, UIKit root-controller alerts); no tests reference FileManagerView
- Validation status: Confirmed (WP4 evidence; structure unchanged 2026-07-15)
- Validation evidence: cited lines

### Problem
FileManagerView performs synchronous filesystem work in the UI context, uses an uncancellable detached copy, and presents alerts through UIKit root-controller access — untested and error/cancellation-lossy.

### Likely Root Cause
Feature grew inside one view without a service layer.

### Recommended Implementation
Per WP4-R04: introduce a filesystem service/actor + observable `FileManagerViewModel`; keep the view presentation-only; SwiftUI-owned alert state; preserve errors and cancellation in copy/delete/list; move measured blocking work off UI isolation.

### Implementation Boundaries
Preserve Settings route, root directory, sort/filter, importer types, selection/confirmation/unique-copy naming. Don't touch the library import architecture.

### Acceptance Criteria
- [x] Temp-directory tests: list/sort/search/root-bound, create/copy collision, failure and cancellation surfacing typed state
- [ ] No long UI-thread file operation (trace)
- [ ] Behavior parity for existing flows

### Suggested Verification
New unit tests with temp dirs; manual copy/delete flows; trace check.

### Notes
Ledger H-11.

### Implementation Record
- Started: 2026-07-28
- Completed:
- Commit: Not requested
- Verification result: IMPLEMENTED SLICE — filesystem operations are isolated behind a service/actor and observable view model with typed operation state, cancellation, collision handling, and SwiftUI-owned confirmation/error presentation. On 2026-07-29 a fresh isolated lane passed all 9 `FileManagerViewModelTests` as part of a 38/38 focused run, including list/search/sort, root and traversal bounds, collision-safe copy, delete, failure, and cancellation. The Xcode 27 trace probe hung and produced a non-exportable incomplete trace, and no new manual copy/delete parity record was captured. The previous complete UI evidence remains green, but the trace and explicit manual parity criteria remain open, so the task remains TODO.

## AUDIT-043 — Localization program: String Catalog, plurals, formatters, composable strings

- Status: [DONE]
- Priority: P2
- Audit sources: Model B (LOC-001, LOC-002, LOC-003, LOC-004)
- Audit finding IDs: LOC-001, LOC-002, LOC-003, LOC-004
- Category: Localization
- Severity: Medium
- Difficulty: Complex (program)
- Risk: Medium
- Scope: Cross-feature
- Estimated effort: XL (phased: catalog → plurals → formatters → composition → widget/a11y strings)
- Implementation group: —
- Depends on: — (schedule after AUDIT-037/038/040 to avoid re-migrating churning strings)
- Related tasks: AUDIT-028 (copy changes), AUDIT-048 (widget strings)
- Affected features: all user-visible text
- Affected files or symbols: no `.xcstrings`/`.strings` anywhere under the app target; `FileImportView.swift:134`, `ImportProgressView.swift:124` (naive count interpolation), `LibraryView.swift:610-611` (raw kHz/bit strings), `:419` (`"\(artist) • \(album)"`)
- Validation status: Confirmed all four members (revalidated 2026-07-15)
- Validation evidence: cited lines

### Problem
There is no localization pipeline at all: every string is hardcoded English, counts bypass plural rules, technical values bypass locale formatting, and precomposed metadata strings can't be reordered for RTL locales.

### Likely Root Cause
Localization was never started.

### Recommended Implementation
Phase 1: create a String Catalog and migrate one feature (Settings) end-to-end as the pattern. Phase 2: plural rules for count strings. Phase 3: `Measurement`/`Number` formatters for technical values. Phase 4: composable localized formats for metadata strings. Phase 5: widget + accessibility strings. Keep the widget wire payload backward compatible.

### Implementation Boundaries
No copy rewrites beyond localization needs. Feature-by-feature; never a big-bang migration.

### Acceptance Criteria
- [x] Focused double-length and forced-RTL builds render correctly for the supported private-app configuration
- [x] Plural/number tests pass in ≥2 locales
- [x] No regression in accessibility labels in the focused covered surfaces

### Suggested Verification
Pseudolocale scheme run per phase; snapshot matrix.

### Notes
Ledger M-24. The implementation was phased by catalog, plurals, formatters, composition, and focused widget/accessibility strings.

Owner disposition (2026-08-01): Comprehensive localization and accessibility matrices are not required for this private, single-user app. The existing focused automated and visual coverage is accepted as sufficient for the supported configuration; this disposition does not claim exhaustive app-wide, locale, appearance, or VoiceOver coverage.

### Implementation Record
- Started: 2026-07-28
- Completed: 2026-08-01
- Commit: Not requested
- Verification result: DONE BY OWNER-ACCEPTED SCOPE — the app/widget catalogs currently contain 292/20 keys, and the English/French plural, number/unit, accessibility-value, and bidirectional metadata formatter suite passed 4/4. A fresh iOS 27 iPhone 17e AX5 double-length/forced-RTL lane initially exposed narrow Home quick actions, crowded tab labels, and a truncated Settings title; accessibility-size actions now stack, tabs use icon-only presentation with retained localized semantic labels, and Settings uses an inline title. The final focused lane passed 1/1 with eight retained screenshots; it also asserts semantic labels for all four double-length tabs and 44-point hittable Shuffle All/Surprise Me targets. Search, Settings descendants, import states, complete Now Playing surfaces, widget families, full VoiceOver order, and light/dark exhaustive reachability were not exhaustively verified and are not required for the supported private-app configuration.
