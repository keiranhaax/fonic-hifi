# Dead Code, Partial Implementations & Debug Leftovers — Fonic HiFi

**Audit date:** 2026-07-09 · **Scope:** whole repo (app + widget + tests), READ-ONLY static analysis, no Xcode.
**Method:** Symbol inventory (563 production type decls) reference-counted with ripgrep; every "unused" claim reference-counted across app + widget + test targets and cross-checked for `@main`, protocol conformance, `#Preview`, string lookup, and sibling-type usage before being asserted. Confidence is downgraded to SUSPECTED where a build-in-Xcode check is the only way to be 100% sure.

> **Project packaging fact that governs "dead file" severity:** `Fonic HiFi.xcodeproj/project.pbxproj:6` declares `objectVersion = 90`, and lines 78-105 define four `PBXFileSystemSynchronizedRootGroup`s (app, tests, UITests, widget) with only `Info.plist` excepted (lines 61-76). **Every `.swift` file on disk under those four folders is automatically compiled into its target.** Consequently there are NO "on-disk-but-not-in-target" orphans — instead, every dead `.swift` file listed below *actually ships in the binary*. `sample/`, `Files/`, and `docs/` are NOT under any synchronized group, so they do not compile.

---

## Summary (worst first)

- **~1,860 lines of fully-dead Swift ship in the app binary.** Ten standalone view/service files are compiled but referenced by nothing except their own `#Preview` (or nothing at all): `AlbumGridView.swift` (294 L), `LiquidGlassRail.swift` (316 L), `LiquidGlassTabBar.swift` (166 L), `BottomSearchBar.swift` (197 L), `ImportSession.swift` (490 L), `SearchPlaylistResultsView.swift` (85 L), `DiagnosticsDetailView.swift` (153 L), `AudioSettingsService.swift` (41 L), `LibraryFilter.swift` (36 L), plus the primary views inside `ArtistListView.swift`/`TrackListView.swift`.
- **An entire abandoned "Liquid Glass" navigation family is dead:** `LiquidGlassTabBar`, `LiquidGlassRail`, `LiquidGlassExpandableRail`, `LiquidGlassSegmentedTabs`. The app actually navigates with the native SwiftUI `TabView`/`Tab` in `ContentView.swift:27-49`. High-value: these are large, plausible-looking files a maintainer could mistake for live UI.
- **A superseded "Library list" UI generation is dead:** standalone `AlbumGridView`, `ArtistListView`, `TrackListView` (their primary list Views + row/sort helpers) are never instantiated; the live Library screen (`LibraryView.swift`) uses its own private `*Entity*` sub-views instead. Only the `*DetailView` types from those files survived (reused by Home/NowPlaying).
- **Production-dead / test-kept services**: `AudioSettingsService`, `ImportSession` (actor), `SearchCache`, `TrackCache`, `PlaybackStateStore`, `LibraryFilter`, `MixDefinition`, `BatchProcessor` — each defined + exercised only by unit tests, with zero production callers. Their tests give false confidence that the code is live.
- **One reachable no-op stub in a user-facing path:** `QueueCoordinator.removeFromQueue(trackId:)` logs "Removing track…" but the body only contains a comment "This would need to be implemented in AudioQueueManager" — it removes nothing. (It is not currently called by any UI, so impact is latent, not active.)
- **Debug hygiene is genuinely good:** ZERO `print()`/`debugPrint()`/`dump()`/`NSLog()` in production; ZERO `TODO`/`FIXME`/`HACK` comments; ZERO `fatalError("not implemented")`-style stubs. `#if DEBUG` blocks are all legitimate debug helpers with no feature-hiding else branches. This is a cleaned-up codebase (the prior "chore: remove debug…" commit was effective).
- **AI features are complete, not stubbed.** `SmartSearchService` and `RecommendationService` are real on-device FoundationModels integrations (`LanguageModelSession.respond(generating:)`) wired to `SmartSearchViewModel` and `HomeView`, with proper guardrail handling and rule-based fallbacks. Not partial.
- **EQ is complete, not partial.** The 10-band `EqualizerConfiguration` flows end-to-end into a real `AVAudioUnitEQ` (`AVAudioEngineAdapter.applyEQ`, lines 656-671), including bit-perfect true-bypass, preamp anti-clip gain, and shelf filters on edge bands — it even implements the "opportunities" EQ.md lists as future work. `EQ.md`'s `[Verified-Code]` line numbers are slightly stale (doc drift), but every claim is otherwise accurate.
- **Repo is cluttered with tracked dev detritus that should not ship in a production repo:** `log.md` (51 KB), `build_verify.log` (29 KB), `build_errors.log` (17 KB), `summary.md`, `Files-analysis.md`, `CLAUDE copy.md`, `project.pbxproj.backup`, `Files/` (102 archived planning docs), `sample/` (5 sample Xcode projects, 49 tracked files). `.gitignore` is also **broken** (malformed final line + `*.xcodeproj` ignored while the real project is force-tracked).
- **Test suite is healthy** (no `XCTSkip`-disabled tests beyond legitimate environment guards, no commented-out test funcs, no orphan test files for deleted types) — but it is the thing keeping several dead production modules "alive".

---

## Findings

### [High] Dead "Liquid Glass" navigation family ships in the binary (never instantiated)
- **Files:**
  - `Fonic HiFi/Presentation/Views/Components/LiquidGlassTabBar.swift:1-166` (types `LiquidGlassTabBar`, `TabButton`, `TabItem`)
  - `Fonic HiFi/Presentation/Views/Components/LiquidGlassRail.swift:1-316` (types `LiquidGlassRail`, `LiquidGlassExpandableRail`, `LiquidGlassSegmentedTabs`, `InteractiveSheen`)
- **Evidence:** `rg -w LiquidGlassTabBar` across `Fonic HiFi` + `Fonic HiFi Widget` returns matches only inside `LiquidGlassTabBar.swift` (declaration at line 15 + two `#Preview` usages at lines 139, 157). Same pattern for `LiquidGlassRail` (decl + `#Preview` at line 275 only). Filtered search excluding the defining file and previews returns **nothing**:
  ```
  rg -w -n LiquidGlassRail "Fonic HiFi"  → (only LiquidGlassRail.swift)
  rg -w -n LiquidGlassTabBar "Fonic HiFi" → (only LiquidGlassTabBar.swift)
  ```
  The `Tab` type in `LiquidGlassRail.swift` appears "used externally" but that is a name collision with **SwiftUI's** `Tab`, used by the real navigation in `ContentView.swift:28-46` (`Tab("Home", systemImage:…){…}` inside a `TabView`). The app uses native tabs, not this custom rail.
- **Why it matters:** ~480 lines of convincing-looking UI compile into the shipping app but are unreachable. A maintainer editing "the tab bar" could waste effort here, or worse, wire it back in by mistake.
- **Fix:** Delete `Fonic HiFi/Presentation/Views/Components/LiquidGlassTabBar.swift` and `Fonic HiFi/Presentation/Views/Components/LiquidGlassRail.swift`. Because the folder is a synchronized group, removing the files from disk removes them from the target automatically — verify with a build after deletion. (SUSPECTED-safe: no production reference exists; the only risk is a `#Preview` you no longer need.)

### [High] Dead standalone Library list views (superseded UI generation)
- **Files:**
  - `Fonic HiFi/Presentation/Views/Library/AlbumGridView.swift:1-294` — `AlbumGridView`, `AlbumSortOrder`, `AlbumGridItem`, `AlbumDetailView`, `AlbumTrackRow` all have **zero external references** (whole file dead).
  - `Fonic HiFi/Presentation/Views/Library/ArtistListView.swift:1-281` — `ArtistListView`, `ArtistRowView`, `ArtistAlbumsView`, `ArtistTracksView`, `ArtistSortOrder`, `ArtistViewMode` are dead; **only** `ArtistDetailView` survives (used by `HomeView.swift:70`).
  - `Fonic HiFi/Presentation/Views/Library/TrackListView.swift:1-175` — `TrackListView`, `TrackSortOrder` are dead; **only** `TrackDetailView` survives (used by `NowPlayingContent.swift:135`).
- **Evidence:** `rg -w AlbumGridView "Fonic HiFi" "Fonic HiFi Widget"` → matches only in `AlbumGridView.swift` (decl line 12 + `#Preview` line 293). Same for `ArtistListView` (decl + `#Preview` 280) and `TrackListView` (decl + `#Preview` 174). The live Library screen is `LibraryView.swift` (wired in `ContentView.swift:35: LibraryView(viewModel: LibraryViewModel(repository: repository))`), which renders its own **private** sub-views `TrackEntityRow`/`AlbumEntityTile`/`ArtistEntityRow`/… (verified used at `LibraryView.swift:198,232,253,129-138`). The standalone `*ListView`/`*GridView` files are a parallel, older generation.
- **Why it matters:** ~640 lines of dead Library UI in the binary; naming (`TrackListView`, `AlbumGridView`) strongly implies these are the live list screens, which is misleading.
- **Fix:** Extract the still-used detail views (`ArtistDetailView`, `TrackDetailView`, and the `DetailRow` helper) into their own files or into `LibraryView.swift`, then delete `AlbumGridView.swift` entirely and the dead remainder of `ArtistListView.swift`/`TrackListView.swift`. Rebuild to confirm the two detail views still resolve. **SUSPECTED for the two detail views' relocation** — verify by building in Xcode.

### [High] `ImportSession.swift` — 490-line abandoned import implementation (test-kept)
- **File:** `Fonic HiFi/Data/Services/ImportSession.swift:1-490`
- **Evidence:** The file declares 10 types. Reference-counting each across production (excluding this file) and tests:
  ```
  ImportSession (actor)      → prod:0  tests:1
  ImportSessionProtocol      → prod:0  tests:0
  ImportProgress             → prod:0  tests:0
  ImportPhase                → prod:0  tests:0
  ValidationResult           → prod:0  tests:0
  ImportValidationIssue      → prod:0  tests:0
  ImportSessionError         → prod:0  tests:1
  ImportItem / ImportStatus  → prod:0  tests:0
  ImportError                → prod:2  tests:0   ← ONLY survivor
  ```
  Actual importing is done by `LibraryImportService` + `FileImportProcessor` (both live; `STATUS.md:22` lists `LibraryImportService` as ✅). `ImportSessionProtocol` has exactly one conformer (`ImportSession`) — an abandoned abstraction.
- **Why it matters:** A large actor + protocol + value-type cluster compiles into the app and is covered by `ImportSessionTests`, giving false "it's used" signals during triage.
- **Fix:** Move the one live enum `ImportError` (used by 2 files) into `LibraryImportService.swift` or a small `ImportError.swift`, then delete `ImportSession.swift` and `Fonic HiFiTests/ImportSessionTests.swift`. Verify build.

### [High] Production-dead, test-kept services (zero production callers)
- **Files / evidence** (each: `rg -w <Type>` returns the defining file + only test files, no production consumer):
  - `Fonic HiFi/Core/Services/AudioSettingsService.swift:15` — `public final class AudioSettingsService` used only in `Fonic HiFiTests/Core/Services/AudioSettingsServiceTests.swift` (5×). App reads audio settings via `AudioPlaybackSettingsStore` (`AudioEngineFacade.swift` references it).
  - `Fonic HiFi/Data/Services/SearchCache.swift:12` — `public actor SearchCache`; own file + `SearchCacheTests`/`SearchCacheStatisticsTests` only.
  - `Fonic HiFi/Core/Audio/Cache/TrackCache.swift:12` — `public actor TrackCache`; own file + `TrackCacheTests` only.
  - `Fonic HiFi/Core/Audio/Playback/PlaybackStateStore.swift:13` — `public final class PlaybackStateStore` with `static let shared` (line 16); every reference is a self-reference (`.shared`, factory, extensions) + `PlaybackStateStoreTests`. No external consumer. Note: the app uses `PlaybackStateManager` (separate, live).
  - `Fonic HiFi/Presentation/ViewModels/Library/LibraryFilter.swift:3` — `enum LibraryFilter`; 10 calls, **all** in `Fonic HiFiTests/LibraryFilterTests.swift`. `LibraryViewModel` does its own filtering.
- **Why it matters:** These pass tests and look load-bearing, but deleting them changes nothing at runtime. They inflate the binary and the mental model of the audio/data layers.
- **Fix:** For each, delete the production file **and** its test file together (deleting the source without the test will break the build since the test is the only referrer). Recommended order: `LibraryFilter` + `LibraryFilterTests`; `AudioSettingsService` + `AudioSettingsServiceTests`; `TrackCache` + `TrackCacheTests`; `SearchCache` + `SearchCache*Tests`; `PlaybackStateStore` + `PlaybackStateStoreTests`. **SUSPECTED** — confirm each is not referenced via a protocol you overlooked by building after each removal.

### [Medium] Reachable-but-no-op stub: `QueueCoordinator.removeFromQueue`
- **File:** `Fonic HiFi/Core/Audio/Coordinators/QueueCoordinator.swift:99-104`
- **Evidence (verbatim):**
  ```swift
  /// Remove a track from the queue
  /// - Parameter trackId: ID of the track to remove
  public func removeFromQueue(trackId: String) {
      // Note: This would need to be implemented in AudioQueueManager
      logger.info("Removing track \(trackId) from queue")
  }
  ```
  `rg -w removeFromQueue "Fonic HiFi"` returns **only** this declaration — it is currently not called by any UI, so the incompleteness is latent.
- **Why it matters:** A `public` API that logs success ("Removing track…") while doing nothing is a trap: if a future "swipe to remove from queue" UI calls it, it will silently fail and the log will falsely suggest it worked.
- **Fix:** Either implement it (delegate to the queue manager) or delete the method until it's real. Implementation sketch:
  ```swift
  public func removeFromQueue(trackId: String) async {
      guard let uuid = UUID(uuidString: trackId) else { return }
      await queueManager.remove(trackID: uuid)   // add matching API to AudioQueueManager
      logger.info("Removed track \(trackId) from queue")
  }
  ```

### [Medium] Dead helper types inside otherwise-live files (dead members)
These files ARE used (their primary type is live), but they carry dead sub-types. Lower priority than whole-file deletions but still cruft.
- `Fonic HiFi/Presentation/Views/Home/HomeView.swift` — `HomeView` is live (`ContentView.swift:29`), but `HomeSection`, `EmptyHomeView`, `AlbumCardView`, `CarouselView`, `TrackCardView` have zero external references (dead helpers). Evidence: per-type `rg -w` returns only HomeView.swift.
- `Fonic HiFi/Presentation/Views/Components/GlassControls.swift` — `FluidProgressView`, `GlassButton`, `GlassCard`, `GlassInteractiveButtonStyle` unused (file's other glass helpers are used elsewhere).
- `Fonic HiFi/Presentation/Views/Components/GlassModifiers.swift` — `A11yAwareGlassModifier`, `AdaptiveGlassModifier`, `AdaptiveGlassPerformanceModifier`, `ClearGlassFixModifier`, `FrameRateControlModifier`, `GlassPerformanceProfileModifier`, `GlassSurfaceModifier`, `GlassTransitionModifier`, `PlayingParticlesModifier`, `BatteryOptimizedGlassUtilities`, `GlassEffectMemoryManager`, `GlassPerformanceProfiler`, `MemoryPressureLevel`, `PerformanceMetric`, `GlassElementType` — a large cluster of unused glass modifiers/utilities.
- `Fonic HiFi/Presentation/Views/Components/AccessibilityEnhancements.swift` — `AccessibilityEnhancements_Previews` (PreviewProvider), `AdaptiveDynamicTypeModifier`, `AssistiveAccessModifier`, `AudioContextAccessibilityModifier`, `EnhancedAccessibilityModifier`, `KeyboardNavigationModifier`, `PlaybackControlAccessibility`, `ProgressControlAccessibility`, `SearchAccessibility` unused.
- `Fonic HiFi Widget/Views/StandByAdaptive.swift` — `StandByAdaptive` (ViewModifier), `StandByAwareContainer`, `StandByEnvironment` unused; note `StandByColors`/`StandByFont`/`StandBySizes` in the same file ARE used by widget views (`SmallWidgetView.swift:27` etc.), so the file stays.
- `Fonic HiFi/Core/AI/Recommendations/RecommendationSchemas.swift` — `MixDefinition` (`tests:1`, prod:0) is a dead schema type; sibling schemas are used.
- `Fonic HiFi/Data/Extensions/SwiftDataPagination.swift` — `BatchProcessor` (`tests:1`, prod:0) dead; `PaginatedFetchDescriptor` in same file is tested too but also has no prod caller — verify.
- `Fonic HiFi/Domain/UseCases/LibraryUseCases.swift` — `LibrarySearchRequest` is a dead member (the rest of the file — `DefaultLibraryUseCases` + `Fetch*PageUseCase` protocols — IS live, used by `LibraryViewModel.swift:47-55`).
- **Fix:** Delete the individual unused types. Grouped by file, these total ~40 dead types. Each removal is low-risk; build after removing a file's worth. **SUSPECTED** for any type that might be referenced only via a `.modifier()`/View-extension name I did not enumerate — build to confirm.

### [Medium] Standalone dead view files (smaller)
- `Fonic HiFi/Presentation/Views/Search/SearchPlaylistResultsView.swift:1-85` — `SearchPlaylistResultsView` + `SearchPlaylistRow`, zero external refs. (The live search screen `SearchView.swift` has its own private playlist row.)
- `Fonic HiFi/Presentation/Views/NowPlaying/DiagnosticsDetailView.swift:1-153` — `DiagnosticsDetailView`, referenced only by its own `#Preview` (line 122). Not presented from any live NowPlaying view.
- `Fonic HiFi/Presentation/Views/Components/BottomSearchBar.swift:1-197` — `BottomSearchBar` + `BottomSearchContainer`, zero external refs (the app uses `SearchView`'s own search field).
- **Fix:** Delete these three files; rebuild.

### [Low] `#if DEBUG` blocks — all legitimate (no action, documented for completeness)
- **Files:** `DataManager+Initialization.swift:156` (`debugModelContainer()` fallback), `MainActorHelpers.swift:15,24,34`, `AVAudioEngineAdapter.swift:185,199,224,234,239,248,259`, `AudioEngineFacade.swift:123,648`, `PlaybackStateStore.swift:239`, `StandByAdaptive.swift:190`.
- **Evidence:** e.g. `DataManager+Initialization.swift:155-159` wraps a debug-only container-diagnostics call with a clean `#endif`; no `#else` hides production behavior. No feature is gated off by a permanently-false flag.
- **Why it matters:** None — this is correct usage. Listed so the reader knows it was checked.

### [Low] Deferred-task `Task.sleep` calls — legitimate (no action)
- **File:** `Fonic HiFi/FonicHiFiApp.swift:198-228` uses `try? await Task.sleep(for: .seconds(3/5/8))` to defer non-launch-critical work (missing-file cleanup, stats logging, relationship backfill), each clearly commented "not launch-critical". This is a valid launch-responsiveness pattern, not an artificial stall. Other `Task.sleep` uses (search debounce `SearchView.swift:98`, `SleepTimerManager`, `ProgressTimerManager`, polling loops) are all functional. Two `Task.sleep`s at `BottomSearchBar.swift:113,138` and one at `AccessibilityEnhancements.swift:386` live inside dead code (covered above).

---

## Feature-completeness deep-dives

### Smart Search (AI) — COMPLETE, not stubbed
- `Fonic HiFi/Core/AI/Search/SmartSearchService.swift:40-111` performs a real `session.respond(to: prompt, generating: SmartSearchResult.self)` against on-device `SystemLanguageModel`/`LanguageModelSession`, with availability gating (`isSmartSearchAvailable`, lines 22-29), guardrail/context-window error handling (lines 97-110), and a deliberate rule-based `fallbackSearch` (lines 117-141) that returns empty to defer to standard search. Wired: `SmartSearchService` → `SmartSearchViewModel.swift` → `SearchView`. `RecommendationService.swift:1-191` is equally real (`session.respond` at lines 66, 124) and wired into `HomeView.swift`. **No AI stubs found.**

### EQ — COMPLETE, not partial (EQ.md doc has minor stale line refs)
- Config model `Fonic HiFi/Core/Audio/DSP/EqualizerConfiguration.swift` defines the full 10-band model, ±12 dB clamp (`EQBand.init` line 23), `preampGain` anti-clip (lines 46-49), and 5 presets (Flat/Bass Boost/Treble Boost/Vocal/Rock, lines 61-127) — matching EQ.md §5.1.
- Applied end-to-end: `AVAudioEngineAdapter.swift:52` `private let eqNode = AVAudioUnitEQ(numberOfBands: 10)`; `configureEQBands()` (lines 479-497) sets frequencies `[32,64,125,250,500,1000,2000,4000,8000,16000]`, shelf filters on bands 0/9, parametric elsewhere; `applyEQ(_:)` (lines 656-671) maps each `EQBand`'s frequency/bandwidth/gain onto the live node and implements **true bit-perfect bypass** by removing the EQ node from the graph when disabled (lines 676-682). Flow: `EqualizerView` → `AudioEngineFacade` → `AudioEngineService` → adapter.
- **`EQBand` "orphan" flag is a FALSE POSITIVE:** `rg -w EQBand` returns only `EqualizerConfiguration.swift` because bands are consumed as an array (`configuration.bands.enumerated()`, `band.gain`) — the type name legitimately appears only in the model file.
- **Doc drift (Low):** `EQ.md:98` cites frequencies at `AVAudioEngineAdapter.swift:453` and bandwidth at `:458`; actual locations are lines 480 and 484. `EQ.md:257` cites `eqNode` at `:52` (correct). Recommend a doc refresh, but the EQ feature itself is fully implemented — arguably the most complete subsystem in the app.

---

## Inventory Tables

### Orphaned / suspected-unused symbols
Confidence: **High** = reference-counted to zero production consumers + verified not an entry point / conformance / preview target. **Suspected** = strong signal, recommend Xcode delete-and-build to confirm.

| Symbol(s) | File | Evidence (reference-count) | Confidence |
|---|---|---|---|
| `LiquidGlassTabBar`, `TabButton`, `TabItem` | Presentation/Views/Components/LiquidGlassTabBar.swift | `rg -w` → defining file only (decl + `#Preview` 139/157); app uses native `TabView`/`Tab` (ContentView.swift:28-46) | High |
| `LiquidGlassRail`, `LiquidGlassExpandableRail`, `LiquidGlassSegmentedTabs`, `InteractiveSheen` | Presentation/Views/Components/LiquidGlassRail.swift | `rg -w` → defining file only; `Tab` "external" ref is SwiftUI's `Tab` (collision) | High |
| `AlbumGridView`, `AlbumSortOrder`, `AlbumGridItem`, `AlbumDetailView`, `AlbumTrackRow` | Presentation/Views/Library/AlbumGridView.swift | all 5 types: 0 external files | High |
| `ArtistListView`, `ArtistRowView`, `ArtistAlbumsView`, `ArtistTracksView`, `ArtistSortOrder`, `ArtistViewMode` | Presentation/Views/Library/ArtistListView.swift | 0 external; sibling `ArtistDetailView` IS used (HomeView.swift:70) | High |
| `TrackListView`, `TrackSortOrder` | Presentation/Views/Library/TrackListView.swift | 0 external; sibling `TrackDetailView` IS used (NowPlayingContent.swift:135) | High |
| `ImportSession`, `ImportSessionProtocol`, `ImportProgress`, `ImportPhase`, `ValidationResult`, `ImportValidationIssue`, `ImportSessionError`, `ImportItem`, `ImportStatus` | Data/Services/ImportSession.swift | prod:0 (tests only for 2); sibling `ImportError` prod:2 survives | High |
| `AudioSettingsService` | Core/Services/AudioSettingsService.swift | prod:0, tests:1 (AudioSettingsServiceTests ×5) | High |
| `SearchCache` | Data/Services/SearchCache.swift | prod:0 (self only), tests:2 | High |
| `TrackCache` | Core/Audio/Cache/TrackCache.swift | prod:0 (self only), tests:1 | High |
| `PlaybackStateStore` (+`PlaybackStateConfiguration`,`PlaybackStateEvent`) | Core/Audio/Playback/PlaybackStateStore.swift | prod:0 (self-refs only), tests:1; app uses PlaybackStateManager | High |
| `LibraryFilter` | Presentation/ViewModels/Library/LibraryFilter.swift | prod:0; 10 calls all in LibraryFilterTests | High |
| `SearchPlaylistResultsView`, `SearchPlaylistRow` | Presentation/Views/Search/SearchPlaylistResultsView.swift | 0 external | High |
| `DiagnosticsDetailView` | Presentation/Views/NowPlaying/DiagnosticsDetailView.swift | referenced only by own `#Preview` (line 122) | High |
| `BottomSearchBar`, `BottomSearchContainer` | Presentation/Views/Components/BottomSearchBar.swift | 0 external | High |
| `HomeSection`, `EmptyHomeView`, `AlbumCardView`, `CarouselView`, `TrackCardView` | Presentation/Views/Home/HomeView.swift | dead members; `HomeView` itself is live | High |
| ~15 glass modifiers/utils (`A11yAwareGlassModifier`, `AdaptiveGlassModifier`, `GlassSurfaceModifier`, `GlassEffectMemoryManager`, `GlassPerformanceProfiler`, `BatteryOptimizedGlassUtilities`, …) | Presentation/Views/Components/GlassModifiers.swift | each `rg -w` → defining file only | High |
| ~9 accessibility modifiers (`AdaptiveDynamicTypeModifier`, `EnhancedAccessibilityModifier`, `KeyboardNavigationModifier`, `AudioContextAccessibilityModifier`, `AssistiveAccessModifier`, `PlaybackControlAccessibility`, `ProgressControlAccessibility`, `SearchAccessibility`) + `AccessibilityEnhancements_Previews` | Presentation/Views/Components/AccessibilityEnhancements.swift | each `rg -w` → defining file only | High |
| `GlassButton`, `GlassCard`, `FluidProgressView`, `GlassInteractiveButtonStyle` | Presentation/Views/Components/GlassControls.swift | dead members in live file | High |
| `StandByAdaptive` (ViewModifier), `StandByAwareContainer`, `StandByEnvironment` | Fonic HiFi Widget/Views/StandByAdaptive.swift | dead members; `StandByColors`/`Font`/`Sizes` live | High |
| `MixDefinition` | Core/AI/Recommendations/RecommendationSchemas.swift | prod:0, tests:1 | High |
| `BatchProcessor`, `PaginatedFetchDescriptor` | Data/Extensions/SwiftDataPagination.swift, Data/Repositories/PaginatedFetch.swift | prod:0, tests:1 each — verify pagination path | Suspected |
| `LibrarySearchRequest` | Domain/UseCases/LibraryUseCases.swift | dead member (rest of file is live via LibraryViewModel) | High |
| `AlbumFilter`, `ArtistFilter`, `TrackFilter`, `PlaylistSortOrder`, `SmartPlaylistField`, `SmartPlaylistOperator`, `LogicalOperator`, `PlaylistType`, `AlbumType` (model sub-enums) | Data/Models/{Album,Artist,Track,Playlist}.swift | `rg -w` → only within their own model file. Some are `CaseIterable` public enums that may be used dynamically; **verify** | Suspected |
| `AccessoryCircularGaugeView` | Fonic HiFi Widget/Views/AccessoryCircularView.swift | dead member; `AccessoryCircularView` sibling is live | High |
| `NowPlayingWidgetView`, `NowPlayingTimelineProvider`, `WidgetArtworkLoader`, `FonicWidgetBundle`, `FonicHiFiApp` | (widget/app) | **NOT dead — false positives.** `NowPlayingWidgetView` used at NowPlayingWidget.swift:21; `NowPlayingTimelineProvider` at :19; `WidgetArtworkView` (sibling of WidgetArtworkLoader) used by 4 widget views; `FonicWidgetBundle`/`FonicHiFiApp` are `@main`. Listed to show they were checked. | N/A |

*Full reference-count data preserved at `/tmp/orphanfinal.txt` and `/tmp/orphans.txt` during the audit session (sandbox-local, not committed).*

### TODO / FIXME ledger
| File:line | Text | Assessed importance |
|---|---|---|
| Core/Audio/Coordinators/QueueCoordinator.swift:102 | `// Note: This would need to be implemented in AudioQueueManager` | **Medium** — marks the no-op `removeFromQueue` stub (see High-severity finding); the only genuine "unimplemented" marker in the codebase |

Note: a repo-wide search for `TODO|FIXME|HACK|XXX` in production returns only 3 hits, **all false positives** — the substring `TXXX` (ID3v2 replay-gain frame) in `MetadataExtractionService.swift:82,363,369`. There are effectively **zero** TODO/FIXME/HACK comments and **zero** `fatalError`/`preconditionFailure`/`notImplemented` stubs in production.

### Debug leftovers
| File:line | Kind | Assessment |
|---|---|---|
| — | `print()` / `debugPrint()` / `dump()` / `NSLog()` | **None in production** (0 matches app + widget). Logging goes through `os.Logger` via `Log.logger(_:)`. |
| DataManager+Initialization.swift:156; MainActorHelpers.swift:15,24,34; AVAudioEngineAdapter.swift:185…259; AudioEngineFacade.swift:123,648; PlaybackStateStore.swift:239; StandByAdaptive.swift:190 | `#if DEBUG` | Legitimate debug helpers; no feature-hiding `#else`. No action. |
| FonicHiFiApp.swift:200,213,226 | `Task.sleep(3/5/8 s)` | Intentional deferral of non-launch-critical startup work; commented. No action. |

### Repo artifacts to remove / relocate
Git-tracked status verified via `git ls-files`; all dated 2025-12-07 (single bulk commit). None of these are under a synchronized source group, so none compile — but they clutter a production repo and several are stale/duplicated.

| Path | Size / count | Tracked? | Recommendation |
|---|---|---|---|
| `log.md` | 51 KB | yes | Delete — raw dev-session log, not documentation |
| `build_verify.log` | 29 KB | yes | Delete + fix .gitignore (see below) |
| `build_errors.log` | 17 KB | yes | Delete |
| `summary.md` | 13.5 KB | yes | Delete or fold into docs/ if it has lasting value |
| `Files-analysis.md` | 13.5 KB | yes | Delete — analysis of the `Files/` dump |
| `CLAUDE copy.md` | 15 KB (370 L vs CLAUDE.md 310 L) | yes | Delete — stale/divergent duplicate of CLAUDE.md (different md5, not a clean copy) |
| `Fonic HiFi.xcodeproj/project.pbxproj.backup` | — | yes | Delete — a checked-in backup of the project file |
| `docs/plans/2025-12-06-home-screen-discovery-design copy.md` | — | yes | Delete — duplicate "copy" of the sibling design doc |
| `Files/` | 102 markdown files | yes (102) | Relocate out of repo or into an archive branch — historical planning docs |
| `sample/` | 5 Xcode sample apps, 49 tracked files, 17 Swift files | yes (49) | Relocate to a separate reference repo. `sample/README.md` calls them "reference implementations"; `rg` confirms **no production or pbxproj reference** to any sample target. They don't ship, but bloat clone size and confuse tooling. |
| `docs/plans/` | 10 planning markdowns | yes | Keep if intentional living docs; otherwise archive |
| `.factory/`, `.kilocode/`, `.claude/` | agent-tool config dirs | yes | Team decision — fine to keep if the team uses these tools; otherwise `.gitignore` them |

**`.gitignore` is broken (Medium):**
- The final line reads `.apdiskbuild_verify.log` — a corrupted concatenation of a partial pattern (`.apdisk…`) and `build_verify.log` with no newline. As a result **`build_verify.log` is not actually ignored** (and is committed).
- `*.xcodeproj` is listed under the SPM section, yet `Fonic HiFi.xcodeproj` and the 5 `sample/*.xcodeproj` are force-tracked. This is inconsistent and a latent hazard (a re-`git add` of the project could be silently skipped). Recommend removing the `*.xcodeproj` line (the project must be tracked) and repairing the malformed last line, e.g.:
  ```gitignore
  # Various logs (dev-only)
  *.log
  build_errors.log
  build_verify.log
  ```

### Duplication
| Item | Files | Finding |
|---|---|---|
| Widget shared models triplicated | `Fonic HiFi/Shared/{WidgetConstants,WidgetPlaybackState,WidgetTrackInfo}.swift` vs `Fonic HiFi Widget/Shared/{same}.swift` | Byte-identical code (only the 4-line header comment differs — widget copy says "Standalone copy for widget extension"). Two compiled copies to keep in sync (drift risk). **Low** — intentional, but could be unified by adding one canonical file to both targets' membership. |
| CLAUDE docs | `CLAUDE.md` (310 L) vs `CLAUDE copy.md` (370 L) | Divergent, not a clean duplicate (different md5). One is stale — see artifacts table. |
| `V2`/`New`/`Old`/`Legacy`/`Deprecated` suffixed files | — | None found in production. |
| Same-name Swift files across dirs | only the 3 Widget/Shared triplicates above | No other same-name collisions. |

### Test hygiene
| Check | Result |
|---|---|
| `XCTSkip` | 30+ occurrences, **all legitimate environment guards** (e.g. `WidgetTrackInfoTests.swift:57 throw XCTSkip("App Group defaults unavailable")`, `AudioKitEngineAdapterTests.swift:9 XCTSkip("AudioKit engine failed to initialize in test environment")`). No permanently-disabled tests. |
| Commented-out test functions | None (`// func test` / `// @Test` → 0 matches) |
| Orphan test files (tests for deleted types) | **None.** Every test file maps to an existing production type; the "0-prod-type" hits (`AudioTestUtilities`, `ImportTestFixtures`, `UserDefaults+Sendable`) are Support/ helpers, and `MainActorHelpersTests` → live `MainActorHelpers`. |
| Frameworks | Mixed: 80 files `import XCTest`, 14 files `import Testing` (Swift Testing). ~400 `func test*` + ~54 `@Test` cases. |
| Note | The problem is inverse orphaning: `AudioSettingsServiceTests`, `SearchCacheTests`, `TrackCacheTests`, `PlaybackStateStoreTests`, `LibraryFilterTests`, `ImportSessionTests` keep otherwise-dead production modules compiling. Delete each such test alongside its dead source (see High findings). |

---

## STATUS.md / docs accuracy spot-check

`STATUS.md` (updated 2025-12-07) is largely accurate and well maintained. Spot-checks:

| STATUS.md claim | Verdict | Evidence |
|---|---|---|
| `WidgetArtworkLoader` ✅ (line 40) | **Accurate** | `WidgetArtworkView` (sibling in that file) used by 4 widget views (SmallWidgetView.swift:33, MediumWidgetView.swift:32, LargeWidgetView.swift:49,205, AccessoryRectangularView.swift:67) |
| `NowPlayingTimelineProvider` ✅ (line 39) | **Accurate** | used at NowPlayingWidget.swift:19 |
| `RecommendationService` / `SmartSearchService` ✅ Foundation Models with fallbacks (lines 52, 58) | **Accurate** | real `LanguageModelSession.respond` + fallbacks, wired to HomeView / SmartSearchViewModel |
| `LibraryImportService` ✅ (line 22) | **Accurate** | live; and it (not the dead `ImportSession`) is the real import path |
| ❌ `Core/Audio/Decoders/` DOES NOT EXIST (line 66) | **Accurate** | directory absent |
| ❌ LiveActivity / `LiveActivityManager.swift` NOT PLANNED (lines 67-70) | **Accurate** | `rg LiveActivityManager\|NowPlayingAttributes` → 0 matches |
| ❌ `PerformanceOptimizedContainer.swift` DELETED (line 74) | **Accurate** | absent |
| "347 tests" (line 6) | **Minor drift** | actual ≈400 `func test*` + ~54 `@Test` cases ≈ 454 test entry points; 347 may count only XCTest cases at that snapshot |
| Coverage "33.61%" (line 6) vs "45.36% (App 33.61%)" (line 80) | **Minor internal inconsistency** | line 6 shows only the app figure; harmonize wording |

`STATUS.md` does **not** describe any of the dead files above as live (it correctly omits `LiquidGlassTabBar`/`AlbumGridView`/`AudioSettingsService`/`ImportSession`), so the docs are not actively misleading about them — the dead code simply exists on disk without documentation.

`docs/plans/2025-12-06-eq-improvements.md` and the `docs/` plan set describe work that largely landed (EQ shelf filters, preamp gain, and bit-perfect bypass are all implemented as noted in the EQ deep-dive) — currency is acceptable; the only stale doc references are the line numbers in `EQ.md` (§2.2/§2.4) noted above.

---

## Confidence & caveats
- All "High" orphan claims were reference-counted across app + widget + test targets with the real ripgrep binary, and cross-checked for `@main`, protocol conformance, `#Preview`-only usage, and sibling-type usage. Because this is a Linux/no-Xcode static pass, the residual risk is a symbol referenced by a mechanism grep cannot see (Objective-C runtime string lookup, `#selector`, KVC key paths). None were observed, but the safe removal procedure is: delete the file/type in Xcode and build — the synchronized-folder setup means a green build after deletion is definitive proof the code was dead.
- "Suspected" items (model sub-enums like `AlbumType`/`TrackFilter`, `BatchProcessor`/`PaginatedFetchDescriptor`) are flagged because they are `public`/`CaseIterable` and could in principle be resolved dynamically; verify by build.
