# Foundation Models / AI — AUDIT-044 … AUDIT-047

## AUDIT-044 — Validate generated track IDs against the offered set; add untrusted-data prompt boundaries

- Status: [DONE]
- Priority: P1
- Audit sources: WP1 (FMA-002, FMA-006)
- Audit finding IDs: FMA-002, FMA-006
- Category: AI safety / correctness
- Severity: Medium
- Difficulty: Easy
- Risk: Low
- Scope: Multi-file
- Estimated effort: S
- Implementation group: GROUP-08
- Depends on: —
- Blocks: AUDIT-047 (the test matrix locks in this behavior)
- Related tasks: AUDIT-045, AUDIT-047
- Affected features: recommendations, Smart Search
- Affected files or symbols: `GeneratedTrackIDValidator`, `AIUntrustedData`, `RecommendationService.validated`, `SmartSearchService.validated`, `SmartSearchService.makePrompt`
- Validation status: Completed (2026-07-20)
- Validation evidence: focused hostile-output and prompt-boundary tests; complete unit target; Debug simulator build

### Problem
Guided output is trusted: generated UUIDs are not checked against the candidate set (out-of-set IDs flow onward), and untrusted user/library text is interpolated directly into prompts — both violate the repo's AI invariants.

### Likely Root Cause
Guided-generation schema conformance was treated as validation; prompt assembly predates the untrusted-data rules.

### Recommended Implementation
After generation: intersect IDs with the offered candidate set, deduplicate, enforce result limits, and re-fetch authoritative tracks before any playback/persistence. In prompts: delimit user queries and library metadata as data (explicit "treat as data, not instructions" framing), keeping role instructions separate.

### Implementation Boundaries
On-device only; no schema or session-lifecycle changes here. Deterministic fallback untouched.

### Acceptance Criteria
- [x] Out-of-set, duplicate, and over-limit IDs are rejected/trimmed (tests with stubbed output)
- [x] Prompts structurally separate instructions from data (snapshot test)
- [x] Malicious metadata (e.g. a title containing instructions) does not alter behavior (test)

### Suggested Verification
Unit tests with malformed/hostile stub outputs; existing AI suite.

### Risks and Regression Areas
Legitimate results must not be over-filtered — validate against the candidate set actually offered per request, not a global track set.

### Notes
AGENTS.md Foundation Models rules make this mandatory, not optional hardening.

### Implementation Record
- Started: 2026-07-20
- Completed: 2026-07-20
- Commit: This commit (`fix(ai): enforce model trust boundaries`)
- Verification result: Generated recommendation and search IDs are now parsed, intersected with the per-request offered set, deduplicated in model order, and capped at 5/7/15 before callers re-fetch authoritative `Track` values. Query, listening, and library text is escaped inside explicit untrusted-data sections while role rules remain in session instructions. Focused AI suites passed 10/10; full `Fonic HiFiTests` passed 456/456; the Debug iPhone 17 Pro simulator build succeeded; SwiftLint reported 0 violations in 289 files; repository-wide `git diff --check` passed. SwiftFormat 0.62.1 passes the new trust-boundary file; the four existing service/test files retain their pre-existing whole-file formatting findings, with no formatter-proposed changes in the new validation or prompt code.

## AUDIT-045 — Distinguish cancellation from failure; hand off to standard search on fallback

- Status: [TODO]
- Priority: P1
- Audit sources: WP1 (FMA-003, FMA-005), Model B (UIUX-011 context)
- Audit finding IDs: FMA-003, FMA-005
- Category: AI correctness / UX
- Severity: Medium
- Difficulty: Moderate
- Risk: Medium
- Scope: Multi-file
- Estimated effort: M
- Implementation group: GROUP-08
- Depends on: —
- Related tasks: AUDIT-038, AUDIT-044
- Affected features: Smart Search
- Affected files or symbols: `SmartSearchService.swift:97-109` (generic catch converts cancellation into fallback results), `:115-140` (fallback returns empty AI result; no handoff), `SmartSearchViewModel.swift:88-106` (applies any completed result without request identity), `SearchView.swift:62-64,171-176` (smart mode shows NoResultsView)
- Validation status: Confirmed both (revalidated 2026-07-15)
- Validation evidence: cited lines

### Problem
A cancelled smart search can materialize as a stale fallback result overwriting newer state, and the "standard search fallback" actually renders an empty AI result instead of running standard search — users get nothing where results exist.

### Likely Root Cause
CancellationError not rethrown; fallback designed as a placeholder.

### Recommended Implementation
Rethrow/propagate cancellation (never convert to results); add request identity/generation in the view model so only the latest request commits; on model unavailability/failure, hand off to the deterministic standard search pipeline and label the results accordingly.

### Implementation Boundaries
Add an explicit single-request gate around each shared `LanguageModelSession` (or use an independent session per request); the current services cache sessions without serialization. Deterministic fallback must never block normal search (AGENTS.md).

### Acceptance Criteria
- [ ] Cancelled generation commits no state (test)
- [ ] Stale completion cannot overwrite a newer query's results (race test)
- [ ] Fallback path returns actual standard-search results (test)

### Suggested Verification
Async view-model tests with controlled generation stubs; UI check of fallback labeling.

### Risks and Regression Areas
Search debounce/cancellation flow in `SmartSearchViewModel`; ensure fallback handoff cannot double-run standard search alongside a late AI completion.

### Notes
FMA-005 was previously masked by unreachable smart search (UIUX-011) — now reachable, so this defect is user-visible. Apple documents that a `LanguageModelSession` handles one request at a time and errors on a concurrent request: `https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models`.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-046 — Decouple initial Home rendering from the model response

- Status: [TODO]
- Priority: P2
- Audit sources: WP1 (FMA-008)
- Audit finding IDs: FMA-008
- Category: Performance / UX
- Severity: Medium
- Difficulty: Moderate
- Risk: Low
- Scope: Localized
- Estimated effort: S
- Implementation group: GROUP-08
- Depends on: —
- Related tasks: AUDIT-038, AUDIT-054
- Affected features: Home first paint
- Affected files or symbols: `HomeView.swift:62-75,231-250` (whole Home held behind `isLoading` until `generateTimeBasedGreeting` completes)
- Validation status: Confirmed (revalidated 2026-07-15)
- Validation evidence: cited lines

### Problem
Home's entire content — including non-AI sections — waits for greeting generation or its deterministic fallback before first paint; generation latency can therefore stall the home screen, while the unavailable-model path currently returns a fallback.

### Likely Root Cause
Single loading flag spanning AI and non-AI content.

### Recommended Implementation
Render library-backed sections immediately; stream the greeting/recommendations into their sections when ready with a placeholder meanwhile; respect the availability check before dispatching model work.

### Implementation Boundaries
No recommendation-logic changes. Deterministic content must never wait on the model.

### Acceptance Criteria
- [ ] Home renders non-AI sections without awaiting the model (test with a never-completing stub)
- [ ] AI sections appear when ready; unavailable state renders fallback

### Suggested Verification
Stubbed-latency test; visual check on a Model-unavailable configuration.

### Risks and Regression Areas
Home loading-state transitions and any code that keyed off the single `isLoading` flag.

### Notes
Also removes a hidden dependency of app startup on model availability.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-047 — Build the Foundation Models failure-matrix test suite

- Status: [TODO]
- Priority: P2
- Audit sources: WP1 (FMA-007)
- Audit finding IDs: FMA-007
- Category: Testing
- Severity: Medium
- Difficulty: Moderate
- Risk: Low
- Scope: Multi-file (tests)
- Estimated effort: M
- Implementation group: GROUP-08
- Depends on: AUDIT-044, AUDIT-045 (tests lock in their behavior)
- Related tasks: AUDIT-050
- Affected features: AI test coverage
- Affected files or symbols: `Fonic HiFiTests/Core/AI/RecommendationServiceTests.swift:9-42`, `SmartSearchServiceTests.swift:9-42`, `Integration/AIRecommendationsIntegrationTests.swift:9-35` (fallback-only, vacuous availability assertions)
- Validation status: Confirmed (revalidated 2026-07-15)
- Validation evidence: cited lines — no injected live-model response/error matrix exists

### Problem
AI tests exercise only fallbacks with vacuous assertions; the generation path, its failure matrix, and hostile-output handling are untested.

### Likely Root Cause
No injection seam for the session/generation layer.

### Recommended Implementation
Introduce a narrow generation-provider seam (protocol around session use) plus an explicit single-request gate for each shared session; test matrix: unavailable, generation error, malformed output, duplicate/out-of-set IDs, over-limit, cancellation mid-generation, locale failure; plus one guarded on-device supported-path test (skipped with explicit reason elsewhere, per repo skip policy).

### Implementation Boundaries
Test seams must not weaken production isolation. Simulator success is not Apple Intelligence hardware proof — record that limit.

### Acceptance Criteria
- [ ] Every matrix case has a deterministic test (red-first where fixing behavior)
- [ ] Vacuous assertions replaced
- [ ] Supported-device path validated on eligible hardware (or explicitly recorded UNVERIFIED → AUDIT-055)

### Suggested Verification
New suite runs deterministically in CI; eligible-device run recorded.

### Risks and Regression Areas
The injection seam touches production service initializers — defaults must preserve current behavior and isolation.

### Notes
AGENTS.md requires exactly this matrix for AI features. Follow AUDIT-050's clock/skip conventions.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:
