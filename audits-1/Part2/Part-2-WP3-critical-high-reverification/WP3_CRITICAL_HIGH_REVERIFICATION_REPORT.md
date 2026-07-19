# Work Package 3 - Independent Critical and High re-verification

## Outcome

Every one of the 27 prior report-level Critical and High records was rechecked against the pinned repository commit. None was accepted solely because a previous report named it. The 27 records represent 23 canonical root causes after duplicate mapping. Final canonical severity is 0 Critical, 13 High, and 10 Medium.

Primary report-record dispositions: 11 retained, 9 downgraded, 7 merged, 0 rejected, and 0 newly identified. Three merged records map into existing Medium findings from other completed domain reports: DLP-004 into DCA-PART-001, CP-002 into DLP-021, and CP-004 into DLP-006.

## Baseline and method

- Repository: https://github.com/keiranhaax/fonic-hifi
- Branch baseline: main
- Commit: 459db9bfd18d17960e8fd2ff8defc4701085532e
- Repository state: detached at the audited commit; index and worktree clean before and after review
- Method: read-only source tracing, deterministic assertions, prior-report cross-checking, current official Apple documentation where behavior controlled a verdict, and exact-SHA public CI evidence
- Build boundary: no Xcode, Apple SDK, simulator, signing identity, TestFlight, App Store Connect, or physical iOS/audio device in the Linux environment
- Source changes: none

## Disposition summary

| Canonical | Source report IDs | Final severity | Report-record disposition | Confidence | Verification status |
|---|---|---|---|---|---|
| WP3-001 | PCFG-001, PSR-001 | High | PCFG-001 downgraded; PSR-001 merged | High | CONFIRMED STATIC EXPOSURE; credential validity and scope UNVERIFIED |
| WP3-002 | PCFG-002, PSR-002 | High | PCFG-002 downgraded; PSR-002 merged | High | CONFIRMED STATIC RELEASE BLOCKER; archive upload UNVERIFIED |
| WP3-003 | PCFG-003, PSR-003, TRV-001 | High | PCFG-003 retained; PSR-003 merged; TRV-001 merged | Very high | CONFIRMED STATICALLY AND CORROBORATED BY EXACT-SHA PUBLIC CI |
| WP3-004 | AUD-ENG-002 | High | AUD-ENG-002 retained | High | CONFIRMED RACE WINDOW; runtime interleaving UNVERIFIED |
| WP3-005 | AUD-SESSION-001 | High | AUD-SESSION-001 retained | High | CONFIRMED LIFECYCLE CONFLICT; audible impact UNVERIFIED |
| WP3-006 | AUD-SESSION-002 | High | AUD-SESSION-002 retained | Very high | CONFIRMED STATICALLY; device route behavior UNVERIFIED |
| WP3-007 | DLP-001 | High | DLP-001 retained | High | CONFIRMED STATIC RECOVERY MISCLASSIFICATION; SwiftData failure mode UNVERIFIED |
| WP3-008 | DLP-002 | Medium | DLP-002 downgraded | High | CONFIRMED STATIC SCHEMA MISMATCH; runtime exception UNVERIFIED |
| WP3-009 | DLP-003 | Medium | DLP-003 downgraded | High | CONFIRMED STATIC ORDERING; actual store migration UNVERIFIED |
| WP3-010 | DLP-004 | Medium | DLP-004 merged | Very high | CONFIRMED STATICALLY |
| WP3-011 | DLP-005 | High | DLP-005 retained | Very high | CONFIRMED STATIC FAILURE PATH; filesystem result UNVERIFIED |
| WP3-012 | DLP-007 | Medium | DLP-007 downgraded | Medium-high | CONFIRMED DESTRUCTIVE POLICY; temporary-unavailability trigger UNVERIFIED |
| WP3-013 | CP-002 | Medium | CP-002 merged | Very high | CONFIRMED STATIC CANCELLATION GAP; post-cancel work extent UNVERIFIED |
| WP3-014 | CP-003 | Medium | CP-003 downgraded | High | CONFIRMED STATIC COST; user-visible latency UNMEASURED |
| WP3-015 | CP-004 | Medium | CP-004 merged | High | CONFIRMED RACE WINDOW; duplicate reproduction UNVERIFIED |
| WP3-016 | UIUX-001 | High | UIUX-001 retained | High | CONFIRMED OBSERVATION MISMATCH; stale rendering UNVERIFIED |
| WP3-017 | UIUX-002 | Medium | UIUX-002 downgraded | High | CONFIRMED STATIC STATE DUPLICATION |
| WP3-018 | UIUX-008 | Medium | UIUX-008 downgraded | High | CONFIRMED STATICALLY |
| WP3-019 | UIUX-009 | High | UIUX-009 retained | High | CONFIRMED STATICALLY |
| WP3-020 | UIUX-010 | High | UIUX-010 retained | High | CONFIRMED OBSERVATION AND OWNERSHIP DEFECT; presentation failure UNVERIFIED |
| WP3-021 | A11Y-001 | High | A11Y-001 retained | High | PROBABLE ACCESSIBILITY BLOCKER; runtime accessibility tree UNVERIFIED |
| WP3-022 | A11Y-002 | High | A11Y-002 retained | High | PROBABLE FEATURE BLOCKER; runtime accessibility tree UNVERIFIED |
| WP3-023 | PSR-004 | Medium | PSR-004 downgraded | High | CONFIRMED STATIC PUBLIC INTERPOLATION; actual log retention and sharing UNVERIFIED |

## Lead corrections to prior reports

1. Public credentials remain a High exposure, not a Critical finding, because current validity, scope, and provider impact were not tested.
2. Missing Required Reason API manifests remain a High App Store blocker, not a Critical user-harm finding.
3. The exact-SHA CI run confirms build failure and skipped tests, but its terminal failure also cites a missing app icon. The toolchain defect is independently proven and is not claimed as the sole cause of that run's failure.
4. Privacy-manifest reason 3B52.1 is not established by the active import path because metadata extraction occurs after the file is copied into the app container.
5. DLP-004, CP-002, and CP-004 duplicate existing Medium findings in other reports and inherit the evidence-supported Medium classification.
6. Performance-only CP-003 was reduced to Medium because no device profiling establishes a High-severity stall.
7. DLP-007 was reduced to Medium because the destructive policy is real but temporary unavailability of the managed local file path was not reproduced.
8. PSR-004 was reduced to Medium because public content-bearing logs are confirmed, but no remote collection or exported Release log was demonstrated.

## Detailed verification

### WP3-001 - Publicly committed developer-tool credentials

- Final severity: High
- Confidence: High
- Verification status: CONFIRMED STATIC EXPOSURE; credential validity and scope UNVERIFIED
- Source report records:
  - PCFG-001: Critical -> High; downgraded
  - PSR-001: Critical -> High; merged; merged into PCFG-001
- Reachability and impact: The audited public commit tracks two machine-local configuration files containing four non-placeholder credential-shaped values. Three values are supplied to configured MCP processes and one is embedded in a permitted setup command. Any reader of the public commit or retained history can obtain the values and attempt quota, billing, or protected-service access.
- Guards and mitigating controls: One value is embedded in a permission command rather than automatically executed, and current validity, privileges, revocation, audit logs, and billing exposure were deliberately not tested. Those limits prevent a Critical rating. Local file permissions and deleting a future revision do not remove public Git history exposure.
- Severity rationale: High is supported for confirmed public secret exposure. Critical requires provider-side evidence that a still-valid value grants material write, administrative, sensitive-data, or significant financial capability.
- Evidence:
  - .kilocode/mcp.json:45 (sensitive scalar redacted)
    > "BRAVE_API_KEY": "[REDACTED]"
  - .kilocode/mcp.json:77 (sensitive scalar redacted)
    > "EXA_API_KEY": "[REDACTED]"
  - .kilocode/mcp.json:92 (sensitive scalar redacted)
    > "Authorization: Bearer [REDACTED]"
  - .claude/settings.local.json:83 (sensitive scalar redacted)
    > "X-API-Key":"[REDACTED]"
- External sources:
  - https://api.github.com/repos/keiranhaax/fonic-hifi
- Limitations:
  - No credential was authenticated, probed, logged, or reproduced in a deliverable.

### WP3-002 - App and widget omit first-party Required Reason API manifests

- Final severity: High
- Confidence: High
- Verification status: CONFIRMED STATIC RELEASE BLOCKER; archive upload UNVERIFIED
- Source report records:
  - PCFG-002: Critical -> High; downgraded
  - PSR-002: Critical -> High; merged; merged into PCFG-002
- Reachability and impact: The app directly uses standard and App Group UserDefaults, file-timestamp APIs, and system uptime. The widget independently reads App Group UserDefaults. The project defines separate app and extension executables, but the repository contains no PrivacyInfo.xcprivacy source file. Apple states undeclared covered API use is not accepted by App Store Connect.
- Guards and mitigating controls: A dependency manifest cannot declare first-party use in the app or widget. The active import path copies selected files into the app container before metadata extraction, so the earlier suggested 3B52.1 reason is not established by that path and must not be carried forward automatically. No upload or generated privacy report was run.
- Severity rationale: This is a confirmed distribution blocker, but no code execution, data disclosure, or irreversible user harm was demonstrated. High is proportionate; Critical is not.
- Evidence:
  - Fonic HiFi/Core/Audio/Engine/AudioPlaybackSettingsStore.swift:19-20,45-54
    > 19:     public init(defaults: UserDefaults = .standard) {
    > 20:         self.defaults = DefaultsBox(value: defaults)
    > 45:     public func setCrossfadeDuration(_ duration: TimeInterval) {
    > 46:         defaults.value.set(duration, forKey: Keys.crossfadeDuration)
    > 47:     }
    > 48:
    > 49:     public func setReplayGainMode(_ mode: ReplayGainMode) {
    > 50:         defaults.value.set(mode.rawValue, forKey: Keys.replayGainMode)
    > 51:     }
    > 52:
    > 53:     public func setPlaybackRate(_ rate: Double) {
    > 54:         defaults.value.set(rate, forKey: Keys.playbackRate)
  - Fonic HiFi/Shared/WidgetPlaybackState.swift:115-129
    > 115:     func save() {
    > 116:         guard let defaults = UserDefaults.appGroup else { return }
    > 117:         let encoder = JSONEncoder()
    > 118:         encoder.dateEncodingStrategy = .iso8601
    > 119:
    > 120:         if let data = try? encoder.encode(self) {
    > 121:             defaults.set(data, forKey: WidgetConstants.Keys.playbackState)
    > 122:             defaults.set(Date(), forKey: WidgetConstants.Keys.lastUpdated)
    > 123:         }
    > 124:     }
    > 125:
    > 126:     /// Load from App Group UserDefaults
    > 127:     static func load() -> WidgetPlaybackState? {
    > 128:         guard let defaults = UserDefaults.appGroup,
    > 129:               let data = defaults.data(forKey: WidgetConstants.Keys.playbackState)
  - Fonic HiFi Widget/Shared/WidgetPlaybackState.swift:115-129
    > 115:     func save() {
    > 116:         guard let defaults = UserDefaults.appGroup else { return }
    > 117:         let encoder = JSONEncoder()
    > 118:         encoder.dateEncodingStrategy = .iso8601
    > 119:
    > 120:         if let data = try? encoder.encode(self) {
    > 121:             defaults.set(data, forKey: WidgetConstants.Keys.playbackState)
    > 122:             defaults.set(Date(), forKey: WidgetConstants.Keys.lastUpdated)
    > 123:         }
    > 124:     }
    > 125:
    > 126:     /// Load from App Group UserDefaults
    > 127:     static func load() -> WidgetPlaybackState? {
    > 128:         guard let defaults = UserDefaults.appGroup,
    > 129:               let data = defaults.data(forKey: WidgetConstants.Keys.playbackState)
  - Fonic HiFi/Data/Services/MetadataExtractionService.swift:59-63
    > 59:         // Extract basic file information
    > 60:         let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
    > 61:         let fileSize = fileAttributes[.size] as? Int64 ?? 0
    > 62:         let dateAdded = fileAttributes[.creationDate] as? Date ?? Date()
    > 63:         let dateModified = fileAttributes[.modificationDate] as? Date ?? Date()
  - Fonic HiFi/Core/Audio/Diagnostics/SystemMetricsCollector.swift:300-304
    > 300: private extension SystemMetricsCollector {
    > 301:     func computeCPUUsage() -> Float {
    > 302:         let now = ProcessInfo.processInfo.systemUptime
    > 303:         if let cached = cachedCPUUsage, now - cached.timestamp < 0.25 {
    > 304:             return cached.value
  - Fonic HiFi.xcodeproj/project.pbxproj:169-192,236-252
    > 169: 		38D04CDC2DE570D80047CB93 /* Fonic HiFi */ = {
    > 170: 			isa = PBXNativeTarget;
    > 171: 			buildConfigurationList = 38D04D042DE570DA0047CB93 /* Build configuration list for PBXNativeTarget "Fonic HiFi" */;
    > 172: 			buildPhases = (
    > 173: 				38D04CD92DE570D80047CB93 /* Sources */,
    > 174: 				38D04CDA2DE570D80047CB93 /* Frameworks */,
    > 175: 				38D04CDB2DE570D80047CB93 /* Resources */,
    > 176: 				C1W1D6E92DF60001000A0001 /* Embed Foundation Extensions */,
    > 177: 			);
    > 178: 			buildRules = (
    > 179: 			);
    > 180: 			dependencies = (
    > 181: 				C1W1D6E42DF60001000A0001 /* PBXTargetDependency */,
    > 182: 			);
    > 183: 			fileSystemSynchronizedGroups = (
    > 184: 				38D04CDF2DE570D80047CB93 /* Fonic HiFi */,
    > 185: 			);
    > 186: 			name = "Fonic HiFi";
    > 187: 			packageProductDependencies = (
    > 188: 				386B1C062DE975FD009FBF25 /* AudioKit */,
    > 189: 			);
    > 190: 			productName = "Fonic HiFi";
    > 191: 			productReference = 38D04CDD2DE570D80047CB93 /* Fonic HiFi.app */;
    > 192: 			productType = "com.apple.product-type.application";
    > 236: 		C1W1D6DD2DF60001000A0001 /* Fonic HiFi Widget */ = {
    > 237: 			isa = PBXNativeTarget;
    > 238: 			buildConfigurationList = C1W1D6E62DF60001000A0001 /* Build configuration list for PBXNativeTarget "Fonic HiFi Widget" */;
    > 239: 			buildPhases = (
    > 240: 				C1W1D6DA2DF60001000A0001 /* Sources */,
    > 241: 				C1W1D6DB2DF60001000A0001 /* Frameworks */,
    > 242: 				C1W1D6DC2DF60001000A0001 /* Resources */,
    > 243: 			);
    > 244: 			buildRules = (
    > 245: 			);
    > 246: 			fileSystemSynchronizedGroups = (
    > 247: 				C1W1D6EB2DF60001000A0001 /* Fonic HiFi Widget */,
    > 248: 			);
    > 249: 			name = "Fonic HiFi Widget";
    > 250: 			productName = "Fonic HiFi Widget";
    > 251: 			productReference = C1W1D6DE2DF60001000A0001 /* Fonic HiFi Widget.appex */;
    > 252: 			productType = "com.apple.product-type.app-extension";
  - Fonic HiFi/Data/Actors/FileImportProcessor.swift:622-628
    > 622:         let copiedFileURL = try copyFile(
    > 623:             from: resolvedURL,
    > 624:             to: baseDirectory,
    > 625:             logger: logger,
    > 626:         )
    > 627:
    > 628:         let trackMetadata = try await metadataExtractor.extractTrackMetadata(from: copiedFileURL)
- External sources:
  - https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- Limitations:
  - App Store Connect validation, final archive inspection, and Organizer privacy-report generation were unavailable.

### WP3-003 - CI selects an iOS 18-era Xcode for an iOS 26 project

- Final severity: High
- Confidence: Very high
- Verification status: CONFIRMED STATICALLY AND CORROBORATED BY EXACT-SHA PUBLIC CI
- Source report records:
  - PCFG-003: High -> High; retained
  - PSR-003: High -> High; merged; merged into PCFG-003
  - TRV-001: High -> High; merged; merged into PCFG-003
- Reachability and impact: The only workflow selects Xcode 16.1, then every make target exports /Applications/Xcode.app. The current macos-15 image maps that alias to default Xcode 16.4. Both are unable to supply the declared iOS 26 deployment target and 26.2 simulator contract. The public run for the audited SHA failed during Build project and skipped tests and coverage, so CI is not a trustworthy release gate.
- Guards and mitigating controls: Versioned Xcode 26 installations exist on the current runner image, but the workflow does not select one. The public build also failed on a missing app icon, so the total run failure is not attributed solely to the toolchain mismatch. The mismatch remains independently proven by configuration, runner inventory, and deployment-target annotations.
- Severity rationale: Retain High because every CI build and test command passes through the conflicting configuration, preventing meaningful validation of an iOS 26 product and current App Store submission toolchain.
- Evidence:
  - .github/workflows/ci.yml:9-17
    > 9:   build-and-test:
    > 10:     runs-on: macos-15
    > 11:
    > 12:     steps:
    > 13:       - name: Checkout repository
    > 14:         uses: actions/checkout@v4
    > 15:
    > 16:       - name: Select Xcode 16.1
    > 17:         run: sudo xcode-select -s /Applications/Xcode_16.1.app
  - Makefile:12-18,32-33
    > 12: SDK = iphonesimulator26.0
    > 13: DEPLOYMENT_TARGET = 26.0
    > 14:
    > 15: # Simulator Configuration
    > 16: SIMULATOR_NAME = iPhone 17 Pro
    > 17: SIMULATOR_OS = 26.2
    > 18: DESTINATION = platform=iOS Simulator,name=$(SIMULATOR_NAME),OS=$(SIMULATOR_OS)
    > 32: # Ensure Xcode.app is used instead of CommandLineTools (required for iOS SDK)
    > 33: export DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer
  - Fonic HiFi.xcodeproj/project.pbxproj:391,439,519,578
    > 391: 				IPHONEOS_DEPLOYMENT_TARGET = 26.0;
    > 439: 				IPHONEOS_DEPLOYMENT_TARGET = 26.0;
    > 519: 				IPHONEOS_DEPLOYMENT_TARGET = 26.0;
    > 578: 				IPHONEOS_DEPLOYMENT_TARGET = 26.0;
- External sources:
  - https://developer.apple.com/news/upcoming-requirements/?id=02032026a
  - https://developer.apple.com/xcode/system-requirements/
  - https://developer.apple.com/documentation/xcode/configuring-command-line-tools-settings
  - https://raw.githubusercontent.com/actions/runner-images/main/images/macos/macos-15-Readme.md
  - https://github.com/keiranhaax/fonic-hifi/actions/runs/28900146035
- Limitations:
  - No local Xcode build was possible. GitHub runner labels and image inventory remain mutable until the workflow pins and asserts one toolchain.

### WP3-004 - Concurrent play requests can commit stale engine and UI state

- Final severity: High
- Confidence: High
- Verification status: CONFIRMED RACE WINDOW; runtime interleaving UNVERIFIED
- Source report records:
  - AUD-ENG-002: High -> High; retained
- Reachability and impact: Every track tap starts an unowned Task. PlaybackController suspends during format detection, session activation, engine creation, load, and play. MainActor isolation serializes synchronous segments but is reentrant at each await. A slow request for track A can resume after track B and replace shared queue, engine, Now Playing, or mini-player state; A's late error handler can clear B.
- Guards and mitigating controls: The facade checks isReady and MainActor isolation prevents simultaneous synchronous mutation. There is no owned play task, cancellation, request generation, or track-identity check after suspension. No test controls the A/B completion order.
- Severity rationale: Retain High because the path is a common user action and can select the wrong audio or clear a valid current selection. Exact scheduling reproduction remains a device/test requirement.
- Evidence:
  - Fonic HiFi/Presentation/Views/Library/TrackRowView.swift:90-101
    > 90:         audioService.setCurrentTrack(track)
    > 91:         showingNowPlaying.wrappedValue = true
    > 92:
    > 93:         Task {
    > 94:             do {
    > 95:                 try await audioService.play(track: track)
    > 96:                 logger.info("play(track:) succeeded for \(track.title, privacy: .public)")
    > 97:             } catch {
    > 98:                 logger.error("play(track:) FAILED: \(error.localizedDescription, privacy: .public)")
    > 99:                 // Clear broken state so user isn't left in non-functional UI
    > 100:                 audioService.setCurrentTrack(nil)
    > 101:                 showingNowPlaying.wrappedValue = false
  - Fonic HiFi/Core/Audio/Engine/PlaybackController.swift:75-102
    > 75:     func play(track: Track, queueEntry: AudioTrack? = nil) async throws {
    > 76:         let info = try await formatDetectionManager.detectFormat(at: track.url)
    > 77:         await sessionManager.setPreferredSampleRate(info.sampleRate)
    > 78:         try await sessionManager.activateAudioSession()
    > 79:         logger.info("Detected format for playback: \(info.format.displayName)")
    > 80:
    > 81:         if engineManager.configuration.performanceMode == .quality {
    > 82:             let validation = await validator.validateBitPerfectPlayback(
    > 83:                 sourceFormat: info,
    > 84:                 outputDevice: nil,
    > 85:             )
    > 86:             if !validation.isValid {
    > 87:                 logger.warning("Bit-perfect validation failed: \(validation.mismatchReason?.userFriendlyDescription ?? "Unknown")")
    > 88:             }
    > 89:         }
    > 90:
    > 91:         let engine = try await engineManager.ensureEngine(for: info)
    > 92:
    > 93:         let audioTrack = queueEntry ?? track.toAudioTrack()
    > 94:         if queueManager.currentTrack?.id != audioTrack.id {
    > 95:             queueManager.setCurrentTrack(audioTrack)
    > 96:         }
    > 97:
    > 98:         uiState.currentTrack = track
    > 99:         uiState.showMiniPlayer = true
    > 100:         stateManager.updateState(.loading())
    > 101:
    > 102:         try await engine.load(url: audioTrack.url)
  - Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:22-23,331-335
    > 22: @MainActor
    > 23: public final class AudioEngineFacade: ObservableObject {
    > 331:     public func play(track: Track) async throws {
    > 332:         assertMainThread()
    > 333:         guard isReady else { throw AudioError.engineInitializationFailed(reason: "Engine not ready") }
    > 334:         logger.info("Playing track: \(track.title, privacy: .public)")
    > 335:         try await playbackController.play(track: track)
- Limitations:
  - No controllable detector/engine test or device rapid-tap run was available.

### WP3-005 - Native engine deactivates a different audio-session owner during load

- Final severity: High
- Confidence: High
- Verification status: CONFIRMED LIFECYCLE CONFLICT; audible impact UNVERIFIED
- Source report records:
  - AUD-SESSION-001: High -> High; retained
- Reachability and impact: The facade constructs one AudioSessionManager, while factory-created AVAudioEngineAdapter instances default to AudioSessionManager.shared. PlaybackController activates the facade manager before engine load. Native load immediately calls stop, whose adapter manager deactivates the process-wide AVAudioSession; play then assumes the session is already managed and does not reactivate it. The native path is reachable in efficiency mode and as an AudioKit fallback.
- Guards and mitigating controls: Balanced mode normally prefers AudioKit for supported formats, which lowers frequency but does not make the native/fallback path unreachable. Both managers wrap AVAudioSession.sharedInstance, so separate internal isSessionActive flags do not isolate the process-wide deactivation.
- Severity rationale: Retain High because the fallback/native engine can deactivate its session immediately before playback, producing silence, activation errors, or invalid recovery on a core path.
- Evidence:
  - Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:132-147
    > 132:     public init(
    > 133:         configuration: AudioEngineConfiguration = .default,
    > 134:         sessionManager: AudioSessionManager? = nil,
    > 135:         formatDetectionManager: AudioFormatDetectionManager? = nil,
    > 136:         engineFactory: AudioEngineFactory? = nil,
    > 137:         stateManager: PlaybackStateManager? = nil,
    > 138:         queueManager: AudioQueueManager? = nil,
    > 139:         validator: BitPerfectValidator? = nil,
    > 140:         monitor: (any AudioPerformanceMonitoring & AudioDiagnosticsReporting)? = nil,
    > 141:         playbackSettingsStore: AudioPlaybackSettingsStore? = nil,
    > 142:         uiStateStore: AudioUIState? = nil,
    > 143:     ) {
    > 144:         self.sessionManager = sessionManager ?? AudioSessionManager()
    > 145:         self.formatDetectionManager = formatDetectionManager ?? AudioFormatDetectionManager()
    > 146:         self.engineFactory = engineFactory ?? AudioEngineFactory()
    > 147:         self.stateManager = stateManager ?? PlaybackStateManager()
  - Fonic HiFi/Core/Audio/Factory/AudioEngineFactory.swift:154-179
    > 154:     private func createEngine(of type: AudioEngineType) async throws -> AudioEngineService {
    > 155:         guard let isAvailable = availableEngines[type], isAvailable else {
    > 156:             throw AudioError.engineInitializationFailed(
    > 157:                 reason: "\(type.displayName) is not available",
    > 158:             )
    > 159:         }
    > 160:
    > 161:         switch type {
    > 162:         case .avAudioEngine:
    > 163:             return AVAudioEngineAdapter()
    > 164:
    > 165:         case .audioKitEngine:
    > 166:             let adapter = AudioKitEngineAdapter()
    > 167:
    > 168:             // Check if AudioKit initialized successfully
    > 169:             do {
    > 170:                 try adapter.checkInitialization()
    > 171:                 return adapter
    > 172:             } catch {
    > 173:                 // AudioKit failed to initialize, mark as unavailable and fall back
    > 174:                 Self.logger.error("AudioKit initialization failed: \(error.localizedDescription)")
    > 175:                 registerEngine(.audioKitEngine, isAvailable: false)
    > 176:
    > 177:                 // Fall back to AVAudioEngine
    > 178:                 Self.logger.info("Falling back to AVAudioEngine due to AudioKit failure")
    > 179:                 return AVAudioEngineAdapter()
  - Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:110-111
    > 110:     public init(sessionManager: any AudioSessionManaging = AudioSessionManager.shared) {
    > 111:         self.sessionManager = sessionManager
  - Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:173-175,282-300
    > 173:     public func load(url: URL) async throws {
    > 174:         // Stop any current playback
    > 175:         await stop()
    > 282:     public func stop() async {
    > 283:         // Stop both players
    > 284:         primaryPlayerNode.stop()
    > 285:         secondaryPlayerNode.stop()
    > 286:         playbackState = .stopped
    > 287:         // Progress timer is managed by AudioEngineFacade
    > 288:
    > 289:         // Reset position and gapless state
    > 290:         audioFile = nil
    > 291:         totalFrames = 0
    > 292:         preparedFile = nil
    > 293:         hasNextPrepared = false
    > 294:         isPrimaryActive = true
    > 295:         await bufferUnderruns.reset()
    > 296:
    > 297:         do {
    > 298:             try await sessionManager.activateSession(false)
    > 299:         } catch {
    > 300:             logger.error("Failed to deactivate audio session: \(String(describing: error), privacy: .public)")
- External sources:
  - https://developer.apple.com/documentation/avfaudio/avaudiosession/setactive(_:options:)
- Limitations:
  - No physical route, interruption, or audible playback test was available.

### WP3-006 - Interruption intent and headphone-disconnect privacy are not preserved

- Final severity: High
- Confidence: Very high
- Verification status: CONFIRMED STATICALLY; device route behavior UNVERIFIED
- Source report records:
  - AUD-SESSION-002: High -> High; retained
- Reachability and impact: Interruption options are compared by integer equality rather than OptionSet containment. StateCoordinator pauses every interruption but does not remember whether playback was active before it, then resumes whenever shouldResume is true. oldDeviceUnavailable only logs, so removing wired, Bluetooth, or USB output does not explicitly pause before audio can reroute to the speaker.
- Guards and mitigating controls: There is a pause on interruption began and a conditional shouldResume branch. Those controls do not preserve prior paused intent, and the option parser can suppress combined flags. No route-loss pause or previous-route classification exists.
- Severity rationale: Retain High because Apple explicitly treats headphone disconnection as an implicit privacy request to pause, and current source can also auto-start a previously paused track after interruption.
- Evidence:
  - Fonic HiFi/Core/Audio/Services/AudioSessionManager.swift:381-385
    > 381:             case .ended:
    > 382:                 let interruptionOption = info[AVAudioSessionInterruptionOptionKey] as? UInt
    > 383:                 let resumeFlag = AVAudioSession.InterruptionOptions.shouldResume.rawValue
    > 384:                 let shouldResume = interruptionOption == resumeFlag
    > 385:                 await self?.handleInterruption(.ended(shouldResume: shouldResume))
  - Fonic HiFi/Core/Audio/Coordinators/StateCoordinator.swift:171-185
    > 171:     public func handleSessionInterruption(_ interruption: AudioInterruptionType) async {
    > 172:         switch interruption {
    > 173:         case .began:
    > 174:             logger.info("Audio session interrupted - pausing playback")
    > 175:             // Delegate to playback coordinator through facade
    > 176:             if let facade {
    > 177:                 await facade.pause()
    > 178:             }
    > 179:         case let .ended(shouldResume):
    > 180:             if shouldResume {
    > 181:                 logger.info("Audio session interruption ended - resuming playback")
    > 182:                 // Delegate to playback coordinator through facade
    > 183:                 if let facade {
    > 184:                     try? await facade.resume()
    > 185:                 }
  - Fonic HiFi/Core/Audio/Coordinators/StateCoordinator.swift:190-198
    > 190:     /// Handle audio route changes
    > 191:     public func handleRouteChange(_ change: AudioRouteChange) {
    > 192:         logger.info("Audio route changed: \(change.currentRoute) (reason: \(change.reason))")
    > 193:
    > 194:         // Handle specific route change scenarios
    > 195:         switch change.reason {
    > 196:         case .oldDeviceUnavailable:
    > 197:             // Headphones were unplugged, might want to pause
    > 198:             logger.info("Output device became unavailable")
- External sources:
  - https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes
  - https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions
- Limitations:
  - No wired, USB, AirPods, Bluetooth, phone-call, Siri, or lock-screen device matrix was run.

### WP3-007 - Read-only in-memory container can be mislabeled as the normal persistent store

- Final severity: High
- Confidence: High
- Verification status: CONFIRMED STATIC RECOVERY MISCLASSIFICATION; SwiftData failure mode UNVERIFIED
- Source report records:
  - DLP-001: High -> High; retained
- Reachability and impact: After persistent open and planned-migration open both fail, buildContainer can return an in-memory configuration with allowsSave false. The convenience initializer receives only a ModelContainer and unconditionally constructs DataManager with isFallback false. Recovery UI is therefore bypassed while normal mutating controls remain visible.
- Guards and mitigating controls: An outer catch creates an explicitly marked fallback only when buildContainer throws. It does not run when the fourth attempt succeeds. The hidden path is rare because two opens must fail first, but it can convert a storage incident into save failures or apparently successful ephemeral use.
- Severity rationale: Retain High because the app can present normal writable operation while persistence is unavailable, risking lost imports and orphan copies during recovery.
- Evidence:
  - Fonic HiFi/Data/DataManager+Initialization.swift:51-61
    > 51:         do {
    > 52:             let containerStart = CFAbsoluteTimeGetCurrent()
    > 53:             let container = try Self.buildContainer(
    > 54:                 schema: schema,
    > 55:                 configuration: modelConfiguration,
    > 56:                 logger: Self.initLogger
    > 57:             )
    > 58:             let containerDuration = String(format: "%.3f", CFAbsoluteTimeGetCurrent() - containerStart)
    > 59:             Self.initLogger.info("Container creation: \(containerDuration)s")
    > 60:
    > 61:             self.init(container: container, isFallback: false)
  - Fonic HiFi/Data/DataManager+Initialization.swift:161-174
    > 161:                 // Fourth attempt: Try with minimal configuration
    > 162:                 do {
    > 163:                     logger.info("Attempting minimal container configuration")
    > 164:                     let minimalConfig = ModelConfiguration(
    > 165:                         isStoredInMemoryOnly: true,
    > 166:                         allowsSave: false,
    > 167:                         cloudKitDatabase: .none
    > 168:                     )
    > 169:                     let container = try ModelContainer(
    > 170:                         for: schema,
    > 171:                         configurations: [minimalConfig]
    > 172:                     )
    > 173:                     logger.info("Successfully created minimal ModelContainer")
    > 174:                     return container
  - Fonic HiFi/FonicHiFiApp.swift:59-82
    > 59:         let fallbackActive = usingFallback || (resolvedDataManager?.isFallback ?? false)
    > 60:
    > 61:         _launchError = State(initialValue: launchError)
    > 62:         _showInitializationError = State(initialValue: showInitializationError)
    > 63:         _isUsingFallbackServices = State(initialValue: fallbackActive)
    > 64:
    > 65:         if resolvedDataManager == nil {
    > 66:             if launchError == nil {
    > 67:                 let fallbackMessage = fallbackError?.localizedDescription
    > 68:                     ?? "Fonic HiFi could not initialize a recovery data store."
    > 69:                 let fallbackLaunchError = LaunchError(message: fallbackMessage)
    > 70:                 launchError = fallbackLaunchError
    > 71:                 _launchError = State(initialValue: fallbackLaunchError)
    > 72:             }
    > 73:             _isUsingFallbackServices = State(initialValue: true)
    > 74:             _showInitializationError = State(initialValue: true)
    > 75:         }
    > 76:
    > 77:         if launchError == nil, resolvedDataManager?.isFallback == true {
    > 78:             launchError = LaunchError(
    > 79:                 message: "Fonic HiFi is operating in recovery mode due to a storage issue.",
    > 80:             )
    > 81:             _launchError = State(initialValue: launchError)
    > 82:             _showInitializationError = State(initialValue: true)
- Limitations:
  - The exact SwiftData error and UI behavior need corrupt-store, low-disk, and protected-data device tests.

### WP3-008 - ListeningSession is missing from the active SwiftData schema

- Final severity: Medium
- Confidence: High
- Verification status: CONFIRMED STATIC SCHEMA MISMATCH; runtime exception UNVERIFIED
- Source report records:
  - DLP-002: High -> Medium; downgraded
- Reachability and impact: SchemaV2 and all fallback model lists omit ListeningSession, while TrackDataActor inserts and fetches that model. Home calls getContinueListeningTracks, which reaches the fetch and then swallows the resulting higher-level error as an empty state.
- Guards and mitigating controls: Production session writes are currently disabled by the separate missing configureSessionTracking call, reducing immediate write-path exposure. Home still reaches a fetch. The defect blocks history-dependent features but does not prevent basic playback or library persistence.
- Severity rationale: Downgrade to Medium. The inconsistency is real, but current mitigations and error swallowing limit demonstrated impact to broken history/recommendation surfaces rather than core library loss.
- Evidence:
  - Fonic HiFi/Data/Migration/RecentSearchMigrationPlan.swift:146-157
    > 146: /// Schema V2: Current schema with sourceURLHash/sourceBookmarkHash and RecentSearch
    > 147: enum SchemaV2: VersionedSchema {
    > 148:     static let versionIdentifier = Schema.Version(2, 0, 0)
    > 149:
    > 150:     static var models: [any PersistentModel.Type] {
    > 151:         [
    > 152:             Track.self,          // Live Track with hash fields
    > 153:             Artist.self,
    > 154:             Album.self,
    > 155:             Playlist.self,
    > 156:             RecentSearch.self   // Added in V2
    > 157:         ]
  - Fonic HiFi/Data/Actors/TrackDataActor.swift:787-819
    > 787:         let session = ListeningSession(
    > 788:             trackId: trackId,
    > 789:             startedAt: startedAt,
    > 790:             durationListened: durationListened,
    > 791:             trackDuration: trackDuration,
    > 792:             completionPercentage: completionPercentage,
    > 793:             wasSkipped: wasSkipped,
    > 794:             wasCompleted: wasCompleted
    > 795:         )
    > 796:         session.endedAt = Date()
    > 797:
    > 798:         modelContext.insert(session)
    > 799:
    > 800:         do {
    > 801:             try modelContext.save()
    > 802:             logger.debug("Recorded listening session for track: \(trackId)")
    > 803:         } catch {
    > 804:             logger.error("Failed to record listening session: \(error.localizedDescription)")
    > 805:             throw TrackDataError.insertFailed(error)
    > 806:         }
    > 807:     }
    > 808:
    > 809:     /// Get recent listening sessions
    > 810:     /// - Parameter limit: Maximum number of sessions to return
    > 811:     /// - Returns: Array of session data sorted by startedAt descending
    > 812:     public func getListeningSessions(limit: Int) throws -> [ListeningSessionData] {
    > 813:         var descriptor = FetchDescriptor<ListeningSession>(
    > 814:             sortBy: [SortDescriptor(\ListeningSession.startedAt, order: .reverse)]
    > 815:         )
    > 816:         descriptor.fetchLimit = limit
    > 817:
    > 818:         let sessions = try modelContext.fetch(descriptor)
    > 819:         return sessions.map { ListeningSessionData(from: $0) }
  - Fonic HiFi/Data/DataManager+Recent.swift:140-151
    > 140:     func getContinueListeningTracks(limit: Int = 3) async throws -> [Track] {
    > 141:         // Get recent sessions that weren't completed
    > 142:         let sessions = try await trackDataActor.getListeningSessions(limit: 50)
    > 143:
    > 144:         // Filter to sessions that weren't completed and have >10% but <90% progress
    > 145:         let incompleteSessionTrackIds = Array(sessions
    > 146:             .filter { !$0.wasCompleted && $0.completionPercentage > 0.1 && $0.completionPercentage < 0.9 }
    > 147:             .prefix(limit)
    > 148:             .map { $0.trackId })
    > 149:
    > 150:         // Fetch the actual tracks using mainContext (already on MainActor)
    > 151:         return try fetchTracks(by: incompleteSessionTrackIds)
  - Fonic HiFi/Presentation/Views/Home/HomeView.swift:214-235
    > 214:             // History-based sections
    > 215:             continueListening = try await dataManager.getContinueListeningTracks(limit: 3)
    > 216:             rediscoverTracks = try await dataManager.getRediscoverTracks(limit: 10)
    > 217:
    > 218:             // Generate AI greeting if we have history
    > 219:             if !recentlyPlayed.isEmpty {
    > 220:                 let sessions = try await dataManager.trackDataActor.getListeningSessions(limit: 50)
    > 221:                 let trackIDs = try await dataManager.trackDataActor.getAllTrackIDs(limit: 200)
    > 222:
    > 223:                 let greeting = await recommendationService.generateTimeBasedGreeting(
    > 224:                     sessions: sessions,
    > 225:                     availableTrackIDs: trackIDs,
    > 226:                     genres: genres
    > 227:                 )
    > 228:                 timeBasedGreeting = greeting
    > 229:
    > 230:                 // Load the actual tracks for the greeting using mainContext
    > 231:                 greetingTracks = try dataManager.fetchTracks(by: greeting.trackIDs)
    > 232:             }
    > 233:         } catch {
    > 234:             // Silently handle errors - home screen shows empty state gracefully
    > 235:         }
- Limitations:
  - No on-disk SwiftData container was opened with Xcode to capture the concrete diagnostic.

### WP3-009 - The migration plan is attempted only after an unplanned store open

- Final severity: Medium
- Confidence: High
- Verification status: CONFIRMED STATIC ORDERING; actual store migration UNVERIFIED
- Source report records:
  - DLP-003: High -> Medium; downgraded
- Reachability and impact: Production first opens SchemaV2 without RecentSearchMigrationPlan. The declared custom V1-to-V2 stage is tried only if that open throws, so an inferred lightweight open can bypass the hash backfill. The test invokes the helper directly against a current schema rather than migrating a V1 fixture.
- Guards and mitigating controls: The added hash fields are optional, and duplicate lookup also compares sourceURLString and track.url, reducing the immediate effect of a missed backfill. A planned fallback exists if the first open fails. No actual V1 store result was available.
- Severity rationale: Downgrade to Medium because the ordering defect and test gap are confirmed, but material data loss or failed migration was not demonstrated and fallback duplicate keys remain.
- Evidence:
  - Fonic HiFi/Data/DataManager+Initialization.swift:128-150
    > 128:         // First attempt: Try creating container normally
    > 129:         do {
    > 130:             logger.info("Creating container without migration plan")
    > 131:             let container = try ModelContainer(
    > 132:                 for: schema,
    > 133:                 configurations: [configuration]
    > 134:             )
    > 135:             logger.info("Successfully created ModelContainer")
    > 136:             return container
    > 137:         } catch {
    > 138:             logger.error("Failed to create ModelContainer without migration plan: \(error)")
    > 139:             logger.error("Error details: \(String(reflecting: error))")
    > 140:
    > 141:             // Second attempt: Try with migration plan (for legacy SchemaV1 → V2 upgrades)
    > 142:             do {
    > 143:                 logger.info("Attempting fallback container with migration plan")
    > 144:                 let container = try ModelContainer(
    > 145:                     for: schema,
    > 146:                     migrationPlan: RecentSearchMigrationPlan.self,
    > 147:                     configurations: [configuration]
    > 148:                 )
    > 149:                 logger.info("Successfully created ModelContainer with migration plan")
    > 150:                 return container
  - Fonic HiFi/Data/Migration/RecentSearchMigrationPlan.swift:167-200
    > 167:     static var stages: [MigrationStage] {
    > 168:         [
    > 169:             .custom(
    > 170:                 fromVersion: SchemaV1.self,
    > 171:                 toVersion: SchemaV2.self,
    > 172:                 willMigrate: { context in
    > 173:                     try migrateTrackBookmarkHashes(in: context)
    > 174:                 },
    > 175:                 didMigrate: { _ in }
    > 176:             )
    > 177:         ]
    > 178:     }
    > 179:
    > 180:     static func migrateTrackBookmarkHashes(in context: ModelContext) throws {
    > 181:         let fetchDescriptor = FetchDescriptor<Track>()
    > 182:         let tracks = try context.fetch(fetchDescriptor)
    > 183:
    > 184:         guard !tracks.isEmpty else { return }
    > 185:
    > 186:         for track in tracks {
    > 187:             if track.sourceURLHash == nil,
    > 188:                let source = track.sourceURLString,
    > 189:                let url = URL(string: source) {
    > 190:                 track.sourceURLHash = url.librarySourceHash()
    > 191:             }
    > 192:
    > 193:             if track.sourceBookmarkHash == nil,
    > 194:                let bookmark = track.sourceURLBookmark {
    > 195:                 track.sourceBookmarkHash = bookmark.sha256Hex()
    > 196:             }
    > 197:         }
    > 198:
    > 199:         if context.hasChanges {
    > 200:             try context.save()
  - Fonic HiFi/Data/Actors/TrackDataActor.swift:485-498
    > 485:         let predicate: Predicate<Track>
    > 486:         if let bookmarkHash {
    > 487:             predicate = #Predicate<Track> { track in
    > 488:                 track.sourceBookmarkHash == bookmarkHash ||
    > 489:                     track.sourceURLHash == normalizedHash ||
    > 490:                     track.sourceURLString == absoluteSource ||
    > 491:                     track.url == url
    > 492:             }
    > 493:         } else {
    > 494:             predicate = #Predicate<Track> { track in
    > 495:                 track.sourceURLHash == normalizedHash ||
    > 496:                     track.sourceURLString == absoluteSource ||
    > 497:                     track.url == url
    > 498:             }
- Limitations:
  - No real V1 store fixture or Xcode migration run was available.

### WP3-010 - Listening-session tracking is implemented but never configured

- Final severity: Medium
- Confidence: Very high
- Verification status: CONFIRMED STATICALLY
- Source report records:
  - DLP-004: High -> Medium; merged; merged into DCA-PART-001
- Reachability and impact: AudioEngineFacade exposes configureSessionTracking and optional-chains every session start/end. Primary, preview, and fallback service factories construct both the data actor and audio facade but never call that method. Playback succeeds while play counts and listening sessions remain empty.
- Guards and mitigating controls: Optional chaining prevents a crash and preserves playback. The missing schema registration in WP3-008 means blindly wiring the service would create a new failure. The defect affects history, recommendations, and statistics rather than core playback.
- Severity rationale: Merge DLP-004 into the already existing DCA-PART-001 record and correct the canonical severity to Medium. Another completed report independently classified the identical root cause as Medium.
- Evidence:
  - Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:202-208,331-341
    > 202:     // MARK: - Session Tracking Configuration
    > 203:
    > 204:     /// Configure listening session tracking with the data actor
    > 205:     /// - Parameter dataActor: The TrackDataActor for persisting listening sessions
    > 206:     public func configureSessionTracking(dataActor: TrackDataActor) {
    > 207:         self.sessionService = ListeningSessionService(dataActor: dataActor)
    > 208:         logger.info("Session tracking configured")
    > 331:     public func play(track: Track) async throws {
    > 332:         assertMainThread()
    > 333:         guard isReady else { throw AudioError.engineInitializationFailed(reason: "Engine not ready") }
    > 334:         logger.info("Playing track: \(track.title, privacy: .public)")
    > 335:         try await playbackController.play(track: track)
    > 336:
    > 337:         // Start listening session after successful play
    > 338:         if let engine = engineManager.currentEngine {
    > 339:             let duration = await engine.duration
    > 340:             sessionService?.startSession(trackId: track.id, duration: duration)
    > 341:         }
  - Fonic HiFi/FonicHiFiApp.swift:318-347
    > 318:     static func makePrimaryServices(
    > 319:         performanceMonitor: PerformanceMonitor,
    > 320:     ) throws -> AppServices {
    > 321:         let dataManager = try DataManager()
    > 322:         let playbackStateManager = PlaybackStateManager()
    > 323:         let audioMonitor = AudioMonitor(performanceMonitor: performanceMonitor)
    > 324:         let queueManager = AudioQueueManager()
    > 325:         let audioService = AudioEngineFacade(
    > 326:             stateManager: playbackStateManager,
    > 327:             queueManager: queueManager,
    > 328:             monitor: audioMonitor,
    > 329:         )
    > 330:         let importService = LibraryImportService(
    > 331:             trackDataActor: dataManager.trackDataActor,
    > 332:             metadataExtractor: dataManager.metadataExtractor,
    > 333:         )
    > 334:         let artworkService = ArtworkService(container: dataManager.container)
    > 335:         let widgetCoordinator = WidgetDataCoordinator(
    > 336:             stateManager: playbackStateManager,
    > 337:             queueManager: queueManager,
    > 338:             artworkService: artworkService,
    > 339:         )
    > 340:         return AppServices(
    > 341:             dataManager: dataManager,
    > 342:             audioService: audioService,
    > 343:             importService: importService,
    > 344:             artworkService: artworkService,
    > 345:             widgetCoordinator: widgetCoordinator,
    > 346:             recoveryError: nil,
    > 347:         )
- Limitations:
  - No session lifecycle integration test or device playback run was available.

### WP3-011 - Import failures after copy leave orphaned managed audio files

- Final severity: High
- Confidence: Very high
- Verification status: CONFIRMED STATIC FAILURE PATH; filesystem result UNVERIFIED
- Source report records:
  - DLP-005: High -> High; retained
- Reachability and impact: The active import path copies a file into the managed music container before metadata extraction and SwiftData insertion. Any later throw is converted into a failed result, but no code removes the new destination. Repeated malformed imports, cancellation, or save failures can consume large amounts of storage with files absent from the library.
- Guards and mitigating controls: Duplicate checks occur before copy and filename collisions receive unique suffixes. Those controls reduce duplicate starts but do not roll back a destination once copy succeeds. The source file is not deleted.
- Severity rationale: Retain High because the defect is reachable through normal import failure and can cause unbounded invisible storage growth, including multi-gigabyte files.
- Evidence:
  - Fonic HiFi/Data/Actors/FileImportProcessor.swift:622-634
    > 622:         let copiedFileURL = try copyFile(
    > 623:             from: resolvedURL,
    > 624:             to: baseDirectory,
    > 625:             logger: logger,
    > 626:         )
    > 627:
    > 628:         let trackMetadata = try await metadataExtractor.extractTrackMetadata(from: copiedFileURL)
    > 629:         let enrichedMetadata = trackMetadata.withSourceInfo(
    > 630:             sourceURL: file.originalURL,
    > 631:             sourceBookmark: file.securityScopedBookmark
    > 632:         )
    > 633:
    > 634:         return try await trackDataActor.createTrack(from: enrichedMetadata)
  - Fonic HiFi/Data/Actors/FileImportProcessor.swift:393-408
    > 393:         } catch {
    > 394:             let duration = Date().timeIntervalSince(taskStart)
    > 395:             let filename = file.originalURL.lastPathComponent
    > 396:             let errorDescription = error.localizedDescription
    > 397:             logger.error(
    > 398:                 """
    > 399:                 File import failed for \(filename, privacy: .public):
    > 400:                 \(errorDescription, privacy: .public)
    > 401:                 """
    > 402:             )
    > 403:             return ProcessedFileResult(
    > 404:                 file: file,
    > 405:                 identifier: nil,
    > 406:                 error: ProcessedFileError(message: error.localizedDescription),
    > 407:                 duration: duration
    > 408:             )
  - Fonic HiFi/Data/Actors/FileImportProcessor.swift:669-695
    > 669:     private static func copyFile(
    > 670:         from sourceURL: URL,
    > 671:         to baseDirectory: URL,
    > 672:         logger: Logger,
    > 673:     ) throws -> URL {
    > 674:         let fileManager = FileManager.default
    > 675:         var destinationURL = baseDirectory.appendingPathComponent(sourceURL.lastPathComponent)
    > 676:
    > 677:         while true {
    > 678:             do {
    > 679:                 try fileManager.copyItem(at: sourceURL, to: destinationURL)
    > 680:                 logger.debug("Copied file to: \(destinationURL.path)")
    > 681:                 return destinationURL
    > 682:             } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError {
    > 683:                 let baseName = sourceURL.deletingPathExtension().lastPathComponent
    > 684:                 let ext = sourceURL.pathExtension
    > 685:                 let uniqueSuffix = UUID().uuidString.prefix(8)
    > 686:                 let newFileName = if ext.isEmpty {
    > 687:                     "\(baseName)-\(uniqueSuffix)"
    > 688:                 } else {
    > 689:                     "\(baseName)-\(uniqueSuffix).\(ext)"
    > 690:                 }
    > 691:                 destinationURL = baseDirectory.appendingPathComponent(newFileName)
    > 692:             } catch {
    > 693:                 throw error
    > 694:             }
    > 695:         }
- Limitations:
  - No injected post-copy failure or device disk-usage test was run.

### WP3-012 - Startup cleanup deletes metadata after a single missing-file observation

- Final severity: Medium
- Confidence: Medium-high
- Verification status: CONFIRMED DESTRUCTIVE POLICY; temporary-unavailability trigger UNVERIFIED
- Source report records:
  - DLP-007: High -> Medium; downgraded
- Reachability and impact: Three seconds after startup, the app fetches every Track and permanently deletes any row whose URL returns fileExists false, then saves once. There is no retry, quarantine, protected-data check, or user confirmation. Track metadata, favorites, counts, and playlist discoverability can be lost if false is temporary.
- Guards and mitigating controls: Imported files are normally managed local copies, making temporary unavailability less likely than the prior report implied. A missing file may also represent an intentional external deletion. The 3-second delay avoids immediate launch cost but is not a validity check.
- Severity rationale: Downgrade to Medium because the destructive one-sample policy is confirmed, but a realistic temporary false-negative on the managed Documents path was not reproduced. Escalate only with a protected-data or provider test that demonstrates unintended deletion.
- Evidence:
  - Fonic HiFi/FonicHiFiApp.swift:194-208
    > 194:     @MainActor
    > 195:     private func performStartupTasks() async {
    > 196:         guard let dataManager else { return }
    > 197:
    > 198:         // Defer cleanup by 3 seconds - not launch-critical
    > 199:         Task {
    > 200:             try? await Task.sleep(for: .seconds(3))
    > 201:             do {
    > 202:                 let removedCount = try await dataManager.cleanupMissingFiles()
    > 203:                 if removedCount > 0 {
    > 204:                     logger.info("Cleaned up \(removedCount) missing files from library")
    > 205:                 }
    > 206:             } catch {
    > 207:                 logger.error("Failed to cleanup missing files: \(error.localizedDescription)")
    > 208:             }
  - Fonic HiFi/Data/Actors/TrackDataActor.swift:687-705
    > 687:     /// Remove tracks that have missing files
    > 688:     /// - Returns: Number of tracks removed
    > 689:     public func cleanupMissingFiles() throws -> Int {
    > 690:         let fetchDescriptor = FetchDescriptor<Track>()
    > 691:
    > 692:         do {
    > 693:             let tracks = try modelContext.fetch(fetchDescriptor)
    > 694:             var removedCount = 0
    > 695:
    > 696:             for track in tracks {
    > 697:                 if !FileManager.default.fileExists(atPath: track.url.path) {
    > 698:                     modelContext.delete(track)
    > 699:                     removedCount += 1
    > 700:                 }
    > 701:             }
    > 702:
    > 703:             if removedCount > 0 {
    > 704:                 try modelContext.save()
    > 705:                 logger.info("Cleaned up \(removedCount) missing files")
- Limitations:
  - No locked-device, protected-data, Files app, or File Provider scenario reproduced a temporary false result.

### WP3-013 - Import cancellation is not propagated to AsyncStream producers

- Final severity: Medium
- Confidence: Very high
- Verification status: CONFIRMED STATIC CANCELLATION GAP; post-cancel work extent UNVERIFIED
- Source report records:
  - CP-002: High -> Medium; merged; merged into DLP-021
- Reachability and impact: Discovery and processing streams each spawn an unowned Task and install no continuation.onTermination handler. cancelImport cancels the consumer-owned task, but that does not cancel the producer task that owns directory traversal and the processing TaskGroup. Work can continue after the UI says Import cancelled.
- Guards and mitigating controls: The producer checks Task.isCancelled and calls group.cancelAll, and LibraryImportService owns a separate discoveryTask. Those controls activate only if cancellation reaches the producer; the missing link is the defect. Concurrency is bounded, limiting simultaneous copies.
- Severity rationale: Merge CP-002 into the identical DLP-021 record and correct the canonical severity to Medium. Extra post-cancel work is plausible and statically enabled but its duration and number of committed files are scheduling-dependent and unmeasured.
- Evidence:
  - Fonic HiFi/Data/Actors/FileImportProcessor.swift:101-105,143-155
    > 101:     /// Discover audio files lazily via streaming sequence
    > 102:     func discoverAudioFilesStream(from urls: [URL]) -> AsyncStream<DiscoveredAudioFile> {
    > 103:         AsyncStream { continuation in
    > 104:             Task { await self.emitDiscoveredFiles(from: urls, to: continuation) }
    > 105:         }
    > 143:         return AsyncStream<ProcessedFileResult> { continuation in
    > 144:             Task {
    > 145:                 await Self.emitProcessedFiles(
    > 146:                     from: files,
    > 147:                     maxConcurrentTasks: maxConcurrentTasks,
    > 148:                     baseDirectory: baseDirectory,
    > 149:                     metadataExtractor: extractor,
    > 150:                     trackDataActor: trackActor,
    > 151:                     securityAccessor: accessor,
    > 152:                     logger: log,
    > 153:                     to: continuation
    > 154:                 )
    > 155:             }
  - Fonic HiFi/Data/Actors/FileImportProcessor.swift:276-334
    > 276:         await withTaskGroup(of: ProcessedFileResult.self) { group in
    > 277:             for _ in 0..<concurrency {
    > 278:                 guard !Task.isCancelled else { break }
    > 279:                 guard let discoveredFile = await iterator.next() else { break }
    > 280:
    > 281:                 let currentCache = hashCache
    > 282:                 group.addTask {
    > 283:                     await Self.processDiscoveredFile(
    > 284:                         discoveredFile,
    > 285:                         hashCache: currentCache,
    > 286:                         baseDirectory: baseDirectory,
    > 287:                         metadataExtractor: metadataExtractor,
    > 288:                         trackDataActor: trackDataActor,
    > 289:                         securityAccessor: securityAccessor,
    > 290:                         logger: logger
    > 291:                     )
    > 292:                 }
    > 293:                 stats.recordLaunch()
    > 294:             }
    > 295:
    > 296:             while let result = await group.next() {
    > 297:                 stats.recordCompletion(for: result)
    > 298:
    > 299:                 if result.succeeded {
    > 300:                     let urlHash = result.file.originalURL.librarySourceHash()
    > 301:                     let bookmarkHash = result.file.securityScopedBookmark?.sha256Hex()
    > 302:                     let urlString = result.file.originalURL.absoluteString
    > 303:                     hashCache.addEntry(urlHash: urlHash, bookmarkHash: bookmarkHash, urlString: urlString)
    > 304:                 }
    > 305:
    > 306:                 continuation.yield(
    > 307:                     result
    > 308:                 )
    > 309:
    > 310:                 if Task.isCancelled {
    > 311:                     break
    > 312:                 }
    > 313:
    > 314:                 if let discoveredFile = await iterator.next() {
    > 315:                     let currentCache = hashCache
    > 316:                     group.addTask {
    > 317:                         await Self.processDiscoveredFile(
    > 318:                             discoveredFile,
    > 319:                             hashCache: currentCache,
    > 320:                             baseDirectory: baseDirectory,
    > 321:                             metadataExtractor: metadataExtractor,
    > 322:                             trackDataActor: trackDataActor,
    > 323:                             securityAccessor: securityAccessor,
    > 324:                             logger: logger
    > 325:                         )
    > 326:                     }
    > 327:                     stats.recordLaunch()
    > 328:                 }
    > 329:
    > 330:                 logQueueProgressIfNeeded(stats: &stats, logger: logger)
    > 331:             }
    > 332:
    > 333:             group.cancelAll()
    > 334:         }
  - Fonic HiFi/Data/Services/LibraryImportService.swift:233-241
    > 233:         for await result in stream {
    > 234:             if Task.isCancelled {
    > 235:                 discoveryTask.cancel()
    > 236:                 queueContinuation.finish()
    > 237:                 _ = await discoveryTask.result
    > 238:                 self.statusMessage = "Import cancelled"
    > 239:                 self.isImporting = false
    > 240:                 self.logger.info("Import task cancelled")
    > 241:                 return
- Limitations:
  - No slow-copy collaborator or Swift Concurrency Instruments run measured work after cancellation.

### WP3-014 - Queue mutation persists the full queue synchronously on MainActor

- Final severity: Medium
- Confidence: High
- Verification status: CONFIRMED STATIC COST; user-visible latency UNMEASURED
- Source report records:
  - CP-003: High -> Medium; downgraded
- Reachability and impact: AudioQueueManager is MainActor-isolated. Track and current-track notifications each call saveState. Every save filters the full queue and history with fileExists, JSON-encodes the snapshot, and writes it to UserDefaults. replaceQueue can cause duplicate full passes, and Shuffle All can supply up to 1,000 tracks.
- Guards and mitigating controls: History is capped and persistence errors are caught. The queue itself is not capped, and no debounce exists. No device timing proves a hang threshold or missed audio deadline.
- Severity rationale: Downgrade to Medium. The synchronous scaling defect is confirmed, but High requires profiling evidence of material stalls on supported hardware and representative queue sizes.
- Evidence:
  - Fonic HiFi/Core/Audio/Queue/AudioQueueManager.swift:12-15,574-591,655-664
    > 12: /// Main actor class that manages the audio playback queue
    > 13: @MainActor
    > 14: @Observable
    > 15: public final class AudioQueueManager: AudioQueue {
    > 574:     public func saveState(playbackPosition: TimeInterval = 0) {
    > 575:         let state = QueueState(
    > 576:             tracks: tracks,
    > 577:             currentIndex: currentIndex,
    > 578:             shuffleMode: shuffleMode,
    > 579:             repeatMode: repeatMode,
    > 580:             hasNext: hasNext,
    > 581:             hasPrevious: hasPrevious,
    > 582:             history: history,
    > 583:             shuffleSequence: shuffleMode.isActive ? shuffleSequence : nil,
    > 584:             timestamp: Date(),
    > 585:             lastPlaybackPosition: playbackPosition,
    > 586:         )
    > 587:
    > 588:         do {
    > 589:             // Validate and save state
    > 590:             let validatedState = state.validateForPersistence()
    > 591:             try validatedState.save()
    > 655:     private func notifyTracksChanged() {
    > 656:         delegate?.audioQueue(self, didUpdateTracks: tracks)
    > 657:         // Auto-save when tracks change
    > 658:         saveState()
    > 659:     }
    > 660:
    > 661:     private func notifyCurrentTrackChanged() {
    > 662:         delegate?.audioQueue(self, didChangeCurrentTrack: currentTrack, at: currentIndex)
    > 663:         // Auto-save when current track changes
    > 664:         saveState()
  - Fonic HiFi/Core/Audio/Queue/QueueState.swift:321-326,359-400
    > 321:     /// Save queue state to UserDefaults
    > 322:     func save() throws {
    > 323:         let encoder = JSONEncoder()
    > 324:         encoder.dateEncodingStrategy = .iso8601
    > 325:         let data = try encoder.encode(self)
    > 326:         UserDefaults.standard.set(data, forKey: Self.persistenceKey)
    > 359:     /// Create a persistence-safe version of the queue state
    > 360:     /// This excludes tracks that may no longer be available
    > 361:     func validateForPersistence() -> QueueState {
    > 362:         // Filter out tracks that no longer exist on disk
    > 363:         let validTracks = tracks.filter { track in
    > 364:             FileManager.default.fileExists(atPath: track.url.path)
    > 365:         }
    > 366:
    > 367:         // Adjust current index if needed
    > 368:         let validCurrentIndex: Int? = if let currentTrack,
    > 369:                                          let newIndex = validTracks.firstIndex(where: { $0.id == currentTrack.id }) {
    > 370:             newIndex
    > 371:         } else {
    > 372:             nil
    > 373:         }
    > 374:
    > 375:         // Adjust shuffle sequence if needed
    > 376:         let validShuffleSequence: [Int]? = if let shuffleSequence {
    > 377:             shuffleSequence.filter { $0 < validTracks.count }
    > 378:         } else {
    > 379:             nil
    > 380:         }
    > 381:
    > 382:         let hasNext = { () -> Bool in
    > 383:             guard let index = validCurrentIndex else { return false }
    > 384:             return index < validTracks.count - 1
    > 385:         }()
    > 386:
    > 387:         let hasPrevious = { () -> Bool in
    > 388:             guard let index = validCurrentIndex else { return false }
    > 389:             return index > 0
    > 390:         }()
    > 391:
    > 392:         return QueueState(
    > 393:             tracks: validTracks,
    > 394:             currentIndex: validCurrentIndex,
    > 395:             shuffleMode: shuffleMode,
    > 396:             repeatMode: repeatMode,
    > 397:             hasNext: hasNext,
    > 398:             hasPrevious: hasPrevious,
    > 399:             history: history.filter { track in
    > 400:                 FileManager.default.fileExists(atPath: track.url.path)
  - Fonic HiFi/Presentation/Views/Home/HomeView.swift:240-251
    > 240:     private func shuffleAll() {
    > 241:         guard let dataManager, let audioEngine else { return }
    > 242:         Task {
    > 243:             do {
    > 244:                 let allTracks = try await dataManager.getRecentlyAddedTracks(limit: 1000)
    > 245:                 guard !allTracks.isEmpty else { return }
    > 246:
    > 247:                 let shuffledTracks = allTracks.shuffled()
    > 248:                 let audioTracks = shuffledTracks.map { $0.toAudioTrack() }
    > 249:                 audioEngine.queueManager.replaceQueue(with: audioTracks, startIndex: 0)
    > 250:                 if let firstTrack = shuffledTracks.first {
    > 251:                     try await audioEngine.play(track: firstTrack)
- Limitations:
  - No Time Profiler, Hangs, File Activity, or device latency measurement was available.

### WP3-015 - Concurrent import deduplication is not an atomic claim

- Final severity: Medium
- Confidence: High
- Verification status: CONFIRMED RACE WINDOW; duplicate reproduction UNVERIFIED
- Source report records:
  - CP-004: High -> Medium; merged; merged into DLP-006
- Reachability and impact: Initial import children receive the same value snapshot of SourceHashCache. The coordinator adds an identity only after a child succeeds. Two identical files in one concurrency window can both pass the cache and serialized actor query before either reaches createTrack, then create separate copies and rows.
- Guards and mitigating controls: LibraryImportService prevents overlapping top-level imports and TrackDataActor serializes each query and insert call. Neither makes the check-plus-copy-plus-insert sequence atomic. Concurrency is bounded and the trigger requires duplicates in the same batch/window.
- Severity rationale: Merge CP-004 into the identical DLP-006 record and correct the canonical severity to Medium. The race is real, but impact is duplicate rows/files rather than corruption of unrelated data, and reproduction was not run.
- Evidence:
  - Fonic HiFi/Data/Actors/FileImportProcessor.swift:273-303,314-327
    > 273:         var hashCache = await loadSourceHashCache(from: trackDataActor, logger: logger)
    > 274:         var stats = ImportQueueStats()
    > 275:
    > 276:         await withTaskGroup(of: ProcessedFileResult.self) { group in
    > 277:             for _ in 0..<concurrency {
    > 278:                 guard !Task.isCancelled else { break }
    > 279:                 guard let discoveredFile = await iterator.next() else { break }
    > 280:
    > 281:                 let currentCache = hashCache
    > 282:                 group.addTask {
    > 283:                     await Self.processDiscoveredFile(
    > 284:                         discoveredFile,
    > 285:                         hashCache: currentCache,
    > 286:                         baseDirectory: baseDirectory,
    > 287:                         metadataExtractor: metadataExtractor,
    > 288:                         trackDataActor: trackDataActor,
    > 289:                         securityAccessor: securityAccessor,
    > 290:                         logger: logger
    > 291:                     )
    > 292:                 }
    > 293:                 stats.recordLaunch()
    > 294:             }
    > 295:
    > 296:             while let result = await group.next() {
    > 297:                 stats.recordCompletion(for: result)
    > 298:
    > 299:                 if result.succeeded {
    > 300:                     let urlHash = result.file.originalURL.librarySourceHash()
    > 301:                     let bookmarkHash = result.file.securityScopedBookmark?.sha256Hex()
    > 302:                     let urlString = result.file.originalURL.absoluteString
    > 303:                     hashCache.addEntry(urlHash: urlHash, bookmarkHash: bookmarkHash, urlString: urlString)
    > 314:                 if let discoveredFile = await iterator.next() {
    > 315:                     let currentCache = hashCache
    > 316:                     group.addTask {
    > 317:                         await Self.processDiscoveredFile(
    > 318:                             discoveredFile,
    > 319:                             hashCache: currentCache,
    > 320:                             baseDirectory: baseDirectory,
    > 321:                             metadataExtractor: metadataExtractor,
    > 322:                             trackDataActor: trackDataActor,
    > 323:                             securityAccessor: securityAccessor,
    > 324:                             logger: logger
    > 325:                         )
    > 326:                     }
    > 327:                     stats.recordLaunch()
  - Fonic HiFi/Data/Actors/FileImportProcessor.swift:617-634
    > 617:         if try await trackDataActor.trackExists(for: file.originalURL, bookmark: file.securityScopedBookmark) != nil {
    > 618:             logger.notice("Duplicate import skipped for: \(file.originalURL.lastPathComponent, privacy: .public)")
    > 619:             throw ProcessedFileError(message: "Duplicate file already exists")
    > 620:         }
    > 621:
    > 622:         let copiedFileURL = try copyFile(
    > 623:             from: resolvedURL,
    > 624:             to: baseDirectory,
    > 625:             logger: logger,
    > 626:         )
    > 627:
    > 628:         let trackMetadata = try await metadataExtractor.extractTrackMetadata(from: copiedFileURL)
    > 629:         let enrichedMetadata = trackMetadata.withSourceInfo(
    > 630:             sourceURL: file.originalURL,
    > 631:             sourceBookmark: file.securityScopedBookmark
    > 632:         )
    > 633:
    > 634:         return try await trackDataActor.createTrack(from: enrichedMetadata)
  - Fonic HiFi/Data/Actors/TrackDataActor.swift:480-505
    > 480:     public func trackExists(for url: URL, bookmark: Data? = nil) throws -> PersistentIdentifier? {
    > 481:         let normalizedHash = url.librarySourceHash()
    > 482:         let absoluteSource = url.absoluteString
    > 483:         let bookmarkHash = bookmark?.sha256Hex()
    > 484:
    > 485:         let predicate: Predicate<Track>
    > 486:         if let bookmarkHash {
    > 487:             predicate = #Predicate<Track> { track in
    > 488:                 track.sourceBookmarkHash == bookmarkHash ||
    > 489:                     track.sourceURLHash == normalizedHash ||
    > 490:                     track.sourceURLString == absoluteSource ||
    > 491:                     track.url == url
    > 492:             }
    > 493:         } else {
    > 494:             predicate = #Predicate<Track> { track in
    > 495:                 track.sourceURLHash == normalizedHash ||
    > 496:                     track.sourceURLString == absoluteSource ||
    > 497:                     track.url == url
    > 498:             }
    > 499:         }
    > 500:
    > 501:         let fetchDescriptor = FetchDescriptor<Track>(predicate: predicate)
    > 502:
    > 503:         do {
    > 504:             let tracks = try modelContext.fetch(fetchDescriptor)
    > 505:             return tracks.first?.persistentModelID
- Limitations:
  - No concurrent duplicate-import test was run with Xcode or a real ModelContainer.

### WP3-016 - Combine audio facade is injected through an unobserved custom environment value

- Final severity: High
- Confidence: High
- Verification status: CONFIRMED OBSERVATION MISMATCH; stale rendering UNVERIFIED
- Source report records:
  - UIUX-001: High -> High; retained
- Reachability and impact: AudioEngineFacade conforms to ObservableObject and exposes @Published currentTrack, showMiniPlayer, and diagnosticsStatus. The app stores it as a plain let and descendants retrieve it through a custom EnvironmentValue. SwiftUI receives the reference but no ObservedObject, StateObject, or EnvironmentObject subscription. Direct consumers such as MorphableArtwork and the mini-player therefore have no guaranteed invalidation when only those published proxies change.
- Guards and mitigating controls: Some computed playback values traverse nested Observation models and other view state can incidentally trigger a redraw. That does not subscribe direct reads of the facade's @Published properties and cannot guarantee correct title, artwork, or diagnostic updates.
- Severity rationale: Retain High because stale track identity and controls affect the primary playback surface and automatic track changes. The structural mismatch is direct and current Apple guidance distinguishes Combine subscription from Observation tracking.
- Evidence:
  - Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:22-23,66-68
    > 22: @MainActor
    > 23: public final class AudioEngineFacade: ObservableObject {
    > 66:     @Published public private(set) var currentTrack: Track?
    > 67:     @Published public private(set) var showMiniPlayer: Bool = false
    > 68:     @Published public private(set) var diagnosticsStatus: DiagnosticsStatus = .empty
  - Fonic HiFi/Presentation/Environment/AudioEnvironment.swift:13-23,88-96
    > 13: /// Environment key for AudioEngineFacade dependency injection
    > 14: struct AudioEngineKey: EnvironmentKey {
    > 15:     static let defaultValue: AudioEngineFacade? = nil
    > 16: }
    > 17:
    > 18: extension EnvironmentValues {
    > 19:     /// Access to the audio engine facade through environment
    > 20:     var audioEngine: AudioEngineFacade? {
    > 21:         get { self[AudioEngineKey.self] }
    > 22:         set { self[AudioEngineKey.self] = newValue }
    > 23:     }
    > 88: extension View {
    > 89:     /// Injects the audio engine into the environment
    > 90:     func audioEngine(_ audioEngine: AudioEngineFacade) -> some View {
    > 91:         environment(\.audioEngine, audioEngine)
    > 92:     }
    > 93:
    > 94:     /// Injects an optional audio engine into the environment
    > 95:     func audioEngine(_ audioEngine: AudioEngineFacade?) -> some View {
    > 96:         environment(\.audioEngine, audioEngine)
  - Fonic HiFi/Presentation/Views/NowPlaying/LiquidGlassMiniPlayer.swift:13-15,36-48
    > 13: struct LiquidGlassMiniPlayer: View {
    > 14:     @Environment(\.audioEngine) private var audioService
    > 15:
    > 36:     private var playerInfo: some View {
    > 37:         HStack(spacing: 12) {
    > 38:             MorphableArtwork(size: 30, namespace: namespace)
    > 39:
    > 40:             VStack(alignment: .leading, spacing: 6) {
    > 41:                 Text(audioService?.currentTrack?.title ?? "Not Playing")
    > 42:                     .font(.callout)
    > 43:                     .lineLimit(1)
    > 44:
    > 45:                 Text(audioService?.currentTrack?.artist ?? "No Artist")
    > 46:                     .font(.caption2)
    > 47:                     .foregroundStyle(.gray)
    > 48:                     .lineLimit(1)
  - Fonic HiFi/Presentation/Views/NowPlaying/MorphableArtwork.swift:14-17,31-40
    > 14: struct MorphableArtwork: View {
    > 15:     let size: CGFloat
    > 16:     let namespace: Namespace.ID
    > 17:     @Environment(\.audioEngine) private var audioService
    > 31:     @ViewBuilder
    > 32:     private var artworkContent: some View {
    > 33:         if let artworkData = audioService?.currentTrack?.artwork,
    > 34:            let uiImage = UIImage(data: artworkData) {
    > 35:             Image(uiImage: uiImage)
    > 36:                 .resizable()
    > 37:                 .aspectRatio(contentMode: .fill)
    > 38:         } else {
    > 39:             // Placeholder when no artwork available
    > 40:             placeholderArtwork
- External sources:
  - https://developer.apple.com/documentation/swiftui/model-data
  - https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app
- Limitations:
  - No Xcode preview, simulator, or device rendering test observed the stale-state manifestation.

### WP3-017 - Now Playing mirrors shuffle, repeat, and speed outside authoritative owners

- Final severity: Medium
- Confidence: High
- Verification status: CONFIRMED STATIC STATE DUPLICATION
- Source report records:
  - UIUX-002: High -> Medium; downgraded
- Reachability and impact: NowPlayingContent renders local @State playbackSpeed and separate AppStorage keys for shuffle and repeat. The queue and settings store already own those effective values, and ToggleShuffleIntent mutates queueState directly. After restore or an external intent, display state and the next toggle action can disagree with actual playback.
- Guards and mitigating controls: Local taps update both the engine and local mirror, so the common in-view action remains coherent until another owner changes state. The issue is misrepresentation and wrong next transition, not data loss or inability to play.
- Severity rationale: Downgrade to Medium. The defect violates single-source-of-truth and can make controls wrong, but the verified impact is localized control drift.
- Evidence:
  - Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:29,39-49
    > 29:     @State private var playbackSpeed: Double = 1.0
    > 39:     @AppStorage("isShuffleEnabled") private var isShuffleEnabled: Bool = false
    > 40:     @AppStorage("repeatMode") private var repeatModeRawValue: String = QueueRepeatMode.none.rawValue
    > 41:
    > 42:     private var volume: Float {
    > 43:         get { Float(volumeStorage) }
    > 44:         set { volumeStorage = Double(newValue) }
    > 45:     }
    > 46:
    > 47:     private var repeatMode: QueueRepeatMode {
    > 48:         get { QueueRepeatMode(rawValue: repeatModeRawValue) ?? .none }
    > 49:         set { repeatModeRawValue = newValue.rawValue }
  - Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:660-679
    > 660:     private func toggleShuffle() {
    > 661:         Task { @MainActor in
    > 662:             guard let audioService else { return }
    > 663:             let newMode: QueueShuffleMode = isShuffleEnabled ? .off : .random
    > 664:             audioService.setShuffleMode(newMode)
    > 665:             isShuffleEnabled = newMode != .off
    > 666:         }
    > 667:     }
    > 668:
    > 669:     private func cycleRepeatMode() {
    > 670:         Task { @MainActor in
    > 671:             guard let audioService else { return }
    > 672:             let newMode: QueueRepeatMode = switch repeatMode {
    > 673:             case .none: .all
    > 674:             case .all: .one
    > 675:             case .one: .none
    > 676:             }
    > 677:             audioService.setRepeatMode(newMode)
    > 678:             repeatModeRawValue = newMode.rawValue
    > 679:         }
  - Fonic HiFi/Core/Intents/ToggleShuffleIntent.swift:31-35
    > 31:         // Toggle shuffle mode (off -> random -> smart -> off)
    > 32:         let currentMode = engine.queueState.shuffleMode
    > 33:         let newMode: QueueShuffleMode = currentMode.isActive ? .off : .random
    > 34:
    > 35:         engine.setShuffleMode(newMode)
- External sources:
  - https://developer.apple.com/documentation/swiftui/model-data
- Limitations:
  - No UI test exercised queue restore and App Intent mutation while Now Playing remained open.

### WP3-018 - Visible settings include inert controls and log-only actions

- Final severity: Medium
- Confidence: High
- Verification status: CONFIRMED STATICALLY
- Source report records:
  - UIUX-008: High -> Medium; downgraded
- Reachability and impact: Dark Mode, Now Playing Animation, Haptic Feedback, Show File Extensions, bit-perfect, buffer size, and sample-rate controls write keys without runtime consumers. Export Settings, Import Settings, and Test Audio Configuration only log. Some controls therefore promise behavior or audiophile signal-path changes that do not occur.
- Guards and mitigating controls: Other settings are wired: artwork theming, gapless, crossfade, and Replay Gain have active consumers. The audio-control subset duplicates the existing AUD-CONFIG-001 root cause, but UIUX-008 also covers separate inert app controls and actions.
- Severity rationale: Downgrade to Medium. False feedback is broad and harms trust, but no safety, privacy, persistence, or core-playback failure follows from the toggles themselves.
- Evidence:
  - Fonic HiFi/Presentation/Views/Settings/SettingsView.swift:13-17,53-59,64-87,122-128
    > 13:     @AppStorage("enableBitPerfectPlayback") private var bitPerfectEnabled = false
    > 14:     @AppStorage("darkModeEnabled") private var darkModeEnabled = true
    > 15:     @AppStorage("showNowPlayingAnimation") private var animationEnabled = true
    > 16:     @AppStorage("enableHapticFeedback") private var hapticsEnabled = true
    > 17:     @AppStorage("showFileExtensions") private var showExtensions = true
    > 53:                     Toggle(isOn: $bitPerfectEnabled) {
    > 54:                         SettingsRow(
    > 55:                             icon: "waveform",
    > 56:                             iconColor: .blue,
    > 57:                             title: "Bit-Perfect Mode"
    > 58:                         )
    > 59:                     }
    > 64:                 Section("Appearance") {
    > 65:                     Toggle(isOn: $darkModeEnabled) {
    > 66:                         SettingsRow(
    > 67:                             icon: "moon.fill",
    > 68:                             iconColor: .purple,
    > 69:                             title: "Dark Mode"
    > 70:                         )
    > 71:                     }
    > 72:
    > 73:                     Toggle(isOn: $animationEnabled) {
    > 74:                         SettingsRow(
    > 75:                             icon: "waveform.circle.fill",
    > 76:                             iconColor: .pink,
    > 77:                             title: "Now Playing Animation"
    > 78:                         )
    > 79:                     }
    > 80:
    > 81:                     Toggle(isOn: $hapticsEnabled) {
    > 82:                         SettingsRow(
    > 83:                             icon: "hand.tap.fill",
    > 84:                             iconColor: .gray,
    > 85:                             title: "Haptic Feedback"
    > 86:                         )
    > 87:                     }
    > 122:                     Toggle(isOn: $showExtensions) {
    > 123:                         SettingsRow(
    > 124:                             icon: "doc.text.fill",
    > 125:                             iconColor: .gray,
    > 126:                             title: "Show File Extensions"
    > 127:                         )
    > 128:                     }
  - Fonic HiFi/ContentView.swift:55-56
    > 55:         }
    > 56:         .preferredColorScheme(.dark)
  - Fonic HiFi/Presentation/Views/Settings/SettingsView.swift:216-232
    > 216:     private func exportSettings() {
    > 217:         logger.info("Exporting settings")
    > 218:     }
    > 219:
    > 220:     private func importSettings() {
    > 221:         logger.info("Importing settings")
    > 222:     }
    > 223:
    > 224:     private func resetSettings() {
    > 225:         bitPerfectEnabled = false
    > 226:         darkModeEnabled = true
    > 227:         animationEnabled = true
    > 228:         hapticsEnabled = true
    > 229:         showExtensions = true
    > 230:         artworkThemingEnabled = true
    > 231:         artworkThemingLightMode = true
    > 232:         logger.info("Reset all settings to defaults")
  - Fonic HiFi/Presentation/Views/Settings/AudioSettingsView.swift:13-15,37-84,145-150
    > 13:     @AppStorage("enableBitPerfectPlayback") private var enableBitPerfectPlayback = false
    > 14:     @AppStorage("audioBufferSize") private var audioBufferSize = 512.0
    > 15:     @AppStorage("sampleRate") private var sampleRate = 44100.0
    > 37:                 Section {
    > 38:                     Toggle("Enable Bit-Perfect Playback", isOn: $enableBitPerfectPlayback)
    > 39:                 } header: {
    > 40:                     Text("Audio Quality")
    > 41:                 } footer: {
    > 42:                     Text("Bit-perfect playback ensures no digital processing is applied to the audio signal, preserving the original quality.")
    > 43:                 }
    > 44:
    > 45:                 Section {
    > 46:                     VStack(alignment: .leading, spacing: 12) {
    > 47:                         HStack {
    > 48:                             Text("Buffer Size")
    > 49:                             Spacer()
    > 50:                             Text("\(Int(audioBufferSize)) samples")
    > 51:                                 .foregroundColor(.secondary)
    > 52:                         }
    > 53:
    > 54:                         Slider(
    > 55:                             value: $audioBufferSize,
    > 56:                             in: 64 ... 2048,
    > 57:                             step: 64,
    > 58:                         ) {
    > 59:                             Text("Buffer Size")
    > 60:                         }
    > 61:                     }
    > 62:
    > 63:                     VStack(alignment: .leading, spacing: 12) {
    > 64:                         HStack {
    > 65:                             Text("Sample Rate")
    > 66:                             Spacer()
    > 67:                             Text("\(Int(sampleRate)) Hz")
    > 68:                                 .foregroundColor(.secondary)
    > 69:                         }
    > 70:
    > 71:                         Picker("Sample Rate", selection: $sampleRate) {
    > 72:                             Text("44,100 Hz").tag(44100.0)
    > 73:                             Text("48,000 Hz").tag(48000.0)
    > 74:                             Text("88,200 Hz").tag(88200.0)
    > 75:                             Text("96,000 Hz").tag(96000.0)
    > 76:                             Text("176,400 Hz").tag(176_400.0)
    > 77:                             Text("192,000 Hz").tag(192_000.0)
    > 78:                         }
    > 79:                         .pickerStyle(.menu)
    > 80:                     }
    > 81:                 } header: {
    > 82:                     Text("Audio Configuration")
    > 83:                 } footer: {
    > 84:                     Text("Lower buffer sizes reduce latency but may cause audio dropouts. Higher sample rates provide better quality but require more processing power.")
    > 145:     private func testAudioConfiguration() {
    > 146:         // Test audio configuration
    > 147:         Task {
    > 148:             // This would test the current audio configuration
    > 149:             logger.info("Testing audio configuration from settings view")
    > 150:         }
- Limitations:
  - No device audio-session inspection was run, but whole-source call-site counts found no consumers for the identified keys.

### WP3-019 - Core failures are logged but shown as normal emptiness or silence

- Final severity: High
- Confidence: High
- Verification status: CONFIRMED STATICALLY
- Source report records:
  - UIUX-009: High -> High; retained
- Reachability and impact: Audio initialization failure leaves the facade unavailable but never updates the existing launch alert. Home swallows any load error and can show import-empty messaging. Standard search converts failure to empty results; Smart Search creates an error state that SearchView never renders; File Manager logs directory failure and keeps an empty list. Users receive the wrong diagnosis and no recovery action.
- Guards and mitigating controls: Detailed OSLog entries exist, and LibraryView separately exposes view-model errors. Those controls do not cover the cited app, Home, Search, Smart Search, and File Manager paths and are not visible to ordinary users.
- Severity rationale: Retain High because a failed audio initialization can make all playback impossible with no user-facing explanation, while data-load errors are presented as absence of user content.
- Evidence:
  - Fonic HiFi/FonicHiFiApp.swift:155-190
    > 155:     @MainActor
    > 156:     private func initializeApp() async {
    > 157:         logger.info("Initializing Fonic HiFi app...")
    > 158:
    > 159:         do {
    > 160:             // Initialize audio service with proper error handling
    > 161:             try await audioService.initialize()
    > 162:             logger.info("Audio service initialized successfully")
    > 163:
    > 164:             // Configure intent dependency provider for widget/Live Activity intents
    > 165:             IntentDependencyProvider.shared.configure(
    > 166:                 audioEngine: audioService,
    > 167:                 widgetCoordinator: widgetCoordinator
    > 168:             )
    > 169:             logger.info("IntentDependencyProvider configured")
    > 170:
    > 171:             // Perform any other startup tasks
    > 172:             await performStartupTasks()
    > 173:
    > 174:             // Track app launch time
    > 175:             let launchDuration = Date().timeIntervalSince(appLaunchStartTime)
    > 176:             await performanceMonitor.recordAppLaunchTime(launchDuration)
    > 177:             logger.info("App launch completed in \(String(format: "%.2f", launchDuration)) seconds")
    > 178:
    > 179:         } catch {
    > 180:             logger.error("Failed to initialize app: \(error.localizedDescription)")
    > 181:
    > 182:             // Track app launch time even if initialization fails
    > 183:             let launchDuration = Date().timeIntervalSince(appLaunchStartTime)
    > 184:             await performanceMonitor.recordAppLaunchTime(launchDuration)
    > 185:
    > 186:             // Record the error in performance monitor
    > 187:             await performanceMonitor.recordError(error, context: "App initialization")
    > 188:
    > 189:             // You could show an alert to the user here if needed
    > 190:             // For now, we'll just log the error and continue with limited functionality
  - Fonic HiFi/Presentation/Views/Home/HomeView.swift:196-235
    > 196:         do {
    > 197:             // Fresh library data
    > 198:             recentlyAdded = try await dataManager.getRecentlyAddedTracks(limit: 10)
    > 199:             artists = try await dataManager.getAllArtists(limit: 15)
    > 200:             genres = try await dataManager.getUniqueGenres()
    > 201:             albums = try await dataManager.getAllAlbums(limit: 10)
    > 202:
    > 203:             // Active library data
    > 204:             recentlyPlayed = try await dataManager.getRecentlyPlayedTracks(limit: 10)
    > 205:             mostListened = try await dataManager.getMostListenedTracks(limit: 10)
    > 206:             favoriteAlbums = try await dataManager.getFavoriteAlbums(limit: 10)
    > 207:
    > 208:             // Pre-cache visible album artwork colors for smoother overlay theming work.
    > 209:             let albumsToPrewarm = Array((albums + favoriteAlbums).prefix(12))
    > 210:             Task(priority: .utility) {
    > 211:                 await DominantColorService.shared.prewarmColorCache(for: albumsToPrewarm)
    > 212:             }
    > 213:
    > 214:             // History-based sections
    > 215:             continueListening = try await dataManager.getContinueListeningTracks(limit: 3)
    > 216:             rediscoverTracks = try await dataManager.getRediscoverTracks(limit: 10)
    > 217:
    > 218:             // Generate AI greeting if we have history
    > 219:             if !recentlyPlayed.isEmpty {
    > 220:                 let sessions = try await dataManager.trackDataActor.getListeningSessions(limit: 50)
    > 221:                 let trackIDs = try await dataManager.trackDataActor.getAllTrackIDs(limit: 200)
    > 222:
    > 223:                 let greeting = await recommendationService.generateTimeBasedGreeting(
    > 224:                     sessions: sessions,
    > 225:                     availableTrackIDs: trackIDs,
    > 226:                     genres: genres
    > 227:                 )
    > 228:                 timeBasedGreeting = greeting
    > 229:
    > 230:                 // Load the actual tracks for the greeting using mainContext
    > 231:                 greetingTracks = try dataManager.fetchTracks(by: greeting.trackIDs)
    > 232:             }
    > 233:         } catch {
    > 234:             // Silently handle errors - home screen shows empty state gracefully
    > 235:         }
  - Fonic HiFi/Presentation/Views/Search/SearchView.swift:129-151
    > 129:         do {
    > 130:             let results = try await searchAllContent(query, dataManager: dataManager)
    > 131:
    > 132:             // Update UI on main actor
    > 133:             await MainActor.run {
    > 134:                 searchResults = results
    > 135:                 isSearching = false
    > 136:
    > 137:                 // Add to recent searches and update count
    > 138:                 Task {
    > 139:                     try? await dataManager.addRecentSearch(query)
    > 140:                     try? await dataManager.updateSearchResultCount(
    > 141:                         query: query,
    > 142:                         count: results.totalCount,
    > 143:                     )
    > 144:                 }
    > 145:             }
    > 146:         } catch {
    > 147:             logger.error("Search failed: \(error.localizedDescription, privacy: .public)")
    > 148:             await MainActor.run {
    > 149:                 searchResults = SearchResults()
    > 150:                 isSearching = false
    > 151:             }
  - Fonic HiFi/Presentation/ViewModels/SmartSearchViewModel.swift:90-94
    > 90:         } catch {
    > 91:             logger.error("Smart search failed: \(error.localizedDescription)")
    > 92:             searchState = .error(error.localizedDescription)
    > 93:             smartSearchResult = nil
    > 94:             resultTrackIDs = []
  - Fonic HiFi/Presentation/Views/Settings/FileManagerView.swift:195-233
    > 195:     private func loadDirectoryContents() async {
    > 196:         isLoading = true
    > 197:         defer { isLoading = false }
    > 198:
    > 199:         do {
    > 200:             let contents = try FileManager.default.contentsOfDirectory(at: currentDirectory, includingPropertiesForKeys: [
    > 201:                 .contentModificationDateKey,
    > 202:                 .fileSizeKey,
    > 203:                 .isDirectoryKey,
    > 204:             ])
    > 205:
    > 206:             var items: [FileItem] = []
    > 207:
    > 208:             for url in contents {
    > 209:                 let resourceValues = try url.resourceValues(forKeys: [
    > 210:                     .contentModificationDateKey,
    > 211:                     .fileSizeKey,
    > 212:                     .isDirectoryKey,
    > 213:                 ])
    > 214:
    > 215:                 let item = FileItem(
    > 216:                     id: url.absoluteString,
    > 217:                     name: url.lastPathComponent,
    > 218:                     url: url,
    > 219:                     isDirectory: resourceValues.isDirectory ?? false,
    > 220:                     size: Int64(resourceValues.fileSize ?? 0),
    > 221:                     dateModified: resourceValues.contentModificationDate ?? Date(),
    > 222:                 )
    > 223:
    > 224:                 items.append(item)
    > 225:             }
    > 226:
    > 227:             await MainActor.run {
    > 228:                 directoryContents = items
    > 229:             }
    > 230:
    > 231:         } catch {
    > 232:             logger.error("Failed to load directory contents for \(currentDirectory.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
    > 233:         }
- External sources:
  - https://developer.apple.com/documentation/swiftui/contentunavailableview
- Limitations:
  - No injected UI failure test verified the exact visible states at runtime.

### WP3-020 - Import progress is unobserved and presentation depends on a race

- Final severity: High
- Confidence: High
- Verification status: CONFIRMED OBSERVATION AND OWNERSHIP DEFECT; presentation failure UNVERIFIED
- Source report records:
  - UIUX-010: High -> High; retained
- Reachability and impact: LibraryImportService is a Combine ObservableObject with published progress, counts, status, and errors. Library, picker, and progress views retrieve it through a plain custom EnvironmentValue without an observed-object subscription. FileImportView starts import and immediately dismisses; the service sets isImporting in another Task; the parent tries to present progress from onChange of that unobserved property. Long imports can proceed with absent or frozen progress and no reliable cancel UI.
- Guards and mitigating controls: The import continues independently and the service prevents a second import. A progress view exists and can cancel if it happens to present and redraw. Picker errors are logged only. These controls do not establish deterministic presentation or observation.
- Severity rationale: Retain High because import is the app's library-ingestion path and users can lose visibility and cancellation control during long, storage-mutating work.
- Evidence:
  - Fonic HiFi/Data/Services/LibraryImportService.swift:15-35,72-100
    > 15: @MainActor
    > 16: public final class LibraryImportService: ObservableObject {
    > 17:     // MARK: - Published Properties
    > 18:
    > 19:     /// Current import progress (0.0 to 1.0)
    > 20:     @Published public private(set) var importProgress: Double = 0.0
    > 21:
    > 22:     /// Whether an import is currently in progress
    > 23:     @Published public private(set) var isImporting: Bool = false
    > 24:
    > 25:     /// Current status message
    > 26:     @Published public private(set) var statusMessage: String = ""
    > 27:
    > 28:     /// Number of files processed
    > 29:     @Published public private(set) var filesProcessed: Int = 0
    > 30:
    > 31:     /// Total number of files to process
    > 32:     @Published public private(set) var totalFiles: Int = 0
    > 33:
    > 34:     /// Import errors encountered
    > 35:     @Published public private(set) var importErrors: [ImportError] = []
    > 72:     /// Import files from selected URLs (handles security-scoped resources)
    > 73:     public func importFiles(from urls: [URL]) {
    > 74:         Task { @MainActor [weak self] in
    > 75:             guard let self else { return }
    > 76:
    > 77:             guard !isImporting else {
    > 78:                 logger.warning("Import already in progress")
    > 79:                 return
    > 80:             }
    > 81:
    > 82:             importProgress = 0.0
    > 83:             filesProcessed = 0
    > 84:             totalFiles = 0
    > 85:             importErrors.removeAll()
    > 86:             recentlyImported.removeAll()
    > 87:             isImporting = true
    > 88:             statusMessage = "Scanning for audio files..."
    > 89:
    > 90:             let task = Task(priority: .userInitiated) { @MainActor [weak self] in
    > 91:                 guard let self else { return }
    > 92:                 logger.info("Starting import of \(urls.count) URLs")
    > 93:                 Metrics.increment(.importsDiscovered, by: urls.count, metadata: [
    > 94:                     "phase": "requested"
    > 95:                 ])
    > 96:                 await executeImportPipeline(urls: urls)
    > 97:             }
    > 98:
    > 99:             importTask?.cancel()
    > 100:             importTask = task
  - Fonic HiFi/Presentation/Views/Import/FileImportView.swift:43-48,63-69
    > 43:                     Button("Import") {
    > 44:                         guard let importService else { return }
    > 45:                         Task {
    > 46:                             importService.importFiles(from: selectedURLs)
    > 47:                             dismiss()
    > 48:                         }
    > 63:     private func handleFileSelection(_ result: Result<[URL], Error>) {
    > 64:         switch result {
    > 65:         case let .success(urls):
    > 66:             selectedURLs.append(contentsOf: urls)
    > 67:         case let .failure(error):
    > 68:             logger.error("File selection failed: \(error.localizedDescription, privacy: .public)")
    > 69:         }
  - Fonic HiFi/Presentation/Views/Import/ImportProgressView.swift:11-35,41-68
    > 11: struct ImportProgressView: View {
    > 12:     @Environment(\.importService) private var importService
    > 13:     @Environment(\.dismiss) private var dismiss
    > 14:
    > 15:     var body: some View {
    > 16:         NavigationStack {
    > 17:             VStack(spacing: 30) {
    > 18:                 // Progress indicator
    > 19:                 ProgressSection(
    > 20:                     progress: importService?.importProgress ?? 0.0,
    > 21:                     filesProcessed: importService?.filesProcessed ?? 0,
    > 22:                     totalFiles: importService?.totalFiles ?? 0,
    > 23:                 )
    > 24:
    > 25:                 // Status message
    > 26:                 Text(importService?.statusMessage ?? "No import service available")
    > 27:                     .font(.subheadline)
    > 28:                     .foregroundColor(.secondary)
    > 29:                     .multilineTextAlignment(.center)
    > 30:                     .padding(.horizontal)
    > 31:
    > 32:                 // Error summary if any
    > 33:                 if !(importService?.importErrors.isEmpty ?? true) {
    > 34:                     ErrorSummaryView(errors: importService?.importErrors ?? [])
    > 35:                 }
    > 41:                     if importService?.isImporting == true {
    > 42:                         Button("Cancel Import") {
    > 43:                             importService?.cancelImport()
    > 44:                         }
    > 45:                         .buttonStyle(.bordered)
    > 46:                         .controlSize(.large)
    > 47:                     } else {
    > 48:                         Button("Done") {
    > 49:                             dismiss()
    > 50:                         }
    > 51:                         .buttonStyle(.borderedProminent)
    > 52:                         .controlSize(.large)
    > 53:                     }
    > 54:                 }
    > 55:                 .padding(.horizontal)
    > 56:             }
    > 57:             .padding(.vertical)
    > 58:             .navigationTitle("Importing Music")
    > 59:             .navigationBarTitleDisplayMode(.inline)
    > 60:             .toolbar {
    > 61:                 if importService?.isImporting != true {
    > 62:                     ToolbarItem(placement: .primaryAction) {
    > 63:                         Button("Done") {
    > 64:                             dismiss()
    > 65:                         }
    > 66:                     }
    > 67:                 }
    > 68:             }
  - Fonic HiFi/Presentation/Views/Library/LibraryView.swift:48,102-117,156-160
    > 48:     @Environment(\.importService) private var importService
    > 102:         .sheet(isPresented: $showingImportView) {
    > 103:             if let importService {
    > 104:                 FileImportView()
    > 105:                     .importService(importService)
    > 106:             } else {
    > 107:                 RecoveryUnavailableView(
    > 108:                     launchError: LaunchError(message: "Import service unavailable."),
    > 109:                     fallbackError: nil
    > 110:                 )
    > 111:             }
    > 112:         }
    > 113:         .sheet(isPresented: $showingImportProgress) {
    > 114:             if let importService {
    > 115:                 ImportProgressView()
    > 116:                     .importService(importService)
    > 117:                     .interactiveDismissDisabled(importService.isImporting)
    > 156:         .onChange(of: importService?.isImporting) { _, isImporting in
    > 157:             if isImporting == true {
    > 158:                 showingImportView = false
    > 159:                 showingImportProgress = true
    > 160:             }
- External sources:
  - https://developer.apple.com/documentation/swiftui/model-data
  - https://developer.apple.com/design/human-interface-guidelines/progress-indicators
- Limitations:
  - No document-picker, large-folder, denied-access, or cloud-provider UI run was available.

### WP3-021 - Core library and mini-player actions are raw gestures rather than semantic controls

- Final severity: High
- Confidence: High
- Verification status: PROBABLE ACCESSIBILITY BLOCKER; runtime accessibility tree UNVERIFIED
- Source report records:
  - A11Y-001: High -> High; retained
- Reachability and impact: Track play, album open, artist open, playlist open, and mini-player open actions are attached with onTapGesture. The track row's only native Button is its Info control. Raw gestures do not provide the native button or navigation semantics required for dependable VoiceOver activation, Full Keyboard Access, Voice Control naming, or Switch Control scanning.
- Guards and mitigating controls: Visible text and images may still appear in the accessibility tree, and the trailing Info and transport controls are native Buttons. That does not supply a guaranteed semantic primary action for the enclosing composite row or mini-player surface.
- Severity rationale: Retain High because primary library navigation and playback initiation are common product paths and may be unavailable to multiple assistive technologies, not merely missing labels.
- Evidence:
  - Fonic HiFi/Presentation/Views/Library/LibraryView.swift:195-204,231-235,252-257,272-277
    > 195:     private var tracksSection: some View {
    > 196:         List {
    > 197:             ForEach(Array(viewModel.tracks.enumerated()), id: \.element.id) { index, track in
    > 198:                 TrackEntityRow(track: track) {
    > 199:                     selectedTrack = track
    > 200:                 }
    > 201:                 .contentShape(Rectangle())
    > 202:                 .onTapGesture {
    > 203:                     playTrack(track)
    > 204:                 }
    > 231:                 ForEach(Array(viewModel.albums.enumerated()), id: \.element.id) { index, album in
    > 232:                     AlbumEntityTile(album: album)
    > 233:                         .onTapGesture {
    > 234:                             selectedAlbum = album
    > 235:                         }
    > 252:             ForEach(Array(viewModel.artists.enumerated()), id: \.element.id) { index, artist in
    > 253:                 ArtistEntityRow(artist: artist)
    > 254:                     .contentShape(Rectangle())
    > 255:                     .onTapGesture {
    > 256:                         selectedArtist = artist
    > 257:                     }
    > 272:             ForEach(Array(viewModel.playlists.enumerated()), id: \.element.id) { index, playlist in
    > 273:                 PlaylistEntityRow(playlist: playlist)
    > 274:                     .contentShape(Rectangle())
    > 275:                     .onTapGesture {
    > 276:                         selectedPlaylist = playlist
    > 277:                     }
  - Fonic HiFi/Presentation/Views/Library/LibraryView.swift:378-417
    > 378: private struct TrackEntityRow: View {
    > 379:     let track: TrackEntity
    > 380:     let onInfoTapped: () -> Void
    > 381:
    > 382:     var body: some View {
    > 383:         HStack(spacing: 12) {
    > 384:             LazyArtworkView(trackId: track.id, size: 56, cornerRadius: 8)
    > 385:
    > 386:             VStack(alignment: .leading, spacing: 6) {
    > 387:                 Text(track.title)
    > 388:                     .font(.headline)
    > 389:                     .lineLimit(2)
    > 390:
    > 391:                 Text("\(track.artist) • \(track.album)")
    > 392:                     .font(.subheadline)
    > 393:                     .foregroundStyle(.secondary)
    > 394:                     .lineLimit(1)
    > 395:
    > 396:                 HStack(spacing: 12) {
    > 397:                     Label(track.qualityDescription, systemImage: "waveform")
    > 398:                     Label(track.formattedDuration, systemImage: "clock")
    > 399:                     Label(track.formattedFileSize, systemImage: "internaldrive")
    > 400:                 }
    > 401:                 .font(.caption)
    > 402:                 .foregroundStyle(.secondary)
    > 403:             }
    > 404:
    > 405:             Spacer()
    > 406:
    > 407:             Button {
    > 408:                 onInfoTapped()
    > 409:             } label: {
    > 410:                 Image(systemName: "info.circle")
    > 411:                     .font(.title3)
    > 412:                     .foregroundStyle(.secondary)
    > 413:             }
    > 414:             .buttonStyle(.plain)
    > 415:         }
    > 416:         .padding(.vertical, 6)
    > 417:     }
  - Fonic HiFi/ContentView.swift:58-67
    > 58:         .tabViewBottomAccessory {
    > 59:             if let audioService {
    > 60:                 LiquidGlassMiniPlayer(namespace: miniPlayerNamespace)
    > 61:                     .environment(\.audioEngine, audioService)
    > 62:                     .matchedTransitionSource(id: "miniplayer", in: miniPlayerNamespace)
    > 63:                     .onTapGesture {
    > 64:                         showingNowPlaying = true
    > 65:                         let generator = UIImpactFeedbackGenerator(style: .medium)
    > 66:                         generator.impactOccurred(intensity: 0.9)
    > 67:                     }
- External sources:
  - https://developer.apple.com/documentation/swiftui/view-accessibility
- Limitations:
  - Accessibility Inspector, VoiceOver, Switch Control, Voice Control, and Full Keyboard Access were not available.

### WP3-022 - The 10-band EQ is drag-only with no adjustable accessibility semantics

- Final severity: High
- Confidence: High
- Verification status: PROBABLE FEATURE BLOCKER; runtime accessibility tree UNVERIFIED
- Source report records:
  - A11Y-002: High -> High; retained
- Reachability and impact: Every EQ band uses a custom 30-point-wide drawing with DragGesture. No accessibility label/value, adjustable action, focusability, keyboard action, or native Slider is attached to the control. A VoiceOver, keyboard, or Switch Control user has no semantic way to discover the frequency or change gain.
- Guards and mitigating controls: Frequency and gain appear as visually adjacent Text and touch drag updates persistence. Adjacent text does not make the custom gesture an adjustable control, and disabled state does not add semantics.
- Severity rationale: Retain High because the entire EQ feature is blocked for multiple assistive technologies and the control is also below the 44-point touch recommendation.
- Evidence:
  - Fonic HiFi/Presentation/Views/Settings/EqualizerView.swift:90-118
    > 90:                     // Band sliders
    > 91:                     HStack(alignment: .center, spacing: 4) {
    > 92:                         ForEach(0..<10, id: \.self) { index in
    > 93:                             VStack(spacing: 4) {
    > 94:                                 // Vertical slider
    > 95:                                 VerticalSlider(
    > 96:                                     value: $configuration.bands[index].gain,
    > 97:                                     range: -12...12
    > 98:                                 )
    > 99:                                 .frame(height: 140)
    > 100:                                 .disabled(!configuration.isEnabled)
    > 101:                                 .onChange(of: configuration.bands[index].gain) { _, _ in
    > 102:                                     selectedPreset = "Custom"
    > 103:                                     applyConfiguration()
    > 104:                                 }
    > 105:
    > 106:                                 // Frequency label
    > 107:                                 Text(frequencyLabels[index])
    > 108:                                     .font(.caption2)
    > 109:                                     .foregroundStyle(.secondary)
    > 110:
    > 111:                                 // Gain value
    > 112:                                 Text(String(format: "%.1f", configuration.bands[index].gain))
    > 113:                                     .font(.system(size: 9, weight: .medium, design: .monospaced))
    > 114:                                     .foregroundStyle(gainColor(for: configuration.bands[index].gain))
    > 115:                             }
    > 116:                         }
    > 117:                     }
    > 118:                     .padding(.horizontal, 4)
  - Fonic HiFi/Presentation/Views/Settings/EqualizerView.swift:169-220
    > 169: private struct VerticalSlider: View {
    > 170:     @Binding var value: Float
    > 171:     let range: ClosedRange<Float>
    > 172:
    > 173:     var body: some View {
    > 174:         GeometryReader { geometry in
    > 175:             let height = geometry.size.height
    > 176:             let normalizedValue = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
    > 177:             let yPosition = height * (1 - normalizedValue)
    > 178:
    > 179:             ZStack {
    > 180:                 // Track background
    > 181:                 Capsule()
    > 182:                     .fill(Color(.systemGray5))
    > 183:                     .frame(width: 4)
    > 184:
    > 185:                 // Center line (0 dB)
    > 186:                 Rectangle()
    > 187:                     .fill(Color(.systemGray3))
    > 188:                     .frame(width: 12, height: 1)
    > 189:                     .offset(y: (height / 2) - (height * normalizedValue))
    > 190:
    > 191:                 // Active fill
    > 192:                 Capsule()
    > 193:                     .fill(value >= 0 ? Color.orange : Color.blue)
    > 194:                     .frame(width: 4, height: abs(CGFloat(value) / 12) * (height / 2))
    > 195:                     .offset(y: value >= 0 ? -(abs(CGFloat(value) / 12) * (height / 4)) : (abs(CGFloat(value) / 12) * (height / 4)))
    > 196:
    > 197:                 // Thumb
    > 198:                 Circle()
    > 199:                     .fill(Color.white)
    > 200:                     .frame(width: 20, height: 20)
    > 201:                     .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    > 202:                     .offset(y: yPosition - (height / 2))
    > 203:             }
    > 204:             .gesture(
    > 205:                 DragGesture(minimumDistance: 0)
    > 206:                     .onChanged { gesture in
    > 207:                         let newY = gesture.location.y
    > 208:                         let normalizedY = 1 - (newY / height)
    > 209:                         let clampedY = max(0, min(1, normalizedY))
    > 210:                         let newValue = range.lowerBound + Float(clampedY) * (range.upperBound - range.lowerBound)
    > 211:                         // Snap to 0 if close
    > 212:                         if abs(newValue) < 0.5 {
    > 213:                             value = 0
    > 214:                         } else {
    > 215:                             value = round(newValue * 2) / 2 // Round to 0.5
    > 216:                         }
    > 217:                     }
    > 218:             )
    > 219:         }
    > 220:         .frame(width: 30)
- External sources:
  - https://developer.apple.com/documentation/swiftui/view-accessibility
- Limitations:
  - No Accessibility Inspector, VoiceOver rotor, keyboard, or Switch Control test was available.

### WP3-023 - Release-reachable logs explicitly mark library content and paths public

- Final severity: Medium
- Confidence: High
- Verification status: CONFIRMED STATIC PUBLIC INTERPOLATION; actual log retention and sharing UNVERIFIED
- Source report records:
  - PSR-004: High -> Medium; downgraded
- Reachability and impact: Active playback, import, format detection, widget-cache, file-manager, and error paths explicitly mark track titles, filenames, full paths, route names, identifiers, and error descriptions public in OSLog interpolation. A deterministic scan counted 125 public interpolations across 28 app Swift files. The cited paths are not generally debug-only.
- Guards and mitigating controls: Some entries are debug level, metrics are disabled by default, and there is no demonstrated remote log uploader. Other cited info and error calls remain release reachable. Access generally requires local diagnostics, support collection, or an exported log archive.
- Severity rationale: Downgrade to Medium because privacy classification is wrong and content can enter unified logs, but no remote collection, attacker-accessible sink, or actual exported archive was established.
- Evidence:
  - Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:331-334
    > 331:     public func play(track: Track) async throws {
    > 332:         assertMainThread()
    > 333:         guard isReady else { throw AudioError.engineInitializationFailed(reason: "Engine not ready") }
    > 334:         logger.info("Playing track: \(track.title, privacy: .public)")
  - Fonic HiFi/Shared/WidgetArtworkCache.swift:39-47
    > 39:         do {
    > 40:             try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    > 41:             cacheURL = url
    > 42:             logger.info("Widget artwork cache initialized at: \(url.path, privacy: .public)")
    > 43:
    > 44:             // Load access dates from disk
    > 45:             loadAccessDates()
    > 46:         } catch {
    > 47:             logger.error("Failed to create artwork cache directory: \(error.localizedDescription)")
  - Fonic HiFi/Data/Actors/FileImportProcessor.swift:367-400
    > 367:         if hashCache.contains(urlHash: urlHash, bookmarkHash: bookmarkHash, urlString: urlString) {
    > 368:             logger.notice("Duplicate import skipped (cache hit): \(file.originalURL.lastPathComponent, privacy: .public)")
    > 369:             return ProcessedFileResult(
    > 370:                 file: file,
    > 371:                 identifier: nil,
    > 372:                 error: ProcessedFileError(message: "Duplicate file already exists"),
    > 373:                 duration: Date().timeIntervalSince(taskStart)
    > 374:             )
    > 375:         }
    > 376:
    > 377:         do {
    > 378:             let identifier = try await Self.importFile(
    > 379:                 file,
    > 380:                 baseDirectory: baseDirectory,
    > 381:                 metadataExtractor: metadataExtractor,
    > 382:                 trackDataActor: trackDataActor,
    > 383:                 securityAccessor: securityAccessor,
    > 384:                 logger: logger
    > 385:             )
    > 386:             let duration = Date().timeIntervalSince(taskStart)
    > 387:             return ProcessedFileResult(
    > 388:                 file: file,
    > 389:                 identifier: identifier,
    > 390:                 error: nil,
    > 391:                 duration: duration
    > 392:             )
    > 393:         } catch {
    > 394:             let duration = Date().timeIntervalSince(taskStart)
    > 395:             let filename = file.originalURL.lastPathComponent
    > 396:             let errorDescription = error.localizedDescription
    > 397:             logger.error(
    > 398:                 """
    > 399:                 File import failed for \(filename, privacy: .public):
    > 400:                 \(errorDescription, privacy: .public)
  - Fonic HiFi/Core/Audio/Services/FormatDetectionCoordinator.swift:41-45,79-103
    > 41:         logger.debug(
    > 42:             """
    > 43:             detection.start id=\(identifier, privacy: .public) \
    > 44:             url=\(fileName, privacy: .public) \
    > 45:             wait_ms=\(milliseconds(waitDuration), privacy: .public)
    > 79:             logger.debug(
    > 80:                 """
    > 81:                 detection.success id=\(identifier, privacy: .public) \
    > 82:                 url=\(fileName, privacy: .public) \
    > 83:                 duration_ms=\(milliseconds(detectionDuration), privacy: .public)
    > 84:                 """
    > 85:             )
    > 86:             return result
    > 87:         } catch is CancellationError {
    > 88:             logger.info(
    > 89:                 "detection.cancelled id=\(context.identifier.uuidString, privacy: .public) url=\(context.url.lastPathComponent, privacy: .public)"
    > 90:             )
    > 91:             throw CancellationError()
    > 92:         } catch CoordinatorError.timeout {
    > 93:             logger.error(
    > 94:                 "detection.timeout id=\(context.identifier.uuidString, privacy: .public) url=\(context.url.lastPathComponent, privacy: .public)"
    > 95:             )
    > 96:             throw DetectionError.timeout
    > 97:         } catch {
    > 98:             logger.error(
    > 99:                 """
    > 100:                 detection.failure id=\(identifier, privacy: .public) \
    > 101:                 url=\(fileName, privacy: .public) \
    > 102:                 error=\(error.localizedDescription, privacy: .public)
    > 103:                 """
- Limitations:
  - No Release-device Console capture or exported log archive was available.

## Final severity set

### High canonical root causes

- WP3-001: Publicly committed developer-tool credentials
- WP3-002: App and widget omit first-party Required Reason API manifests
- WP3-003: CI selects an iOS 18-era Xcode for an iOS 26 project
- WP3-004: Concurrent play requests can commit stale engine and UI state
- WP3-005: Native engine deactivates a different audio-session owner during load
- WP3-006: Interruption intent and headphone-disconnect privacy are not preserved
- WP3-007: Read-only in-memory container can be mislabeled as the normal persistent store
- WP3-011: Import failures after copy leave orphaned managed audio files
- WP3-016: Combine audio facade is injected through an unobserved custom environment value
- WP3-019: Core failures are logged but shown as normal emptiness or silence
- WP3-020: Import progress is unobserved and presentation depends on a race
- WP3-021: Core library and mini-player actions are raw gestures rather than semantic controls
- WP3-022: The 10-band EQ is drag-only with no adjustable accessibility semantics

### Medium canonical root causes

- WP3-008: ListeningSession is missing from the active SwiftData schema
- WP3-009: The migration plan is attempted only after an unplanned store open
- WP3-010: Listening-session tracking is implemented but never configured
- WP3-012: Startup cleanup deletes metadata after a single missing-file observation
- WP3-013: Import cancellation is not propagated to AsyncStream producers
- WP3-014: Queue mutation persists the full queue synchronously on MainActor
- WP3-015: Concurrent import deduplication is not an atomic claim
- WP3-017: Now Playing mirrors shuffle, repeat, and speed outside authoritative owners
- WP3-018: Visible settings include inert controls and log-only actions
- WP3-023: Release-reachable logs explicitly mark library content and paths public

## Verification boundary

The static root causes above are evidence-backed at the pinned commit. Any item whose status or limitation says runtime, build, device, archive, credential, or App Store behavior is unverified must not be represented as tested. No repository source file was modified.
