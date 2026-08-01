# Fonic HiFi Audit Cross-Check and Remediation Ledger

**Created:** 2026-07-10
**Status:** implementation in progress; third bounded batch verified, with E-02 complete and E-07 split at shuffle-active editing
**Audited revision:** `459db9bfd18d17960e8fd2ff8defc4701085532e` on `main`
**Task order:** easiest to hardest, except the security response, which is urgent and external
**Completion marker:** ✅ identifies a fully completed and verified ledger item; partial slices remain unchecked.

## Purpose and scope

This file reconciles the two AI audit packages under `audits-1/` against the current working tree and turns the defensible findings into an implementation ledger.

The two model folders are:

1. `audits-1/5c92e094-7bff-4bfd-8c71-3f80d100a3a8` — called **Model A** below.
2. `audits-1/fonic-hifi-production-audit` — called **Model B** below.

Together they contain 21 relevant Markdown/JSON files, 9,792 lines, and 713,673 bytes. Both audited the same commit, so matching prose is useful corroboration but is not independent runtime proof.

### Assumption

**ASSUMPTION:** These two populated subfolders are the two model outputs the user meant.
**BECAUSE:** `audits-1` is the only top-level audit directory and contains exactly these two populated audit packages.
**REVISIT-IF:** A second audit directory outside `audits-1` was intended.

### Constraints

- Preserve the current dirty working tree and every user-owned change.
- Do not implement production fixes as part of this analysis task.
- Do not print or copy credential values, tokens, endpoints, private paths, or user library metadata.
- Do not weaken concurrency checks, add `@unchecked Sendable`, delete user data, replace a failed persistent store with silent data loss, or make unmeasured bit-perfect claims.
- Do not stage, commit, branch, rewrite history, force-push, change signing/capabilities, or contact providers without explicit authorization.
- Keep each future implementation step to at most three files and roughly 40 changed lines. Split any larger row below before acting.

## Current ground truth

| Check | Current result | Interpretation |
|---|---|---|
| Git baseline | `main` at `459db9b`; worktree already dirty | The audits match `HEAD`, but several current local edits postdate the audit snapshot. |
| Main project | `Fonic HiFi.xcodeproj/project.pbxproj` exists | Authoritative project is present. |
| SwiftPM pin | main workspace `Package.resolved` exists | AudioKit remains pinned; do not update it incidentally. |
| Host toolchain | selected Xcode 27 beta, Swift 6.4 compiler | This does not change the iOS 26 deployment target or Swift 6 language mode. |
| Xcode build | `buildForTesting`: success in 18.136 s, 0 errors | Current source and test targets compile under the selected beta toolchain. It does not prove stable-Xcode, release, archive, device, or App Store behavior. |
| Test discovery | 452 enabled, 0 disabled | The active local scheme can discover tests, despite no versioned shared scheme/test plan in Git. |
| Batch 1 focused tests | 4 passed, 0 failed, 0 skipped, 0 not run | Current local playback-error surfacing and post-failure permit-release changes are verified at their tested layer. |
| Batch 2 focused tests | 26 passed, 0 failed, 0 skipped on the iOS 27 simulator | Queue editing and remote-command suites are green from the committed-project scheme. |
| Full suite | not run in this analysis | Full-suite status remains `UNVERIFIED`. |
| Repository visibility | GitHub reports `PUBLIC` | Tracked sensitive local-tool configuration is exposed in a public repository/history. Credential validity or revocation status was not tested. |
| Recent CI | 20 most recent listed CI runs all failed | The current workflow is not a credible release gate. This does not prove every historical failure had the same root cause. |
| Privacy manifests | 0 first-party app/widget manifests | App/widget required-reason declarations remain open. |
| Covered API surface | 21 app/widget Swift files use `UserDefaults`/`@AppStorage`; file timestamps and `systemUptime` are also used | Each executable needs a target-specific, truthful reason inventory. |
| Real FLAC probe | `AVAudioFile` opened the repository FLAC: 10,651,620 frames, 44.1 kHz, 2 channels | The local native decoder accepts the sample. iOS/device playback and output correctness remain unverified. |

### Protected pre-existing changes

The current worktree already changes files that overlap several findings, including `.gitignore`, `ContentView.swift`, `StateCoordinator.swift`, `AudioEngineFacade.swift`, `FormatDetectionCoordinator.swift`, `FonicHiFiApp.swift`, `LiquidGlassMiniPlayer.swift`, `NowPlayingContent.swift`, two test files, and the untracked `PlaybackErrorBanner.swift`. Future work must re-read and checkpoint these edits before touching them.

The current edits partially address two audit areas:

- Playback/startup failures now have visible error state, and 3 focused tests pass. Observation wiring and several Home/Search/File Manager failure paths remain open.
- Format-detection permits are released synchronously after a completed failure, and 1 focused test passes. Cancellation of a task waiting for a permit remains open.

## Accuracy verdict

### Model A

Model A is directionally useful but not safe to implement verbatim.

| Classification | Count | Meaning |
|---|---:|---|
| Confirmed | 24 | Accurate in the current tree without material qualification. Two are positive/no-action checks. |
| Partial or overstated | 16 | Factual core exists, but impact, severity, reachability, performance, or proposed fix is overstated. |
| Stale/already addressed | 1 | The original missing-icon claim was corrected, and the current build resolves the icon asset. |
| False | 2 | `ImportSession` security-scope defect and widget inherited-deployment-target claim. |
| Runtime/hardware only | 3 | Static evidence cannot decide the claimed behavior. |
| **Total** | **46** | 40 have some correct factual core; only 24 are unqualified current findings. |

Strong Model A findings include route-loss handling, missing first-party privacy manifests, public tracked configuration, CI drift, Smart Search's logging-only playback action, EQ accessibility, FLAC exclusion, queue persistence mechanics, and several dead-source candidates.

Model A materially overstates or misframes these points:

- Absence of `ITSAppUsesNonExemptEncryption` causes a questionnaire; it is not by itself a submission failure.
- Neither engine is proven bit-perfect from static graph inspection. The native adapter also always contains time-pitch and mixer nodes.
- A successful compile does not prove unused source ships byte-for-byte in the final binary; deletion still needs per-file ownership and build checks.
- `QueueCoordinator.removeFromQueue` is inert but has no production caller; it is not currently a reachable UI failure.
- In-app `.fileImporter` works without document-type registration. “Open in”/file sharing is a separate product capability that needs an incoming-URL design.
- Fixed-size SF Symbol calls are not automatically Dynamic Type defects; text and layout must be audited separately.
- Liquid Glass performance claims need Instruments evidence; `.ultraThinMaterial` is not inherently a defect.
- “Live credentials” is unverified. Exposure is confirmed, so the safe response is still to treat them as compromised until providers confirm revocation.

### Model B

Model B is the stronger audit. It has better evidence boundaries, rejects more candidate false positives, qualifies policy/runtime claims, and uses current Apple sources. It is still a checkpoint, not a final synthesis, and its severities must not be added across reports.

- Raw retained findings: 139 across nine finding reports.
- Self-labeled confidence: 117 confirmed by static evidence, 17 probable, 5 unverified.
- Independent current-tree review of reports 01–05: 56 confirmed, 34 partial/overstated, 1 owner/policy-unverifiable, 0 wholly false.
- Independent deduped review of reports 06–09: 29 of 38 distinct groups confirmed, 3 partial/overstated, 6 runtime/owner-unverified, 0 wholly false.

Model B's main limitation is not fabrication; it is breadth. Multiple reports repeat the same root causes, performance reports identify code smells without traces, and many samples are sketches that violate this project's size, ownership, or concurrency rules if pasted literally.

## Where both models agree

| Consolidated issue | Model A | Model B | Current verdict | Ledger |
|---|---|---|---|---|
| Sensitive local-tool config is tracked in a public repo | A-C03 | PCFG-001, PSR-001 | Exposure confirmed; validity/revocation unverified | SEC-01–03 |
| App/widget privacy manifests are missing | A-C02 | PCFG-002, PSR-002 | Confirmed and current | M-01–03 |
| CI toolchain is incompatible and conflicted by Makefile | A-C05 | PCFG-003, PSR-003, TRV-001 | Confirmed and current | M-04 |
| Local/build/Xcode artifacts remain tracked | A-C07, A-C09 | PCFG-008, PSR-007, DCA-ART-001 | Confirmed; current worktree partially deletes some | E-01–02 |
| Headphone/route loss does not pause | A-B01 | AUD-SESSION-002 | Confirmed; Apple explicitly recommends pause | X-02 |
| Audio-session/transition ownership is unsafe | A-B02 | AUD-SESSION-001, AUD-TRANSITION-001 | Static mechanics confirmed; audible gap needs device signal evidence | X-01, X-06 |
| Bit-perfect UI/engine conclusions are heuristic | A-B03 | AUD-BIT-001, AUD-BIT-002 | Confirmed as an honesty/evidence problem; actual output unverified | X-07 |
| Audio settings do not reliably control runtime | A-B05 | AUD-CONFIG-001, UIUX-008 | Confirmed core; performance impact unmeasured | M-19 |
| Queue persistence runs synchronous work on MainActor | A-B06 | CP-003 | Static hot path confirmed; jank needs trace | H-08 |
| Native seek accounting is suspicious | A-B07 | AUD-SEEK-001 | Probable; reproduce before fixing | X-05 |
| AudioKit completion uses 100 ms polling | A-B10 | CP-007 | Confirmed mechanism; energy impact unmeasured | M-16, H-12 |
| Facade observation boundary is wrong | A-F01 | UIUX-001 | Confirmed and still open | M-11 |
| Smart Search action/state is incomplete | A-F03 | UIUX-011, DCA-PART-004 | Confirmed | M-08 |
| EQ bands lack semantic adjustable control | A-F05 | UIUX-020, A11Y-002 | Confirmed static omission; device accessibility still required | M-09 |
| Now Playing/Dynamic Type needs adaptive validation | A-F10, A-F11, A-F13 | UIUX-005, UIUX-006, A11Y-006 | Credible but visual/runtime dependent | M-13, X-08 |
| Widget progress/state becomes stale | A-F14 | AUD-WIDGET-001, DLP-016, CP-006 | Confirmed functional issue; energy impact unprofiled | M-17 |
| Multiple source families are production-unreferenced | A-D01–04, A-D07 | DCA-DEAD-001, DCA-DEAD-002 | Candidate inventory confirmed; delete only in small verified batches | E-15 |
| QueueCoordinator exposes inert methods | A-D05 | DCA-PART-003 | Confirmed but latent/no caller | E-06 |
| SwiftLint omits widget/UI-test roots | A-C12 | PCFG-009 | Confirmed scope gap; rule expansion is optional/incremental | E-04 |
| APNs/Live Activity metadata lacks product implementation | A-C11 | PCFG-010, PCFG-012, PSR-008, PSR-009 | Confirmed metadata drift; removal needs product/signing decision | E-05 |
| App icon exists | corrected A-C01 | PCFG verified-good check | Confirmed by successful build; archive validation remains | R-02 |
| Export key is absent | A-C06 | PSR-010 | Absence confirmed; classification is release-owner work, not a proven defect | R-01 |

Agreement does not promote probable performance, visual, audio-output, or App Store claims to verified behavior. Those require the evidence gates listed below.

## Execution protocol

For every implementation row:

1. Re-read this file, the original audit section, current source, tests, and current `git status --short`.
2. Write a `PREDICT` record with the exact test/build/probe and expected counts before editing.
3. Touch no more than three files and roughly 40 lines. Split the row when needed.
4. Preserve existing user edits. Never roll back an entire overlapping file.
5. Re-read the changed region, run the narrow test, and record raw counts plus exit status.
6. Mark only `MATCH` as `VERIFIED`. Stop on `MISMATCH`; strengthen an `INCONCLUSIVE` check immediately.
7. At the merge point, rerun the union of affected tests, the app/widget build as applicable, lint, and `git diff --check`.

**Standard rollback:** reverse only the task's patch. If the user explicitly authorizes task commits, revert that task commit. Never use a whole-file restore on a file that had pre-existing changes.

## Immediate security gate — urgent, not difficulty-sorted

### SEC-01 — Provider-side credential response

- **Status:** `BLOCKED(USER/PROVIDER)`
- **Evidence:** public repo plus tracked sensitive-marker configuration; credential validity not tested.
- **Outcome:** provider owners revoke/rotate all exposed values, review recent access/billing, and record completion without pasting values here.
- **Verification:** provider dashboard confirms old credential revoked and replacement active; repository tools use environment/keychain injection only.
- **Rollback:** none. Rotation is intentionally irreversible, so this is an A4 action owned by the user/provider.

### SEC-02 — Stop tracking local secret-bearing configuration

- **Status:** `PENDING`, depends on SEC-01 and current `.claude/settings.local.json` ownership review.
- **Outcome:** untrack the two local configuration files, add narrowly scoped ignore rules, and provide redacted templates only if a team template is actually needed.
- **Verification:** `git ls-files` returns zero sensitive local-config paths; two independent secret scanners report no raw credential in the prospective commit; local tooling still starts using external environment/keychain values.
- **Rollback:** restore only redacted templates/ignore entries; never restore revoked secrets.

### SEC-03 — Historical exposure cleanup

- **Status:** `BLOCKED(EXPLICIT AUTHORIZATION)`
- **Outcome:** after rotation, decide whether to rewrite history; coordinate every collaborator/fork and require fresh clones.
- **Verification:** provider values are revoked first; post-rewrite history scans find no old secret blobs; branch protection/remote state is revalidated.
- **Rollback:** no complete rollback after collaborators consume rewritten history. Requires a separate A4 approval.

## Preflight before any engineering task

### PRE-01 — Checkpoint the existing dirty worktree

- **Status:** `✅ SATISFIED FOR BATCHES 1–3` — the user explicitly authorized task commits; each batch recorded its starting revision/status, and every touched path was clean or an explicitly preserved deletion before editing.
- **Outcome:** identify which current edits are intentional and establish a user-approved checkpoint or patch record before overlapping work.
- **Verification:** current changes are attributable; no task diff contains unexplained pre-existing lines; the latest verified focused check is rerun after the checkpoint.
- **Rollback:** return to the recorded checkpoint by task-scoped reverse patches only.

## Level 1 — easiest, small and mostly independent

| ID | Status | Outcome and source | Exact verification |
|---|---|---|---|
| E-01 | ✅ VERIFIED | Finish `.gitignore`: preserve the current main-project/`Package.resolved` fix, repair the corrupted `.apdiskbuild_verify.log` line, and add scoped log/local-config rules. A-C04, A-C07. | Ten path probes matched: eight intended artifacts/configs are ignored by repository rules; the authoritative project and pin are not ignored. `git diff --check` exits 0. |
| E-02 | ✅ VERIFIED | Removed three tracked personal `xcuserdata` files in `b64b89d`, then removed the stale project backup and two tracked build logs in `814bf5e`. Existing ignore rules prevent regeneration from becoming tracked. PCFG-008, PSR-007, DCA-ART-001. | Each commit contained exactly three deletions, staged diff checks exited 0, the unrelated-worktree fingerprint remained unchanged, and post-deletion simulator builds succeeded in 2.0 s and 1.3 s with 0 errors. |
| E-03 | PENDING/OWNER | Resolve the mode-160000 orphan gitlink: remove it or restore a verified upstream plus `.gitmodules`. PCFG-006. | `git submodule status` exits 0 and a fresh clone has no broken gitlink. |
| E-04 | PENDING/TOOLING | Add widget and UI-test roots to SwiftLint without enabling unrelated rule churn. SwiftLint is not installed on the selected host, and project rules prohibit installing it without approval. PCFG-009. | `swiftlint lint --strict` scans all four target roots and exits 0; touched source count is nonzero for each root. |
| E-05 | BLOCKED(PRODUCT/SIGNING) | Decide APNs and Live Activities. Remove unused declarations through Xcode/capability tooling, or create separate implementation epics. PCFG-010/012, PSR-008/009. | Processed Release entitlements/Info.plist match the decision; archive signing succeeds. |
| E-06 | ✅ VERIFIED (deletion path) | Delete the three inert `QueueCoordinator` APIs or delegate them to existing manager APIs with typed IDs/results. A-D05, DCA-PART-003. | For deletion: two independent reference probes find no inert API and `build-for-testing` produces the unit-test bundle. If retained in the future, positive mutation and persistence tests are required. |
| E-07 | PARTIAL — VERIFIED SHUFFLE-OFF SLICE | Queue edits now use atomic manager-owned `IndexSet` translation, preserve the current track at index 0/middle/last, support SwiftUI start/end and multi-row move semantics, reject invalid sets, and expose `EditButton`. Shuffle-active editing is intentionally disabled until its order/persistence contract is designed. AUD-QUEUE-001, UIUX-013. | 22 `AudioQueueManagerTests` passed with 0 failures/skips; explicit shuffle-active no-op coverage prevents the prior corruption path. |
| E-08 | ✅ VERIFIED (disabled path) | Keep unsupported skip-forward/backward remote commands disabled while retaining absolute seek and the supported transport controls. AUD-REMOTE-001. | All 4 `AudioSessionServiceTests` passed; the direct command-center test proves both skip commands remain disabled after enabling supported controls. |
| E-09 | PENDING | Upsert normalized recent searches and render rows with persistent identity. DLP-015. | Repeating/case-variant queries leaves one row; ordering and delete tests pass. |
| E-10 | PENDING | Persist all extracted ReplayGain gain/peak fields. DLP-008. | A focused metadata-to-model test asserts all four values survive save/re-fetch. |
| E-11 | PENDING | Remove the nested `NavigationStack` in Audio Settings. UIUX-014. | Settings → Audio Settings → back/edge-swipe UI flow has one navigation stack and passes. |
| E-12 | PENDING | Add a confirmation dialog that names the scope of Reset All Settings. UIUX-016. | Cancel preserves settings; confirm resets the documented keys; both UI paths pass. |
| E-13 | PENDING | Render and enforce the Surprise Me busy/disabled state. UIUX-019. | Double activation starts exactly one request; progress state appears and clears on success/failure. |
| E-14a | ✅ VERIFIED | Correct the stale widget provider comment to match its actual `TimelineProvider` conformance. A-F14. | Source comment and conformance agree; the app/widget build succeeds with 0 errors. |
| E-14b | PENDING/SPLIT | Replace the unrelated HealthKit project reference with a concise Fonic-specific reference. A-B11. | Documentation paths/settings match current pbxproj, plist, and Swift 6 language mode; `git diff --check` exits 0. |
| E-15 | PENDING/BATCHED | Triage production-unreferenced source one family at a time; delete only after two reference probes and ownership review. A-D01–04, A-D06–07, DCA-DEAD-001/002. | For each batch: two reference probes, focused tests, main build, then `git diff --check`; zero unrelated deletion. |

## Level 2 — medium, bounded feature/configuration work

| ID | Status | Outcome and source | Exact verification |
|---|---|---|---|
| M-01 | PENDING | Produce a target-by-target required-reason API inventory. Do not copy Model A's single `CA92.1` example blindly. PCFG-002, PSR-002. | Every app/widget call site maps to owning bundle, category, execution path, and current approved reason; two searches find no unmapped covered API. |
| M-02 | PENDING, depends M-01 | Add the app `PrivacyInfo.xcprivacy` with truthful categories/reasons and data/tracking declarations. | `plutil -lint` exits 0; built `.app` contains one valid manifest; Xcode privacy report matches inventory. |
| M-03 | PENDING, depends M-01 | Add the widget manifest using App Group/defaults reasons appropriate to the extension. | `plutil -lint` exits 0; built `.appex` contains its own valid manifest; archive privacy report has no missing-reason error. |
| M-04 | PENDING | Move CI to the current GitHub-hosted `macos-26` surface, print/discover the installed stable Xcode 26.x/SDK/runtime, and remove the conflicting hard-coded Makefile override. PCFG-003, PSR-003, TRV-001, A-C05. | A clean workflow prints one intended Xcode/SDK, finds its destination, reaches test execution, and exits 0. |
| M-05 | PENDING, depends M-04 | Generate and version a real shared scheme/test plan through Xcode. Never paste audit placeholder UUIDs. PCFG-004, TRV-002. | Fresh clone `xcodebuild -list` shows the shared scheme; test discovery reports positive counts for unit and UI targets. |
| M-06 | PENDING, depends M-05 | Split unit/UI Make targets and fail zero-test or unexpected-skip runs. TRV-003, TRV-015. | Unit command executes >0 unit and 0 UI tests; UI command executes >0 UI tests; unexpected skip/0 tests makes CI nonzero. |
| M-07 | PENDING, depends M-04/M-05 | Add unsigned Release build/analyze gates; design signed archive/export as a protected owner lane. PCFG-007, TRV-014. | Debug tests, Release build, analyze, and protected archive each report separate nonzero work and zero errors. |
| M-08 | PENDING | Make Smart Search mode reachable, route result taps through the authoritative playback path, and render unavailable/error/retry states. Split reachability and playback/error into separate patches. A-F03, UIUX-011, DCA-PART-004. | Focused view-model tests cover availability/fallback/error; UI flow reaches Smart mode, taps a result, and observes current track/Now Playing or a visible error. |
| M-09 | PENDING/BATCHED | Fix accessibility one control family at a time: EQ adjustable actions/44-point targets, slider labels/values, favorite/A-B hit areas, shuffle/repeat state, Reduce Motion, lyrics modal focus. A-F05/F06, UIUX-020, A11Y-002–008. | Each family gets focused accessibility assertions; final device pass covers VoiceOver, keyboard/Switch Control, AX sizes, Reduce Motion/Transparency. |
| M-10 | PENDING/BATCHED | Replace raw tap gestures with `Button`/`NavigationLink`, then wire empty/import/browse/select affordances one surface at a time. A-F04/F12, UIUX-012/015/017, A11Y-001. | UI tests activate each action by semantic label and assert navigation/play/import postconditions. |
| M-11 | PENDING | Repair app-wide observation ownership: fully use `@StateObject`/`@EnvironmentObject` or fully migrate the facade to Observation. Do not mix models at the boundary. A-F01, UIUX-001. | A focused invalidation test proves track/artwork/error/import changes update consumers; build and facade tests pass. |
| M-12 | PENDING, depends M-11 | Finish typed user-visible error/import state across Home, Search, File Manager, picker failure, and import progress. Preserve the current verified banner work. UIUX-009/010. | Failure injection produces visible recoverable state; success/empty/error are distinguishable; focused tests have 0 failures. |
| M-13 | PENDING, depends M-11 | Remove duplicated shuffle/repeat/speed state, gate mini player on an authoritative track, and add explicit/adaptive Now Playing dismissal/layout. Split state, gating, and layout patches. UIUX-002–006, A11Y-006, A-F11/F13. | State remains coherent after external/remote changes; screenshot/UI matrix covers portrait, landscape, smallest phone, and AX5. |
| M-14 | PENDING/SPLIT | Repair format contract in three patches: inspect M4A codec rather than extension; hide or implement OGG/Opus/WavPack/APE; route FLAC natively after focused tests. AUD-FORMAT-001/002, A-B04. | Real AAC-M4A, ALAC-M4A, FLAC, and unsupported fixtures take the expected detector/engine path; no advertised format lacks a playable path. |
| M-15 | PENDING | Normalize persisted engine preference and make runtime settings a typed applied source. AUD-ENG-001, AUD-CONFIG-001, UIUX-008. | Every stored choice selects the requested capable engine; unsupported choices fall back visibly; each setting changes runtime or is removed. |
| M-16 | PENDING | Replace AudioKit completion polling with an exactly-once engine callback; retain UI progress scheduling separately. A-B10, CP-007. | Completion tests observe one callback for finish, seek-near-end, stop, cancel, and transition; no 100 ms completion poll remains. |
| M-17 | PENDING | Publish complete widget state and derive progress from timestamps/rate; remove missed-change 500 ms polling where possible. A-F14, AUD-WIDGET-001, DLP-016, CP-006. | App/widget Codable compatibility tests pass; timeline advances progress and reflects pause/rate/queue-mode/staleness. |
| M-18 | PENDING | Move sleep-timer ownership out of `NowPlayingContent` and preserve actual volume/fade policy. AUD-SLEEP-001, UIUX-007. | Dismissing/reopening Now Playing does not cancel timer; fade starts/restores actual volume; cancel/background tests pass. |
| M-19 | PENDING | Restore/reapply persisted EQ on initial engine creation and every switch; expose DSP capability failures instead of silent no-ops. AUD-DSP-001, DCA-PART-002. | Engine creation/switch/restart tests assert identical EQ state; unsupported DSP returns a typed visible result. |
| M-20 | PENDING | Add parity/fixture checks for mirrored app/widget contracts before considering target-membership consolidation. DCA-DUP-001. | Both source copies encode/decode the same golden old/current payloads; any drift fails tests. |
| M-21 | PENDING/BATCHED | Replace public logging of titles, paths, filenames, searches, routes, and free-form errors one data class/module at a time. PSR-004. | Release log exercise plus static scan finds zero prohibited `.public` user-data sites; operational fields remain useful and redacted. |
| M-22 | PENDING/OWNER | Build a verified local-data map, update in-app/external privacy policy, and record final-archive export determination. PSR-006/010, A-C06. | Policy covers actual current storage/retention/deletion; final archive dependency graph supports the App Store answers and processed export key. |
| M-23 | PENDING/BATCHED | Strengthen test quality: exact errors, non-vacuous DSP state, deterministic test roots/defaults, real licensed audio fixtures, UI postconditions, skip classification, and targeted coverage. TRV-004–006/009/013/015. | Every new regression is observed red before green; target counts/skips are explicit; no test deletes shared host data. |
| M-24 | PENDING/PROGRAM | Establish a String Catalog, then migrate plural, number/unit, metadata, widget, and accessibility strings feature by feature. LOC-001–004. | Pseudolocalized and RTL builds render correctly; plural/number tests cover at least two locales; wire payload remains backward compatible. |

## Level 3 — hard, data/concurrency/architecture work

| ID | Status | Outcome and source | Exact verification |
|---|---|---|---|
| H-01 | PENDING | Define a non-destructive persistent-store recovery contract. The current local UI makes fallback visible but still permits ephemeral services. DLP-001. | Inject persistent-open failure: no normal library/mutation UI appears; existing store/media remain untouched; recovery guidance is visible. |
| H-02 | PENDING, depends H-01 | Add a new immutable schema version containing `ListeningSession` and an ordered migration from a real prior store. DLP-002/003, TRV-010. | Create V1 store → close → open through production migration → re-open; all tracks/relationships/bookmarks survive and session insertion succeeds. |
| H-03 | PENDING, depends H-02 | Wire serialized listening-session lifecycle, actual listened-time deltas, transition replacement, and retention. DLP-004/017/019/020, CP-005, DCA-PART-001. | Play/pause/seek/restore/next/previous/stop/crash-relaunch tests produce one correct bounded session sequence. |
| H-04 | PENDING | Remove copied managed media after every post-copy failure/cancellation without deleting prior user files. DLP-005. | Failure injected after copy leaves zero new orphan and preserves pre-existing destination; red/green test recorded. |
| H-05 | PENDING | Make duplicate import a single actor-owned/unique claim with a final atomic check. DLP-006, CP-004. | Concurrent same-source imports create exactly one file/model/relationship set; loser reports duplicate, not failure. |
| H-06 | PENDING | Tie import producer/group/continuation lifetime to consumer cancellation and cleanup. DLP-021, CP-002. | Cancel while discovering, queued, copying, extracting, and persisting; producer terminates, counts stop changing, partial files are removed. |
| H-07 | PENDING | Replace `AsyncSemaphore` with a cancellation-aware tokenized waiter design; do not copy Model B's racy sample. CP-001. | Cancel a queued waiter before/after registration and race release/cancel repeatedly; no continuation leak, permit loss, or over-release. |
| H-08 | PENDING/PROFILE-FIRST | Snapshot queue state, coalesce writes, and serialize/persist off MainActor through a safe owner. A-B06, CP-003. | Trace baseline first; mutation tests preserve order/history/position; MainActor no longer performs file stat/encode/write; before/after metrics recorded. |
| H-09 | PENDING | Replace one-shot missing-file deletion with quarantine/retry/relink policy. DLP-007. | Temporary provider unavailability never deletes records; confirmed permanent removal cleans relationships only after policy threshold. |
| H-10 | PENDING/SPLIT | Complete playlist mutations, observable library revision, and real repository pagination/count/search. DLP-010–014. | Add/remove/reorder survives re-open; writes refresh views once; paginated 10k on-disk library returns correct counts without hydrating all rows. |
| H-11 | PENDING | Preserve errors/cancellation in File Manager I/O and move measured blocking work off UI isolation. CP-015. | Copy/delete/list failure and cancellation surface typed state; trace shows no long UI-thread file operation. |
| H-12 | PENDING/PROFILE-FIRST | Measure before changing remaining performance candidates: progress invalidation, widget/artwork work, cache bytes, array materialization, pagination, formatting, diagnostics storage, and startup tasks. A-F02/F07/F10, A-B05/B09, CP-006–016, DLP-012–014. | One Release device trace per symptom with reproduction, baseline CPU/frame/memory/wakeup metrics, one hypothesis, and before/after evidence. |
| H-13 | PENDING | Add real on-disk migration/import/large-library benchmarks with product budgets, not one-shot wall-clock assertions. TRV-006/010/011. | Repeatable XCTest metrics on declared hardware/configuration meet written budgets; fixtures are valid audio and production paths are used. |
| H-14 | PENDING/DEVICE | Represent unavailable diagnostics as unavailable, bound histories, and implement only measurements supported by real evidence. AUD-DIAG-001, CP-012, DCA-PART-005. | No synthetic zero is shown as real data; buffers are bounded; device trace validates sampling overhead and values. |

## Level 4 — hardest, audio state machine and release evidence

| ID | Status | Outcome and source | Exact verification |
|---|---|---|---|
| X-01 | PENDING | Establish one audio-session owner and separate track transition teardown from genuine playback shutdown. AUD-SESSION-001, A-B02. | Session spy shows activation before playback, zero deactivation between queued tracks, and one deactivation on true shutdown. |
| X-02 | PENDING, depends X-01 | Preserve interruption intent, use OptionSet containment, and pause coherently on old-device-unavailable only when playing. AUD-SESSION-002, A-B01. | Logic tests cover playing/paused interruption and route loss; physical headphone/Bluetooth/USB tests keep UI/Now Playing coherent. |
| X-03 | PENDING | Serialize play requests with latest-request-wins cancellation/generation validation. AUD-ENG-002. | Delayed A then fast B always ends on B; stale A cannot clear/commit state; cancellation has no generic error UI. |
| X-04 | PENDING | Make AudioKit crossfade cancellation reconcile one authoritative player/file/state. AUD-TRANSITION-002. | Cancel at start/mid/end plus pause/seek/next; one player/current track remains and completion fires once. |
| X-05 | PENDING/REPRODUCE-FIRST | Reproduce and repair native seek source offsets, A-B looping, and media-services reset reconstruction. AUD-SEEK-001, AUD-RESET-001, A-B07. | Same reproduction fails before and passes after; repeated seeks/completion and injected reset rebuild engine/commands/Now Playing. |
| X-06 | PENDING, depends X-01/X-03/X-04 | Build a real prepared-next gapless state machine; do not treat zero-duration crossfade fallback as gapless. AUD-TRANSITION-001, A-B02, TRV-007. | Logic scheduling tests, offline waveform boundary analysis, then consecutive real-track device capture across formats; no session deactivation at boundary. |
| X-07 | PENDING/PHYSICAL EVIDENCE | Rename current UI to eligibility until engine graph, DSP bypass, route, volume, sample-rate conversion, and digital output are measured. AUD-BIT-001/002, A-B03. | Cache invalidates on every eligibility input; unity graph bypass tests pass; external digital capture is bit-identical before any “bit-perfect” claim. |
| X-08 | PENDING/DEVICE/OWNER | Execute the release matrix: stable Xcode 26 Debug/Release, full tests, accessibility/locale/visual states, real audio routes/background/interruption/remote/widget, signed archive, privacy report, export classification, and App Store validation. TRV-012/016 plus all device-only findings. | Fresh evidence records exact test counts, skips, build/archive results, device/OS/route, screenshots/traces, and App Store validation outcome. |

## Release-only and product-choice records

These are not automatic code fixes:

### R-01 — Export compliance

The key is absent. Apple's current documentation says omission triggers the questionnaire for each version. Add `NO` only after the final app and linked libraries are classified as no encryption or exempt-only; otherwise use the required declaration/code. This is a release-owner determination, not a static defect.

### R-02 — App icon

The original Model A Critical finding was false and later corrected. `Fonic.icon` resolves in the current successful build. Keep only archive/App Store icon validation; remove the empty legacy set afterward if it remains unused.

### R-03 — Document types and file sharing

Missing `CFBundleDocumentTypes`, `LSSupportsOpeningDocumentsInPlace`, and file-sharing keys do not break the live in-app file picker. Add them only if product wants “Open in Fonic HiFi”/Files sharing, together with an incoming URL lifecycle, supported UTI contract, copy/security-scope behavior, and tests.

### R-04 — Backup and Data Protection policy

Desired backup behavior is a product decision. The audit did not prove `copyItem` preserves a problematic source protection class. Measure destination protection on device and define locked/background playback requirements before changing file attributes or backup exclusion.

### R-05 — Context menus, broad visual redesign, and optional architecture consistency

Context menus, swipe actions, materials, and unifying every view-model paradigm are product/polish choices unless tied to a demonstrated common-task failure. Implement incrementally after queue/playback actions are authoritative.

## Model B ID coverage map

Every retained Model B finding is routed below; ranges are inclusive.

- **Audio:** AUD-ENG-001 → M-15; AUD-ENG-002 → X-03; AUD-SESSION-001 → X-01; AUD-FORMAT-001/002 → M-14; AUD-CONFIG-001 → M-15; AUD-BIT-001/002 → X-07; AUD-TRANSITION-001 → X-06; AUD-TRANSITION-002 → X-04; AUD-DSP-001 → M-19; AUD-QUEUE-001 → E-07; AUD-QUEUE-002 → M-18-adjacent product policy task before implementation; AUD-RECOVERY-001 → M-17-adjacent queue restore patch; AUD-SEEK-001 → X-05; AUD-SESSION-002 → X-02; AUD-REMOTE-001 → E-08; AUD-RESET-001 → X-05; AUD-SLEEP-001 → M-18; AUD-DIAG-001 → H-14; AUD-WIDGET-001 → M-17.
- **Data:** DLP-001 → H-01; DLP-002/003 → H-02; DLP-004/017/019/020 → H-03; DLP-005 → H-04; DLP-006 → H-05; DLP-007 → H-09; DLP-008 → E-10; DLP-009 → fixture-first metadata subtask under M-14/H-13; DLP-010–014 → H-10/H-12; DLP-015 → E-09; DLP-016 → M-17; DLP-018 → R-04; DLP-021 → H-06.
- **Concurrency/performance:** CP-001 → H-07; CP-002 → H-06; CP-003 → H-08; CP-004 → H-05; CP-005 → H-03; CP-006 → M-17/H-12; CP-007 → M-16/H-12; CP-008–011 → H-12; CP-012 → H-14; CP-013 → lifecycle patch under H-12; CP-014 → H-10/H-12; CP-015 → H-11; CP-016 → H-12.
- **UI/UX:** UIUX-001 → M-11; UIUX-002–006 → M-13; UIUX-007 → M-18; UIUX-008 → M-15; UIUX-009/010 → M-12; UIUX-011 → M-08; UIUX-012/015/017 → M-10; UIUX-013 → E-07; UIUX-014 → E-11; UIUX-016 → E-12; UIUX-018 → M-10; UIUX-019 → E-13; UIUX-020 → M-09.
- **Accessibility/localization:** A11Y-001 → M-10; A11Y-002–008 → M-09/M-13; LOC-001–004 → M-24; A11YTEST-001 → X-08.
- **Project/config/privacy:** PCFG-001/PSR-001 → SEC-01–03; PCFG-002/PSR-002 → M-01–03; PCFG-003/PSR-003 → M-04; PCFG-004 → M-05; PCFG-005 → dependency-lock subtask under M-04/M-07; PCFG-006 → E-03; PCFG-007 → M-07; PCFG-008/PSR-007 → E-01/E-02; PCFG-009 → E-04; PCFG-010/012 and PSR-008/009 → E-05; PCFG-011 → build-product probe under E-05; PSR-004 → M-21; PSR-005 → R-04; PSR-006 → M-22; PSR-010 → R-01.
- **Dead/partial/artifacts:** DCA-DEAD-001/002 → E-15; DCA-PART-001 → H-02/H-03; DCA-PART-002 → M-19; DCA-PART-003 → E-06; DCA-PART-004 → M-08; DCA-PART-005 → H-14; DCA-ART-001 → E-02; DCA-SAMPLE-001 → ownership subtask under E-15; DCA-DUP-001 → M-20.
- **Testing/release:** TRV-001 → M-04; TRV-002 → M-05; TRV-003 → M-06; TRV-004–006 → M-23; TRV-007 → X-06; TRV-008 → deterministic-clock subtask under M-23/H-12; TRV-009 → M-23; TRV-010/011 → H-13; TRV-012 → X-08; TRV-013/015 → M-06/M-23; TRV-014 → M-07; TRV-016 → X-08.

## Model A coverage and drop map

- **Backend:** A-B01 → X-02; A-B02 → X-01/X-06; A-B03 → X-07; A-B04 → M-14; A-B05/B09 → H-12; A-B06 → H-08; A-B07 → X-05; A-B10 → M-16; A-B11 → E-14. A-B08 is false for the concrete extractor and is dropped.
- **Frontend:** A-F01 → M-11; A-F02/F07/F10 → H-12/M-09; A-F03 → M-08; A-F04 → R-05/M-10; A-F05/F06 → M-09; A-F09 → E-15; A-F11/F13 → M-13/X-08; A-F12 → M-10; A-F14 → M-17. A-F08 is optional architecture cleanup and has no mandatory task.
- **Configuration:** A-C01 → R-02; A-C02 → M-01–03; A-C03 → SEC-01–03; A-C04 → E-01; A-C05 → M-04; A-C06 → R-01; A-C07/C09 → E-02; A-C08 → R-03; A-C11 → E-05; A-C12 → E-04 optional expansion. A-C10 is false and dropped.
- **Dead/partial:** A-D01–04/A-D07 → E-15; A-D05 → E-06; A-D06 → corrected per-symbol triage in E-15. A-D08/D09 are positive/no-action records.

## Official/current references used to qualify the audits

- Apple upload minimum: https://developer.apple.com/news/upcoming-requirements/
- Apple privacy manifests: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- Apple required-reason APIs: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- Apple route changes/headphone privacy: https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes
- Apple Liquid Glass custom-view guidance: https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views
- Apple export key behavior: https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption
- GitHub-hosted runner images: https://github.com/actions/runner-images

## Completion gate for the eventual remediation program

The remediation program is not complete until all of the following are recorded from the final current state:

1. Requirements sweep maps every approved task above to `VERIFIED`, `DROPPED(reason)`, or `BLOCKED(reason)`.
2. Stable Xcode 26 full unit/UI counts are positive, with every skip named and approved.
3. Debug and Release app/widget builds pass; lint and analysis pass.
4. A real prior-store migration preserves user data; import cancellation/duplicates/failures preserve media and database integrity.
5. Physical-device audio evidence covers routes, interruptions, background, remote commands, completion, gapless/crossfade, and any bit-perfect claim.
6. Accessibility, localization, Liquid Glass, and adaptive-layout matrices are captured.
7. Signed archive inspection confirms entitlements, manifests, privacy report, icon, export answer, App Group, and widget embedding.
8. App Store Connect validation completes without missing-reason, signing, export, or capability errors.
9. Final `git status`, diff/stat, secret scan, cleanup scan, and `git diff --check` explain every changed path.
