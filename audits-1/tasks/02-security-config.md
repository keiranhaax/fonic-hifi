# Security, Privacy & Configuration — AUDIT-001 … AUDIT-007

## AUDIT-001 — Remove retired Kilo Code configuration

- Status: [DONE]
- Priority: P0
- Audit sources: Model B (PCFG-001, PSR-001), Model A (A-C03), WP3-001, WP5 (CLN-001 part)
- Audit finding IDs: CAN-001
- Category: Security
- Severity: High (WP3 recalibrated from Critical; validity of credentials unverified, exposure confirmed)
- Difficulty: Easy
- Risk: Low
- Scope: Localized
- Estimated effort: S
- Implementation group: GROUP-01
- Depends on: —
- Blocks: —
- Related tasks: AUDIT-002
- Affected features: none (tooling config)
- Affected files or symbols: `.kilocode/**`, `.gitignore`
- Validation status: Completed 2026-07-16 — the owner retired Kilo Code and directed removal of the entire configuration folder
- Validation evidence: `.kilocode` is absent; `git ls-files --deleted -- .kilocode` reports all 9 formerly tracked paths; `.gitignore` covers `.kilocode/`

### Problem
The retired Kilo Code configuration, including credential-bearing local MCP settings, remained tracked in the repository and its history.

### Likely Root Cause
The Kilo Code folder was committed before the tool was retired; the prior ignore rule covered only `mcp.json` rather than the complete tool directory.

### Recommended Implementation
Delete `.kilocode/` completely and ignore the entire directory so obsolete local configuration cannot be reintroduced. Do not create a replacement template because the tool will no longer be used.

### Implementation Boundaries
Do not print or copy credential values anywhere. Do not rewrite history without explicit authorization. Preserve unrelated local-tool configuration and user changes.

### Acceptance Criteria
- [x] `.kilocode/` is physically absent from the working tree
- [x] All 9 formerly tracked `.kilocode` paths are recorded as deleted
- [x] `.gitignore` covers the entire `.kilocode/` directory
- [x] No credential value appears in task documentation or command output

### Suggested Verification
`test ! -e .kilocode`; `git ls-files --deleted -- .kilocode`; `git check-ignore --no-index -v .kilocode/probe`; `git diff --check`.

### Risks and Regression Areas
Deletion does not revoke historical provider credentials or erase existing Git history. Provider-side revocation remains prudent even though Kilo Code is retired.

### Notes
The owner explicitly scoped completion to full `.kilocode/` removal on 2026-07-16. `.claude/settings.local.json` was untracked by AUDIT-002 and its local copy was removed with the broader AUDIT-056 Claude purge.

### Implementation Record
- Started: 2026-07-16
- Completed: 2026-07-16
- Commit: Not requested
- Verification result: MATCH — `.kilocode` absent; 9 tracked paths deleted; directory-wide ignore rule matched; scoped `git diff --check` passed

## AUDIT-002 — Purge remaining tracked artifacts and duplicate documents

- Status: [DONE]
- Priority: P2
- Audit sources: Model B (PCFG-008, PSR-007, DCA-ART-001), WP5 (CLN-001 residual, CLN-007, CLN-009), Model A (A-C07/C09)
- Audit finding IDs: CAN-006 (residual)
- Category: Repository hygiene
- Severity: Medium
- Difficulty: Trivial
- Risk: Low
- Scope: Localized
- Estimated effort: XS
- Implementation group: GROUP-01
- Depends on: —
- Blocks: —
- Related tasks: AUDIT-052, AUDIT-053, AUDIT-056
- Affected features: none
- Affected files or symbols: `.claude/settings.local.json`, `sample/**/xcuserdata/*.plist` (3), `CLAUDE copy.md`, `docs/plans/2025-12-06-home-screen-discovery-design copy.md`, `log.md`, `EQ.md`, `Files-analysis.md`, `summary.md` (assess), `.AGENTS.md.backup.md` (untracked — leave), legacy empty AppIcon set (CLN-009)
- Validation status: Completed 2026-07-16 — eight scoped index removals staged; local copies of machine-local files preserved; duplicates and empty AppIcon set removed from disk
- Validation evidence: staged `D` for exactly 8 paths; local keep confirmed for `settings.local.json`, `log.md`, and 3 sample `xcuserdata` plists; ignore rules still match those paths; canonical home-design plan and `Fonic.icon/icon.json` present; acceptance scan empty for settings/log/copy/main AppIcon/sample xcuserdata

### Problem
Machine-local state, raw logs, and stale document copies remain tracked, defeating hygiene and confusing future readers.

### Likely Root Cause
Cleanup batches E-01/E-02 intentionally stopped at the main project; sample projects and docs were out of scope.

### Recommended Implementation
After ownership review, untrack `.claude/settings.local.json` without deleting its local copy. `git rm --cached` the sample `xcuserdata` plists and `log.md`; reconcile unique content from the two `copy` docs into their canonical files, then remove copies; assess `EQ.md`/`summary.md`/`Files-analysis.md` for archival under `docs/`; remove the empty legacy AppIcon set only after an archive build validates the `Fonic.icon` path (CLN-009 gate).

### Implementation Boundaries
One category per commit. Do not touch `Files/` (intentional historical archive, CLN-014). Do not delete local copies of removed files.

### Acceptance Criteria
- [x] `git ls-files` returns no local-config (`settings.local.json`), sample `xcuserdata`, raw-log (`log.md`), or `copy` doc / main AppIcon paths (staged removal; commit not requested)
- [x] Canonical docs retain the current content; removed copies contained only superseded guidance/design text
- [x] Release device build succeeds after AppIcon-set removal and compiles `Fonic.icon` as `--app-icon Fonic`

### Suggested Verification
`git ls-files | grep -E "xcuserdata|copy|^log\.md"` empty for AUDIT-002 classes; `git diff --cached --check`; local presence of untracked machine-local files.

### Risks and Regression Areas
Accidental deletion of a doc with unique content — diff each copy against canonical first.

### Notes
`.AGENTS.md.backup.md` and `music-file/` are untracked user files and were left alone. `EQ.md`, `Files-analysis.md`, and `summary.md` remain tracked because AUDIT-053 explicitly owns their validation/indexing. Full tracked `.claude/` tree, root `CLAUDE.md`, and sample `.claude` are **not** in this task; they are routed to AUDIT-056. Nested untracked `AGENTS.md` files can still block an unmodified Release build (duplicate bundle resources); prior asset validation used `EXCLUDED_SOURCE_FILE_NAMES=AGENTS.md` only as a command-line override.

### Implementation Record
- Started: 2026-07-16
- Completed: 2026-07-16
- Commit: Not requested (8 paths remain staged)
- Verification result: MATCH — staged deletions/untracks for 8 AUDIT-002 paths; machine-local files still on disk and ignored; copies and empty AppIcon absent; `Fonic.icon` present; `git diff --cached --check` clean

## AUDIT-003 — Fix widget AccentColor build-setting / asset mismatch

- Status: [DONE]
- Priority: P2
- Audit sources: Model B (PCFG-011)
- Audit finding IDs: PCFG-011
- Category: Project configuration
- Severity: Low
- Difficulty: Trivial
- Risk: Low
- Scope: Localized
- Estimated effort: XS
- Implementation group: —
- Depends on: —
- Blocks: —
- Related tasks: AUDIT-048 (widget builds)
- Affected features: Widget appearance
- Affected files or symbols: `Fonic HiFi.xcodeproj/project.pbxproj` widget Debug/Release build settings
- Validation status: Completed 2026-07-16 — the stale widget-only AccentColor setting was removed from both configurations
- Validation evidence: live build settings retain `AccentColor` on the app target but not the widget; fresh Debug and Release app+extension builds pass; the installed widget renders in light and dark appearances

### Problem
The widget target names an accent colorset that does not exist in its own asset catalogs; tint falls back silently and the setting is misleading.

### Likely Root Cause
Setting copied from the app target when the widget was created.

### Recommended Implementation
Clear the widget-target setting in Debug and Release. The app's existing `AccentColor` colorset contains no custom color, so adding a duplicate empty widget catalog would not change appearance.

### Implementation Boundaries
Widget target only; do not alter app-target asset settings or the shared palette definitions.

### Acceptance Criteria
- [x] Widget builds with no missing-asset warning
- [x] Widget tint matches the app's default accent behavior in light/dark screenshots

### Suggested Verification
Build app + extension; widget snapshot in light/dark.

### Risks and Regression Areas
None significant.

### Notes
The initial unmodified build was blocked by duplicate untracked nested `AGENTS.md` resources. Validation used the existing command-line-only `EXCLUDED_SOURCE_FILE_NAMES=AGENTS.md` workaround; no project setting was added for that separate issue. Xcode 27's Device Hub was used for light/dark widget screenshots after the Xcode IDE preview bridge timed out.

### Implementation Record
- Started: 2026-07-16
- Completed: 2026-07-16
- Commit: Not requested
- Verification result: MATCH — pbxproj parses; widget AccentColor setting absent in Debug/Release while app setting remains; fresh Debug and Release builds succeeded on iPhone 17 Pro (iOS 26.5); light/dark widget screenshots passed

## AUDIT-004 — Decide and reconcile APNs and Live Activity declarations

- Status: [BLOCKED]
- Priority: P2
- Audit sources: Model B (PCFG-010, PCFG-012, PSR-008, PSR-009), Model A (A-C11)
- Audit finding IDs: CAN-007, CAN-008
- Category: Project configuration / product
- Severity: Low
- Difficulty: Easy
- Risk: Medium (signing/entitlement change)
- Scope: Localized
- Estimated effort: S
- Implementation group: —
- Depends on: product decision (implement features vs. remove declarations)
- Blocks: —
- Related tasks: AUDIT-055 (archive validation)
- Affected features: none currently (declarations only)
- Affected files or symbols: `Fonic HiFi/Info.plist` (`NSSupportsLiveActivities`), `Fonic HiFi/Fonic_HiFi.entitlements` (`aps-environment`)
- Validation status: Confirmed — both declarations still present (rg 2026-07-15); no ActivityKit configuration or push registration exists
- Validation evidence: `rg -l "NSSupportsLiveActivities|aps-environment"` matches `Info.plist` and entitlements

### Problem
The app declares Live Activity support and carries an APNs entitlement with no implementing code — metadata drift that complicates review and signing.

### Likely Root Cause
Aspirational configuration added ahead of features that were never built (corroborated by `STATUS.md`).

### Recommended Implementation
Product decides: (a) remove both declarations via Xcode capability tooling, or (b) open separate feature epics for Now Playing Live Activity / push. If removing, verify processed Info.plist and entitlements in a Release archive.

### Implementation Boundaries
Do not change other entitlements, App Group, or signing. No feature implementation inside this task.

### Acceptance Criteria
- [ ] Declarations match the product decision exactly
- [ ] Release archive signs and validates with the resulting entitlement set

### Suggested Verification
`codesign -d --entitlements` on the archived app; App Store validation (with AUDIT-055).

### Risks and Regression Areas
Entitlement changes affect signing; coordinate with release owner.

### Notes
BLOCKED on product decision (ledger E-05).

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-005 — Close CI/config residuals: green-run evidence, dependency pinning, manifest and coverage checks

- Status: [BLOCKED]
- Priority: P1
- Audit sources: Model B (PCFG-005, TRV-013), WP3-002/003 residuals
- Audit finding IDs: PCFG-005, TRV-013, CAN-002 (residual), CAN-003 (residual)
- Category: CI / release engineering
- Severity: Medium
- Difficulty: Easy
- Risk: Low
- Scope: Future multi-file work (workflow, Makefile, docs)
- Estimated effort: S
- Implementation group: GROUP-01
- Depends on: owner decision to reintroduce CI; supported Xcode 27 runner/toolchain
- Blocks: —
- Related tasks: AUDIT-050, AUDIT-055, AUDIT-057
- Affected features: future CI pipeline
- Affected files or symbols: future `.github/workflows/ci.yml`; `Makefile` (`install-deps`, `coverage-check`); `Package.resolved`
- Validation status: Blocked 2026-07-18 — the owner directed removal of the failing Xcode 27 beta workflow until further notice
- Validation evidence: AUDIT-057 records the owner decision and verifies that no hosted workflow is active; local Makefile validation remains available

### Problem
Hosted CI is intentionally disabled because the available runner/toolchain contract has not reliably supported the project's Xcode 27 beta baseline. Dependency pin enforcement, deterministic tool versions, coverage behavior, and green-run evidence remain requirements for any future workflow.

### Likely Root Cause
The attempted hosted workflow depended on an unavailable or unreliable Xcode 27 beta runner contract. Repeated failures did not provide trustworthy project evidence.

### Recommended Implementation
Take no implementation action until the owner explicitly reintroduces CI. At that point: select a supported runner and Xcode 27 toolchain; enforce `Package.resolved`; pin development-tool versions; retain distinct unit/UI, Release, analyze, and coverage gates; then record a representative green run and artifact evidence.

### Implementation Boundaries
Do not recreate a workflow speculatively. No dependency updates, test-content changes, weakened coverage thresholds, or external CI writes without explicit scope.

### Acceptance Criteria
- [ ] Owner explicitly authorizes CI reintroduction and names the supported runner/toolchain
- [ ] CI fails if `Package.resolved` would change during resolution
- [ ] Unit/UI, Release, analyze, privacy-manifest, and coverage gates run with deterministic tool versions
- [ ] One green run and its coverage/test artifacts are recorded

### Suggested Verification
When unblocked, validate the workflow syntax locally, inspect the selected runner/Xcode lines, and review every gate's exit status and uploaded artifacts. No push or dispatch is authorized by this task alone.

### Risks and Regression Areas
Runner availability can regress independently of repository code. `make install-deps` performs package-manager writes and must not run locally without approval.

### Notes
The earlier workflow repair is historical evidence only. AUDIT-057 intentionally retires hosted CI; this task is the blocked reintroduction/evidence contract.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-006 — Remove `.public` logging of user library content and paths

- Status: [DONE]
- Priority: P1
- Audit sources: Model B (PSR-004), WP3-023
- Audit finding IDs: PSR-004
- Category: Privacy
- Severity: Medium (WP3 recalibrated; static interpolation confirmed, retention/sharing unverified)
- Difficulty: Easy
- Risk: Low
- Scope: Multi-file (batched)
- Estimated effort: S
- Implementation group: —
- Depends on: —
- Blocks: —
- Related tasks: AUDIT-007
- Affected features: logging/diagnostics
- Affected files or symbols: confirmed sites include `FileManagerView.swift:238-276,340-392`, `MetadataExtractionService.swift:142-170`, `FileImportProcessor.swift:368-400,587`, and other user-content logging call sites found by the acceptance scan
- Validation status: Completed 2026-07-16 — content-bearing public interpolations were redacted while operational fields remained public
- Validation evidence: two independent static probes found zero prohibited content-bearing `.public` interpolations; focused tests and the full unit target passed; Debug app+widget build passed

### Problem
Release-reachable os.Logger calls mark file paths, filenames, folder names, and metadata `.public`, defeating OSLog privacy redaction for user library content.

### Likely Root Cause
`.public` applied for debugging convenience without a data-classification pass.

### Recommended Implementation
One module per batch: replace `.public` on user-data interpolations with `.private` or the repo's `LogPrivacy` helpers; keep operational fields (counts, error codes) public. Add a lint/CI grep guard against `privacy: .public` on known user-data identifiers if practical.

### Implementation Boundaries
Do not delete log statements or change log levels/taxonomy; only privacy annotations. Follow `Log.logger(_:)` conventions (AGENTS.md §5).

### Acceptance Criteria
- [x] Static scan finds zero `.public` annotations on paths/titles/queries/filenames
- [x] Logs remain useful (operational counts, durations, booleans, formats, and state/type values remain public)
- [x] No `print()` introduced

### Suggested Verification
`rg "privacy: \.public" "Fonic HiFi"` review; build + focused tests of touched modules.

### Risks and Regression Areas
Over-redaction can hamper support diagnostics — keep counts/codes public.

### Notes
Ledger M-21. Batch by module to keep diffs reviewable.

### Implementation Record
- Started: 2026-07-16
- Completed: 2026-07-16
- Commit: Not requested
- Verification result: MATCH — two independent prohibited-content scans returned no matches; focused suites executed 39 tests with 0 failures; full `Fonic HiFiTests` executed 437 tests with 0 failures and 0 skips; Debug app+widget build succeeded; SwiftLint remains unavailable locally

## AUDIT-007 — Privacy disclosure, data map, backup/protection policy, export classification

- Status: [BLOCKED]
- Priority: P2
- Audit sources: Model B (PSR-005, PSR-006, PSR-010, DLP-018), Model A (A-C06)
- Audit finding IDs: PSR-005, PSR-006, PSR-010, DLP-018
- Category: Privacy / release policy
- Severity: Medium
- Difficulty: Moderate
- Risk: Low (documentation/policy) to Medium (file-attribute changes, if any)
- Scope: Cross-feature (policy) 
- Estimated effort: M
- Implementation group: —
- Depends on: owner decisions on backup policy and export classification
- Blocks: parts of AUDIT-055 (App Store answers)
- Related tasks: AUDIT-006
- Affected features: privacy disclosure UI, import file attributes, release metadata
- Affected files or symbols: privacy disclosure view (Settings), `FileImportProcessor` copy path (protection class), Info.plist (`ITSAppUsesNonExemptEncryption` absent)
- Validation status: Confirmed as policy gaps; PSR-005's technical premise (protection class propagation via `copyItem`) is unproven — measure on device before changing attributes
- Validation evidence: WP3/WP2 packages; ledger R-01/R-04 analysis (export-key omission triggers questionnaire, not automatic failure)

### Problem
In-app privacy disclosure omits material local data and retention/deletion behavior; imported-file protection/backup behavior is implicit; export compliance is undeclared.

### Likely Root Cause
Policy work was never done; these are owner determinations, not code defects.

### Recommended Implementation
Build a verified local-data map (stores, keys, media, logs, retention); update the in-app disclosure to match; measure destination file-protection class on device before any attribute change; record the export-compliance determination and add the key only when final.

### Implementation Boundaries
No file-attribute or backup-exclusion changes without device measurement and explicit owner sign-off. No CloudKit or sync scope.

### Acceptance Criteria
- [ ] Disclosure text matches actual current storage/retention/deletion
- [ ] Backup/protection decision recorded with device evidence
- [ ] Export determination recorded; key added only if final

### Suggested Verification
Manual review against the data map; device probe of protection attributes; archive privacy report (with AUDIT-055).

### Risks and Regression Areas
Wrong protection class could break locked-screen/background playback — that is why measurement precedes change.

### Notes
BLOCKED on owner/policy decisions (ledger M-22, R-01, R-04).

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:
