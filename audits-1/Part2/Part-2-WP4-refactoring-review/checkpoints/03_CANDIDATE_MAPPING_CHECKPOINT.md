# Work Package 4 candidate-mapping checkpoint

## Timestamp

- Local: 2026-07-11 00:10:54 EDT
- UTC: 2026-07-11T04:10:54Z

## Phase outcome

The candidate map is complete. Eight refactoring opportunities were retained and six candidates were rejected or deferred after source and reachability checks.

### Retained

1. WP4-R01 — Consolidate the SwiftUI audio presentation-state boundary.
2. WP4-R02 — Separate queue mutations from notification and persistence side effects.
3. WP4-R03 — Give each library section explicit request ownership and load phase.
4. WP4-R04 — Move file-system operations and operation state out of FileManagerView.
5. WP4-R05 — Create one TrackDataActor insertion kernel before broader responsibility splitting.
6. WP4-R06 — Own AsyncStream producer lifetime and cancellation in FileImportProcessor.
7. WP4-R07 — Use one process-metrics provider instead of Mach probes inside AVAudioEngineAdapter.
8. WP4-R08 — Compile one canonical app/widget shared-data contract.

### Rejected or deferred

1. Size-only split of diagnostics declaration files — rejected.
2. Broad AVAudioEngineAdapter decomposition — rejected for this work package because of audio/device regression risk.
3. Standalone LibraryView private-type file moves — rejected as navigation-only churn.
4. Smart-playlist evaluator extraction — deferred to Work Package 5 after reachability showed the containing path appears orphaned.
5. ImportSession/FileImportProcessor consolidation — deferred to Work Package 5 because ImportSession appears test-only.
6. Size-only split of GlassModifiers.swift — rejected.

## Evidence produced

- evidence/01_SWIFT_MECHANICAL_INVENTORY.csv
- evidence/02_SYMBOL_REFERENCE_COUNTS.csv
- evidence/03_WIDGET_CONTRACT_COMPARISON.md
- evidence/04_SOURCE_EVIDENCE_INDEX.md
- evidence/05_CANDIDATE_MAP.md

## Methods applied

- Mechanical size, declaration, state-wrapper, Task, error, and singleton-I/O inventory across 325 Swift files.
- Symbol/reference counts across product and test Swift sources.
- Direct source tracing from active app roots to candidate code.
- Test inventory and negative reference checks.
- Exact app/widget contract comparison.
- Official Apple documentation check for Observation dependency tracking and AsyncStream termination cleanup.
- Axiom iOS Audit Agents, SwiftUI, Swift Concurrency, and Testing skill guidance applied to screening and validation planning.

## Repository mutation check

- Source changes: none
- Repository status entries: 0
- Minimal validation patch: not needed

## Next phase

Independently re-read every retained candidate, rank implementation order and dependencies, write agent-ready behavior-preserving plans and acceptance tests, then run all available non-Xcode verification commands.
