# Security, Privacy & Configuration — AUDIT-001 … AUDIT-007

## AUDIT-001 — Rotate exposed credentials and untrack local tool configuration

- Status: [BLOCKED]
- Priority: P0
- Audit sources: Model B (PCFG-001, PSR-001), Model A (A-C03), WP3-001, WP5 (CLN-001 part)
- Audit finding IDs: CAN-001
- Category: Security
- Severity: High (WP3 recalibrated from Critical; validity of credentials unverified, exposure confirmed)
- Difficulty: Easy
- Risk: Low (repo-side); rotation itself is external
- Scope: Localized
- Estimated effort: S
- Implementation group: GROUP-01
- Depends on: provider-side rotation (user/provider action)
- Blocks: AUDIT-002 (final removal of the two config files)
- Related tasks: AUDIT-002
- Affected features: none (tooling config)
- Affected files or symbols: `.claude/settings.local.json`, `.kilocode/mcp.json`, `.gitignore`
- Validation status: Confirmed — both files remain tracked (`git ls-files`, 2026-07-15); repository is public per prior ledger evidence
- Validation evidence: `git ls-files | grep settings.local` returns both paths; WP3-001 evidence package (redacted)

### Problem
Credential/endpoint-bearing local tool configuration is tracked in a public repository (and its history). Until rotated, the values must be treated as compromised.

### Likely Root Cause
Local tool configs were committed before ignore rules covered them.

### Recommended Implementation
1. (External, owner) Rotate/revoke every exposed value at each provider; verify replacement works via environment/keychain injection. 2. `git rm --cached` both files, confirm ignore rules cover them, and (only if needed) add redacted templates. 3. Decide separately whether to rewrite history (requires explicit authorization — ledger SEC-03).

### Implementation Boundaries
Do not print or copy credential values anywhere. Do not rewrite history without explicit authorization. Do not delete users' local copies of the files.

### Acceptance Criteria
- [ ] Provider dashboards confirm old values revoked, replacements active
- [ ] `git ls-files` returns neither path; local tooling still starts
- [ ] Two independent secret scanners pass on the prospective commit
- [ ] No credential value appears in any commit message, doc, or template

### Suggested Verification
`git ls-files | grep -E "settings.local|mcp.json"` empty; secret scan (e.g. gitleaks) on staged diff; tool smoke start.

### Risks and Regression Areas
Local tooling breakage if env/keychain injection is not set up before untracking.

### Notes
BLOCKED on user/provider rotation (ledger SEC-01). The repo-side untracking (SEC-02) can be prepared but should land after rotation.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-002 — Purge remaining tracked artifacts and duplicate documents

- Status: [TODO]
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
- Depends on: AUDIT-001 (only for the two credential configs; the rest can proceed now)
- Blocks: —
- Related tasks: AUDIT-052, AUDIT-053
- Affected features: none
- Affected files or symbols: `sample/**/xcuserdata/*.plist` (3), `CLAUDE copy.md`, `docs/plans/2025-12-06-home-screen-discovery-design copy.md`, `log.md`, `EQ.md`, `Files-analysis.md`, `summary.md` (assess), `.AGENTS.md.backup.md` (untracked — leave), legacy empty AppIcon set (CLN-009)
- Validation status: Confirmed partial — main-project `xcuserdata`, backup pbxproj, and build logs already removed (ledger E-02, commits `b64b89d`, `814bf5e`); the listed paths remain tracked as of 2026-07-15
- Validation evidence: `git ls-files` output 2026-07-15 shows the 3 sample `xcuserdata` plists, both `copy` docs, and `log.md` still tracked

### Problem
Machine-local state, raw logs, and stale document copies remain tracked, defeating hygiene and confusing future readers.

### Likely Root Cause
Cleanup batches E-01/E-02 intentionally stopped at the main project; sample projects and docs were out of scope.

### Recommended Implementation
`git rm --cached` the sample `xcuserdata` plists and `log.md`; reconcile unique content from the two `copy` docs into their canonical files, then remove copies; assess `EQ.md`/`summary.md`/`Files-analysis.md` for archival under `docs/`; remove the empty legacy AppIcon set only after an archive build validates the `Fonic.icon` path (CLN-009 gate).

### Implementation Boundaries
One category per commit. Do not touch `Files/` (intentional historical archive, CLN-014). Do not delete local copies of removed files.

### Acceptance Criteria
- [ ] `git ls-files` returns no `xcuserdata`, raw-log, or `copy` doc paths
- [ ] Unique content from removed copies preserved in canonical docs
- [ ] Build still succeeds after AppIcon-set removal (if performed)

### Suggested Verification
`git ls-files | grep -E "xcuserdata|copy|^log\.md"` empty; `git diff --check`; simulator build after asset removal.

### Risks and Regression Areas
Accidental deletion of a doc with unique content — diff each copy against canonical first.

### Notes
`.AGENTS.md.backup.md` and `music-file/` are untracked user files; leave them alone.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-003 — Fix widget AccentColor build-setting / asset mismatch

- Status: [TODO]
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
- Affected files or symbols: `Fonic HiFi.xcodeproj/project.pbxproj:717-720,749-752` (`ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor` for the widget target); widget target has no `.xcassets` colorset
- Validation status: Confirmed (revalidated 2026-07-15)
- Validation evidence: pbxproj lines cited; no widget colorset exists under the widget synchronized root

### Problem
The widget target names an accent colorset that does not exist in its own asset catalogs; tint falls back silently and the setting is misleading.

### Likely Root Cause
Setting copied from the app target when the widget was created.

### Recommended Implementation
Either add an `AccentColor` colorset to a widget asset catalog (matching the app palette) or clear the widget-target setting. Prefer adding the asset for visual parity.

### Implementation Boundaries
Widget target only; do not alter app-target asset settings or the shared palette definitions.

### Acceptance Criteria
- [ ] Widget builds with no missing-asset warning
- [ ] Widget tint matches app accent in light/dark snapshots

### Suggested Verification
Build app + extension; widget snapshot in light/dark.

### Risks and Regression Areas
None significant.

### Notes
Requires editing `project.pbxproj` — a genuine build-setting change, permitted by repo rules for this purpose.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

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

- Status: [TODO]
- Priority: P1
- Audit sources: Model B (PCFG-005, TRV-013), WP3-002/003 residuals
- Audit finding IDs: PCFG-005, TRV-013, CAN-002 (residual), CAN-003 (residual)
- Category: CI / release engineering
- Severity: Medium
- Difficulty: Easy
- Risk: Low
- Scope: Multi-file (workflow, Makefile, docs)
- Estimated effort: S
- Implementation group: GROUP-01
- Depends on: —
- Blocks: —
- Related tasks: AUDIT-050, AUDIT-055
- Affected features: CI pipeline
- Affected files or symbols: `.github/workflows/ci.yml`, `Makefile` (`install-deps`, `coverage-check`), `Package.resolved`
- Validation status: Partially fixed — CI workflow was rebuilt (stable Xcode 26 selection, split unit/UI, Release+analyze gates all present); pin enforcement and a recorded green run remain open
- Validation evidence: `ci.yml:10-80` (2026-07-15); prior ledger noted 20 consecutive failed runs *before* the rework — no post-rework green run is recorded in the repo

### Problem
The rebuilt CI is unproven (no recorded green run), dependency/tool resolution is not fully pin-enforced (PCFG-005), and coverage evidence is not retained in-repo (TRV-013).

### Likely Root Cause
CI rework landed recently; enforcement and evidence steps were not part of it.

### Recommended Implementation
1. Trigger CI and record the run result; fix any residual workflow break. 2. Enforce `Package.resolved` (e.g. `-disableAutomaticPackageResolution` or resolved-file check step). 3. Verify `make install-deps` in CI is deterministic and doesn't drift tool versions. 4. Retain coverage summary artifacts and document thresholds.

### Implementation Boundaries
No dependency updates. Do not change test content. Do not weaken coverage thresholds.

### Acceptance Criteria
- [ ] One green CI run on `main` recorded (link/ID in ledger)
- [ ] CI fails if `Package.resolved` would change during resolution
- [ ] Coverage artifacts retained per run; threshold behavior documented

### Suggested Verification
Push a trivial docs commit or manually dispatch the workflow; inspect run logs for the selected Xcode line and per-step exit codes.

### Risks and Regression Areas
`make install-deps` requires Homebrew installs — CI-only; do not run locally without approval.

### Notes
CAN-003's core fix is DONE (register #2); this task carries only the evidence/enforcement tail.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

## AUDIT-006 — Remove `.public` logging of user library content and paths

- Status: [TODO]
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
- Affected files or symbols: ~17 sites incl. `FileManagerView.swift:238-276,340-392`, `MetadataExtractionService.swift:142-170`, `FileImportProcessor.swift:368-400,587`
- Validation status: Confirmed (revalidated 2026-07-15, ~17 remaining `.public` user-data sites)
- Validation evidence: rg sweep by validation agent, examples cited above

### Problem
Release-reachable os.Logger calls mark file paths, filenames, folder names, and metadata `.public`, defeating OSLog privacy redaction for user library content.

### Likely Root Cause
`.public` applied for debugging convenience without a data-classification pass.

### Recommended Implementation
One module per batch: replace `.public` on user-data interpolations with `.private` or the repo's `LogPrivacy` helpers; keep operational fields (counts, error codes) public. Add a lint/CI grep guard against `privacy: .public` on known user-data identifiers if practical.

### Implementation Boundaries
Do not delete log statements or change log levels/taxonomy; only privacy annotations. Follow `Log.logger(_:)` conventions (AGENTS.md §5).

### Acceptance Criteria
- [ ] Static scan finds zero `.public` annotations on paths/titles/queries/filenames
- [ ] Logs remain useful (operational fields still public)
- [ ] No `print()` introduced

### Suggested Verification
`rg "privacy: \.public" "Fonic HiFi"` review; build + focused tests of touched modules.

### Risks and Regression Areas
Over-redaction can hamper support diagnostics — keep counts/codes public.

### Notes
Ledger M-21. Batch by module to keep diffs reviewable.

### Implementation Record
- Started:
- Completed:
- Commit:
- Verification result:

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
