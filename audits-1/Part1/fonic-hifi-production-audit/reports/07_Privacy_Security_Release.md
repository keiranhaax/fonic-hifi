# Privacy, Security, and App Store Release Audit

## Conclusion

**The audited commit is not safe to release.** Two current, evidence-backed blockers are present:

1. Four live plaintext credential values are committed in two tracked local-tool configuration files. One file also contains a sensitive direct-IP service endpoint. The values are not reproduced here; only labels, lengths, fingerprints, and locations are reported.
2. The app and widget contain first-party Required Reason API use but the repository contains no `PrivacyInfo.xcprivacy` file. Under Apple's current iOS 26 submission rules, the affected upload is not accepted until each executable bundle truthfully declares its own use.

Two additional High findings materially weaken release assurance: CI selects Xcode 16.1 for an iOS/Xcode 26 project (then the Makefile overrides the selection), and production logging explicitly marks track titles, filenames, paths, route names, and error text as public. Medium findings cover imported-file protection normalization, an incomplete privacy disclosure, and committed local/build/debug artifacts. Low findings cover unused APNs and Live Activity declarations. Export compliance remains a deliberate release determination rather than a proven defect.

This is a static audit in a Linux sandbox. No Xcode/Apple SDK is available; compilation, signing, archive inspection, App Store Connect validation, simulator/device behavior, and effective Data Protection classes are not claimed.

### Findings count

| Severity | Count |
|---|---:|
| Critical | 2 |
| High | 2 |
| Medium | 3 |
| Low | 2 |
| Informational | 1 |
| **Total** | **10** |

### Confidence count

| Confidence | Count |
|---|---:|
| Confirmed by static evidence | 8 |
| Probable | 1 |
| UNVERIFIED — needs build/device check | 1 |
| **Total** | **10** |

## Ground truth, scope, and method

- Repository: `/agent/workspace/fonic-hifi-audit`
- Branch: `main`
- Commit: `459db9bfd18d17960e8fd2ff8defc4701085532e`
- Audit date: 2026-07-09
- Independent Git verification: HEAD and branch match the audit contract; `git status --porcelain=v1 --untracked-files=all` was empty before report creation; 594 tracked paths and 212 reachable commits were enumerated read-only.
- The repository was not edited. All work output is outside it under `/agent/workspace/fonic-hifi-audit-work/subagents`.

Loaded and applied:

- Axiom: Security & Privacy
- Axiom: App Store Shipping & Review
- Axiom: iOS Audit Agents (38), especially its security/privacy, storage, and networking audit guidance
- Axiom: Apple Docs Research

Static work included:

- Use of `_safe_repo_scan.json` and `_safe_history_scan.json` as candidate locators, followed by independent parsing of the current files, Git index checks, HEAD-object checks, a clean-worktree check, and live-source searches.
- Redacted current-file inspection; no secret or sensitive address is reproduced.
- Full target-source searches for credentials, network clients/endpoints, ATS exceptions, protected-resource APIs, tracking APIs, Required Reason APIs, public logging, file writes/copies, file-protection configuration, entitlements, background modes, Foundation Models tools, privacy UI, and release/debug artifacts.
- Parsing of app/widget Info plists and entitlement files, relevant project settings, workflow/Makefile toolchain selection, and the exact SPM pin.
- Cross-check against `subagents/11_current_apple_sources.md`. Its current iOS 26 boundary controls this report. Beta-only iOS 27 addenda in skills were treated as forward-looking, not current release gates.

### Redacted candidate summary

The safe current-tree locator reported three credential hits in `.kilocode/mcp.json`; its assignment pattern did not catch the doubly escaped key embedded in `.claude/settings.local.json`. Independent JSON parsing safely confirmed all four live values:

| Location | Redacted identifier | Length | SHA-256 prefix |
|---|---|---:|---|
| `.kilocode/mcp.json:45` | `BRAVE_API_KEY=[REDACTED]` | 31 | `sha256:a64a38fd06ff` |
| `.kilocode/mcp.json:77` | `EXA_API_KEY=[REDACTED]` | 36 | `sha256:675ffddddb61` |
| `.kilocode/mcp.json:92` | `Authorization: Bearer [REDACTED]` | 35 | `sha256:22da2a34d302` |
| `.claude/settings.local.json:83` | `X-API-Key: [REDACTED]` | 64 | `sha256:416e38324abe` |

The sensitive endpoint at `.claude/settings.local.json:83` is reported only as `sha256:92f6602b0af1` for the full URL candidate and `sha256:432e96abfc65` for the address literal.

The history locator covered 212 commits and 4,787 unique blobs. It found the same four values at HEAD plus two 13-character `password` literals in an old authentication-test example. Redacted context confirmed the latter are illustrative test inputs, not credentials; they are rejected below.

### Current official requirement classification

| Requirement | Classification on 2026-07-09 | Repository implication |
|---|---|---|
| Xcode 26+ / iOS 26 SDK+ for uploads since 2026-04-28 | **Current mandatory upload rule** (`APPLE-SRC-001`) | CI's Xcode 16.1 lane cannot qualify a release. |
| Required Reason API declarations | **Current mandatory rule when covered APIs are used** (`APPLE-SRC-002` through `APPLE-SRC-007`) | App and widget need separate bundled manifests. |
| App Store privacy details | **Current mandatory submission metadata** (`APPLE-SRC-008`) | App Store Connect answers are outside the repository and require release-owner verification. Purely on-device processing is not “collected” under Apple's definition. |
| Privacy-policy links | **Current mandatory requirement** (`APPLE-SRC-009`) | An in-app policy is present; the App Store URL is unverified and the in-app text is incomplete. |
| Export-compliance determination | **Current mandatory determination** (`APPLE-SRC-010` through `APPLE-SRC-012`) | Omission of the plist key is allowed but causes a per-version questionnaire; the final archive must be classified. |
| Background audio | **Allowed only for intended playback** (`APPLE-SRC-009`, `APPLE-SRC-013`) | The declaration and `.playback` session are corroborated; no defect retained. |
| iOS 27 UIScene/launch-screen gate | **Beta-only, out of the current iOS 26 release scope** (`APPLE-OOS-003`) | Not used as a blocker. The project already requests generated scene and launch metadata. |

## Findings table

| ID | Severity | Confidence | Summary |
|---|---|---|---|
| PSR-001 | Critical | Confirmed by static evidence | Four live credentials and a sensitive endpoint are committed in tracked local configuration |
| PSR-002 | Critical | Confirmed by static evidence | App and widget lack privacy manifests despite first-party Required Reason API use |
| PSR-003 | High | Confirmed by static evidence | CI cannot validate the current iOS 26 release toolchain |
| PSR-004 | High | Confirmed by static evidence | Release logging marks user library content and diagnostic details public |
| PSR-005 | Medium | Probable | Imported audio files retain uncontrolled source protection metadata |
| PSR-006 | Medium | Confirmed by static evidence | In-app privacy disclosure omits material local data and retention/deletion behavior |
| PSR-007 | Medium | Confirmed by static evidence | Local settings, build logs, Xcode user state, and a stale project backup are committed |
| PSR-008 | Low | Confirmed by static evidence | The app claims APNs without a product implementation |
| PSR-009 | Low | Confirmed by static evidence | Info.plist claims Live Activity support without an ActivityKit configuration |
| PSR-010 | Informational | UNVERIFIED — needs build/device check | Export classification is not encoded and needs final-archive determination |

---

## Full findings

### PSR-001 — Four live credentials and a sensitive endpoint are committed in tracked local configuration

- **Severity:** Critical
- **Confidence:** Confirmed by static evidence
- **Exact evidence:**
  - `.kilocode/mcp.json:38-46`
    > `"brave-search": { ... "env": { "BRAVE_API_KEY": "[REDACTED]" } }`
  - `.kilocode/mcp.json:70-78`
    > `"exa": { ... "env": { "EXA_API_KEY": "[REDACTED]" } }`
  - `.kilocode/mcp.json:86-93`
    > `"--header", "Authorization: Bearer [REDACTED]"`
  - `.claude/settings.local.json:81-84`
    > `"Bash(claude mcp add-json ... \"url\":\"[REDACTED_ADDRESS]\" ... \"X-API-Key\":\"[REDACTED]\" ...)"`
  - `.gitignore:1-22,84-108` ignores generic Xcode user/build output but does not ignore either local-tool file.
  - Independent `git ls-files --error-unmatch` confirmed both files are tracked. HEAD-object verification confirmed all four locations exist in commit `459db9bfd18d`; the worktree is clean, so this is not an uncommitted local-only state.
  - Current checkout modes are `0644`; that is not a compensating control and Git history remains readable regardless of local mode.
- **Redacted value inventory:** See the fingerprint/length table above. No value or endpoint is reproduced.
- **Impact / execution path:** Any repository reader, old clone, fork, backup, CI artifact, or indexed cache can attempt authentication, consume paid quotas, query provider data, or reach the exposed service. Removing only the current lines does not revoke a credential or remove historical copies. The embedded permission command also couples broad local automation permission with a sensitive address and key. This meets the audit definition of exploitable secret exposure.
- **Preserving remediation:** Keep the existing developer-tool architecture, but make all machine-specific configuration local and untracked.
  1. Revoke/rotate all four values first. Review provider access logs, quota, and billing for use since first exposure.
  2. Remove `.claude/settings.local.json` and `.kilocode/mcp.json` from the index and add them to `.gitignore`.
  3. Commit sanitized `.example.json` files only if onboarding needs a template; use placeholders and document runtime environment/secret-manager injection. Do not commit a real endpoint.
  4. Coordinate a history rewrite after rotation; invalidate forks/caches where possible and require fresh clones.
  5. Add pre-commit and CI secret scanning plus host-side push protection.
- **Safe code/config sample:**

```gitignore
# Machine-local agent/tool configuration
.claude/settings.local.json
.kilocode/mcp.json

# Never commit environment/credential material
.env
.env.*
!.env.example
```

```json
{
  "mcpServers": {
    "example": {
      "command": "tool-command",
      "env": {
        "API_KEY": "[INJECT_AT_RUNTIME_FROM_SECRET_STORE]"
      }
    }
  }
}
```

The example file must remain nonfunctional until a developer supplies a local secret. Confirm the selected tool actually supports the chosen environment-injection mechanism; do not assume `${VAR}` expansion in JSON.

```bash
# Only after every exposed value has been revoked/rotated.
git rm --cached -- ".claude/settings.local.json" ".kilocode/mcp.json"

# Coordinated maintenance operation; back up and require collaborators to re-clone.
git filter-repo \
  --path ".claude/settings.local.json" \
  --path ".kilocode/mcp.json" \
  --invert-paths
```

- **Verification / acceptance criteria:**
  1. Provider dashboards show all four old fingerprints disabled; authentication with old values fails.
  2. Provider audit/billing review has no unresolved suspicious activity.
  3. `git ls-files` does not list either local file; a fresh clone contains only sanitized examples.
  4. Full-history scanning reports no matching fingerprints and no additional high-confidence secret.
  5. A clean developer setup works only after local secret-store/environment provisioning.
  6. Push protection rejects a synthetic test credential in a disposable branch.
- **Related:** PSR-007.

### PSR-002 — App and widget lack privacy manifests despite first-party Required Reason API use

- **Severity:** Critical
- **Confidence:** Confirmed by static evidence
- **Exact evidence:**
  - `Fonic HiFi/Core/Audio/Engine/AudioPlaybackSettingsStore.swift:3-20,45-54`
    > `Values are stored in UserDefaults...`
    > `public init(defaults: UserDefaults = .standard)`
    > `defaults.value.set(...)`
  - `Fonic HiFi/Shared/WidgetConstants.swift:59-64`
    > `static var appGroup: UserDefaults? { UserDefaults(suiteName: ...) }`
  - `Fonic HiFi Widget/Shared/WidgetConstants.swift:59-64` has the same direct App Group defaults access in the extension executable.
  - `Fonic HiFi/Shared/WidgetPlaybackState.swift:113-135` and `Fonic HiFi Widget/Shared/WidgetPlaybackState.swift:113-135`
    > `defaults.set(data, forKey: ...)`
    > `defaults.data(forKey: ...)`
  - `Fonic HiFi/Data/Services/MetadataExtractionService.swift:55-63`
    > `FileManager.default.attributesOfItem(atPath: url.path)`
    > `fileAttributes[.creationDate]`
    > `fileAttributes[.modificationDate]`
  - `Fonic HiFi/Presentation/Views/Settings/FileManagerView.swift:195-222` reads `.contentModificationDateKey` and puts the resulting value in visible file rows.
  - `Fonic HiFi/Core/Audio/Diagnostics/SystemMetricsCollector.swift:300-304,353-386` reads `ProcessInfo.processInfo.systemUptime` for elapsed metric calculations; additional direct reads occur at lines 464, 482, and 541.
  - `Fonic HiFi.xcodeproj/project.pbxproj:61-104,169-193,236-253` defines separate filesystem-synchronized app and widget executable roots/resources.
  - Repository-wide live path enumeration found **zero** `PrivacyInfo.xcprivacy` files.
- **Current official requirement:** `APPLE-SRC-002` through `APPLE-SRC-007` state that each bundle using a covered category needs a correctly named, valid manifest and truthful approved reasons. Since 2024-05-01, uploads lacking descriptions for covered APIs are not accepted. A dependency's manifest cannot declare first-party app or extension usage.
- **Impact / execution path:** The app directly triggers User Defaults, File Timestamp, and System Boot Time categories. The widget separately triggers App Group User Defaults. App Store Connect can reject the binary with a missing API declaration before review, even though local builds run. This is a current iOS 26 requirement, not an iOS 27 assumption.
- **Preserving remediation:** Add one manifest to each synchronized executable root. Declare only reasons exercised by that target:
  - App: app-only defaults `CA92.1`; same-App-Group defaults `1C8F.1`; app-container metadata `C617.1`; user-selected files `3B52.1`; timestamps displayed in the file UI `DDA9.1`; elapsed-time calculations `35F9.1`.
  - Widget: same-App-Group defaults `1C8F.1`.
  - Do not invent tracking or collection declarations. Reconcile those separately with App Store Connect and the privacy owner.
- **Safe code/config sample — `Fonic HiFi/PrivacyInfo.xcprivacy`:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
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

- **Safe code/config sample — `Fonic HiFi Widget/PrivacyInfo.xcprivacy`:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
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

The samples are unapplied and must be revalidated against Apple's live reason list and the compiled execution paths immediately before submission.

- **Verification / acceptance criteria:**
  1. `plutil -lint` accepts both files.
  2. Xcode target membership/resource inspection shows one manifest at the top of the built `.app` and one at the top of the embedded `.appex`.
  3. Organizer's generated privacy report contains the app's three categories and the widget's App Group defaults category with only truthful reasons.
  4. Inspect every embedded dynamic library/resource bundle. The pinned AudioKit source appears to process its own manifest, but the final archive—not an upstream tree—is authoritative.
  5. App Store Connect validation reports no missing/invalid Required Reason API declaration.
  6. A privacy owner signs off that manifest collection/tracking declarations and App Store privacy answers match actual practices.
- **Related:** PSR-006, PSR-010.

### PSR-003 — CI cannot validate the current iOS 26 release toolchain

- **Severity:** High
- **Confidence:** Confirmed by static evidence
- **Exact evidence:**
  - `.github/workflows/ci.yml:8-17`
    > `runs-on: macos-15`
    > `Select Xcode 16.1`
    > `sudo xcode-select -s /Applications/Xcode_16.1.app`
  - `.github/workflows/ci.yml:19-36` runs lint, Debug build, tests, and coverage through `make`.
  - `Makefile:29-37`
    > `export DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer`
  - `Fonic HiFi.xcodeproj/project.pbxproj:382-410,430-458` sets deployment target 26.0 and Swift 6.0 for both app configurations; project object version is 90 at `project.pbxproj:1-7`.
- **Current official requirement:** `APPLE-SRC-001` states that since 2026-04-28, uploads need Xcode 26+ and an iOS 26 SDK+. This is a build-SDK minimum, not a rule that every deployment target must be 26.0.
- **Impact / execution path:** Xcode 16.1 cannot supply the iOS 26 SDK. Even before that incompatibility is reached, the Makefile's exported `DEVELOPER_DIR` takes precedence over `xcode-select`, so CI may silently use an unrelated `/Applications/Xcode.app`. The lane therefore cannot establish that source, privacy manifests, entitlements, or Release settings compile under the submission toolchain. This is not proof that the app fails under Xcode 26; it is proof that CI does not test that contract.
- **Preserving remediation:** Select an installed, supported stable Xcode 26.x in one place; remove the Makefile override; assert the actual toolchain/SDK; resolve packages from the lock; then build/test both Debug and Release and archive/sign in a protected lane.
- **Safe code/config sample:**

```diff
--- a/Makefile
+++ b/Makefile
@@
-# Ensure Xcode.app is used instead of CommandLineTools (required for iOS SDK)
-export DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer
+# Honor the workflow's xcode-select / DEVELOPER_DIR choice.
```

```yaml
- name: Select supported Xcode 26 toolchain
  shell: bash
  run: |
    set -euo pipefail
    XCODE_DEVELOPER_DIR="${XCODE_DEVELOPER_DIR:?configure an installed stable Xcode 26.x Developer directory}"
    test -d "$XCODE_DEVELOPER_DIR"
    sudo xcode-select -s "$XCODE_DEVELOPER_DIR"
    test "$(xcodebuild -version | awk 'NR==1 {print $2}' | cut -d. -f1)" -ge 26
    test "$(xcrun --sdk iphoneos --show-sdk-version | cut -d. -f1)" -ge 26
```

Configure `XCODE_DEVELOPER_DIR` from the runner image inventory rather than guessing an application path. Add a Release archive step only in a protected macOS signing environment.

- **Verification / acceptance criteria:**
  1. CI logs show one Xcode 26+ developer directory and iOS 26+ SDK for every `make`/`xcodebuild` command.
  2. `make` no longer overrides the selected toolchain.
  3. Clean Debug and Release simulator builds and tests run with locked package resolution.
  4. A protected distribution lane produces an archive and verifies signatures, app/widget entitlements, embedded manifests, bundle/version parity, export key, and privacy report.
  5. App Store Connect accepts a non-production validation upload.
- **Related:** PSR-002, PSR-010.

### PSR-004 — Release logging marks user library content and diagnostic details public

- **Severity:** High
- **Confidence:** Confirmed by static evidence
- **Exact evidence:**
  - `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:329-347`
    > `logger.info("Playing track: \([REDACTED_TRACK_TITLE], privacy: .public)")`
  - `Fonic HiFi/Shared/AppGroupManager.swift:73-92`
    > `logger.debug("Track info synced: \([REDACTED_TRACK_TITLE], privacy: .public)")`
  - `Fonic HiFi/Shared/WidgetArtworkCache.swift:33-48`
    > `logger.info("Widget artwork cache initialized at: \([REDACTED_PATH], privacy: .public)")`
  - `Fonic HiFi/Data/Actors/FileImportProcessor.swift:361-409,603-619`
    > `Duplicate import skipped ... \([REDACTED_FILENAME], privacy: .public)`
    > `File import failed for \([REDACTED_FILENAME], privacy: .public): \([REDACTED_ERROR], privacy: .public)`
  - `Fonic HiFi/Core/Audio/Services/FormatDetectionCoordinator.swift:29-47,78-104` marks request UUIDs, filenames, and error descriptions public.
  - `Fonic HiFi/Core/Audio/Diagnostics/BitPerfectDeviceManager.swift:116-126`
    > `Estimating bit depth for device: \([REDACTED_ROUTE_NAME], privacy: .public)`
  - `Fonic HiFi/Presentation/Views/Library/TrackRowView.swift:75-103` logs a public track title and an object identity during the user tap/play path.
  - `Fonic HiFi/Presentation/Views/Settings/FileDetailsView.swift:165-184` and `FileManagerView.swift:225-232,265-270,290-300,331-339,373-386` mark filenames, folder names, and errors public.
  - `Fonic HiFi/Utils/Logging/Metrics.swift:31-44` renders arbitrary metadata as one public string; `Fonic HiFi/Data/Services/LibraryImportService.swift:214-266` supplies filenames and failure text.
  - `Fonic HiFi/Utils/Logging/LogPrivacy.swift:3-18` calls a filename “non-sensitive” and only strips directories/truncates text; filenames and short errors can still disclose personal content.
  - Static count: 125 explicit `.public` interpolations on 109 lines across 28 app files. Not every numeric interpolation is sensitive, but the cited content-bearing paths are.
  - `Fonic HiFi.xcodeproj/project.pbxproj:531-587` has normal Release settings and no Release `DEBUG` condition; the cited paths are not generally enclosed in `#if DEBUG`.
- **Official privacy behavior:** Apple's OSLog documentation says sensitive dynamic values should use privacy options that hide the value. Public interpolation emits the value as-is. Error/notice/fault logs can be persisted to the unified log; info can also be collected.
- **Impact / execution path:** Playback, importing, file management, route inspection, and error paths can put listening choices, filenames, folder names, hardware route names, container paths, persistent request identifiers, and error-contained paths into unified logs. Those logs can be viewed during support/diagnostics and may be retained on disk depending on level/collection. Music titles and filenames can reveal health, religion, politics, relationships, or other personal interests. This also undermines the in-app policy's broad privacy assurances.
- **Preserving remediation:** Keep the category architecture and useful structural metrics, but classify data:
  - public: static event names, bounded counts, durations, booleans, format/sample-rate values;
  - private or omitted: titles, artists, filenames, directories, search text, route names, UUIDs, object identities, bookmarks, and error text;
  - hash only when stable correlation is genuinely needed and document the purpose;
  - do not treat truncation or `lastPathComponent` as anonymization.
- **Safe code sample:**

```swift
logger.info(
    "Playback started track=\(track.id.uuidString, privacy: .private(mask: .hash))"
)

logger.error(
    """
    Metadata extraction failed file=\(url.lastPathComponent, privacy: .private(mask: .hash)) \
    error=\(String(describing: error), privacy: .private)
    """
)

// Metrics retain operational value without content-bearing metadata.
Metrics.increment(.importsFailed, metadata: [
    "phase": "metadata",
    "retryable": "false"
])
```

For full paths, prefer omitting the value entirely. Compilation is required to validate OSLog interpolation syntax in each multiline call.

- **Verification / acceptance criteria:**
  1. A source lint/test rejects `.public` on title/artist/query/file/path/url/folder/route/identifier/error fields and rejects free-form public metrics metadata.
  2. Import/play/search/failure scenarios on a Release device generate no raw track title, filename, path, route name, query, UUID, or localized error in Console or an exported log archive outside Xcode.
  3. Necessary correlation values appear only as redacted/hash presentations.
  4. Privacy policy and support runbooks state what technical logs exist and how long support retains user-supplied diagnostics.
- **Related:** PSR-006, PSR-007.

### PSR-005 — Imported audio files retain uncontrolled source protection metadata

- **Severity:** Medium
- **Confidence:** Probable
- **Exact evidence:**
  - `Fonic HiFi/Data/Actors/FileImportProcessor.swift:669-695`
    > `try fileManager.copyItem(at: sourceURL, to: destinationURL)`
    > `return destinationURL`
  - `Fonic HiFi/Data/Services/ImportSession.swift:297-308`
    > `try self.fileManager.copyItem(at: sourceURL, to: destinationURL)`
  - `Fonic HiFi/Presentation/Views/Settings/FileManagerView.swift:303-340`
    > `try fm.copyItem(at: sourceURL, to: targetURL)`
  - Repository-wide live-source search found no `fileProtectionKey`, `NSFileProtection`, `completeFileProtection...`, or `setAttributes` normalization.
  - `Fonic HiFi/Info.plist:7-10` declares background audio and `Fonic HiFi/Core/Audio/Services/AudioSessionManager.swift:71-84` configures `.playback`, so locked/background access is an actual product path.
- **Why this is probable rather than confirmed:** Apple's default class for third-party app data is Protected Until First User Authentication, which is generally compatible with post-unlock background playback. However, `copyItem` can preserve source metadata instead of applying a known destination class. The effective class depends on the provider/source and runtime filesystem behavior; this sandbox cannot inspect it on iOS.
- **Impact / execution path:** A source file carrying Complete Protection may remain inaccessible after lock when the player advances/reopens it; a source with an unexpectedly weak class may remain weaker than the app's intended policy. Either outcome makes protection inconsistent across imported tracks. The finding is not an App Store rejection claim and does not justify setting the whole app container to Complete Protection, which could break background playback, widgets, and SwiftData.
- **Preserving remediation:** Define a product policy for imported playback media. For an offline player expected to advance while locked, explicitly normalize successful copies to `completeUntilFirstUserAuthentication`; fail and remove the copied destination if normalization fails. Apply a separately chosen stronger class only to content that never needs locked/background access. Do not use `NSFileProtectionNone`.
- **Safe code sample:**

```swift
private static func copyPlaybackFile(
    from sourceURL: URL,
    to destinationURL: URL,
    fileManager: FileManager = .default
) throws {
    try fileManager.copyItem(at: sourceURL, to: destinationURL)

    do {
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: destinationURL.path
        )
    } catch {
        try? fileManager.removeItem(at: destinationURL)
        throw error
    }
}
```

A streaming creation API that assigns the class at creation time is preferable if the team needs to eliminate the brief post-copy normalization window. Do not load large audio files wholly into memory to use `Data.write`.

- **Verification / acceptance criteria:**
  1. A DEBUG-only device test imports source files with at least Complete and Until-First-Authentication classes, then checks destination `.protectionKey` without logging any path/name.
  2. After first unlock, lock the device and test current-track continuation, automatic next-track open, previous/next remote commands, widget artwork reads, and relaunch behavior expected by product requirements.
  3. Before first unlock after reboot, protected media/database behavior matches a documented UX.
  4. Copy/protection failure removes partial destinations and leaves no database row.
  5. Archive entitlements and per-file runtime attributes match the approved policy.
- **Related:** PSR-004.

### PSR-006 — In-app privacy disclosure omits material local data and retention/deletion behavior

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Exact evidence:**
  - `Fonic HiFi/Presentation/Views/Settings/SettingsView.swift:131-164` makes `PrivacyPolicyView` easily reachable from Settings.
  - `Fonic HiFi/Presentation/Views/Settings/AppSettingsView.swift:90-130`
    > `Fonic HiFi only accesses your music files with your explicit permission.`
    > `We do not collect, store, or transmit any personal data or music files to external servers.`
    > `All app data, including your music library metadata and preferences, is stored locally on your device.`
  - `Fonic HiFi/Data/Models/Track.swift:11-49,51-110,144-150` persists the copied file URL/name, original URL string/bookmark, rich metadata, artwork, rating, and play count.
  - `Fonic HiFi/Data/Models/ListeningSession.swift:5-39` persists track ID, start/end times, listened duration, completion/skip status, hour, and weekday.
  - `Fonic HiFi/Data/Models/RecentSearch.swift:11-28` persists query text, timestamp, and result count.
  - `Fonic HiFi/Core/AI/Search/SmartSearchService.swift:40-95,145-180` sends the query, listening context, and up to 100 tracks to Apple's on-device `SystemLanguageModel`; no model tool or app networking path was found.
  - `Fonic HiFi/Data/DataManager+Recent.swift:13-26` and `Fonic HiFi/Presentation/Views/Search/SearchView.swift:30-42` provide recent-search deletion. No user-facing listening-session deletion path was found; the observed model remains until store/app removal unless other runtime behavior is added.
- **Current official requirement:** `APPLE-SRC-009` confirms every app needs an easily accessible in-app policy and an App Store Connect policy link. Current App Review Guideline 5.1.1 also requires the policy to identify data handled, collection/use, and retention/deletion behavior. `APPLE-SRC-008` separately says local-only processing is not “collected” for the App Store privacy label unless data or a derivative leaves the device.
- **Impact / execution path:** The existing three-paragraph disclosure is too broad to tell a user that the app copies audio, retains original-source references, records detailed listening history and searches, uses those records for on-device personalization, and has different deletion paths. An App Review/privacy owner cannot reliably reconcile this text with App Store answers. This is a review and user-trust risk, not proof that the app “collects” data under Apple's off-device label definition.
- **Preserving remediation:** Keep the current Settings destination and offline product direction, but expand the policy with: exact on-device categories; purposes; App Group/widget sharing; on-device Foundation Models processing; technical logging after PSR-004; retention periods or events; deletion controls; backup behavior; and a maintained contact/effective date. Ensure the App Store-hosted policy URL has equivalent text.
- **Safe copy sample:**

```swift
Text("On-device data")
    .font(.headline)
Text("""
Fonic HiFi stores imported audio copies, artwork, library metadata, playback settings,
recent searches, and listening history on this device. App Group storage shares current
playback state and artwork with the Fonic HiFi widget. These records support playback,
search, recommendations, and library management.
""")

Text("On-device intelligence")
    .font(.headline)
Text("""
Smart Search and recommendations use Apple's on-device Foundation Models when available.
Fonic HiFi does not provide model tools that send your query or library to an external server.
""")

Text("Retention and deletion")
    .font(.headline)
Text("""
Recent searches can be cleared from Search. Imported files can be removed in File Manager.
Listening history and remaining app data are retained until the app's documented deletion
control removes them or the app is deleted. [Replace this sentence if a different retention
or backup policy is implemented.]
""")
```

The bracketed sentence is an implementation prompt, not production copy; a privacy owner must replace it with verified behavior.

- **Verification / acceptance criteria:**
  1. A data map covers SwiftData, documents, App Group defaults/files, OSLog, Foundation Models prompts, backups, and the AudioKit dependency.
  2. Every policy statement is reproduced on a physical device and backed by code/runtime inspection.
  3. Recent-search, imported-file, listening-history, settings, widget-cache, and full-app deletion behavior is tested and documented.
  4. App Store Connect has a live policy URL, and its App Privacy answers match actual app/dependency off-device transmission.
  5. If the app remains network-free and no third party receives data, “No data collected” is considered under Apple's definition; it is not asserted solely from this source audit.
- **Related:** PSR-002, PSR-004, PSR-010.

### PSR-007 — Local settings, build logs, Xcode user state, and a stale project backup are committed

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Exact evidence:**
  - `build_errors.log:1-35,349-353` is a tracked 376-line tool/build transcript and includes a developer home path at lines 349 and 352:
    > `[REDACTED_HOME]/Documents/.../AudioQueueManagerTests.swift:...`
  - `build_verify.log:1-35,250-268` is a tracked 429-line build transcript with repeated developer home paths and compiler diagnostics:
    > `[REDACTED_HOME]/Documents/.../AudioEngineFacade.swift:...`
  - `Fonic HiFi.xcodeproj/project.pbxproj.backup:1-30` is a tracked 580-line stale project copy; line 6 says `objectVersion = 77`, while the active `Fonic HiFi.xcodeproj/project.pbxproj:1-7` says `objectVersion = 90`.
  - Tracked main-project user-state files:
    - `Fonic HiFi.xcodeproj/project.xcworkspace/xcuserdata/keiran.xcuserdatad/IDEFindNavigatorScopes.plist:1-5`
    - `Fonic HiFi.xcodeproj/xcuserdata/keiran.xcuserdatad/xcschemes/xcschememanagement.plist:1-24`
    - `Fonic HiFi.xcodeproj/xcuserdata/willy.xcuserdatad/xcschemes/xcschememanagement.plist:1-14`
  - `.claude/settings.local.json:1-107` and `.kilocode/mcp.json:1-117` are machine-local configuration; their secret exposure is PSR-001.
  - `.gitignore:5-22` already ignores `xcuserdata/`, but tracked files remain tracked; `.gitignore:108` contains the malformed line `.apdiskbuild_verify.log` rather than a general log rule.
- **Impact / execution path:** Build logs leak developer filesystem structure and tool inventory and can capture future diagnostics, environment arguments, source snippets, or signing paths. User-state files disclose local workflow and create churn. The backup provides a second, stale configuration source that can be edited or mined accidentally. These files are not proven app-bundle resources, so this is repository hygiene/privacy and release reproducibility risk—not a direct App Store binary rejection.
- **Preserving remediation:** Remove generated/user-local artifacts from the index, keep build logs and result bundles in CI artifact storage with retention/access controls, and rely on Git history rather than `.backup` files. Retain only reviewed shared schemes/configuration.
- **Safe code/config sample:**

```gitignore
# Local agent/tool settings
.claude/settings.local.json
.kilocode/mcp.json

# Build/debug transcripts and ad-hoc backups
*.log
*.pbxproj.backup

# Xcode user state (already present; keep one canonical rule)
xcuserdata/
```

```bash
git rm --cached -- \
  "build_errors.log" \
  "build_verify.log" \
  "Fonic HiFi.xcodeproj/project.pbxproj.backup"

git rm -r --cached -- \
  "Fonic HiFi.xcodeproj/project.xcworkspace/xcuserdata" \
  "Fonic HiFi.xcodeproj/xcuserdata"
```

Do not use the command above for PSR-001 until credentials have been revoked and the coordinated history plan is ready.

- **Verification / acceptance criteria:**
  1. A fresh clone contains no `xcuserdata`, raw build log, `.pbxproj.backup`, or local tool config.
  2. CI uploads `.xcresult`, logs, dSYMs, and reports to access-controlled artifact storage with a documented retention period.
  3. Secret scanning is run over generated logs before publication.
  4. The project opens without recreating tracked user-state changes, and the active PBX file is the only project source of truth.
- **Related:** PSR-001, PSR-004.

### PSR-008 — The app claims APNs without a product implementation

- **Severity:** Low
- **Confidence:** Confirmed by static evidence
- **Exact evidence:**
  - `Fonic HiFi/Fonic_HiFi.entitlements:5-10`
    > `<key>aps-environment</key>`
    > `<string>development</string>`
    > `<key>com.apple.security.application-groups</key>`
  - Both app configurations use the file at `Fonic HiFi.xcodeproj/project.pbxproj:370-375,418-423`.
  - Repository-wide first-party search found no `registerForRemoteNotifications`, device-token callbacks, or `UNUserNotificationCenter` usage.
  - `Fonic HiFi/Info.plist:7-10` declares only the `audio` background mode, not `remote-notification`.
- **Impact / execution path:** The unused capability expands the App ID/provisioning profile and signing surface without user value and can cause avoidable profile drift. The literal `development` value is **not** reported as proof of a broken Release signature; Xcode combines the entitlements file and provisioning profile, so the final archive is authoritative.
- **Preserving remediation:** If push is not a shipping feature, remove Push Notifications in Signing & Capabilities and delete only the APS entry, retaining the App Group. If product requirements need push, keep it and implement registration/token/error handling before release.
- **Safe code/config sample:**

```diff
--- a/Fonic HiFi/Fonic_HiFi.entitlements
+++ b/Fonic HiFi/Fonic_HiFi.entitlements
@@
-	<key>aps-environment</key>
-	<string>development</string>
```

- **Verification / acceptance criteria:**
  1. The app target lists no Push Notifications capability unless a tested push feature exists.
  2. Development/distribution profiles remain valid for the retained App Group.
  3. `codesign -d --entitlements :- <archived-app>` has the approved App Group and no APS entitlement when push is removed.
  4. If push is retained, verify the production APS environment in the signed archive and end-to-end token/error handling.
- **Related:** PSR-003.

### PSR-009 — Info.plist claims Live Activity support without an ActivityKit configuration

- **Severity:** Low
- **Confidence:** Confirmed by static evidence
- **Exact evidence:**
  - `Fonic HiFi/Info.plist:5-10`
    > `<key>NSSupportsLiveActivities</key>`
    > `<true/>`
    > `<key>UIBackgroundModes</key>`
  - Repository-wide Swift search found no `import ActivityKit`, `ActivityConfiguration`, or `Activity<...>` construction.
  - `Fonic HiFi/Shared/WidgetArtworkCache.swift:118-131` and related comments mention Live Activity sizing, but comments/helpers do not register a Live Activity surface.
  - `Fonic HiFi Widget/Info.plist:5-11` declares only a WidgetKit extension point.
- **Impact / execution path:** The processed Info.plist advertises support that no target implements. This can confuse capability review, App Store metadata, and future maintainers. It is not treated as a guaranteed rejection and does not invalidate the legitimate background-audio declaration.
- **Preserving remediation:** Remove the key for the current release unless Live Activities are a committed feature. If retained, add a real ActivityKit attributes/configuration/start-update-end lifecycle and test it before shipping.
- **Safe code/config sample:**

```diff
--- a/Fonic HiFi/Info.plist
+++ b/Fonic HiFi/Info.plist
@@
-	<key>NSSupportsLiveActivities</key>
-	<true/>
```

- **Verification / acceptance criteria:**
  1. If removed, the processed app Info.plist contains no `NSSupportsLiveActivities`.
  2. If retained, the extension bundle contains a registered `ActivityConfiguration`, and a physical device can start, update, end, and relaunch-recover it.
  3. Product-page metadata does not claim an unavailable Live Activity.
- **Related:** PSR-008.

### PSR-010 — Export classification is not encoded and needs final-archive determination

- **Severity:** Informational
- **Confidence:** UNVERIFIED — needs build/device check
- **Exact evidence:**
  - `Fonic HiFi/Info.plist:4-11` has only Live Activity/background-mode keys and no `ITSAppUsesNonExemptEncryption`.
  - Generated app Info settings at `Fonic HiFi.xcodeproj/project.pbxproj:382-390,430-438` also contain no export key.
  - `Fonic HiFi/Data/Extensions/Data+Hashing.swift:1-8` and `Fonic HiFi/Data/Extensions/URL+SourceIdentifier.swift:8-20` use CryptoKit `SHA256.hash` for local identifiers/bookmark hashing.
    > `import CryptoKit`
    > `let digest = SHA256.hash(data: [REDACTED_LOCAL_INPUT])`
  - Product-source search found no `URLSession`, Network framework client, app endpoint, TLS override, or custom encryption implementation. The final linked dependency/archive was not available for binary classification.
- **Current official requirement:** `APPLE-SRC-010` through `APPLE-SRC-012` require a deliberate encryption/export determination. Omitting `ITSAppUsesNonExemptEncryption` is permitted but causes the questionnaire for each version. Setting `NO` is truthful only if the app and linked libraries use no encryption or only exempt encryption. Apple says OS-only encryption requires no App Store Connect documentation.
- **Impact / execution path:** There is no proven compliance failure in source. The risk is an inconsistent or guessed App Store Connect answer, especially if the final dependency graph differs from this snapshot. SHA-256 hashing alone does not justify claiming non-exempt encryption, but this static audit is not legal/export classification.
- **Preserving remediation:** Have the release owner classify the final archive and distribution regions. If the determination is “no encryption or exempt only,” encode `NO` to avoid repeated ambiguity. If non-exempt cryptography is present, set `YES` and provide the required code/documentation. Do not copy the sample until the determination is signed off.
- **Safe conditional config sample:**

```xml
<!-- Add only after the final app and every linked library are classified as no/non-exempt encryption. -->
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

- **Verification / acceptance criteria:**
  1. Inspect the final archive's linked frameworks and processed Info.plist.
  2. Record the legal/export rationale, algorithms, dependency versions, and distribution regions.
  3. The App Store Connect answer, plist value, and any compliance code/documentation agree.
  4. Re-run the determination when cryptography, networking, authentication, or dependencies change.
- **Related:** PSR-002, PSR-003, PSR-006.

---

## Verified-good checks and rejected candidate findings

These candidates were investigated and **not** retained as defects:

1. **No additional confirmed secret family:** the current safe locator found three values; independent parsing added the escaped fourth value. The two historical 13-character `password` hits are example inputs in an old authentication-test snippet, not live credentials. They remain useful scanner false-positive fixtures.
2. **No product endpoint or ATS exception:** the safe locator produced 309 URL/IP candidates: 297 public hosts and 12 IP/loopback/private classifications. The only sensitive direct-IP endpoint in active configuration is the redacted local-tool entry in PSR-001. Other private/loopback candidates are example documentation, a disabled loopback tool, or archived plans. Product Swift has no `URLSession`, `NWConnection`, HTTP(S) literal, `WKWebView`, ATS exception, or arbitrary-load key. Default ATS therefore remains intact.
3. **Public URLs in product configuration are expected:** all 11 product/project URL candidates are public plist/SVG namespaces or the public SPM origin. They are not sensitive service endpoints.
4. **No protected-resource permission mismatch was established:** first-party source has no microphone recorder, photo library, location, Contacts, Bluetooth-central, tracking, or authorization request path. The absence of corresponding usage-description keys is therefore not a current crash/review finding. User-selected file access is initiated by the file importer/security-scoped URLs.
5. **No tracking path:** no AppTrackingTransparency, advertising identifier, tracking-domain declaration, ad SDK, or product network client was found. Do not add `NSUserTrackingUsageDescription` preemptively.
6. **Background audio is corroborated:** `Fonic HiFi/Info.plist:7-10` declares only `audio`; `AudioSessionManager.swift:71-84` sets `.playback`; the app has real local playback code. This matches `APPLE-SRC-009`/`APPLE-SRC-013` and is not a keepalive-only mode.
7. **App Group alignment is coherent:** app/widget entitlements and source accessors use the same App Group, and the widget is embedded as a separate executable. The final signed archive still needs verification.
8. **AudioKit manifest candidate rejected:** the exact SPM pin is AudioKit 5.6.5 at revision `5b3fd238ef8ee95c9842ca4ea83ca58ee151e630` (`Package.resolved:3-12`). Read-only inspection of that exact upstream tree found `Sources/AudioKit/Resources/PrivacyInfo.xcprivacy`, and its `Package.swift` processes `Resources`. This does not cure first-party PSR-002 and does not replace final archive inspection.
9. **On-device Foundation Models are not off-device collection by themselves:** source uses `SystemLanguageModel`/`LanguageModelSession`, defines no model `Tool`, and has no app networking fallback. Under `APPLE-SRC-008`, local-only processing is not “collected.” App Store answers remain an owner-controlled metadata check, not something this repository can prove.
10. **Default Data Protection is present:** Apple Platform Security describes Protected Until First User Authentication as the default class for third-party app data. Lack of a global Data Protection entitlement is not itself a defect. PSR-005 is narrower: copied media has no explicit destination-class normalization.
11. **Release debug settings are sane:** Release disables assertions, Metal debug info, and uses dSYMs/validation (`project.pbxproj:531-587`). `MainActorHelpers.swift:12-39` and other verbose engine probes use `#if DEBUG`. PSR-004 remains because many content-bearing logs are not debug-gated.
12. **APS `development` alone is not a release-signature finding:** final APS environment is derived with signing/provisioning. PSR-008 is retained only because no product path uses push.
13. **iOS 27 beta launch rules are not current blockers:** per `APPLE-OOS-003`, requiring iOS 27 scene/launch behavior would be an out-of-scope assumption for this iOS 26 release. Independently, the project requests generated scene and launch metadata at `project.pbxproj:382-390,430-438`, and `FonicHiFiApp.swift` uses `WindowGroup`.
14. **Archived plans/comments are not release evidence:** sensitive-address examples in `Files/plan2/all.md` and networking skill files, permission proposals in archived plans, and Live Activity comments did not become findings without corroborating live product/config paths.

## Open Xcode/device/App Store release checks

All items below are **UNVERIFIED — needs build/device/release-owner check** unless explicitly stated otherwise:

1. Rotate/revoke the four values, review provider access/billing, rewrite history, and verify old fingerprints cannot authenticate.
2. Build and test with a supported stable Xcode 26.x/iOS 26 SDK; capture exact `xcodebuild -version` and SDK version.
3. Archive the Release app with the intended distribution team. Inspect the processed app/extension Info plists, signatures, provisioning profiles, App Group, APS decision, bundle/version parity, and embedded widget.
4. Generate Organizer's privacy report. Confirm app, widget, AudioKit resource bundle, and every embedded executable/library has the correct manifest and truthful reasons. Run App Store Connect validation.
5. Exercise all logging paths in a Release build outside Xcode and inspect an exported log archive for raw titles, filenames, paths, searches, route names, IDs, and errors.
6. Verify actual Data Protection classes for imported media, SwiftData stores, App Group defaults/artwork, and cache files. Lock/reboot/advance tracks to test the approved background-access policy.
7. Compare the live App Store privacy-policy URL and App Privacy answers with copied audio, metadata/artwork, source bookmarks, recent searches, listening history, widget sharing, logs, Foundation Models, backup, and dependency behavior.
8. Complete and record export classification from the final archive; verify the processed `ITSAppUsesNonExemptEncryption` value and App Store Connect answer.
9. Test background playback through lock, foreground/background transitions, interruption/route changes, next-track open, and widget reads. This validates that the legitimate `audio` mode and file-protection policy coexist.
10. Decide whether APNs and Live Activities are release features. Remove stale declarations or ship complete, tested implementations.
11. Confirm CI artifacts/logs have access controls, retention, and redaction; verify a fresh clone contains no local/debug artifacts.
12. Forward-test on iOS 26.6 separately. Do not elevate iOS 27 beta requirements to current iOS 26 blockers.

## Official references used

Primary current-requirement source map: `subagents/11_current_apple_sources.md`, especially:

- `APPLE-SRC-001` — SDK minimum requirements
- `APPLE-SRC-002` through `APPLE-SRC-007` — privacy manifests, Required Reason API categories/reasons, third-party SDK responsibility
- `APPLE-SRC-008` — App Privacy Details and the on-device/off-device collection boundary
- `APPLE-SRC-009` — App Review privacy policy and intended background services
- `APPLE-SRC-010` through `APPLE-SRC-012` — export compliance and `ITSAppUsesNonExemptEncryption`
- `APPLE-SRC-013` — configuring media playback/background audio
- `APPLE-OOS-003` — iOS 27 launch/scene behavior is beta-only and out of the current release scope

Supplemental official Apple guidance used for security behavior, not represented as a new App Store gate:

- OSLog privacy and generating log messages: `https://developer.apple.com/documentation/os/`
- Apple Platform Security, Data Protection classes: `https://support.apple.com/guide/security/data-protection-classes-secb010e978a/web`
- App Review Guidelines 5.1.1: `https://developer.apple.com/app-store/review/guidelines/`

No external source was treated as permission to mutate the repository, and no secret or sensitive address is present in this report.
