# Fonic HiFi Project Cleanup Assessment and Phased Plan

## Outcome

Work Package 5 is complete as a read-only assessment. The repository does contain cleanup strategies, but only as fragmented historical plans and the prior dead-code inventory. None is adequate for the current commit. The repository needs a phased, reversible cleanup rather than a bulk deletion.

The highest-confidence cleanup is repository hygiene: tracked local configurations, raw logs, Xcode user state, stale backups, copy files, and the orphan Git link. Source cleanup is also justified, but it must happen later and in small Xcode-validated batches because 18 whole files and 61 symbol roots are only statically proven unreachable. No source file was deleted or modified in this work package.

## Scope and baseline

- Repository: https://github.com/keiranhaax/fonic-hifi
- Branch: main
- Commit: `459db9bfd18d17960e8fd2ff8defc4701085532e`
- Remote `main` at assessment start: same commit
- Worktree before and after assessment: clean
- Repository mutations: none
- Checkpoint manifest verification: PASS, 11 of 11 declared files matched
- Xcode, Apple SDK, simulator, device, signing, and App Store validation: unavailable in this Linux environment

## What already existed

The earlier checkpoint provided a strong `Dead Code, Completeness, and Repository Artifacts` report with reproducible inventories. The repository also includes several cleanup-oriented documents:

- `Files/Plan/mock2.plan`: September 2025 mock and stub cleanup
- `Files/plan2/files-summary.md`: proposal to synthesize and archive `/Files`
- `Files/Plan/Sheet.md`: narrow now-playing migration cleanup and rollback note
- `Files-analysis.md`: December 2025 documentation audit

These are useful inputs, but they are stale or partial. They reference missing files, conflict with current directory contents, omit current cleanup categories, and lack a current commit baseline plus phase-by-phase validation and rollback. The strategy verdict is therefore: partial historical strategy exists; adequate current strategy does not.

## Assessment summary

### Confirmed cleanup surface

- 14 tracked machine, local, generated, backup, or copy artifacts: 156,761 bytes and 3,306 physical lines
- 1 unusable mode-160000 Git link with no `.gitmodules` mapping
- 18 production-unreachable source files: 3,642 physical lines
- 61 unreferenced declaration roots inside otherwise live files
- 3 undocumented source-only sample roots: 18 files, nine Swift files, 775 Swift lines
- 3 manually duplicated app/widget data-contract pairs
- 6 substantive exact-content documentation duplicate groups
- Fragmented documentation across root, `docs`, `Files`, `.factory`, and tool-specific directories
- 1 empty `AppIcon.appiconset` superseded by the configured `Fonic.icon`, pending Xcode archive confirmation

### Negative findings and corrections

- No exact duplicate Swift source file group was found.
- No unused package dependency was found. AudioKit is declared, linked, and imported by production code.
- No unused shared scheme was found because no shared scheme or test plan is tracked.
- No build setting was classified unused from static Linux evidence.
- The four initially unreferenced sample color assets are actually used through generated Swift symbols. They are retained.
- Tool-specific duplicate workflow files and per-sample Xcode/asset boilerplate are retained.
- The 63-file historical archive is explicitly labeled. It is not a deletion target merely because it is large.

## Cleanup principles

1. Never combine behavior changes with repository cleanup.
2. Never delete from a dirty worktree.
3. One cleanup category per commit.
4. Record every removed or moved path, its replacement or canonical owner, and its validation result.
5. Treat compiler, macro, App Intent, WidgetKit, Codable, preview, selector, and migration reachability as Xcode-gated.
6. Use Git history as rollback. Do not create new `copy`, `backup`, or ad hoc archive files inside the active tree.
7. Do not restore revoked credentials during rollback.
8. Stop a phase immediately if its acceptance checks fail. Revert only that phase.

# Phased execution plan

## Phase 0: owner approval and Xcode-capable baseline

### Purpose

Establish a real release baseline before any removal.

### Actions

- Get explicit approval for the cleanup branch and for every architectural choice, especially source deletion and shared app/widget contracts.
- Create a dedicated cleanup branch from the audited commit or a later explicitly chosen commit.
- Capture `git status`, `git rev-parse HEAD`, tracked-file manifest, and clean-clone proof.
- In Xcode 26 or later, create and commit a shared app scheme and test plan if they remain part of the project's release contract. Include app, widget, unit, and UI-test targets intentionally.
- Run and record clean Debug and Release builds, static analysis, unit tests, UI tests, previews used by the team, and an unsigned simulator archive path where applicable.
- Capture the resolved compiled-source and resource lists for all four targets.
- Record the final package graph and `Package.resolved` state.

### Acceptance gate

Do not start deletion unless the repository has a repeatable Xcode baseline, a clean worktree, a portable shared test action, and a rollback point.

### Rollback

No product cleanup occurs in this phase. Revert only baseline-configuration commits if they fail review.

## Phase 1: credential and local-artifact hygiene

### Purpose

Remove the highest-confidence and highest-risk repository clutter first.

### Prerequisite

Complete the separate credential rotation and history-purge procedure already identified by the privacy/security audit. This plan does not reproduce secret values.

### Actions

- Correct `.gitignore` so the live `.xcodeproj`, shared schemes, test plan, and `Package.resolved` can remain tracked.
- Keep ignoring `xcuserdata`, raw logs, result bundles, derived data, local tool configuration, and PBX backups.
- Remove from the index:
  - `.claude/settings.local.json`
  - `.kilocode/mcp.json`
  - all six tracked `xcuserdata` files
  - `build_errors.log`
  - `build_verify.log`
  - `log.md`
  - `Fonic HiFi.xcodeproj/project.pbxproj.backup`
- Reconcile unique content from `CLAUDE copy.md` and `docs/plans/2025-12-06-home-screen-discovery-design copy.md` into canonical files only if still valid, then remove the copies.
- Keep sanitized templates only when a shared configuration is genuinely required.

### Validation

- `git ls-files` returns no local configurations, raw logs, `xcuserdata`, PBX backups, or copy files.
- The live project, lockfile, shared scheme, and test plan remain tracked.
- A clean checkout builds and tests using only portable configuration.
- Secret scanning passes without printing values.

### Rollback

Revert the cleanup commit for non-secret files. Restore local settings from a private local backup if needed, never from repository history. Do not restore revoked credentials.

## Phase 2: repair repository contracts

### Purpose

Remove structural Git and sample-tree ambiguity.

### Actions

- Decide whether `.claude/skills/ios-simulator-skill` is required.
  - If not required, remove the Git link.
  - If required, re-add it as a real submodule with an approved HTTPS URL and pinned commit.
- Decide the status of `sample/CustomGlassTabBar`, `sample/CustomMenu`, and `sample/CustomToolBottomBar`.
  - Preferred choices: consolidate into a buildable sample workspace, label as snippets, or remove after owner confirmation.
- Update `sample/README.md` so every retained root has provenance, license, purpose, and build status.

### Validation

- `git submodule status` exits zero.
- A recursive clean clone succeeds if a submodule is retained.
- Every directory called an application is buildable or explicitly labeled non-buildable.
- No sample `xcuserdata` is tracked.

### Rollback

Use separate commits for the Git link and sample changes. Revert independently.

## Phase 3: establish one documentation system

### Purpose

Remove duplicate sources and distinguish current guidance from history.

### Actions

- Create one documentation index with statuses: authoritative, active plan, reference, generated research, raw input, and historical.
- Choose canonical roots. A reasonable target is `docs/plans`, `docs/references`, and `docs/archive`, but final naming requires owner approval.
- Repair or remove the four broken `docs/references` links in `CLAUDE.md`.
- Remove the five exact active duplicates under `Files/plan2` after confirming `all.md` is still canonical; retain one archived copy.
- Keep only the archived copy of the exact duplicate code-analysis report unless the owner explicitly wants an active, reverified report.
- Archive stale root analyses such as `Files-analysis.md` and `summary.md` with dates and non-authoritative labels.
- Move `EQ.md` into the approved reference tree after rechecking code and Apple claims.
- Reconcile unique requirements from `Files/text.txt`, the Compass artifact, and the PDF into current authoritative documents. Then archive or remove the raw inputs according to the retention decision.
- Keep the intentionally labeled 63-file archive unless a separate retention policy is approved.
- Keep `.claude` and `.kilocode` tool documentation that is required by those tools, even where content is duplicated.

### Validation

- Every active document has one canonical path and an owner/status.
- Internal links resolve.
- No active and archived exact copy coexist without an explicit reason.
- `CLAUDE.md`, `AGENTS.md`, `README.md`, and `STATUS.md` reference current paths only.
- A documentation-only diff contains no source or project changes.

### Rollback

Use path-map commits small enough to revert independently. Do not create new backup copies in the active tree.

## Phase 4: resolve whole-file dead-code candidates

### Purpose

Reduce compile, index, review, and maintenance surface without removing framework entry points.

### Order

1. Three files with no production, test, or preview consumer:
   - `DataManager+SmartSearch.swift`
   - `GlassControls.swift`
   - `SearchPlaylistResultsView.swift`
2. Eight test-only implementation layers
3. Seven preview/self-only prototypes

### Required decision per file

- Connect to a named production owner
- Move test fixture/support to a test target
- Move approved prototype to a sample package
- Remove the obsolete file and its obsolete tests/previews

### Validation

For every small batch:

- Confirm resolved Xcode target membership.
- Run app and widget Debug and Release builds.
- Run all unit and UI tests.
- Run affected previews.
- Exercise relevant navigation, playback, search, import, and accessibility smoke paths.
- Run compiler-aware unused-code analysis and manually review macro, selector, App Intent, Codable, WidgetKit, and migration boundaries.

### Rollback

One file or cohesive pair per commit. Revert the smallest failing commit.

## Phase 5: prune unreferenced roots inside live files

### Purpose

Remove the 61 confirmed lexical roots without destabilizing active files.

### Order

1. Five private helpers
2. Six unreferenced declarations
3. Fifty internal/public method roots, grouped by owner

### Actions

- For each root, either name and test a real production call path or remove/narrow it.
- Do not retain parallel convenience APIs for hypothetical future use.
- Do not delete a framework-discovered or generated entry point based on token counts.

### Validation

Run the same Xcode matrix as Phase 4 plus focused owner tests. For audio, widget, and persistence owners, include device or migrated-store checks where relevant.

### Rollback

One owner group per commit. Revert only the failing owner group.

## Phase 6: consolidate duplicated contracts and assets

### Purpose

Remove drift-prone duplication and one high-confidence obsolete asset.

### Actions requiring explicit architectural approval

- Choose one canonical app/widget contract source compiled into both targets, or keep the copies with a mandatory semantic-diff guard and bidirectional Codable compatibility tests.
- After a clean Xcode archive proves `Fonic.icon` is authoritative, remove the empty `AppIcon.appiconset`.
- Do not alter `AccentColor` merely because its catalog entry is minimal; it is referenced by build settings.

### Validation

- Build both app and widget targets.
- Encode current and legacy payloads from each contract and decode in the other.
- Validate App Group reads and widget refresh on device.
- Validate all app icon appearances, App Store icon, Settings, search, notifications, and TestFlight.

### Rollback

Separate the contract and icon changes. Revert either independently.

## Phase 7: final clean-clone release verification

### Actions

- Clone recursively into a new directory.
- Confirm no local configuration, logs, backups, user state, or unresolved Git links are present.
- Resolve packages only from the reviewed lockfile.
- Run Debug, Release, analyze, unit, UI, widget, preview, and archive checks.
- Run secret scanning, internal-link validation, duplicate-file inventory, and compiler-aware unused-code analysis.
- Run physical-device playback, interruption, route-change, import, persistence, widget, accessibility, and app-icon smoke checks affected by cleanup.
- Compare app behavior and bundle contents to the Phase 0 baseline.

### Acceptance

Cleanup is complete only when the clean clone passes, the repository has one documented source of truth per concern, and no removed file is needed for a production, test, preview, tool, or framework path.

## Proposed phase commits

1. `chore(repo): establish cleanup guardrails and portable scheme`
2. `chore(repo): remove local and generated artifacts`
3. `chore(repo): repair simulator skill git contract`
4. `docs: consolidate active and archived guidance`
5. `chore(samples): document or remove source-only fragments`
6. `refactor(dead-code): resolve orphan source files in small batches`
7. `refactor(dead-code): prune unreferenced live-file roots`
8. `refactor(widget): remove shared-contract drift`
9. `chore(assets): remove superseded empty app icon catalog`

Commit names are suggestions only. No commit was created in this work package.

## Stop line

This plan is assessment-only. It does not authorize deletion, source rewiring, project restructuring, or architectural changes. Begin implementation only after the owner approves the phase and the Xcode baseline exists.
