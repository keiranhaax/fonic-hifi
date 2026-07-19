# Fonic HiFi Part 2, Work Package 2: Cross-domain deduplication

## TLDR

The 147 existing source findings reduce to 118 canonical findings without deleting evidence: 26 merged clusters contain 55 source records, 92 findings remain standalone, and 29 duplicate records are removed from the actionable count. No new defect was added, no source severity was changed, and the repository was not modified.

## Outcome

- Source findings: 147
- Unique source IDs: 147
- Accepted merged clusters: 26
- Source findings inside merged clusters: 55
- Retained standalone findings: 92
- Canonical findings after deduplication: 118
- Duplicate-record reduction: 29, or 19.73%
- New defects identified: 0
- Source findings rejected: 0
- Source severities changed or downgraded: 0
- Repository changes: 0

This package is a cross-domain normalization and deduplication result. It is not the independent Critical/High re-verification required by Work Package 3.

## Inputs

1. Original checkpoint: `fonic-hifi-production-audit-checkpoint-2026-07-09.zip`
   - SHA-256: `aeba8b0f4ada6a99ff2e76ae0d9f60d118c6147a56ff1cb7c8fc882b64fe6a9e`
   - Nine finding-domain reports plus the Apple-source dossier
   - Internal manifest: PASS
2. Completed WP1 package: `Part-2-WP1-foundation-models.zip`
   - SHA-256: `5348606ff78fc2f04f1cfaa7de0646233fa7c5855dc787f88df6aaef33fc8c6f`
   - Eight Foundation Models findings
   - Package validation: PASS
3. Repository baseline
   - Commit: `459db9bfd18d17960e8fd2ff8defc4701085532e`
   - Worktree: clean
   - Mutation: none

## Source corpus

| Domain | Source findings |
|---|---:|
| Audio Reliability | 21 |
| Data, Library, and Persistence | 21 |
| Concurrency and Performance | 16 |
| UI and UX | 20 |
| Accessibility and Localization | 13 |
| Project Configuration | 12 |
| Privacy, Security, and Release | 10 |
| Dead, Partial, and Artifacts | 10 |
| Testing and Release Verification | 16 |
| Foundation Models | 8 |
| Total | 147 |

Source severity totals are preserved exactly:

| Source severity | Count |
|---|---:|
| Critical | 4 |
| High | 23 |
| Medium | 96 |
| Low | 17 |
| Informational | 7 |

## Deduplication method

Every source finding was normalized with:

- source ID, title, severity, confidence, and domain
- source package/report and finding-section line range
- all extracted code/configuration locations
- evidence and excerpts
- domain-specific impact
- remediation and acceptance guidance
- explicit related IDs
- the complete original finding-section text

Candidate generation compared title, remediation, impact, location overlap, and explicit cross-links. It generated 169 review candidates. Candidate scores were triage only. A merge was accepted only after the complete source finding sections were compared.

A true duplicate required at least one of these:

1. the same root cause,
2. the same affected path and behavior,
3. one record being a clear domain-specific subset of another, or
4. materially identical remediation and acceptance criteria for the same defect.

Shared files, broad themes, or causal relationships were not enough by themselves.

## Severity rule

Each source severity remains attached to its member record. A canonical cluster receives the highest member severity only as a sorting and triage label. WP2 does not validate that severity.

Canonical highest-severity counts:

| Canonical highest severity | Count |
|---|---:|
| Critical | 2 |
| High | 21 |
| Medium | 75 |
| Low | 14 |
| Informational | 6 |
| Total | 118 |

## Accepted canonical clusters

| Canonical ID | Highest severity | Source IDs | Canonical defect |
|---|---|---|---|
| CAN-001 | Critical | PCFG-001, PSR-001 | Four live credentials and a sensitive local endpoint are committed |
| CAN-002 | Critical | PCFG-002, PSR-002 | App and widget lack required-reason privacy manifests |
| CAN-003 | High | PCFG-003, PSR-003, TRV-001 | CI selects an impossible and internally conflicting iOS 26 toolchain |
| CAN-004 | Medium | PCFG-004, TRV-002 | No committed shared scheme or test plan defines the CI test action |
| CAN-005 | Medium | PCFG-007, TRV-014 | Release, analyzer, archive, and distribution-signing behavior is not gated |
| CAN-006 | Medium | PCFG-008, PSR-007, DCA-ART-001 | Tracked local, generated, user-state, log, and backup artifacts defeat repository hygiene |
| CAN-007 | Low | PCFG-010, PSR-009 | Info.plist claims Live Activity support without an Activity configuration |
| CAN-008 | Low | PCFG-012, PSR-008 | The app carries an unused APNs capability |
| CAN-009 | High | DLP-004, DCA-PART-001 | Listening-session tracking exists but is never wired into production |
| CAN-010 | High | DLP-006, CP-004 | Concurrent import deduplication has a check-to-insert race |
| CAN-011 | Medium | DLP-012, CP-014 | Every pagination request hydrates the full result set to compute an unused count |
| CAN-012 | Medium | DLP-019, CP-005 | Listening-session replacement is unsequenced and can clear the new session |
| CAN-013 | High | DLP-021, CP-002 | Import cancellation does not propagate to AsyncStream producers |
| CAN-014 | Medium | AUD-QUEUE-001, UIUX-013 | Queue edit callbacks translate visible offsets to the wrong absolute indices |
| CAN-015 | Medium | AUD-SLEEP-001, UIUX-007 | Sleep-timer ownership is transient and fade volume starts from 1.0 |
| CAN-016 | Medium | AUD-DIAG-001, DCA-PART-005 | Audio diagnostics report synthetic zero metrics while polling an empty collector |
| CAN-017 | Medium | AUD-WIDGET-001, DLP-016, CP-006 | Widget synchronization is stale and poll-driven |
| CAN-018 | High | UIUX-015, A11Y-001 | Primary library and mini-player actions use raw gestures instead of semantic controls |
| CAN-019 | High | UIUX-020, A11Y-002 | The 10-band EQ is a drag-only, undersized, non-adjustable control |
| CAN-020 | Informational | A11YTEST-001, TRV-012 | Accessibility, Dynamic Type, locale, RTL, and widget behavior lack a real verification lane |
| CAN-021 | Medium | UIUX-019, FMA-001 | Surprise Me lacks a single-flight gate for its shared model session and playback side effects |
| CAN-022 | High | UIUX-009, FMA-004 | Failures are collapsed into silence, false emptiness, or generic fallback states |
| CAN-023 | Medium | AUD-DSP-001, DCA-PART-002 | Persisted EQ is not restored or reapplied across engine creation and switching |
| CAN-024 | High | AUD-CONFIG-001, UIUX-008 | Visible audio settings persist values but do not configure the active audio engine |
| CAN-025 | Medium | UIUX-006, A11Y-006 | Now Playing lacks an adaptive scroll/layout contract for short heights and Dynamic Type |
| CAN-026 | Medium | TRV-004, TRV-015 | Missing prerequisites and behavior are converted into passing test skips |

`DEDUP_DECISION_LOG.md` records the rationale, source severity, domain, source pointer, locations, impact, remediation, and evidence-preservation requirements for every accepted cluster.

## Important near-duplicates kept separate

The following groups were reviewed and deliberately not merged:

| IDs | Why they remain separate |
|---|---|
| DLP-003, TRV-010 | Production migration-plan defect versus absence of a real migration test |
| UIUX-011, FMA-003, FMA-005, DCA-PART-004 | Reachability, stale cancellation, fallback handoff, and playback integration are four defects |
| CAN-003, CAN-005 | Invalid toolchain versus missing Release/archive gates |
| CP-012, CAN-016 | Unbounded diagnostic retention versus false synthetic metrics |
| DLP-005, CAN-013 | File rollback after failure versus cancellation propagation |
| CAN-009, CAN-012, DLP-020 | Unwired tracking, replacement race, and incorrect listened-duration measurement |
| AUD-BIT-002, CAN-016 | Bit-perfect path verification versus diagnostic metric integrity |
| DLP-002, DLP-003 | Missing schema model versus migration-open sequencing |
| TRV-002, TRV-003 | Missing test-action contract versus aliases that fail to select targets |
| TRV-013, TRV-014 | Coverage evidence versus Release/archive gating |
| A11Y-001, A11YTEST-001 | Semantic-control implementation versus verification coverage |
| UIUX-005, UIUX-006 | Missing dismissal versus layout reachability |
| FMA-003, FMA-005 | Stale cancellation writes versus fallback handoff |
| CAN-001, CAN-006 | Secret rotation/history purge versus general artifact cleanup |
| AUD-TRANSITION-001, TRV-007 | Production transition defect versus missing output verification |
| AUD-FORMAT-001, AUD-FORMAT-002 | M4A classification versus advertised/detector format mismatch |

The complete non-merge rationale is in `evidence/DEDUP_DECISIONS.json`.

## Evidence preservation

No source finding was deleted or rewritten. `CANONICAL_FINDINGS.json` contains:

- all 118 canonical records,
- the full member record under each merged cluster,
- every original source severity,
- the union of all member locations,
- complete source finding sections,
- source-to-canonical mapping for all 147 IDs, and
- documented near-duplicate non-merges.

`SOURCE_TO_CANONICAL.csv` provides a compact 147-row mapping for later remediation and WP3 re-verification.

## Deterministic verification

The verification pass checked:

- normalized source count: 147
- unique source IDs: 147
- parser field gaps: 0
- accepted clusters: 26 unique canonical IDs
- merged member IDs: 55, each used once
- canonical findings: 118
- source-to-canonical map: 147 of 147
- full source-record preservation inside the canonical map
- highest-severity derivation for each cluster
- canonical location unions
- accepted-cluster path or explicit-related connectivity
- source and canonical severity totals
- non-merge reference resolution
- repository revision and clean state

Result: PASS, 18 checks, 0 failures.

## Sub-agent disposition

The single delegated duplicate-cluster scan returned no analyzable proposal. It was rejected in full. No sub-agent merge decision appears in this package.

## Limitations

- WP2 does not independently re-prove reachability, exploitability, runtime behavior, or source severity.
- Critical and High canonical findings still require Work Package 3 verification.
- Candidate similarity is not evidence; only the accepted decisions and preserved source records are authoritative for this package.
- No Xcode or Apple SDK was available, but WP2 did not require a build.

## Recommended next work package

Set `CURRENT WORK PACKAGE` to `3` for independent Critical and High re-verification. Use `CANONICAL_FINDINGS.json` and `SOURCE_TO_CANONICAL.csv` so every high-severity source record remains traceable while duplicate clusters are evaluated once with all member evidence.