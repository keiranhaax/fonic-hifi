# UI/UX, State Ownership & Accessibility — AUDIT-036 … AUDIT-043

## AUDIT-036 — Fix the app-wide observation boundary for the audio facade

- Status: [TODO]
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
- [ ] Focused invalidation test: track/artwork/error/import changes update consumers
- [ ] External changes (widget/App Intent/remote) update Now Playing and mini player
- [ ] No view retains a stale copy of facade state after migration
- [ ] Build + facade suites green; in-flight banner work preserved

### Suggested Verification
Invalidation tests; SwiftUI Cause & Effect instrumentation; device playback/interruption/restore smoke.

### Risks and Regression Areas
Every audio-consuming screen. Migrate slice-by-slice with checkpoints; WP4 flagged this approval-required.

### Notes
Ledger M-11. The single highest-leverage UI task: AUDIT-037/038 and half of AUDIT-021 are wasted effort without it.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-037 — Make Now Playing/mini-player state authoritative; gate visibility; add dismissal and accessory adaptation

- Status: [TODO]
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
- [ ] External/remote changes to shuffle/repeat/speed reflect immediately in Now Playing (test)
- [ ] Mini player hidden with no track; appears on first load
- [ ] Visible, accessible dismissal control (44 pt, labeled)
- [ ] Accessory renders correctly in both placements

### Suggested Verification
State-coherence tests; UI smoke portrait/landscape; VoiceOver pass on new control.

### Notes
Ledger M-13.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-038 — Surface remaining silent failures and observe import progress

- Status: [TODO]
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
- [ ] Failure injection on each surface produces visible, recoverable state
- [ ] Empty vs error visually and accessibly distinct
- [ ] Import progress renders live during an import; completion errors listed
- [ ] No presentation race (deterministic sheet trigger)

### Suggested Verification
Per-surface failure-injection tests; manual import of a mixed-validity batch.

### Notes
Ledger M-12.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-039 — Wire genre pill destinations

- Status: [TODO]
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
- Affected files or symbols: `GenresSection.swift:22-23,35-40` (`GenrePillView` inert)
- Validation status: Partially fixed — album/artist cards now navigate (commits `98f4263…`); genre pills remain inert (2026-07-15)
- Validation evidence: cited lines

### Problem
Genre pills look tappable but do nothing — the last remaining dead browse affordance.

### Likely Root Cause
Destination screen/filter was never wired.

### Recommended Implementation
Make pills semantic buttons navigating to a genre-filtered library/track list (reuse existing library filtering; no new design).

### Implementation Boundaries
No new navigation patterns; follow the album/artist card wiring just landed.

### Acceptance Criteria
- [ ] Tapping a genre shows that genre's tracks
- [ ] Pills are buttons with labels (VoiceOver activatable)

### Suggested Verification
UI test activating a pill by label; navigation postcondition.

### Notes
Ledger M-10 residue.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-040 — Adaptive Now Playing layout and non-color state differentiation

- Status: [TODO]
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
- [ ] No clipped/overlapping controls at AX5, smallest iPhone, landscape (screenshot matrix)
- [ ] Shuffle/repeat states distinguishable without color/opacity alone
- [ ] Reduce Motion/Transparency still honored

### Suggested Verification
Screenshot matrix (light/dark × sizes); accessibility audit tooling.

### Notes
Ledger M-13/X-08 visual slice.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

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
- [ ] One persistence request per logical mutation (test)
- [ ] MainActor performs no file stat/encode/write for queue persistence (trace)
- [ ] Force-quit restore unchanged
- [ ] Before/after trace at queue scale recorded

### Suggested Verification
Characterization tests → refactor → Time Profiler/File Activity on device at 1k-track queue.

### Notes
Ledger H-08 (profile-first mandate).

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

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
- [ ] Temp-directory tests: list/sort/search/root-bound, create/copy collision, failure and cancellation surfacing typed state
- [ ] No long UI-thread file operation (trace)
- [ ] Behavior parity for existing flows

### Suggested Verification
New unit tests with temp dirs; manual copy/delete flows; trace check.

### Notes
Ledger H-11.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-043 — Localization program: String Catalog, plurals, formatters, composable strings

- Status: [TODO]
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
- [ ] Pseudolocalized and RTL builds render correctly for migrated features
- [ ] Plural/number tests pass in ≥2 locales
- [ ] No regression in accessibility labels

### Suggested Verification
Pseudolocale scheme run per phase; snapshot matrix.

### Notes
Ledger M-24. Explicitly a phased program — decompose per phase at implementation time.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:
