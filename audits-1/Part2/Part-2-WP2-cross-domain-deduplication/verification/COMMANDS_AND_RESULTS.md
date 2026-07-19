# WP2 verification commands and results

All repository operations were read-only. No Git remote write, source edit, build, or test command was attempted.

## Input package integrity

Python `zipfile` and SHA-256 checks were run against both input archives.

Original checkpoint:

```text
SHA256 aeba8b0f4ada6a99ff2e76ae0d9f60d118c6147a56ff1cb7c8fc882b64fe6a9e
FILES 13
UNSAFE []
CRC PASS
```

WP1 package:

```text
SHA256 5348606ff78fc2f04f1cfaa7de0646233fa7c5855dc787f88df6aaef33fc8c6f
FILES 16
UNSAFE []
CRC PASS
```

Repository baseline:

```text
REPO_HEAD=459db9bfd18d17960e8fd2ff8defc4701085532e
REPO_STATUS=
```

## Corpus normalization

```text
python3 verification/parse_audit_corpus.py PRIOR_REPORT_DIR WP1_REPORT evidence/NORMALIZED_FINDINGS.json
python3 -m py_compile verification/parse_audit_corpus.py
python3 -m json.tool evidence/NORMALIZED_FINDINGS.json
```

Result:

```text
CORPUS_PARSE=PASS
PARSER_PY_COMPILE=PASS
CORPUS_JSON=PASS
SOURCE_FINDINGS=147
UNIQUE_IDS=147
DUPLICATE_SOURCE_IDS=[]
PARSER_FIELD_GAPS=[]
```

## Candidate generation

```text
python3 verification/generate_dedup_candidates.py evidence/NORMALIZED_FINDINGS.json evidence/DEDUP_CANDIDATES.json
python3 -m py_compile verification/generate_dedup_candidates.py
python3 -m json.tool evidence/DEDUP_CANDIDATES.json
```

Result:

```text
CANDIDATE_GENERATION=PASS
CANDIDATE_SCRIPT_COMPILE=PASS
CANDIDATE_JSON=PASS
CANDIDATE_PAIRS=169
```

Candidate scores were used only for review order. They were not treated as merge evidence.

## Canonical-map build

```text
python3 verification/build_canonical_map.py evidence/NORMALIZED_FINDINGS.json evidence/DEDUP_DECISIONS.json CANONICAL_FINDINGS.json
python3 -m py_compile verification/build_canonical_map.py
python3 -m json.tool CANONICAL_FINDINGS.json
```

Result:

```text
CANONICAL_BUILD=PASS
CANONICAL_SCRIPT_COMPILE=PASS
CANONICAL_JSON=PASS
MERGED_CLUSTERS=26
MERGED_SOURCE_FINDINGS=55
STANDALONE_CANONICAL=92
CANONICAL_FINDINGS=118
DUPLICATE_RECORD_REDUCTION=29
```

## Human-readable outputs

```text
python3 verification/render_dedup_outputs.py CANONICAL_FINDINGS.json DEDUP_DECISION_LOG.md SOURCE_TO_CANONICAL.csv
python3 -m py_compile verification/render_dedup_outputs.py
```

Result:

```text
DEDUP_OUTPUT_RENDER=PASS
RENDER_SCRIPT_COMPILE=PASS
DECISION_LOG_CLUSTERS=26
MAPPING_ROWS=147
```

## Independent canonical-map verification

```text
python3 verification/verify_dedup_map.py evidence/NORMALIZED_FINDINGS.json evidence/DEDUP_DECISIONS.json CANONICAL_FINDINGS.json REPOSITORY
python3 -m py_compile verification/verify_dedup_map.py
python3 -m json.tool verification/DEDUP_VERIFICATION.json
```

Result:

```text
DEDUP_VERIFICATION=PASS
CHECKS=18
FAILURES=0
VERIFY_SCRIPT_COMPILE=PASS
VERIFY_JSON=PASS
```

Verified invariants:

- all 147 source IDs are unique and covered exactly once
- no normalized required field is missing
- 55 merged members are unique and resolve
- 26 canonical cluster IDs are unique
- all source records remain byte-for-byte equal as JSON data inside canonical members
- each accepted cluster has a connected location or explicit-related anchor graph
- highest source severity and location unions are correct
- source and canonical severity totals recompute
- all non-merge references resolve
- repository revision and clean state are unchanged

## Non-material command corrections

Two read-only summary commands initially failed because of shell/Python quoting or a stray brace. They were corrected immediately. Neither command wrote output used by the package, and no repository or deliverable data was changed by those failures.

The first package-validator run also rejected two intentionally redacted `Authorization: Bearer [REDACTED]` evidence lines and counted three near-duplicate table references as canonical table rows. The evidence was inspected with long tokens masked, confirmed redacted, and the validator was narrowed to reject only unredacted header lines and count only `CAN-###` rows in the canonical table. The corrected validation then passed.

## Final package checks

Validation covered the exact file allowlist, JSON/CSV/Markdown consistency, canonical counts, no caches, no prior-report files, sensitive-data patterns, repository revision and clean state, ZIP path safety, CRC, and byte-for-byte comparison of every archived entry.

Result:

```text
DIRECTORY_PACKAGE_VALIDATION=PASS
EXPECTED_FILES=23
ACTUAL_FILES=23
ALLOWLIST_EXACT=true
CSV_MAPPING_ROWS=147
REPORT_CANONICAL_ROWS=26
REPOSITORY_CLEAN=true
SENSITIVE_DATA_CANDIDATES=[]
PREVIOUS_REPORTS_INCLUDED=[]
ZIP_VALIDATION=PASS
ZIP_FILE_ENTRIES=23
ZIP_CRC=PASS
ZIP_PATH_SAFETY=PASS
ZIP_CONTENT_MATCH=true
```

The final archive validation is repeated after the last rebuild. The external validation result and final ZIP SHA-256 remain outside the ZIP to avoid a self-referential archive hash.