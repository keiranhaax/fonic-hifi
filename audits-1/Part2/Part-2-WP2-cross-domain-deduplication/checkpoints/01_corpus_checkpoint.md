# WP2 normalized corpus checkpoint

- Recorded: 2026-07-11T01:55:25Z
- Repository commit: 459db9bfd18d17960e8fd2ff8defc4701085532e
- Repository mutation: none

## Corpus result

The prior domain reports and completed WP1 Foundation Models report were parsed into `evidence/NORMALIZED_FINDINGS.json`.

- Source findings: 147
- Unique source IDs: 147
- Duplicate source IDs: 0
- Parser field gaps: 0

Counts by domain:

- Audio Reliability: 21
- Data, Library, and Persistence: 21
- Concurrency and Performance: 16
- UI and UX: 20
- Accessibility and Localization: 13
- Project Configuration: 12
- Privacy, Security, and Release: 10
- Dead, Partial, and Artifacts: 10
- Testing and Release Verification: 16
- Foundation Models: 8

Counts by source severity:

- Critical: 4
- High: 23
- Medium: 96
- Low: 17
- Informational: 7

## Preserved fields

Every normalized record includes source ID, title, severity, confidence, domain, source package, source report, report line range, extracted locations, evidence, domain impact, remediation, verification guidance, related IDs, and the complete original finding-section text.

## Validation

- Parser execution: PASS
- Parser Python syntax compilation: PASS
- Normalized JSON parsing: PASS
- Every finding ID unique: PASS
- Required parser fields present: PASS

## Next phase

One sub-agent may propose duplicate clusters from the normalized corpus. Its output will remain a candidate set until each cluster is independently checked against complete source sections, locations, root cause, and remediation.