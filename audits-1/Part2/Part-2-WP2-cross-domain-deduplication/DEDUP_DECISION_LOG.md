# WP2 cross-domain deduplication decision log

This log records every accepted merge and the principal near-duplicate groups deliberately kept separate. Complete original finding sections are preserved in CANONICAL_FINDINGS.json and evidence/NORMALIZED_FINDINGS.json.

## Accepted canonical clusters

### CAN-001: Four live credentials and a sensitive local endpoint are committed

- Highest source severity: Critical
- Members: PCFG-001, PSR-001
- Domains: Project Configuration, Privacy, Security, and Release
- Rationale: Both records cite the same four exposed values in the same tracked local-tool files and require the same rotate, untrack, history-rewrite, and secret-scanning remediation.
- Evidence to preserve: Keep configuration/reproducibility impact, security exploitability, endpoint/permission context, provider-log review, and full-history cleanup requirements.

Member records:

- Shared path anchors: .claude/settings.local.json, .kilocode/mcp.json
- PCFG-001 [Critical; Project Configuration] Four plaintext credentials are committed in local tool configuration
  - Source: 06_Project_Configuration.md lines 97-146
  - Locations: .kilocode/mcp.json:38-46; .kilocode/mcp.json:70-78; .kilocode/mcp.json:86-93; .claude/settings.local.json:81-84; .kilocode/mcp.json; .claude/settings.local.json
  - Domain impact: Anyone able to read the repository or an old clone can attempt to use the credentials, consume paid quotas, access provider data, or reach a private service. Deleting only the current files does not revoke the credentials or remove them from commit history. The local settings file also exposes a private endpoint and gives project-local automation broad command permissions. Under the audit severity contract, exploitable secret exposure is Critical.
  - Remediation: 1. **Revoke/rotate all four credentials before making a cleanup commit.** Review provider audit logs and billing for unauthorized use.   2. Remove both local files from version control and ignore them. If team configuration is needed, commit sanitized `.example.json` files that reference environment-variable names only and contain no address or credential.   3. Coordinate a history rewrite with all repository users; invalidate forks/caches where possible and force fresh clones.   4. Enable GitHub secret scanning/push protection and a CI secret scanner.
- PSR-001 [Critical; Privacy, Security, and Release] Four live credentials and a sensitive endpoint are committed in tracked local configuration
  - Source: 07_Privacy_Security_Release.md lines 104-175
  - Locations: .kilocode/mcp.json:38-46; .kilocode/mcp.json:70-78; .kilocode/mcp.json:86-93; .claude/settings.local.json:81-84
  - Domain impact: Any repository reader, old clone, fork, backup, CI artifact, or indexed cache can attempt authentication, consume paid quotas, query provider data, or reach the exposed service. Removing only the current lines does not revoke a credential or remove historical copies. The embedded permission command also couples broad local automation permission with a sensitive address and key. This meets the audit definition of exploitable secret exposure.
  - Remediation: Keep the existing developer-tool architecture, but make all machine-specific configuration local and untracked.   1. Revoke/rotate all four values first. Review provider access logs, quota, and billing for use since first exposure.   2. Remove `.claude/settings.local.json` and `.kilocode/mcp.json` from the index and add them to `.gitignore`.   3. Commit sanitized `.example.json` files only if onboarding needs a template; use placeholders and document runtime environment/secret-manager injection. Do not commit a real endpoint.   4. Coordinate a history rewrite after rotation; invalidate forks/caches where possible and require fresh clones.   5. Add pre-commit and CI secret scanning plus host-side push protection.

### CAN-002: App and widget lack required-reason privacy manifests

- Highest source severity: Critical
- Members: PCFG-002, PSR-002
- Domains: Project Configuration, Privacy, Security, and Release
- Rationale: Both records describe the same absent app and widget PrivacyInfo.xcprivacy files, the same covered first-party APIs, and the same per-target required-reason declarations.
- Evidence to preserve: Keep target-membership evidence, exact reason-code guidance, archive inspection, Organizer privacy report, and App Store validation impact.

Member records:

- Shared path anchors: Fonic HiFi Widget/Shared/WidgetConstants.swift, Fonic HiFi/Core/Audio/Diagnostics/SystemMetricsCollector.swift, Fonic HiFi/Core/Audio/Engine/AudioPlaybackSettingsStore.swift, Fonic HiFi/Data/Services/MetadataExtractionService.swift, Fonic HiFi/Presentation/Views/Settings/FileManagerView.swift, Fonic HiFi/Shared/WidgetConstants.swift, PrivacyInfo.xcprivacy
- PCFG-002 [Critical; Project Configuration] App and widget lack required-reason privacy manifests despite direct covered API use
  - Source: 06_Project_Configuration.md lines 147-240
  - Locations: Fonic HiFi/Core/Audio/Engine/AudioPlaybackSettingsStore.swift:3-20,45-54; Fonic HiFi/Shared/WidgetConstants.swift:59-64; Fonic HiFi Widget/Shared/WidgetConstants.swift:59-64; Fonic HiFi/Data/Services/MetadataExtractionService.swift:55-63; Fonic HiFi/Presentation/Views/Settings/FileManagerView.swift:199-221; Fonic HiFi/Presentation/Views/Settings/FileDetailsView.swift:58; Fonic HiFi/Core/Audio/Diagnostics/SystemMetricsCollector.swift:300-304,353-386; PrivacyInfo.xcprivacy; project.pbxproj:169-253
  - Domain impact: `UserDefaults`, file-timestamp/file-metadata APIs, and system boot-time APIs are Apple Required Reason APIs. Apple states that uploads using covered APIs without approved reasons in the target's bundled privacy manifest are not accepted. AudioKit's own resource manifest, if present in the resolved package, cannot declare first-party app or widget usage. The widget also directly accesses App Group defaults and therefore cannot rely on the app's manifest.
  - Remediation: Add `PrivacyInfo.xcprivacy` to both synchronized target roots. For the app, declare standard defaults (`CA92.1`), same-App-Group defaults (`1C8F.1`), the file-metadata reasons actually exercised (`C617.1`, `3B52.1`, `DDA9.1`), and elapsed-time measurement (`35F9.1`). For the widget, declare its same-App-Group defaults use (`1C8F.1`). Revalidate reason codes against Apple's current documentation and the exact execution paths before submission; do not add collection/tracking declarations without a separate data-practice review.
- PSR-002 [Critical; Privacy, Security, and Release] App and widget lack privacy manifests despite first-party Required Reason API use
  - Source: 07_Privacy_Security_Release.md lines 176-276
  - Locations: Fonic HiFi/Core/Audio/Engine/AudioPlaybackSettingsStore.swift:3-20,45-54; Fonic HiFi/Shared/WidgetConstants.swift:59-64; Fonic HiFi Widget/Shared/WidgetConstants.swift:59-64; Fonic HiFi/Shared/WidgetPlaybackState.swift:113-135; Fonic HiFi Widget/Shared/WidgetPlaybackState.swift:113-135; Fonic HiFi/Data/Services/MetadataExtractionService.swift:55-63; Fonic HiFi/Presentation/Views/Settings/FileManagerView.swift:195-222; Fonic HiFi/Core/Audio/Diagnostics/SystemMetricsCollector.swift:300-304,353-386; Fonic HiFi.xcodeproj/project.pbxproj:61-104,169-193,236-253; PrivacyInfo.xcprivacy
  - Domain impact: The app directly triggers User Defaults, File Timestamp, and System Boot Time categories. The widget separately triggers App Group User Defaults. App Store Connect can reject the binary with a missing API declaration before review, even though local builds run. This is a current iOS 26 requirement, not an iOS 27 assumption.
  - Remediation: Add one manifest to each synchronized executable root. Declare only reasons exercised by that target:   - App: app-only defaults `CA92.1`; same-App-Group defaults `1C8F.1`; app-container metadata `C617.1`; user-selected files `3B52.1`; timestamps displayed in the file UI `DDA9.1`; elapsed-time calculations `35F9.1`.   - Widget: same-App-Group defaults `1C8F.1`.   - Do not invent tracking or collection declarations. Reconcile those separately with App Store Connect and the privacy owner.

### CAN-003: CI selects an impossible and internally conflicting iOS 26 toolchain

- Highest source severity: High
- Members: PCFG-003, PSR-003, TRV-001
- Domains: Project Configuration, Privacy, Security, and Release, Testing and Release Verification
- Rationale: All three records trace to Xcode 16.1 plus the Makefile DEVELOPER_DIR override while the project requires the iOS 26 SDK/runtime. They share the same preflight and Xcode 26 remediation.
- Evidence to preserve: Keep build-gate, privacy/release-validation, and test-execution consequences, plus the distinction that this proves CI invalidity rather than source failure under Xcode 26.

Member records:

- Shared path anchors: .github/workflows/ci.yml, Fonic HiFi.xcodeproj/project.pbxproj, Makefile
- PCFG-003 [High; Project Configuration] CI selects Xcode 16.1 for an Xcode/iOS 26 project, and the Makefile overrides that selection
  - Source: 06_Project_Configuration.md lines 241-308
  - Locations: .github/workflows/ci.yml:9-17; Makefile:12-18,32-34; Fonic HiFi.xcodeproj/project.pbxproj:6,256-300,370-414; Fonic HiFi/Presentation/Views/Components/GlassModifiers.swift:45-54,92-104; Fonic HiFi/ContentView.swift:58; Fonic HiFi/Core/AI/Recommendations/RecommendationSchemas.swift:1-6
  - Domain impact: Xcode 16.1 ships the iOS 18.1 SDK and cannot compile the iOS 26 API surface or provide an iOS 26.2 runtime. Further, GNU Make's exported `DEVELOPER_DIR` takes the build tools from `/Applications/Xcode.app` rather than reliably honoring the preceding `xcode-select` command. The workflow can either fail before test execution or run a different Xcode than the step name claims. It is not a trustworthy merge gate.
  - Remediation: Select one installed Xcode 26.x path explicitly, make `DEVELOPER_DIR` and simulator variables overridable, and add a fail-fast toolchain/runtime preflight. Keep runner-image drift visible rather than silently falling back.
- PSR-003 [High; Privacy, Security, and Release] CI cannot validate the current iOS 26 release toolchain
  - Source: 07_Privacy_Security_Release.md lines 277-325
  - Locations: .github/workflows/ci.yml:8-17; .github/workflows/ci.yml:19-36; Makefile:29-37; Fonic HiFi.xcodeproj/project.pbxproj:382-410,430-458; project.pbxproj:1-7
  - Domain impact: Xcode 16.1 cannot supply the iOS 26 SDK. Even before that incompatibility is reached, the Makefile's exported `DEVELOPER_DIR` takes precedence over `xcode-select`, so CI may silently use an unrelated `/Applications/Xcode.app`. The lane therefore cannot establish that source, privacy manifests, entitlements, or Release settings compile under the submission toolchain. This is not proof that the app fails under Xcode 26; it is proof that CI does not test that contract.
  - Remediation: Select an installed, supported stable Xcode 26.x in one place; remove the Makefile override; assert the actual toolchain/SDK; resolve packages from the lock; then build/test both Debug and Release and archive/sign in a protected lane.
- TRV-001 [High; Testing and Release Verification] CI toolchain selection cannot satisfy the declared iOS 26 build
  - Source: 09_Testing_Release_Verification.md lines 65-111
  - Locations: .github/workflows/ci.yml:9-17; Makefile:12-18,32-34; Fonic HiFi.xcodeproj/project.pbxproj:600-618,664-683
  - Domain impact: Xcode 16.1 cannot provide the iOS 26.0 SDK or iOS 26.2 simulator requested by the Makefile. In addition, GNU Make exports `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, so the workflow's `xcode-select` step does not reliably select `/Applications/Xcode_16.1.app` for `make`. The gate can fail before tests start or silently use a different Xcode than the workflow claims. Nothing about production compilation or tests is verified while this contradiction exists.
  - Remediation: Pin one installed Xcode 26.x toolchain, derive the simulator destination from installed runtimes, and fail immediately if the selected SDK/runtime is absent. Do not hard-code a conflicting `DEVELOPER_DIR` in the Makefile.

### CAN-004: No committed shared scheme or test plan defines the CI test action

- Highest source severity: Medium
- Members: PCFG-004, TRV-002
- Domains: Project Configuration, Testing and Release Verification
- Rationale: Both records cite the same absent shared scheme/test plan, reliance on xcuserdata/autogenerated behavior, and lack of a portable target-selection contract.
- Evidence to preserve: Keep project-configuration reproducibility and testing target/count/coverage impacts.

Member records:

- Shared path anchors: Fonic HiFi.xcodeproj/project.pbxproj, Fonic HiFi.xcodeproj/xcuserdata/keiran.xcuserdatad/xcschemes/xcschememanagement.plist, Makefile
- PCFG-004 [Medium; Project Configuration] No versioned shared scheme or test plan defines what CI builds and tests
  - Source: 06_Project_Configuration.md lines 309-342
  - Locations: Makefile:5-6,245-255; Fonic HiFi.xcodeproj/xcuserdata/keiran.xcuserdatad/xcschemes/xcschememanagement.plist:5-21; Fonic HiFi.xcodeproj/project.pbxproj:194-234
  - Domain impact: CI depends on an auto-created scheme whose TestAction is not versioned. A clean machine has no checked contract for which test targets, coverage targets, language/region, launch arguments, sanitizers, or parallelization settings are used. User scheme-management metadata is not a portable substitute. An autogenerated scheme may work locally, but it does not make the release test selection auditable.
  - Remediation: In Xcode 26, share `Fonic HiFi`, create/attach a versioned test plan listing `Fonic HiFiTests` and `Fonic HiFiUITests`, intentionally select coverage targets, and commit the generated files under `Fonic HiFi.xcodeproj/xcshareddata/xcschemes/`. Do not hand-author the scheme XML; Xcode must generate and validate it.
- TRV-002 [Medium; Testing and Release Verification] No shared scheme or test plan defines the release test action
  - Source: 09_Testing_Release_Verification.md lines 112-186
  - Locations: Makefile:245-255; Fonic HiFi.xcodeproj/xcuserdata/keiran.xcuserdatad/xcschemes/xcschememanagement.plist:5-21; Fonic HiFi.xcodeproj/project.pbxproj:194-234
  - Domain impact: The command assumes an autogenerated `Fonic HiFi` scheme. A clean CI checkout has no versioned TestAction specifying unit/UI targets, configurations, language/region, parallelization, repetition, sanitizer options, launch arguments, or coverage targets. Local user metadata naming a scheme is not a portable TestAction. It remains unverified whether both test targets are included on a fresh runner.
  - Remediation: Commit a shared scheme and a test plan. Make the plan explicitly list `Fonic HiFiTests` and `Fonic HiFiUITests`, enable app/widget coverage intentionally, and define deterministic configurations.

### CAN-005: Release, analyzer, archive, and distribution-signing behavior is not gated

- Highest source severity: Medium
- Members: PCFG-007, TRV-014
- Domains: Project Configuration, Testing and Release Verification
- Rationale: Both records identify the same Debug-only CI path and absent Release/analyze/archive/sign/export verification, with materially identical release-lane remediation.
- Evidence to preserve: Keep Release compiler/settings, widget embedding, sanitizer/analyzer, entitlement/profile, dSYM, signing, export, and App Store validation impacts.

Member records:

- Shared path anchors: .github/workflows/ci.yml, Makefile
- PCFG-007 [Medium; Project Configuration] CI never builds/analyzes Release and has no distribution-signing verification contract
  - Source: 06_Project_Configuration.md lines 446-491
  - Locations: .github/workflows/ci.yml:22-32; Makefile:160-185; Makefile:187-199; Makefile:309-319; Fonic HiFi.xcodeproj/project.pbxproj:531-586; project.pbxproj:418-464,749-779
  - Domain impact: Debug success would not exercise whole-module compilation, disabled assertions, dSYM generation, product validation, Release conditional compilation, embedded-extension validation, or distribution entitlement/profile resolution. Automatic local signing may be appropriate, but the repository has no documented automated or manual release-signing acceptance contract.
  - Remediation: After fixing the toolchain, add unsigned Release simulator build and static analysis gates. Separately define a protected macOS signing/archive lane (or documented Xcode Organizer checklist) that verifies both app and widget distribution profiles, final entitlements, embedded extension, bundle IDs, version parity, privacy manifests, and export compliance.
- TRV-014 [Medium; Testing and Release Verification] Release configuration and release-only failure modes are not gated
  - Source: 09_Testing_Release_Verification.md lines 773-814
  - Locations: .github/workflows/ci.yml:19-39; Makefile:160-185; Makefile:187-199; .github/workflows/ci.yml
  - Domain impact: Optimized compilation, `#if DEBUG` differences, whole-module optimization, extension embedding, archive validation, entitlements, resource copying, dead stripping, and signing/export can regress while Debug simulator tests remain green. Sanitizer/race diagnostics and static analyzer findings are not release gates. What remains unverified is the actual distributable artifact.
  - Remediation: Add Release generic-device archive and analyzer jobs on pull requests, and signed export/App Store validation in a protected release workflow. Add separate ASan/TSan jobs where supported.

### CAN-006: Tracked local, generated, user-state, log, and backup artifacts defeat repository hygiene

- Highest source severity: Medium
- Members: PCFG-008, PSR-007, DCA-ART-001
- Domains: Project Configuration, Privacy, Security, and Release, Dead, Partial, and Artifacts
- Rationale: The three records describe the same tracked artifact set and the same untrack/ignore/sanitized-artifact remediation; the dead-code report adds the quantified manifest.
- Evidence to preserve: Keep exact artifact counts, stale-build/reproducibility risk, developer-path/privacy exposure, log-retention guidance, and the separate reference to credential rotation for the local configs.

Member records:

- Shared path anchors: Fonic HiFi.xcodeproj/xcuserdata/keiran.xcuserdatad/xcschemes/xcschememanagement.plist
- PCFG-008 [Medium; Project Configuration] User-specific Xcode state, raw logs, a stale PBX backup, and local settings are tracked
  - Source: 06_Project_Configuration.md lines 492-545
  - Locations: Fonic HiFi.xcodeproj/project.xcworkspace/xcuserdata/keiran.xcuserdatad/IDEFindNavigatorScopes.plist:1-4; Fonic HiFi.xcodeproj/xcuserdata/keiran.xcuserdatad/xcschemes/xcschememanagement.plist:5-21; Fonic HiFi.xcodeproj/xcuserdata/willy.xcuserdatad/xcschemes/xcschememanagement.plist:5-12; .claude/settings.local.json; .kilocode/mcp.json
  - Domain impact: These files create merge churn and machine-specific behavior, expose developer identity/path information, preserve stale diagnostics that can be mistaken for current evidence, and leave a second obsolete PBX graph next to the real project. The tracked status defeats existing ignore rules. This finding does **not** treat the historical build logs as proof that current source builds or fails.
  - Remediation: Remove user state, raw logs, PBX backups, and local settings from the index; keep shared schemes/test plans and the SPM lockfile. Extend ignores for recurring temporary outputs. Store any intentionally retained diagnostic as a sanitized, dated artifact outside the live project root.
- PSR-007 [Medium; Privacy, Security, and Release] Local settings, build logs, Xcode user state, and a stale project backup are committed
  - Source: 07_Privacy_Security_Release.md lines 492-544
  - Locations: Fonic HiFi.xcodeproj/project.pbxproj:1-7; Fonic HiFi.xcodeproj/project.xcworkspace/xcuserdata/keiran.xcuserdatad/IDEFindNavigatorScopes.plist:1-5; Fonic HiFi.xcodeproj/xcuserdata/keiran.xcuserdatad/xcschemes/xcschememanagement.plist:1-24; Fonic HiFi.xcodeproj/xcuserdata/willy.xcuserdatad/xcschemes/xcschememanagement.plist:1-14; .claude/settings.local.json:1-107; .kilocode/mcp.json:1-117
  - Domain impact: Build logs leak developer filesystem structure and tool inventory and can capture future diagnostics, environment arguments, source snippets, or signing paths. User-state files disclose local workflow and create churn. The backup provides a second, stale configuration source that can be edited or mined accidentally. These files are not proven app-bundle resources, so this is repository hygiene/privacy and release reproducibility risk—not a direct App Store binary rejection.
  - Remediation: Remove generated/user-local artifacts from the index, keep build logs and result bundles in CI artifact storage with retention/access controls, and rely on Git history rather than `.backup` files. Retain only reviewed shared schemes/configuration.
- DCA-ART-001 [Low; Dead, Partial, and Artifacts] Fourteen machine/generated/backup artifacts are tracked despite ignore intent
  - Source: 08_Dead_Partial_Artifacts.md lines 336-376
  - Locations: Fonic HiFi.xcodeproj/xcuserdata/keiran.xcuserdatad/xcschemes/xcschememanagement.plist:5-15
  - Domain impact: The tracked set contains three generated logs (98,356 bytes/1,723 lines), six user-specific Xcode-state files (2,171 bytes/85 lines), three copy/backup files (49,688 bytes/1,274 lines), and two local tool configuration files (6,546 bytes/224 lines): 14 files, 156,761 bytes, 3,306 lines. They create noisy diffs, preserve stale build/project state, and can carry machine-local or sensitive configuration. Credential values were not reproduced; the two local configuration files require the redacted security remediation already recorded in PCFG-001/PSR-001.
  - Remediation: Remove these paths from the index, extend `.gitignore` for logs, project backups/copies, and local tool configuration, and retain only sanitized templates where configuration is genuinely shared. Rotate any credential that has ever been committed, following the security audit.

### CAN-007: Info.plist claims Live Activity support without an Activity configuration

- Highest source severity: Low
- Members: PCFG-010, PSR-009
- Domains: Project Configuration, Privacy, Security, and Release
- Rationale: Both records cite NSSupportsLiveActivities with no ActivityKit import, attributes, lifecycle, or ActivityConfiguration and prescribe removal or full implementation.
- Evidence to preserve: Keep capability-metadata drift, release-review, Lock Screen/Dynamic Island, and physical-device verification context.

Member records:

- Shared path anchors: Fonic HiFi/Info.plist
- PCFG-010 [Low; Project Configuration] Info.plist advertises Live Activity support without an Activity configuration
  - Source: 06_Project_Configuration.md lines 578-605
  - Locations: Fonic HiFi/Info.plist:5-6; Fonic HiFi Widget/FonicWidgetBundle.swift:11-16; Fonic HiFi Widget/NowPlayingWidget.swift:13-24
  - Domain impact: The built app declares Live Activity support while its embedded extension provides no Live Activity configuration to start or render. This is capability/metadata drift and can confuse release review, diagnostics, and future developers. `LiveActivityIntent` conformance on button intents does not create an Activity configuration.
  - Remediation: If Live Activities are not shipping, remove `NSSupportsLiveActivities`. If they are intended, implement and register a real `ActivityConfiguration`, add the necessary attributes/state/update lifecycle, and validate on Lock Screen/Dynamic Island before retaining the key.
- PSR-009 [Low; Privacy, Security, and Release] Info.plist claims Live Activity support without an ActivityKit configuration
  - Source: 07_Privacy_Security_Release.md lines 576-605
  - Locations: Fonic HiFi/Info.plist:5-10; Fonic HiFi/Shared/WidgetArtworkCache.swift:118-131; Fonic HiFi Widget/Info.plist:5-11
  - Domain impact: The processed Info.plist advertises support that no target implements. This can confuse capability review, App Store metadata, and future maintainers. It is not treated as a guaranteed rejection and does not invalidate the legitimate background-audio declaration.
  - Remediation: Remove the key for the current release unless Live Activities are a committed feature. If retained, add a real ActivityKit attributes/configuration/start-update-end lifecycle and test it before shipping.

### CAN-008: The app carries an unused APNs capability

- Highest source severity: Low
- Members: PCFG-012, PSR-008
- Domains: Project Configuration, Privacy, Security, and Release
- Rationale: Both records cite the same aps-environment entitlement with no push registration/token/product path and require removing Push Notifications or implementing it fully.
- Evidence to preserve: Keep least-privilege, provisioning/signing drift, App Group preservation, and final signed-archive entitlement verification.

Member records:

- Shared path anchors: Fonic HiFi.xcodeproj/project.pbxproj, Fonic HiFi/Fonic_HiFi.entitlements, Fonic HiFi/Info.plist
- PCFG-012 [Low; Project Configuration] The app claims an unused APNs capability, increasing signing scope without product code
  - Source: 06_Project_Configuration.md lines 635-713
  - Locations: Fonic HiFi/Fonic_HiFi.entitlements:5-10; Fonic HiFi.xcodeproj/project.pbxproj:370-376,418-424; Fonic HiFi/Info.plist:7-10
  - Domain impact: The push entitlement requires the App ID/provisioning profile to carry an unused capability, increasing least-privilege and signing/provisioning complexity. The literal `development` value is not itself proof of a broken Release signature—Apple documents that Xcode derives the final APS environment from the selected provisioning profile—but the capability has no corroborating product path and should not be claimed.
  - Remediation: Remove Push Notifications from Signing & Capabilities and delete `aps-environment` while retaining the App Group entitlement. If push becomes a real requirement, re-add the capability through Xcode and implement registration/token/error handling; verify final distribution entitlements rather than hard-coding production.
- PSR-008 [Low; Privacy, Security, and Release] The app claims APNs without a product implementation
  - Source: 07_Privacy_Security_Release.md lines 545-575
  - Locations: Fonic HiFi/Fonic_HiFi.entitlements:5-10; Fonic HiFi.xcodeproj/project.pbxproj:370-375,418-423; Fonic HiFi/Info.plist:7-10
  - Domain impact: The unused capability expands the App ID/provisioning profile and signing surface without user value and can cause avoidable profile drift. The literal `development` value is **not** reported as proof of a broken Release signature; Xcode combines the entitlements file and provisioning profile, so the final archive is authoritative.
  - Remediation: If push is not a shipping feature, remove Push Notifications in Signing & Capabilities and delete only the APS entry, retaining the App Group. If product requirements need push, keep it and implement registration/token/error handling before release.

### CAN-009: Listening-session tracking exists but is never wired into production

- Highest source severity: High
- Members: DLP-004, DCA-PART-001
- Domains: Data, Library, and Persistence, Dead, Partial, and Artifacts
- Rationale: Both records cite the same nil sessionService/configuration gap in the production service graph and the same configureSessionTracking remediation after the schema fix.
- Evidence to preserve: Keep downstream history, play-count, rediscovery, recommendation, smart-search, preview/fallback construction, and required-dependency guidance.

Member records:

- Shared path anchors: Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift, Fonic HiFi/FonicHiFiApp.swift
- DLP-004 [High; Data, Library, and Persistence] Listening history is never wired into the production audio service
  - Source: 02_Data_Library_Persistence.md lines 258-297
  - Locations: Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:202-208; Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:331-341; Fonic HiFi/FonicHiFiApp.swift:318-347
  - Domain impact: `sessionService` remains `nil`; optional start/end calls are no-ops; `recordListeningSession` and `incrementPlayCount` are never reached. Continue Listening, Recently Played, Most Listened, Rediscover, time-based recommendations, and persisted play counts therefore have no production data source. Runtime UI behavior is **UNVERIFIED — needs build/device check**, but the missing dependency wiring is static and unconditional.
  - Remediation: Configure the existing service in every service graph immediately after constructing `AudioEngineFacade`. Apply DLP-002 first so the model is registered.
- DCA-PART-001 [Medium; Dead, Partial, and Artifacts] Listening-session tracking is implemented but never configured
  - Source: 08_Dead_Partial_Artifacts.md lines 195-227
  - Locations: Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:35-36,167-178,204-208,331-341; Fonic HiFi/FonicHiFiApp.swift:318-345
  - Domain impact: Primary startup creates both `dataManager.trackDataActor` and `audioService` in the same service factory but never connects them. All start/end calls are optional-chained, so playback succeeds while silently recording no sessions. Recent listening, rediscovery, recommendations, and smart-search context then operate on empty/stale history. Wiring this immediately must be coordinated with the separate schema defect: `ListeningSession` must first be present in the active SwiftData schema/migration.
  - Remediation: After resolving DLP-002’s schema/migration issue, call `configureSessionTracking` in primary, preview, and recoverable-fallback service construction whenever a real `DataManager` exists. Prefer making the dependency required in the facade initializer so future constructors cannot forget it.

### CAN-010: Concurrent import deduplication has a check-to-insert race

- Highest source severity: High
- Members: DLP-006, CP-004
- Domains: Data, Library, and Persistence, Concurrency and Performance
- Rationale: Both records describe identical cache snapshots and non-atomic actor-isolated existence checks allowing duplicate copy and Track creation.
- Evidence to preserve: Keep batch-local in-flight claim, persistence-level uniqueness/create-if-absent, alias handling, failure release, and concurrency-test requirements.

Member records:

- Shared path anchors: Fonic HiFi/Data/Actors/FileImportProcessor.swift
- DLP-006 [Medium; Data, Library, and Persistence] Concurrent deduplication is not an atomic claim
  - Source: 02_Data_Library_Persistence.md lines 352-406
  - Locations: Fonic HiFi/Data/Actors/FileImportProcessor.swift:276-303; Fonic HiFi/Data/Actors/FileImportProcessor.swift:363-385; Fonic HiFi/Data/Actors/FileImportProcessor.swift:617-634
  - Domain impact: Initial child tasks receive the same cache snapshot. Two identical URLs in the same selection can both miss the cache, serialize through `trackExists` before either inserts, copy twice, and create two rows. No `@Attribute(.unique)` or atomic source claim closes the check-to-insert window. Exact reproduction is **UNVERIFIED — needs build/device check**, but the race window exists in active source.
  - Remediation: Add a batch-local actor that atomically claims a canonical source identity before copy; retain the claim on success and release on failure. Keep the database check as defense in depth. A durable unique source identity should be considered in the next schema version if imports can originate from more than one service/process.
- CP-004 [High; Concurrency and Performance] Concurrent imports can pass duplicate checks before either commits
  - Source: 03_Concurrency_Performance.md lines 269-337
  - Locations: Fonic HiFi/Data/Actors/FileImportProcessor.swift:273-327,352-385,603-634; Fonic HiFi/Data/Actors/TrackDataActor.swift:480-505
  - Domain impact: each child receives a value snapshot of the cache. The coordinator adds a source identity to the cache only after that child completes. Two identical URLs admitted in the same concurrency window can therefore both miss the cache. Their actor-isolated `trackExists` calls can also both return nil before either task finishes copy/metadata work and calls `createTrack`; actor isolation serializes each check, but it does not make the check-plus-insert transaction atomic across suspension points. The result can be two copied files and two library records for one source.
  - Remediation: claim each source identity synchronously in the single coordinator before launching a child. Keep a set of preexisting plus in-flight hashes, and yield a duplicate result without launching when insertion fails. Add a persistence-level unique import identity (or an atomic `createIfAbsent`) as the final invariant.

### CAN-011: Every pagination request hydrates the full result set to compute an unused count

- Highest source severity: Medium
- Members: DLP-012, CP-014
- Domains: Data, Library, and Persistence, Concurrency and Performance
- Rationale: Both records cite the same pagination helpers and whole-dataset model fetch used as a count on every page while the UI does not consume totalCount.
- Evidence to preserve: Keep large-library complexity, near-quadratic cumulative work, store-side count option, includeTotalCount=false fast path, and 50k-row profiling requirements.

Member records:

- Shared path anchors: Fonic HiFi/Data/Extensions/SwiftDataPagination.swift, Fonic HiFi/Data/Repositories/PaginatedFetch.swift, Fonic HiFi/Data/Repositories/SwiftDataLibraryRepository.swift
- DLP-012 [Medium; Data, Library, and Persistence] Pagination computes counts by hydrating every matching model on every page
  - Source: 02_Data_Library_Persistence.md lines 654-696
  - Locations: Fonic HiFi/Data/Repositories/SwiftDataLibraryRepository.swift:43-49,65-71,97-103,127-133; Fonic HiFi/Data/Repositories/PaginatedFetch.swift:27-29; Fonic HiFi/Data/Extensions/SwiftDataPagination.swift:61-81
  - Domain impact: Each page request performs its limited page fetch and then repeatedly fetches full model objects for the entire result set merely to count them. Loading 100 pages can rescan the same table 100 times; offset cost can also rise with depth. This defeats the repository’s stated large-library purpose and can increase memory/CPU/latency. Exact thresholds are **UNVERIFIED — needs build/device check**.
  - Remediation: Use SwiftData’s store-side count API and request total count only when the UI needs it (the current `LibraryViewModel` does not consume it). Keep the existing `Page` contract.
- CP-014 [Medium; Concurrency and Performance] Pagination implements total count by fetching all models on every page
  - Source: 03_Concurrency_Performance.md lines 825-866
  - Locations: Fonic HiFi/Data/Repositories/SwiftDataLibraryRepository.swift:29-51,54-83,86-113,116-135; Fonic HiFi/Data/Repositories/PaginatedFetch.swift:10-34; Fonic HiFi/Data/Extensions/SwiftDataPagination.swift:55-82
  - Domain impact: every page request for tracks, albums, artists, and playlists sets `includeTotalCount: true`. The custom “count” loops through the entire matching dataset in batches of 512 and fetches model objects. The active view model never reads `Page.totalCount`; it only uses `items`, `nextPage`, and `hasMore`. Consequently each incremental page can rescan the whole table for a value the UI discards, producing near-quadratic cumulative work as a user pages through a large library.
  - Remediation: set `includeTotalCount: false` for active pages because the result is unused. If a future UI needs a count, call SwiftData's count API once for page zero/cache invalidation and cache it independently; do not fetch models to count rows.

### CAN-012: Listening-session replacement is unsequenced and can clear the new session

- Highest source severity: Medium
- Members: DLP-019, CP-005
- Domains: Data, Library, and Persistence, Concurrency and Performance
- Rationale: Both records identify the same unstructured old-session teardown in ListeningSessionService that reads and clears mutable replacement state.
- Evidence to preserve: Keep the broader transition omissions for Next/Previous/auto-advance, exact start-A/start-B race, ordered replacement contract, and playback-lifecycle test matrix.

Member records:

- Shared path anchors: Fonic HiFi/Core/Audio/Analytics/ListeningSessionService.swift
- DLP-019 [Medium; Data, Library, and Persistence] Track transitions omit or race the replacement listening session
  - Source: 02_Data_Library_Persistence.md lines 965-1028
  - Locations: Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:331-341; Fonic HiFi/Core/Audio/Analytics/ListeningSessionService.swift:55-71; Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:405-430; Fonic HiFi/Core/Audio/Coordinators/QueueCoordinator.swift:39-74; Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:171-183
  - Domain impact: Only the public `play(track:)` method starts a session. Manual next, previous, and natural auto-advance end the old session and call `QueueCoordinator` directly; no new session is started for the newly playing queue item. Directly selecting another track has the opposite failure: `startSession` schedules asynchronous cleanup of the old session, immediately installs the new session, and the later MainActor task can observe and clear that replacement. Even after DLP-004 wiring, queue history is incomplete and direct replacement is racy. Runtime playback/history behavior is **UNVERIFIED — needs build/device check**, but both transition paths are static.
  - Remediation: Keep queue playback in `QueueCoordinator`, but centralize transition ownership in `AudioEngineFacade`: synchronously/awaitably finish the old session before playback replacement, call one post-success start hook after every successful transition, and remove the unstructured cleanup `Task` from `startSession`. Do not start a session before playback succeeds.
- CP-005 [Medium; Concurrency and Performance] Old session teardown can clear a newly started listening session
  - Source: 03_Concurrency_Performance.md lines 338-394
  - Locations: Fonic HiFi/Core/Audio/Analytics/ListeningSessionService.swift:55-74,81-102
  - Domain impact: `startSession` is synchronous on the MainActor. The unstructured task cannot complete the actor-isolated `endSession` before the current call stores the replacement. When that task later executes, `endSession` reads and clears the new session, not the old one. Rapid track changes or an overlapping start can therefore discard the session for the track that is actually playing and corrupt play-count/listening analytics.
  - Remediation: make replacement ordered. Either make `startSession` async and await termination before assignment, or capture the old `ActiveSession` value and persist that value without consulting mutable `activeSession` later. The caller should supply the old engine position rather than hard-code zero if the old session is meant to be recorded.

### CAN-013: Import cancellation does not propagate to AsyncStream producers

- Highest source severity: High
- Members: DLP-021, CP-002
- Domains: Data, Library, and Persistence, Concurrency and Performance
- Rationale: Both records cite discarded unstructured producer tasks, absent continuation.onTermination, and continued discovery/copy/persistence after the consumer reports cancellation.
- Evidence to preserve: Keep discovery and processing producers, buffer/yield behavior, copy cancellation limit, cleanup, security-scoped access, and deterministic post-cancel assertions.

Member records:

- Shared path anchors: Fonic HiFi/Data/Actors/FileImportProcessor.swift, Fonic HiFi/Data/Services/LibraryImportService.swift
- DLP-021 [Medium; Data, Library, and Persistence] Import cancellation is not propagated to the stream producer
  - Source: 02_Data_Library_Persistence.md lines 1087-1173
  - Locations: Fonic HiFi/Data/Services/LibraryImportService.swift:108-115; Fonic HiFi/Data/Actors/FileImportProcessor.swift:143-155; Fonic HiFi/Data/Actors/FileImportProcessor.swift:276-334; Fonic HiFi/Data/Services/LibraryImportService.swift:233-241
  - Domain impact: `cancelImport` cancels the consumer task. `processFilesStream` created a separate unstructured `Task`; ending the consumer/`AsyncStream` iteration does not automatically cancel that producer because no `onTermination` handler links them. The producer’s `Task.isCancelled` checks and `group.cancelAll()` therefore may never activate, and queued/in-flight imports can continue copying and saving after the UI reports “Import cancelled.” The number of extra commits depends on scheduling/buffering and is **UNVERIFIED — needs build/device check**, but the missing cancellation link is static.
  - Remediation: Retain the producer task inside the `AsyncStream` builder and cancel it from `continuation.onTermination`. Apply the same pattern to discovery, call `Task.checkCancellation()` between copy/metadata/save phases, and combine it with DLP-005’s compensating delete.
- CP-002 [High; Concurrency and Performance] Import cancellation does not reach AsyncStream producers
  - Source: 03_Concurrency_Performance.md lines 136-192
  - Locations: Fonic HiFi/Data/Actors/FileImportProcessor.swift:101-105,126-156,260-338,456-495; Fonic HiFi/Data/Services/LibraryImportService.swift:193-241
  - Domain impact: both stream builders start unstructured producer tasks and discard their handles. Neither sets `continuation.onTermination`. `cancelImport()` cancels the MainActor consumer and its explicitly owned `discoveryTask`, but cancellation does not propagate into `FileImportProcessor`'s discovery task or the task that owns `withTaskGroup`. The discovery producer also ignores the result of `continuation.yield`; after its consumer terminates it can continue walking a large directory and creating bookmarks. The processing producer can continue bounded copies, metadata extraction, and SwiftData inserts after the UI already says “Import cancelled.” The existing test only checks UI state and `filesProcessed < totalFiles`; it does not assert that disk copies and database inserts stop after cancellation.
  - Remediation: retain each producer handle in its stream and cancel it from `onTermination`; make the producer check cancellation before every new file and before persistence; explicitly await producer shutdown before publishing the canceled state. Accept that `FileManager.copyItem` is not mid-copy cancellable unless replaced with chunked copying, but do not start any new copy after cancellation.

### CAN-014: Queue edit callbacks translate visible offsets to the wrong absolute indices

- Highest source severity: Medium
- Members: AUD-QUEUE-001, UIUX-013
- Domains: Audio Reliability, UI and UX
- Rationale: Both records describe the same currentIndex+1 base error for displayed Up Next delete/move operations and the same queue API/index-translation remediation.
- Evidence to preserve: Keep end-destination and multi-delete semantics plus the separate UI discoverability/edit-mode impact.

Member records:

- Shared path anchors: Fonic HiFi/Presentation/Views/Queue/QueueView.swift
- AUD-QUEUE-001 [Medium; Audio Reliability] Queue edits use the wrong absolute index
  - Source: 01_Audio_Reliability.md lines 387-402
  - Locations: Fonic HiFi/Presentation/Views/Queue/QueueView.swift:40-66
  - Domain impact: The visible Up Next list is `tracks[(currentIndex + 1)...]`, but edit callbacks assume the current track is always array index zero. If currentIndex is 4, deleting visible row 0 removes absolute index 1, not 5; moving can reorder history or the current track. This corrupts the live queue after any progression beyond its first item.
  - Remediation: Convert relative indices using `currentIndex + 1` as the base and implement a queue API that accepts `IndexSet` plus SwiftUI destination semantics atomically. Do not duplicate array-index arithmetic in the view.
- UIUX-013 [Medium; UI and UX] Queue edit controls are undiscoverable and displayed offsets are translated incorrectly
  - Source: 04_UI_UX.md lines 683-745
  - Locations: Fonic HiFi/Presentation/Views/Queue/QueueView.swift:14-28,31-68; Fonic HiFi/Core/Audio/Queue/QueueState.swift:70-75; Fonic HiFi/Core/Audio/Queue/AudioQueueManager.swift:152-193,203-237
  - Domain impact: the displayed list begins at `currentIndex + 1`, not absolute queue index `1`. If the current item is at index 5, deleting displayed row 0 removes queue index 1 — a prior/history item — rather than index 6. Moving has the same base error and also treats Swift's destination offset as a final index; destination can equal the displayed count, while `AudioQueueManager.move` rejects `toIndex == tracks.count`. Multi-delete processes ascending offsets, so earlier removals shift later targets. Finally, `.onMove` and multi-selection edit affordances normally require edit mode on touch-only devices, but the toolbar has only Done.
  - Remediation: expose `EditButton`, compute the visible base from `currentIndex`, apply collection move semantics to a copy of the displayed remainder, and delete in descending order. Keep the same Queue sheet and sections.

### CAN-015: Sleep-timer ownership is transient and fade volume starts from 1.0

- Highest source severity: Medium
- Members: AUD-SLEEP-001, UIUX-007
- Domains: Audio Reliability, UI and UX
- Rationale: Both records cite the same NowPlayingContent-owned SleepTimerManager and hard-coded full-volume baseline, with the same persistent-owner and authoritative-volume remediation.
- Evidence to preserve: Keep dismissal/background/relaunch lifetime, fade jump, cancel/restore semantics, absolute expiry, and single-fire verification.

Member records:

- Shared path anchors: Fonic HiFi/Core/Services/SleepTimerManager.swift, Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift, Fonic HiFi/Presentation/Views/NowPlaying/SleepTimerSheet.swift
- AUD-SLEEP-001 [Medium; Audio Reliability] Sleep timer is view-scoped and its fade assumes full volume
  - Source: 01_Audio_Reliability.md lines 563-584
  - Locations: Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:23-32; Fonic HiFi/ContentView.swift:70-82; Fonic HiFi/Core/Services/SleepTimerManager.swift:33-35; Fonic HiFi/Presentation/Views/NowPlaying/SleepTimerSheet.swift:127-130
  - Domain impact: Dismissing Now Playing destroys the owner and cancels an active timer, so the advertised sleep timer does not reliably survive normal navigation. It is also not persisted/reconstructed across process suspension/relaunch. The sheet always tells the fade logic that volume is 1.0; if playback is at 0.2, fade start can jump close to full volume and completion/cancellation restores full volume. The slider’s persisted volume then disagrees with the engine.
  - Remediation: Own one `SleepTimerManager` at app/audio-facade scope, represent expiry as an absolute `Date`, and inject it into the view. Store/read the engine’s actual app volume, update the shared volume state during fade, and restore only if no user volume change occurred after fade began.
- UIUX-007 [Medium; UI and UX] Sleep-timer ownership is transient and its volume baseline is hard-coded
  - Source: 04_UI_UX.md lines 335-383
  - Locations: Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:31-40,138-155; Fonic HiFi/Presentation/Views/NowPlaying/SleepTimerSheet.swift:19-22,103-130; Fonic HiFi/Core/Services/SleepTimerManager.swift:23-35,39-66,69-95
  - Domain impact: the timer belongs to the transient `NowPlayingContent` presented by `fullScreenCover`. When that view is destroyed, the manager deinitializes and cancels its task, so a user cannot rely on the timer after leaving Now Playing. Separately, the sheet always seeds the manager with volume `1.0`; a timer started at 30% volume fades/restores relative to 100%, and completion restores 100% into the engine for the next playback. This can cause an unexpected volume jump.
  - Remediation: own `SleepTimerManager` in persistent player/app state (at least `ContentView`), pass it into the presented player as `@ObservedObject`, and supply the actual authoritative volume.

### CAN-016: Audio diagnostics report synthetic zero metrics while polling an empty collector

- Highest source severity: Medium
- Members: AUD-DIAG-001, DCA-PART-005
- Domains: Audio Reliability, Dead, Partial, and Artifacts
- Rationale: Both records cite AudioKitEngineAdapter fixed-zero metrics and empty collection, producing false healthy diagnostics while paying polling overhead.
- Evidence to preserve: Keep native-adapter synthetic metric concerns, unsupported-versus-zero modeling, diagnostic scores/exports, output-tap gating, and device instrumentation requirements.

Member records:

- Shared path anchors: Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift
- AUD-DIAG-001 [Medium; Audio Reliability] Engine metrics are synthetic while native monitoring overhead is unconditional
  - Source: 01_Audio_Reliability.md lines 585-613
  - Locations: Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift:240-253; Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:404-417; Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:561-582; Fonic HiFi/Presentation/Views/NowPlaying/DiagnosticsDetailView.swift:95-113
  - Domain impact: The default AudioKit engine can report perfect zero errors/latency without measurement. The native engine displays fixed latency/fill/drop values and equates a zero-frame tap callback with underrun, which is not a reliable underrun detector. These values feed diagnostics, scores, alerts, and exports as facts. Meanwhile the native output tap runs on every render even though broader runtime monitoring defaults off in Release; the tap’s diagnostic value is not established.
  - Remediation: Mark unavailable fields as optional/unsupported, not zero. Populate only from measured timestamps/render callbacks/session latency or remove the field. Gate taps behind the runtime-monitoring setting and remove them atomically when disabled; keep the realtime block allocation/lock free. Never derive quality/reliability scores from placeholders.
- DCA-PART-005 [Medium; Dead, Partial, and Artifacts] AudioKit diagnostics return fixed zero metrics while an empty collector is polled
  - Source: 08_Dead_Partial_Artifacts.md lines 312-335
  - Locations: Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift:240-253; Fonic HiFi/Core/Audio/Diagnostics/AudioMonitorEngineHooks.swift:69-82; Fonic HiFi/Core/Audio/Diagnostics/EngineMetricsCollector.swift:19-38
  - Domain impact: When AudioKit is active, monitoring repeatedly calls an empty method and the reporting path converts a fixed all-zero snapshot into diagnostics. This can present “healthy” zero underruns/latency/load rather than “unavailable,” undermining troubleshooting and any recommendations built on the data while still paying polling/task overhead.
  - Remediation: Either implement measurable AudioKit metrics and update stored samples, or remove `collectMetrics` polling from the engine protocol and model unsupported fields explicitly as unavailable. Never encode missing measurements as successful zero values.

### CAN-017: Widget synchronization is stale and poll-driven

- Highest source severity: Medium
- Members: AUD-WIDGET-001, DLP-016, CP-006
- Domains: Audio Reliability, Data, Library, and Persistence, Concurrency and Performance
- Rationale: All three records describe the same widget synchronization path: frozen elapsed time/stale state and a 500 ms MainActor queue poll that still misses mode-only changes. They share an event-driven snapshot/timestamp/rate remediation.
- Evidence to preserve: Keep progress projection, stale-playing policy, shuffle/repeat propagation, playback-rate correctness, bounded App Group writes, idle/background energy cost, and lifecycle teardown.

Member records:

- Shared path anchors: No single path shared by every member; cluster is connected through pairwise path/explicit-related anchors.
- AUD-WIDGET-001 [Medium; Audio Reliability] Widget time and queue modes become stale while the app polls forever
  - Source: 01_Audio_Reliability.md lines 614-671
  - Locations: Fonic HiFi/Core/Services/WidgetDataCoordinator.swift:71-93; Fonic HiFi/Shared/AppGroupManager.swift:50-64; Fonic HiFi Widget/Views/MediumWidgetView.swift:81-105; Fonic HiFi/Core/Services/WidgetDataCoordinator.swift:184-203
  - Domain impact: Playback-state updates occur, but `AppGroupManager` intentionally discards elapsed-time-only changes. Widget views do not interpolate from timestamp/rate or use a timer-range view, so their progress/time remain frozen at the last meaningful state even when the timeline reloads. Queue polling misses shuffle/repeat changes because it compares only track ID/count; direct in-app mode toggles do not call full widget sync. Polling on MainActor twice per second continues while idle and is still insufficient for correctness. Non-1× playback would be wrong even with interpolation because 1.0 is exported.
  - Remediation: Replace polling with explicit queue mutation/state publishers or coordinator callbacks. Persist timestamp plus actual playback rate and derive effective elapsed time in widget entries, bounded by duration; use supported timer/progress rendering and a budget-conscious timeline. Sync shuffle/repeat immediately on mutation.
- DLP-016 [Medium; Data, Library, and Persistence] Widget state freezes progress and can remain “playing” after becoming stale
  - Source: 02_Data_Library_Persistence.md lines 834-881
  - Locations: Fonic HiFi/Shared/AppGroupManager.swift:53-63; Fonic HiFi Widget/Shared/WidgetPlaybackState.swift:66-94; Fonic HiFi Widget/NowPlayingEntry.swift:43-49; Fonic HiFi Widget/NowPlayingTimelineProvider.swift:36-49
  - Domain impact: The app intentionally does not persist current-time-only updates. The widget’s `progress` ignores `timestamp` and `playbackRate`, so each scheduled timeline reload reads the same `currentTime`; the bar remains frozen. `isStale` exists but `fromAppGroup` never uses it, so a crash/force quit can leave the widget reporting playing indefinitely and requesting minute refreshes. Device scheduling/render behavior is **UNVERIFIED — needs build/device check**.
  - Remediation: Persist bounded checkpoints and derive projected time from the snapshot timestamp/rate. Resolve stale snapshots to paused/idle according to product policy; do not write every audio tick.
- CP-006 [Medium; Concurrency and Performance] Widget synchronization polls the queue every 500 ms even when idle
  - Source: 03_Concurrency_Performance.md lines 395-443
  - Locations: Fonic HiFi/FonicHiFiApp.swift:318-339; Fonic HiFi/Core/Services/WidgetDataCoordinator.swift:28-32,56-94
  - Domain impact: primary, preview, and fallback service construction all create this coordinator. Its task wakes at the configured 500 ms interval for the coordinator's lifetime, even when the queue is idle and unchanged. During background audio playback that is a configured two wakeups per second on the MainActor, each creating a queue snapshot containing queue/history arrays just to compare current ID and count. The weak capture prevents a permanent owner cycle, but it does not remove the process-lifetime wake source because the app intentionally retains the coordinator.
  - Remediation: replace polling with a queue-change publisher/observation callback emitted only when tracks/current index/shuffle/repeat change. Subscribe with a weak capture and debounce only the widget reload, not state detection. If polling must remain as a fallback, start it only while playback is active, move the weak-self check after sleep, use a much longer tolerance-aware clock, and expose an explicit `stop()` invoked by the lifecycle owner.

### CAN-018: Primary library and mini-player actions use raw gestures instead of semantic controls

- Highest source severity: High
- Members: UIUX-015, A11Y-001
- Domains: UI and UX, Accessibility and Localization
- Rationale: Both records identify the same onTapGesture action surfaces in overlapping library paths and prescribe native Button/NavigationLink or explicit default actions.
- Evidence to preserve: Keep general interaction semantics, compound Play/Info row design, mini-player Open Now Playing action, VoiceOver, keyboard, Switch Control, and Voice Control impact.

Member records:

- Shared path anchors: Fonic HiFi/Presentation/Views/Library/LibraryView.swift
- UIUX-015 [Medium; UI and UX] Active tap targets use raw gestures instead of semantic controls
  - Source: 04_UI_UX.md lines 785-830
  - Locations: Fonic HiFi/Presentation/Views/Home/Sections/ArtistsSection.swift:21-30; Fonic HiFi/Presentation/Views/Home/Sections/GenresSection.swift:21-28; Fonic HiFi/Presentation/Views/Home/Sections/RecentlyAddedSection.swift:21-30; Fonic HiFi/Presentation/Views/Library/LibraryView.swift:195-208,217-239,250-280; Fonic HiFi/Presentation/Views/Library/TrackRowView.swift:59-65
  - Domain impact: these are primary actions implemented as gestures on layout views. They do not automatically receive Button traits, activation semantics, keyboard/Voice Control behavior, disabled state, or standard pressed feedback. Some content is therefore harder or impossible to discover and activate with assistive input. The library track row also contains a separate Info `Button`, so its primary play action needs deliberate sibling semantics rather than a gesture on their shared container.
  - Remediation: replace one-action gesture surfaces with plain-styled `Button`/`NavigationLink`. For compound rows, make Play and Info distinct semantic controls, or add an explicit default accessibility action while preserving separate Info.
- A11Y-001 [High; Accessibility and Localization] Core library and mini-player actions use raw tap gestures instead of semantic controls
  - Source: 05_Accessibility_Localization.md lines 51-131
  - Locations: Fonic HiFi/Presentation/Views/Library/LibraryView.swift:195-204,217-239,250-280; Fonic HiFi/Presentation/Views/Library/LibraryView.swift:378-418; Fonic HiFi/ContentView.swift:58-68; Fonic HiFi/Presentation/Views/NowPlaying/LiquidGlassMiniPlayer.swift:18-32,36-51
  - Domain impact: `onTapGesture` supplies pointer/touch behavior but does not make these composite rows native `Button`/`NavigationLink` controls. The active track row compounds the problem: its only native button is the trailing Info button (`LibraryView.swift:407-414`), while the primary “play this track” action is attached outside the row as a raw gesture. A semantic accessibility tree can therefore expose title/artist text and Info without a dependable Play action. The same pattern opens albums, artists, playlists, and the full Now Playing screen. This threatens common-path VoiceOver activation, Full Keyboard Access, Voice Control naming, and Switch Control item scanning. The exact runtime hierarchy remains a device check, hence “Probable.”
  - Remediation: Keep the current layouts and destinations, but separate each action into native controls. For the track row, make the summary area a plain-styled `Button` for Play and retain a distinct Info button; do not nest one button inside another. Use `NavigationLink` for actual navigation and `Button` for sheets/playback. Give the mini-player's artwork/title region its own “Open Now Playing” button while leaving Play and Next as sibling buttons. Combine only the descriptive children of each action.

### CAN-019: The 10-band EQ is a drag-only, undersized, non-adjustable control

- Highest source severity: High
- Members: UIUX-020, A11Y-002
- Domains: UI and UX, Accessibility and Localization
- Rationale: Both records cite the same VerticalSlider implementation, fixed 30-point width, DragGesture-only input, and missing adjustable/focus/keyboard semantics.
- Evidence to preserve: Keep narrow-layout reachability, 44-point hit area, frequency/dB labels, 0.5 dB steps, native-versus-custom implementation options, and all assistive-input tests.

Member records:

- Shared path anchors: Fonic HiFi/Presentation/Views/Settings/EqualizerView.swift
- UIUX-020 [Medium; UI and UX] The 10-band EQ is a gesture-only fixed-width control
  - Source: 04_UI_UX.md lines 1040-1213
  - Locations: Fonic HiFi/Presentation/Views/Settings/EqualizerView.swift:71-121,167-221
  - Domain impact: all ten bands are forced into one non-scrolling `HStack`, each custom control is 30 points wide, and its only input is a `DragGesture`. `VerticalSlider` exposes no accessibility element, label, current dB value, adjustable action, focus action, or keyboard alternative. VoiceOver/Switch Control cannot adjust it, while narrow/landscape widths compress or clip the ten-band strip and large labels. This is a primary audiophile control, not decorative content.
  - Remediation: retain the ten vertical bands, frequencies, colors, and 0.5 dB behavior, but make each band an adjustable accessibility element and provide enough horizontal room (or a horizontal scroll container) without shrinking the control.
- A11Y-002 [High; Accessibility and Localization] The 10-band EQ is drag-only and has no adjustable, focus, or keyboard semantics
  - Source: 05_Accessibility_Localization.md lines 132-211
  - Locations: Fonic HiFi/Presentation/Views/Settings/EqualizerView.swift:90-118,167-221
  - Domain impact: Each band is a custom drawing plus `DragGesture`. It has no `.accessibilityLabel`, `.accessibilityValue`, `.accessibilityAdjustableAction`, native `Slider`, `.focusable`, or key action. A VoiceOver user cannot discover which frequency the control edits or increment/decrement its gain through the adjustable rotor. A keyboard or Switch Control user has no semantic adjustment action, and the 30-point-wide control is also below the 44-point touch recommendation. This blocks a complete product feature for multiple assistive technologies. Runtime inspection is still required to confirm exactly what iOS exposes.
  - Remediation: Preserve the vertical EQ design and 0.5 dB snapping, but either (a) use a native `Slider` rotated/laid out vertically while keeping the existing visuals, or (b) make the custom view a single adjustable element with frequency label, localized dB value, increment/decrement logic, a minimum 44-point hit area, and Up/Down key handling. Pass the frequency into `VerticalSlider` rather than leaving it in a visually adjacent `Text`.

### CAN-020: Accessibility, Dynamic Type, locale, RTL, and widget behavior lack a real verification lane

- Highest source severity: Informational
- Members: A11YTEST-001, TRV-012
- Domains: Accessibility and Localization, Testing and Release Verification
- Rationale: Both records identify the same absent accessibility audit/configuration coverage and the same automated audit plus manual device-matrix remediation.
- Evidence to preserve: Keep skip-on-missing behavior, stable identifiers, AX5/RTL configurations, widget coverage, focus/order, contrast, Reduce Motion/Transparency, Switch Control, and physical-device limits.

Member records:

- Shared path anchors: Fonic HiFiUITests/LibraryNowPlayingSmokeTests.swift
- A11YTEST-001 [Informational; Accessibility and Localization] Accessibility, Dynamic Type, locale, RTL, and widget accessibility have no automated coverage
  - Source: 05_Accessibility_Localization.md lines 762-847
  - Locations: Fonic HiFiUITests/LibraryNowPlayingSmokeTests.swift:1-117; Fonic HiFi/ContentView.swift:58-68; Fonic HiFi/Presentation/Views/NowPlaying/LiquidGlassMiniPlayer.swift:18-32
  - Domain impact: `Fonic HiFiUITests` contains this single Swift file. It does not call `performAccessibilityAudit`, launch at accessibility content sizes, set `AppleLanguages`/`AppleLocale`, test RTL, exercise Reduce Motion/Transparency, or cover the widget. The tests query English labels directly. Both Now Playing tests query “MiniPlayer,” but the source call site assigns no `.accessibilityIdentifier("MiniPlayer")`; each test then skips rather than failing, so the most relevant interaction coverage can silently disappear. This is a verification gap, not proof that every runtime surface fails.
  - Remediation: Add stable, nonlocalized accessibility identifiers used only for automation; replace skip-on-missing for required preview data with a failure; add default and AX5/RTL test-plan configurations; run `XCUIApplication.performAccessibilityAudit()` on Home, Library, Search, Now Playing, Lyrics, Queue, Settings/EQ, Import, and error states. Keep manual VoiceOver/Switch Control/widget checks because automation does not prove scan order or usability.
- TRV-012 [Informational; Testing and Release Verification] Accessibility verification is absent
  - Source: 09_Testing_Release_Verification.md lines 697-735
  - Locations: Fonic HiFiUITests/LibraryNowPlayingSmokeTests.swift:10-17,28-117; Fonic HiFi/Presentation/Views/Components/CustomProgressSlider.swift:87-125; Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:158-160,175-203,375-506; Fonic HiFi.xcodeproj/project.pbxproj:610-618,674-683
  - Domain impact: Labels in source do not prove VoiceOver focus order, adjustable actions, state announcements, hit regions, contrast, Dynamic Type clipping, Reduce Motion, Switch Control, localization, or landscape/small-screen behavior. The UI suite never changes accessibility settings or invokes XCTest's accessibility audit.
  - Remediation: Add automated accessibility audits and explicit interaction tests, then run a manual physical-device matrix for behavior automation cannot certify.

### CAN-021: Surprise Me lacks a single-flight gate for its shared model session and playback side effects

- Highest source severity: Medium
- Members: UIUX-019, FMA-001
- Domains: UI and UX, Foundation Models
- Rationale: Both records share the same enabled repeated action and existing busy state. One records queue/playback races; the other records the same overlap violating the shared LanguageModelSession single-request contract.
- Evidence to preserve: Keep progress UI, action disablement, admission gate, isResponding/fresh-session option, exact one queue/playback side effect, and eligible-device runtime uncertainty.

Member records:

- Shared path anchors: Fonic HiFi/Presentation/Views/Home/HomeView.swift, Fonic HiFi/Presentation/Views/Home/Sections/QuickActionsSection.swift
- UIUX-019 [Medium; UI and UX] “Surprise Me” has tracked loading state that the UI never renders
  - Source: 04_UI_UX.md lines 982-1039
  - Locations: Fonic HiFi/Presentation/Views/Home/HomeView.swift:32-37,89-108,260-299; Fonic HiFi/Presentation/Views/Home/Sections/QuickActionsSection.swift:11-35
  - Domain impact: the async recommendation path intentionally records a busy state while it loads listening sessions, invokes the recommendation service, fetches tracks, replaces the queue, and starts playback. No view reads that state, so the button never shows progress and remains enabled. Repeated taps can launch concurrent recommendation tasks that each replace the queue and attempt playback; the final result depends on completion order, with no indication that work is underway.
  - Remediation: pass the existing `isGeneratingRecommendations` value into `QuickActionsSection`, retain the same label/icon/style, show a small `ProgressView`, and disable repeat activation until the task finishes.
- FMA-001 [Medium; Foundation Models] A shared session can receive overlapping recommendation requests
  - Source: WP1_FOUNDATION_MODELS_REVIEW.md lines 62-130
  - Locations: Fonic HiFi/Core/AI/Recommendations/RecommendationService.swift:7-13,91-134,172-189; Fonic HiFi/Presentation/Views/Home/HomeView.swift:32-36,260-299; Fonic HiFi/Presentation/Views/Home/Sections/QuickActionsSection.swift:26-33; evidence/APPLE_SOURCES.md
  - Domain impact: Rapidly tapping Surprise Me can overlap two calls to `generateSurpriseMix`. Both can obtain the same cached session and call `respond`. At minimum, one request can fail and fall back while both tasks still race to replace the queue and start playback. Apple documents the overlapping-session call as a runtime error, but whether this exact iOS 26 build throws a catchable generation error or traps must be verified on an eligible device.  The existing UIUX-019 already identifies the repeated-action and queue race. This finding adds the Foundation Models session-contract impact. Formal deduplication belongs to Work Package 2.
  - Remediation: - Make the existing busy state the single admission gate before creating a task. - Disable the action while generation is active. - Check `session.isResponding` before every shared-session call. - Prefer a fresh session for these independent single-turn recommendation requests, as Apple recommends for single-turn interactions. - Do not introduce a new recommendation architecture solely for this fix.

### CAN-022: Failures are collapsed into silence, false emptiness, or generic fallback states

- Highest source severity: High
- Members: UIUX-009, FMA-004
- Domains: UI and UX, Foundation Models
- Rationale: The Foundation Models record is the Smart Search/model-status slice of the broader UI failure-state defect: distinct failures are discarded and SearchView does not render its error state. Both require typed state and user-safe reason preservation.
- Evidence to preserve: Keep audio initialization, Home, standard search, File Manager, Foundation Models availability reasons, asset loss, locale, guardrail, context, cancellation, privacy-safe logging, and retry/recovery distinctions.

Member records:

- Shared path anchors: Fonic HiFi/Presentation/ViewModels/SmartSearchViewModel.swift, Fonic HiFi/Presentation/Views/Search/SearchView.swift
- UIUX-009 [High; UI and UX] Playback and browse failures are logged but surfaced as silence or false emptiness
  - Source: 04_UI_UX.md lines 440-506
  - Locations: Fonic HiFi/FonicHiFiApp.swift:155-191; Fonic HiFi/Presentation/Views/Home/HomeView.swift:45-55,186-237,302-310; Fonic HiFi/Presentation/Views/Search/SearchView.swift:44-75,123-152; Fonic HiFi/Presentation/ViewModels/SmartSearchViewModel.swift:82-95; Fonic HiFi/Presentation/Views/Settings/FileManagerView.swift:195-233
  - Domain impact: an audio initialization error leaves `isReady == false` and makes playback impossible, but the existing `launchError` alert is never updated. Home catches any data error and then evaluates `isEmpty`, telling users to import music even if their library failed to load. Standard search converts errors into “No results”; Smart Search has `.error(String)` but the body never renders that state; File Manager retains an empty list after load failure. These are materially different states with different recovery actions, and the current UI misdiagnoses them.
  - Remediation: model loading as idle/loading/content/empty/error at each owning surface; show the existing content for real emptiness and a small retryable unavailable view for errors. Reuse the existing launch alert for audio initialization.
- FMA-004 [Medium; Foundation Models] Availability, runtime asset loss, locale failure, and model errors collapse into booleans or generic fallback
  - Source: WP1_FOUNDATION_MODELS_REVIEW.md lines 267-324
  - Locations: Fonic HiFi/Core/AI/Recommendations/RecommendationService.swift:21-29,39-86,96-135; Fonic HiFi/Core/AI/Search/SmartSearchService.swift:21-29,55-110; Fonic HiFi/Presentation/ViewModels/SmartSearchViewModel.swift:38-43; Fonic HiFi/Presentation/Views/Search/SearchView.swift:44-75
  - Domain impact: The same false/generic-fallback path represents materially different states:  - ineligible device - Apple Intelligence disabled - model assets still downloading or temporarily unavailable - assets removed while the app is running - unsupported language or locale - guardrail refusal - context overflow - decoding or other generation failure - cancellation  Apple documents reason-specific availability UI, runtime `assetsUnavailable`, locale preflight, and user-facing handling for unsupported languages and guardrail failures. See A1, A4, A5, and A7.
  - Remediation: Define a small app-owned model-status/error type that preserves the Apple reason without exposing raw framework diagnostics. Map each case to one of: available, unavailable-permanent, unavailable-user-action, unavailable-temporary, unsupported-language, safety-refusal, canceled, or generation-failed. Keep deterministic fallbacks, but return the reason with the fallback so the caller can present the correct state.  Do not expose private prompt or library content in errors or logs.

### CAN-023: Persisted EQ is not restored or reapplied across engine creation and switching

- Highest source severity: Medium
- Members: AUD-DSP-001, DCA-PART-002
- Domains: Audio Reliability, Dead, Partial, and Artifacts
- Rationale: DCA-PART-002 is the persisted-EQ subset of AUD-DSP-001 and cites the same facade/helper/engine-switch gap with the same load-and-apply remediation.
- Evidence to preserve: Keep the broader engine capability/replay-gain divergence, one authoritative EQ state, cold launch/recreation/auto-advance coverage, and unsupported-engine UI state.

Member records:

- Shared path anchors: Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift
- AUD-DSP-001 [Medium; Audio Reliability] DSP capability and persistence silently diverge by engine
  - Source: 01_Audio_Reliability.md lines 361-386
  - Locations: Fonic HiFi/Core/Audio/Factory/AudioEngineFactory.swift:124-137; Fonic HiFi/Core/Audio/Interfaces/AudioEngineService.swift:126-156; Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:247-263; Fonic HiFi/Presentation/Views/Settings/EqualizerView.swift:133-153
  - Domain impact: The default AudioKit adapter does not override EQ support, so the fully interactive Equalizer UI persists enabled state and shows “DSP Active” while playback remains unchanged. The native adapter supports EQ but inherits the no-op replay-gain implementation, so Replay Gain silently does nothing on that engine. Persisted EQ is never loaded/applied during facade initialization and `reapplyEQConfiguration` has no active call site after engine creation/switch. Users therefore cannot trust DSP state, and switching engines changes sound features without feedback.
  - Remediation: Add an explicit engine capability model (`supportsEQ`, replay gain, rate, gapless, crossfade) and gate controls/selection. Implement equivalent DSP or clearly disable it. Load the persisted EQ once during facade initialization and apply it after each successful engine creation before playback; if unsupported, expose an actionable UI state rather than a log.
- DCA-PART-002 [Medium; Dead, Partial, and Artifacts] Persisted EQ is neither restored nor reapplied after engine creation/switch
  - Source: 08_Dead_Partial_Artifacts.md lines 228-252
  - Locations: Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:74-75,247-264,268-280; Fonic HiFi/Core/Audio/Engine/AudioPlaybackSettingsStore.swift:85-99; Fonic HiFi/Core/Audio/Engine/AudioEngineManager.swift:124-145
  - Domain impact: The EQ view persists changes, but facade initialization merges only crossfade, replay gain, playback rate, and gapless settings. `currentEQConfiguration` therefore starts flat/default. When `AudioEngineManager` creates a new adapter after format or preference change, neither manager nor controller reapplies the stored EQ; the dedicated helper is never called. Users can see a persisted enabled preset while playback is flat, and an engine switch can silently drop a live EQ.
  - Remediation: Make EQ part of the engine-preparation contract. Load the persisted configuration during facade initialization, then apply it whenever `ensureEngine` returns a newly created/recreated engine and before playback starts. Keep one authoritative configuration; do not make individual views responsible for restoring engine state.

### CAN-024: Visible audio settings persist values but do not configure the active audio engine

- Highest source severity: High
- Members: AUD-CONFIG-001, UIUX-008
- Domains: Audio Reliability, UI and UX
- Rationale: AUD-CONFIG-001 is the bit-perfect/buffer/sample-rate subset of the broader inert-settings record and shares the same defaults-only, no-runtime-consumer root cause.
- Evidence to preserve: Keep the additional inert appearance/haptics/file actions, authoritative effective-value UI, source-rate wording, buffer application, route sample-rate verification, and remove-until-real option.

Member records:

- Shared path anchors: Fonic HiFi/Core/Audio/Interfaces/AudioEngineConfiguration.swift, Fonic HiFi/Presentation/Views/Settings/AudioSettingsView.swift
- AUD-CONFIG-001 [Medium; Audio Reliability] Bit-perfect, buffer, and sample-rate controls do not configure audio
  - Source: 01_Audio_Reliability.md lines 213-238
  - Locations: Fonic HiFi/Presentation/Views/Settings/AudioSettingsView.swift:11-84; Fonic HiFi/Core/Audio/Engine/AudioPlaybackSettingsStore.swift:23-42; Fonic HiFi/Core/Audio/Interfaces/AudioEngineConfiguration.swift:49-67
  - Domain impact: These controls write unrelated `UserDefaults` keys but have no `onChange` bridge into `AudioEngineFacade`, and the settings store does not read them during initialization. Playback keeps the configuration defaults: bit-perfect enabled internally regardless of the UI toggle, source-rate preference rather than the selected rate, and a 512-frame logical value that neither adapter applies. The UI explicitly promises quality/latency effects that do not occur.
  - Remediation: Either remove the controls for this release or add validated configuration mutations and persistence keys, with explicit “preferred/requested” wording for sample rate. Read actual route sample rate after activation and surface mismatch. Adapters must apply supported buffer settings or report them unavailable.
- UIUX-008 [High; UI and UX] Settings exposes inert controls/actions that do not change the claimed feature
  - Source: 04_UI_UX.md lines 384-439
  - Locations: Fonic HiFi/Presentation/Views/Settings/SettingsView.swift:13-19,53-128,168-232; Fonic HiFi/ContentView.swift:55-57,70-79; Fonic HiFi/Presentation/Views/Settings/AudioSettingsView.swift:12-18,37-85,127-160; Fonic HiFi/Core/Audio/Interfaces/AudioEngineConfiguration.swift:10-25,48-67; Fonic HiFi/Presentation/Views/Settings/FileRowView.swift:23-27,50-64
  - Domain impact: whole-repository symbol tracing found no runtime consumer for `darkModeEnabled`, `showNowPlayingAnimation`, `enableHapticFeedback`, or `showFileExtensions`; the app forces dark mode, always runs the player transition/haptics, and always renders `item.name` with its extension. `enableBitPerfectPlayback`, `audioBufferSize`, and `sampleRate` are written only to defaults and never applied to `AudioEngineConfiguration` (whose default `enableBitPerfect` is `true` even while the settings toggle defaults to `false`). “Export Settings,” “Import Settings,” and “Test Audio Configuration” only log. In total, ten visible choices/actions provide false feedback, including audiophile signal-path claims.
  - Remediation: for each row, either wire it to the existing owning subsystem and reflect the effective value, or remove it from production until implementation exists. Do not add substitute branding or settings. Prioritize bit-perfect/buffer/sample rate because the current UI can misrepresent the audio path.

### CAN-025: Now Playing lacks an adaptive scroll/layout contract for short heights and Dynamic Type

- Highest source severity: Medium
- Members: UIUX-006, A11Y-006
- Domains: UI and UX, Accessibility and Localization
- Rationale: Both records cite the same non-scrollable NowPlayingContent stack, unused size category, fixed artwork/spacers, and lower-control reachability under landscape or accessibility sizes.
- Evidence to preserve: Keep Home-card fixed-height clipping, line wrapping, compact accessibility layouts, actual scroll content, safe-area behavior, long strings, pseudolanguage, and AX5 device matrix.

Member records:

- Shared path anchors: Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift
- UIUX-006 [Medium; UI and UX] Now Playing has no height-adaptive scrolling contract for landscape or large text
  - Source: 04_UI_UX.md lines 286-334
  - Locations: Fonic HiFi.xcodeproj/project.pbxproj:389-391,437-439; Fonic HiFi/ContentView.swift:70-82; Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:17,59-101,320-371,373-540
  - Domain impact: landscape is explicitly supported, but the full-screen wrapper uses an empty `ScrollView` and inserts the entire player as a top safe-area inset. Safe-area inset content is not the scroll content that provides reachability. The player sizes artwork from width (up to 400 points) and then vertically stacks metadata, progress, five controls, volume, and fixed minimum spacers. The declared `sizeCategory` is unused. On short landscape heights or accessibility sizes, lower controls can be off-screen without a valid scroll path.
  - Remediation: make Now Playing the actual scroll content with at least the viewport's height. Preserve the same vertical composition and zoom transition; only add reachability.
- A11Y-006 [Medium; Accessibility and Localization] Fixed frames and line limits can clip Dynamic Type, including on the non-scrollable Now Playing surface
  - Source: 05_Accessibility_Localization.md lines 378-438
  - Locations: Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:17,59-102,335-371; Fonic HiFi/Presentation/Views/Home/Sections/ExpandableAlbumCard.swift:15-40; Fonic HiFi/Presentation/Views/Home/Sections/AlbumsSection.swift:22-32
  - Domain impact: Dynamic Type fonts expand, but the Home album-card text is constrained to a fixed 34-point height and one line per field. On Now Playing, the declared `sizeCategory` environment value is unused; a tall stack of artwork, controls, and fixed spacer ranges has no vertical scrolling or accessibility-size alternative. Track title and artist remain one line. Long metadata, accessibility sizes, or landscape height can therefore truncate text or push controls out of reach. Static code proves the constraints; the exact devices/sizes that fail require rendering.
  - Remediation: Remove fixed text heights, allow important metadata to wrap, use `dynamicTypeSize.isAccessibilitySize` to reduce decorative artwork/spacers and switch compact horizontal groupings to vertical layouts, and make the Now Playing content vertically scrollable when it cannot fit. Keep the current visual arrangement at standard sizes.

### CAN-026: Missing prerequisites and behavior are converted into passing test skips

- Highest source severity: Medium
- Members: TRV-004, TRV-015
- Domains: Testing and Release Verification
- Rationale: TRV-004 is the UI-test subset of TRV-015's repository-wide skip problem. Both allow core missing behavior to pass and require deterministic prerequisites plus failure on unexpected skips.
- Evidence to preserve: Keep UI postconditions and identifiers, AudioKit/App Group/widget prerequisites, 26-site inventory, silent early returns, xcresult skip gate, lane-specific allowlist, and owner/expiry governance.

Member records:

- Shared path anchors: Fonic HiFiUITests/LibraryNowPlayingSmokeTests.swift
- TRV-004 [Medium; Testing and Release Verification] UI smoke tests skip or ignore missing core behavior
  - Source: 09_Testing_Release_Verification.md lines 232-283
  - Locations: Fonic HiFiUITests/LibraryNowPlayingSmokeTests.swift:28-45,64-84,87-117
  - Domain impact: Missing Mini Player/Now Playing UI—the principal playback surface—becomes a passing skip. The Settings row and every Now Playing control may be absent without failure. Search typing has no result/empty/error assertion. Tapping controls has no state postcondition. Two of three UI methods can skip their playback portion, and the third can finish after typing text. These tests prove little beyond basic navigation.
  - Remediation: Seed a deterministic current track in the UI-test launch mode, add stable accessibility identifiers, require core elements, and assert observable state transitions after every action.
- TRV-015 [Medium; Testing and Release Verification] Conditional skips are not a failing release signal
  - Source: 09_Testing_Release_Verification.md lines 815-857
  - Locations: Fonic HiFiTests/AudioKitEngineAdapterTests.swift:6-10,21-25,38-42,69-89,105-140; Fonic HiFiTests/AppGroupManagerTests.swift:32-35,62-65,94-97,111-114,127-130; Fonic HiFiTests/WidgetArtworkCacheTests.swift:12-20; Fonic HiFiUITests/LibraryNowPlayingSmokeTests.swift:38-41,102-105; .github/workflows/ci.yml:28-39
  - Domain impact: A runner can lose AudioKit initialization, App Group entitlements, widget storage, or seeded Mini Player behavior and still report a successful suite. Static inventory found 26 skip call sites across 9 files. The silent `guard ... else { return }` is even less visible. The most environment-sensitive production behavior is therefore easiest to omit from a release run.
  - Remediation: Classify skips: unit tests should inject capabilities and never skip; device-only tests may skip outside their designated lane, but the designated lane must fail if prerequisites are missing. Parse `.xcresult` and reject unexpected skips.

## Near-duplicate groups retained separately

### DLP-003, TRV-010

DLP-003 is a production migration-plan defect; TRV-010 is the independent absence of a real migration test. One can be fixed while the other remains.

### UIUX-011, FMA-003, FMA-005, DCA-PART-004

These share Smart Search files but are four different defects: mode reachability, stale cancellation writes, fallback handoff, and playback action integration.

### CAN-003, CAN-005

Toolchain incompatibility prevents CI execution; missing Release/archive gates remain a separate contract even after the toolchain is corrected.

### CP-012, CAN-016

CP-012 includes unbounded sample/error retention and a separate no-op poller lifecycle. CAN-016 covers false synthetic metrics; merging would hide the independent memory-growth issue.

### DLP-005, CAN-013

DLP-005 is compensating cleanup after a copied-file failure. CAN-013 is missing task cancellation propagation; either can occur without the other.

### CAN-009, CAN-012, DLP-020

Unwired tracking, replacement teardown races, and incorrect listened-duration measurement are separate lifecycle layers with distinct fixes.

### AUD-BIT-002, CAN-016

Bit-perfect path verification and synthetic diagnostic metrics are related trust problems but have different owners, evidence, and acceptance tests.

### DLP-002, DLP-003

Missing ListeningSession schema registration and the migration-plan-open sequence are separate persistence defects.

### TRV-002, TRV-003

A missing committed test action and aliases that fail to select unit/UI targets require separate changes even though both affect test selection.

### TRV-013, TRV-014

Coverage evidence quality and Release/archive gating are independent release controls.

### A11Y-001, A11YTEST-001

The semantic-control defect and the missing accessibility verification lane are implementation versus test-coverage findings.

### UIUX-005, UIUX-006

A missing visible dismissal action and missing scroll/reachability contract affect the same screen but have independent controls and fixes.

### FMA-003, FMA-005

Stale cancellation writes and failure-to-handoff fallback are separate Smart Search state-machine defects.

### CAN-001, CAN-006

Credential rotation/history purge must remain separate from general artifact cleanup; untracking files alone does not revoke secrets.

### AUD-TRANSITION-001, TRV-007

The production gapless/crossfade implementation defect and absence of output verification are code behavior versus evidence-lane findings.

### AUD-FORMAT-001, AUD-FORMAT-002

M4A misclassification and mismatch between advertised/imported formats and detector representation have different affected inputs and remediations.
