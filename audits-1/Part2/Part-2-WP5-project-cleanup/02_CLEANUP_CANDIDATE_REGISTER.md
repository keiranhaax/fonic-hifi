# Work Package 5 Cleanup Candidate Register

## Baseline

- Repository: https://github.com/keiranhaax/fonic-hifi
- Branch: main
- Commit: 459db9bfd18d17960e8fd2ff8defc4701085532e
- Mode: read-only static assessment
- Repository files changed: none

## Disposition meanings

- Remove from index: confirmed repository-local or generated material; preserve a local copy only if still needed.
- Remove later: strong cleanup candidate, but only after the stated validation gate.
- Consolidate: duplicate or fragmented ownership; select a canonical source before removing copies.
- Archive or relocate: content may be worth retaining, but its current location or status is misleading.
- Keep: evidence does not support cleanup.
- Investigate: insufficient static evidence for removal.

## Summary

| ID | Area | Disposition | Confidence | Scope |
|---|---|---|---|---|
| CLN-001 | Tracked machine, local, generated, backup, and copy artifacts | Remove from index or reconcile | Confirmed | 14 paths, 156,761 bytes, 3,306 physical lines |
| CLN-002 | Orphan Git link | Remove or repair after ownership decision | Confirmed | 1 mode-160000 entry |
| CLN-003 | Production-unreachable source files | Remove later, move, or wire intentionally | Confirmed lexical reachability; Xcode gate required | 18 files, 3,642 physical lines |
| CLN-004 | Unreferenced symbol roots in live files | Remove later or connect intentionally | Confirmed lexical absence; Xcode gate required | 61 roots |
| CLN-005 | Undocumented source-only samples | Document, make buildable, relabel as snippets, or remove later | Confirmed | 3 roots, 18 files, 9 Swift files, 775 Swift lines |
| CLN-006 | App and widget contract copies | Consolidate or add drift guard | Confirmed duplication | 3 mirrored source pairs |
| CLN-007 | Exact duplicate documentation | Remove redundant active copies after canonical-source check | Confirmed | 6 substantive groups |
| CLN-008 | Documentation tree fragmentation and stale plans | Archive, relocate, and index | Confirmed | Multiple competing roots and stale references |
| CLN-009 | Empty legacy AppIcon asset set | Remove later after Xcode archive validation | High | 1 asset set |
| CLN-010 | Dependency cleanup | Keep AudioKit | Confirmed active | 1 package dependency, 1 production import |
| CLN-011 | Shared schemes and build settings | No unused shared scheme or build setting confirmed | Negative finding | Shared schemes 0; test plans 0 |
| CLN-012 | Asset false positive correction | Keep sample colors and preview asset path | Confirmed | 4 colorsets plus preview catalog |
| CLN-013 | Exact duplicate false positives | Keep required or tool-specific boilerplate copies | Confirmed | Cross-tool and per-project boilerplate groups |
| CLN-014 | Explicit historical archive | Keep as historical corpus for now | Confirmed intentional archive | 63 files, 798,582 bytes, 21,980 lines |
| CLN-015 | Current cleanup strategy | Replace fragmented historical plans with phased plan | Confirmed inadequate | Partial plans exist, but no current commit-anchored strategy |

## CLN-001: tracked local and generated artifacts

### Evidence

The deterministic tracked-file inventory found 14 cleanup paths totaling 156,761 bytes and 3,306 physical lines:

1. `.claude/settings.local.json`
2. `.kilocode/mcp.json`
3. `CLAUDE copy.md`
4. `Fonic HiFi.xcodeproj/project.pbxproj.backup`
5. `Fonic HiFi.xcodeproj/project.xcworkspace/xcuserdata/keiran.xcuserdatad/IDEFindNavigatorScopes.plist`
6. `Fonic HiFi.xcodeproj/xcuserdata/keiran.xcuserdatad/xcschemes/xcschememanagement.plist`
7. `Fonic HiFi.xcodeproj/xcuserdata/willy.xcuserdatad/xcschemes/xcschememanagement.plist`
8. `build_errors.log`
9. `build_verify.log`
10. `docs/plans/2025-12-06-home-screen-discovery-design copy.md`
11. `log.md`
12. `sample/AppleMusicBottomBar/AppleMusicBottomBar.xcodeproj/xcuserdata/balajivenkatesh.xcuserdatad/xcschemes/xcschememanagement.plist`
13. `sample/AppleMusicBottomBar/AppleMusicBottomBar.xcodeproj/xcuserdata/keiran.xcuserdatad/xcschemes/xcschememanagement.plist`
14. `sample/AppleMusicMiniPlayer/AppleMusicMiniPlayer.xcodeproj/xcuserdata/balajivenkatesh.xcuserdatad/xcschemes/xcschememanagement.plist`

Supporting source evidence:

- `.gitignore:5-6` already declares `xcuserdata/`, but the six user-state files remain tracked.
- `.gitignore:22` repeats the same `xcuserdata/` rule.
- `.gitignore:37-38` ignores `Package.resolved` and every `*.xcodeproj`, contradicting the repository's need to version its project and lockfile.
- `.gitignore:108` contains the malformed combined entry `.apdiskbuild_verify.log`, which does not provide a general build-log rule.
- `Fonic HiFi.xcodeproj/project.pbxproj.backup:6` says `objectVersion = 77;`; the live project says `objectVersion = 90;` at `Fonic HiFi.xcodeproj/project.pbxproj:6`.
- `build_errors.log:1-31` is dependency and lint transcript output.
- `build_verify.log:30-40` is a historical local build transcript.
- `log.md:1-10` begins with raw runtime and Core Data diagnostics.
- A redacted structural scan found non-placeholder credential or endpoint markers in both local configuration files. Values are intentionally not reproduced.
- `CLAUDE copy.md:133-145` documents Live Activity files that `STATUS.md:65-74` explicitly says do not exist or are not planned.
- The home-design copy differs from the canonical file by 12 added and 42 deleted lines and preserves an older interaction mechanism.

### Disposition

- Remove the six `xcuserdata` paths, three raw logs, stale PBX backup, and two local configuration files from Git tracking.
- Reconcile any unique content from the two `copy` documents into their canonical files, then remove the copies.
- Rotate and history-purge exposed credentials under the already identified security remediation before treating local-config deletion as complete. This work package does not repeat or implement the security repair.
- Correct `.gitignore` before cleanup so the live Xcode project, shared schemes, and `Package.resolved` remain versionable while local artifacts remain ignored.

### Validation and rollback

- Work in one cleanup branch with one category per commit.
- Preserve local-only settings outside the repository before removing from the index.
- Verify `git ls-files` returns none of the cleanup paths.
- Verify the live project, lockfile, future shared scheme, and test plan remain tracked.
- Secret scanning must pass without printing values.
- Roll back by reverting the category commit. Do not restore revoked credentials.

## CLN-002: orphan Git link

### Evidence

- Git tree entry: `.claude/skills/ios-simulator-skill`, mode `160000`, object `fe4c14d565eac1ddd4f6baee53c6ca9c33b1dd83`.
- `.gitmodules` is absent.
- `git submodule status` exits 128: no submodule mapping exists for the path.
- `git cat-file -t` for the recorded object exits 128 because the object is unavailable.
- `git fsck --full` exits 0, so this should be described as an unusable submodule contract, not generalized repository corruption.

### Disposition

Determine ownership. If the simulator skill is unnecessary, remove the Git link. If required, re-add it as a real submodule using a reviewed HTTPS URL and pinned commit. Do not invent the missing upstream.

### Validation and rollback

- Removal path: a clean clone has no tree entry and `git submodule status` exits 0.
- Retention path: `.gitmodules` maps the exact path, the object is fetchable, and recursive clone succeeds.
- Roll back by reverting the dedicated Git-link commit.

## CLN-003: 18 production-unreachable source files

Independent token-boundary scanning at the current commit confirmed all 18 paths exist, their primary declarations have zero external production references, eight have test-only references, seven have preview entry points, and three have neither production, test, nor preview consumers. The path manifest and 3,642-line total reproduce the earlier audit hash `21246b4b87cb5be1f4de437cf4562a739bb5119e0081fa5593b5914271649892`.

| Path | Lines | Static disposition |
|---|---:|---|
| `Fonic HiFi/Core/Audio/Cache/TrackCache.swift` | 216 | Test-only alternate cache layer |
| `Fonic HiFi/Core/Audio/Diagnostics/PlaybackDiagnostics/PlaybackDiagnosticFormatters.swift` | 100 | Formatter APIs used only by tests |
| `Fonic HiFi/Core/Audio/Playback/PlaybackStateStore.swift` | 261 | Test-only alternate state layer |
| `Fonic HiFi/Core/Services/AudioSettingsService.swift` | 41 | Test-only wrapper |
| `Fonic HiFi/Data/DataManager+SmartSearch.swift` | 18 | No external consumer |
| `Fonic HiFi/Data/Services/ImportSession.swift` | 490 | Test-only alternate import layer |
| `Fonic HiFi/Data/Services/SearchCache.swift` | 311 | Test-only cache not integrated into active search |
| `Fonic HiFi/Presentation/ViewModels/Library/LibraryFilter.swift` | 36 | Test-only filter abstraction |
| `Fonic HiFi/Presentation/Views/Components/AccessibilityEnhancements.swift` | 458 | Preview/self-only prototype |
| `Fonic HiFi/Presentation/Views/Components/BottomSearchBar.swift` | 197 | Preview/self-only prototype |
| `Fonic HiFi/Presentation/Views/Components/ErrorView.swift` | 332 | Preview/self-only alternate error surface |
| `Fonic HiFi/Presentation/Views/Components/GlassControls.swift` | 128 | No external consumer |
| `Fonic HiFi/Presentation/Views/Components/LiquidGlassRail.swift` | 316 | Preview/self-only prototype |
| `Fonic HiFi/Presentation/Views/Components/LiquidGlassTabBar.swift` | 166 | Preview/self-only alternate tab bar |
| `Fonic HiFi/Presentation/Views/Library/AlbumGridView.swift` | 294 | Preview/self-only alternate library layer |
| `Fonic HiFi/Presentation/Views/NowPlaying/DiagnosticsDetailView.swift` | 153 | Preview/self-only diagnostics screen |
| `Fonic HiFi/Presentation/Views/Search/SearchPlaylistResultsView.swift` | 85 | No external consumer |
| `Fonic HiFi/Utils/MainActorHelpers.swift` | 40 | Test-only helpers |

The project uses file-system-synchronized app and widget roots and excludes only `Info.plist` (`project.pbxproj:61-104,168-253`), so these app-tree files are expected target inputs. Xcode must still confirm resolved compiled sources.

### Disposition

Do not mass-delete. For each file, choose one of four outcomes: name its production owner and connect it, move a reusable fixture to the test target, move an approved prototype to a clearly labeled sample package, or remove it with its obsolete tests/previews. Start with the three no-consumer files, then test-only layers, then preview prototypes.

### Validation and rollback

- One file or cohesive pair per commit.
- Before each removal, capture all references and target membership with Xcode.
- Run app, widget, unit, UI, Debug, and Release checks after every small batch.
- Exercise retained previews before moving them.
- Revert the individual commit if any compiled source, preview, navigation, or test breaks.

## CLN-004: 61 unreferenced symbol roots in live files

A path-scoped independent scan found all 61 declarations at the current commit and zero external product or test token occurrences. The set comprises 50 method roots, six declarations, and five private helpers across 24 files. Representative evidence:

- `AudioKitEngineAdapter.swift:389-408`: `audioFormatName`, `getBitDepthFromFormat`
- `AVAudioEngineAdapter.swift:552-556`: `handlePlaybackCompletion`
- `FileImportProcessor.swift:536-542,556-577`: `scanDirectory`, `copyFileToContainer`
- `PlaybackStateManager.swift:202,246,268,285,366-390`: unused query, synchronization, and transition methods
- `GlassModifiers.swift:345-370,500-572`: unused modifiers and `BatteryOptimizedGlassUtilities`

### Disposition

Remove private helpers first after compiler confirmation. For internal/public roots, either attach them to an existing owner with a test of the real execution path or remove/narrow them. Do not infer framework deadness from token counts alone.

### Validation and rollback

Use an Xcode-capable unused-code tool plus clean Debug and Release builds, all tests, previews, App Intents, WidgetKit, Codable, macros, selectors, and migration checks. Revert per small symbol batch.

## CLN-005: three undocumented source-only samples

### Evidence

`sample/README.md:5-15` documents only `AppleMusicBottomBar` and `AppleMusicMiniPlayer`. Three other roots contain app entry candidates but no Xcode project, workspace, or package manifest:

- `sample/CustomGlassTabBar`: 7 tracked files
- `sample/CustomMenu`: 6 tracked files
- `sample/CustomToolBottomBar`: 5 tracked files

Combined: 18 files, nine Swift files, 775 Swift lines.

### Disposition

If still valuable, document provenance and license, consolidate into a buildable sample workspace, or relabel them as non-buildable snippets. Otherwise remove them after owner confirmation. Keep the two documented samples, but remove their tracked `xcuserdata` under CLN-001.

### Validation and rollback

A clean checkout must either build every directory called an application or identify it explicitly as a snippet. Make sample cleanup a separate commit and revert that commit if any referenced implementation or license record is lost.

## CLN-006: mirrored app and widget contracts

### Evidence

Three pairs differ only in the first seven header lines; their bodies have matching SHA-256 values:

- `Fonic HiFi/Shared/WidgetConstants.swift` and `Fonic HiFi Widget/Shared/WidgetConstants.swift`
- `Fonic HiFi/Shared/WidgetPlaybackState.swift` and `Fonic HiFi Widget/Shared/WidgetPlaybackState.swift`
- `Fonic HiFi/Shared/WidgetTrackInfo.swift` and `Fonic HiFi Widget/Shared/WidgetTrackInfo.swift`

The widget copies state at line 5 that they are standalone copies. The risk is future Codable and key drift, not current duplicate-symbol failure because the files compile in separate modules.

### Disposition

Choose, with approval, either one canonical source compiled into both targets or a mandatory semantic-diff plus bidirectional encode/decode compatibility test. No project restructuring is performed in this assessment.

### Validation and rollback

Build app and widget targets, encode representative and legacy payloads in each module, decode in the other, and verify App Group behavior on device. Revert the target-membership commit if either target loses the contract.

## CLN-007: exact duplicate documentation

Six substantive exact-content duplicate groups are cleanup candidates:

- `Files/plan2/ai.md` and `Files/plan2/archive/ai.md`
- `Files/plan2/features.md` and `Files/plan2/archive/features.md`
- `Files/plan2/prd.md` and `Files/plan2/archive/prd.md`
- `Files/plan2/roadmap.md` and `Files/plan2/archive/roadmap.md`
- `Files/plan2/files-summary.md` and `Files/plan2/archive/files-summary.md`
- `Files/Code_Analysis_Report.md` and `Files/Archive/agents/gemini.md`

`Files/plan2/archive/README.md:3-8,94-119` says the five planning files were archived into `all.md` to leave one active source. Their exact duplicates in the active directory contradict that policy.

### Disposition

Remove the five active duplicate planning files after confirming `all.md` remains the intended canonical plan. Keep one archived copy. For the code-analysis report, keep the archived copy and remove or replace the active duplicate because its findings were not reverified in this work package.

### Validation and rollback

Record canonical ownership in an index, verify inbound links, run a link/path scan, and use a dedicated documentation-only commit.

## CLN-008: fragmented and stale documentation structure

### Evidence

The repository contains 207 tracked Markdown, plan, or text documents spread across competing roots, including:

- `.factory/docs`: 27
- `docs/plans`: 10
- `Files/Plan`: 7
- `Files/plan2`: 9 active plus 6 archived
- `Files/docs`: 19
- `Files/Archive`: 57
- repository root: 9

Specific contradictions:

- `Files/Plan/README.md:3-5` says the directory is intentionally minimal, but six other plan files remain beside it.
- `Files/plan2/files-summary.md:1-3,33-38` proposes archiving or removing `/Files` after synthesis, but line 35 requires a nonexistent `plan2/prd2.md`.
- `Files-analysis.md:3-13` is a December 2025 audit of a local `/Files` path, not a current repository-wide strategy.
- `summary.md:3-15,21-36` reports a 2025 snapshot with 172 Swift files and stale architecture; the current product has 213 Swift files.
- `CLAUDE.md:46-53` links four documents under `docs/references/`, but that directory and all four targets are absent.
- `Files/text.txt:1-8,84-88` is a raw conversation-style requirements input.
- `Files/compass_artifact_wf-6370d5fc-cf08-4b73-8c4f-7675edb1e462_text_markdown.md:1-5` is a generated research artifact with a workflow identifier in its filename.
- `EQ.md:1-5` is a technical reference placed at the repository root rather than under a documented reference tree.

### Disposition

Create one current documentation index with statuses: authoritative, active plan, historical, generated research, and raw input. Archive stale generated analyses and raw inputs only after mapping unique requirements into the current PRD or reference set. Move `EQ.md` into the chosen reference tree after validating its code claims. Repair or remove broken `CLAUDE.md` links. Do not delete the historical archive wholesale.

### Validation and rollback

Generate a before/after path map, check inbound links, and preserve Git history through small documentation commits. Roll back each move independently if an agent workflow or link breaks.

## CLN-009: empty AppIcon catalog superseded by Icon Composer

### Evidence

- `Fonic HiFi.xcodeproj/project.pbxproj:373,421` sets the primary app icon name to `Fonic` in Debug and Release.
- `Fonic HiFi/Fonic.icon/icon.json:36-38` references its SVG layer.
- `Fonic HiFi/Assets.xcassets/AppIcon.appiconset/Contents.json:1-34` contains three empty image declarations and no filenames.
- Apple states that an Icon Composer file replaces the existing icon asset catalog, and the App Icon field must match the `.icon` filename without its extension: https://developer.apple.com/documentation/Xcode/creating-your-app-icon-using-icon-composer

### Disposition

Treat the empty `AppIcon.appiconset` as a high-confidence cleanup candidate, not an immediate deletion. Remove it only after an Xcode 26 clean archive proves `Fonic.icon` supplies all required app icon variants and App Store validation remains clean.

### Validation and rollback

Archive before and after removal; inspect the built bundle and App Store icon; validate light, dark, tinted, and TestFlight rendering. Revert the asset-only commit if any variant is missing.

## CLN-010: dependency review

The project declares one Swift package, AudioKit, in `Package.resolved:3-12` and `project.pbxproj:826-842`. The app target links it at `project.pbxproj:107-113,168-190`, and production source imports it at `AudioKitEngineAdapter.swift:8`. No unused package dependency is statically supported. Keep AudioKit. Dependency version, supply-chain, and audio correctness issues belong to other work packages.

## CLN-011: schemes and build settings

No shared `.xcscheme` or `.xctestplan` is tracked, so there is no unused shared scheme to remove. The user-specific scheme-management plists are cleanup items under CLN-001, but they are not portable scheme definitions. No build setting was classified unused from Linux-only static evidence. Missing shared scheme/test-plan coverage is a release-configuration gap from the prior audit, not a deletion target.

## CLN-012: corrected asset false positive

The first lexical inventory missed generated Swift asset symbols and flagged four sample colorsets. Direct source verification rejected that result:

- `ExpandableMusicPlayer.swift:29` uses `.playerBackground`.
- `ExpandableMusicPlayer.swift:32` uses `.artwork1`, `.artwork2`, and `.artwork3`.
- `DEVELOPMENT_ASSET_PATHS` references the sample preview-content directory in Debug and Release.

Disposition: keep all four colorsets and the preview asset catalog. The corrected inventory reports zero non-system asset sets without textual or generated-symbol references.

## CLN-013: exact duplicate false positives

Keep these duplicate groups because duplication is structural or tool-specific:

- `.claude/commands/plan.md` and `.kilocode/workflows/plan.md`: separate tool discovery locations.
- AppIcon, AccentColor, and catalog `Contents.json` files across independent sample projects: required per-project asset-catalog boilerplate.
- Workspace `contents.xcworkspacedata` files across independent projects: required Xcode project boilerplate.

The duplicated sample `xcuserdata` plists are not kept; they remain CLN-001 cleanup items.

## CLN-014: intentional archive

The 63 paths under `Files/Archive` and `Files/plan2/archive` total 798,582 bytes and 21,980 physical lines. `Files/Archive/README.md:1-9` explicitly marks that corpus historical and non-representative. Size alone is not proof of clutter. Keep the archive unless the owner adopts a retention limit. Remove only exact redundant active/archive copies under CLN-007.

## CLN-015: cleanup strategy adequacy

Historical cleanup strategies do exist:

- `Files/Plan/mock2.plan:1-24,77-128,185-206` defines a September 2025 mock/stub cleanup.
- `Files/plan2/files-summary.md:1-3,29-38` proposes synthesizing and then archiving `/Files`.
- `Files/Plan/Sheet.md:393-425` contains a narrow UI migration cleanup and rollback note.
- The checkpoint's `reports/08_Dead_Partial_Artifacts.md` provides a strong candidate inventory and per-finding verification guidance.

They are not an adequate current cleanup strategy because they predate the current repository state, contain paths that no longer exist, conflict with current directory contents, do not cover all requested cleanup categories, and do not define a commit-anchored, phased, reversible execution order. Work Package 5 therefore creates a new phased cleanup plan without applying it.
