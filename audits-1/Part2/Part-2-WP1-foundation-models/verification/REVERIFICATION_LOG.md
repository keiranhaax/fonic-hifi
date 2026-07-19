# Independent WP1 evidence re-verification log

Lead re-verification was performed after drafting, against the repository at commit `459db9bfd18d17960e8fd2ff8defc4701085532e` and the current Apple/Swift sources listed in `evidence/APPLE_SOURCES.md`.

Automated source-predicate result: PASS, 0 failures. Captured output: `evidence-reverification.json`.

## Finding decisions

### FMA-001

- Decision: retain at Medium.
- Verified: one cached recommendation session; Surprise Me remains enabled; repeated taps create tasks; no `isResponding` gate.
- Severity guardrail: not raised to High because the exact iOS 26 outcome of a second `respond` call was not run. Apple documents a runtime error, but this environment cannot establish catchable error versus process failure.
- Related prior record: UIUX-019 remains separate pending Work Package 2 deduplication.

### FMA-002

- Decision: retain at Medium.
- Verified: all four generated ID arrays use string UUIDs and `compactMap`; no allowed-set, uniqueness, or minimum-count validation exists; downstream fetch silently drops unresolved IDs.
- False-positive check: `@Generable` guarantees structure, not membership in the request’s runtime ID set. The finding does not claim malformed JSON.

### FMA-003

- Decision: retain at Medium.
- Verified: SearchView cancels the previous task; the service converts generic errors to fallback; no post-generation cancellation or request-identity check protects state writes.
- Reachability qualifier: current Smart Search UI reachability is reduced by UIUX-011. The defect remains in the integration and becomes active when that prior UI issue is fixed.

### FMA-004

- Decision: retain at Medium.
- Verified: both availability APIs discard the unavailable reason; no locale preflight exists; SmartSearchViewModel defines an error state that SearchView never renders; model errors are converted to generic fallback.
- False-positive check: deterministic fallback itself is good. The defect is loss of reason and incorrect UI/state semantics, not the existence of fallback.

### FMA-005

- Decision: retain at Medium with explicit UIUX-011 bound.
- Verified: fallback promises standard search, returns zero IDs, ViewModel maps it to no-results, and no handoff calls the existing standard search.
- Deduplication guardrail: no merge performed in WP1. Work Package 2 owns formal merging.

### FMA-006

- Decision: retain at Low.
- Verified: query and imported metadata are interpolated directly; generated strategy/reasons reach UI; no model tool, URLSession, HTTP literal, or remote fallback exists in the direct AI code.
- Severity guardrail: kept Low because the reviewed prompt-injection path has no side-effect or exfiltration capability and remains on-device.

### FMA-007

- Decision: retain at Medium.
- Verified: two tautological availability tests; integration tests construct production services; no injectable model/session dependency; no deterministic error/cancellation/output-validation matrix.
- Limitation: no test target was executed because Xcode and Apple SDKs are unavailable.

### FMA-008

- Decision: retain at Medium.
- Verified: Home renders a blocking ProgressView while `isLoading`; the state is cleared only after awaiting the optional generated greeting and fetching its tracks.
- False-positive correction: the report does not claim `@MainActor` makes inference run synchronously on the main thread. The confirmed issue is the UI state dependency.

## Prior-related disposition check

- UIUX-009: Foundation Models slice retained; no duplicate count.
- UIUX-011: retained and used as a reachability qualifier.
- UIUX-019: retained; adds the UI/action half of FMA-001.
- DCA-PART-004: retained but outside Foundation Models remediation.
- PSR-006: on-device intelligence disclosure slice retained; no off-device model path found.

## Rejected candidates rechecked

Seven rejected candidates remain rejected: server upload, active tool exfiltration, asserted main-thread blocking, malformed-JSON framing, deployment-target mismatch, mandatory-streaming framing, and acceptable-use violation.

## Sub-agent correction log

The single delegated scan returned no finding or evidence. Its complete output was rejected and none of it appears in the report. There was no sub-agent factual claim to correct; the absence itself is recorded in `checkpoints/01_delegation_checkpoint.md`.

## Final pre-package decision

- Critical retained: 0
- High retained: 0
- Medium retained: 7
- Low retained: 1
- Downgrades during lead re-verification: 0
- Rejections during lead re-verification: 0 additional
- Repository changes: 0
