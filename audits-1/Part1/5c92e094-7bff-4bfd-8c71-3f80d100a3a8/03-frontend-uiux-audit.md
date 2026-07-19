# Frontend UI/UX Audit — Fonic HiFi

**Scope:** SwiftUI frontend in `Fonic HiFi/Presentation/**` + `Fonic HiFi Widget/**`. Static review only (Linux sandbox, no Xcode render). iOS 26 minimum deployment is treated as correct.
**Method:** Mapped the view layer (`Presentation/` is the UI root; there is no `DesignSystem/` dir — tokens live in `Presentation/Constants/DesignTokens.swift`). Read the main screens fully (ContentView, NowPlayingContent, mini-player, HomeView, LibraryView, SearchView, EqualizerView, QueueView, ImportProgressView, glass components) and the full playback-state observation chain (`AudioEngineFacade` → `StateCoordinator` → `PlaybackStateManager` → `ProgressTimerManager`), then grepped systematically.

## Summary (worst first)

- **State-management paradigm is mixed and mis-wired for the player's core loop.** `AudioEngineFacade` is a legacy Combine `ObservableObject`, but every view reaches it via `@Environment(\.audioEngine)` (never `@StateObject`/`@ObservedObject`/`@EnvironmentObject`), and its `playbackProgress`/`currentTime`/`duration`/`isPlaying` are **computed** (not `@Published`). Progress updates only propagate because they transitively read a *nested* `@Observable` (`PlaybackStateManager`) — a fragile accident, not a design. (High → borderline Critical.)
- **The 0.5 s progress tick re-evaluates the entire `NowPlayingContent.body`** (720-line monolith: artwork, gradient, all controls, volume) every half-second, because the whole screen depends on one `PlaybackState` value. No subview isolation. This is the exact hotspot called out for a ticking player. (High.)
- **Smart-search results are un-playable and AI errors are silent.** `SearchView.playTrack` is a logging no-op placeholder; the VM's `.error` state has no UI branch. (Critical for the flagship "smart search" feature.)
- **No context menus and no swipe actions anywhere in the app** (0 occurrences). No Play Next / Add to Queue / Add to Playlist / Share on any track row. This is a table-stakes music-player omission. (High.)
- **The custom EQ slider (`VerticalSlider`) has zero accessibility** — VoiceOver users cannot set EQ bands at all. (High a11y blocker.)
- **A large, well-built accessibility layer (`AccessibilityEnhancements.swift`, 458 lines) is entirely unused** — player controls use ad-hoc labels instead. The `a11yAwareGlass`/Reduce-Transparency-aware modifier is also unused, so the glass surfaces that ARE used ignore Reduce Transparency. (High.)
- **Fake glassmorphism coexists with real Liquid Glass:** `.ultraThinMaterial` stacks (ContinueListeningSection, ExpandableAlbumCard, ArtistsSection, GlassControls) and manual `strokeBorder` + `scaleEffect/opacity/blur` "glass" (GlassModifiers). Real `.glassEffect` pills sit inside a horizontal ScrollView with no `GlassEffectContainer` (GenresSection). (Medium–High, violates the house doc.)
- **Substantial dead UI code:** `LiquidGlassRail`, `LiquidGlassSegmentedTabs`, `LiquidGlassExpandableRail`, `LiquidGlassTabBar`, `BottomSearchBar`, all of `GlassControls.swift`, and four full library list views (`TrackListView`, `AlbumGridView`, `ArtistListView`, `PlaylistListView`, ~1,270 lines) are referenced only by their own `#Preview`s. Plus the whole `showMiniPlayer` `@Published` pipeline is never read. (Medium.)
- **Dynamic Type is effectively unsupported:** 37 `.font(.system(size:N))` call sites across 20 files; no `@ScaledMetric`; `dynamicTypeSize` only read inside the unused a11y modifier. (Medium.)
- **Design tokens exist but are thin and inconsistently applied** — no color/typography tokens, and magic paddings/sizes are scattered (mini-player `spacing: 15`, `padding 15/10`; many `spacing: 12`, fixed artwork/thumb sizes). (Medium.)

---

## Findings

### [High] Player state is a mixed `ObservableObject`/`@Observable` graph read only through `@Environment` — observation works by accident
- **File:** `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:22-23,40-45,66-69`; `Fonic HiFi/Presentation/Environment/AudioEnvironment.swift:14-24`; `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:15`; `Fonic HiFi/Presentation/Views/NowPlaying/LiquidGlassMiniPlayer.swift:14`
- **Evidence:**
  ```swift
  // AudioEngineFacade — legacy Combine ObservableObject…
  public final class AudioEngineFacade: ObservableObject {
      public var playbackProgress: Double { currentState.progress ?? 0.0 }   // computed, NOT @Published
      public var currentTime: TimeInterval { currentState.currentTime ?? 0.0 }
      @Published public private(set) var currentTrack: Track?                 // only these fire objectWillChange
  ```
  ```swift
  // …but injected as a plain optional through Environment (no ObservableObject subscription):
  struct AudioEngineKey: EnvironmentKey { static let defaultValue: AudioEngineFacade? = nil }
  ```
  ```swift
  @Environment(\.audioEngine) private var audioService: AudioEngineFacade?   // every consumer
  ```
- **Why it matters:** `@Environment` does **not** subscribe to `ObservableObject.objectWillChange`. Progress/time only reach the UI because `facade.playbackProgress` transitively reads `PlaybackStateManager.currentState`, which *is* `@Observable` and is read inside the view body. This is undocumented, implicit, and brittle: any refactor that caches the value, hops a thread, or reads it outside a tracked scope silently freezes the scrubber. It also means `objectWillChange.send()` calls sprinkled through the facade (lines 214, 221, 228…) do nothing for these `@Environment` consumers.
- **Fix:** Make the facade a first-class `@Observable` and expose it via the modern environment so tracking is explicit and reliable. Preserve the public API surface (`playbackProgress`, `currentTrack`, `isPlaying`, all command methods).
  ```swift
  import Observation
  @MainActor @Observable
  public final class AudioEngineFacade {          // drop ObservableObject + @Published
      public private(set) var currentTrack: Track?
      // computed reads of PlaybackStateManager stay fine — both are @Observable now
      public var playbackProgress: Double { stateCoordinator.currentState.progress ?? 0 }
      …
  }
  ```
  ```swift
  // AudioEnvironment.swift — @Observable objects belong in the Entry-based environment:
  extension EnvironmentValues { @Entry var audioEngine: AudioEngineFacade? = nil }
  ```
  Consumers keep `@Environment(\.audioEngine)` unchanged. Remove the now-defunct `objectWillChange.send()` calls and the `uiStateStore.$… .sink` bridge in `setupStateBindings()`.

### [High] The 0.5 s progress tick invalidates the whole Now Playing screen
- **File:** `Fonic HiFi/Core/Audio/Engine/PlaybackController.swift:276-293`; `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:59-101,375-435`
- **Evidence:**
  ```swift
  progressTimer.start(pollInterval: 0.5) { [weak self] in
      …
      stateManager.updateTime(time, duration: total)   // mutates the single observed PlaybackState
  }
  ```
  ```swift
  var body: some View {                    // one 720-line body; reads audioService?.playbackProgress,
      VStack(spacing: 0) {                 // currentTime, duration, isPlaying — everything re-evals on tick
          dragIndicator; headerBar; …
          albumArtworkView; trackInfoView; progressView; playbackControlsView; volumeView
      }
      .background(LinearGradient(colors: [theme.dominant.opacity(0.6), …]))   // re-drawn every 0.5 s
  ```
- **Why it matters:** Every half-second, SwiftUI re-evaluates artwork (`MorphableArtwork` also re-reads the engine), the multi-stop gradient, all six control buttons, and the volume slider — none of which change between ticks. On a premium player this shows up as scrubber micro-stutter and wasted GPU/CPU (and battery) during the most-viewed screen. `PlaybackStateManager.updateTime` already debounces <0.3 s deltas (line 158), which helps churn but not the *scope* of invalidation.
- **Fix:** Isolate the only per-tick-changing pieces (progress bar + time labels) into a small child view that owns the progress dependency, so the rest of the hierarchy is stable. Keep the seek/drag logic intact.
  ```swift
  private struct ScrubberSection: View {
      @Environment(\.audioEngine) private var audio: AudioEngineFacade?
      @Binding var sliderProgress: Double
      @Binding var isUserDragging: Bool
      var body: some View {                       // ONLY this view depends on playbackProgress/currentTime
          VStack(spacing: 6) {
              CustomProgressSlider(progress: $sliderProgress, onEditingChanged: { … },
                                   abLoopState: audio?.abLoopState, duration: audio?.duration)
                  .onChange(of: audio?.playbackProgress) { _, v in if !isUserDragging, let v { sliderProgress = v } }
              HStack { Text(format(audio?.currentTime ?? 0)); Spacer(); Text(format(audio?.duration ?? 0)) }
                  .monospacedDigit()
          }
      }
  }
  ```
  Then in `NowPlayingContent.body` replace the inline `progressView` with `ScrubberSection(...)`. Hoist the gradient into a `.background` computed from `theme.dominant` only (not inside the observed body path) so it isn't re-evaluated by progress changes.

### [Critical] Smart-search results cannot be played; AI failure state has no UI
- **File:** `Fonic HiFi/Presentation/Views/Search/SearchView.swift:44-76,180-184`; `Fonic HiFi/Presentation/ViewModels/SmartSearchViewModel.swift:12-18,90-95`
- **Evidence:**
  ```swift
  private func playTrack(_ track: Track) {
      // Delegate to audio engine via environment if available
      // For now, this is a placeholder - integrate with audioEngine environment
      logger.info("Playing track from smart search: \(track.title, privacy: .public)")
  }
  ```
  ```swift
  public enum SearchState: Equatable { case idle, searching, results, noResults, error(String) }
  ```
  `SearchView.body` (lines 44-76) branches on `.results`, `.noResults`, `.searching` — there is **no** `case .error` branch; an AI failure falls through to the generic empty/`EmptySearchView`.
- **Why it matters:** The headline "smart search" feature is a dead end: a tap logs a line and nothing plays, and if the on-device model errors the user sees a blank/empty screen with no explanation or retry. For the feature the app markets most, this reads as broken.
- **Fix (playback):** `SearchView` has no `audioEngine` in scope; ContentView already injects it into the Search tab (`ContentView.swift:51`). Wire it:
  ```swift
  @Environment(\.audioEngine) private var audioEngine
  @Environment(\.showingNowPlaying) private var showingNowPlaying
  private func playTrack(_ track: Track) {
      guard let audioEngine else { return }
      Task {
          audioEngine.setCurrentTrack(track)
          showingNowPlaying.wrappedValue = true
          try? await audioEngine.play(track: track)
          try? await dataManager?.addRecentSearch(searchText)
      }
  }
  ```
- **Fix (error UI):** add the missing branch before the generic fallback:
  ```swift
  } else if useSmartSearch, case let .error(message) = smartSearchViewModel.searchState {
      ContentUnavailableView {
          Label("Smart Search Unavailable", systemImage: "exclamationmark.triangle")
      } description: { Text(message) } actions: {
          Button("Use Standard Search") { useSmartSearch = false }
      }
  }
  ```

### [High] No context menus or swipe actions on any track/album/artist/playlist row
- **File:** whole app — 0 hits for `\.contextMenu` / `\.swipeActions`. Representative rows: `Fonic HiFi/Presentation/Views/Library/LibraryView.swift:195-215` (`tracksSection`), `Fonic HiFi/Presentation/Views/Library/TrackRowView.swift:24-66`, `Fonic HiFi/Presentation/Views/Search/SearchView.swift:197-199`.
- **Evidence:**
  ```swift
  ForEach(Array(viewModel.tracks.enumerated()), id: \.element.id) { index, track in
      TrackEntityRow(track: track) { selectedTrack = track }
          .contentShape(Rectangle())
          .onTapGesture { playTrack(track) }        // tap-to-play is the ONLY affordance
          .onAppear { loadNextPage(for: .tracks, index: index) }
  }
  ```
- **Why it matters:** Apple Music, and every serious audiophile library app, expose "Play Next", "Add to Queue", "Add to Playlist", "Go to Album/Artist", "Share", "Track Info" via long-press context menus and leading/trailing swipe. Their total absence makes the library feel like a demo: users cannot build a queue without opening each track, and cannot manage playlists from the list.
- **Fix:** Add a reusable menu + swipe to the row. `AudioEngineFacade` already has `enqueue`, `enqueueNext` (facade lines 456-461).
  ```swift
  TrackEntityRow(track: track) { selectedTrack = track }
      .onTapGesture { playTrack(track) }
      .contextMenu {
          Button { playNext(track) }  label: { Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") }
          Button { addToQueue(track) } label: { Label("Add to Queue", systemImage: "text.append") }
          Button { addToPlaylist(track) } label: { Label("Add to Playlist", systemImage: "music.note.list") }
          Divider()
          Button { selectedTrack = track } label: { Label("Track Info", systemImage: "info.circle") }
      }
      .swipeActions(edge: .trailing) {
          Button { addToQueue(track) } label: { Label("Queue", systemImage: "text.append") }.tint(.blue)
      }
      .swipeActions(edge: .leading) {
          Button { playNext(track) } label: { Label("Play Next", systemImage: "forward.end") }.tint(.orange)
      }
  ```
  Apply the same treatment in `SearchResultsListView`, Home rows, and `QueueRowView`.

### [High] Custom EQ `VerticalSlider` is completely inaccessible to VoiceOver
- **File:** `Fonic HiFi/Presentation/Views/Settings/EqualizerView.swift:169-222` (used at 91-104)
- **Evidence:**
  ```swift
  private struct VerticalSlider: View {
      @Binding var value: Float
      let range: ClosedRange<Float>
      var body: some View {
          GeometryReader { geometry in
              ZStack { … Circle().fill(.white)… }        // pure drag gesture, no a11y at all
              .gesture(DragGesture(minimumDistance: 0).onChanged { … })
          }
          .frame(width: 30)
      }
  }
  ```
  No `accessibilityElement`, `accessibilityLabel`, `accessibilityValue`, `accessibilityAdjustableAction`, or `.isButton`/adjustable trait anywhere (contrast `CustomProgressSlider.swift:109-125`, which does it correctly).
- **Why it matters:** A 10-band EQ is a core audiophile control. A VoiceOver user cannot read any band's gain or change it — the entire equalizer is unusable with assistive tech, and the 30 pt-wide hit area (line 220) is also below the 44 pt target. The frequency labels (`"32"…"16K"`, line 16) aren't associated with the sliders either.
- **Fix:** Make each band an adjustable element (the unused `AccessibilityEnhancements` layer isn't needed for this — inline it):
  ```swift
  VerticalSlider(value: $configuration.bands[index].gain, range: -12...12)
      .frame(width: 44, height: 140)               // widen hit target to 44 pt
      .accessibilityElement()
      .accessibilityLabel("\(frequencyLabels[index]) hertz band")
      .accessibilityValue(String(format: "%.1f decibels", configuration.bands[index].gain))
      .accessibilityAdjustableAction { direction in
          let g = configuration.bands[index].gain
          switch direction {
          case .increment: configuration.bands[index].gain = min(12, g + 0.5)
          case .decrement: configuration.bands[index].gain = max(-12, g - 0.5)
          @unknown default: break
          }
          selectedPreset = "Custom"; applyConfiguration()
      }
  ```

### [High] The accessibility subsystem is built but not wired in; used glass ignores Reduce Transparency
- **File:** `Fonic HiFi/Presentation/Views/Components/AccessibilityEnhancements.swift:83-361` (unused outside its own `PreviewProvider` at 412); `Fonic HiFi/Presentation/Views/Components/GlassModifiers.swift:209-258` (`A11yAwareGlassModifier`, exposed as `a11yAwareGlass()` at 357 — no call sites) vs `GlassSurfaceModifier:82-105` (the one actually used, via `glassSurface()`)
- **Evidence:**
  ```swift
  // GlassSurfaceModifier — the modifier that IS used (HomeView TrackCardView, GlassCard, LiquidGlassRail):
  func body(content: Content) -> some View {
      let glass = style.resolvedGlass(tint: tint, interactive: interactive, colorScheme: colorScheme)
      content.clipShape(shape).overlay(shape.strokeBorder(.white.opacity(strokeOpacity), lineWidth: 1))
          .glassEffect(glass, in: shape)            // no reduceTransparency / differentiateWithoutColor check
  }
  ```
  ```swift
  // A11yAwareGlassModifier — the a11y-correct version, never called:
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  if reduceTransparency { content.background(shape.fill(fallbackColor))… } else { …glassEffect… }
  ```
  `PlaybackControlAccessibility`, `ProgressControlAccessibility`, `audioContextAccessibility`, `adaptiveDynamicType`, `enhancedAccessibility` — all defined, none referenced by any screen.
- **Why it matters:** The app ships the *appearance* of accessibility investment without the wiring. Now Playing controls fall back to terse ad-hoc labels (`NowPlayingContent.swift:450,463,480`), and every real glass surface stays translucent even when the user has Reduce Transparency on — a legibility and comfort regression the codebase already knows how to prevent.
- **Fix:** (1) Route `glassSurface()` through the accessibility-aware path — either make `GlassSurfaceModifier` read `@Environment(\.accessibilityReduceTransparency)` and branch to a solid fill (copy the `A11yAwareGlassModifier` logic), or repoint the public `glassSurface()` to call the existing `a11yAwareGlass()` implementation. (2) Apply `PlaybackControlAccessibility` to the six Now Playing buttons instead of the bare labels. Preserve current visuals when Reduce Transparency is off.

### [High] Fake glassmorphism and un-contained glass violate the project's own Liquid Glass doc
- **File:** `Fonic HiFi/Presentation/Views/Home/Sections/ContinueListeningSection.swift:57`; `Fonic HiFi/Presentation/Views/Home/Sections/ExpandableAlbumCard.swift:36`; `Fonic HiFi/Presentation/Views/Home/Sections/ArtistsSection.swift:67`; `Fonic HiFi/Presentation/Views/Components/GlassControls.swift:84`; `Fonic HiFi/Presentation/Views/Home/Sections/GenresSection.swift:21-46`; `Fonic HiFi/Presentation/Views/Components/GlassModifiers.swift:99-103,107-118`
- **Evidence:**
  ```swift
  // ContinueListeningSection row — manual material pretending to be glass, inside a list of rows on Home:
  .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
  ```
  ```swift
  // GenresSection — real glass pills, but in a horizontal ScrollView with NO GlassEffectContainer:
  ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(genres) { GenrePillView($0) } } }
  //   GenrePillView: Text(genre).padding(…).glassEffect(.regular.interactive())
  ```
  ```swift
  // GlassModifiers — augmenting real glass with a manual stroke, and a fake "glass transition":
  .overlay(shape.strokeBorder(.white.opacity(strokeOpacity), lineWidth: 1)).glassEffect(glass, in: shape)
  // GlassTransitionModifier: .scaleEffect(...).opacity(...).blur(radius: isActive ? 1 : 0)
  ```
  The house doc (`.claude/reference/ios26-liquid-glass.md:289-313`) explicitly says "Always wrap multiple glass elements in `GlassEffectContainer`", "Avoid overlapping / glass-on-glass", and migrate `.ultraThinMaterial` → `.glassEffect()`.
- **Why it matters:** Three problems for a design-forward app: (a) the `.ultraThinMaterial` rows don't get Liquid Glass's light/reflection/vibrancy adaptation, so they look flat and inconsistent next to the real glass in GenresSection and the mini-player; (b) glass pills inside a horizontal ScrollView with no container each trigger their own sampling pass every frame while scrolling — the doc's named performance anti-pattern; (c) `GlassSurfaceModifier` layers a manual white stroke over real glass, fighting the material's own edge treatment. `LiquidGlassRail` compounds this by putting `.glassEffect()` on content *and* `.glassSurface()` (which calls `.glassEffect()` again) — literal glass-on-glass (`LiquidGlassRail.swift:36-40`).
- **Fix:** Standardize on real glass and containers.
  ```swift
  // GenresSection — wrap the row in a container so pills share one sampling pass:
  GlassEffectContainer(spacing: 12) {
      HStack(spacing: 12) { ForEach(genres, id: \.self) { GenrePillView(genre: $0)… } }
  }
  ```
  ```swift
  // ContinueListeningSection row — replace the material with glass (or glassSurface):
  .padding(12).glassEffect(in: .rect(cornerRadius: 12))
  ```
  Drop the manual `strokeBorder` overlay in `GlassSurfaceModifier` (let the material own its edge, or gate the stroke behind `differentiateWithoutColor`). Retire `GlassTransitionModifier`/`playingParticles` in favor of `.interactive()` glass, which the doc says already provides press scaling/shimmer.

### [Medium] View-model paradigm is inconsistent across the app
- **File:** `Fonic HiFi/Presentation/ViewModels/Library/LibraryViewModel.swift:16-31` (`ObservableObject` + `@Published`) vs `Fonic HiFi/Presentation/ViewModels/SmartSearchViewModel.swift:6-24` (`@Observable`) and `Fonic HiFi/Core/Audio/Playback/PlaybackStateManager.swift:14-20` (`@Observable`)
- **Evidence:**
  ```swift
  final class LibraryViewModel: ObservableObject { @Published private(set) var tracks: [TrackEntity] = [] … }
  ```
  ```swift
  @Observable public final class SmartSearchViewModel { public private(set) var searchState: SearchState = .idle … }
  ```
  Consumption is correspondingly split: `LibraryView` uses `@StateObject` + `.onReceive(viewModel.$lastError)` (`LibraryView.swift:47,170`), while `SearchView` uses plain `@State private var smartSearchViewModel` (`SearchView.swift:23`).
- **Why it matters:** Two observation systems in one codebase is a maintenance and correctness hazard — `.onReceive($lastError)` (LibraryView:170-172) is a Combine workaround that would be a plain `.onChange` under `@Observable`, and mixing invites the exact "which system is actually observing?" bug seen in the facade finding above.
- **Fix:** Migrate `LibraryViewModel` to `@Observable` (drop `@Published`, keep `private(set)`), switch `@StateObject`→`@State` in `LibraryView`, and replace `.onReceive(viewModel.$lastError)` with `.onChange(of: viewModel.lastError) { _, e in showingErrorAlert = e != nil }`. Preserve the pagination logic verbatim.

### [Medium] Large amounts of dead UI code and dead state plumbing
- **File:** `Fonic HiFi/Presentation/Views/Components/LiquidGlassRail.swift` (all 3 types), `Fonic HiFi/Presentation/Views/Components/LiquidGlassTabBar.swift:15`, `Fonic HiFi/Presentation/Views/Components/BottomSearchBar.swift:14`, all of `Fonic HiFi/Presentation/Views/Components/GlassControls.swift`, and `TrackListView.swift` / `AlbumGridView.swift` / `ArtistListView.swift` / `PlaylistListView.swift` — each referenced only by its own `#Preview`. Plus `showMiniPlayer`: `AudioEngineFacade.swift:67,160,561-563`, `AudioUIState.swift:14`, `StateCoordinator.swift:87,94`.
- **Evidence:** grep for each symbol returns only its definition + `#Preview`/preview harness. E.g. `LiquidGlassTabBar` → only `LiquidGlassTabBar.swift:15,139,157`; `TrackListView` → only its own file lines 13/174. `showMiniPlayer` is written in five places but read by **no** view — `ContentView.swift:58-68` shows the accessory unconditionally (`if let audioService`), never consulting it.
- **Why it matters:** ~1,270 lines of unused list views plus five unused glass components and a fully-plumbed-but-unread `@Published` pipeline (with `RunLoop.main` `.sink` bridging in the facade) inflate build size, confuse contributors about which components are canonical (there are two segmented-tab implementations and two track-detail screens), and hide the real observation graph. `TrackDetailView` (TrackListView.swift:86, *live* — used by NowPlayingContent) duplicates `TrackEntityDetailView` (LibraryView.swift:543).
- **Fix:** Delete the dead components and list views, or, if kept as a component library, move them under a clearly-marked `Components/Experimental/` and add doc comments. Remove the `showMiniPlayer` property + its `.sink` bridge, or actually gate the accessory on it (`if audioService.showMiniPlayer`). Consolidate the two track-detail views into one. (No behavior change — pure cleanup; verify each symbol truly has no non-preview reference before removal.)

### [Medium] Dynamic Type is not supported on custom-sized text
- **File:** 37 sites of `.font(.system(size:N))` across 20 files (e.g. `NowPlayingContent.swift:182,312,358,420,444,457,473,487,500,516`; `EqualizerView.swift:113`; `ContentView.swift:105`). No `@ScaledMetric` anywhere; `dynamicTypeSize` read only in the unused `AdaptiveDynamicTypeModifier` (`AccessibilityEnhancements.swift:153`).
- **Evidence:**
  ```swift
  Image(systemName: "list.bullet").font(.system(size: 18, weight: .medium))     // NowPlayingContent header
  Image(systemName: …).font(.system(size: 28, weight: .medium))                 // prev/next controls
  Text(String(format: "%.1f", …)).font(.system(size: 9, weight: .medium, design: .monospaced)) // EQ gain
  ```
- **Why it matters:** Fixed point sizes don't respond to the user's text-size setting, and control glyphs / the 9 pt EQ readout won't grow for low-vision users. Apple-native players scale their labels; audiophiles skew older and lean on Dynamic Type. The 9 pt monospaced gain value is below comfortable legibility even at default size.
- **Fix:** Prefer semantic text styles (`.font(.title3)`, `.body`, `.caption`) for text, and `@ScaledMetric` for glyph sizes that must be numeric:
  ```swift
  @ScaledMetric(relativeTo: .title2) private var controlGlyph: CGFloat = 28
  Image(systemName: "backward.fill").font(.system(size: controlGlyph, weight: .medium))
  ```
  For the EQ readout, use `.font(.caption2.monospacedDigit())` (scales) instead of a hard 9 pt. Keep the visual weight/design arguments.

### [Medium] `fullScreenCover` builds Now Playing inside an empty `ScrollView` + `safeAreaInset`
- **File:** `Fonic HiFi/ContentView.swift:70-82`
- **Evidence:**
  ```swift
  .fullScreenCover(isPresented: $showingNowPlaying) {
      ScrollView {}                                   // intentionally empty scroll view
          .safeAreaInset(edge: .top, spacing: 0) {
              NowPlayingContent(namespace: miniPlayerNamespace, dismiss: { showingNowPlaying = false })
                  .navigationTransition(.zoom(sourceID: "miniplayer", in: miniPlayerNamespace))
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(.background)
  }
  ```
- **Why it matters:** Hosting the entire player as a top `safeAreaInset` on an empty `ScrollView` is a workaround (the code comment in `NowPlayingContent.swift:5-6` admits it's "Used directly inside fullScreenCover's safeAreaInset for proper zoom transition"). It's fragile against safe-area/keyboard/rotation changes and makes the player non-scrollable — so at large Dynamic Type or on small devices the content (fixed `Spacer().frame(minHeight:…maxHeight:)` stack, `NowPlayingContent.swift:71-92`) can clip with no way to scroll. It also couples the zoom transition to an unusual layout.
- **Fix:** Present `NowPlayingContent` directly and let it own its layout; attach the zoom transition to the content root. If vertical overflow is a risk, wrap the real content in a `ScrollView` with the controls pinned:
  ```swift
  .fullScreenCover(isPresented: $showingNowPlaying) {
      NowPlayingContent(namespace: miniPlayerNamespace, dismiss: { showingNowPlaying = false })
          .environment(\.audioEngine, audioService)
          .navigationTransition(.zoom(sourceID: "miniplayer", in: miniPlayerNamespace))
  }
  ```
  Verify the zoom source still matches after removing the wrapper (it should — `matchedTransitionSource` is on the accessory at `ContentView.swift:62`). *UNVERIFIED — needs visual check in Xcode to confirm the transition still animates without the ScrollView host.*

### [Medium] Empty-library and empty-home states don't offer a tappable import action
- **File:** `Fonic HiFi/Presentation/Views/Library/LibraryView.swift:770-787` (`EmptyLibraryView`), `Fonic HiFi/Presentation/Views/Home/HomeView.swift:333-348` (`EmptyHomeView`)
- **Evidence:**
  ```swift
  struct EmptyLibraryView: View {
      var body: some View {
          VStack(spacing: 20) {
              Image(systemName: "music.note")…
              Text("Your Library is Empty").font(.title2).fontWeight(.semibold)
              Text("Import music to get started").font(.body).foregroundStyle(.secondary)
          }   // no button — import lives only in the toolbar '+' (LibraryView.swift:95-98)
      }
  }
  ```
- **Why it matters:** For an *offline* player, first run with zero tracks is the make-or-break moment. Both empty states tell the user to "import music" but neither gives them a button to do it — the only path is a small toolbar `+`. `ContentUnavailableView` with an action is the iOS-native pattern and would make the primary first-run task one tap away.
- **Fix:** Use `ContentUnavailableView` with a CTA that opens the existing import sheet (`showingImportView`):
  ```swift
  ContentUnavailableView {
      Label("Your Library is Empty", systemImage: "music.note.house")
  } description: {
      Text("Import your FLAC, ALAC, and other audio files to start listening.")
  } actions: {
      Button("Import Music") { showingImportView = true }.buttonStyle(.borderedProminent)
  }
  ```
  For `EmptyHomeView`, route the button to the Library tab's import (e.g. via a shared binding or `openURL("fonichifi://import")`). Preserve the current iconography.

### [Low] Now Playing "drag indicator" is decorative and the sheet isn't actually draggable
- **File:** `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:61,165-171`; dismissal only via `.accessibilityAction(.escape)` (158-160) and the `dismiss` closure.
- **Evidence:**
  ```swift
  private var dragIndicator: some View {
      Capsule().fill(.primary.secondary).frame(width: 35, height: 3)…   // looks draggable
  }
  ```
- **Why it matters:** The grabber signals "swipe down to dismiss", but this is a `fullScreenCover` (ContentView:70) with no drag-to-dismiss gesture wired to the indicator — only VoiceOver escape and (implicitly) the system. Users will swipe and nothing happens, which feels broken versus Apple Music's interactive dismiss.
- **Fix:** Either add a downward `DragGesture` on the header that calls `dismiss()` past a threshold, or switch to a large `.sheet` with `.presentationDetents([.large])` (which gives a real interactive grabber for free). If keeping the grabber decorative, at least make the whole header tappable to dismiss and mark the capsule `.accessibilityHidden(true)`.

### [Low] Widget "Now Playing" progress bar is static between 60 s refreshes; provider comment misstates its type
- **File:** `Fonic HiFi Widget/NowPlayingTimelineProvider.swift:11-13,33-53`; `Fonic HiFi Widget/Views/MediumWidgetView.swift:81-108`
- **Evidence:**
  ```swift
  /// Uses AppIntentTimelineProvider for interactive widget support [Verified-Apple]
  struct NowPlayingTimelineProvider: TimelineProvider {          // actually plain TimelineProvider
      refreshDate = Date().addingTimeInterval(60)                // playing: 1 entry per 60 s
  ```
  ```swift
  Capsule().fill(colors.primary).frame(width: geometry.size.width * CGFloat(entry.progress))  // frozen value
  ```
- **Why it matters:** The widget progress bar and `currentTime`/`remainingTime` labels only move on timeline reloads (~60 s), so they visibly lag and jump — noticeable for a "Now Playing" widget audiophiles glance at. The class comment claiming `AppIntentTimelineProvider` is misleading for maintainers (the control buttons do work via `Button(intent:)`, so interactivity is fine; it's just not that provider type).
- **Fix:** Render the elapsed/remaining time with a self-updating timer text and derive the bar from the same clock, so it ticks without extra reloads:
  ```swift
  if entry.isPlaying, let start = entry.playbackStartDate, let end = entry.trackEndDate {
      Text(timerInterval: start...end, countsDown: true).font(fonts.monospacedTime(size: 9))
      ProgressView(timerInterval: start...end, countsDown: false).progressViewStyle(.linear).tint(colors.primary)
  } else { /* existing static labels for paused */ }
  ```
  (Requires exposing start/end dates through the App Group entry.) Fix the doc comment to say `TimelineProvider`. *UNVERIFIED — depends on adding date fields to `NowPlayingEntry`; confirm App Group payload.*

---

## UX Enhancement Opportunities (options, not mandates — each tied to code read this session)

- **Now Playing: replace the volume `Slider` with an output-aware volume that respects the AirPlay route** — the screen already has `AirPlayRouteButton` (`NowPlayingContent.swift:199`) and a generic `Slider` (514-538). Consider `MPVolumeView`-backed control or at least labeling it "Volume" for VoiceOver (it currently has no accessibility label on the slider). Optional.
- **Now Playing: surface bit-perfect / hi-res status inline.** The facade computes rich `diagnosticsStatus` (`AudioEngineFacade.swift:493-534`) and there's a `DiagnosticsDetailView`, but the main player shows no quality badge. The medium widget already renders a `qualityBadge` (`MediumWidgetView.swift:61-69`) — mirroring a small "24/96 FLAC · Bit-Perfect" chip near the track title (335-348) would delight the target audience. Tie any chip to `theme.accent` for consistency.
- **Home carousels: unify the card treatment.** `TrackCardView` uses `.glassSurface` (HomeView:407) while `ContinueListeningRow` uses `.ultraThinMaterial` (ContinueListeningSection:57) and `AlbumCardView` uses none — three different row looks on one screen. Picking one (real glass) would tighten the Home visual system. Option, folds into the glass finding above.
- **Queue: show real artwork and a "play from here" affordance.** `QueueRowView` always draws a placeholder note (QueueRowView.swift:16-24) because `AudioTrack` carries no artwork; wiring `LazyArtworkView(trackId:)` (used everywhere else) and a tap-to-jump would bring the queue up to Apple Music parity. `onMove`/`onDelete` already exist (QueueView:48-49) — add a context menu with "Remove" + "Play Next" for discoverability.
- **Search: add scopes and result counts.** `SearchResultsListView` (SearchView:189-239) hard-caps sections (`prefix(10)`/`prefix(5)`) with a non-tappable "See all N tracks" label (200-206). Making that row a `NavigationLink` and adding `.searchScopes` (Tracks/Albums/Artists/Playlists) would match native search UX. The `SearchAccessibility` result-count announcer already exists (AccessibilityEnhancements:365-392) — wire it here.

## Design System Notes

- **Tokens exist but are partial.** `DesignTokens.swift` covers `Grid`, `CornerRadius`, `Spacing`, `Animation` — and these ARE used well in HomeView/NowPlayingContent/LibraryView. But there are **no color or typography tokens**, so colors are ad-hoc (`theme.accent`/`theme.dominant`/`theme.subtle` from `ThemePalette` for artwork theming, mixed with literal `.white`, `.orange`, `.purple`, `.gray.opacity(...)`, `Color(.systemGray5)` in EqualizerView:182). A `DesignTokens.Color` (semantic: `accent`, `favorite`, `smartSearch`, `warning`) and `DesignTokens.Typography` layer would let you kill the 37 `.font(.system(size:))` sites and the scattered purples/oranges.
- **Magic numbers persist alongside tokens.** The mini-player uses raw `spacing: 15`, `padding(.horizontal, 15)`, `padding(.trailing, 10)` (LiquidGlassMiniPlayer:19,25,31) instead of `DesignTokens.Spacing`; NowPlaying uses raw `Color.clear.frame(height: 6)` (66) and slider thumb `8`/`14` (CustomProgressSlider:23-24). Not wrong, but inconsistent with the token discipline shown elsewhere.
- **Two competing glass systems.** Real iOS 26 `.glassEffect` (GenresSection, LyricsView, LiquidGlassRail) vs the custom `glassSurface`/`GlassCard`/`ultraThinMaterial` stack (GlassModifiers, GlassControls, Home sections). The house doc (`.claude/reference/ios26-liquid-glass.md`) clearly favors the former; consolidating on `.glassEffect` + `GlassEffectContainer` and deleting the material-based imitations (see the glass finding) is the single biggest lever for design-system coherence.
- **Color theming pipeline is a strength.** `DominantColorService` → `ThemePalette` → `\.themePalette` environment (ContentView:83, NowPlayingContent:18) is a clean, Apple-native artwork-adaptive accent system; the accent play button (NowPlayingContent:471) and tinted sliders read well against the dominant-color gradient. Worth extending into the Home cards and Library "now playing" row highlight (`TrackRowView.swift:61` already uses `theme.subtle`).
