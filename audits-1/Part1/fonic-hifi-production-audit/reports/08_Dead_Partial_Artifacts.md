# 08 — Dead Code, Completeness, and Repository Artifacts Audit

**Snapshot audited:** `main` at `459db9bfd18d17960e8fd2ff8defc4701085532e`
**Audit date:** 2026-07-09
**Repository boundary:** `/agent/workspace/fonic-hifi-audit` was treated as immutable and remained clean. All generated output is under `/agent/workspace/fonic-hifi-audit-work/subagents`.
**Tooling boundary:** static inspection only. This Linux environment has no Xcode or Apple SDK, so no compilation, linker dead-stripping, simulator, preview, widget, App Intent, or device result is claimed.
**Skills loaded:** Axiom: iOS Audit Agents (38); Axiom: Testing.

## Conclusion

The snapshot contains substantial stale production surface and several incomplete integrations. Eighteen complete source files have no production consumer; they total **3,642 physical lines across an exact, hashed file list** (8.03% of the 45,374 product-Swift physical lines). Manual source review split them into eight test-only implementation files, seven preview/self-only prototype files, and three files with no external consumer. In still-live files, **61 scanner roots** were retained as unreferenced: 50 methods with no product or test call, six declarations with no product or test use, and five private helpers. Dependent helper types inside those roots were not separately counted, and no symbol-level line total is claimed.

Three material completeness defects remain: listening-session tracking is fully implemented but never configured; persisted EQ is never restored or reapplied when an engine is created/recreated; and AudioKit diagnostics report fixed zero values while a monitor repeatedly invokes an empty collector. QueueCoordinator also exposes three inert methods, and the smart-search track action only logs instead of playing.

Repository hygiene is also incomplete: 14 tracked machine/generated/backup artifacts occupy 156,761 bytes and 3,306 physical lines; three undocumented sample app fragments contain 18 files (nine Swift files, 775 Swift lines) but no project container; and three app/widget shared-data contracts (constants plus two Codable models) are maintained as manual source copies. The 63-file archive is explicitly labeled historical and was not treated as proof of a product defect.

### Retained finding counts

| Severity | Count |
|---|---:|
| Critical | 0 |
| High | 0 |
| Medium | 3 |
| Low | 6 |
| Informational | 1 |
| **Total** | **10** |

| Confidence | Count |
|---|---:|
| Confirmed by static evidence | 10 |
| Probable | 0 |
| UNVERIFIED — needs build/device check | 0 retained findings; required runtime checks are separated below |

## Reproducible inventories

The inventory scripts use `git ls-files` at the audited commit and count physical lines with `read_bytes().splitlines()`. The scripts and generated manifests are outside the repository:

- `dead_audit_inventory.py`
- `dead_manual_verify.py`
- `dead_candidate_dispositions.py`
- `08_dead_inventory.json`
- `08_dead_manual_verification.json`
- `08_dead_candidate_dispositions.json`

They were rerun after manual review; `git status --short` remained empty.

| Inventory | Files | Physical lines | Bytes | Exact list / SHA-256 |
|---|---:|---:|---:|---|
| Product Swift (app + widget) | 213 | 45,374 | 1,471,403 | `08_product_swift_files.txt` / `b236b772d62cee922d10552b393cdd59abbdb2ca87ba0edfad1b11eb84978c32` |
| Test Swift | 95 | 13,460 | 476,526 | `08_test_swift_files.txt` / `71334f4da7ceb4ebde93868ec27bbef2104a06abbfbc2a284c2486082fd47815` |
| Active Swift total | 308 | 58,834 | 1,947,929 | `08_active_swift_files.txt` / `e14ffde051508ec18471d2fc3d568224efb466c7e91bbbe859af87594f75f522` |
| Production-unreachable whole source files | 18 | **3,642** | 115,118 | `08_confirmed_orphan_source_files.txt` / `21246b4b87cb5be1f4de437cf4562a739bb5119e0081fa5593b5914271649892` |
| Sample tree | 49 | — | 156,189 | `08_sample_files.txt` / `5ffef3e93e308c65501f4b6c4af524d10567091c45283c1dda0a7de09b9b36c6` |
| Sample Swift subset | 17 | 1,428 | 45,123 | `08_sample_swift_files.txt` / `a4f0663edf90071ff711e35235d4623f9e9644ffdef395139ad2d8ff6d5a5352` |
| Explicit archive documentation | 63 | 21,980 | 798,582 | `08_archived_doc_files.txt` / `953605be26c9934f9e96b7c3fc33fc8b75ad2107f1f1cd9b4e5f607a2e46dedd` |
| Machine/generated/backup hygiene candidates | 14 | 3,306 | 156,761 | `08_hygiene_candidate_files.txt` / `a5a1377733ff574301f3d900f34bc058ce0d4571e48b2bd9c2f8f320a1deaa1b` |

**Dead-line accounting rule:** only the 18-path `08_confirmed_orphan_source_files.txt` manifest is used for the **3,642** production-unreachable line figure. No line count is inferred from token counts, declaration counts, or symbol ranges. Sample, archive, and machine-artifact lines are reported as separate inventories and are not added to dead production lines.

### Manually reverified whole-file inventory

Every file below was read in full. Product references, test references, previews, enclosing declarations, protocol/framework roles, and likely dynamic entry points were checked. “Preview/self-only” means a SwiftUI preview is a valid development entry point, but no app runtime path consumes the implementation.

| Repository-relative file | Exact range | Lines | Manual production disposition |
|---|---:|---:|---|
| `Fonic HiFi/Core/Audio/Cache/TrackCache.swift` | 1-216 | 216 | Used by tests only; production uses other persistence/cache paths. |
| `Fonic HiFi/Core/Audio/Diagnostics/PlaybackDiagnostics/PlaybackDiagnosticFormatters.swift` | 1-100 | 100 | Used by diagnostics tests only. |
| `Fonic HiFi/Core/Audio/Playback/PlaybackStateStore.swift` | 1-261 | 261 | Used by tests only; facade directly owns `PlaybackStateManager`. |
| `Fonic HiFi/Core/Services/AudioSettingsService.swift` | 1-41 | 41 | Used by tests only; views/facade write `AudioPlaybackSettingsStore` directly. |
| `Fonic HiFi/Data/DataManager+SmartSearch.swift` | 1-18 | 18 | No external consumer; Smart Search queries the actor directly. |
| `Fonic HiFi/Data/Services/ImportSession.swift` | 1-490 | 490 | Used by tests only; production uses `LibraryImportService`. |
| `Fonic HiFi/Data/Services/SearchCache.swift` | 1-311 | 311 | Used by tests only; active search has no cache integration. |
| `Fonic HiFi/Presentation/ViewModels/Library/LibraryFilter.swift` | 1-36 | 36 | Used by tests only; active repository/view-model filtering is separate. |
| `Fonic HiFi/Presentation/Views/Components/AccessibilityEnhancements.swift` | 1-458 | 458 | Preview/self-only prototype; its custom actions include inert bodies. |
| `Fonic HiFi/Presentation/Views/Components/BottomSearchBar.swift` | 1-197 | 197 | Preview/self-only prototype. |
| `Fonic HiFi/Presentation/Views/Components/ErrorView.swift` | 1-332 | 332 | Preview/self-only; the alert helper is only self-referenced. |
| `Fonic HiFi/Presentation/Views/Components/GlassControls.swift` | 1-128 | 128 | No external consumer. |
| `Fonic HiFi/Presentation/Views/Components/LiquidGlassRail.swift` | 1-316 | 316 | Preview/self-only prototype. |
| `Fonic HiFi/Presentation/Views/Components/LiquidGlassTabBar.swift` | 1-166 | 166 | Preview/self-only; the app uses native iOS 26 tab APIs. |
| `Fonic HiFi/Presentation/Views/Library/AlbumGridView.swift` | 1-294 | 294 | Preview/self-only alternate library layer. |
| `Fonic HiFi/Presentation/Views/NowPlaying/DiagnosticsDetailView.swift` | 1-153 | 153 | Preview/self-only; no diagnostics navigation presents it. |
| `Fonic HiFi/Presentation/Views/Search/SearchPlaylistResultsView.swift` | 1-85 | 85 | No external consumer. |
| `Fonic HiFi/Utils/MainActorHelpers.swift` | 1-40 | 40 | Used by tests only; production uses a separate facade-local assertion. |
| **Total** |  | **3,642** |  |

## Findings summary

| ID | Severity | Confidence | Summary |
|---|---|---|---|
| DCA-DEAD-001 | Low | Confirmed by static evidence | Eighteen target-included files have no production consumer (3,642 physical lines). |
| DCA-DEAD-002 | Low | Confirmed by static evidence | Live files contain 61 manually retained unreferenced symbol roots. |
| DCA-PART-001 | Medium | Confirmed by static evidence | Listening-session tracking is implemented but never configured. |
| DCA-PART-002 | Medium | Confirmed by static evidence | Persisted EQ is neither restored at startup nor reapplied after engine creation/switch. |
| DCA-PART-003 | Low | Confirmed by static evidence | QueueCoordinator exposes three inert persistence/removal methods beside working manager APIs. |
| DCA-PART-004 | Low | Confirmed by static evidence | Smart-search result taps only log and never invoke playback. |
| DCA-PART-005 | Medium | Confirmed by static evidence | AudioKit diagnostics return fixed zero metrics while an empty collector is polled. |
| DCA-ART-001 | Low | Confirmed by static evidence | Fourteen machine/generated/backup artifacts are tracked despite ignore intent. |
| DCA-SAMPLE-001 | Low | Confirmed by static evidence | Three undocumented sample app fragments have `@main` sources but no build container. |
| DCA-DUP-001 | Informational | Confirmed by static evidence | Three app/widget shared-data contracts are manually duplicated; they are aligned now but can drift. |

---

## Full findings

### DCA-DEAD-001 — Eighteen target-included files have no production consumer

- **Severity:** Low
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi.xcodeproj/project.pbxproj:62-67,79-85,169-185`
    > `membershipExceptions = (`
    > `Info.plist,`
    > `fileSystemSynchronizedGroups = (`
    > `38D04CDF... /* Fonic HiFi */`
  - `Fonic HiFi/Core/Audio/Cache/TrackCache.swift:11-16`
    > `/// LRU cache for track data with actor isolation`
    > `public actor TrackCache {`
  - `Fonic HiFi/Data/DataManager+SmartSearch.swift:4-16`
    > `extension DataManager {`
    > `public func getSmartSearchContext() async throws -> (`
  - `Fonic HiFi/Presentation/Views/Components/BottomSearchBar.swift:186-195`
    > `#Preview {`
    > `BottomSearchBar(searchText: $searchText)`
  - Exact manifest: `08_confirmed_orphan_source_files.txt`, SHA-256 `21246b4b87cb5be1f4de437cf4562a739bb5119e0081fa5593b5914271649892`.
- **Defect and execution path:** The app and widget targets use Xcode file-system-synchronized root groups, with only each `Info.plist` excluded. These 18 Swift files are therefore target inputs, but full-file review found no production construction, call, navigation, modifier use, framework callback, selector, Codable/reflection dependency, or cross-file consumer. Eight exist to satisfy tests of otherwise unused layers, seven are exercised only by previews/self-references, and three have no external consumer at all. The result is compile/index cost, duplicated architecture, misleading test coverage, and a high chance of maintaining the wrong layer. Preview entry points remain valid development tools; “production-unreachable” does not mean blindly deleting a preview the team still values.
- **Remediation:** Decide per file whether the implementation is the intended production path. Wire intended layers into the existing facade/repository/UI architecture; otherwise move reusable test fixtures into the test target, move design explorations into a clearly separate sample/package, or delete the obsolete implementation and its tests. Do not leave production-target files whose only consumer is a test for that same unused implementation.
- **Unapplied production code:** Not supplied. This is an ownership/architecture decision spanning 18 files; an automatic deletion patch would discard tests and previews without product-owner intent.
- **Verification and acceptance:** In Xcode 26, build app, widget, unit tests, UI tests, and Release after each removal/move. Run the relevant previews if retained. Acceptance: each listed file has a documented production consumer or is absent from production target inputs; all tests build from target-appropriate fixtures; the exact manifest becomes empty or contains only explicitly approved preview/sample files.
- **Related:** DCA-DEAD-002, DCA-PART-001, DCA-SAMPLE-001, DLP-004, UIUX-011.

### DCA-DEAD-002 — Live files contain 61 manually retained unreferenced symbol roots

- **Severity:** Low
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift:389-408`
    > `private func audioFormatName() -> String {`
    > `private func getBitDepthFromFormat(_ format: AVAudioCommonFormat?) -> Double {`
  - `Fonic HiFi/Data/Actors/FileImportProcessor.swift:536-542,556-577`
    > `private func scanDirectory(...) async -> [DiscoveredAudioFile] {`
    > `private func copyFileToContainer(_ url: URL) throws -> URL {`
  - `Fonic HiFi/Core/Audio/Playback/PlaybackStateManager.swift:365-391`
    > `func transitionToPaused(...) {`
    > `func transitionToError(...) {`
  - Candidate disposition: `08_dead_candidate_dispositions.json` (`unreferencedAPIInLiveFile` = 50; `deadPrivateHelper` = 5). Six no-product/no-test declarations were also retained after manual review.
- **Defect and execution path:** Unlike the whole-file inventory, these roots live beside active code, so they increase review surface and suggest capabilities that the running app does not use. Manual review checked each definition’s enclosing type, access level, attributes, conformances, direct tests, previews, and product call sites. None of the 50 method roots is a protocol requirement, SwiftUI/WidgetKit callback, App Intent entry point, selector, Codable hook, macro/reflection entry point, or test consumer. The five private helpers cannot be dynamically invoked. The six retained declarations are ordinary concrete helpers/views, not framework-discovered types.
- **Remediation:** Remove private helpers directly. For public/internal methods, either connect them through an existing owner (facade, repository, coordinator, or view) with a test of the real execution path, or delete/narrow them. Prefer deleting unused convenience wrappers over preserving parallel APIs “for later.” Run compiler/index-assisted analysis before committing because static lexical absence is supporting evidence, not a substitute for the Swift compiler.
- **Unapplied production code:** Not supplied; these roots span 23 live files and require per-owner decisions. Mechanical deletion without Xcode type checking is unsafe.
- **Verification and acceptance:** Run a clean Debug and Release build, unit/UI tests, SwiftLint, and an Xcode-capable unused-code tool against all targets. Acceptance: every retained root below is either removed or has a named production call path and focused test; no framework-generated or reflective entry point is removed.
- **Related:** DCA-DEAD-001, DCA-PART-002, DCA-PART-003, AUD-DIAG-001.

#### Retained no-product/no-test method roots (50)

| File | Exact declaration roots |
|---|---|
| `Fonic HiFi Widget/Views/StandByAdaptive.swift` | `standByAdaptive:63` |
| `Fonic HiFi/Core/Audio/Analytics/ListeningSessionService.swift` | `cancelSession:129` |
| `Fonic HiFi/Core/Audio/Coordinators/QueueCoordinator.swift` | `clearQueue:94` |
| `Fonic HiFi/Core/Audio/Diagnostics/PerformanceMonitor.swift` | `startPlaybackTracking:321`, `stopPlaybackTracking:326`, `recordBitPerfectSession:334` |
| `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift` | `validatePlaybackSetup:474`, `getCurrentDiagnostics:485` |
| `Fonic HiFi/Core/Audio/Engines/AVAudioEngineConfig.swift` | `optimalFormat:30` |
| `Fonic HiFi/Core/Audio/Interfaces/AudioDevice.swift` | `bluetoothAudio:212` |
| `Fonic HiFi/Core/Audio/Interfaces/AudioMetrics.swift` | `fromEngine:253` |
| `Fonic HiFi/Core/Audio/Playback/PlaybackState.swift` | `withUpdatedTime:152`, `withUpdatedDuration:168`, `withUpdatedProgress:180` |
| `Fonic HiFi/Core/Audio/Playback/PlaybackStateManager.swift` | `isInState:202`, `recentHistory:246`, `syncFromEngine:268`, `handleEngineStateChange:285`, `transitionToPaused:366`, `transitionToLoading:370`, `transitionToStopped:374`, `transitionToIdle:378`, `transitionToBuffering:382`, `transitionToSeeking:386`, `transitionToError:390` |
| `Fonic HiFi/Core/Audio/Services/NowPlayingInfo+Extensions.swift` | `setTrackNumber:57`, `setIsLiveStream:68` |
| `Fonic HiFi/Core/Services/WidgetDataCoordinator.swift` | `forceReloadWidgets:177`, `cleanupOrphanedArtwork:270`, `clearAllWidgetData:277` |
| `Fonic HiFi/Data/Actors/TrackDataActor.swift` | `getRecentlyPlayed:630`, `getMostListened:650`, `updatePlaybackStats:722`, `updateUserData:743`, `getLastSession:825` |
| `Fonic HiFi/Data/DataManager.swift` | `exportLibraryData:94` |
| `Fonic HiFi/Data/Models/Playlist.swift` | `clearTracks:185`, `removeSmartFilter:201`, `clearSmartFilters:208`, `mostPlayed:417` |
| `Fonic HiFi/Data/Services/LibraryImportService.swift` | `isFileInLibrary:122`, `verifyTrackAccess:321` |
| `Fonic HiFi/Presentation/Views/Components/GlassModifiers.swift` | `playingParticles:345`, `adaptiveGlass:349`, `clearGlassFix:353`, `a11yAwareGlass:357`, `glassPerformanceProfiled:366`, `adaptiveGlassPerformance:370`, `optimalFrameRate:501`, `optimalBlurRadius:538` |

#### Retained no-product/no-test declarations (6)

| Declaration | Exact path/range | Manual check |
|---|---|---|
| `AccessoryCircularGaugeView` | `Fonic HiFi Widget/Views/AccessoryCircularView.swift:72-95` | Not selected by `NowPlayingWidget`; ordinary alternate `View`. |
| `AlbumCardView` | `Fonic HiFi/Presentation/Views/Home/HomeView.swift:350-368` | Private and never constructed. |
| `BatteryOptimizedGlassUtilities` | `Fonic HiFi/Presentation/Views/Components/GlassModifiers.swift:500-572` | Ordinary helper island; no modifier/caller uses it. |
| `LibrarySearchRequest` | `Fonic HiFi/Domain/UseCases/LibraryUseCases.swift:24-34` | Not passed to any repository/use case. |
| `PerformanceMetrics` | `Fonic HiFi/Core/Audio/Diagnostics/BitPerfectValidationResult.swift:549-578` | Not the active `AudioPerformanceMetrics`/`AppPerformanceMetrics` types. |
| `StandByAwareContainer` | `Fonic HiFi Widget/Views/StandByAdaptive.swift:169-186` | Ordinary generic `View`; not framework-discovered or constructed. |

#### Retained private helpers (5)

| Helper | Exact path/range |
|---|---|
| `audioFormatName` | `Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift:389-392` |
| `getBitDepthFromFormat` | `Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift:397-408` |
| `handlePlaybackCompletion` | `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:552-556` |
| `scanDirectory` | `Fonic HiFi/Data/Actors/FileImportProcessor.swift:536-542` |
| `copyFileToContainer` | `Fonic HiFi/Data/Actors/FileImportProcessor.swift:556-577` |

### DCA-PART-001 — Listening-session tracking is implemented but never configured

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:35-36,167-178,204-208,331-341`
    > `private var sessionService: ListeningSessionService?`
    > `await self.sessionService?.endSession(...)`
    > `public func configureSessionTracking(dataActor: TrackDataActor) {`
    > `self.sessionService = ListeningSessionService(dataActor: dataActor)`
    > `sessionService?.startSession(trackId: track.id, duration: duration)`
  - `Fonic HiFi/FonicHiFiApp.swift:318-345`
    > `let dataManager = try DataManager()`
    > `let audioService = AudioEngineFacade(...)`
    > `return AppServices(...)`
  - Repository-wide call-site verification found only the declaration of `configureSessionTracking`.
- **Defect and execution path:** Primary startup creates both `dataManager.trackDataActor` and `audioService` in the same service factory but never connects them. All start/end calls are optional-chained, so playback succeeds while silently recording no sessions. Recent listening, rediscovery, recommendations, and smart-search context then operate on empty/stale history. Wiring this immediately must be coordinated with the separate schema defect: `ListeningSession` must first be present in the active SwiftData schema/migration.
- **Remediation:** After resolving DLP-002’s schema/migration issue, call `configureSessionTracking` in primary, preview, and recoverable-fallback service construction whenever a real `DataManager` exists. Prefer making the dependency required in the facade initializer so future constructors cannot forget it.
- **Unapplied production patch (requires Xcode compile and persistence tests):**

```swift
let audioService = AudioEngineFacade(
    stateManager: playbackStateManager,
    queueManager: queueManager,
    monitor: audioMonitor
)
audioService.configureSessionTracking(dataActor: dataManager.trackDataActor)
```

Apply the equivalent connection in every factory that returns an audio service with a data manager. Do not ship this alone until `ListeningSession` schema/migration support is fixed.
- **Verification and acceptance:** Add an integration test with a real in-memory schema containing `ListeningSession`: play, stop/complete/skip, then fetch sessions from `TrackDataActor`. Acceptance: one correctly attributed session is persisted per playback lifecycle, skip/completion flags are correct, fallback mode does not crash, and production construction cannot produce an unconfigured tracker. Run a device test across natural completion and manual Next.
- **Related:** DLP-002, DLP-004, DLP-019, DLP-020.

### DCA-PART-002 — Persisted EQ is neither restored nor reapplied after engine creation/switch

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:74-75,247-264,268-280`
    > `private var currentEQConfiguration: EqualizerConfiguration = .default`
    > `public func applyEQ(_ configuration: EqualizerConfiguration) async {`
    > `public func reapplyEQConfiguration() async {`
    > `await applyEQ(currentEQConfiguration)`
    > `let mergedConfiguration = await playbackSettingsStore.configuration(...)`
  - `Fonic HiFi/Core/Audio/Engine/AudioPlaybackSettingsStore.swift:85-99`
    > `public func setEqualizerConfiguration(...)`
    > `public func equalizerConfiguration() -> EqualizerConfiguration`
  - `Fonic HiFi/Core/Audio/Engine/AudioEngineManager.swift:124-145`
    > `let engine = try await engineFactory.makeEngine(...)`
    > `currentEngine = engine`
    > `return engine`
  - Repository-wide call-site verification found only the declaration of `reapplyEQConfiguration`.
- **Defect and execution path:** The EQ view persists changes, but facade initialization merges only crossfade, replay gain, playback rate, and gapless settings. `currentEQConfiguration` therefore starts flat/default. When `AudioEngineManager` creates a new adapter after format or preference change, neither manager nor controller reapplies the stored EQ; the dedicated helper is never called. Users can see a persisted enabled preset while playback is flat, and an engine switch can silently drop a live EQ.
- **Remediation:** Make EQ part of the engine-preparation contract. Load the persisted configuration during facade initialization, then apply it whenever `ensureEngine` returns a newly created/recreated engine and before playback starts. Keep one authoritative configuration; do not make individual views responsible for restoring engine state.
- **Unapplied production code:** Not supplied. A safe patch crosses actor initialization, manager/controller ownership, initial load, queue auto-advance, and engine-switch paths; adding one call in the EQ view or one play method would miss other paths.
- **Verification and acceptance:** Add an engine spy that records `applyEQ`; cover cold launch with persisted EQ, same-engine reuse, format-driven recreation, preference-driven switch, queue auto-advance, and disabled/bypass mode. Acceptance: the selected configuration is applied exactly once to every newly active EQ-capable engine before audible playback; unsupported engines expose a clear state. Validate graph/bypass behavior on device.
- **Related:** AUD-DSP-001, AUD-ENG-001, DCA-DEAD-002.

### DCA-PART-003 — QueueCoordinator exposes three inert methods beside working manager APIs

- **Severity:** Low
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Coordinators/QueueCoordinator.swift:99-104,173-185`
    > `public func removeFromQueue(trackId: String) {`
    > `// Note: This would need to be implemented in AudioQueueManager`
    > `public func saveQueueState() async {`
    > `// This could be implemented to persist queue to disk`
    > `public func restoreQueueState() async {`
  - `Fonic HiFi/Core/Audio/Queue/AudioQueueManager.swift:153-199,574-602`
    > `public func remove(at index: Int) -> AudioTrack?`
    > `public func remove(track: AudioTrack) -> Bool`
    > `public func saveState(...)`
    > `public func restoreState() -> Bool`
- **Defect and execution path:** The coordinator’s `removeFromQueue`, `saveQueueState`, and `restoreQueueState` methods only log. None currently has a caller, while the manager already implements the operations and the facade uses the manager directly. This is not a proven current queue-action failure; it is a stale partial abstraction that can become a silent failure as soon as a caller adopts the coordinator API. `removeFromQueue` also takes `String` although `AudioTrack.id` is `UUID`, confirming drift.
- **Remediation:** Delete these three methods if the manager remains the owner. If the coordinator is the intended boundary, change removal to a typed `UUID`/track or index, delegate to the manager, return success/failure, and delegate persistence to `saveState`/`restoreState`. Do not keep log-only public commands.
- **Unapplied production code:** Not supplied; no current caller establishes the desired signature or ownership.
- **Verification and acceptance:** Add coordinator tests only if the methods remain. Acceptance: removal changes the intended queue entry and preserves current index/order; save/restore round-trips queue, modes, current item, and playback position; no public queue command has a log-only body.
- **Related:** AUD-QUEUE-001, AUD-RECOVERY-001, DCA-DEAD-002.

### DCA-PART-004 — Smart-search result taps only log and never invoke playback

- **Severity:** Low
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Presentation/Views/Search/SearchView.swift:44-56,180-184`
    > `SmartSearchResultsView(...) { track in`
    > `playTrack(track)`
    > `// For now, this is a placeholder - integrate with audioEngine environment`
    > `logger.info("Playing track from smart search: ...")`
  - `Fonic HiFi/Presentation/Views/Search/SmartSearchResultsView.swift:65-70`
    > `Button {`
    > `onTap(track)`
- **Defect and execution path:** A smart-result row is a real Button and forwards the selected `Track`, but the terminal callback only logs. The broader smart-search mode is currently difficult/unreachable through active state flow (UIUX-011), which bounds current impact; once that path is exposed, tapping a result will still do nothing.
- **Remediation:** Inject the existing `audioEngine` environment value into `SearchView`, invoke `AudioEngineFacade.play(track:)`, and surface failure through the existing search/UI error state. Do not duplicate a playback controller in Search.
- **Unapplied production patch (requires Xcode compile/UI test):**

```swift
@Environment(\.audioEngine) private var audioEngine

private func playTrack(_ track: Track) {
    Task { @MainActor in
        do {
            guard let audioEngine else { return }
            try await audioEngine.play(track: track)
        } catch {
            logger.error("Smart search playback failed: \(error.localizedDescription)")
            // Route this through the app's visible error presentation.
        }
    }
}
```

The final patch must add visible error presentation rather than logging alone.
- **Verification and acceptance:** First expose Smart Search deterministically. In a UI test, search, tap a known result, and assert mini-player/current-track state. Add a failure-path test. Acceptance: the selected track becomes current and begins playback, or a visible recoverable error appears; a tap never ends as a log-only action.
- **Related:** UIUX-011, DCA-DEAD-001.

### DCA-PART-005 — AudioKit diagnostics return fixed zero metrics while an empty collector is polled

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift:240-253`
    > `public func getMetrics() async -> AudioMetrics {`
    > `cpuUsage: 0.0,`
    > `memoryUsage: 0,`
    > `bufferUnderruns: 0,`
    > `public func collectMetrics() async {}`
  - `Fonic HiFi/Core/Audio/Diagnostics/AudioMonitorEngineHooks.swift:69-82`
    > `await initialEngine.collectMetrics()`
    > `while !Task.isCancelled {`
    > `await currentEngine.collectMetrics()`
  - `Fonic HiFi/Core/Audio/Diagnostics/EngineMetricsCollector.swift:19-38`
    > `let audioMetrics = await engine.getMetrics()`
    > `return EngineMetrics(...)`
- **Defect and execution path:** When AudioKit is active, monitoring repeatedly calls an empty method and the reporting path converts a fixed all-zero snapshot into diagnostics. This can present “healthy” zero underruns/latency/load rather than “unavailable,” undermining troubleshooting and any recommendations built on the data while still paying polling/task overhead.
- **Remediation:** Either implement measurable AudioKit metrics and update stored samples, or remove `collectMetrics` polling from the engine protocol and model unsupported fields explicitly as unavailable. Never encode missing measurements as successful zero values.
- **Unapplied production code:** Not supplied; accurate metrics require AudioKit/AVAudioEngine instrumentation and device validation. Replacing zeros with guessed values would be worse.
- **Verification and acceptance:** On a physical device, exercise AudioKit playback under normal and induced-load conditions. Acceptance: supported measurements vary plausibly and correlate with instrumentation, unsupported measurements are shown as unavailable, and no periodic task invokes an empty collector. Add unit tests that distinguish unavailable from numeric zero.
- **Related:** AUD-DIAG-001, CP-012, DCA-DEAD-002.

### DCA-ART-001 — Fourteen machine/generated/backup artifacts are tracked despite ignore intent

- **Severity:** Low
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `.gitignore:5-11,22-27`
    > `## User settings`
    > `xcuserdata/`
    > `## Build generated`
    > `build/`
    > `DerivedData/`
  - `Fonic HiFi.xcodeproj/xcuserdata/keiran.xcuserdatad/xcschemes/xcschememanagement.plist:5-15`
    > `<key>SchemeUserState</key>`
    > `<key>Fonic HiFi.xcscheme_^#shared#^_</key>`
    > `<key>orderHint</key>`
  - `build_errors.log:1-9`
    > `Checking dependencies...`
    > `[OK] xcodebuild`
    > `[OK] swiftlint`
  - `Fonic HiFi.xcodeproj/project.pbxproj.backup:1-6`
    > `// !$*UTF8*$!`
    > `objectVersion = 77;`
  - Exact manifest: `08_hygiene_candidate_files.txt`, SHA-256 `a5a1377733ff574301f3d900f34bc058ce0d4571e48b2bd9c2f8f320a1deaa1b`.
- **Defect and execution path:** The tracked set contains three generated logs (98,356 bytes/1,723 lines), six user-specific Xcode-state files (2,171 bytes/85 lines), three copy/backup files (49,688 bytes/1,274 lines), and two local tool configuration files (6,546 bytes/224 lines): 14 files, 156,761 bytes, 3,306 lines. They create noisy diffs, preserve stale build/project state, and can carry machine-local or sensitive configuration. Credential values were not reproduced; the two local configuration files require the redacted security remediation already recorded in PCFG-001/PSR-001.
- **Remediation:** Remove these paths from the index, extend `.gitignore` for logs, project backups/copies, and local tool configuration, and retain only sanitized templates where configuration is genuinely shared. Rotate any credential that has ever been committed, following the security audit.
- **Unapplied hygiene patch:** Add patterns such as:

```gitignore
*.log
log.md
*.pbxproj.backup
* copy.md
.claude/settings.local.json
.kilocode/mcp.json
xcuserdata/
```

Then remove the 14 manifest paths from Git tracking without deleting needed local copies.
- **Verification and acceptance:** `git ls-files` must return none of the 14 manifest paths; fresh build/test commands must regenerate logs outside version control; shared schemes, if needed, must be committed under `xcshareddata`, not `xcuserdata`; secret scanning must pass without printing values.
- **Related:** PCFG-001, PCFG-008, PSR-001, PSR-007.

### DCA-SAMPLE-001 — Three undocumented sample app fragments have no build container

- **Severity:** Low
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `sample/README.md:1-17`
    > `# Sample Applications`
    > `## AppleMusicBottomBar`
    > `## AppleMusicMiniPlayer`
  - `sample/CustomGlassTabBar/CustomGlassTabBar/CustomGlassTabBarApp.swift:8-16`
    > `import SwiftUI`
    > `@main`
    > `struct CustomGlassTabBarApp: App`
  - Equivalent `@main` app declarations exist at `sample/CustomMenu/CustomMenu/CustomMenuApp.swift:8-16` and `sample/CustomToolBottomBar/CustomToolBottomBar/CustomToolBottomBarApp.swift:8-16`.
  - Tracked-file verification found no `.xcodeproj`, package manifest, or other build container under those three roots.
- **Defect and execution path:** The sample tree contains five app-like directories, but the README documents only the two that include Xcode projects. `CustomGlassTabBar`, `CustomMenu`, and `CustomToolBottomBar` contain 18 tracked files, including nine Swift files/775 physical Swift lines and three `@main` entry points, yet cannot be opened or CI-built as standalone samples from the committed tree. They are neither product target members nor complete documented samples.
- **Remediation:** If they remain useful references, document provenance/license and intended use, add a buildable project/package (prefer one consolidated sample workspace), and gate it in CI. Otherwise reduce them to clearly labeled snippets or remove them. Do not copy sample code into production without adapting it to the app’s state, accessibility, and architecture.
- **Unapplied production code:** Not applicable; this is repository/sample ownership.
- **Verification and acceptance:** From a clean checkout, every directory named as a sample either has documented build/run steps and builds with the declared Xcode/iOS version, or is explicitly labeled a non-buildable snippet. Acceptance: README inventory matches the tracked sample roots; no sample `xcuserdata` is tracked.
- **Related:** DCA-DEAD-001, DCA-ART-001, UIUX “Preserving, unapplied sample inventory.”

### DCA-DUP-001 — Three app/widget shared-data contracts are manually duplicated

- **Severity:** Informational
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Shared/WidgetConstants.swift:10-26` and `Fonic HiFi Widget/Shared/WidgetConstants.swift:10-26`
    > `public enum WidgetConstants {`
    > `public enum Keys {`
    > `public enum WidgetKind {`
  - `Fonic HiFi/Shared/WidgetPlaybackState.swift:10-38` and `Fonic HiFi Widget/Shared/WidgetPlaybackState.swift:10-38`
    > `public struct WidgetPlaybackState: Codable, Sendable, Hashable`
  - `Fonic HiFi/Shared/WidgetTrackInfo.swift:10-35` and `Fonic HiFi Widget/Shared/WidgetTrackInfo.swift:10-35`
    > `public struct WidgetTrackInfo: Codable, Sendable, Hashable, Identifiable`
  - `Fonic HiFi.xcodeproj/project.pbxproj:183-185,246-248` shows separate synchronized app/widget roots.
- **Defect and execution path:** The three pairs are currently semantically identical; a line diff found only two header-comment differences per pair. They are not classified as dead or as duplicate-symbol build errors because app and widget compile as separate modules. The risk is contract drift: either target can change Codable fields, keys, defaults, date strategies, or cache constants independently, causing silent widget decode fallback/staleness.
- **Remediation:** Compile one canonical shared source into both targets, or move the contracts into a small local shared package. If project layout prevents that immediately, add a cross-target fixture/contract test and an automated semantic-diff guard.
- **Unapplied production code:** Not supplied; consolidating files requires Xcode target-membership/project changes that cannot be validated in this environment.
- **Verification and acceptance:** Build both targets, encode representative current/legacy payloads in the app contract and decode them in the widget contract, and vice versa. Acceptance: one canonical source owns the schema, or CI fails on semantic drift; versioned decoding handles future additive changes.
- **Related:** AUD-WIDGET-001, DLP-016, DCA-ART-001.

## Candidate disposition and rejected findings

### Complete scanner disposition

The lexical scan was treated only as candidate generation. Every retained group above was manually checked against source and target structure.

| Candidate class | Count | Disposition |
|---|---:|---|
| Single-occurrence functions | 130 | 26 belong to whole-file finding; 50 retained as unreferenced live roots; 5 retained private helpers; 3 retained inert methods; 2 retained missing integrations; 40 test-only APIs rejected as dead; 4 framework requirements rejected. |
| Low-occurrence declarations | 16 | 7 belong to whole-file finding; 6 retained live declarations; 1 PreviewProvider preserved; `BatchProcessor` preserved as test-used; `MixDefinition` preserved as `@Generable`/test-used. |
| Marker hits | 25 | All manually resolved; no production fatal/TODO/FIXME hazard retained. |
| Initial artifact candidates | 57 | 49 sample-tree files plus 8 non-sample cleanup paths. Broader tracked-file inventory found 14 hygiene candidates, including paths the initial fragment matcher omitted. |

### Explicit rejections and qualifications

- **Framework/protocol entry points are live:** `NowPlayingTimelineProvider.getSnapshot` and `getTimeline` (`Fonic HiFi Widget/NowPlayingTimelineProvider.swift:24,33`) satisfy WidgetKit; `makeUIView` and `updateUIView` (`Fonic HiFi/Presentation/Views/Components/AirPlayRouteButton.swift:13,23`) satisfy `UIViewRepresentable`. They were not labeled dead from token counts.
- **Preview entry point is preserved:** `AccessibilityEnhancements_Previews` (`Fonic HiFi/Presentation/Views/Components/AccessibilityEnhancements.swift:412-458`) is a SwiftUI `PreviewProvider`. Its surrounding implementation is production-unreachable, but the preview itself is a valid development entry point.
- **Foundation Models macro/reflection boundary:** `MixDefinition` (`Fonic HiFi/Core/AI/Recommendations/RecommendationSchemas.swift:31-51`) is `@Generable` and directly tested. It was not labeled dead from its single product token. Macro-generated schema/reflection behavior needs Xcode confirmation.
- **App Intents boundary:** the four same-named app/widget intent declarations were not labeled dead or defective from empty widget `perform()` bodies/token counts. App Intents/LiveActivityIntent routing requires an Xcode/device check. The main-app implementations are explicit framework entry points.
- **Codable/reflection boundary:** `CodingKeys`, app/widget Codable models, persistence decode methods, and migration model types were not classified dead from lexical counts. DCA-DUP-001 concerns maintainability, not current deadness.
- **Selector boundary:** notification handlers referenced with `#selector` were treated as live even if ordinary direct-call counts were low.
- **Test-only APIs (40):** `addingMetadata`, `availableEngineTypes`, `builtInMicrophone`, `clearAdapters`, `clearMetrics`, `clearSavedState`, `createTracks`, `discoverAudioFiles`, `formatCompatibility`, `generateInsights`, `getPreviousTrack`, `getSessionsByHourRange`, `getTrackMetadata`, `getTracksCount`, `groupBySeverity`, `importSingleFile`, `isEngineAvailable`, `loadLastUpdated`, `loadPlaybackState`, `loadTrackInfo`, `loadUpNextTracks`, `mostCritical`, `moveToNext`, `moveToPrevious`, `nearestSupportedSampleRate`, `needsSampleRateConversion`, `processBatches`, `processFiles`, `registerAdapter`, `registerEffect`, `removeSearch`, `renderQuality`, `sampleRateConverterSettings`, `setCurrentEngine`, `setSinkForTesting`, `transitionToPlaying`, `unregisterEffect`, `updateStatisticsCacheTTL`, `validateState`, and `wiredHeadphones` have direct tests. They may be candidates for narrower access or test-support extraction, but they are not repository-dead and were not counted in DCA-DEAD-002.
- **Fatal/precondition scan:** product source contains **0 `fatalError`**, **0 `assertionFailure`**, and **1 `precondition`**. `AsyncSemaphore` requires a positive value (`Fonic HiFi/Core/Audio/Services/AsyncSemaphore.swift:9`); all tracked constructors pass defaults/values 4, 2, 1, or other positive constants. Four `fatalError` calls are fail-fast methods in test stubs only (`Fonic HiFiTests/AudioEngineFacadeOrchestratorTests.swift:232,244`; `Fonic HiFiTests/StateCoordinatorTests.swift:139,151`). The second precondition is a test-fixture input guard (`Fonic HiFiTests/Support/ImportTestFixtures.swift:74`). No production crash finding was retained.
- **TODO/FIXME/commented code:** active app/widget Swift contains **0 TODO**, **0 FIXME**, **0 HACK marker**, and no block-commented or line-commented production code candidate after manual review. Three lexical `XXX` hits are the legitimate metadata term “ID3v2 TXXX” (`Fonic HiFi/Data/Services/MetadataExtractionService.swift:82,363,369`).
- **Debug code:** all 16 `#if DEBUG` hits are bounded to debug logging/assertions, model diagnostics, test helpers, or preview constants. No release-path debug action was retained. `AudioEngineFacade`’s runtime monitor defaults on only in DEBUG and off in Release (`Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:119-127`).
- **Empty/no-op syntax:** empty initializers, empty conformance extensions, SwiftUI alert cancel actions, preview closures, `AudioQueueDelegate` optional defaults, and `ThermalStateMonitor.startMonitoring` were reviewed and rejected as defects. The retained empty/inert behavior is limited to DCA-PART-003/004/005 and inert actions inside the already orphaned Accessibility prototype.
- **Placeholders:** 47 case-insensitive “placeholder” occurrences were reviewed. Forty-six are normal artwork/widget/text-field/preview placeholders. The single implementation placeholder is `SearchView.playTrack` and is retained as DCA-PART-004.
- **Duplicate-name scan:** 23 lexical duplicate-name groups were reviewed. Four are app/widget App Intent declarations in separate modules; seven describe the mirrored widget contract in DCA-DUP-001; four are nested same-name types in different scopes; eight are private/test-local stubs. No duplicate-symbol build error was inferred. There are 12 exact-content file groups (37 files), but **no exact duplicate Swift source file group**.
- **Target membership:** no static membership gap was found for tracked app, widget, or test trees. The project uses four file-system-synchronized roots and excludes only each target’s `Info.plist`. Xcode 26 must still confirm compiled source lists and resource membership.
- **Documented samples:** `sample/README.md:1-17` explicitly preserves AppleMusicBottomBar and AppleMusicMiniPlayer as references; they were not labeled product dead. DCA-SAMPLE-001 is limited to the three undocumented, non-buildable fragments.
- **Archives:** `Files/Archive/README.md:1-9` explicitly labels its contents historical and non-representative. The 63 archived files/21,980 lines are a quantified inventory, not evidence of a product bug. Five plan files are exact duplicates of active/archive counterparts; cleanup is optional documentation governance.

## Open Xcode/build/device checks

1. **Compiled-source verification:** in Xcode 26, inspect `PBXFileSystemSynchronizedRootGroup` resolved build inputs for all four targets and archive the source-file list. Confirm no unexpected cross-target resource/source inclusion.
2. **Dead-code confirmation:** clean-build Debug and Release, run all unit/UI tests, then run an Xcode-capable unused-code tool. Review generated macro, App Intents, Objective-C selector, SwiftUI preview, WidgetKit, Codable, and migration roots before removal.
3. **Listening-session integration:** first fix/register `ListeningSession` schema and migration, then run play/pause/stop/skip/natural-completion tests against a real in-memory and migrated persistent store.
4. **EQ restoration:** on both adapters and a physical route, validate cold launch, format-driven engine recreation, manual engine preference switch, disabled bypass, and queue auto-advance.
5. **AudioKit diagnostics:** compare displayed/exported metrics to Instruments/device observations; unsupported fields must be unavailable rather than zero.
6. **App Intent routing:** invoke each widget/Live Activity control on device with app foreground, background, suspended, and terminated. Confirm which target’s `perform()` executes before changing the duplicate declarations.
7. **Shared Codable contract:** encode/decode app-to-widget and widget-to-app fixtures, including an older payload, after consolidating or guarding the mirrored types.
8. **Samples:** either build every documented sample from a clean checkout or relabel/remove source-only fragments; do not claim sample viability without Xcode results.
