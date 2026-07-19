# Work Package 4 verification commands and results

Repository: `main` at `459db9bfd18d17960e8fd2ff8defc4701085532e`.

## Successful checks

### Input and baseline

1. Python SHA-256 of the supplied checkpoint ZIP
   Result: PASS
   SHA-256: `aeba8b0f4ada6a99ff2e76ae0d9f60d118c6147a56ff1cb7c8fc882b64fe6a9e`

2. `git -C /agent/workspace/wp4-audit/repo rev-parse HEAD`
   Result: PASS
   Output: `459db9bfd18d17960e8fd2ff8defc4701085532e`

3. `git -C /agent/workspace/wp4-audit/repo status --porcelain=v1`
   Result: PASS
   Output entries: `0`

4. `git -C /agent/workspace/wp4-audit/repo cat-file -t 459db9bfd18d17960e8fd2ff8defc4701085532e`
   Result: PASS
   Output: `commit`

### Static evidence

5. `python3 /agent/workspace/wp4-audit/work/verify_wp4_evidence.py`
   Result: PASS
   Checks: `23 passed, 0 failed`
   Machine-readable result: `evidence/06_STATIC_VERIFICATION.json`

The checks cover repository identity/cleanliness, input hash, Swift inventory, three app/widget contract pairs, audio environment/state ownership, Now Playing state mirrors, queue mutation/persistence path, Library request state, FileManager direct I/O/test boundary, single/batch Track insertion duplication, AsyncStream termination ownership, duplicate process metric probes, deferred-code reachability, and evidence-file presence.

6. `git -C /agent/workspace/wp4-audit/repo diff --check`
   Result: PASS

7. `git -C /agent/workspace/wp4-audit/repo diff --exit-code`
   Result: PASS

8. `python3 -m py_compile` for the four analysis/verification scripts
   Result: PASS

### Generated evidence validation

9. Python comparison of the app/widget `WidgetConstants.swift`, `WidgetPlaybackState.swift`, and `WidgetTrackInfo.swift` bodies from line 8 onward
   Result: PASS for all three pairs

10. Python mechanical inventory
    Result: PASS
    Swift files: `325`
    Physical Swift lines: `60,262`

11. Python symbol/reference inventory
    Result: PASS
    Output: `evidence/02_SYMBOL_REFERENCE_COUNTS.csv`

## Attempted but unavailable

1. `make -C /agent/workspace/wp4-audit/repo check-deps`
   Result: NOT RUN
   Shell result: exit `127`, `make: command not found`

2. `make -C /agent/workspace/wp4-audit/repo lint`
   Result: NOT RUN
   Shell result: exit `127`, `make: command not found`

3. `swift --version`
   Result: unavailable

4. `xcodebuild -version`
   Result: unavailable

5. `swiftlint version`
   Result: unavailable

6. `swiftformat --version`
   Result: unavailable

7. `xcrun --version`
   Result: unavailable

## Not claimed

No Swift parse/type-check, Xcode build, unit/UI test execution, SwiftLint, SwiftFormat, Xcode Analyze, Thread Sanitizer, simulator/device run, Instruments trace, signing, TestFlight, or App Store Connect validation was performed.

## Repository mutation result

- Source files modified: `0`
- Source files added: `0`
- Source files deleted: `0`
- Worktree status after verification: clean
