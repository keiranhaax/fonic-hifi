# Project Configuration & Hygiene Audit — Fonic HiFi

**Audit date:** 2026-07-09 · **HEAD:** `459db9b` (2026-02-06, "refactor(home): replace album overlay with Liquid Glass sheet")
**Scope:** READ-ONLY static inspection (Linux sandbox, no Xcode/build). Main project `Fonic HiFi.xcodeproj` + 2 sample projects under `sample/`.
**Method note:** pbxproj files read as plain text. Main project uses **folder-reference file inclusion** (`PBXFileSystemSynchronizedRootGroup`, objectVersion 90) — see finding H4; source files are auto-included from disk, so classic "dangling file reference" detection does not apply the way it would for explicit membership.

## Summary (worst first)
- **CRITICAL — No app icon shipped.** `AppIcon.appiconset` contains only `Contents.json` (3 entries, zero `filename` keys, zero PNGs). App Store rejects binaries with no 1024px marketing icon. Compounded by the app-icon build setting pointing at a *different* asset (`ASSETCATALOG_COMPILER_APPICON_NAME = Fonic`).
- **CRITICAL — No privacy manifest anywhere.** Zero `PrivacyInfo.xcprivacy` in the repo. Required by App Store since 2024. App uses `UserDefaults` (required-reason API, category `NSPrivacyAccessedAPICategoryUserDefaults`) in 28 files but declares no reason.
- **CRITICAL — Live API tokens committed to VCS.** 4 secrets in tracked dev-tooling config: Brave key, Exa key, apple-rag Bearer token (`.kilocode/mcp.json`), and an omnisearch `X-API-Key` (`.claude/settings.local.json`). Not app-shipping keys, but real credentials leaked in git history.
- **HIGH — `.gitignore` ignores the entire Xcode project** (`*.xcodeproj`, line 38) and `Package.resolved` (line 37), yet both are tracked. New project/dependency changes will be silently missed by `git add`. Line 108 is a corrupted merge (`.apdiskbuild_verify.log`).
- **HIGH — CI selects Xcode 16.1, which cannot build this project.** Project is objectVersion 90 / iOS 26 / widget `CreatedOnToolsVersion 26.0`. `ci.yml` runs `xcode-select -s /Applications/Xcode_16.1.app` on `macos-15`. Every CI run is broken.
- **HIGH — `ITSAppUsesNonExemptEncryption` absent** from both real Info.plists → every TestFlight/App Store upload stalls on the export-compliance prompt.
- **HIGH — Two stale, contradictory build logs committed at repo root** (`build_errors.log` = tests FAIL exit 65; `build_verify.log` = "Build Succeeded"), ~2 months older than HEAD, both leaking absolute path `/Users/keiran/Documents/Fonic-HiFi/`.
- **MEDIUM — File-type registration missing for a file-import music player.** No `CFBundleDocumentTypes` / `UTImportedTypeDeclarations` / `UIFileSharingEnabled` / `LSSupportsOpeningDocumentsInPlace`, so FLAC/ALAC files can't be opened *into* the app from Files/other apps (in-app picker still works via `ENABLE_USER_SELECTED_FILES = readonly`).
- **MEDIUM — Committed local/editor artifacts:** `xcuserdata` (keiran, willy), `project.pbxproj.backup` (obsolete objectVersion-77 pre-widget snapshot), `CLAUDE copy.md`, and 37 tracked files under `.vscode/` `.factory/` `.kilocode/`.
- **POSITIVE (verified) — no leaked *app* secret.** The AI "smart search" uses Apple's on-device `FoundationModels` (`SystemLanguageModel`/`LanguageModelSession`), no network endpoint or API key. App-group id, Swift 6 mode, Debug/Release split, and version numbers are all clean (details below).

---

## Findings

### [CRITICAL] App has no icon assets (App Store rejection)
- **File:** `Fonic HiFi/Assets.xcassets/AppIcon.appiconset/Contents.json` (whole file); directory listing shows only `Contents.json`, no image files.
- **Evidence:** three image entries, each like:
  ```json
  { "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ```
  None has a `"filename"` key; `ls AppIcon.appiconset/` → only `Contents.json`.
- **Also:** `project.pbxproj:373` / `:421` `ASSETCATALOG_COMPILER_APPICON_NAME = Fonic;` — points at the Icon Composer asset `Fonic HiFi/Fonic.icon/` (contains `icon.json` + one SVG `Untitled design-3 2.svg`), **not** at `AppIcon.appiconset`. So the empty `AppIcon` set is unused *and* the actual icon source is an unresolved Icon Composer file (cannot verify it produces a valid rendered icon set without Xcode — **UNVERIFIED** whether `Fonic.icon` yields a compliant icon at build time).
- **Why it matters:** Missing/invalid app icon → automatic App Store rejection and blank home-screen icon.
- **Fix:** Add real icon PNGs. Either populate `AppIcon.appiconset` with a 1024×1024 (plus dark/tinted) and set `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`, or verify the `Fonic.icon` Icon Composer asset builds and keep `= Fonic`. Example `Contents.json` entry:
  ```json
  { "filename" : "AppIcon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ```

### [CRITICAL] Privacy manifest (`PrivacyInfo.xcprivacy`) missing for app (and required-reason APIs undeclared)
- **File:** none exists — `find . -name "*.xcprivacy"` → 0 results.
- **Evidence:** `UserDefaults` usage in 28 app-target files (85 occurrences), e.g. `Fonic HiFi/FonicHiFiApp.swift:37` `UserDefaults.standard.set(false, forKey: "SwiftUI.Animation.AsyncRendering")`; `Fonic HiFi/Shared/WidgetConstants.swift:63` `UserDefaults(suiteName:)`. House doc `.claude/reference/privacy-compliance.md:437-443` documents the exact requirement: category `NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1`.
- **Why it matters:** Apple has required a privacy manifest since Nov 2024; apps using required-reason APIs (UserDefaults here) without a declared reason are rejected at review. AudioKit (the only 3rd-party SDK) must also be checked for its own manifest.
- **Fix:** Add `Fonic HiFi/PrivacyInfo.xcprivacy` to the app target:
  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0"><dict>
    <key>NSPrivacyTracking</key><false/>
    <key>NSPrivacyTrackingDomains</key><array/>
    <key>NSPrivacyCollectedDataTypes</key><array/>
    <key>NSPrivacyAccessedAPITypes</key><array>
      <dict>
        <key>NSPrivacyAccessedAPIType</key><string>NSPrivacyAccessedAPICategoryUserDefaults</string>
        <key>NSPrivacyAccessedAPITypeReasons</key><array><string>CA92.1</string></array>
      </dict>
    </array>
  </dict></plist>
  ```
  Also add one for the widget target if it reads shared `UserDefaults` (it does, via App Group), and confirm AudioKit ships `PrivacyInfo.xcprivacy` (5.6.5 does; verify at build).

### [CRITICAL] Live API credentials committed to version control
- **File / evidence (all tracked in git):**
  - `.kilocode/mcp.json:45` `"BRAVE_API_KEY": "BSAAr9***REDACTED-ROTATE-THIS***"`
  - `.kilocode/mcp.json:77` `"EXA_API_KEY": "a345d5***REDACTED-ROTATE-THIS***"`
  - `.kilocode/mcp.json:92` `"Authorization: Bearer at_64e***REDACTED-ROTATE-THIS***"`
  - `.claude/settings.local.json:83` `...X-API-Key\"\":\"\"8e3b2b43ab397cd1eb9d218f84acebaad3a7b7a968f64ec7806a9388c18833ae\"\"...`
- **Why it matters:** These are working dev-tooling tokens (Brave Search, Exa, apple-rag, an internal omnisearch MCP at `http://100.84.79.***:8000`). Anyone with repo/history access can use them; the internal IP also leaks infra topology. (Not compiled into the shipping app — no app-facing secret exists, see positive note — but a real credential leak regardless.)
- **Fix:** Rotate all four tokens now. Remove the values from tracked files (use env-var placeholders), add `.kilocode/` and `.claude/settings.local.json` to `.gitignore`, and purge from history (`git filter-repo` / BFG).

### [HIGH] `.gitignore` ignores the Xcode project and `Package.resolved`; corrupted line
- **File:** `.gitignore:37` `Package.resolved`, `:38` `*.xcodeproj`, `:42` `.swiftpm/`, `:108` `.apdiskbuild_verify.log`
- **Evidence:** `git ls-files` confirms `Fonic HiFi.xcodeproj/project.pbxproj` and `.../Package.resolved` ARE tracked despite the ignore rules (added before the rule / via `-f`). Line 108 `.apdiskbuild_verify.log` is a botched edit — `.apdisk` fragment fused to `build_verify.log`, so it ignores neither cleanly.
- **Why it matters:** Any developer running `git add .` on a fresh clone will NOT stage project or dependency-pin changes → project drift, non-reproducible builds, "works on my machine". For an App Store release you want `Package.resolved` tracked (pinned deps) and the project tracked.
- **Fix:** Remove `Package.resolved` and `*.xcodeproj` from `.gitignore`. Replace the malformed tail with real entries:
  ```gitignore
  # (delete line 37 "Package.resolved" and line 38 "*.xcodeproj")
  # fix corrupted last line
  build_errors.log
  build_verify.log
  log.md
  .kilocode/
  .claude/settings.local.json
  *.backup
  ```

### [HIGH] CI uses Xcode 16.1 — cannot build an iOS 26 / objectVersion-90 project
- **File:** `.github/workflows/ci.yml:11` `runs-on: macos-15`; `:17` `run: sudo xcode-select -s /Applications/Xcode_16.1.app`
- **Evidence:** `project.pbxproj:6` `objectVersion = 90;`, `:276` widget `CreatedOnToolsVersion = 26.0;`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0` throughout. objectVersion 90 and iOS 26 SDK require Xcode 26; Xcode 16.1 will refuse to open/build it.
- **Why it matters:** Every push/PR CI run fails at project load — no real build/test/coverage gate. (CI steps otherwise reference real `make` targets that exist — `install-deps`, `lint`, `build`, `test`, `coverage-check` all present in the Makefile — so only the toolchain/runner is wrong.)
- **Fix:** Bump to an Xcode-26-capable runner:
  ```yaml
  runs-on: macos-26
  # ...
  - name: Select Xcode 26
    run: sudo xcode-select -s /Applications/Xcode_26.app
  ```

### [HIGH] `ITSAppUsesNonExemptEncryption` not declared
- **File:** `Fonic HiFi/Info.plist` (entire file, 12 lines — key absent); `grep -r ITSAppUsesNonExemptEncryption` → 0 hits.
- **Evidence:** app `Info.plist` contains only `NSSupportsLiveActivities` and `UIBackgroundModes`.
- **Why it matters:** Without this key, every TestFlight/App Store submission blocks on the manual export-compliance question, delaying releases. App uses only standard HTTPS/OS crypto → exempt.
- **Fix:** add to `Fonic HiFi/Info.plist`:
  ```xml
  <key>ITSAppUsesNonExemptEncryption</key>
  <false/>
  ```

### [HIGH] Stale, contradictory build logs committed at repo root (with path leak)
- **Files:** `build_errors.log`, `build_verify.log` (both tracked; last commit `2025-12-07`, HEAD is `2026-02-06`).
- **Evidence:** `build_errors.log:349` `❌ /Users/keiran/Documents/Fonic-HiFi/Fonic HiFiTests/AudioQueueManagerTests.swift:183:57: referencing instance method 'id' on 'Optional' requires that 'AudioTrack' (aka 'LegacyTrack') conform to 'View'` → `:374 ❌ Tests failed with exit code 65`. Meanwhile `build_verify.log` (tail) ends `Build Succeeded`. `build_verify.log` contains the absolute path `/Users/keiran/...` 29 times. Both logs reference source files no longer on disk (`ContentView_Safe.swift`, `FonicHiFiApp_Debug.swift`, `GlassShowcase.swift`, `MiniPlayerView.swift`) — see Build Log Analysis below.
- **Why it matters:** Committed logs are noise, leak the developer's username/home path, and mislead (they contradict each other and are 2 months out of date). They are not build inputs but pollute the repo and any release archive if copied.
- **Fix:** `git rm --cached build_errors.log build_verify.log log.md` and add them to `.gitignore` (see HIGH gitignore fix). Regenerate on demand via `make build-verify` / `make error-report`.

### [MEDIUM] File-import type registration missing for FLAC/ALAC music player
- **File:** `Fonic HiFi/Info.plist` — no `CFBundleDocumentTypes`, `UTImportedTypeDeclarations`, `UIFileSharingEnabled`, or `LSSupportsOpeningDocumentsInPlace`. (Grep hits for these keys exist only under `Files/**` planning docs, not in target config.)
- **Evidence:** `project.pbxproj:381`/`:429` `ENABLE_USER_SELECTED_FILES = readonly;` (auto-adds the read-only user-selected-files sandbox entitlement — so the in-app document picker works). But no document-type association is declared.
- **Why it matters:** Users cannot "Open in Fonic HiFi" / share FLAC/ALAC into the app from the Files app, Mail, AirDrop, or other apps, and files won't surface in the app's iTunes/Files share container. For an offline importer this is a core-capability gap (functional, not a rejection).
- **Fix:** declare imported UTIs + document types (and optionally file sharing) in `Fonic HiFi/Info.plist`:
  ```xml
  <key>UIFileSharingEnabled</key><true/>
  <key>LSSupportsOpeningDocumentsInPlace</key><true/>
  <key>CFBundleDocumentTypes</key>
  <array><dict>
    <key>CFBundleTypeName</key><string>Audio File</string>
    <key>LSHandlerRank</key><string>Alternate</string>
    <key>LSItemContentTypes</key>
    <array>
      <string>public.audio</string>
      <string>org.xiph.flac</string>
      <string>com.apple.m4a-audio</string>
    </array>
  </dict></array>
  ```

### [MEDIUM] Committed local/editor artifacts pollute the repo
- **Files (all tracked):**
  - `Fonic HiFi.xcodeproj/xcuserdata/keiran.xcuserdatad/...` and `.../willy.xcuserdatad/...` (per-user scheme/nav state) — `.gitignore:6,22` says `xcuserdata/` but they were committed before the rule.
  - `Fonic HiFi.xcodeproj/project.pbxproj.backup` — objectVersion 77, 580 lines, **no widget target** (obsolete pre-widget snapshot; current is objectVersion 90, 846 lines, with widget).
  - `CLAUDE copy.md` (15 KB duplicate of `CLAUDE.md`).
  - 37 tracked files under `.vscode/`, `.factory/` (26 planning docs), `.kilocode/` (rules/workflows/`mcp.json`).
- **Evidence:** `git ls-files` lists all of the above; Python diff of `.backup` vs current shows `objectVersion 77 → 90` and absence of the `Fonic HiFi Widget` target in the backup.
- **Why it matters:** `xcuserdata` and `.backup` cause needless merge churn and can confuse tooling; the duplicate `CLAUDE copy.md` and obsolete backup mislead readers. None break the build, but they signal loose release hygiene.
- **Fix:** `git rm -r --cached "Fonic HiFi.xcodeproj/xcuserdata" "Fonic HiFi.xcodeproj/project.xcworkspace/xcuserdata"`, `git rm --cached "Fonic HiFi.xcodeproj/project.pbxproj.backup" "CLAUDE copy.md"`; add `*.backup`, `*copy.md` (or the specific file) to `.gitignore`. Decide whether `.factory/`/`.kilocode/`/`.vscode/` belong in VCS; if kept, scrub secrets (see Critical).

### [MEDIUM] Widget target relies on inherited deployment target (no explicit per-target key)
- **File:** `project.pbxproj` widget configs `C1W1D6E7...` (Debug) / `C1W1D6E8...` (Release), lines 717-779 — both set `IPHONEOS_DEPLOYMENT_TARGET = 26.0`. App target sets `26.0` too (`:391`,`:439`); project level `:519`,`:578` = `26.0`.
- **Evidence:** All deployment targets read `IPHONEOS_DEPLOYMENT_TARGET = 26.0` (app, widget, tests, UITests, project) — **consistent**. No mismatch found. (Documented per scope requirement: this is a *pass*, listed at Medium only so the consistency check is on record.)
- **Why it matters:** Consistent iOS 26 baseline is correct for the July 2026 App Store; no action needed.
- **Fix:** none.

### [LOW] `aps-environment` committed as `development`
- **File:** `Fonic HiFi/Fonic_HiFi.entitlements:5-6` `<key>aps-environment</key><string>development</string>`
- **Why it matters:** Push/Live-Activity remote environment is `development`; App Store distribution needs `production`. Xcode's automatic signing usually rewrites this at export, so it's often harmless — but committing the dev value is a foot-gun if a manual/CI archive skips the rewrite. (App declares `NSSupportsLiveActivities` in Info.plist, so APNs is genuinely used.)
- **Fix:** set to `production` for the Release/distribution entitlements (or confirm the export step overrides it):
  ```xml
  <key>aps-environment</key><string>production</string>
  ```

### [LOW] SwiftLint heavily de-scoped; sample projects excluded
- **File:** `.swiftlint.yml:25-40` disables 14 rules (`cyclomatic_complexity`, `file_length`, `identifier_name`, `type_name`, `force_unwrapping` is opt-in at `:44`, etc.); `:10-11` excludes `sample/**`.
- **Evidence:** `build_errors.log:256` `Done linting! Found 0 violations, 0 serious in 223 files.` — SwiftLint IS wired into the build (`make lint`, run in CI and pre-build), so the tool works; it's just leniently configured.
- **Why it matters:** Zero-violation status is partly because many quality rules are off. Not a release blocker.
- **Fix:** re-enable disabled rules incrementally; keep the custom `no_print_statements` error rule (`:63-69`).

### [LOW] Widescreen positives worth recording (no action)
- **App Group id is consistent everywhere** (no mismatch): `Fonic HiFi/Fonic_HiFi.entitlements:9`, `Fonic HiFi Widget/Fonic_HiFi_Widget.entitlements:7`, app code `Fonic HiFi/Shared/WidgetConstants.swift:13`, widget code `Fonic HiFi Widget/Shared/WidgetConstants.swift:13` all `group.ai.keiranlabs.Fonic-HiFi`; used in `AppGroupManager.swift:36` and `FileManager.appGroupContainerURL`.
- **Background audio present:** `Fonic HiFi/Info.plist:7-10` `UIBackgroundModes` → `audio`. Core capability satisfied.
- **Swift 6 language mode is genuinely enabled:** `SWIFT_VERSION = 6.0` + `SWIFT_STRICT_CONCURRENCY = complete` on every target (`:405`,`:410`,`:453`,`:458`,`:616-617`,`:648-649`,`:680-681`,`:710-711`,`:743-744`,`:775-776`), plus upcoming-feature flags.
- **Debug/Release split is clean:** `ENABLE_TESTABILITY = YES` only in Debug (`:503`), absent in Release (`:531-587`); `SWIFT_OPTIMIZATION_LEVEL = -Onone` Debug vs `SWIFT_COMPILATION_MODE = wholemodule` + `VALIDATE_PRODUCT = YES` Release (`:584-585`); `DEBUG=1` / `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG` only in Debug. No testability/DEBUG leak into Release.
- **Version numbers consistent:** `MARKETING_VERSION = 1.0` and `CURRENT_PROJECT_VERSION = 1` across all 8 build configs (app, widget, tests, UITests).
- **No app secret / external AI endpoint:** `SmartSearchService.swift` and `RecommendationService.swift` use on-device `FoundationModels` (`SystemLanguageModel.default`, `LanguageModelSession`) — no URLs, keys, or bearer tokens. The "hardcoded AI key" risk does not exist in shipping code.
- **Code signing:** `DEVELOPMENT_TEAM = R29WA9QFUP` is hardcoded in every config and `CODE_SIGN_STYLE = Automatic` (no hardcoded provisioning-profile UUIDs). Committing the team ID is normal for a single-team app; noted, not flagged.

---

## Build Log Analysis
Both logs are tracked at repo root and were last committed **2025-12-07 01:01** ("feat(data): add getAllArtists query method"), i.e. **~2 months before HEAD (2026-02-06)** — treat as stale.

| Log | Last commit | What it shows | Outcome |
|---|---|---|---|
| `build_errors.log` | 2025-12-07 | SwiftLint clean (`0 violations…in 223 files`, line 256), then a **test-target compile failure**: `AudioQueueManagerTests.swift:183:57 — referencing instance method 'id' on 'Optional' requires that 'AudioTrack' (aka 'LegacyTrack') conform to 'View'` and `generic parameter 'ID' could not be inferred` (lines 349-353). | **FAIL — `Tests failed with exit code 65`** (line 374); `make[1]: *** [build] Error 2`. |
| `build_verify.log` | 2025-12-07 | Debug **app** build only (not tests): resolves AudioKit 5.6.5, compiles, links, signs `Fonic HiFi.app`. | **Build Succeeded** (tail). |

Notes:
- The two logs **contradict** (one fails on tests, one succeeds on the app) because they captured different phases (`make test` vs `make build-verify`) at different moments.
- Both reference files **not on the current disk** — `ContentView_Safe.swift`, `FonicHiFiApp_Debug.swift`, `GlassShowcase.swift`, `MiniPlayerView.swift`, `iOS26_Features_Documentation.swift`, `DebugContentView.swift`, `PreviewData.swift`, `MinimalCrashTest.swift`. Because the project uses folder-sync inclusion, these were auto-compiled when present and have since been deleted → confirms the logs are stale and the tree has moved on.
- Both leak `/Users/keiran/Documents/Fonic-HiFi/` (username + home path); `build_verify.log` 29 times.
- **Actionability:** the specific error (`AudioQueueManagerTests.swift:183`) is against a Dec-2025 tree and may already be resolved at HEAD — **UNVERIFIED** on current code (cannot build in sandbox). The current `Fonic HiFiTests/AudioQueueManagerTests.swift` exists on disk; re-run `make test` on an Xcode-26 machine to confirm.

## Dependency Inventory
Source: `Fonic HiFi.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (version 3) + `project.pbxproj:826-843`.

| Package | Version (pinned) | Requirement rule | Purpose | Risk |
|---|---|---|---|---|
| AudioKit (`github.com/AudioKit/AudioKit.git`) | **5.6.5** (rev `5b3fd238…`) | `upToNextMajorVersion` from `5.6.5` (pbxproj:830-833) | Audio engine / DSP (used by `AudioKitEngineAdapter.swift`) | **Low.** 5.6.5 is a stable tagged release (not beta/branch/fork). MIT-licensed → no GPL/App-Store licensing red flag. Only caveat: `upToNextMajor` allows 5.x drift, but `Package.resolved` pins the exact revision. Verify AudioKit ships its own `PrivacyInfo.xcprivacy` (it does at 5.6.x) so the app inherits SDK privacy compliance. |

Only **one** third-party dependency. No stale/beta/fork/GPL dependencies found.

## Repo Hygiene Inventory
Every stray/notable artifact located (`git ls-files` = tracked unless noted):

| Path | Type | Tracked? | Recommended action |
|---|---|---|---|
| `.kilocode/mcp.json` | 3 live API tokens (Brave/Exa/apple-rag) | Yes | **Rotate + scrub history + gitignore `.kilocode/`** |
| `.claude/settings.local.json` | local perms + omnisearch `X-API-Key` + internal IP | Yes | **Rotate + gitignore** |
| `build_errors.log` | stale failing build log, path leak | Yes | `git rm --cached` + gitignore |
| `build_verify.log` | stale succeeding build log, path leak ×29 | Yes | `git rm --cached` + gitignore |
| `log.md` (51 KB) | dev running log | Yes | `git rm --cached` + gitignore |
| `Fonic HiFi.xcodeproj/project.pbxproj.backup` | obsolete objectVersion-77 pre-widget project | Yes | `git rm --cached` + gitignore `*.backup` |
| `CLAUDE copy.md` | duplicate of `CLAUDE.md` | Yes | delete |
| `Fonic HiFi.xcodeproj/xcuserdata/keiran…`, `…/willy…` | per-user Xcode state | Yes | `git rm -r --cached` (gitignore already lists `xcuserdata/`) |
| `Fonic HiFi.xcodeproj/project.xcworkspace/xcuserdata/keiran…` | per-user workspace state | Yes | `git rm -r --cached` |
| `.vscode/settings.json` | editor config | Yes | keep or gitignore (team choice) |
| `.factory/docs/*` (26 md) | AI planning docs | Yes | keep in a docs area or gitignore — not release-relevant |
| `.kilocode/rules,workflows` | tool config | Yes | keep/gitignore; ensure no secrets |
| `Files/Fonic HiFi SaaS Implementation Plan.pdf` (426 KB) | planning PDF binary | Yes | move out of app repo or gitignore; not a build input |
| `sample/AppleMusicMiniPlayer/.../Artwork.imageset/Artwork.jpg` (72 KB) | sample-project asset | Yes | belongs to `sample/`; keep with samples or remove `sample/` from release repo entirely |
| `Fonic HiFi/Fonic.icon/` (icon.json + SVG) | Icon Composer source | Yes | keep, but verify it renders a compliant app icon (see Critical #1) |
| `Package.resolved` | dep pin | Yes (but gitignored!) | **un-ignore** — must stay tracked |
| `DerivedData/` / `.build/` traces | — | None found | n/a (clean) |

**Sample projects** (`sample/AppleMusicBottomBar`, `sample/AppleMusicMiniPlayer`): separate reference Xcode projects with their own pbxproj/entitlements and other developers' `xcuserdata` (`balajivenkatesh`, `keiran`). Out of scope for the shipping app but bloat the release repo and carry foreign user data — recommend excluding `sample/` from the production repo (already excluded from SwiftLint at `.swiftlint.yml:10`).
