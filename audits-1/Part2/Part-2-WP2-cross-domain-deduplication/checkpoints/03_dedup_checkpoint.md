# WP2 canonical deduplication checkpoint

- Recorded: 2026-07-11T02:13:59Z
- Repository commit: 459db9bfd18d17960e8fd2ff8defc4701085532e
- Repository worktree: clean
- Repository mutation: none

## Canonical result

- Source findings: 147
- Accepted merged clusters: 26
- Source findings inside merged clusters: 55
- Retained standalone findings: 92
- Canonical findings: 118
- Duplicate-record reduction: 29, or 19.73%
- New defects: 0
- Source severity changes: 0

## Evidence preservation

Every source record is embedded unchanged inside its canonical record. The source-to-canonical map covers all 147 unique IDs. Canonical clusters preserve every member severity, domain, source pointer, location, evidence, impact, remediation, verification instruction, related IDs, and complete original finding-section text.

## Independent deterministic check

- Checks: 18
- Failures: 0
- Result: PASS

The pass covered source uniqueness, field completeness, cluster/member uniqueness, full corpus coverage, canonical totals, source-record equality, highest-severity derivation, location unions, cluster anchor connectivity, non-merge references, repository revision, and clean state.

## Created records

- CANONICAL_FINDINGS.json
- SOURCE_TO_CANONICAL.csv
- DEDUP_DECISION_LOG.md
- WP2_CROSS_DOMAIN_DEDUPLICATION.md
- evidence/DEDUP_DECISIONS.json
- evidence/DEDUP_CANDIDATES.json
- verification/DEDUP_VERIFICATION.json

## Remaining phase

Complete the continuation and file manifests, run final cross-file and sensitive-data checks, create the allowlisted ZIP, validate every archived byte, and deliver the six-item completion report.