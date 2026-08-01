# Fonic HiFi Audit Evidence Closure Plan

**Created:** 2026-07-29
**Status:** execution-ready plan; no remediation work performed by this document
**Authoritative backlog:** `audits-1/tasks/00-README.md`
**Planning baseline:** `main` at `1207bca20749cfc3a2ab62e7ea83bacf82680e44`, with the existing dirty worktree preserved
**Current ledger:** 66 tasks = 53 DONE + 8 TODO + 5 BLOCKED

## Objective

Close the remaining audit backlog by collecting the evidence that the implemented
slices still lack, fixing only defects that a recorded trace or reproduction
actually proves, and retaining explicit owner or hardware gates where the
repository cannot supply the answer.

This is primarily an evidence program:

- TODO: AUDIT-034, AUDIT-040, AUDIT-041, AUDIT-042, AUDIT-043, AUDIT-050,
  AUDIT-054, and AUDIT-066.
- BLOCKED: AUDIT-004, AUDIT-005, AUDIT-007, AUDIT-055, and AUDIT-061.
- No existing DONE task is reopened unless current evidence contradicts its
  recorded acceptance result.
- No release-ready, gapless, bit-perfect, device-support, or zero-runtime-warning
  claim is permitted while its corresponding gate remains open.

## Current verified baseline

The backlog records the following latest results. They are the starting point,
not a substitute for fresh evidence during execution:

| Check | Recorded result |
| --- | --- |
| App and widget build | 0 compiler warnings |
| Focused iOS 27 audio migration tests | 55 passed |
| Full unit target | 592 passed, 0 failed, 0 skipped, 4 QoS warning instances |
| Full UI target | 26 passed, 0 failed, 0 skipped, 4 QoS warning instances |
| SwiftLint | 0 violations across 316 files |
| Widget contract verifier | Passed |
| Whitespace validation | `git diff --check` passed |
| Simulator text size | Restored to `large` |
| Git | Nothing staged or committed |
| SwiftFormat | Outside the green claim; no repository-wide formatter run is authorized |

The eight QoS reports are warning instances across two XCResults. They must be
grouped by reproduced root cause before anyone treats them as eight distinct
defects.

The table uses the latest consolidated AUDIT-066 record. Earlier task records
show 590 unit tests and 23 UI tests because they were captured before later
coverage was added; those historical counts are progression evidence, not a
current count-drift failure.

## Constraints and non-goals

- Preserve all existing tracked and untracked work. Do not use blanket restore,
  reset, clean, stash, reformat, or checkout operations.
- Do not stage, commit, branch, push, open a pull request, or rewrite history
  unless separately requested.
- Do not reset, erase, or delete a simulator or CoreSimulator clone. If
  non-destructive diagnosis cannot recover parallel execution, stop and request
  approval for the exact proposed infrastructure action.
- Do not run builds or tests concurrently against the same simulator,
  DerivedData, `build/` subtree, or result bundle.
- Do not run `make format`; formatting debt and DerivedData traversal remain a
  separate concern.
- Do not add dependencies, update AudioKit or `Package.resolved`, change signing,
  entitlements, capabilities, App Groups, deployment targets, or privacy
  declarations inside an evidence lane.
- Do not use personal library data. Use generated fixtures, repository test
  media, or a purpose-built synthetic library.
- A failed visual, trace, device, or warning probe creates a small reproducible
  implementation task. Do not patch source opportunistically while gathering
  evidence.

## Evidence protocol

Every lane follows the same record:

1. Re-read the task, current source, relevant tests, and the closest
   `AGENTS.md`.
2. Record `HEAD`, `git status --short`, Xcode/Swift versions, simulator or
   device identity, OS build, configuration, scenario, and task-relevant source
   checksums.
3. Write the expected observable result before running the probe.
4. Use an isolated output root such as
   `build/AuditEvidence/<run-id>/<audit-id>/`; raw screenshots, traces, logs,
   and XCResults remain ignored build artifacts unless the release owner
   approves an external evidence destination.
5. Record exact counts, durations, warning instances, failures, and skips.
   Empty output or zero executed tests is not a pass.
6. Classify the result as MATCH, MISMATCH, or INCONCLUSIVE. A mismatch stops the
   lane and opens a focused fix; an inconclusive probe is strengthened before
   proceeding.
7. Update the task file and `00-README.md` only after all unchecked acceptance
   criteria for that task are proven. Keep the implementation record factual
   and link or name the evidence artifact.

XcodeBuildMCP defaults are process- and session-scoped. One live server may have
no defaults while another points at the repository's shared
`build/DerivedData`; multiple XcodeBuildMCP and `mcpbridge` processes may also
be present. Therefore, before every future build, run, test, or profiling
launch through that tool:

1. inspect the active session defaults;
2. explicitly select `Fonic HiFi.xcodeproj`, scheme `Fonic HiFi`, the required
   configuration, and the scenario-specific iOS 27 destination;
3. override `derivedDataPath` with that lane's isolated path; and
4. confirm no Make or MCP lane is using that destination or path.

An MCP operation must never inherit `./build/DerivedData` while a Make lane is
active, because that is the Makefile's default DerivedData path.

The checked-in Makefile remains the command contract. A full lane can isolate
its products with a command-line `BUILD_DIR`, for example:

```sh
make test-unit BUILD_DIR="build/AuditEvidence/<run-id>/unit"
make test-ui BUILD_DIR="build/AuditEvidence/<run-id>/ui"
```

## Workstream responsibilities

Historical agent names do not imply current ownership. Assign people or agents
when execution begins.

| Lane | Tasks | Shared-state rule |
| --- | --- | --- |
| Audio evidence | AUDIT-034; audio portion of AUDIT-055 | Exclusive access to the selected physical route and capture chain |
| Visual and localization evidence | AUDIT-040, AUDIT-043; accessibility portion of AUDIT-055 | Exclusive access to the selected simulator/device during each matrix |
| Trace and performance evidence | AUDIT-041, AUDIT-042, AUDIT-054 | One Instruments capture at a time; fixed fixture and scenario manifest |
| Simulator/runtime-warning lane | AUDIT-050, AUDIT-066 | Runs before the final test merge gate; isolated result bundles |
| Ledger lane | All status transitions and owner decisions | No source edits; task status changes only from reviewed evidence |
| Human release owner | AUDIT-004, AUDIT-005, AUDIT-007, AUDIT-055, AUDIT-061 | Supplies decisions, devices, credentials disposition, and release sign-off |

The lanes may prepare scenarios in parallel, but Xcode execution must be
serialized unless every simulator, DerivedData path, result bundle, and artifact
root is distinct.

## Wave 0 — Freeze the execution baseline

### Step 0.1 — Reconcile the ledger and environment

**Outcome:** the execution record still reports exactly 53 DONE, 8 TODO, and
5 BLOCKED, or the plan is revised before any probe.

**Verification:**

- Parse the live status headings in `audits-1/tasks/`.
- Confirm `Fonic HiFi.xcodeproj/project.pbxproj` and the authoritative
  `Fonic HiFi.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
  exist.
- Record current toolchain, available iOS 27 runtimes, simulator list, and
  XcodeBuildMCP defaults.
- Record protected dirty-tree paths; do not snapshot secret-bearing config or
  personal data.

**Rollback:** none needed; read-only.

### Step 0.2 — Create per-lane manifests

Each lane manifest records:

- task ID and acceptance criterion being tested;
- source fingerprint;
- fixture identity and generation procedure;
- device/simulator, OS, appearance, locale, Dynamic Type, and accessibility
  settings where applicable;
- exact command or manual procedure;
- raw artifact names;
- expected result and actual verdict.

**Pass condition:** another person can repeat the scenario without relying on
the original operator's memory.

**Rollback:** generated manifests and artifacts remain below the ignored
task-specific build directory; do not delete reviewed evidence automatically.

## Wave 1 — Restore trustworthy simulator and warning evidence

### Wave 1 precondition — Quiesce shared simulator tooling

Before either Wave 1 lane runs:

1. inventory booted simulators, active `xcodebuild` processes, XcodeBuildMCP
   servers, and `mcpbridge` clients;
2. select one target UDID and confirm with the operators of other live MCP
   sessions that none holds or is about to use it;
3. stop test applications and non-destructively shut down unrelated booted
   simulators so only the selected destination remains active; and
4. recheck that no process uses the lane's simulator, DerivedData, result
   bundle, or artifact root.

Shutdown is the maximum pre-authorized simulator lifecycle action in this
plan. Erase, reset, clone deletion, device deletion, or CoreSimulator service
reset remains prohibited without separate approval.

### Step 1.1 — AUDIT-050: prove randomized parallel unit execution

1. Confirm the test plan still uses random ordering and marks the unit target
   parallelizable.
2. Inspect CoreSimulator and Device Hub state without resetting or deleting
   anything. Confirm there is no competing `xcodebuild` using the same
   destination or DerivedData.
3. Run the canonical unit lane twice from fresh, distinct `BUILD_DIR` paths.
   `make test-unit` already requests parallel testing.
4. From both XCResults, record the positive executed count, zero failures, zero
   skips, ordering, worker/clone evidence, and duration.

**Pass condition:** the first fresh run establishes a positive discovered count
`N`; the second run executes exactly `N` tests with random ordering and parallel
workers. Both runs report 0 failed and 0 skipped. Compare `N` with the latest
592-test AUDIT-066 record and explain any source-backed difference. Do not use
the older 590-test AUDIT-050 record as the current expected count.

**Stop condition:** if clones remain stuck in creation or zero tests execute,
record the exact CoreSimulator state and stop. The next step is a separately
approved, target-specific infrastructure recovery proposal—not a simulator
reset or deletion performed by default.

**Status rule:** successful local parallel evidence completes the local half of
AUDIT-050. Its CI skip-report criterion remains conditional on AUDIT-005. The
task may become DONE only after either CI is deliberately reintroduced and
proves the criterion, or the owner records that the CI-only criterion is not
applicable while hosted CI remains intentionally retired.

**Rollback:** none needed for read-only diagnosis and test execution. Preserve
the pre-run simulator data state.

### Step 1.2 — AUDIT-066: reproduce and classify the QoS family

1. Produce fresh isolated app/widget build, unit, and UI result bundles.
2. Confirm the build remains at 0 compiler warnings.
3. Export every runtime issue from both XCResults using the supported current
   `xcresulttool` or Xcode issue interface after checking its live help.
4. Group warning instances by test, call stack, waiting thread QoS, owner
   thread QoS, process, framework, and first repository-owned frame.
5. Reproduce one representative of each distinct group with Thread Performance
   Checker or a System Trace capture.
6. Assign each group to repository code, test harness, Apple framework,
   AudioKit, or simulator/tooling. Attribution requires a stack or trace, not a
   filename guess.
7. For each repository-owned group, open one focused fix slice with a
   reproduction-first test or probe. Rerun that group, then the complete unit
   and UI lanes.

**Pass condition:**

- build: 0 compiler warnings;
- unit: complete target, 0 failed, 0 skipped;
- UI: complete target, 0 failed, 0 skipped;
- repository-owned QoS warnings: 0;
- any remaining third-party or device-only instance has a stack-backed
  attribution, owner, and explicit disposition without being called fixed.

AUDIT-066 becomes DONE only when the remaining QoS family is eliminated or the
ledger records an owner-approved external/toolchain disposition consistent
with its acceptance criteria.

**Rollback:** a conditional source fix must carry a file/hunk-specific inverse
patch. Never roll back an overlapping dirty file wholesale.

## Wave 2 — Complete the visual, accessibility, and localization matrices

### Step 2.1 — AUDIT-040: full Now Playing reachability

Use the smallest available supported iPhone simulator (currently the iPhone 17e
lane) and the existing deterministic preview track.

Capture the complete scroll surface—not only the initial viewport—for this
matrix:

| Text size | Orientation | Appearance |
| --- | --- | --- |
| Large | Portrait | Light and dark |
| Large | Landscape | Light and dark |
| AX5 | Portrait | Light and dark |
| AX5 | Landscape | Light and dark |

For every cell:

- dismiss, shuffle, previous, play/pause, next, repeat, scrubber, volume, route,
  lyrics, queue, sleep timer, and track-information actions are reachable and
  do not overlap or clip;
- essential labels and values remain readable;
- 44-point targets remain hittable;
- active shuffle and repeat states remain distinguishable with Differentiate
  Without Color enabled;
- VoiceOver traversal and activation order are coherent;
- Reduce Motion and Reduce Transparency do not hide state or controls.

Run the existing focused AX5 UI test as an automated guard, then perform and
record the full manual/accessibility inspection.

**Pass condition:** all eight matrix cells have reviewed full-surface evidence
and zero clipping, overlap, unreachable control, color-only state, or semantic
navigation defect.

**Rollback:** none for evidence capture. A visual defect becomes a separate
small patch with focused screenshot and UI verification.

### Step 2.2 — AUDIT-043: migrated-feature localization reachability

First generate a feature/key inventory from both String Catalogs and current
user-visible call sites. The matrix must include every migrated feature, not
just the four initial screens:

- Home and browse destinations;
- Library tabs, collections, track rows, details, playlist editor, and empty
  states;
- standard and Smart Search states;
- Settings, Audio, Equalizer, File Manager, file details, and confirmations;
- import, progress, cancellation, and failure states;
- Now Playing, queue, lyrics, sleep timer, and playback errors;
- widget families and placeholder, stale, missing-artwork, and decode-failure
  states;
- accessibility labels, values, hints, and actions used by those features.

Exercise:

- double-length strings;
- forced right-to-left layout;
- English and French plural, number, measurement, and metadata composition;
- Large and AX5 on the smallest supported phone for high-density screens;
- VoiceOver reading order and semantic labels;
- supported widget families in light and dark appearances.

The existing double-length/RTL test and its eight initial-viewport screenshots
remain a smoke guard. Closure requires navigation through the complete
migrated-feature inventory and a reviewed visual/accessibility record.

**Pass condition:** every inventory row has a result; there is no essential
truncation, mirrored-layout defect, broken interpolation/plural, reordered
metadata defect, or regressed accessibility label.

**Rollback:** none for evidence capture. Catalog or view fixes are isolated by
feature and followed by the affected locale matrix, app/widget build, widget
contract verifier, and full UI target.

## Wave 3 — Run one controlled performance campaign

The queue, File Manager, and app-wide programs share setup but retain separate
acceptance records. Use the AUDIT-051 generated on-disk fixtures; never import a
personal library. Freeze one scripted scenario before capturing any trace.

Simulator traces may support relative UI/main-thread comparisons. Device
evidence is required for memory, thermal, energy, and physical-output claims.

### Step 3.1 — AUDIT-041: queue persistence at 1,000-track scale

Capture Time Profiler and File Activity for:

- restoring a 1,000-track queue;
- one enqueue, remove, move, shuffle, and repeat mutation;
- a fixed burst of rapid mutations that exercises coalescing;
- background termination and relaunch restoration.

The current-state trace must prove that the MainActor performs no queue file
stat, encode, or write. Record persistence request count, main-thread time,
write count/bytes, mutation latency, and restored queue identity/order.

For the required before/after comparison:

- do not treat a plain `1207bca` snapshot as a queue-only baseline:
  `QueueStatePersistence.swift` is untracked and `HEAD` also predates many
  unrelated dirty-worktree slices, so a whole-tree comparison would be a
  multi-slice delta;
- derive the exact AUDIT-041 path/hunk set from the current task record and
  diff, then create a disposable copy of the current tree and revert or remove
  only that slice inside the copy;
- use separate DerivedData and the identical fixture/scenario for the
  reconstructed pre-slice and current-state captures; never alter the live Git
  worktree; and
- if a faithful per-slice reconstruction is impossible, use the absolute
  current-state no-MainActor-I/O criteria and obtain an explicit owner
  disposition for the unavailable delta. Do not manufacture a baseline.

**Pass condition:** the current trace contains no MainActor queue persistence
I/O, semantics and force-quit restoration match, and a valid before/after
record or approved evidence disposition exists.

**Rollback:** none for traces. Any measured regression becomes a separate queue
task preserving order, shuffle/repeat, delegate ordering, payload, and restore
contracts.

### Step 3.2 — AUDIT-042: File Manager I/O and manual parity

Use a generated temporary directory and scripted files large enough to make
copy/cancellation visible. Capture Time Profiler and File Activity while
performing:

- list, sort, and search;
- create folder;
- copy and collision-safe rename;
- cancel an in-progress copy and verify no partial destination;
- delete with confirmation;
- root-bound rejection and typed error presentation.

Run the focused File Manager unit tests and UI flows around selection and import
progress. Manually compare navigation, selection, confirmation, naming,
sorting/filtering, cancellation, and errors against the task's preserved
behavior contract.

**Pass condition:** no long filesystem operation or file I/O is attributed to
the MainActor; cancellation/failure leaves no corrupt destination; every manual
parity row has a result.

**Rollback:** none for traces. A mismatch opens one service, view-model, or
presentation fix at a time.

### Step 3.3 — AUDIT-054 Phase 0: rank measured app hotspots

With the same generated 10,000-track on-disk store, capture:

1. cold launch through first usable Home;
2. Home section loading;
3. repeated Search typing and cancellation;
4. Library scrolling and collection switching;
5. queue mutation;
6. artwork-heavy navigation and memory pressure.

Collect Time Profiler, SwiftUI, and Allocations traces. On device, add memory,
hitch, and thermal context where claimed. Rank the remaining candidates:

- MainActor search/SwiftData work;
- artwork cache cost;
- per-body collection materialization;
- render-path formatter/sort construction;
- startup work already moved into the cancellable workflow;
- app-side widget/artwork coordination where the trace reaches it.

Only a candidate with a reproducible measured cost proceeds to a fix phase.
For each convicted candidate:

1. freeze the baseline trace and metric;
2. define one root-cause hypothesis;
3. make the smallest change within the established actor/repository boundary;
4. rerun the identical trace;
5. rerun the focused tests and AUDIT-051 scale baseline;
6. retain the change only when the selected metric improves without functional
   regression.

The already-completed startup slice cannot use plain `HEAD` as its baseline:
`DeferredStartupWorkflow.swift` is untracked and `HEAD` omits the other
unrelated dirty-worktree slices. Reconstruct a per-slice baseline in a
disposable copy by reverting only the startup path/hunks and removing only the
startup file introduced by that slice. If that cannot be done faithfully,
record absolute current-state evidence plus an explicit owner disposition for
the unavailable delta. Future fixes do not receive that exception: baseline
first is mandatory.

**Pass condition:** baseline traces cover the complete scenario list; every
shipped performance change has a comparable post trace and measured
improvement; unconvicted smells remain unchanged; scale baselines remain green.

**Rollback:** inverse the specific conditional patch and rerun the same trace
when the metric does not improve or behavior regresses.

## Wave 4 — Close offline audio evidence before device work

### Step 4.1 — AUDIT-034: offline waveform boundary analysis

Use deterministic phase-contiguous PCM fixtures for sample-level analysis, then
representative repository-safe tracks for format coverage. Exercise the native
and AudioKit transition paths that claim prepared-next behavior.

For each case, retain:

- input format, sample rate, channel layout, frame counts, and engine path;
- rendered output;
- expected boundary frame;
- detected silence run, duplicated/overlapped frames, and frame-count delta;
- waveform plot or equivalent sample report around the boundary;
- seek-near-end and engine-switch-at-boundary result where supported.

**Pass condition:** the deterministic render contains neither inserted silence
nor duplicated overlap at the scheduled boundary, output duration/frame
accounting matches the known fixtures, and the session spy still records no
between-track deactivation.

Encoder priming or resampling must be stated and measured; it may not be
silently counted as a gapless pass.

After this step, AUDIT-034 remains TODO until its consecutive real-track
physical-device capture is complete under AUDIT-055.

**Rollback:** none for measurement artifacts. A reproduced transition defect
opens a focused engine-path task with the same waveform probe as its regression
test.

## Wave 5 — Owner decisions and physical-device release evidence

These gates can be prepared early but cannot be completed autonomously.

### Step 5.1 — Resolve owner decisions

| Task | Required input | Authorized action after the decision |
| --- | --- | --- |
| AUDIT-061 | Credential owner records revoked, rotated, inactive, or unknown for each provider; separate history decision | Provider-side action or coordinated history plan only under separate explicit authorization; never print secret values |
| AUDIT-004 | Choose removal of unused APNs/Live Activity declarations or separate feature epics | If removal is chosen, use capability tooling and validate a signed Release archive without touching unrelated entitlements |
| AUDIT-007 | Approve local-data disclosure, backup/protection policy, and export classification | Measure file protection on device first; then make only the approved disclosure/attribute/key changes |
| AUDIT-005 | Decide whether hosted CI remains retired or is intentionally reintroduced on a named supported Xcode 27 runner | Only after approval, design deterministic pinned gates and obtain a real green run; no speculative workflow |
| AUDIT-055 | Name release owner, device set, routes, capture equipment, and evidence destination | Execute the repeatable device matrix and sign the release-evidence record |

Security disposition for AUDIT-061 is the first owner decision because current
worktree deletion cannot prove historical provider credentials are inactive.

### Step 5.2 — AUDIT-055: execute the physical-device matrix

The release owner records exact device model, OS build, app build identity,
route/accessory, source track, settings, and result for every row:

- background playback and foreground restoration;
- interruption begin/end and correct resume behavior;
- wired/headphone loss and route changes;
- Bluetooth, AirPlay, and USB DAC behavior available to the owner;
- remote transport commands and Now Playing coherence;
- consecutive real-track gapless capture across representative supported
  formats for AUDIT-034;
- source/output/DSP/volume/resampling capture for any bit-perfect wording;
- media-services reset behavior where safely reproducible;
- supported Apple Intelligence path plus unavailable fallback;
- VoiceOver, AX5, RTL, French/localized formats, and reduced motion/transparency;
- widget placeholder, live, stale, missing-artwork, intent, and refresh behavior;
- signed Release archive, processed entitlements, privacy report, export
  classification, and App Store validation after AUDIT-004/007 decisions.

**Pass condition:**

- every matrix row has PASS, FAIL, or BLOCKED with device/OS identity and an
  artifact;
- every marketing-sensitive claim maps to a reviewed evidence item;
- failures become separate tasks rather than ad-hoc fixes inside the lane;
- the release owner signs a documented repeat procedure.

AUDIT-055 remains BLOCKED until the physical devices, routes, capture equipment,
and human release owner are available.

**Rollback:** evidence-only. Signing, entitlement, provider, submission, and
App Store actions require their own explicit authorization.

## Merge and completion gates

### Gate A — Simulator and warnings

- AUDIT-050 local parallel lane executes twice with positive counts.
- Fresh app/widget build reports 0 compiler warnings.
- Unit and UI targets report exact pass/fail/skip counts.
- QoS instances are eliminated or stack-attributed and owner-dispositioned.

### Gate B — Visual and localization

- AUDIT-040 full eight-cell Now Playing matrix is reviewed.
- AUDIT-043 migrated-feature inventory is complete for double-length, RTL,
  localization, widgets, and accessibility.
- Full UI target remains green after any conditional fix.

### Gate C — Performance

- AUDIT-041 and AUDIT-042 traces prove their MainActor/I/O criteria.
- AUDIT-054 Phase 0 ranks all scenarios.
- Every retained performance change has comparable before/after evidence.
- AUDIT-051 scale baselines remain green.

### Gate D — Audio and device

- AUDIT-034 offline waveform evidence passes.
- AUDIT-055 supplies real-track, route, accessibility, widget, AI, archive, and
  release-owner evidence.
- No gapless, bit-perfect, background, or release-ready statement exceeds the
  recorded device evidence.

### Final repository validation

After the last conditional source or catalog change—and not merely after
evidence capture—run from current state:

```sh
make build BUILD_DIR="build/AuditEvidence/final/build"
make test-unit BUILD_DIR="build/AuditEvidence/final/unit"
make test-ui BUILD_DIR="build/AuditEvidence/final/ui"
make test BUILD_DIR="build/AuditEvidence/final/shared"
make coverage-check BUILD_DIR="build/AuditEvidence/final/coverage"
make lint
python3 scripts/verify_widget_contracts.py
git diff --check
```

Record:

- app/widget compiler-warning count;
- unit/UI passed, failed, and skipped counts;
- runtime-warning count by family and owner;
- SwiftLint file and violation counts;
- widget contract result;
- shared-test-plan XCResult counts;
- overall and app coverage percentages against the 40% thresholds;
- `git diff --check` exit status;
- every check that remains UNVERIFIED, including SwiftFormat.

`make coverage-check` runs a fresh shared test plan internally. If either the
explicit `make test` lane or coverage enforcement cannot run, record that check
as UNVERIFIED with the exact blocker; do not silently omit it or inherit a stale
XCResult. `xcbeautify` is currently absent, so the Makefile's documented raw
output fallback is expected and is not a validation failure.

Do not run these commands concurrently against shared state. `make format`,
staging, committing, and simulator reset/deletion are not part of this gate.

## Status-transition rules

- A TODO becomes DONE only when every unchecked task acceptance criterion has
  reviewed current-state evidence.
- A TODO with a newly discovered external dependency becomes BLOCKED with the
  exact dependency; it is not rounded up to DONE.
- A BLOCKED task stays BLOCKED until the named owner, device, toolchain, or
  provider input arrives.
- A failed evidence row creates a focused implementation task and preserves the
  failed artifact.
- The ledger lane recomputes all status counts after each transition and checks
  that the 66-task total remains invariant.
- Nothing is staged or committed unless the user separately requests a
  task-scoped Conventional Commit.

## Expected end state

The safely achievable near-term result is:

- complete local simulator parallel-test evidence;
- reproduced and root-cause-classified QoS warnings;
- complete visual/localization matrices;
- queue, File Manager, and app-wide traces;
- offline gapless waveform evidence;
- precise retained blockers for CI, policy, credentials, physical hardware,
  and release ownership.

The backlog reaches full closure only after the owner and physical-device gates
are supplied. Until then, the plan favors accurate BLOCKED/TODO status over an
unsupported green or release-ready claim.
