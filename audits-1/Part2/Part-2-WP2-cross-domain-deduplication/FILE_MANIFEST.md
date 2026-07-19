# Part 2 WP2 file manifest

Every file in `Part-2-WP2-cross-domain-deduplication.zip` was created or modified during Work Package 2. The archive excludes the repository, prior ZIP contents, prior reports, source files, build products, dependency checkouts, caches, and unrelated artifacts.

| File | Why it is included |
|---|---|
| `WP2_CROSS_DOMAIN_DEDUPLICATION.md` | Standalone WP2 outcome, method, counts, accepted cluster summary, non-merge summary, verification, and limitations. |
| `CANONICAL_FINDINGS.json` | Complete 118-record canonical map with all 147 source records preserved under their canonical owner. |
| `SOURCE_TO_CANONICAL.csv` | Compact 147-row source-to-canonical mapping for WP3 and remediation tracking. |
| `DEDUP_DECISION_LOG.md` | Human-readable accepted-cluster rationale, source evidence pointers, impacts, remediation, and preserved distinctions. |
| `CONTINUATION_MANIFEST.json` | Completed WP2 continuation state, inspected inputs, created files, commands, checkpoints, and limitations. |
| `FILE_MANIFEST.md` | Lists every packaged file and its purpose. |
| `evidence/NORMALIZED_FINDINGS.json` | Deterministic normalized corpus with every complete original finding section. |
| `evidence/DEDUP_CANDIDATES.json` | Reproducible 169-pair similarity triage output; not authoritative merge evidence. |
| `evidence/DEDUP_DECISIONS.json` | Authoritative 26 accepted cluster decisions and 16 documented non-merge groups. |
| `verification/parse_audit_corpus.py` | Reproducible prior-report and WP1 finding parser. |
| `verification/generate_dedup_candidates.py` | Reproducible candidate-pair generator. |
| `verification/build_canonical_map.py` | Canonical-map builder with coverage, severity, and evidence-preservation logic. |
| `verification/render_dedup_outputs.py` | Generates the decision log and CSV mapping from the canonical records. |
| `verification/verify_dedup_map.py` | Independent 18-check canonical-map and repository-state verifier. |
| `verification/DEDUP_VERIFICATION.json` | Captured PASS result from the independent verifier. |
| `verification/REVERIFICATION_LOG.md` | Lead second-pass decisions, severity guardrails, non-merge guardrails, and sub-agent rejection record. |
| `verification/COMMANDS_AND_RESULTS.md` | Commands and observed outcomes for input, corpus, candidate, canonical, verification, and package phases. |
| `verification/PACKAGE_VALIDATION.json` | Final allowlist, format, count, sensitive-data, hash, repository-state, and package validation. |
| `checkpoints/00_initial_checkpoint.md` | Input and scope checkpoint created before delegation. |
| `checkpoints/01_corpus_checkpoint.md` | Normalized 147-finding corpus checkpoint. |
| `checkpoints/02_delegation_checkpoint.md` | Delegation result and rejection of the unusable payload. |
| `checkpoints/03_dedup_checkpoint.md` | Canonical clustering and deterministic verification checkpoint. |
| `checkpoints/04_final_checkpoint.md` | Final pre-package completion checkpoint. |
