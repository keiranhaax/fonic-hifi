# Current Repository Audit Follow-ups — AUDIT-057 … AUDIT-066

These tasks were added after the repository-wide read-only audit completed on 2026-07-18 against `4fab020` and the live dirty worktree. They supplement the normalized Part 1/Part 2 backlog; they do not renumber or duplicate existing findings. Existing tasks remain authoritative where a follow-up is already covered.

## AUDIT-057 — Temporarily retire GitHub Actions CI

- Status: [DONE]
- Priority: P1
- Audit sources: 2026-07-18 current-tree audit; owner decision on 2026-07-18
- Category: CI / repository configuration
- Severity: Medium
- Difficulty: Trivial
- Risk: Low
- Scope: Localized
- Estimated effort: XS
- Implementation group: GROUP-13
- Depends on: —
- Blocks: AUDIT-005 until hosted CI is intentionally reintroduced
- Related tasks: AUDIT-005, AUDIT-055
- Affected files or symbols: `.github/workflows/ci.yml`, `AGENTS.md`, active audit-ledger references

### Problem

The workflow targets an unsupported or unavailable Xcode 27 beta runner contract and has not produced reliable evidence. Keeping it active creates repeated failures without adding a trustworthy release gate.

### Approved Implementation

Delete the workflow until further notice, preserve the Makefile's local build/test contract, and update active documentation so it does not claim CI is configured. Reintroducing CI is a separate owner-approved task after a suitable Xcode 27 runner exists.

### Acceptance Criteria

- [x] `.github/workflows/ci.yml` is absent
- [x] Active repository instructions state that hosted CI is intentionally disabled
- [x] `Makefile` local build, lint, and test recipes are unchanged by this task
- [x] AUDIT-005 is blocked on an explicit CI-reintroduction decision

### Suggested Verification

`test ! -e .github/workflows/ci.yml`; two independent searches for active-workflow claims; `git diff --check`; compare the Makefile hash with the pre-cleanup baseline.

### Implementation Record

- Started: 2026-07-18
- Completed: 2026-07-18
- Commit: `b15f330`
- Verification result: MATCH — workflow absent by filesystem and workflow-directory probes; active instructions record intentional retirement; AUDIT-005 is blocked; scoped diff check passed

## AUDIT-058 — Preserve the local agent contract across the malformed upstream rewrite

- Status: [DONE]
- Priority: P1
- Audit sources: 2026-07-18 Git/upstream audit; owner decision on 2026-07-18
- Category: Repository instructions
- Severity: High
- Difficulty: Easy
- Risk: Medium
- Scope: Localized
- Estimated effort: S
- Implementation group: GROUP-13
- Depends on: —
- Blocks: blind pull/merge of upstream `2cb2ec8`
- Related tasks: AUDIT-056
- Affected files or symbols: `AGENTS.md`, nested `AGENTS.md` files, upstream-only commit `2cb2ec8`

### Problem

The local guide contains the current privacy, dirty-worktree, architecture, and verification contract. The upstream-only rewrite is truncated after seven logical lines and ends mid-sentence, so applying it wholesale would remove safety-critical guidance.

### Approved Implementation

Preserve the local guide and nested specializations. Change only statements made stale by the approved CI retirement. Do not pull, merge, restore, or replace the file from the upstream revision during cleanup.

### Acceptance Criteria

- [x] The local privacy, data-safety, dirty-worktree, build, and nested-guide contracts remain present
- [x] CI wording matches the intentionally disabled workflow state
- [x] No pull, merge, branch switch, stage, unstage, or history operation occurs

### Suggested Verification

Re-read `AGENTS.md`; compare its required section headings with the pre-cleanup copy; verify branch, HEAD, upstream divergence, and staged-diff checksum are unchanged.

### Implementation Record

- Started: 2026-07-18
- Completed: 2026-07-18
- Commit: `3ed799c`
- Verification result: MATCH — nine project guides remain; all seven required root sections remain; branch `main`, HEAD `4fab020`, upstream divergence `0 1`, and staged-diff checksum are unchanged

## AUDIT-059 — Retain the audit corpus and project references as intentional evidence

- Status: [DONE]
- Priority: P2
- Audit sources: 2026-07-18 repository audit; owner classification on 2026-07-18
- Category: Documentation / repository hygiene
- Severity: Low
- Difficulty: Easy
- Risk: Low
- Scope: Documentation
- Estimated effort: XS
- Implementation group: GROUP-13
- Depends on: —
- Blocks: —
- Related tasks: AUDIT-053
- Affected files or symbols: `audits-1/Part1/`, `audits-1/Part2/`, `docs/references/`, `audits-1/tasks/00-README.md`

### Problem

The source audit packages and project references are untracked, so their intended status is ambiguous even though the normalized task ledger cites them as evidence.

### Approved Implementation

Classify these paths as durable reference material, keep them outside production targets, keep them unignored, and document their role. Git staging and committing remain owner-controlled follow-up actions.

### Acceptance Criteria

- [x] All three reference roots exist and remain unignored
- [x] The task README identifies Part 1 and Part 2 as source evidence and `docs/references/` as project guidance
- [x] No reference file is edited as production source

### Suggested Verification

List each root, count its files, run `git check-ignore --no-index` probes, and validate every README path.

### Implementation Record

- Started: 2026-07-18
- Completed: 2026-07-18
- Commit: `09943b4`
- Verification result: MATCH — the three roots contain 109 files in aggregate, all exist and remain unignored, and the tracker README identifies their reference role

## AUDIT-060 — Ignore local test-song media

- Status: [DONE]
- Priority: P1
- Audit sources: 2026-07-18 repository audit; owner classification on 2026-07-18
- Category: Privacy / repository hygiene
- Severity: High
- Difficulty: Trivial
- Risk: Low
- Scope: Localized
- Estimated effort: XS
- Implementation group: GROUP-13
- Depends on: —
- Blocks: —
- Related tasks: AUDIT-051
- Affected files or symbols: `.gitignore`, `music-file/`

### Problem

The repository-local test-song folder contains user-provided audio files and is currently visible as untracked content. Accidental staging would create a privacy and repository-size incident.

### Approved Implementation

Add a root-scoped `/music-file/` ignore rule. Preserve every local song file; do not inspect filenames or contents, move media, or use it as a committed fixture.

### Acceptance Criteria

- [x] `/music-file/` is ignored by a documented root-scoped rule
- [x] The directory and its existing files remain on disk
- [x] No media filename or content is copied into source, logs, tasks, or reports

### Suggested Verification

Record only aggregate file count and size before/after; run `git check-ignore --no-index -v music-file/.audit-probe`; ensure `git status --short` does not enumerate the directory.

### Implementation Record

- Started: 2026-07-18
- Completed: 2026-07-18
- Commit: `b15f330`
- Verification result: MATCH — three files and 97,996 KiB remained on disk; the root-scoped ignore rule matched; normal status no longer enumerates the media directory

## AUDIT-061 — Review historical MCP credentials and choose provider-side action

- Status: [BLOCKED]
- Priority: P0
- Audit sources: CAN-001, AUDIT-001 residual risk, 2026-07-18 history audit
- Category: Security / external coordination
- Severity: High
- Difficulty: Easy
- Risk: High (credentials and history)
- Scope: External owner action plus optional repository-history action
- Estimated effort: S
- Implementation group: —
- Depends on: account owner identifying whether the credentials were ever active
- Blocks: any claim that historical exposure is fully remediated
- Related tasks: AUDIT-001
- Affected files or symbols: historical `.kilocode/mcp.json`, historical `.claude/settings.local.json`

### Problem

Historical configuration contains credential material associated with Brave Search, Exa, Apple RAG, and an Omnisearch MCP endpoint. Current validity and account ownership are unknown. Deleting the worktree files does not revoke provider credentials or remove Git objects.

### Required Owner Decision

Determine whether each provider account was used and whether its credential is still active. If active or uncertain, revoke or rotate it provider-side. Decide separately whether a coordinated Git-history rewrite is warranted.

### Implementation Boundaries

Never record credential values, endpoints, or authentication headers in tasks or command output. Do not contact providers, change credentials, or rewrite history without a separate explicit authorization and coordination plan.

### Acceptance Criteria

- [ ] Each provider credential has an owner-recorded disposition: revoked, rotated, confirmed inactive, or unknown
- [ ] Any history-cleanup decision names affected remotes/collaborators and recovery steps
- [ ] No secret value appears in repository documentation or cleanup output

### Suggested Verification

Provider dashboards or support records supplied by the owner; secret-pattern and history scans that report only path/count/category, never values.

## AUDIT-062 — Make facade initialization and shutdown mutually safe

- Status: [TODO]
- Priority: P1
- Audit sources: 2026-07-18 current-diff concurrency audit
- Category: Audio lifecycle / concurrency
- Severity: Medium
- Difficulty: Moderate
- Risk: Medium
- Scope: Localized behavior plus focused tests
- Estimated effort: M
- Implementation group: GROUP-05
- Depends on: preserve the in-flight initialization-serialization work
- Blocks: relying on `AudioEngineFacade.shutdown()` as a complete teardown boundary
- Related tasks: AUDIT-030, AUDIT-031
- Affected files or symbols: `AudioEngineFacade.initialize()`, `performInitialization()`, `shutdown()`; `AudioEngineFacadeOrchestratorTests`

### Problem

The current worktree creates a shared initialization task, but shutdown clears its property without cancelling or awaiting the task. Main-actor reentrancy permits initialization to resume after teardown and restore ready/initialized state or services.

### Recommended Implementation

Define one lifecycle state machine for initialize versus shutdown, cancel and await owned work without self-awaiting, and guard every post-suspension state mutation against shutdown or supersession. Preserve concurrent-caller serialization.

### Acceptance Criteria

- [ ] Shutdown cannot return while an earlier initialization can still mutate facade state
- [ ] Concurrent initialization callers still share one attempt
- [ ] Initialization failure remains retryable
- [ ] Focused tests exercise initialize/initialize, initialize/shutdown, failure/retry, and cancellation interleavings

### Suggested Verification

Focused lifecycle tests under strict concurrency, then the complete unit target and isolated simulator build.

## AUDIT-063 — Establish nonisolated boundaries for audio callbacks

- Status: [TODO]
- Priority: P0
- Audit sources: 2026-07-18 current-tree concurrency audit
- Category: Audio / Swift concurrency
- Severity: High
- Difficulty: Hard
- Risk: High
- Scope: Multi-file behavioral change
- Estimated effort: L
- Implementation group: GROUP-05
- Depends on: AUDIT-031 session-ownership design
- Blocks: confidence in strict-concurrency runtime safety for completion, interruption, route, and remote-command callbacks
- Related tasks: AUDIT-030, AUDIT-031, AUDIT-032
- Affected files or symbols: `AVAudioEngineAdapter.swift:247,328,389`; `AudioSessionManager.swift:220-255,369-418`; `AudioMonitor.swift:408`

### Problem

Framework callbacks documented or permitted to arrive off-main are created inside main-actor-isolated services. Placing a main-actor `Task` inside the callback does not by itself prove that the outer closure can be entered without an isolation assertion; one completion callback also reads actor-isolated logger state before the hop.

### Recommended Implementation

Use an explicit nonisolated callback boundary that captures only sendable values, then perform one deliberate hop to the owning actor before accessing isolated state. Coordinate notification, remote-command, completion, and monitor bridges under the single session owner established by AUDIT-031.

### Acceptance Criteria

- [ ] Outer framework callbacks do not access main-actor state before the hop
- [ ] Completion, interruption, route-loss, remote-command, and monitor paths retain their behavior
- [ ] Race-oriented tests exercise callbacks from non-main executors
- [ ] No `nonisolated(unsafe)` or `@unchecked Sendable` bypass is introduced

### Suggested Verification

Focused callback tests, strict-concurrency build, Thread Sanitizer where supported, complete unit target, and physical-device interruption/route checks through AUDIT-055.

## AUDIT-064 — Make transient playback errors accessible and motion-aware

- Status: [TODO]
- Priority: P1
- Audit sources: 2026-07-18 current-diff accessibility audit
- Category: Accessibility / playback UX
- Severity: High
- Difficulty: Moderate
- Risk: Low
- Scope: Localized UI behavior plus tests
- Estimated effort: M
- Implementation group: GROUP-07
- Depends on: AUDIT-036 observation boundary; preserve the in-flight playback-error work
- Blocks: treating playback-error surfacing as complete
- Related tasks: AUDIT-038, AUDIT-040, AUDIT-055
- Affected files or symbols: `PlaybackErrorBanner.swift`; `AudioEngineFacade.reportPlaybackControlError`; error overlays in `ContentView.swift` and `NowPlayingContent.swift`

### Problem

The new error banner is visually transient, automatically clears after 2.5 seconds, has no explicit announcement or dismissal action, and animates even when Reduce Motion is enabled. VoiceOver users can miss a playback failure before focus reaches it.

### Recommended Implementation

Expose an assertive but non-duplicating accessibility announcement, provide a semantic dismissal path, gate transitions on Reduce Motion, and define a lifecycle that does not erase unread errors solely on a short timer.

### Acceptance Criteria

- [ ] A newly presented playback error is announced once with meaningful text
- [ ] The error can be dismissed semantically
- [ ] Reduced-motion mode avoids movement-based transitions
- [ ] Repeated/superseded errors have deterministic announcement and clearing behavior
- [ ] Visual and accessibility behavior is verified in both root and Now Playing presentations

### Suggested Verification

Focused state tests, UI tests for presentation/dismissal, simulator accessibility inspection, and a physical-device VoiceOver pass through AUDIT-055.

## AUDIT-065 — Complete explicit privacy annotations in release-reachable logging

- Status: [TODO]
- Priority: P1
- Audit sources: AUDIT-006 residual; 2026-07-18 privacy-policy scan
- Category: Privacy / diagnostics
- Severity: Medium
- Difficulty: Moderate
- Risk: Low
- Scope: Multi-file, independently batched
- Estimated effort: M
- Implementation group: —
- Depends on: preserve the verified content-bearing `.public` removals from AUDIT-006
- Blocks: claiming full compliance with the repository's explicit-interpolation privacy policy
- Related tasks: AUDIT-006, AUDIT-007
- Affected files or symbols: release-reachable `Logger` interpolations of errors, filenames, paths, identifiers, metadata, and route/device descriptions

### Problem

AUDIT-006 removed confirmed content-bearing `.public` annotations, but a broader current-tree scan found many interpolations—especially `error.localizedDescription`—without an explicit privacy annotation. OSLog's default `.auto` is not evidence of plaintext exposure, but it does not satisfy the repository's explicit annotation contract.

### Recommended Implementation

Re-scan the live tree and remediate by privacy class in small batches: free-form errors, file/path values, library identifiers/metadata, then route/device descriptions. Prefer structured error categories or privacy-safe helpers over copying user-derived descriptions.

### Acceptance Criteria

- [ ] Every release-reachable content-bearing interpolation has an explicit justified privacy classification
- [ ] User paths, filenames, metadata, prompts, lyrics, credentials, and bearer-like values never use `.public`
- [ ] Operational counts, booleans, durations, and fixed enum labels remain useful where public classification is justified
- [ ] Two independent static probes and focused tests verify each batch

### Suggested Verification

Privacy-pattern scans, SwiftLint, focused subsystem tests, complete unit target, and an isolated Debug build.

## AUDIT-066 — Burn down compiler and test-runtime warnings by evidence family

- Status: [TODO]
- Priority: P2
- Audit sources: 2026-07-18 isolated build and XCResult inspection
- Category: Build quality / tests
- Severity: Medium
- Difficulty: Moderate
- Risk: Medium
- Scope: Phased umbrella
- Estimated effort: L
- Implementation group: GROUP-10
- Depends on: stable Xcode 27 SDK and preserved in-flight work
- Blocks: a zero-warning build/test quality claim
- Related tasks: AUDIT-050, AUDIT-054
- Affected files or symbols: ignored throwing task in `AudioMonitorRuntime`; deprecated AVAudioSession/AVAsset/AudioKit APIs; missing `os` imports; test actor-isolation warnings; SwiftUI Query/model-context warnings; QoS priority inversions

### Problem

The isolated audit build succeeded with 51 warnings. Unit and UI XCResults passed but recorded runtime warnings, including QoS priority inversion and tests accessing SwiftUI query state without an installed model context. Treating all warnings as one refactor would mix unrelated risk.

Post-cleanup validation kept the same isolated DerivedData: the Debug build succeeded with 51 warnings; the unit target passed 447 tests with 72 reported warning instances; and the UI target passed 19 tests with three QoS priority-inversion runtime warnings.

### Recommended Implementation

Create one verified subtask per warning family: ownership of throwing tasks, iOS 27 API migrations, import hygiene, actor-isolated test lifecycle, SwiftUI test environment setup, and QoS inversion reproduction. Rebuild/retest after each family and record warning-count deltas.

### Acceptance Criteria

- [ ] Each warning family has a reproducible baseline and owner
- [ ] Fixes address root causes without suppressing compiler, concurrency, or runtime diagnostics
- [ ] Final build and XCResults report exact warning counts
- [ ] Device-only or third-party warnings remain explicitly attributed and unclaimed

### Suggested Verification

Fresh isolated Debug build, complete unit and UI targets, XCResult warning extraction, and focused runtime probes for any remaining QoS issue.
