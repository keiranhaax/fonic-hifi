# Library Data Layer — AUDIT-017 … AUDIT-019

## AUDIT-017 — Repository correctness: cheap counts, no N+1 mapping, search via repository, refresh after writes

- Status: [DONE]
- Priority: P1
- Audit sources: Model B (DLP-011, DLP-012, DLP-013, DLP-014, CP-014)
- Audit finding IDs: CAN-011 (residual), DLP-011, DLP-013, DLP-014 (residual)
- Category: Data / performance
- Severity: Medium
- Difficulty: Hard
- Risk: Medium
- Scope: Multi-file
- Estimated effort: L
- Implementation group: GROUP-09
- Depends on: —
- Blocks: —
- Related tasks: AUDIT-018, AUDIT-054 (profiling)
- Affected features: library browsing, search
- Affected files or symbols: `SwiftDataLibraryRepository.swift:43-48,72-77,104-110` (count on every page; per-row to-many dereference), `SwiftDataPagination.swift:67-78` (count by hydrating all matches in 512-row batches), `DataManager+Search.swift:37-54` (bypasses repository, `fetchLimit = 100` silent truncation), `LibraryImportService.swift:246-250` + `LibraryView.swift:350-352` (writes invalidate statistics only, not page state)
- Validation status: Partially fixed — pagination no longer hydrates everything per page, but count still hydrates all matches batchwise; legacy search path and refresh gap confirmed (2026-07-15)
- Validation evidence: cited lines

### Problem
Library pages still pay a full-hydration count cost per request, album/artist rows dereference to-many relationships per row, one search path bypasses the repository and silently truncates, and completed imports don't refresh repository-backed views.

### Likely Root Cause
Repository layer evolved incrementally; count/mapping/search/invalidation contracts were never unified.

### Recommended Implementation
Use `fetchCount`-style cheap counts (or drop unused totals); precompute row counts in the query or cache them instead of touching relationships per row; route all search through the repository with explicit paging (no hidden truncation); introduce a library revision/invalidation signal so writes refresh visible pages once.

### Implementation Boundaries
Preserve SwiftData query semantics and schema. Keep view-model changes minimal — request-ownership redesign is AUDIT-018.

### Acceptance Criteria
- [x] Page fetch performs no full-result hydration for counts (verified via fetch instrumentation or fetchCount assertion)
- [x] 10k-track on-disk fixture: album/artist pages return correct counts without per-row relationship faults
- [x] Search results are complete (or explicitly paged), never silently truncated
- [x] Import completion refreshes visible library state exactly once

### Suggested Verification
Repository unit tests against an on-disk fixture store; performance comparison at 10k tracks (with AUDIT-051 benchmarks).

### Risks and Regression Areas
Query-plan changes can alter ordering/paging; lock with characterization tests first.

### Notes
Ledger H-10/H-12 (data slices).

### Implementation Record
- Started: 2026-07-26
- Completed: 2026-07-26
- Commit: Not requested
- Verification result: Repository pages now use store-side counts, prefetch relationship counts, expose explicit paging without a hidden standard-search cap, and refresh through the library revision signal. The selected repository/library validation lane passed, including the 10k-track fixture; the assembled simulator build succeeded.

## AUDIT-018 — Give each Library section explicit request ownership and load phases

- Status: [DONE]
- Priority: P1
- Audit sources: WP4-R03
- Audit finding IDs: WP4-R03
- Category: UI state / concurrency
- Severity: Medium
- Difficulty: Moderate
- Risk: Medium
- Scope: Multi-file
- Estimated effort: M
- Implementation group: GROUP-09
- Depends on: — (sequence with AUDIT-017; same layer)
- Blocks: —
- Related tasks: AUDIT-017, AUDIT-036
- Affected features: library loading, pagination
- Affected files or symbols: `LibraryViewModel.swift:33-44,66-79,98-188`, `LibraryView.swift:140-177,195-310,336-369`, `LibraryViewModelTests.swift`
- Validation status: Confirmed static (WP4 evidence at cited lines; structure unchanged 2026-07-15)
- Validation evidence: WP4-R03 evidence list

### Problem
Library sections share loading state without per-section request ownership: out-of-order completions can commit stale results, duplicate threshold triggers double-load, and initial load is not modeled separately from pagination.

### Likely Root Cause
Single view model grew four sections without request generations.

### Recommended Implementation
Per WP4-R03: store a per-section request task or generation, set stored loading state before suspension, reject stale responses, cancel on tab/query change, and model initial-load vs pagination phases distinctly.

### Implementation Boundaries
Preserve tabs, page size, prefetch threshold, item identity, import/create actions, error text, and visual layout. No repository query changes (AUDIT-017 owns those).

### Acceptance Criteria
- [x] Out-of-order completion cannot overwrite newer results (async test)
- [x] Duplicate threshold trigger issues one request
- [x] Tab/query change cancels in-flight requests
- [x] Initial-load vs pagination present distinct UI states

### Suggested Verification
Executable async view-model tests; UI smoke on Library tabs.

### Risks and Regression Areas
Loading indicators and empty-state logic; lock with tests before refactor.

### Notes
WP4 requires approval before implementation — treat this task's landing as that approval checkpoint.

### Implementation Record
- Started: 2026-07-26
- Completed: 2026-07-26
- Commit: Not requested
- Verification result: Each Library section now owns its request generation, task, and initial/pagination phase; duplicate pagination is suppressed and revision changes refresh visible data. Deterministic request-ownership tests passed in the selected library lane; the assembled simulator build succeeded.

## AUDIT-019 — Complete the playlist mutation path

- Status: [DONE]
- Priority: P2
- Audit sources: Model B (DLP-010)
- Audit finding IDs: DLP-010
- Category: Feature completion
- Severity: Medium
- Difficulty: Moderate
- Risk: Medium
- Scope: Multi-file
- Estimated effort: M
- Implementation group: —
- Depends on: —
- Blocks: —
- Related tasks: AUDIT-017 (refresh-after-write applies to playlists too)
- Affected features: playlists
- Affected files or symbols: `PlaylistListView.swift:507-515` (insert-then-dismiss without explicit save); model-level add/remove/move helpers exist but no complete persisted UI flow
- Validation status: Partially fixed — creation and model helpers exist; end-to-end persisted add/remove/reorder from UI remains incomplete (2026-07-15)
- Validation evidence: cited lines

### Problem
The UI exposes playlists but the mutation path is not complete end-to-end: users can create playlists whose contents can't be reliably managed and persisted.

### Likely Root Cause
Feature landed in stages; UI wiring to the repository/model helpers was never finished.

### Recommended Implementation
Route playlist create/add/remove/reorder through `TrackDataActor`/repository (views must not be persistence authorities), ensure explicit save boundaries, and refresh playlist views after writes.

### Implementation Boundaries
No schema change expected (verify relationships exist). Preserve current UI design.

### Acceptance Criteria
- [x] Add/remove/reorder survive app relaunch (on-disk test)
- [x] Mutations go through the model-actor/repository boundary
- [x] Views refresh once after each write

### Suggested Verification
Repository/actor tests + UI flow test creating and editing a playlist.

### Risks and Regression Areas
Relationship delete rules; verify no cascade deletes tracks.

### Notes
Ledger H-10 slice.

### Implementation Record
- Started: 2026-07-26
- Completed: 2026-07-26
- Commit: Not requested
- Verification result: Playlist create/add/remove/reorder now run through the model actor, the editor refreshes after successful writes, and an on-disk test verifies persistence across container reopen. The selected playlist tests passed and the integrated Library UI compiled in the simulator build.
