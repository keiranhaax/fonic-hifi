# Project Configuration Audit

## Conclusion

**The Xcode object graph is structurally coherent, but the repository is not release-ready or reproducible as configured.** Static parsing found four correctly linked native targets, filesystem-synchronized target roots, matching app/widget App Group identifiers, aligned bundle-ID prefixes, a correctly embedded widget extension, Swift 6 strict-concurrency settings on every target configuration, a valid `Package.resolved` pin, and sane baseline Release compiler settings. No dangling 24-character PBX object references, duplicate top-level PBX object definitions, missing asset file references, or project shell-script phases were found.

Two release blockers remain. First, two tracked local-tool configuration files contain **four plaintext credential values**; all values are redacted here and must be revoked, removed, and purged from history. Second, neither executable target contains `PrivacyInfo.xcprivacy`, even though first-party code uses `UserDefaults`, App Group defaults, file-timestamp APIs, and `ProcessInfo.systemUptime`; this is incompatible with Apple's required-reason API submission rules.

The only GitHub Actions lane is also not credible for this iOS 26 project: it selects Xcode 16.1 while source and destinations require Xcode/iOS 26, and the Makefile overrides that selection with its own `DEVELOPER_DIR`. Other material gaps are the absence of a checked-in shared scheme/test plan, no Release/analysis lane, a malformed gitlink without `.gitmodules`, non-enforced SPM/action/tool pins, checked-in local/build artifacts, incomplete SwiftLint scope, and stale widget/Live Activity/capability metadata.

**Execution boundary:** this Linux sandbox has no Xcode or Apple SDKs. I did **not** compile, test, sign, archive, launch, install, render a widget, resolve packages with Xcode, or validate App Store Connect behavior. I do not claim build success. Every such conclusion below is explicitly left for Xcode/device validation.

### Findings count

| Severity | Count |
|---|---:|
| Critical | 2 |
| High | 1 |
| Medium | 5 |
| Low | 4 |
| Informational | 0 |
| **Total** | **12** |

### Confidence count

| Confidence | Count |
|---|---:|
| Confirmed by static evidence | 11 |
| Probable | 1 |
| UNVERIFIED — needs build/device check | 0 retained findings (validation items are listed separately) |

## Audit scope and method

Loaded and applied these knowledge skills before inspection:

- Axiom: Build & Xcode Debugging
- Axiom: Security & Privacy
- Axiom: Xcode Cloud & iOS CI/CD
- Axiom: Testing
- Axiom: iOS Audit Agents (38)

Static work included:

- Full read of `Fonic HiFi.xcodeproj/project.pbxproj` and `project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
- PBX ID integrity scan: **41 unique top-level object definitions, zero duplicate top-level definitions, zero undefined 24-character references**.
- Target/root/source inventory and validation of synchronized root groups and exception sets.
- Parsing of both Info plists, both entitlement files, all JSON asset descriptors, user scheme-management plists, GitHub Actions, Makefile, SwiftLint config, gitignore, and coverage script.
- Git index/tree inspection for tracked user state, generated artifacts, object modes, gitlinks, and submodule metadata.
- Static credential-name scan with values suppressed; no credential value is reproduced in this report.
- Read-only upstream checks: the AudioKit `5.6.5` annotated tag peels to the exact revision in `Package.resolved`; GitHub Action tag SHAs listed in the proposed patch were verified with `git ls-remote` on the audit date.

## Static inventory

| Item | Result |
|---|---:|
| Native targets | 4: app, widget, unit tests, UI tests |
| Build configurations | Debug + Release on project and all four targets |
| Filesystem-synchronized target roots | 4 |
| App Swift files under synchronized root | 197 |
| Widget Swift files under synchronized root | 16 |
| Unit/support Swift files under synchronized root | 94 |
| UI-test Swift files under synchronized root | 1 |
| Checked-in shared `.xcscheme` files | 0 |
| Checked-in `.xctestplan` files | 0 |
| SPM pins | 1 (`AudioKit` 5.6.5, exact revision) |
| Project/workspace shell build phases | 0 |
| GitHub Actions workflows | 1 |
| First-party `PrivacyInfo.xcprivacy` files | 0 |
| App asset containers | `Assets.xcassets` plus `Fonic.icon` |
| Widget asset catalogs | 0 |
| Malformed gitlinks | 1 |
| Tracked main-project `xcuserdata` files | 3 |
| Tracked build logs/project backups | 3 |
| Total tracked paths | 594 |

## Findings table

| ID | Severity | Confidence | Summary |
|---|---|---|---|
| PCFG-001 | Critical | Confirmed by static evidence | Four plaintext credentials are committed in local tool configuration |
| PCFG-002 | Critical | Confirmed by static evidence | App and widget lack required-reason privacy manifests despite direct covered API use |
| PCFG-003 | High | Confirmed by static evidence | CI selects Xcode 16.1 for an Xcode/iOS 26 project, and the Makefile overrides that selection |
| PCFG-004 | Medium | Confirmed by static evidence | No versioned shared scheme or test plan defines what CI builds and tests |
| PCFG-005 | Medium | Confirmed by static evidence | Dependency/tool resolution is only partly pinned and not enforced in CI |
| PCFG-006 | Medium | Confirmed by static evidence | A mode-160000 gitlink has no `.gitmodules` mapping or available object |
| PCFG-007 | Medium | Confirmed by static evidence | CI never builds/analyzes Release and has no distribution-signing verification contract |
| PCFG-008 | Medium | Confirmed by static evidence | User-specific Xcode state, raw logs, a stale PBX backup, and local settings are tracked |
| PCFG-009 | Low | Confirmed by static evidence | SwiftLint excludes all widget and UI-test source |
| PCFG-010 | Low | Confirmed by static evidence | Info.plist advertises Live Activity support without an Activity configuration |
| PCFG-011 | Low | Probable | Widget asset build settings name color sets that do not exist in the widget target |
| PCFG-012 | Low | Confirmed by static evidence | The app claims an unused APNs capability, increasing signing scope without product code |

---

## Full findings

### PCFG-001 — Four plaintext credentials are committed in local tool configuration

- **Severity:** Critical
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `.kilocode/mcp.json:38-46`
    > `"brave-search": { ... "env": { "BRAVE_API_KEY": "[REDACTED]" } }`
  - `.kilocode/mcp.json:70-78`
    > `"exa": { ... "env": { "EXA_API_KEY": "[REDACTED]" } }`
  - `.kilocode/mcp.json:86-93`
    > `"Authorization: Bearer [REDACTED]"`
  - `.claude/settings.local.json:81-84`
    > `"Bash(claude mcp add-json ... [REDACTED PRIVATE ADDRESS] ... \"X-API-Key\":\"[REDACTED]\" ... )"`
  - Read-only index inspection confirms both paths are tracked. Git history contains `.kilocode/mcp.json` from commit `6b5f6267a4e1cd74abac31a490720f3d88a66231`; `.claude/settings.local.json` has many historical revisions.
- **Why this is defective/risky:** Anyone able to read the repository or an old clone can attempt to use the credentials, consume paid quotas, access provider data, or reach a private service. Deleting only the current files does not revoke the credentials or remove them from commit history. The local settings file also exposes a private endpoint and gives project-local automation broad command permissions. Under the audit severity contract, exploitable secret exposure is Critical.
- **Remediation:**
  1. **Revoke/rotate all four credentials before making a cleanup commit.** Review provider audit logs and billing for unauthorized use.
  2. Remove both local files from version control and ignore them. If team configuration is needed, commit sanitized `.example.json` files that reference environment-variable names only and contain no address or credential.
  3. Coordinate a history rewrite with all repository users; invalidate forks/caches where possible and force fresh clones.
  4. Enable GitHub secret scanning/push protection and a CI secret scanner.
- **Safe unapplied patch (contains no secret):**

```diff
--- a/.gitignore
+++ b/.gitignore
@@
 xcuserdata/
+.claude/settings.local.json
+.kilocode/mcp.json
```

```bash
# Run only after all exposed values have been revoked/rotated.
git rm --cached -- ".claude/settings.local.json" ".kilocode/mcp.json"

# Coordinated maintenance operation; back up first and require every collaborator to re-clone.
git filter-repo \
  --path ".claude/settings.local.json" \
  --path ".kilocode/mcp.json" \
  --invert-paths
```

- **Verification / acceptance criteria:**
  1. Old values are disabled in every provider dashboard and cannot authenticate.
  2. A full-history secret scan (`gitleaks detect`, or equivalent) reports none of the four credentials.
  3. `git ls-files` no longer lists either local file.
  4. A fresh clone configures tools only after the developer supplies credentials through a secret store/environment.
  5. Provider audit logs and billing are reviewed and any suspicious activity is resolved.
- **Related:** PCFG-005, PCFG-008.

### PCFG-002 — App and widget lack required-reason privacy manifests despite direct covered API use

- **Severity:** Critical
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Engine/AudioPlaybackSettingsStore.swift:3-20,45-54`
    > `Values are stored in UserDefaults...`
    > `public init(defaults: UserDefaults = .standard)`
    > `defaults.value.set(...)`
  - `Fonic HiFi/Shared/WidgetConstants.swift:59-64`
    > `static var appGroup: UserDefaults? {`
    > `UserDefaults(suiteName: WidgetConstants.appGroupIdentifier)`
  - `Fonic HiFi Widget/Shared/WidgetConstants.swift:59-64` contains the same App Group `UserDefaults` access in the extension executable.
  - `Fonic HiFi/Data/Services/MetadataExtractionService.swift:55-63`
    > `FileManager.default.attributesOfItem(atPath: url.path)`
    > `fileAttributes[.creationDate]`
    > `fileAttributes[.modificationDate]`
  - `Fonic HiFi/Presentation/Views/Settings/FileManagerView.swift:199-221` reads `.contentModificationDateKey`; `Fonic HiFi/Presentation/Views/Settings/FileDetailsView.swift:58` displays the modified date.
  - `Fonic HiFi/Core/Audio/Diagnostics/SystemMetricsCollector.swift:300-304,353-386`
    > `let now = ProcessInfo.processInfo.systemUptime`
  - Repository-wide path scan found **zero** `PrivacyInfo.xcprivacy` files. The app and widget are separate executables (`project.pbxproj:169-253`), so each executable's own first-party covered API use needs a manifest in its bundle.
- **Why this is defective/risky:** `UserDefaults`, file-timestamp/file-metadata APIs, and system boot-time APIs are Apple Required Reason APIs. Apple states that uploads using covered APIs without approved reasons in the target's bundled privacy manifest are not accepted. AudioKit's own resource manifest, if present in the resolved package, cannot declare first-party app or widget usage. The widget also directly accesses App Group defaults and therefore cannot rely on the app's manifest.
- **Remediation:** Add `PrivacyInfo.xcprivacy` to both synchronized target roots. For the app, declare standard defaults (`CA92.1`), same-App-Group defaults (`1C8F.1`), the file-metadata reasons actually exercised (`C617.1`, `3B52.1`, `DDA9.1`), and elapsed-time measurement (`35F9.1`). For the widget, declare its same-App-Group defaults use (`1C8F.1`). Revalidate reason codes against Apple's current documentation and the exact execution paths before submission; do not add collection/tracking declarations without a separate data-practice review.
- **Safe unapplied new file — `Fonic HiFi/PrivacyInfo.xcprivacy`:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
                <string>1C8F.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
                <string>3B52.1</string>
                <string>DDA9.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategorySystemBootTime</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>35F9.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

- **Safe unapplied new file — `Fonic HiFi Widget/PrivacyInfo.xcprivacy`:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>1C8F.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

- **Verification / acceptance criteria:**
  1. `plutil -lint` accepts both files.
  2. Xcode 26 target membership/resource inspection shows one manifest at the top of the built `.app` and one at the top of the embedded `.appex`.
  3. Organizer's generated privacy report contains all three app categories and the widget's App Group default category.
  4. An archive upload no longer reports ITMS-91053 for first-party app or extension binaries.
  5. A privacy owner confirms every reason describes actual product behavior and that separate collection/tracking declarations are complete.
- **Related:** PCFG-004, PCFG-012.

### PCFG-003 — CI selects Xcode 16.1 for an Xcode/iOS 26 project, and the Makefile overrides that selection

- **Severity:** High
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `.github/workflows/ci.yml:9-17`
    > `runs-on: macos-15`
    > `- name: Select Xcode 16.1`
    > `sudo xcode-select -s /Applications/Xcode_16.1.app`
  - `Makefile:12-18,32-34`
    > `SDK = iphonesimulator26.0`
    > `SIMULATOR_NAME = iPhone 17 Pro`
    > `SIMULATOR_OS = 26.2`
    > `export DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer`
  - `Fonic HiFi.xcodeproj/project.pbxproj:6,256-300,370-414`
    > `objectVersion = 90;`
    > `LastUpgradeCheck = 2600;`
    > `IPHONEOS_DEPLOYMENT_TARGET = 26.0;`
    > `SWIFT_VERSION = 6.0;`
  - Live source requires iOS 26 APIs: `Fonic HiFi/Presentation/Views/Components/GlassModifiers.swift:45-54,92-104` uses `Glass`/`.glassEffect`; `Fonic HiFi/ContentView.swift:58` uses `.tabViewBottomAccessory`; Foundation Models imports appear in `Fonic HiFi/Core/AI/Recommendations/RecommendationSchemas.swift:1-6`.
- **Why this is defective/risky:** Xcode 16.1 ships the iOS 18.1 SDK and cannot compile the iOS 26 API surface or provide an iOS 26.2 runtime. Further, GNU Make's exported `DEVELOPER_DIR` takes the build tools from `/Applications/Xcode.app` rather than reliably honoring the preceding `xcode-select` command. The workflow can either fail before test execution or run a different Xcode than the step name claims. It is not a trustworthy merge gate.
- **Remediation:** Select one installed Xcode 26.x path explicitly, make `DEVELOPER_DIR` and simulator variables overridable, and add a fail-fast toolchain/runtime preflight. Keep runner-image drift visible rather than silently falling back.
- **Safe unapplied patch:**

```diff
--- a/Makefile
+++ b/Makefile
@@
-SIMULATOR_NAME = iPhone 17 Pro
-SIMULATOR_OS = 26.2
+SIMULATOR_NAME ?= iPhone 17 Pro
+SIMULATOR_OS ?= 26.2
@@
-export DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer
+DEVELOPER_DIR ?= $(shell xcode-select -p)
+export DEVELOPER_DIR
```

```diff
--- a/.github/workflows/ci.yml
+++ b/.github/workflows/ci.yml
@@
   build-and-test:
     runs-on: macos-15
+    timeout-minutes: 60
+    env:
+      DEVELOPER_DIR: /Applications/Xcode_26.2.app/Contents/Developer
@@
-      - name: Select Xcode 16.1
-        run: sudo xcode-select -s /Applications/Xcode_16.1.app
+      - name: Verify Xcode and simulator contract
+        shell: bash
+        run: |
+          set -euo pipefail
+          test -d "$DEVELOPER_DIR"
+          xcodebuild -version
+          test "$(xcrun --sdk iphonesimulator --show-sdk-version)" = "26.2"
+          xcrun simctl list devices available | grep -F "iPhone 17 Pro"
```

The exact installed Xcode path/runtime must be rechecked against the selected GitHub runner image when applying this patch.
- **Verification / acceptance criteria:**
  1. CI logs print the intended Xcode build and Simulator SDK before dependency installation.
  2. `xcrun --find xcodebuild` resolves beneath the declared `DEVELOPER_DIR`.
  3. The named simulator/runtime exists; a missing path/runtime fails at preflight, not after package resolution.
  4. A clean checkout reaches build/test execution with the same toolchain locally and in CI.
- **Related:** PCFG-004, PCFG-005, PCFG-007.

### PCFG-004 — No versioned shared scheme or test plan defines what CI builds and tests

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Makefile:5-6,245-255`
    > `SCHEME = Fonic HiFi`
    > `xcodebuild test ... -scheme "$(SCHEME)" ... -enableCodeCoverage YES`
  - `Fonic HiFi.xcodeproj/xcuserdata/keiran.xcuserdatad/xcschemes/xcschememanagement.plist:5-21`
    > `<key>Fonic HiFi.xcscheme_^#shared#^_</key>`
    > `<key>Fonic HiFiTests.xcscheme_^#shared#^_</key>`
  - `Fonic HiFi.xcodeproj/project.pbxproj:194-234` confirms the unit and UI-test targets exist. Repository-wide inventory found **no** `*.xcscheme` and **no** `*.xctestplan`.
  - `.gitignore:32-43` ignores `Package.resolved`, all `*.xcodeproj`, and `.swiftpm`, making future shared scheme/lockfile additions easy to miss.
- **Why this is defective/risky:** CI depends on an auto-created scheme whose TestAction is not versioned. A clean machine has no checked contract for which test targets, coverage targets, language/region, launch arguments, sanitizers, or parallelization settings are used. User scheme-management metadata is not a portable substitute. An autogenerated scheme may work locally, but it does not make the release test selection auditable.
- **Remediation:** In Xcode 26, share `Fonic HiFi`, create/attach a versioned test plan listing `Fonic HiFiTests` and `Fonic HiFiUITests`, intentionally select coverage targets, and commit the generated files under `Fonic HiFi.xcodeproj/xcshareddata/xcschemes/`. Do not hand-author the scheme XML; Xcode must generate and validate it.
- **Safe unapplied ignore patch:**

```diff
--- a/.gitignore
+++ b/.gitignore
@@
-Package.resolved
-*.xcodeproj
+# Application projects commit their Xcode project, shared schemes, and lockfile.
+# Per-user state remains ignored by xcuserdata/ above.
```

- **Verification / acceptance criteria:**
  1. `git ls-files` lists `Fonic HiFi.xcodeproj/xcshareddata/xcschemes/Fonic HiFi.xcscheme` and a referenced `.xctestplan`.
  2. `xcodebuild -project "Fonic HiFi.xcodeproj" -list` on a clean clone lists the shared scheme.
  3. The plan explicitly contains both test target identifiers (`38D04D142DE571000047CB93`, `38D04E052DE571500047CB93`).
  4. CI output proves both test bundles execute; static presence alone is not acceptance.
- **Related:** PCFG-003, PCFG-007, PCFG-008.

### PCFG-005 — Dependency/tool resolution is only partly pinned and not enforced in CI

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi.xcodeproj/project.pbxproj:826-833`
    > `repositoryURL = "https://github.com/AudioKit/AudioKit.git";`
    > `kind = upToNextMajorVersion;`
    > `minimumVersion = 5.6.5;`
  - `Fonic HiFi.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:3-14`
    > `"identity" : "audiokit"`
    > `"revision" : "5b3fd238ef8ee95c9842ca4ea83ca58ee151e630"`
    > `"version" : "5.6.5"`
  - The `5.6.5` annotated tag currently peels to that exact commit; the lockfile contains one pin and no transitive package pins.
  - `Makefile:167-198,248-256,312-318` invokes `xcodebuild` without `-disableAutomaticPackageResolution` / `-onlyUsePackageVersionsFromResolvedFile`.
  - `.github/workflows/ci.yml:13-14,41-44` uses mutable `actions/checkout@v4` and `actions/upload-artifact@v4` tags.
  - `Makefile:129-145` installs current Homebrew formulae (plus unrelated tools) without a Brewfile/lock; `Makefile:131` can execute the current remote Homebrew installer. No Dependabot configuration exists.
- **Why this is defective/risky:** The checked lockfile is a useful pin, but CI does not require it to remain authoritative. A stale/missing lockfile can trigger resolution inside the broad 5.x range. GitHub Action tags and Homebrew formula versions can change without a repository diff, and CI installs far more tools than the lane needs. This weakens reproducibility and expands supply-chain exposure. AudioKit 5.6.5 is also behind the upstream 5.7.2 release observed on the audit date; upgrading may be appropriate, but must not be automatic because it is in the playback path.
- **Remediation:** Enforce the checked `Package.resolved`, keep it tracked, pin GitHub Actions to reviewed full SHAs, replace broad `install-deps` in CI with a minimal versioned tool bootstrap, and add dependency update monitoring. Review AudioKit 5.7.2 release notes/diff and run focused audio/concurrency regression tests before intentionally changing the pin.
- **Safe unapplied patches:**

```make
# Add near the Xcode variables in Makefile.
PACKAGE_RESOLUTION_FLAGS = -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile

# Add $(PACKAGE_RESOLUTION_FLAGS) to each CI-used xcodebuild build/test/analyze invocation.
# Example:
#   $(XCODEBUILD) test \
#       $(PACKAGE_RESOLUTION_FLAGS) \
#       -project "$(PROJECT_NAME).xcodeproj" ...
```

```diff
--- a/.github/workflows/ci.yml
+++ b/.github/workflows/ci.yml
@@
-      - name: Checkout repository
-        uses: actions/checkout@v4
+      - name: Checkout repository
+        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
@@
-        uses: actions/upload-artifact@v4
+        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4.6.2
```

```diff
--- a/.github/workflows/ci.yml
+++ b/.github/workflows/ci.yml
@@
-      - name: Install dependencies
-        run: make install-deps
+      - name: Install CI tools
+        env:
+          HOMEBREW_NO_AUTO_UPDATE: "1"
+        run: brew install swiftlint xcbeautify
```

The Homebrew replacement reduces scope but is not a complete version pin; a checked Brewfile/lock, Mint configuration, or reviewed prebuilt tool artifacts are still required for bit-for-bit tooling reproducibility.
- **Verification / acceptance criteria:**
  1. CI fails if `Package.resolved` is missing/out of date rather than selecting a new AudioKit revision.
  2. `git diff --exit-code -- "Fonic HiFi.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"` remains clean after CI.
  3. Every third-party action uses a reviewed 40-character SHA with a version comment.
  4. CI logs exact SwiftLint/xcbeautify/Xcode versions.
  5. An intentional AudioKit update arrives as a reviewed lockfile diff and passes playback/device regression checks.
- **Related:** PCFG-001, PCFG-003, PCFG-007.

### PCFG-006 — A mode-160000 gitlink has no `.gitmodules` mapping or available object

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - Repository-relative tree entry `.claude/skills/ios-simulator-skill` is mode `160000`, object `fe4c14d565eac1ddd4f6baee53c6ca9c33b1dd83`. A gitlink is not a line-addressable text file; this is the exact Git tree evidence for that path.
  - Repository-wide inventory found no `.gitmodules` file.
  - The worktree path is empty, and `git cat-file -t fe4c14d565eac1ddd4f6baee53c6ca9c33b1dd83` cannot find the object.
  - Read-only `git submodule status` fails with:
    > `fatal: no submodule mapping found in .gitmodules for path '.claude/skills/ios-simulator-skill'`
- **Why this is defective/risky:** Standard submodule tooling fails, recursive clone/update automation cannot recover the content, and contributors cannot determine the intended upstream URL or verify the referenced commit. Backup and release automation that treats gitlinks as valid submodules can fail even though this path is outside the app target.
- **Remediation:** If the skill is not required, remove the orphan gitlink. If it is required, remove the orphan first and re-add it as a real submodule from a verified URL/commit so `.gitmodules` and the object are both available.
- **Safe unapplied patch — removal path:**

```bash
git rm --cached -- ".claude/skills/ios-simulator-skill"
# The current worktree directory is empty; remove it locally if Git leaves it behind.
rmdir ".claude/skills/ios-simulator-skill" 2>/dev/null || true
```

Re-add only with a verified source:

```bash
git submodule add --name ios-simulator-skill \
  "<VERIFIED_HTTPS_REPOSITORY_URL>" \
  ".claude/skills/ios-simulator-skill"
git -C ".claude/skills/ios-simulator-skill" checkout "<VERIFIED_COMMIT>"
git add .gitmodules ".claude/skills/ios-simulator-skill"
```

- **Verification / acceptance criteria:**
  1. `git submodule status` exits zero.
  2. If retained, `.gitmodules` maps the exact path to a reviewed HTTPS URL and a clean clone can fetch the pinned commit.
  3. If removed, `git ls-tree HEAD .claude/skills/ios-simulator-skill` returns no entry.
  4. `git fsck --full` reports no project-introduced missing object.
- **Related:** PCFG-008.

### PCFG-007 — CI never builds/analyzes Release and has no distribution-signing verification contract

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `.github/workflows/ci.yml:22-32`
    > `Run lint`
    > `Build project` → `make build`
    > `Run tests` → `make test`
    > `Run coverage check`
  - `Makefile:160-185` shows `make build` uses `CONFIGURATION_DEBUG` and redundantly runs lint and tests before building.
  - `Makefile:187-199` defines `build-release`, but the workflow never calls it.
  - `Makefile:309-319` defines `analyze`, but the workflow never calls it.
  - `Fonic HiFi.xcodeproj/project.pbxproj:531-586` has meaningful Release-only settings:
    > `DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";`
    > `ENABLE_NS_ASSERTIONS = NO;`
    > `SWIFT_COMPILATION_MODE = wholemodule;`
    > `VALIDATE_PRODUCT = YES;`
  - Target Release signing is automatic with fixed team `R29WA9QFUP` (`project.pbxproj:418-464,749-779`), but no CI export options, signing assets, archive lane, or entitlement inspection exists.
- **Why this is defective/risky:** Debug success would not exercise whole-module compilation, disabled assertions, dSYM generation, product validation, Release conditional compilation, embedded-extension validation, or distribution entitlement/profile resolution. Automatic local signing may be appropriate, but the repository has no documented automated or manual release-signing acceptance contract.
- **Remediation:** After fixing the toolchain, add unsigned Release simulator build and static analysis gates. Separately define a protected macOS signing/archive lane (or documented Xcode Organizer checklist) that verifies both app and widget distribution profiles, final entitlements, embedded extension, bundle IDs, version parity, privacy manifests, and export compliance.
- **Safe unapplied CI patch:**

```diff
--- a/.github/workflows/ci.yml
+++ b/.github/workflows/ci.yml
@@
       - name: Build project
         run: make build
+
+      - name: Build Release configuration (unsigned simulator)
+        run: make build-release
+
+      - name: Run Xcode static analysis
+        run: make analyze
```

Do not add signing secrets to this pull-request lane. Put archive/distribution in an environment-protected job or Xcode Cloud workflow with least-privilege credentials.
- **Verification / acceptance criteria:**
  1. CI logs show Release Swift compilation and `Validate` steps, not only Debug products.
  2. `make analyze` failures fail the job.
  3. A protected archive run produces an `.xcarchive` whose app and `.appex` both have distribution profiles for the intended team and App Group.
  4. `codesign -d --entitlements :-` and embedded-profile inspection match the approved capability matrix.
  5. The archive's dSYM UUID matches the shipped executable UUID and is retained for crash symbolication.
- **Related:** PCFG-002, PCFG-003, PCFG-004, PCFG-012.

### PCFG-008 — User-specific Xcode state, raw logs, a stale PBX backup, and local settings are tracked

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `.gitignore:5-7`
    > `## User settings`
    > `xcuserdata/`
  - Despite that rule, tracked files include:
    - `Fonic HiFi.xcodeproj/project.xcworkspace/xcuserdata/keiran.xcuserdatad/IDEFindNavigatorScopes.plist:1-4`
      > `<array/>`
    - `Fonic HiFi.xcodeproj/xcuserdata/keiran.xcuserdatad/xcschemes/xcschememanagement.plist:5-21`
    - `Fonic HiFi.xcodeproj/xcuserdata/willy.xcuserdatad/xcschemes/xcschememanagement.plist:5-12`
  - `Fonic HiFi.xcodeproj/project.pbxproj.backup:6,181-220,284-341` is a stale Xcode 16-era project (`objectVersion = 77`) with old targets/settings/bundle ID, while the live project is object version 90 with a widget and AudioKit.
  - `build_errors.log:30-40` and `build_verify.log:30-41` are raw build outputs; later lines contain a local absolute home path. The excerpt is intentionally not reproduced.
  - `.claude/settings.local.json` and `.kilocode/mcp.json` are also tracked local configuration; the credential aspect is PCFG-001.
- **Why this is defective/risky:** These files create merge churn and machine-specific behavior, expose developer identity/path information, preserve stale diagnostics that can be mistaken for current evidence, and leave a second obsolete PBX graph next to the real project. The tracked status defeats existing ignore rules. This finding does **not** treat the historical build logs as proof that current source builds or fails.
- **Remediation:** Remove user state, raw logs, PBX backups, and local settings from the index; keep shared schemes/test plans and the SPM lockfile. Extend ignores for recurring temporary outputs. Store any intentionally retained diagnostic as a sanitized, dated artifact outside the live project root.
- **Safe unapplied patch:**

```diff
--- a/.gitignore
+++ b/.gitignore
@@
 xcuserdata/
+*.xcresult
+*.log
+*.pbxproj.backup
+.build_output.tmp
+.test_output.tmp
+.claude/settings.local.json
+.kilocode/mcp.json
```

```bash
git rm -r --cached -- \
  "Fonic HiFi.xcodeproj/xcuserdata" \
  "Fonic HiFi.xcodeproj/project.xcworkspace/xcuserdata"
git rm --cached -- \
  "Fonic HiFi.xcodeproj/project.pbxproj.backup" \
  "build_errors.log" \
  "build_verify.log" \
  ".claude/settings.local.json" \
  ".kilocode/mcp.json"
```

Apply equivalent cleanup to sample-project `xcuserdata` if samples remain in source control.
- **Verification / acceptance criteria:**
  1. `git ls-files` returns no `xcuserdata`, raw `*.log`, `project.pbxproj.backup`, or local settings files.
  2. A developer opening Xcode changes only ignored user state.
  3. The shared scheme/test plan and `Package.resolved` remain tracked.
  4. A clean clone has exactly one live `project.pbxproj` for the product project.
- **Related:** PCFG-001, PCFG-004, PCFG-006.

### PCFG-009 — SwiftLint excludes all widget and UI-test source

- **Severity:** Low
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `.swiftlint.yml:1-4`
    > `included:`
    > `- Fonic HiFi`
    > `- Fonic HiFiTests`
  - Widget and UI-test targets are active synchronized targets in `Fonic HiFi.xcodeproj/project.pbxproj:215-253`.
  - `Fonic HiFi Widget/Intents/WidgetIntents.swift:10-25` and `Fonic HiFiUITests/LibraryNowPlayingSmokeTests.swift:1-13` are compiled Swift source but lie outside the lint include list.
  - `.swiftlint.yml:63-70` makes `print()` an error, but that custom rule is never applied to those two target roots.
- **Why this is defective/risky:** Extension and UI-test changes bypass the repository's strict lint policy, including force-use/TODO/custom logging checks. Target membership is automatic, so a newly added widget source compiles without any project-file diff and can silently remain outside lint.
- **Remediation / safe unapplied patch:** Add both live roots to the include list.

```diff
--- a/.swiftlint.yml
+++ b/.swiftlint.yml
@@
 included:
   - Fonic HiFi
+  - Fonic HiFi Widget
   - Fonic HiFiTests
+  - Fonic HiFiUITests
```

- **Verification / acceptance criteria:**
  1. `swiftlint lint --strict` enumerates files from all four roots.
  2. A temporary known violation in the widget and UI-test roots fails lint, then is removed.
  3. CI uses the checked `.swiftlint.yml` and records the SwiftLint version.
- **Related:** PCFG-005.

### PCFG-010 — Info.plist advertises Live Activity support without an Activity configuration

- **Severity:** Low
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Info.plist:5-6`
    > `<key>NSSupportsLiveActivities</key>`
    > `<true/>`
  - `Fonic HiFi Widget/FonicWidgetBundle.swift:11-16` exposes only `NowPlayingWidget()`.
  - `Fonic HiFi Widget/NowPlayingWidget.swift:13-24` defines a `StaticConfiguration`; repository-wide source inventory found no `ActivityConfiguration` and no `import ActivityKit`.
- **Why this is defective/risky:** The built app declares Live Activity support while its embedded extension provides no Live Activity configuration to start or render. This is capability/metadata drift and can confuse release review, diagnostics, and future developers. `LiveActivityIntent` conformance on button intents does not create an Activity configuration.
- **Remediation:** If Live Activities are not shipping, remove `NSSupportsLiveActivities`. If they are intended, implement and register a real `ActivityConfiguration`, add the necessary attributes/state/update lifecycle, and validate on Lock Screen/Dynamic Island before retaining the key.
- **Safe unapplied patch for current live source:**

```diff
--- a/Fonic HiFi/Info.plist
+++ b/Fonic HiFi/Info.plist
@@
-	<key>NSSupportsLiveActivities</key>
-	<true/>
```

- **Verification / acceptance criteria:**
  1. If removed, the processed app Info.plist contains no `NSSupportsLiveActivities` key.
  2. If retained, the extension bundle contains a registered `ActivityConfiguration` and a device can start, update, end, and relaunch-recover the activity.
  3. App Store metadata does not claim an unavailable surface.
- **Related:** PCFG-011.

### PCFG-011 — Widget asset build settings name color sets that do not exist in the widget target

- **Severity:** Low
- **Confidence:** Probable
- **Evidence:**
  - `Fonic HiFi.xcodeproj/project.pbxproj:717-745,749-777`
    > `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;`
    > `ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME = WidgetBackground;`
  - The widget target's only synchronized root is `Fonic HiFi Widget` (`project.pbxproj:236-248`). Repository inventory found **zero** `.xcassets` beneath that root and no `WidgetBackground.colorset` anywhere in the product target.
  - `Fonic HiFi Widget/NowPlayingWidget.swift:16-35` uses `.containerBackground(.fill.tertiary, for: .widget)` and does not reference either named color.
- **Why this is defective/risky:** Xcode's widget background/accent build settings are intended to name color sets in an asset catalog used by the widget target. Here they point to absent resources, so generated widget configuration metadata may be missing/incorrect or future code may assume colors are bundled when they are not. Static inspection cannot determine whether Xcode 26 treats the stale options as only a warning or how the gallery renders; therefore confidence is Probable.
- **Remediation:** Because current source uses system container styling and no named colors, remove the stale settings from both widget configurations. If branded gallery colors are desired, instead add a widget-owned asset catalog with matching `AccentColor` and `WidgetBackground` color sets.
- **Safe unapplied patch:**

```diff
--- a/Fonic HiFi.xcodeproj/project.pbxproj
+++ b/Fonic HiFi.xcodeproj/project.pbxproj
@@
-				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
-				ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME = WidgetBackground;
```

Apply the same two-line deletion in both widget XCBuildConfiguration blocks (`C1W1D6E7...` Debug and `C1W1D6E8...` Release).
- **Verification / acceptance criteria:**
  1. Xcode 26 builds the widget target without missing asset warnings.
  2. The processed extension Info.plist does not point to a nonexistent widget background color.
  3. The widget gallery and all six supported families render correctly in light/dark/tinted modes on a device/simulator.
- **Related:** PCFG-010.

### PCFG-012 — The app claims an unused APNs capability, increasing signing scope without product code

- **Severity:** Low
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Fonic_HiFi.entitlements:5-10`
    > `<key>aps-environment</key>`
    > `<string>development</string>`
    > `<key>com.apple.security.application-groups</key>`
  - Both app configurations use this entitlement file (`Fonic HiFi.xcodeproj/project.pbxproj:370-376,418-424`).
  - Repository-wide first-party source search found no `registerForRemoteNotifications`, `didRegisterForRemoteNotifications`, or `UNUserNotificationCenter` usage. `Fonic HiFi/Info.plist:7-10` declares background audio only, not `remote-notification`.
- **Why this is defective/risky:** The push entitlement requires the App ID/provisioning profile to carry an unused capability, increasing least-privilege and signing/provisioning complexity. The literal `development` value is not itself proof of a broken Release signature—Apple documents that Xcode derives the final APS environment from the selected provisioning profile—but the capability has no corroborating product path and should not be claimed.
- **Remediation:** Remove Push Notifications from Signing & Capabilities and delete `aps-environment` while retaining the App Group entitlement. If push becomes a real requirement, re-add the capability through Xcode and implement registration/token/error handling; verify final distribution entitlements rather than hard-coding production.
- **Safe unapplied patch:**

```diff
--- a/Fonic HiFi/Fonic_HiFi.entitlements
+++ b/Fonic HiFi/Fonic_HiFi.entitlements
@@
-	<key>aps-environment</key>
-	<string>development</string>
```

- **Verification / acceptance criteria:**
  1. The app target's Signing & Capabilities list no longer includes Push Notifications.
  2. Development and distribution provisioning profiles remain valid for the App Group capability.
  3. `codesign -d --entitlements :- <archived-app>` contains the App Group and no APS entitlement.
  4. If product requirements say push is needed, reject this patch and instead add a tested push implementation plus production-profile verification.
- **Related:** PCFG-007.

---

## Verified-good configuration and rejected candidate findings

These candidates were investigated and **not** retained as defects:

1. **PBX object integrity:** The live PBX file has 41 unique top-level objects and no unresolved 24-character references. The four targets and dependencies point to defined IDs (`project.pbxproj:168-301,351-367`).
2. **Filesystem-synchronized target membership:** App, widget, unit-test, and UI-test roots are each attached to the intended target (`project.pbxproj:78-104,183-248`). App/widget Info plists are deliberately excluded from synchronized build membership (`project.pbxproj:61-75`) while still linked by `INFOPLIST_FILE`.
3. **Widget embedding:** The app depends on and embeds `Fonic HiFi Widget.appex` in `PlugIns` (`project.pbxproj:40-49,169-193,351-366`). `SKIP_INSTALL = YES` is set on the extension (`project.pbxproj:717-779`).
4. **Bundle IDs and versions:** App `ai.keiranlabs.Fonic-HiFi` and widget `ai.keiranlabs.Fonic-HiFi.Widget` are prefix-aligned; both use marketing version 1.0/build 1 in Debug and Release (`project.pbxproj:370-464,717-779`). Test IDs are distinct.
5. **App Group synchronization:** Both entitlements and both source copies use `group.ai.keiranlabs.Fonic-HiFi` (`Fonic HiFi/Fonic_HiFi.entitlements:7-10`; `Fonic HiFi Widget/Fonic_HiFi_Widget.entitlements:5-8`; both `WidgetConstants.swift:10-14`). The three duplicated shared model files differ only in header comments at this commit.
6. **Info.plist linkage/lifecycle:** Both XML plists parse. App generation enables a scene manifest and launch screen (`project.pbxproj:382-390,430-438`); SwiftUI `WindowGroup` supplies scene lifecycle (`Fonic HiFi/FonicHiFiApp.swift:86-92`). Background audio is explicitly declared (`Fonic HiFi/Info.plist:7-10`).
7. **Swift/concurrency settings:** Every app, widget, unit-test, and UI-test configuration explicitly uses `SWIFT_VERSION = 6.0` and `SWIFT_STRICT_CONCURRENCY = complete` (`project.pbxproj:404-410,452-458,614-617,648-649,678-681,710-711,742-744,774-776`). This does not prove code is race-free; it only verifies configuration.
8. **Release baseline:** Release has dSYM generation, disabled assertions, whole-module compilation, and product validation (`project.pbxproj:531-586`). The retained defect is lack of CI execution, not the presence of obviously unsafe Release flags.
9. **SPM pin integrity:** `Package.resolved` is valid JSON version 3 and pins AudioKit 5.6.5 to the commit currently referenced by that annotated tag. No additional/transitive package pin is present. No known advisory was established by static inspection; the upgrade is a review item, not a claimed vulnerability.
10. **App icon asset:** `ASSETCATALOG_COMPILER_APPICON_NAME = Fonic` matches `Fonic HiFi/Fonic.icon`; its `icon.json:36-38` references an existing SVG. The empty legacy `AppIcon.appiconset` is unused and was treated as cleanup, not a release defect.
11. **No product build scripts:** The PBX graph contains no `PBXShellScriptBuildPhase`; `ENABLE_USER_SCRIPT_SANDBOXING = YES` is set at project level (`project.pbxproj:504,569`). Script risks described above are repository/CI scripts, not hidden Xcode phases.
12. **APS environment value alone:** The literal `development` entitlement was not reported as a guaranteed Release mismatch because Xcode/provisioning can derive the final value. PCFG-012 is retained only because the entire push capability is uncorroborated by live product code.
13. **iPhone-only family:** App/widget set `TARGETED_DEVICE_FAMILY = 1` while supported platforms are iOS device/simulator. No product contract in live configuration proves iPad support, so this is an open product decision rather than a defect.

## Open Xcode/build/device/release checks

All items below are **UNVERIFIED — needs build/device check**:

1. Open the clean project in the intended Xcode 26.x version and confirm object version 90/synchronized groups are accepted without automatic project rewrites.
2. Run `xcodebuild -list` and `-showBuildSettings` after creating the shared scheme; capture effective Debug/Release settings for all four targets.
3. Run a clean locked-package resolve/build with no SPM caches and no network update; confirm `Package.resolved` remains unchanged.
4. Compile Debug and Release simulator configurations with the exact CI toolchain. No static audit result should be interpreted as build success.
5. Execute both unit and UI test bundles from the committed test plan and confirm the widget target is built as the app dependency.
6. Generate an archive with the real distribution team. Inspect app and extension signatures, profiles, App Group entitlement, APS absence/presence decision, bundle/version parity, and embedded extension path.
7. Generate Xcode Organizer's privacy report and inspect the final `.app`, `.appex`, and AudioKit resource bundle manifests. Submit to a non-production App Store Connect validation flow and confirm no missing-required-reason errors.
8. Verify `Fonic.icon` in all required icon variants and App Store validation. The static JSON/SVG reference check is not an `actool` validation.
9. Install the app/widget on iOS 26: verify all supported widget families, gallery colors, App Group reads/writes, artwork cache, interactive intents, Lock Screen behavior, and removal/re-add behavior.
10. Decide whether Live Activities are a shipping feature. If yes, implement/start/update/end on a physical device; if no, verify the processed Info.plist no longer claims support.
11. Decide whether APNs is a shipping feature. If yes, add tested registration/token handling and verify production entitlements; if no, remove the capability and regenerate profiles.
12. Confirm intended device family (iPhone-only versus iPad) with product ownership; if iPad is intended, update `TARGETED_DEVICE_FAMILY` and run layout/orientation testing.
13. Run Release static analysis and sanitizer/device lanes appropriate to the app; retain result bundles and dSYMs outside the repository.
14. After credential rotation/history rewrite, test old credentials are dead and require fresh clones for every collaborator/automation account.

## External policy/tooling references used

- Apple, **Describing use of required reason API**: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- Apple, **TN3183: Adding required reason API entries to your privacy manifest**: https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest
- Apple, **Privacy manifest files**: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- Apple, **APS Environment Entitlement**: https://developer.apple.com/documentation/bundleresources/entitlements/aps-environment
- Apple Developer Forums guidance on locked `Package.resolved` / `-disableAutomaticPackageResolution`: https://developer.apple.com/forums/thread/699342
- GitHub Actions macOS 15 runner image inventory (used only to frame the proposed Xcode path; recheck on application): https://github.com/actions/runner-images/blob/releases/macos-15/20260421/images/macos/macos-15-Readme.md

No external source was treated as permission to mutate the read-only repository, and no external claim substitutes for the repository evidence above.
