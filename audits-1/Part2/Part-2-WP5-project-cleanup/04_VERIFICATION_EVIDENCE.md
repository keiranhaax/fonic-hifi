# Work Package 5 Verification Evidence

## Verification boundary

This evidence supports only the project-cleanup assessment at repository commit `459db9bfd18d17960e8fd2ff8defc4701085532e`. It does not re-verify unrelated product defects, Foundation Models behavior, prior Critical or High findings, or the separate refactoring work package.

## Input and checkpoint verification

| Check | Command or method | Result |
|---|---|---|
| Input ZIP hash | `sha256sum` | `aeba8b0f4ada6a99ff2e76ae0d9f60d118c6147a56ff1cb7c8fc882b64fe6a9e` |
| ZIP path safety | Python `zipfile` inventory rejecting absolute paths, parent traversal, backslashes, and symlinks | PASS: 15 entries, 13 files, zero unsafe entries |
| ZIP extraction | Manual streamed extraction after path validation | PASS: 565,520 uncompressed bytes |
| Embedded report manifest | Recomputed bytes, physical lines, and SHA-256 for every declared report | PASS: 11 of 11 |
| Prior package limitation review | Read checkpoint README and validation | Confirmed: no final synthesis, Xcode build, or device validation was claimed |

## Repository identity and immutability

| Check | Command | Result |
|---|---|---|
| Remote default branch | `git ls-remote --symref ... HEAD refs/heads/main` | `main` at audited commit |
| Clone | `git clone --no-tags --single-branch --branch main` | PASS |
| Local branch and commit | `git branch --show-current`; `git rev-parse HEAD` | `main`; audited commit |
| Baseline worktree | `git status --porcelain=v1 --untracked-files=all` | Clean |
| Tracked entries | `git ls-files` | 594 |
| Final worktree | `git status --porcelain`; `git diff --exit-code`; `git diff --cached --exit-code` | Clean; both diff checks exit 0 |
| Repository mutation | Direct comparison of baseline and final status | None |

## Deterministic cleanup inventories

| Check | Method | Result |
|---|---|---|
| Artifact inventory | Tracked-path patterns plus file sizes and physical line counts | 14 paths; 156,761 bytes; 3,306 lines |
| Ignore contradictions | `git check-ignore --no-index -v` over all tracked paths | 14 tracked paths matched current ignore rules, including live project metadata because `*.xcodeproj` is overbroad |
| Exact duplicate hashes | SHA-256 over all tracked regular files | 12 groups; zero exact duplicate Swift groups |
| Whole-file orphan reproduction | Path-scoped declaration extraction and token-boundary reference scan | 18 of 18 paths present; zero production reference paths; 3,642 lines; prior manifest hash reproduced |
| Whole-file candidate split | Same scan | 8 test-used; 7 preview-used; 3 with neither test nor preview consumer |
| Live-file root reproduction | 61 path-scoped symbol searches across all tracked Swift | 61 found at definitions; zero external product or test token occurrences |
| Undocumented samples | Git tracked-file inventory | 3 roots; 18 files; 9 Swift files; 775 Swift lines; no build containers |
| Historical archive | Git tracked-file inventory | 63 files; 798,582 bytes; 21,980 lines; prior path-manifest hash reproduced |
| Documentation topology | Tracked Markdown, plan, and text inventory | 207 documents across competing roots |
| Current Swift size | Tracked Swift inventory | 213 product files and 95 test files |

## Candidate-specific checks

### Git link

- `.gitmodules`: absent.
- `git submodule status`: exit 128, no mapping for `.claude/skills/ios-simulator-skill`.
- `git cat-file -t` for the recorded Git-link object: exit 128, object unavailable.
- `git fsck --full`: exit 0.

Conclusion: the Git link is unusable as a submodule contract, but `git fsck` does not support calling the entire repository corrupt.

### Local configurations

A redacted structural scan parsed both local configuration files as valid JSON and found non-placeholder credential or endpoint markers in both. The scan recorded only file paths, line numbers, marker types, and hashes of the containing lines. No value was printed into a deliverable.

Conclusion: remove the local configurations from tracking after the separate credential-rotation and history-purge procedure.

### Copy and backup files

- `CLAUDE.md` versus `CLAUDE copy.md`: 277 added and 217 deleted lines in the copy-side comparison; the copy contains stale Live Activity architecture.
- Canonical home-design plan versus its `copy` file: 12 added and 42 deleted lines; the copy preserves an older mechanism.
- PBX backup: `objectVersion = 77` versus live `objectVersion = 90`.

Conclusion: reconcile unique valid content before removing the copy files; the PBX backup is stale.

### App/widget shared contracts

`git diff --no-index --numstat` showed two header-line changes in each of three pairs. Hashing content after line 7 produced identical hashes for each pair.

Conclusion: the contracts are duplicated but aligned now. Consolidation needs Xcode target and Codable compatibility validation.

### Assets and resources

The first inventory searched only asset names such as `Artwork1` and reported four no-reference sample colors. Manual source review found generated Swift symbol use:

- `.playerBackground`
- `.artwork1`
- `.artwork2`
- `.artwork3`

The inventory was corrected to search generated lower-camel symbols. Final result: zero non-system asset sets without references.

A separate current-source check found the empty `AppIcon.appiconset` while both app configurations select `Fonic` and the active `Fonic.icon` references its SVG layer. Apple's Icon Composer documentation states that the Icon Composer file replaces an existing app-icon asset catalog and that the App Icon field must match the `.icon` filename.

Official source: https://developer.apple.com/documentation/Xcode/creating-your-app-icon-using-icon-composer

Conclusion: sample colors are retained; the empty AppIcon set is a high-confidence but Xcode-gated cleanup candidate.

### Dependencies

- `Package.resolved` contains one pin: AudioKit.
- The Xcode project declares and links the AudioKit product to the app target.
- `AudioKitEngineAdapter.swift:8` imports AudioKit.

Conclusion: no unused Swift package dependency was confirmed.

### Schemes and build settings

- Shared `.xcscheme` count: 0.
- `.xctestplan` count: 0.
- User-specific scheme-management plists are tracked.

Conclusion: remove the user-state plists. There is no shared scheme to classify unused. No build setting was declared unused without Xcode-resolved evidence.

## Static format checks

| Check | Result |
|---|---|
| JSON and plist parsing over tracked metadata | PASS: 38 of 38 |
| Repository Python script AST parse | PASS: `scripts/coverage_summary.py` |
| Swift parser | Not run; `swiftc` unavailable |
| YAML parser | Not run; PyYAML unavailable |
| Xcode project listing/build/test/archive | Not run; Xcode unavailable |
| `make check-deps` | Could not start because `make` is unavailable in the sandbox |

The historical tracked build logs were inspected only as artifact evidence. They are not current build proof.

## Sub-agent handling

Two sequential, never-parallel narrow delegation attempts were made after the pre-delegation checkpoint. Both returned no analyzable cleanup report because their file-result handling failed. No sub-agent statement was used as evidence. All retained and rejected classifications in this package come from direct repository inspection and deterministic checks recorded above.

## Non-material tooling retries

- One initial copy-file diff used relative paths from the wrong working directory and could not access the files. It was rerun with absolute paths.
- One inline Python display command had a quoting syntax error. It was rerun successfully.

Neither retry touched the repository or changed a finding.

## Required Xcode follow-up

The following remain `UNVERIFIED - needs Xcode/build/device check`:

1. Resolved source and resource membership for all synchronized groups.
2. Safe removal of any Swift file or live-file declaration.
3. App and widget compilation after shared-contract consolidation.
4. Macro, App Intent, selector, Codable, WidgetKit, preview, and migration reachability.
5. App icon generation and App Store validation after removing the empty AppIcon set.
6. Build, test, static-analysis, archive, signing, and physical-device behavior after cleanup.
