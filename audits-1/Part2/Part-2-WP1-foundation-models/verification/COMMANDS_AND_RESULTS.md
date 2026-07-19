# WP1 verification commands and results

All repository commands were read-only. Paths are local sandbox paths; no repository remote write was attempted.

## Baseline package

### Archive safety and inventory

Command class: Python `zipfile` inspection plus SHA-256.

Result:

- SHA-256: `aeba8b0f4ada6a99ff2e76ae0d9f60d118c6147a56ff1cb7c8fc882b64fe6a9e`
- Entries: 15
- Uncompressed bytes: 565,520
- Unsafe absolute or parent-traversal paths: none

### Prior manifest verification

Command class: Python recomputation of every expected file’s byte count, line count, and SHA-256 from `CHECKPOINT_MANIFEST.json`.

Result:

```text
VALIDATED 11
MISSING []
ERRORS []
RESULT PASS
```

## Repository baseline

### Fresh clone and revision

```text
GIT_TERMINAL_PROMPT=0 git clone --filter=blob:none --no-tags https://github.com/keiranhaax/fonic-hifi.git /agent/workspace/fonic-wp1/repo/fonic-hifi
git -C /agent/workspace/fonic-wp1/repo/fonic-hifi status --short --branch
git -C /agent/workspace/fonic-wp1/repo/fonic-hifi rev-parse HEAD
git -C /agent/workspace/fonic-wp1/repo/fonic-hifi branch --show-current
```

Result:

```text
## main...origin/main
459db9bfd18d17960e8fd2ff8defc4701085532e
main
```

A later `git status --porcelain=v1` returned an empty string.

### Tracked-file inventory

Command class: Python plus `git ls-files`, with SHA-256 for the first-order review set.

Result:

```text
TRACKED_FILES 594
TRACKED_SWIFT 325
STATUS ''
```

## Toolchain availability

```text
swift --version
command -v xcodebuild
command -v swiftlint
```

Result:

```text
swift: command not found
xcodebuild: not found
swiftlint: not found
```

Consequences:

- No Swift parse or compile check was possible.
- No Xcode app/test build was possible.
- No Simulator, eligible-device Foundation Models run, Instruments trace, signing, or TestFlight/App Store check was possible.

## Scoped structural verification

```text
python3 /agent/workspace/fonic-wp1/deliverable/verification/verify_foundation_models.py /agent/workspace/fonic-wp1/repo/fonic-hifi > /agent/workspace/fonic-wp1/deliverable/verification/structural-verification.json
python3 -m py_compile /agent/workspace/fonic-wp1/deliverable/verification/verify_foundation_models.py
```

Result:

```text
STRUCTURAL_CHECK=PASS
PY_COMPILE=PASS
```

The captured JSON verifies only source structure. It is not a compile or runtime pass. Verified facts include:

- three direct product imports of `FoundationModels`
- two cached `LanguageModelSession` properties/constructions
- three `respond` calls
- two availability checks
- four `@Generable` schemas
- three exact-count array guides
- no product `isResponding` guard
- no product locale-support preflight
- no Foundation Models tool, URLSession use, or HTTP literal in direct AI code
- clean repository at the audited commit

## Integrity checks completed before drafting

```text
git -C /agent/workspace/fonic-wp1/repo/fonic-hifi diff --check
test -z "$(git -C /agent/workspace/fonic-wp1/repo/fonic-hifi status --porcelain=v1)"
python3 -m json.tool /agent/workspace/fonic-wp1/deliverable/CONTINUATION_MANIFEST.json
python3 -m json.tool /agent/workspace/fonic-wp1/deliverable/verification/structural-verification.json
```

Result:

```text
GIT_DIFF_CHECK=PASS
REPOSITORY_CLEAN=PASS
MANIFEST_JSON=PASS
STRUCTURAL_JSON=PASS
```

## Independent evidence re-verification

```text
python3 /agent/workspace/fonic-wp1/deliverable/verification/reverify_findings.py /agent/workspace/fonic-wp1/repo/fonic-hifi /agent/workspace/fonic-wp1/deliverable
python3 -m py_compile /agent/workspace/fonic-wp1/deliverable/verification/reverify_findings.py
```

Result:

```text
EVIDENCE_REVERIFICATION=PASS
REVERIFIER_PY_COMPILE=PASS
FAILED_CHECKS=0
```

The re-verifier checked each finding’s source predicates, the full FMA-001 through FMA-008 set, the 7 Medium / 1 Low severity totals, and the existence of every cited source file and primary line range.

## Final package validation

Validation covered the exact file allowlist, JSON parsing, finding-count consistency, repository revision and clean state, sensitive-data patterns, ZIP path safety, CRC, and byte-for-byte comparison between every archived entry and its source deliverable.

Result:

```text
DIRECTORY_PACKAGE_VALIDATION=PASS
EXPECTED_FILES=16
ACTUAL_FILES=16
ALLOWLIST_EXACT=true
REPOSITORY_CLEAN=true
SENSITIVE_DATA_CANDIDATES=[]
ZIP_VALIDATION=PASS
ZIP_FILE_ENTRIES=16
ZIP_CRC=PASS
ZIP_PATH_SAFETY=PASS
ZIP_CONTENT_MATCH=true
```

The final archive validation is repeated after the last rebuild. The external validation result and final ZIP SHA-256 are kept outside the ZIP to avoid a self-referential archive hash.
