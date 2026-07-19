# Glassline — SwiftUI UI/UX audit

**Repository:** `/agent/workspace/fonic-hifi-audit`
**Audited snapshot:** `main` @ `459db9bfd18d17960e8fd2ff8defc4701085532e`
**Audit date:** 2026-07-09
**Scope:** active iOS app paths rooted at `FonicHiFiApp` → `ContentView`, including Home, Library/import, Search, Now Playing, Queue, Settings/File Manager, responsive behavior, and iOS 26 Liquid Glass integration. Preview-only custom rails/tab bars and sample projects were not treated as active product UI.
**Reference skills loaded:** Axiom: SwiftUI; Axiom: iOS Audit Agents; Axiom: Apple Docs Research. Axiom: Design & HIG was additionally loaded for the requested Liquid Glass review.
**Method boundary:** static inspection only. This Linux environment has no Xcode or Apple SDK. No build, simulator, device, VoiceOver, rotation, or visual Liquid Glass result is claimed.

## Conclusion

The active UI keeps Fonic HiFi's existing four-tab identity and already uses the correct iOS 26 structural direction — native `TabView`, a `.search` tab, tab-bar minimization, a bottom player accessory, standard navigation/toolbars, and restrained custom Liquid Glass on active screens. The audit did **not** recommend a redesign, renamed features, new branding, new colors, or a replacement navigation model.

The principal production risk is state and interaction reliability, not visual taste. The app-wide `AudioEngineFacade` is an `ObservableObject` passed through an unobserved custom environment value, while Now Playing separately persists shuffle/repeat/speed display state. This can leave primary playback UI stale or contradictory. Several visible controls are inert or unreachable (settings actions, Smart Search mode, browse rows), runtime errors become false empty/no-results states, Now Playing lacks a visible dismissal action and height-adaptive scroll contract, queue edits translate displayed offsets incorrectly, and the import sheet-to-progress handoff is race-prone. The iOS 26 tab accessory also does not react to its inline placement, which Apple explicitly demonstrates for mini players.

**Retained findings: 20 — 5 High, 13 Medium, 2 Low.**
**Confidence: 17 confirmed by static evidence, 3 probable.**
**Native iPad support:** not enabled (`TARGETED_DEVICE_FAMILY = 1`); iPad-specific redesign findings were therefore not invented. iPhone portrait and both landscape orientations are declared and must be verified.

## Findings table

| ID | Severity | Confidence | Finding |
|---|---|---|---|
| UIUX-001 | High | Confirmed by static evidence | The app-wide audio model is injected as an unobserved environment value |
| UIUX-002 | High | Confirmed by static evidence | Now Playing duplicates authoritative shuffle, repeat, and speed state |
| UIUX-003 | Medium | Confirmed by static evidence | The mini player is always shown, including with no track |
| UIUX-004 | Medium | Probable | The iOS 26 tab accessory never adapts to inline placement |
| UIUX-005 | Medium | Probable | Full-screen Now Playing has no visible dismissal control |
| UIUX-006 | Medium | Probable | Now Playing has no height-adaptive scrolling contract for landscape or large text |
| UIUX-007 | Medium | Confirmed by static evidence | Sleep-timer ownership is transient and its volume baseline is hard-coded |
| UIUX-008 | High | Confirmed by static evidence | Settings exposes inert controls/actions that do not change the claimed feature |
| UIUX-009 | High | Confirmed by static evidence | Playback and browse failures are logged but surfaced as silence or false emptiness |
| UIUX-010 | High | Confirmed by static evidence | Import progress is unobserved; picker errors are invisible; presentation depends on a race |
| UIUX-011 | Medium | Confirmed by static evidence | Smart Search is effectively unreachable from the active Search states |
| UIUX-012 | Medium | Confirmed by static evidence | Multiple browse affordances have no destination or action |
| UIUX-013 | Medium | Confirmed by static evidence | Queue edit controls are undiscoverable and displayed offsets are translated incorrectly |
| UIUX-014 | Low | Confirmed by static evidence | Audio Settings nests a second navigation stack inside the Settings stack |
| UIUX-015 | Medium | Confirmed by static evidence | Active tap targets use raw gestures instead of semantic controls |
| UIUX-016 | Low | Confirmed by static evidence | “Reset All Settings” executes immediately without confirmation |
| UIUX-017 | Medium | Confirmed by static evidence | File Manager's multi-select actions have no touch-only edit-mode entry |
| UIUX-018 | Medium | Confirmed by static evidence | Every library pagination fetch presents a full-screen blocking loader |
| UIUX-019 | Medium | Confirmed by static evidence | “Surprise Me” has tracked loading state that the UI never renders |
| UIUX-020 | Medium | Confirmed by static evidence | The 10-band EQ is a gesture-only fixed-width control |

---

## Full findings

### UIUX-001 — The app-wide audio model is injected as an unobserved environment value

- **Severity:** High
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/FonicHiFiApp.swift:16-24,103-110`
  - `Fonic HiFi/Presentation/Environment/AudioEnvironment.swift:13-23,88-96`
  - `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:22-23,62-69`
  - `Fonic HiFi/ContentView.swift:12-15,58-68`
  - `Fonic HiFi/Presentation/Views/NowPlaying/LiquidGlassMiniPlayer.swift:13-15,36-48,55-74`
  - `Fonic HiFi/Presentation/Views/NowPlaying/MorphableArtwork.swift:14-17,31-40`
- **Source excerpt:**

  ```swift
  struct AudioEngineKey: EnvironmentKey {
      static let defaultValue: AudioEngineFacade? = nil
  }
  ```

  ```swift
  @Environment(\.audioEngine) private var audioService
  ```

  ```swift
  @Published public private(set) var currentTrack: Track?
  @Published public private(set) var showMiniPlayer: Bool = false
  ```

- **Why this is defective:** `AudioEngineFacade` uses Combine's `ObservableObject`/`@Published`, but views retrieve it through a plain custom `EnvironmentValue`. That passes the reference; it does not subscribe the view to `objectWillChange` as `@ObservedObject`, `@StateObject`, or `@EnvironmentObject` does. `MorphableArtwork` is the clearest execution path: its body only reads the facade's `@Published currentTrack.artwork`, so a track change creates neither an `ObservableObject` subscription nor an Observation dependency and has no guaranteed invalidation source. The same applies to direct reads of `currentTrack`, `showMiniPlayer`, and `diagnosticsStatus`. Some computed playback values happen to traverse nested `@Observable` managers and may invalidate independently, but that does not repair the facade's published-state boundary. Stale title/artwork/accessory/diagnostic UI remains a high-risk common playback path.
- **Apple guidance:** Apple describes `StateObject` as the single source of truth for an `ObservableObject`, and `environmentObject(_:)`/`@EnvironmentObject` as the mechanism that supplies and subscribes descendants to it ([A1], [A2]). Apple's Observation guide separately says plain `@Environment` tracking applies to types using the `@Observable` macro, which this facade does not ([A3]).
- **Preserving remediation:** Keep the facade and current environment-wide architecture, but make the app own it with `@StateObject` and expose it with `environmentObject`; consume it with `@EnvironmentObject`. Alternatively, migrate the facade completely to `@Observable` and continue type/custom-environment injection, but do not mix the two observation systems at this boundary.
- **Unapplied sample (minimal Combine path; compile/device validation required):**

  ```swift
  // FonicHiFiApp
  @StateObject private var audioService: AudioEngineFacade

  init() {
      let resolution = Self.resolveInitialization(/* existing arguments */)
      _audioService = StateObject(wrappedValue: resolution.audioService)
      // Preserve the remaining existing assignments.
  }

  ContentView()
      .environmentObject(audioService)
  ```

  ```swift
  // Active consumers
  @EnvironmentObject private var audioService: AudioEngineFacade
  ```

  Update previews to inject `.environmentObject(AudioEngineFacade())`. Remove the optional custom audio key only after all active consumers have migrated.
- **Verification / acceptance:**
  1. Start track A, allow automatic advance to track B, and verify mini-player title/artwork, expanded title/artwork, play icon, elapsed time, queue, and diagnostics all update without reselecting a tab.
  2. Pause/resume using Control Center and an App Intent; verify every visible play/pause control updates.
  3. Restore a queue on relaunch; verify the accessory appears with the restored track.
  4. Acceptance: each published playback mutation invalidates only relevant views; no stale title/artwork/control state remains.
- **Related:** UIUX-002, UIUX-003, UIUX-004.

### UIUX-002 — Now Playing duplicates authoritative shuffle, repeat, and speed state

- **Severity:** High
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:23-50,218-280,439-507,660-679`
  - `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:40-60,228-237,464-469`
  - `Fonic HiFi/Core/Audio/Queue/QueueState.swift:24-28,60-67`
  - `Fonic HiFi/Core/Intents/ToggleShuffleIntent.swift:22-40`
- **Source excerpt:**

  ```swift
  @State private var playbackSpeed: Double = 1.0
  @AppStorage("isShuffleEnabled") private var isShuffleEnabled: Bool = false
  @AppStorage("repeatMode") private var repeatModeRawValue: String = QueueRepeatMode.none.rawValue
  ```

  ```swift
  let currentMode = engine.queueState.shuffleMode
  engine.setShuffleMode(newMode)
  ```

- **Why this is defective:** the queue and engine already own `shuffleMode`, `repeatMode`, and `playbackRate`, including restored queue state and App Intent changes. The view instead renders and computes its next action from unrelated local/defaults state. After queue restore or `ToggleShuffleIntent`, the displayed tint/accessibility label can disagree with actual playback; tapping Shuffle may set `.random` again instead of turning it off. Playback rate is restored by the engine settings store, while the menu always starts at `1.0`, so its checkmark and active badge can be wrong. This violates the single-source-of-truth contract for primary playback controls.
- **Apple guidance:** Apple's model-data guidance says SwiftUI data tools help maintain “a single source of truth for every piece of data,” and bindings should connect controls to that source rather than duplicate it ([A1], [A3]).
- **Preserving remediation:** derive display state and action transitions from `audioService.queueState` and `audioService.playbackRate`; remove these local/AppStorage mirrors. Persistence remains in the existing queue/settings owners.
- **Unapplied sample (requires UIUX-001 observation fix and Xcode validation):**

  ```swift
  private var isShuffleEnabled: Bool {
      audioService?.queueState.shuffleMode.isActive ?? false
  }

  private var repeatMode: QueueRepeatMode {
      audioService?.queueState.repeatMode ?? .none
  }

  private var playbackSpeed: Double {
      audioService?.playbackRate ?? 1.0
  }
  ```

  ```swift
  private func toggleShuffle() {
      guard let audioService else { return }
      let next: QueueShuffleMode = audioService.queueState.shuffleMode.isActive ? .off : .random
      audioService.setShuffleMode(next)
  }
  ```

  Apply the same authoritative-state pattern to repeat and speed; do not write the view-only defaults keys.
- **Verification / acceptance:** restore shuffle/repeat/speed, toggle shuffle from the widget/App Intent while Now Playing is open, and cycle controls. Acceptance: tint, symbol, checkmark, VoiceOver label, queue behavior, and persisted value agree after every external and local change.
- **Related:** UIUX-001.

### UIUX-003 — The mini player is always shown, including with no track

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/ContentView.swift:58-69`
  - `Fonic HiFi/Presentation/Views/NowPlaying/LiquidGlassMiniPlayer.swift:36-48,55-74`
  - `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:66-68,538-550`
- **Source excerpt:**

  ```swift
  .tabViewBottomAccessory {
      if let audioService {
          LiquidGlassMiniPlayer(namespace: miniPlayerNamespace)
  ```

  ```swift
  Text(audioService?.currentTrack?.title ?? "Not Playing")
  ```

- **Why this is defective:** `audioService` exists for the app's lifetime, so this condition always inserts the accessory. The facade already exposes `showMiniPlayer` and clears it when the track becomes `nil`, but `ContentView` ignores it. A fresh/empty library therefore loses vertical space to “Not Playing / No Artist”; tapping the accessory still presents a control surface with no playable item.
- **Apple guidance:** SwiftUI's bottom-accessory API defines the accessory as conditional content and provides a dedicated dynamic-visibility overload on iOS 26.1+ ([A4]). Because this target starts at iOS 26.0, the preserving fix must either conditionally emit content with the original iOS 26 API or availability-gate the newer overload.
- **Preserving remediation:** gate the existing accessory using the existing facade visibility/track state; do not change its styling or placement and do not raise the deployment target solely for this fix.
- **Unapplied iOS 26.0-compatible sample (depends on UIUX-001; device validation required):**

  ```swift
  .tabViewBottomAccessory {
      if audioService.showMiniPlayer, audioService.currentTrack != nil {
          LiquidGlassMiniPlayer(namespace: miniPlayerNamespace)
              .environmentObject(audioService)
      }
  }
  ```

  If conditional builder content proves unstable on the pinned iOS 26.0 runtime, apply the accessory modifier conditionally to the whole `TabView`; on iOS 26.1+, the `isEnabled:` overload is the explicit alternative.
- **Verification / acceptance:** test iOS 26.0 and current iOS 26.x: clean launch with empty library (no accessory), start playback (accessory appears), clear current track (accessory hides), restore queue on relaunch (accessory appears). No blank Now Playing can be opened.
- **Related:** UIUX-001, UIUX-004.

### UIUX-004 — The iOS 26 tab accessory never adapts to inline placement

- **Severity:** Medium
- **Confidence:** Probable
- **Code:**
  - `Fonic HiFi/ContentView.swift:55-69`
  - `Fonic HiFi/Presentation/Views/NowPlaying/LiquidGlassMiniPlayer.swift:13-32,36-74`
- **Source excerpt:**

  ```swift
  .tabBarMinimizeBehavior(.onScrollDown)
  .tabViewBottomAccessory {
  ```

  ```swift
  HStack(spacing: 15) {
      playerInfo
      Spacer(minLength: 0)
      playPauseButton
      nextButton
  }
  ```

- **Why this is risky:** the tab bar is configured to minimize, but the accessory always renders artwork, two text lines, Play/Pause, and Next. In iOS 26 the accessory becomes inline with the minimized tab bar, where substantially less width is available. On narrow iPhones, long metadata, and large Dynamic Type, content can truncate excessively or compete with tab items.
- **Apple guidance:** Apple's iOS 26 SwiftUI session says to read `tabViewBottomAccessoryPlacement` and adjust the accessory when it collapses; Apple's Music example hides some media controls inline ([A5]). The API documentation also states that placement changes with tab-bar size ([A4]).
- **Preserving remediation:** keep the current mini-player identity and controls, but render a compact subset when placement is `.inline`.
- **Unapplied sample (API spelling must be confirmed with the iOS 26 SDK):**

  ```swift
  @Environment(\.tabViewBottomAccessoryPlacement) private var placement

  var body: some View {
      HStack(spacing: 12) {
          MorphableArtwork(size: placement == .inline ? 24 : 30, namespace: namespace)
          if placement != .inline { trackText }
          Spacer(minLength: 0)
          playPauseButton
          if placement != .inline { nextButton }
      }
  }
  ```

- **Verification / acceptance:** on the smallest supported iPhone, scroll each tab until the bar minimizes. Test short/long titles and Dynamic Type default/AX3. Acceptance: no overlap, clipped controls, ambiguous tap region, or tab obstruction in either `.expanded` or `.inline` placement.
- **Related:** UIUX-003, UIUX-006.

### UIUX-005 — Full-screen Now Playing has no visible dismissal control

- **Severity:** Medium
- **Confidence:** Probable
- **Code:**
  - `Fonic HiFi/ContentView.swift:70-82`
  - `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:20-21,59-67,158-171,175-203`
- **Source excerpt:**

  ```swift
  let dismiss: () -> Void
  ```

  ```swift
  .accessibilityAction(.escape) {
      dismiss()
  }
  ```

  ```swift
  Capsule()
      .frame(width: 35, height: 3)
  ```

- **Why this is risky:** the only invocation of the supplied dismiss closure is the accessibility escape action. The visible capsule looks like a drag indicator but has no gesture, and the header only exposes Queue and AirPlay. `fullScreenCover` requires the app to provide a dismissal path by changing the binding or invoking `dismiss`; the source does not establish a visible path. Users who do not know or cannot perform the escape gesture can be trapped in Now Playing.
- **Apple guidance:** Apple's `fullScreenCover` example includes an explicit action that changes the presentation binding, and SwiftUI's modal documentation exposes `DismissAction` for this purpose ([A6], [A7]). The escape action is useful but should not be the sole visible interaction.
- **Preserving remediation:** add one conventional close/chevron-down button to the existing header and retain the escape action. Do not change the full-screen presentation or navigation model.
- **Unapplied sample:**

  ```swift
  Button(action: dismiss) {
      Image(systemName: "chevron.down")
          .frame(width: 44, height: 44)
  }
  .buttonStyle(.plain)
  .accessibilityLabel("Dismiss Now Playing")
  ```

- **Verification / acceptance:** present/dismiss by touch, VoiceOver escape, Voice Control (“Dismiss Now Playing”), Switch Control, and hardware keyboard Escape. Acceptance: all routes return to the prior tab without resetting playback.
- **Related:** UIUX-006, UIUX-007.

### UIUX-006 — Now Playing has no height-adaptive scrolling contract for landscape or large text

- **Severity:** Medium
- **Confidence:** Probable
- **Code:**
  - `Fonic HiFi.xcodeproj/project.pbxproj:389-391,437-439`
  - `Fonic HiFi/ContentView.swift:70-82`
  - `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:17,59-101,320-371,373-540`
- **Source excerpt:**

  ```swift
  INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
  ```

  ```swift
  ScrollView {}
      .safeAreaInset(edge: .top, spacing: 0) {
          NowPlayingContent(...)
  ```

  ```swift
  min(proxy.size.width - (DesignTokens.Spacing.xLarge * 2), 400)
  ```

- **Why this is risky:** landscape is explicitly supported, but the full-screen wrapper uses an empty `ScrollView` and inserts the entire player as a top safe-area inset. Safe-area inset content is not the scroll content that provides reachability. The player sizes artwork from width (up to 400 points) and then vertically stacks metadata, progress, five controls, volume, and fixed minimum spacers. The declared `sizeCategory` is unused. On short landscape heights or accessibility sizes, lower controls can be off-screen without a valid scroll path.
- **Apple guidance:** Apple says iOS interfaces must adjust to different sizes and orientations and demonstrates changing layout flow at accessibility text sizes; `ViewThatFits` can select the first layout that fits available space ([A8], [A9], [A10]).
- **Preserving remediation:** make Now Playing the actual scroll content with at least the viewport's height. Preserve the same vertical composition and zoom transition; only add reachability.
- **Unapplied sample:**

  ```swift
  .fullScreenCover(isPresented: $showingNowPlaying) {
      GeometryReader { proxy in
          ScrollView {
              NowPlayingContent(
                  namespace: miniPlayerNamespace,
                  dismiss: { showingNowPlaying = false }
              )
              .frame(minHeight: proxy.size.height, alignment: .top)
              .navigationTransition(.zoom(sourceID: "miniplayer", in: miniPlayerNamespace))
          }
          .scrollBounceBehavior(.basedOnSize)
      }
      .background(.background)
  }
  ```

- **Verification / acceptance:** iPhone portrait and both landscapes at default, XXXL, AX3, and AX5; test long localized title/artist strings. Acceptance: close, queue, artwork, metadata, progress, playback controls, and volume remain reachable without overlap or clipped safe areas.
- **Related:** UIUX-004, UIUX-005, UIUX-015.

### UIUX-007 — Sleep-timer ownership is transient and its volume baseline is hard-coded

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:31-40,138-155`
  - `Fonic HiFi/Presentation/Views/NowPlaying/SleepTimerSheet.swift:19-22,103-130`
  - `Fonic HiFi/Core/Services/SleepTimerManager.swift:23-35,39-66,69-95`
- **Source excerpt:**

  ```swift
  @StateObject private var sleepTimerManager = SleepTimerManager()
  ```

  ```swift
  timerManager.start(seconds: seconds, currentVolume: 1.0)
  ```

  ```swift
  deinit {
      timerTask?.cancel()
  }
  ```

- **Why this is defective:** the timer belongs to the transient `NowPlayingContent` presented by `fullScreenCover`. When that view is destroyed, the manager deinitializes and cancels its task, so a user cannot rely on the timer after leaving Now Playing. Separately, the sheet always seeds the manager with volume `1.0`; a timer started at 30% volume fades/restores relative to 100%, and completion restores 100% into the engine for the next playback. This can cause an unexpected volume jump.
- **Apple guidance:** Apple's SwiftUI data-lifetime guidance says global/feature-lifetime model data belongs at a common ancestor or app source of truth, while `StateObject` lifetime is tied to the declaring view ([A1], [A2]).
- **Preserving remediation:** own `SleepTimerManager` in persistent player/app state (at least `ContentView`), pass it into the presented player as `@ObservedObject`, and supply the actual authoritative volume.
- **Unapplied sample (volume should ultimately move to the audio model):**

  ```swift
  // ContentView
  @StateObject private var sleepTimerManager = SleepTimerManager()

  NowPlayingContent(
      namespace: miniPlayerNamespace,
      dismiss: { showingNowPlaying = false },
      sleepTimerManager: sleepTimerManager
  )
  ```

  ```swift
  // SleepTimerSheet
  let currentVolume: Float
  timerManager.start(seconds: seconds, currentVolume: currentVolume)
  ```

- **Verification / acceptance:** start a 5-minute timer at 25% volume, dismiss Now Playing, navigate all tabs, background/foreground the app, reopen the timer, cancel during fade, and let another timer complete. Acceptance: countdown survives Now Playing dismissal; cancellation restores 25%; completion pauses and does not make later playback louder.
- **Related:** UIUX-002, UIUX-005.

### UIUX-008 — Settings exposes inert controls/actions that do not change the claimed feature

- **Severity:** High
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Presentation/Views/Settings/SettingsView.swift:13-19,53-128,168-232`
  - `Fonic HiFi/ContentView.swift:55-57,70-79`
  - `Fonic HiFi/Presentation/Views/Settings/AudioSettingsView.swift:12-18,37-85,127-160`
  - `Fonic HiFi/Core/Audio/Interfaces/AudioEngineConfiguration.swift:10-25,48-67`
  - `Fonic HiFi/Presentation/Views/Settings/FileRowView.swift:23-27,50-64`
- **Source excerpt:**

  ```swift
  @AppStorage("darkModeEnabled") private var darkModeEnabled = true
  ```

  ```swift
  .preferredColorScheme(.dark)
  ```

  ```swift
  private func exportSettings() {
      logger.info("Exporting settings")
  }
  ```

  ```swift
  private func testAudioConfiguration() {
      Task { logger.info("Testing audio configuration from settings view") }
  }
  ```

- **Why this is defective:** whole-repository symbol tracing found no runtime consumer for `darkModeEnabled`, `showNowPlayingAnimation`, `enableHapticFeedback`, or `showFileExtensions`; the app forces dark mode, always runs the player transition/haptics, and always renders `item.name` with its extension. `enableBitPerfectPlayback`, `audioBufferSize`, and `sampleRate` are written only to defaults and never applied to `AudioEngineConfiguration` (whose default `enableBitPerfect` is `true` even while the settings toggle defaults to `false`). “Export Settings,” “Import Settings,” and “Test Audio Configuration” only log. In total, ten visible choices/actions provide false feedback, including audiophile signal-path claims.
- **Apple guidance:** Apple defines settings as values that configure an app's interface and behavior, and says a settings interface offers controls to change their associated values; its examples listen for preference changes and update the feature immediately ([A11], [A12], [A13]).
- **Preserving remediation:** for each row, either wire it to the existing owning subsystem and reflect the effective value, or remove it from production until implementation exists. Do not add substitute branding or settings. Prioritize bit-perfect/buffer/sample rate because the current UI can misrepresent the audio path.
- **Unapplied safe samples:**

  ```swift
  // ContentView: honor the existing appearance setting.
  @AppStorage("darkModeEnabled") private var darkModeEnabled = true
  // ...
  .preferredColorScheme(darkModeEnabled ? .dark : nil)
  ```

  ```swift
  // Existing haptic sites: preserve feedback only when enabled.
  @AppStorage("enableHapticFeedback") private var hapticsEnabled = true
  if hapticsEnabled {
      UIImpactFeedbackGenerator(style: .medium).impactOccurred()
  }
  ```

  No paste-ready audio-configuration sample is safe without adding facade APIs for buffer size, preferred sample rate, and bit-perfect mode and defining when an engine reconfiguration is allowed. Those controls should be hidden rather than left misleading until that contract exists. Export/import/test likewise need real services and success/failure UI before being exposed.
- **Verification / acceptance:** make a control-by-control matrix. Toggle each setting, relaunch, and verify the named feature changes and the UI reflects the effective engine/app value. Export produces a shareable file; Import opens a picker, validates data, and reports success/failure; Test produces an audible/diagnostic result. Acceptance: no production row is log-only or defaults-only.
- **Related:** UIUX-002, UIUX-009, UIUX-016.

### UIUX-009 — Playback and browse failures are logged but surfaced as silence or false emptiness

- **Severity:** High
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/FonicHiFiApp.swift:155-191`
  - `Fonic HiFi/Presentation/Views/Home/HomeView.swift:45-55,186-237,302-310`
  - `Fonic HiFi/Presentation/Views/Search/SearchView.swift:44-75,123-152`
  - `Fonic HiFi/Presentation/ViewModels/SmartSearchViewModel.swift:82-95`
  - `Fonic HiFi/Presentation/Views/Settings/FileManagerView.swift:195-233`
- **Source excerpt:**

  ```swift
  } catch {
      logger.error("Failed to initialize app: \(error.localizedDescription)")
      // ... log the error and continue with limited functionality
  }
  ```

  ```swift
  } catch {
      // Silently handle errors - home screen shows empty state gracefully
  }
  ```

  ```swift
  } catch {
      searchResults = SearchResults()
      isSearching = false
  }
  ```

- **Why this is defective:** an audio initialization error leaves `isReady == false` and makes playback impossible, but the existing `launchError` alert is never updated. Home catches any data error and then evaluates `isEmpty`, telling users to import music even if their library failed to load. Standard search converts errors into “No results”; Smart Search has `.error(String)` but the body never renders that state; File Manager retains an empty list after load failure. These are materially different states with different recovery actions, and the current UI misdiagnoses them.
- **Apple guidance:** Apple recommends `ContentUnavailableView` when content cannot display because of an error, an empty list, or no search results — distinct causes that should not be collapsed ([A14]). Apple's search guidance recommends a considered no-results view rather than ambiguity ([A15]).
- **Preserving remediation:** model loading as idle/loading/content/empty/error at each owning surface; show the existing content for real emptiness and a small retryable unavailable view for errors. Reuse the existing launch alert for audio initialization.
- **Unapplied sample:**

  ```swift
  // FonicHiFiApp.initializeApp()
  } catch {
      launchError = LaunchError(
          message: "Audio playback could not be initialized. You can retry by restarting Fonic HiFi."
      )
      showInitializationError = true
      await performanceMonitor.recordError(error, context: "App initialization")
  }
  ```

  ```swift
  // Home/Search/File Manager pattern
  if let loadError {
      ContentUnavailableView {
          Label("Unable to Load", systemImage: "exclamationmark.triangle")
      } description: {
          Text(loadError)
      } actions: {
          Button("Try Again") { Task { await retry() } }
      }
  } else if content.isEmpty {
      ExistingEmptyView()
  }
  ```

  Use a user-safe message, retain the detailed error in `Log`, and keep Smart Search `.error` separate from `.noResults`.
- **Verification / acceptance:** inject failures into audio initialization, Home fetch, all four standard search fetches, Smart Search, and directory enumeration. Acceptance: each failure is named, offers a working retry or clear recovery, and never claims the library/search is empty unless the request succeeded with zero items.
- **Related:** UIUX-008, UIUX-010.

### UIUX-010 — Import progress is unobserved; picker errors are invisible; presentation depends on a race

- **Severity:** High
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Presentation/Environment/AudioEnvironment.swift:41-53,109-116`
  - `Fonic HiFi/Presentation/Views/Import/FileImportView.swift:12-18,35-59,63-69`
  - `Fonic HiFi/Presentation/Views/Import/ImportProgressView.swift:10-35,39-68`
  - `Fonic HiFi/Presentation/Views/Library/LibraryView.swift:48-58,102-124,156-161`
  - `Fonic HiFi/Data/Services/LibraryImportService.swift:15-35,72-105`
- **Source excerpt:**

  ```swift
  case let .failure(error):
      logger.error("File selection failed: \(error.localizedDescription, privacy: .public)")
  ```

  ```swift
  importService.importFiles(from: selectedURLs)
  dismiss()
  ```

  ```swift
  @Environment(\.importService) private var importService
  Text(importService?.statusMessage ?? "No import service available")
  ```

  ```swift
  .onChange(of: importService?.isImporting) { _, isImporting in
      if isImporting == true { ... }
  }
  ```

- **Why this is defective:** `LibraryImportService` is a Combine `ObservableObject` with six published progress fields, but `LibraryView`, `FileImportView`, and `ImportProgressView` receive it through the same plain custom-environment pattern as UIUX-001. None subscribes with `@ObservedObject`/`@EnvironmentObject`, so `ProgressSection`, status, error summary, the Cancel-versus-Done branch, and `interactiveDismissDisabled` have no guaranteed invalidation when the service publishes. In addition, picker failure produces no visible error or retry. On success, `FileImportView` calls `importFiles` and immediately dismisses. The service sets `isImporting = true` inside a newly scheduled `Task`; meanwhile the view containing the `onChange` handler is being removed. The only transition to `ImportProgressView` therefore depends on an unobserved change plus task/sheet teardown timing. A long import can run with frozen/absent progress and no reliable cancel UI.
- **Apple guidance:** Apple requires `ObservedObject`/`EnvironmentObject` subscription for Combine `ObservableObject` updates ([A1], [A2]). `fileImporter` returns a `Result` specifically indicating success or failure and documents that returned URLs are security-scoped ([A16]). Apple's progress guidance says ongoing tasks should provide clear status and cancellation where appropriate ([A17]).
- **Preserving remediation:** pass the existing service explicitly to import views as `@ObservedObject` (or provide it with `environmentObject`), then make the user's Import tap explicitly request the parent transition. Dismiss the picker sheet first, present progress from its `onDismiss`, and store picker error in state for a retryable alert.
- **Unapplied sample (observation plus presentation handoff):**

  ```swift
  // LibraryView
  @State private var presentProgressAfterImportSheet = false

  .sheet(isPresented: $showingImportView, onDismiss: {
      if presentProgressAfterImportSheet {
          presentProgressAfterImportSheet = false
          showingImportProgress = true
      }
  }) {
      FileImportView(importService: importService) {
          presentProgressAfterImportSheet = true
          showingImportView = false
      }
  }

  .sheet(isPresented: $showingImportProgress) {
      ImportProgressView(importService: importService)
          .interactiveDismissDisabled(importService.isImporting)
  }
  ```

  ```swift
  // FileImportView / ImportProgressView
  @ObservedObject var importService: LibraryImportService
  let onImportStarted: () -> Void // FileImportView only

  Button("Import") {
      importService.importFiles(from: selectedURLs)
      onImportStarted()
  }
  ```

  Add an item-bound alert for picker failure; do not treat user cancellation as an error.
- **Verification / acceptance:** select one file, a large folder, an unsupported/empty folder, and a cloud file with denied/unavailable access. Acceptance: progress appears exactly once after starting, remains visible for the operation, Cancel works, picker failures are shown, user cancellation stays quiet, and completion/error details remain accessible.
- **Related:** UIUX-001, UIUX-007, UIUX-009.

### UIUX-011 — Smart Search is effectively unreachable from the active Search states

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:** `Fonic HiFi/Presentation/Views/Search/SearchView.swift:16-25,28-76,79-120,353-388`
- **Source excerpt:**

  ```swift
  @State private var useSmartSearch = false
  ```

  ```swift
  if searchText.isEmpty, showingRecentSearches {
      RecentSearchesView(...)
  }
  ```

  ```swift
  Toggle(isOn: $useSmartSearch) { ... }
  // only inside EmptySearchView
  ```

- **Why this is defective:** `useSmartSearch` starts false. With empty text, the first body branch always shows `RecentSearchesView`, not `EmptySearchView`, so the only toggle capable of changing the value is absent. Entering text runs standard search. The fallback `EmptySearchView` is not reachable through normal state transitions, making a shipped feature undiscoverable/unusable. A later mode toggle would also need to rerun a nonempty query, but only `searchText` changes currently schedule work.
- **Apple guidance:** Apple's search design guidance warns that less-discoverable search modes should be paired with visible filtering controls rather than replacing them ([A15]).
- **Preserving remediation:** move the existing Smart Search toggle into a persistent Search toolbar/menu and rerun the current query when mode changes. Keep its current name, icon, availability check, and result UI.
- **Unapplied sample:**

  ```swift
  .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
          Toggle(isOn: $useSmartSearch) {
              Label("Smart Search", systemImage: "sparkles")
          }
          .disabled(!smartSearchViewModel.isSmartSearchEnabled)
      }
  }
  .onChange(of: useSmartSearch) { _, _ in
      guard !searchText.isEmpty else { return }
      scheduleSearch(for: searchText) // extract the existing debounced task body
  }
  ```

- **Verification / acceptance:** with zero and multiple recent searches, enable/disable Smart Search before and after entering text; verify unavailable devices expose a disabled, understandable state. Acceptance: both search modes are intentionally selectable and current results always correspond to the visible mode.
- **Related:** UIUX-009, UIUX-012.

### UIUX-012 — Multiple browse affordances have no destination or action

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Presentation/Views/Search/SearchView.swift:189-238,243-304`
  - `Fonic HiFi/Presentation/Views/Home/HomeView.swift:41-44,131-160,370-408`
  - `Fonic HiFi/Presentation/Views/Home/Sections/GenresSection.swift:11-45`
- **Source excerpt:**

  ```swift
  Text("See all \(results.tracks.count) tracks")
      .foregroundStyle(.tint)
  ```

  ```swift
  AlbumRowView(album: album)
  SearchArtistRow(artist: artist)
  PlaylistSearchRowView(playlist: playlist)
  ```

  ```swift
  selectedGenre = genre
  ```

- **Why this is defective:** “See all” is tinted like an action but is plain text. Standard-search album, artist, and playlist rows have no `Button`, `NavigationLink`, sheet state, or gesture. Home genre pills call a closure that only assigns `selectedGenre`, but that state is never read to present content. “Recently Played” and “Most Listened” use `CarouselView`/`TrackCardView` without a tap callback, unlike adjacent playable sections. Users encounter visible, action-shaped content that does nothing.
- **Apple guidance:** SwiftUI's standard controls provide the interaction and accessibility action automatically; Apple recommends using built-in controls and styles instead of gesture-only/custom substitutes ([A18], [A19]). Navigation destinations should be registered within the owning `NavigationStack` and driven by links or bound items ([A20], [A21]).
- **Preserving remediation:** wire these existing affordances to the app's existing playback/detail destinations. If a destination is not production-ready (genre), remove `.interactive()`/tap behavior until it is; do not invent a new destination.
- **Unapplied samples:**

  ```swift
  // Preserve the existing Home playback action for history carousels.
  CarouselView(tracks: recentlyPlayed, onTrackTap: playTrack)

  private struct TrackCardView: View {
      let track: Track
      let onTap: () -> Void
      var body: some View {
          Button(action: onTap) { existingCardContent }
              .buttonStyle(.plain)
      }
  }
  ```

  ```swift
  // Search rows: keep current row visuals and pass destinations from SearchView.
  Button { onAlbumSelected(album) } label: {
      AlbumRowView(album: album)
  }
  .buttonStyle(.plain)
  ```

  For genre, either bind `selectedGenre` to a real existing filtered-library destination, or remove the tap and `.interactive()` glass variant for this release.
- **Verification / acceptance:** activate every result/history/genre item by touch, VoiceOver, Voice Control, and keyboard. Acceptance: every visual affordance performs the named action once; non-actions have no interactive styling/traits.
- **Related:** UIUX-011, UIUX-015.

### UIUX-013 — Queue edit controls are undiscoverable and displayed offsets are translated incorrectly

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Presentation/Views/Queue/QueueView.swift:14-28,31-68`
  - `Fonic HiFi/Core/Audio/Queue/QueueState.swift:70-75`
  - `Fonic HiFi/Core/Audio/Queue/AudioQueueManager.swift:152-193,203-237`
- **Source excerpt:**

  ```swift
  let remaining = audioService?.queueManager.queueState.remainingTracks ?? []
  ```

  ```swift
  let actualFrom = fromIndex + 1
  let actualTo = destination + 1
  ```

  ```swift
  for index in offsets {
      let actualIndex = index + 1
      _ = audioService?.queueManager.remove(at: actualIndex)
  }
  ```

- **Why this is defective:** the displayed list begins at `currentIndex + 1`, not absolute queue index `1`. If the current item is at index 5, deleting displayed row 0 removes queue index 1 — a prior/history item — rather than index 6. Moving has the same base error and also treats Swift's destination offset as a final index; destination can equal the displayed count, while `AudioQueueManager.move` rejects `toIndex == tracks.count`. Multi-delete processes ascending offsets, so earlier removals shift later targets. Finally, `.onMove` and multi-selection edit affordances normally require edit mode on touch-only devices, but the toolbar has only Done.
- **Apple guidance:** Apple says a `List` with `onMove` exposes move controls in edit mode and recommends `EditButton` to toggle it; multiple selection on touch-only devices also requires edit mode ([A22]). Apple's collection move API defines destination as the offset *before which* to insert, valid in `0...count` ([A23]).
- **Preserving remediation:** expose `EditButton`, compute the visible base from `currentIndex`, apply collection move semantics to a copy of the displayed remainder, and delete in descending order. Keep the same Queue sheet and sections.
- **Unapplied sample (validate shuffle semantics with the audio owner):**

  ```swift
  .toolbar {
      ToolbarItem(placement: .topBarLeading) { EditButton() }
      ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
  }
  ```

  ```swift
  private func moveTrack(from source: IndexSet, to destination: Int) {
      guard let queue = audioService?.queueManager else { return }
      let state = queue.queueState
      let base = state.currentIndex.map { $0 + 1 } ?? 0
      var remaining = state.remainingTracks
      remaining.move(fromOffsets: source, toOffset: destination)
      queue.replaceQueue(
          with: Array(state.tracks.prefix(base)) + remaining,
          startIndex: state.currentIndex
      )
  }

  private func deleteTrack(at offsets: IndexSet) {
      guard let queue = audioService?.queueManager else { return }
      let base = queue.queueState.currentIndex.map { $0 + 1 } ?? 0
      for offset in offsets.sorted(by: >) {
          _ = queue.remove(at: base + offset)
      }
  }
  ```

- **Verification / acceptance:** construct queues with current index 0, middle, last, and nil; move one/multiple rows to beginning/end; delete one/multiple noncontiguous rows; repeat with shuffle off/on. Acceptance: only visible Up Next rows change, current track remains current, order persists, and end moves work.
- **Related:** UIUX-001, UIUX-015.

### UIUX-014 — Audio Settings nests a second navigation stack inside the Settings stack

- **Severity:** Low
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Presentation/Views/Settings/SettingsView.swift:25-43,199-203`
  - `Fonic HiFi/Presentation/Views/Settings/AudioSettingsView.swift:22-24,139-143`
- **Source excerpt:**

  ```swift
  NavigationLink {
      AudioSettingsView()
  }
  ```

  ```swift
  var body: some View {
      NavigationStack {
          Form {
  ```

- **Why this is defective:** Settings already owns the stack and pushes `AudioSettingsView`; the destination then creates another root stack. Two independent navigation containers can produce duplicated chrome, an inner root with no back state, and inconsistent toolbar/back-swipe behavior. The existing UI test expects the outer “Settings” back button, so the destination should participate in that stack.
- **Apple guidance:** Apple defines `NavigationStack` as a root plus presented destinations and places `navigationDestination`/links inside that hierarchy; the stack owns the built-in Back behavior ([A20], [A21]).
- **Preserving remediation:** remove only the inner `NavigationStack` wrapper from `AudioSettingsView`; retain the `Form`, title, and outer Settings navigation.
- **Unapplied sample:**

  ```swift
  var body: some View {
      Form {
          // existing sections unchanged
      }
      .navigationTitle("Audio Settings")
      .navigationBarTitleDisplayMode(.inline)
  }
  ```

- **Verification / acceptance:** push Audio Settings, change controls, edge-swipe back, tap Back, and return repeatedly. Acceptance: one navigation bar, one Settings back action, preserved state, no double animation.
- **Related:** none.

### UIUX-015 — Active tap targets use raw gestures instead of semantic controls

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Presentation/Views/Home/Sections/ArtistsSection.swift:21-30`
  - `Fonic HiFi/Presentation/Views/Home/Sections/GenresSection.swift:21-28`
  - `Fonic HiFi/Presentation/Views/Home/Sections/RecentlyAddedSection.swift:21-30`
  - `Fonic HiFi/Presentation/Views/Library/LibraryView.swift:195-208,217-239,250-280`
  - `Fonic HiFi/Presentation/Views/Library/TrackRowView.swift:59-65`
- **Source excerpt:**

  ```swift
  ArtistAvatarView(artist: artist)
      .onTapGesture { onArtistTap(artist) }
  ```

  ```swift
  AlbumEntityTile(album: album)
      .onTapGesture { selectedAlbum = album }
  ```

- **Why this is defective:** these are primary actions implemented as gestures on layout views. They do not automatically receive Button traits, activation semantics, keyboard/Voice Control behavior, disabled state, or standard pressed feedback. Some content is therefore harder or impossible to discover and activate with assistive input. The library track row also contains a separate Info `Button`, so its primary play action needs deliberate sibling semantics rather than a gesture on their shared container.
- **Apple guidance:** Apple says SwiftUI introspects standard controls such as buttons and provides accessibility labels/actions by default, and recommends using built-in controls/styles whenever possible; custom gestures must explicitly expose actions ([A18], [A19]).
- **Preserving remediation:** replace one-action gesture surfaces with plain-styled `Button`/`NavigationLink`. For compound rows, make Play and Info distinct semantic controls, or add an explicit default accessibility action while preserving separate Info.
- **Unapplied sample:**

  ```swift
  Button {
      onArtistTap(artist)
  } label: {
      ArtistAvatarView(artist: artist)
  }
  .buttonStyle(.plain)
  ```

  ```swift
  // Transitional compound-row fallback; a sibling Button structure is preferable.
  .accessibilityElement(children: .combine)
  .accessibilityAddTraits(.isButton)
  .accessibilityAction { playTrack() }
  ```

- **Verification / acceptance:** audit all active rows with Accessibility Inspector, VoiceOver rotor, Voice Control labels, Switch Control, Full Keyboard Access, and pointer. Acceptance: each action announces as an action, activates once, and keeps secondary actions distinct.
- **Related:** UIUX-012, UIUX-013.

### UIUX-016 — “Reset All Settings” executes immediately without confirmation

- **Severity:** Low
- **Confidence:** Confirmed by static evidence
- **Code:** `Fonic HiFi/Presentation/Views/Settings/SettingsView.swift:189-197,224-232`
- **Source excerpt:**

  ```swift
  Button(role: .destructive) {
      resetSettings()
  } label: {
      SettingsRow(... title: "Reset All Settings")
  }
  ```

- **Why this is defective:** one tap immediately changes every currently wired preference. There is no confirmation, review, undo, or completion feedback. The action is bounded and manually reversible, hence Low, but accidental activation causes surprising multi-setting changes.
- **Apple guidance:** SwiftUI's confirmation-dialog documentation uses a destructive confirmation before permanently changing multiple items; the system supplies standard cancellation behavior and appropriate role ordering ([A24]).
- **Preserving remediation:** keep the existing row/name and add a confirmation dialog; call the existing reset method only from the confirmed destructive action.
- **Unapplied sample:**

  ```swift
  @State private var showingResetConfirmation = false

  Button(role: .destructive) {
      showingResetConfirmation = true
  } label: {
      SettingsRow(icon: "arrow.counterclockwise", iconColor: .red, title: "Reset All Settings")
  }
  .confirmationDialog(
      "Reset all settings to their defaults?",
      isPresented: $showingResetConfirmation
  ) {
      Button("Reset All Settings", role: .destructive, action: resetSettings)
  }
  ```

- **Verification / acceptance:** tap reset, cancel, confirm, relaunch. Acceptance: cancel changes nothing; confirm changes every supported setting once and the UI immediately reflects effective values.
- **Related:** UIUX-008.

### UIUX-017 — File Manager's multi-select actions have no touch-only edit-mode entry

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Presentation/Views/Settings/FileManagerView.swift:25-35,99-139,141-161,260-288`
  - `Fonic HiFi/Presentation/Views/Settings/FileRowView.swift:10-13,74-82`
- **Source excerpt:**

  ```swift
  @State private var selectedItems: Set<FileItem> = []
  ```

  ```swift
  List(selection: $selectedItems) {
      ForEach(filteredContents, id: \.id) { item in
          FileRowView(...)
  ```

  ```swift
  if !selectedItems.isEmpty {
      // Delete / Import Selected toolbar
  }
  ```

- **Why this is defective:** Delete and “Import Selected” are rendered only after `selectedItems` becomes nonempty, but the view supplies no `EditButton` or explicit edit-mode state. Its trailing toolbar contains only an ellipsis menu, while each row consumes a normal tap to open a directory/details and a long press to show details. On a touch-only iPhone, SwiftUI requires edit mode for multiple selection, so the state that reveals both batch actions has no discoverable input path.
- **Apple guidance:** Apple documents that people on devices without an attached keyboard, mouse, or trackpad can make multiple List selections only while edit mode is active, and recommends `EditButton` to toggle that mode ([A22]).
- **Preserving remediation:** add `EditButton` to the existing toolbar, tag each row with its `FileItem`, and suppress the row's navigation tap while editing. Keep the current File Manager, selection set, bottom actions, and ellipsis menu.
- **Unapplied sample:**

  ```swift
  @Environment(\.editMode) private var editMode

  List(selection: $selectedItems) {
      ForEach(filteredContents, id: \.id) { item in
          FileRowView(
              item: item,
              onTap: {
                  if editMode?.wrappedValue.isEditing != true {
                      handleItemTap(item)
                  }
              },
              onLongPress: { showFileDetails(item) }
          )
          .tag(item)
      }
  }
  .toolbar {
      ToolbarItem(placement: .topBarTrailing) { EditButton() }
      ToolbarItem(placement: .topBarTrailing) { existingActionsMenu }
  }
  ```

  Extract the current ellipsis `Menu` into `existingActionsMenu`; do not remove or rename its actions.
- **Verification / acceptance:** on an iPhone with no external input, enter Edit, select one/multiple audio files and a mixed audio/folder set, cancel selection, run Import Selected, and confirm/delete selected files. Acceptance: selection indicators appear, row taps select rather than navigate in Edit, batch actions reveal at the correct time, and leaving Edit cannot retain a confusing hidden selection.
- **Related:** UIUX-010, UIUX-013, UIUX-015.

### UIUX-018 — Every library pagination fetch presents a full-screen blocking loader

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Presentation/ViewModels/Library/LibraryViewModel.swift:143-188`
  - `Fonic HiFi/Presentation/Views/Library/LibraryView.swift:140-144,195-215,217-248,250-288,290-310,789-816`
- **Source excerpt:**

  ```swift
  nextState.isLoading = true
  isLoadingSection = section
  ```

  ```swift
  if viewModel.isLoadingSection == .tracks {
      LoadingListRow()
  }
  ```

  ```swift
  if let loadingMessage {
      LoadingOverlay(message: loadingMessage, isShowing: true)
  }
  ```

- **Why this is defective:** `isLoadingSection` represents both the first page and every later page. Each section already renders an inline pagination spinner, but the root also derives a nonnil `loadingMessage` from the same value and overlays an opaque, full-screen interaction layer. As a user approaches each page threshold, pagination therefore blocks the whole Library and interrupts scrolling instead of incrementally extending the visible list/grid. On a large library this repeats for every page.
- **Apple guidance:** Apple's progress guidance distinguishes clear progress feedback from unnecessary blocking and recommends an indicator that matches the operation's scope ([A17]). A later page affects only the list tail, so its existing inline indicator is the proportional feedback.
- **Preserving remediation:** keep the current overlay for an initial load only; retain the existing list/grid spinner for pagination. The view model need not be redesigned — derive initial-loading state from the active section being empty.
- **Unapplied sample:**

  ```swift
  private var initialLoadingMessage: String? {
      guard viewModel.isLoadingSection == selectedTab.section else { return nil }
      let isEmpty = switch selectedTab {
      case .tracks: viewModel.tracks.isEmpty
      case .albums: viewModel.albums.isEmpty
      case .artists: viewModel.artists.isEmpty
      case .playlists: viewModel.playlists.isEmpty
      }
      return isEmpty ? selectedTab.loadingDescription : nil
  }
  ```

  ```swift
  .overlay {
      if let initialLoadingMessage {
          LoadingOverlay(message: initialLoadingMessage, isShowing: true)
      }
  }
  ```

- **Verification / acceptance:** use at least three pages in each section, slowly scroll across every prefetch threshold, switch tabs during a page load, and test failed next-page fetch/retry. Acceptance: first load communicates progress, later loads leave existing content scrollable, one inline spinner appears at the tail, and no duplicate blocking overlay flashes.
- **Related:** UIUX-009.

### UIUX-019 — “Surprise Me” has tracked loading state that the UI never renders

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Presentation/Views/Home/HomeView.swift:32-37,89-108,260-299`
  - `Fonic HiFi/Presentation/Views/Home/Sections/QuickActionsSection.swift:11-35`
- **Source excerpt:**

  ```swift
  @State private var isGeneratingRecommendations = false
  ```

  ```swift
  isGeneratingRecommendations = true
  defer { isGeneratingRecommendations = false }
  ```

  ```swift
  Button {
      onSurpriseMe()
  } label: {
      Label("Surprise Me", systemImage: "dice")
  }
  ```

- **Why this is defective:** the async recommendation path intentionally records a busy state while it loads listening sessions, invokes the recommendation service, fetches tracks, replaces the queue, and starts playback. No view reads that state, so the button never shows progress and remains enabled. Repeated taps can launch concurrent recommendation tasks that each replace the queue and attempt playback; the final result depends on completion order, with no indication that work is underway.
- **Apple guidance:** Apple's progress guidance recommends clear feedback for ongoing work ([A17]); standard button disabled/loading state also preserves reliable, single activation semantics ([A18]).
- **Preserving remediation:** pass the existing `isGeneratingRecommendations` value into `QuickActionsSection`, retain the same label/icon/style, show a small `ProgressView`, and disable repeat activation until the task finishes.
- **Unapplied sample:**

  ```swift
  QuickActionsSection(
      onShuffleAll: shuffleAll,
      onSurpriseMe: surpriseMe,
      isGeneratingRecommendations: isGeneratingRecommendations
  )
  ```

  ```swift
  let isGeneratingRecommendations: Bool

  Button(action: onSurpriseMe) {
      if isGeneratingRecommendations {
          ProgressView().frame(maxWidth: .infinity)
      } else {
          Label("Surprise Me", systemImage: "dice")
              .frame(maxWidth: .infinity)
      }
  }
  .disabled(isGeneratingRecommendations)
  .buttonSizing(.flexible)
  .buttonStyle(.glass)
  ```

- **Verification / acceptance:** use a delayed recommendation test double, tap rapidly, background/foreground mid-request, and test success, empty fallback, and failure fallback. Acceptance: exactly one operation runs, visible progress begins promptly, the action cannot be double-submitted, and the original label returns after every exit path.
- **Related:** UIUX-009, UIUX-012.

### UIUX-020 — The 10-band EQ is a gesture-only fixed-width control

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:** `Fonic HiFi/Presentation/Views/Settings/EqualizerView.swift:71-121,167-221`
- **Source excerpt:**

  ```swift
  HStack(alignment: .center, spacing: 4) {
      ForEach(0..<10, id: \.self) { index in
  ```

  ```swift
  .gesture(
      DragGesture(minimumDistance: 0)
          .onChanged { gesture in ... }
  )
  .frame(width: 30)
  ```

- **Why this is defective:** all ten bands are forced into one non-scrolling `HStack`, each custom control is 30 points wide, and its only input is a `DragGesture`. `VerticalSlider` exposes no accessibility element, label, current dB value, adjustable action, focus action, or keyboard alternative. VoiceOver/Switch Control cannot adjust it, while narrow/landscape widths compress or clip the ten-band strip and large labels. This is a primary audiophile control, not decorative content.
- **Apple guidance:** Apple recommends built-in controls whenever possible because they provide accessibility semantics automatically; custom controls and gestures must expose labels, values, and actions so assistive technologies can operate them ([A18], [A19]). Apple's Dynamic Type guidance also recommends adapting layout flow rather than relying on fixed horizontal geometry ([A9]).
- **Preserving remediation:** retain the ten vertical bands, frequencies, colors, and 0.5 dB behavior, but make each band an adjustable accessibility element and provide enough horizontal room (or a horizontal scroll container) without shrinking the control.
- **Unapplied sample:**

  ```swift
  ScrollView(.horizontal, showsIndicators: false) {
      HStack(alignment: .center, spacing: 8) {
          ForEach(0..<10, id: \.self) { index in
              VerticalSlider(
                  value: $configuration.bands[index].gain,
                  range: -12...12
              )
              .frame(width: 44, height: 140)
              .accessibilityElement(children: .ignore)
              .accessibilityLabel("\(frequencyLabels[index]) hertz")
              .accessibilityValue(
                  "\(configuration.bands[index].gain, specifier: "%.1f") decibels"
              )
              .accessibilityAdjustableAction { direction in
                  adjustBand(index, direction: direction)
              }
          }
      }
      .padding(.horizontal, 4)
  }

  private func adjustBand(
      _ index: Int,
      direction: AccessibilityAdjustmentDirection
  ) {
      let delta: Float
      switch direction {
      case .increment: delta = 0.5
      case .decrement: delta = -0.5
      @unknown default: return
      }
      configuration.bands[index].gain = min(
          12,
          max(-12, configuration.bands[index].gain + delta)
      )
  }
  ```

  The existing gain `onChange` can continue applying/persisting configuration.
- **Verification / acceptance:** test all bands with touch, VoiceOver swipes, Switch Control, Full Keyboard Access, portrait/landscape, and AX5 text. Acceptance: each band announces frequency and dB, increments/decrements by 0.5 dB, remains visually reachable, and still applies the existing EQ configuration.
- **Related:** UIUX-006, UIUX-015.

---

## Preserving, unapplied sample inventory

No repository code was modified. Every sample above is deliberately local to the existing architecture and UI identity:

| Finding | Preservation boundary | Required validation |
|---|---|---|
| UIUX-001 | Same facade and environment-wide dependency; only observation ownership changes | Build all previews/targets; playback state/device tests |
| UIUX-002 | Same controls, labels, persistence owners, and modes | Queue restore, App Intent, remote command tests |
| UIUX-003 | Same mini player; uses existing `showMiniPlayer` contract | iOS 26 accessory API build and lifecycle test |
| UIUX-004 | Same mini-player visuals/controls; compact subset only when system placement is inline | iOS 26 SDK spelling and smallest-device visual check |
| UIUX-005 | Same full-screen presentation; adds only a standard close path | Touch/VoiceOver/keyboard dismissal |
| UIUX-006 | Same vertical Now Playing composition and zoom transition; makes it real scroll content | Portrait/landscape/Dynamic Type screenshots |
| UIUX-007 | Same timer manager and sheet; moves lifetime to a stable ancestor and passes real volume | Background, fade, cancel, and later-playback checks |
| UIUX-008 | Existing names/preferences only; wire them or hide them, no replacement features | Audio-engine contract and settings behavior matrix |
| UIUX-009 | Existing content and empty views remain; errors become explicit and retryable | Failure injection |
| UIUX-010 | Same import service and two-sheet flow; subscribe to it and make handoff explicit | Files/iCloud/large-folder device tests |
| UIUX-011 | Same Smart Search toggle and results; move toggle to a persistent location | Availability and mode-switch tests |
| UIUX-012 | Same card/row visuals and existing playback/detail intent | End-to-end activation tests |
| UIUX-013 | Same Queue sheet and sections; correct data/index handling plus Edit | Queue permutations and shuffle tests |
| UIUX-014 | Same Settings navigation; remove redundant inner owner | Back button/edge swipe test |
| UIUX-015 | Same visuals/actions; semantic `Button`/`NavigationLink` wrappers | Accessibility and keyboard tests |
| UIUX-016 | Same reset method and label; add system confirmation | Cancel/confirm test |
| UIUX-017 | Same File Manager, row visuals, selection set, and actions; expose system edit mode | Touch-only multi-select and batch-action tests |
| UIUX-018 | Same Library overlay and inline indicators; scope blocking overlay to first page | Large-library pagination tests |
| UIUX-019 | Same Quick Action label, icon, style, and recommendation path; expose existing busy state | Delayed/double-tap recommendation tests |
| UIUX-020 | Same ten bands, vertical visual, colors, range, and step; add semantics and width reachability | Assistive-input and orientation EQ tests |

---

## Rejected candidate findings

These candidates were intentionally **not retained** because they were subjective, inactive, unsupported by current product configuration, or lacked static proof of a defect.

1. **“Redesign the four-tab structure / move Settings / rename Search.”** Rejected: no concrete defect; violates the preservation boundary. The native `TabView` and `.search` role are appropriate iOS 26 structure.
2. **“Replace the app's colors, gradients, iconography, or artwork-driven identity.”** Rejected: subjective branding change, explicitly out of scope.
3. **“Liquid Glass is not adopted because the app does not use the custom `LiquidGlassTabBar`/`LiquidGlassRail`.”** Rejected: those types are preview-only; the active app correctly relies on native iOS 26 `TabView`, `.search`, minimized tab bar, bottom accessory, and glass button styles. Native components automatically adopt Liquid Glass.
4. **“Every custom glass surface must be removed.”** Rejected: active custom glass is limited, and the media-rich Lyrics clear surface includes a dimming layer. No contrast/device evidence proves a defect. Apple advises restraint, not zero custom glass ([A25]).
5. **“The Home `TrackCardView.glassSurface` is definitely excessive.”** Rejected as subjective. It is a single content treatment; validate legibility/Reduce Transparency on device before changing identity.
6. **“Missing iOS availability gates around Liquid Glass.”** Rejected: the active target's deployment target is iOS 26.0 (`project.pbxproj:391,439`).
7. **“Native iPad layout is broken.”** Rejected: active app target is iPhone-only (`TARGETED_DEVICE_FAMILY = 1`, `project.pbxproj:411,459`). iPad-specific split-view work would invent unsupported scope.
8. **“The four-segment Library picker definitely clips.”** Rejected as unverified visual risk. Four segments are bounded; test on small iPhone/Dynamic Type before changing the established information architecture.
9. **“All fixed-size album/artwork cards are nonresponsive.”** Rejected: active album library uses an adaptive grid and Home cards intentionally live in horizontal scroll views. No static overflow defect was proven.
10. **“Multiple `.sheet` modifiers on Library/Now Playing are inherently invalid.”** Rejected: SwiftUI supports distinct sheet modifiers; no static path proves simultaneous presentation here. The specific import handoff race is retained as UIUX-010.
11. **“Home and Library empty states must use a new visual design.”** Rejected: existing empty-state style is coherent. The retained issue is state correctness/recovery, not aesthetics.
12. **“A native iPad sidebar is required for iOS 26.”** Rejected: iPad is not targeted and a sidebar would replace the current navigation model.

---

## Open build/device checks

All checks are open because this environment cannot run Xcode or Apple SDKs.

| Check | Configuration and steps | Acceptance criteria | Related findings |
|---|---|---|---|
| DV-01 | Build Debug and Release with the pinned iOS 26 SDK; compile all app/UI-test targets and previews touched by observation samples | Zero compile errors/warnings caused by environment ownership, `tabViewBottomAccessory`, placement enum, or sample APIs | UIUX-001–004 |
| DV-02 | Smallest supported iPhone, portrait + both landscapes; default, XXXL, AX3, AX5 | Every Now Playing control is reachable; no overlap, negative size, clipped safe area, or inaccessible close action | UIUX-005, UIUX-006 |
| DV-03 | iPhone with long title/artist/localized strings; collapse tab bar by scrolling each tab | Expanded and inline accessories remain readable and do not obstruct tabs; compact variant activates only inline | UIUX-003, UIUX-004 |
| DV-04 | VoiceOver, Voice Control, Switch Control, Full Keyboard Access, hardware Escape; traverse Home/Library/Search/Queue/Now Playing | Every action has a role/label and activates once; Now Playing can always dismiss; Info remains separate from Play | UIUX-005, UIUX-012, UIUX-015 |
| DV-05 | Reduce Motion on/off and `showNowPlayingAnimation` on/off | If the setting ships, transition behavior changes as named and Reduce Motion remains comfortable; otherwise remove the inert setting | UIUX-008 |
| DV-06 | Reduce Transparency, Increase Contrast, Differentiate Without Color, light/dark preference | Active glass remains legible and state is never conveyed only by tint; Dark Mode setting has observable effect | UIUX-004, UIUX-008 |
| DV-07 | Start A→B queue; automatic next; Control Center pause/resume; App Intent shuffle; relaunch queue restoration | Mini/expanded title, artwork, elapsed time, icons, shuffle/repeat/speed labels all stay synchronized | UIUX-001, UIUX-002 |
| DV-08 | Start timer at 25% volume; dismiss Now Playing; background/foreground; cancel during fade; let timer finish | Timer persists as intended, restores 25%, pauses once, and later playback does not jump to 100% | UIUX-007 |
| DV-09 | Force audio-session/engine initialization failure, SwiftData Home failure, Search/Smart Search failure, and directory permission failure | Each surface shows the correct recoverable error and never substitutes an empty/no-results claim | UIUX-009 |
| DV-10 | Import local/iCloud files, a folder with hundreds of tracks, empty folder, denied/unavailable cloud item, picker failure, user cancel | Progress appears exactly once, remains cancellable, completion/errors persist, cancellation is not shown as an error | UIUX-010 |
| DV-11 | Search with and without recents; Smart Search available/unavailable; switch modes before and after text entry | Mode control is always discoverable, unavailable state is clear, and current results match current mode | UIUX-011 |
| DV-12 | Activate Search albums/artists/playlists/See All, Home history cards, and genre pills by all supported input methods | Every affordance has a real destination/action or no interactive styling | UIUX-012, UIUX-015 |
| DV-13 | Queue current index 0/middle/last/nil; single/multiple move to start/end; noncontiguous delete; shuffle off/on | Correct Up Next items move/delete, current item remains stable, end destination works, order persists | UIUX-013 |
| DV-14 | Push Audio Settings repeatedly, use Back and edge swipe | Exactly one navigation bar/back action; no nested-stack state reset | UIUX-014 |
| DV-15 | Tap Reset, cancel, confirm, relaunch | Cancel is no-op; confirm applies supported defaults once and reflected controls match effective state | UIUX-016 |
| DV-16 | File Manager on touch-only iPhone: enter/leave Edit, select one/multiple/mixed items, import, cancel, and delete | Edit is discoverable; taps select rather than navigate while editing; batch actions reveal and act on exactly the selected items | UIUX-017 |
| DV-17 | Populate 3+ pages in Tracks/Albums/Artists/Playlists; cross every prefetch threshold and switch tabs mid-load | Initial load is clear; pagination remains interactive with one tail spinner and no full-screen flash | UIUX-018 |
| DV-18 | Delay recommendation generation; tap “Surprise Me” rapidly; background/foreground; force success/empty/failure | One task runs, progress is visible, repeat taps are blocked, and label/control recover on every exit path | UIUX-019 |
| DV-19 | EQ at portrait/landscape and AX5; adjust every band with touch, VoiceOver, Switch Control, and keyboard | Each band is reachable, labeled by frequency/value, adjusts in 0.5 dB steps, and persists/applies | UIUX-020 |
| DV-20 | Optional iPad compatibility-mode smoke test only; do not score as native iPad support | App runs acceptably in system compatibility mode if distributed there; no native iPad claim is inferred | Scope note |

---

## Official Apple guidance used

- **[A1]** [Model data — SwiftUI](https://developer.apple.com/documentation/swiftui/model-data) — single sources of truth; `StateObject`, `ObservedObject`, and `EnvironmentObject` roles.
- **[A2]** [`StateObject`](https://developer.apple.com/documentation/swiftui/stateobject) — owns an `ObservableObject` for the declaring view's lifetime and distributes it with `environmentObject`.
- **[A3]** [Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app) — `@Observable` types form dependencies when body reads properties; environment distribution for Observation models.
- **[A4]** [`tabViewBottomAccessory(isEnabled:content:)`](https://developer.apple.com/documentation/swiftui/view/tabviewbottomaccessory%28isenabled:content:%29) — dynamic visibility (iOS 26.1+) and expanded/inline placement behavior; availability must be checked against the app's iOS 26.0 minimum.
- **[A5]** [Build a SwiftUI app with the new design — WWDC25](https://developer.apple.com/videos/play/wwdc2025/323/) — adapt mini-player content using `tabViewBottomAccessoryPlacement` when inline.
- **[A6]** [`fullScreenCover(isPresented:onDismiss:content:)`](https://developer.apple.com/documentation/swiftui/view/fullscreencover(ispresented:ondismiss:content:)) — binding-driven full-screen presentation and explicit dismissal example.
- **[A7]** [Modal presentations — SwiftUI](https://developer.apple.com/documentation/swiftui/modal-presentations) — `dismiss`/`DismissAction` for current presentation.
- **[A8]** [Interface fundamentals](https://developer.apple.com/documentation/technologyoverviews/interface-fundamentals) — adapt iOS interfaces to sizes and orientations.
- **[A9]** [Get started with Dynamic Type — WWDC24](https://developer.apple.com/videos/play/wwdc2024/10074/) — change layout flow at accessibility sizes and test all text sizes.
- **[A10]** [`ViewThatFits`](https://developer.apple.com/documentation/swiftui/viewthatfits) — choose the first child layout that fits available space.
- **[A11]** [Settings — Foundation](https://developer.apple.com/documentation/foundation/settings) — settings configure app interface and behavior.
- **[A12]** [Adding a settings interface to your app](https://developer.apple.com/documentation/foundation/adding-a-settings-interface-to-your-app) — controls change associated values and the app responds to settings.
- **[A13]** [Detecting changes in the preferences window](https://developer.apple.com/documentation/uikit/detecting-changes-in-the-preferences-window?changes=latest_major) — official example updates the feature when preference values change.
- **[A14]** [`ContentUnavailableView`](https://developer.apple.com/documentation/swiftui/contentunavailableview) — represent error, empty-list, and no-results situations without conflating them.
- **[A15]** [Design intuitive search experiences — WWDC26](https://developer.apple.com/videos/play/wwdc2026/292/) — visible mode/filter controls and graceful no-results states.
- **[A16]** [`fileImporter` with multiple selection](https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:allowsmultipleselection:oncompletion:)) — completion `Result` and security-scoped URL contract.
- **[A17]** [Progress indicators — HIG](https://developer.apple.com/design/human-interface-guidelines/progress-indicators) — clear ongoing status and cancellation where appropriate.
- **[A18]** [Accessibility modifiers — SwiftUI](https://developer.apple.com/documentation/swiftui/view-accessibility) — standard controls receive built-in accessibility; custom interactions need explicit actions.
- **[A19]** [Catch up on accessibility in SwiftUI — WWDC24](https://developer.apple.com/videos/play/wwdc2024/10073/) — prefer built-in controls and styles; expose custom gestures as actions.
- **[A20]** [`NavigationStack`](https://developer.apple.com/documentation/swiftui/navigationstack) — one stack owns root, destinations, Back, and path state.
- **[A21]** [Understanding the navigation stack](https://developer.apple.com/documentation/swiftui/understanding-the-navigation-stack) — link/item/path-driven destinations within the owning stack.
- **[A22]** [`EditMode`](https://developer.apple.com/documentation/swiftui/environmentvalues/editmode) — `onMove` controls and touch-only multiple selection appear in edit mode; `EditButton` toggles it.
- **[A23]** [`move(fromOffsets:toOffset:)`](https://developer.apple.com/documentation/swift/mutablecollection/move(fromoffsets:tooffset:)) — destination is an insertion offset in `0...count`.
- **[A24]** [`confirmationDialog`](https://developer.apple.com/documentation/swiftui/view/confirmationdialog(_:ispresented:titlevisibility:actions:)) — system destructive confirmation and cancellation behavior.
- **[A25]** [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass) and [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views) — prefer system components, use custom glass sparingly, and use `GlassEffectContainer` for multiple related custom effects.
