# Northstar — Accessibility & Localization audit

**Repository:** `/agent/workspace/fonic-hifi-audit`
**Audited snapshot:** `main` @ `459db9bfd18d17960e8fd2ff8defc4701085532e`
**Audit date:** 2026-07-09
**Scope:** active app paths rooted at `FonicHiFiApp` → `ContentView`, the active Home/Library/Search/Now Playing/Queue/Settings surfaces, and the WidgetKit target. Preview-only components and `sample/` projects were not treated as shipped behavior.
**Skills loaded:** Axiom: Accessibility; Axiom: SwiftUI; Axiom: Testing; Axiom: Apple Docs Research.
**Method boundary:** static source/project inspection only in a Linux sandbox without Xcode or Apple SDKs. No successful build, simulator/device behavior, VoiceOver hierarchy, Switch Control scan order, rendered contrast ratio, or Liquid Glass appearance is claimed. Every sample below is unapplied and requires Xcode compilation plus simulator/device validation.

## Conclusion

The active Now Playing screen has several good foundations: the main transport controls have explicit VoiceOver labels and 44-point frames, `CustomProgressSlider` supplies a 44-point touch region and a working `accessibilityAdjustableAction`, the full-screen player supports the VoiceOver escape action, and the glass utility contains a Reduce Transparency-aware fallback. Those strengths are not consistently applied across the product.

The two highest accessibility risks are common-path semantic reachability and the custom equalizer. Library tiles/rows and the mini-player entry use raw tap gestures rather than native controls, so their primary actions are not reliably exposed to VoiceOver, Full Keyboard Access, or Switch Control. The EQ's ten custom vertical sliders expose only a drag gesture in a 30-point-wide region and have no label, value, adjustable action, or keyboard path. Additional medium risks cover lyrics focus/dismissal semantics, unlabeled native sliders, sub-44-point controls, Dynamic Type clipping, unguarded motion, and shuffle/repeat state conveyed only by opacity when the symbol itself does not change.

Localization is not production-ready. The project says it prefers string catalogs but contains no `.xcstrings`, `.strings`, or `.stringsdict` resource; only English/Base regions are configured. Active UI, accessibility copy, widget metadata, and `LocalizedError` output include hardcoded English. Count-bearing text is manually concatenated without plural rules, several runtime strings bypass locale-aware `FormatStyle`, and precomposed artist/album strings prevent translators from reordering placeholders for bidirectional languages. The sole UI-test file contains no accessibility audit, Dynamic Type, locale, or RTL configuration and can skip its Now Playing coverage after querying an identifier the source never assigns.

**Retained findings: 13 — 2 High, 10 Medium, 0 Low, 1 Informational.**
**Confidence: 8 confirmed by static evidence, 5 probable.**

| Severity | Count |
|---|---:|
| Critical | 0 |
| High | 2 |
| Medium | 10 |
| Low | 0 |
| Informational | 1 |

## Findings table

| ID | Severity | Confidence | Finding |
|---|---|---|---|
| A11Y-001 | High | Probable | Core library and mini-player actions use raw tap gestures instead of semantic controls |
| A11Y-002 | High | Probable | The 10-band EQ is drag-only and has no adjustable, focus, or keyboard semantics |
| A11Y-003 | Medium | Probable | The lyrics overlay lacks an accessible close name and modal focus management |
| A11Y-004 | Medium | Probable | Volume, crossfade, and fade-out sliders do not expose purpose-specific labels/values |
| A11Y-005 | Medium | Confirmed by static evidence | Favorite and A-B loop controls have visible hit regions below 44×44 points |
| A11Y-006 | Medium | Probable | Fixed frames and line limits can clip Dynamic Type, including on the non-scrollable Now Playing surface |
| A11Y-007 | Medium | Confirmed by static evidence | Active palette and lyrics transitions do not honor Reduce Motion |
| A11Y-008 | Medium | Confirmed by static evidence | Shuffle-on and repeat-all states rely on opacity/color when their symbols do not change |
| LOC-001 | Medium | Confirmed by static evidence | There is no localization resource pipeline despite extensive English UI and accessibility copy |
| LOC-002 | Medium | Confirmed by static evidence | Count-bearing strings bypass plural rules |
| LOC-003 | Medium | Confirmed by static evidence | User-visible technical values bypass locale-aware number and measurement formatting |
| LOC-004 | Medium | Confirmed by static evidence | Precomposed metadata strings are not translator-reorderable for bidirectional layouts |
| A11YTEST-001 | Informational | Confirmed by static evidence | Accessibility, Dynamic Type, locale, RTL, and widget accessibility have no automated coverage |

---

## Full findings

### A11Y-001 — Core library and mini-player actions use raw tap gestures instead of semantic controls

- **Severity:** High
- **Confidence:** Probable
- **Code:**
  - `Fonic HiFi/Presentation/Views/Library/LibraryView.swift:195-204,217-239,250-280`
  - `Fonic HiFi/Presentation/Views/Library/LibraryView.swift:378-418`
  - `Fonic HiFi/ContentView.swift:58-68`
  - `Fonic HiFi/Presentation/Views/NowPlaying/LiquidGlassMiniPlayer.swift:18-32,36-51`
- **Source excerpt:**

  ```swift
  TrackEntityRow(track: track) {
      selectedTrack = track
  }
  .contentShape(Rectangle())
  .onTapGesture {
      playTrack(track)
  }
  ```

  ```swift
  AlbumEntityTile(album: album)
      .onTapGesture {
          selectedAlbum = album
      }
  ```

  ```swift
  LiquidGlassMiniPlayer(namespace: miniPlayerNamespace)
      // ...
      .onTapGesture {
          showingNowPlaying = true
      }
  ```

- **Why this is defective/risky:** `onTapGesture` supplies pointer/touch behavior but does not make these composite rows native `Button`/`NavigationLink` controls. The active track row compounds the problem: its only native button is the trailing Info button (`LibraryView.swift:407-414`), while the primary “play this track” action is attached outside the row as a raw gesture. A semantic accessibility tree can therefore expose title/artist text and Info without a dependable Play action. The same pattern opens albums, artists, playlists, and the full Now Playing screen. This threatens common-path VoiceOver activation, Full Keyboard Access, Voice Control naming, and Switch Control item scanning. The exact runtime hierarchy remains a device check, hence “Probable.”
- **Preserving remediation:** Keep the current layouts and destinations, but separate each action into native controls. For the track row, make the summary area a plain-styled `Button` for Play and retain a distinct Info button; do not nest one button inside another. Use `NavigationLink` for actual navigation and `Button` for sheets/playback. Give the mini-player's artwork/title region its own “Open Now Playing” button while leaving Play and Next as sibling buttons. Combine only the descriptive children of each action.
- **Safe sample (representative track-row refactor; compile/device validation required):**

  ```swift
  private struct TrackEntityRow: View {
      let track: TrackEntity
      let onPlay: () -> Void
      let onInfo: () -> Void

      var body: some View {
          HStack(spacing: 12) {
              Button(action: onPlay) {
                  HStack(spacing: 12) {
                      LazyArtworkView(trackId: track.id, size: 56, cornerRadius: 8)
                      VStack(alignment: .leading, spacing: 6) {
                          Text(track.title).font(.headline)
                          Text(track.artist).font(.subheadline)
                      }
                      Spacer()
                  }
                  .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .accessibilityElement(children: .combine)
              .accessibilityLabel("\(track.title), \(track.artist)")
              .accessibilityHint("Plays this track")

              Button(action: onInfo) {
                  Image(systemName: "info.circle")
                      .frame(width: 44, height: 44)
              }
              .accessibilityLabel("Track information")
          }
      }
  }
  ```

- **Verification and acceptance:**
  1. In Accessibility Inspector, verify every track exposes separate **Play** and **Track information** actions; album, artist, and playlist tiles expose one correctly named native action.
  2. With VoiceOver, navigate and activate every library content type without coordinate exploration.
  3. With Full Keyboard Access and Switch Control, reach and activate the same actions in a deterministic order.
  4. In the tab-bar mini player, verify “Open Now Playing,” Play/Pause, and Next are three distinct elements; opening the full player must not fire a transport control.
- **Related:** A11Y-003, A11YTEST-001, LOC-001.

### A11Y-002 — The 10-band EQ is drag-only and has no adjustable, focus, or keyboard semantics

- **Severity:** High
- **Confidence:** Probable
- **Code:** `Fonic HiFi/Presentation/Views/Settings/EqualizerView.swift:90-118,167-221`
- **Source excerpt:**

  ```swift
  VerticalSlider(
      value: $configuration.bands[index].gain,
      range: -12...12
  )
  .frame(height: 140)
  ```

  ```swift
  ZStack {
      // custom track, fill, and thumb
  }
  .gesture(
      DragGesture(minimumDistance: 0)
          .onChanged { gesture in
              // derive gain from gesture.location.y
          }
  )
  // ...
  .frame(width: 30)
  ```

- **Why this is defective/risky:** Each band is a custom drawing plus `DragGesture`. It has no `.accessibilityLabel`, `.accessibilityValue`, `.accessibilityAdjustableAction`, native `Slider`, `.focusable`, or key action. A VoiceOver user cannot discover which frequency the control edits or increment/decrement its gain through the adjustable rotor. A keyboard or Switch Control user has no semantic adjustment action, and the 30-point-wide control is also below the 44-point touch recommendation. This blocks a complete product feature for multiple assistive technologies. Runtime inspection is still required to confirm exactly what iOS exposes.
- **Preserving remediation:** Preserve the vertical EQ design and 0.5 dB snapping, but either (a) use a native `Slider` rotated/laid out vertically while keeping the existing visuals, or (b) make the custom view a single adjustable element with frequency label, localized dB value, increment/decrement logic, a minimum 44-point hit area, and Up/Down key handling. Pass the frequency into `VerticalSlider` rather than leaving it in a visually adjacent `Text`.
- **Safe sample (custom-control path; compile/device validation required):**

  ```swift
  // Keep the existing VerticalSlider drawing and DragGesture, then add at the call site:
  VerticalSlider(
      value: $configuration.bands[index].gain,
      range: -12 ... 12
  )
  .frame(minWidth: 44, minHeight: 140)
  .disabled(!configuration.isEnabled)
  .accessibilityElement(children: .ignore)
  .accessibilityLabel(
      "Equalizer gain, \(Int(configuration.bands[index].frequency)) hertz"
  )
  .accessibilityValue(
      "\(configuration.bands[index].gain.formatted(.number.precision(.fractionLength(1)))) decibels"
  )
  .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: adjustBand(at: index, by: 0.5)
      case .decrement: adjustBand(at: index, by: -0.5)
      @unknown default: break
      }
  }
  .focusable()
  .onKeyPress(.upArrow) {
      adjustBand(at: index, by: 0.5)
      return .handled
  }
  .onKeyPress(.downArrow) {
      adjustBand(at: index, by: -0.5)
      return .handled
  }

  private func adjustBand(at index: Int, by delta: Float) {
      let current = configuration.bands[index].gain
      configuration.bands[index].gain = min(12, max(-12, current + delta))
      // The existing onChange keeps preset selection, DSP application, and persistence intact.
  }
  ```

- **Verification and acceptance:**
  1. VoiceOver announces, for example, “32 hertz gain, 0.0 decibels, adjustable.”
  2. One-finger up/down changes exactly 0.5 dB, clamps at ±12 dB, invokes the existing persistence/apply path, and announces the new value.
  3. Full Keyboard Access reaches all ten bands; Up/Down changes the focused band without requiring touch.
  4. Switch Control can select and adjust each band; Accessibility Inspector reports at least a 44×44-point hit region.
  5. Re-run with EQ disabled and ensure the controls are announced as disabled.
- **Related:** A11Y-005, LOC-003, A11YTEST-001.

### A11Y-003 — The lyrics overlay lacks an accessible close name and modal focus management

- **Severity:** Medium
- **Confidence:** Probable
- **Code:**
  - `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:115-123`
  - `Fonic HiFi/Presentation/Views/NowPlaying/LyricsView.swift:14-68`
- **Source excerpt:**

  ```swift
  .overlay {
      if showingLyrics {
          LyricsView(
              lyrics: audioService?.currentTrack?.lyrics,
              isPresented: $showingLyrics
          )
      }
  }
  ```

  ```swift
  Button {
      isPresented = false
  } label: {
      Image(systemName: "xmark.circle.fill")
          .font(.title2)
  }
  // no accessibility label or accessibility focus state
  ```

- **Why this is defective/risky:** The close control is an icon-only button with no explicit accessible name. More importantly, Lyrics is inserted as a visual overlay in the same hierarchy; there is no `@AccessibilityFocusState`, no initial focus transfer, no hiding of the underlying player from the accessibility tree, and no local escape action. VoiceOver focus can remain on obscured playback controls or enter the overlay at an arbitrary point. The dimming layer's touch-only tap-to-dismiss is not a replacement for semantic dismissal. Runtime focus behavior must be verified on device.
- **Preserving remediation:** Keep the visual overlay, but split the base player and overlay into sibling layers, set `.accessibilityHidden(showingLyrics)` on the base layer, name the close button, move VoiceOver focus to the Lyrics heading/close control on presentation, support `.escape`, and restore focus to the More Options control on dismissal. A system sheet/full-screen cover is also safe if its presentation can preserve the current visual direction.
- **Safe sample (overlay-local portion; compile/device validation required):**

  ```swift
  struct LyricsView: View {
      let lyrics: String?
      @Binding var isPresented: Bool
      @AccessibilityFocusState private var closeFocused: Bool

      var body: some View {
          VStack {
              HStack {
                  Text("Lyrics").font(.headline)
                  Spacer()
                  Button { isPresented = false } label: {
                      Image(systemName: "xmark.circle.fill")
                          .frame(width: 44, height: 44)
                  }
                  .accessibilityLabel("Close lyrics")
                  .accessibilityFocused($closeFocused)
              }
              // Preserve the existing lyrics ScrollView.
          }
          .onAppear { closeFocused = true }
          .accessibilityAction(.escape) { isPresented = false }
      }
  }
  ```

- **Verification and acceptance:**
  1. Open Lyrics with VoiceOver; focus immediately announces Lyrics or “Close lyrics.”
  2. Swipe navigation cannot reach obscured Now Playing controls while the overlay is open.
  3. The close button, two-finger scrub/escape action, and Switch Control all dismiss the overlay.
  4. After dismissal, focus returns to More Options (or the control that opened Lyrics), not the top of the screen.
- **Related:** A11Y-001, A11Y-007, A11YTEST-001.

### A11Y-004 — Volume, crossfade, and fade-out sliders do not expose purpose-specific labels/values

- **Severity:** Medium
- **Confidence:** Probable
- **Code:**
  - `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:514-540`
  - `Fonic HiFi/Presentation/Views/Settings/AudioSettingsView.swift:95-108`
  - `Fonic HiFi/Presentation/Views/NowPlaying/SleepTimerSheet.swift:103-117`
- **Source excerpt:**

  ```swift
  Slider(
      value: Binding(/* volume */),
      in: 0 ... 1
  )
  .tint(theme.accent)
  ```

  ```swift
  Text("Crossfade")
  // ...
  Slider(value: $crossfadeDuration, in: 0...12, step: 1)
  ```

  ```swift
  Text("Duration")
  // ...
  Slider(value: $fadeOutDuration, in: 10...60, step: 5)
  ```

- **Why this is defective/risky:** These native sliders retain adjustable behavior, but unlike the Buffer Size slider (`AudioSettingsView.swift:54-60`) they do not use the label-bearing `Slider` initializer or explicit accessibility labels/values. Visually adjacent text and speaker symbols are not a guaranteed programmatic label association. VoiceOver may expose a percentage/value without saying whether it is Volume, Crossfade, or Fade Out Duration, especially when several controls share a form.
- **Preserving remediation:** Use the label closure for every `Slider` and provide a localized value that includes the correct unit or “Off.” Keep the adjacent visible labels if desired; SwiftUI can still use the semantic label without changing the visual design.
- **Safe sample (compile/device validation required):**

  ```swift
  Slider(value: $volumeStorage, in: 0 ... 1) {
      Text("Volume")
  }
  .accessibilityValue(
      Text(volumeStorage, format: .percent.precision(.fractionLength(0)))
  )

  Slider(value: $crossfadeDuration, in: 0 ... 12, step: 1) {
      Text("Crossfade duration")
  }
  .accessibilityValue(
      crossfadeDuration == 0
          ? Text("Off")
          : Text("^[\(Int(crossfadeDuration)) second](inflect: true)")
  )
  ```

- **Verification and acceptance:** VoiceOver must announce each control's purpose, current localized value/unit, “adjustable,” and disabled state where applicable; rotor adjustment must use the existing step and persist/apply the change. Verify Volume, Crossfade, Fade Out Duration, and Buffer Size in sequence so no two controls have an ambiguous announcement.
- **Related:** LOC-002, LOC-003, A11YTEST-001.

### A11Y-005 — Favorite and A-B loop controls have visible hit regions below 44×44 points

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:** `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:352-364,407-425`
- **Source excerpt:**

  ```swift
  Button {
      toggleFavorite()
  } label: {
      Image(systemName: isFavorite ? "heart.fill" : "heart")
          .font(.system(size: 20, weight: .medium))
          .contentShape(.rect)
  }
  ```

  ```swift
  Button {
      handleLoopTap()
  } label: {
      Image(systemName: loopButtonIcon)
          .font(.system(size: 14, weight: .medium))
  }
  ```

- **Why this is defective/risky:** Neither label receives a minimum frame or padding. `contentShape` changes the shape of existing bounds; it does not enlarge a 20-point or 14-point symbol to a 44-point hit region. Neighboring queue/transport controls explicitly use 44×44 frames, confirming the omission is localized rather than an intentional global sizing system. These small targets increase missed taps and make motor-access selection harder.
- **Preserving remediation:** Give each button label a 44×44 frame and rectangular content shape, preserving the symbol size and current spacing. Do not enlarge only the visual glyph.
- **Safe sample (compile/device validation required):**

  ```swift
  Button(action: toggleFavorite) {
      Image(systemName: isFavorite ? "heart.fill" : "heart")
          .font(.system(size: 20, weight: .medium))
          .frame(width: 44, height: 44)
          .contentShape(Rectangle())
  }
  .buttonStyle(.plain)
  .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
  ```

- **Verification and acceptance:** Accessibility Inspector must report at least 44×44 points for Favorite and A-B Loop in all states. Tap the four corners of each region on the smallest supported iPhone and verify only the intended control activates; confirm adjacent overflow/time labels remain independently reachable.
- **Related:** A11Y-002.

### A11Y-006 — Fixed frames and line limits can clip Dynamic Type, including on the non-scrollable Now Playing surface

- **Severity:** Medium
- **Confidence:** Probable
- **Code:**
  - `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:17,59-102,335-371`
  - `Fonic HiFi/Presentation/Views/Home/Sections/ExpandableAlbumCard.swift:15-40`
  - `Fonic HiFi/Presentation/Views/Home/Sections/AlbumsSection.swift:22-32`
- **Source excerpt:**

  ```swift
  @Environment(\.sizeCategory) private var sizeCategory
  // sizeCategory is not used

  VStack(spacing: 0) {
      // artwork, track info, progress, transport, volume and fixed spacers
  }
  // no vertical ScrollView or accessibility-size branch
  ```

  ```swift
  Text(album.title)
      .font(.callout.bold())
      .lineLimit(1)
  Text(album.albumArtist)
      .font(.caption)
      .lineLimit(1)
  // ...
  .frame(height: 34, alignment: .topLeading)
  .frame(width: 140, alignment: .leading)
  ```

- **Why this is defective/risky:** Dynamic Type fonts expand, but the Home album-card text is constrained to a fixed 34-point height and one line per field. On Now Playing, the declared `sizeCategory` environment value is unused; a tall stack of artwork, controls, and fixed spacer ranges has no vertical scrolling or accessibility-size alternative. Track title and artist remain one line. Long metadata, accessibility sizes, or landscape height can therefore truncate text or push controls out of reach. Static code proves the constraints; the exact devices/sizes that fail require rendering.
- **Preserving remediation:** Remove fixed text heights, allow important metadata to wrap, use `dynamicTypeSize.isAccessibilitySize` to reduce decorative artwork/spacers and switch compact horizontal groupings to vertical layouts, and make the Now Playing content vertically scrollable when it cannot fit. Keep the current visual arrangement at standard sizes.
- **Safe sample (album card; compile/device validation required):**

  ```swift
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  private var cardWidth: CGFloat {
      dynamicTypeSize.isAccessibilitySize ? 220 : 140
  }

  var body: some View {
      VStack(alignment: .leading, spacing: 8) {
          LazyArtworkView(album: album, size: cardWidth, cornerRadius: 8)
          Text(album.title)
              .font(.callout.bold())
              .lineLimit(2)
          Text(album.albumArtist)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(2)
      }
      .frame(width: cardWidth, alignment: .leading)
  }
  ```

- **Verification and acceptance:** Test every content-size category through AX5, including an iPhone SE-sized simulator, portrait and both declared landscape orientations, long track/artist/album strings, and Xcode's double-length pseudolanguage. No primary text may clip or overlap, and all Now Playing controls must remain reachable by scrolling/focus without shrinking text below the selected size.
- **Related:** LOC-001, A11YTEST-001. This overlaps the layout risk independently reported by UI/UX and adds the accessibility-size acceptance contract.

### A11Y-007 — Active palette and lyrics transitions do not honor Reduce Motion

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Core/Services/DominantColorService.swift:45-46,56-81,83-138`
  - `Fonic HiFi/ContentView.swift:18-20,83-97`
  - `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:115-123`
- **Source excerpt:**

  ```swift
  private let transitionDuration: Double = 2.5

  withAnimation(.easeInOut(duration: transitionDuration)) {
      rebuildPalette()
  }
  ```

  ```swift
  .animation(
      .easeInOut(duration: DesignTokens.Animation.quickFadeDuration),
      value: showingLyrics
  )
  ```

- **Why this is defective/risky:** Artwork/color-scheme/settings changes route through the shared `DominantColorService`, which always wraps palette publication in a 2.5-second animation. Lyrics presentation also always animates. Neither active path reads or is configured from `accessibilityReduceMotion`. Users who request reduced motion therefore still receive app-authored transitions. This finding concerns the missing preference branch only; it does not claim how the transitions look on a device.
- **Preserving remediation:** Read `accessibilityReduceMotion` in an active view, propagate it into the shared service, centralize palette publication in one helper that disables animations when requested, and pass `nil` animation for Lyrics. Do not disable state updates or artwork theming itself.
- **Safe sample (compile/device validation required):**

  ```swift
  // ContentView
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  .onAppear { colorService.setReduceMotion(reduceMotion) }
  .onChange(of: reduceMotion) { _, value in
      colorService.setReduceMotion(value)
  }

  // DominantColorService
  private var reduceMotion = false

  func setReduceMotion(_ value: Bool) { reduceMotion = value }

  private func publishPaletteChange() {
      if reduceMotion {
          var transaction = Transaction()
          transaction.disablesAnimations = true
          withTransaction(transaction) { rebuildPalette() }
      } else {
          withAnimation(.easeInOut(duration: transitionDuration)) {
              rebuildPalette()
          }
      }
  }
  ```

- **Verification and acceptance:** With Reduce Motion off, preserve the current transitions. With it on before launch and toggled while running, changing tracks/themes and opening/closing Lyrics must update immediately without app-authored scale/zoom/long fade animation. Verify with Xcode/device; do not infer from static code alone.
- **Related:** A11Y-003, A11YTEST-001.

### A11Y-008 — Shuffle-on and repeat-all states rely on opacity/color when their symbols do not change

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:** `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:439-450,497-506,544-549`
- **Source excerpt:**

  ```swift
  Image(systemName: "shuffle")
      .foregroundStyle(.white.opacity(isShuffleEnabled ? 1.0 : 0.6))
  ```

  ```swift
  Image(systemName: repeatModeIcon)
      .foregroundStyle(.white.opacity(repeatMode != .none ? 1.0 : 0.6))

  private var repeatModeIcon: String {
      switch repeatMode {
      case .none: "repeat"
      case .all: "repeat"
      case .one: "repeat.1"
      }
  }
  ```

- **Why this is defective/risky:** Shuffle uses the same symbol in both states; only opacity changes. Repeat Off and Repeat All also share the same symbol and differ only by opacity. VoiceOver receives state-specific labels, but sighted users who enable Differentiate Without Color—or who cannot reliably perceive the opacity/color difference—have no non-color state cue for Shuffle On or Repeat All. No rendered contrast claim is made.
- **Preserving remediation:** Read `accessibilityDifferentiateWithoutColor` and add a shape/text cue (for example, a small checkmark badge) when Shuffle or Repeat is active. Preserve the current styling when the preference is off and retain the existing VoiceOver labels.
- **Safe sample (compile/device validation required):**

  ```swift
  @Environment(\.accessibilityDifferentiateWithoutColor)
  private var differentiateWithoutColor

  ZStack(alignment: .topTrailing) {
      Image(systemName: "shuffle")
      if differentiateWithoutColor && isShuffleEnabled {
          Image(systemName: "checkmark.circle.fill")
              .font(.caption2)
      }
  }
  .frame(width: 44, height: 44)
  ```

- **Verification and acceptance:** Enable Differentiate Without Color and verify Shuffle Off/On and Repeat Off/All/One are visually distinguishable without relying on hue or opacity. With VoiceOver, labels must still announce the exact state. Recheck standard mode to ensure the product's current visual direction is unchanged.
- **Related:** A11YTEST-001.

### LOC-001 — There is no localization resource pipeline despite extensive English UI and accessibility copy

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi.xcodeproj/project.pbxproj:281-286,519-525,578-583`
  - `Fonic HiFi/ContentView.swift:27-50,101-118`
  - `Fonic HiFi/Presentation/Views/Components/AccessibilityEnhancements.swift:263-295,330-390`
  - `Fonic HiFi/Core/Audio/Interfaces/AudioError.swift:51-120`
  - `Fonic HiFi Widget/NowPlayingWidget.swift:34-35`
  - `Fonic HiFi Widget/Info.plist:5-6`
- **Source excerpt:**

  ```text
  developmentRegion = en;
  knownRegions = (
      en,
      Base,
  );
  LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
  STRING_CATALOG_GENERATE_SYMBOLS = YES;
  ```

  ```swift
  Tab("Home", systemImage: "house.fill") { ... }
  Tab("Library", systemImage: "music.note.list") { ... }
  Text("Library Unavailable")
  ```

  ```swift
  public var errorDescription: String? {
      switch self {
      case let .unsupportedFormat(format):
          "The audio format '\(format)' is not supported"
      // ...
      }
  }
  ```

  ```swift
  .configurationDisplayName("Now Playing")
  .description("See what's playing and control playback.")
  ```

- **Why this is defective/risky:** The project opts into string catalogs but the repository contains no `.xcstrings`, `.strings`, `.stringsdict`, or `.xcloc` resource. Only English and Base are declared. SwiftUI literal initializers are extraction-capable, but without a target resource and translations they remain English; plain `String` values built in computed properties, accessibility labels, error descriptions, and widget metadata also require explicit localization handling. The result is an English-only app/widget and an English VoiceOver experience, with no translator comments or reviewable key inventory. A static sink scan found 251 direct literal UI/accessibility constructor occurrences in the app target and 14 in the widget target; this is scope evidence, not an AST-complete count.
- **Preserving remediation:** Add `Localizable.xcstrings` to the app and widget targets (and `InfoPlist.xcstrings` for target metadata/display names), let Xcode extract SwiftUI/AppIntent literals, then explicitly migrate runtime/computed `String` values to `String(localized:)` or `LocalizedStringResource`. Add translator comments and stable keys for accessibility copy, errors, technical units, and placeholder-reorderable phrases. Preserve feature names and product identity.
- **Safe sample (runtime string path; compile/Xcode extraction validation required):**

  ```swift
  enum L10n {
      static let notPlaying = String(
          localized: "playback.not-playing",
          defaultValue: "Not Playing",
          comment: "Track title shown when no audio is selected"
      )

      static func unsupportedFormat(_ format: String) -> String {
          String(
              localized: "error.unsupported-format \(format)",
              defaultValue: "The audio format '\(format)' is not supported",
              comment: "Playback error; format is a short value such as FLAC"
          )
      }
  }
  ```

- **Verification and acceptance:**
  1. Xcode's Export Localizations produces app, widget, InfoPlist, App Intent, and accessibility strings with translator comments.
  2. Build with a non-English test localization and both pseudolanguages; no product UI/accessibility/error copy remains unexpectedly English.
  3. Verify dynamic metadata (track names, file names, format identifiers) remains verbatim while surrounding grammar translates.
  4. Run `xcodebuild -exportLocalizations`/String Catalog validation in CI and fail on stale/missing translations according to release policy.
- **Related:** LOC-002, LOC-003, LOC-004, A11YTEST-001.

### LOC-002 — Count-bearing strings bypass plural rules

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Presentation/Views/Library/LibraryView.swift:471-480,493-521`
  - `Fonic HiFi/Presentation/Views/Queue/QueueView.swift:40-50`
  - `Fonic HiFi/Presentation/Views/Import/ImportProgressView.swift:113-140`
- **Source excerpt:**

  ```swift
  Label("\(artist.albumCount) Albums", systemImage: "square.stack")
  Label("\(artist.trackCount) Tracks", systemImage: "music.note")
  Text("\(playlist.trackCount) Tracks")
  ```

  ```swift
  Section("Up Next \u{2022} \(remaining.count) tracks")
  ```

  ```swift
  Text("\(errors.count) files failed to import")
  ```

- **Why this is defective/risky:** The noun is fixed in English regardless of count, producing “1 Albums,” “1 Tracks,” and “1 files.” Translating only the noun does not solve languages with zero/one/two/few/many categories or reordered count phrases. These are active, user-facing library, queue, and error paths.
- **Preserving remediation:** Put the complete count phrase in the string catalog with plural variations or use Apple's automatic grammar inflection where appropriate. Do not concatenate a localized number with a separately localized noun.
- **Safe sample (compile/catalog review required):**

  ```swift
  Label(
      "^[\(artist.albumCount) album](inflect: true)",
      systemImage: "square.stack"
  )

  Text("^[\(errors.count) file](inflect: true) failed to import")

  Section("Up Next · ^[\(remaining.count) track](inflect: true)") {
      // existing rows
  }
  ```

- **Verification and acceptance:** Exercise counts 0, 1, 2, 3, 11, and 21 under English plus at least one locale with multiple plural categories. A linguist/catalog review must confirm the full phrase, count placement, and punctuation. VoiceOver must announce the same grammatically correct phrase.
- **Related:** LOC-001, A11Y-004, A11YTEST-001.

### LOC-003 — User-visible technical values bypass locale-aware number and measurement formatting

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Presentation/Views/Settings/AudioSettingsView.swift:45-84`
  - `Fonic HiFi/Presentation/Views/Settings/EqualizerView.swift:106-115`
  - `Fonic HiFi/Presentation/Views/NowPlaying/DiagnosticsDetailView.swift:95-113`
- **Source excerpt:**

  ```swift
  Text("44,100 Hz").tag(44100.0)
  Text("48,000 Hz").tag(48000.0)
  // ...
  Text("192,000 Hz").tag(192_000.0)
  ```

  ```swift
  Text(String(format: "%.1f", configuration.bands[index].gain))
  ```

  ```swift
  Text(String(format: "%.1f%%", metrics.cpuUsage))
  Text(String(format: "%.2f ms", metrics.renderLatency * 1000))
  ```

- **Why this is defective/risky:** Fixed comma-grouped sample-rate strings encode one presentation, while runtime `String(format:)` results combine the number and unit into an already-built `String` that SwiftUI/string catalogs cannot reorder or format with `FormatStyle`. This bypasses locale-aware digit grouping, decimal precision policy, percent formatting, unit spacing/order, and translator context. This finding does not assert that every `String(format:)` call renders a dot in every locale; the defect is bypassing the locale/measurement pipeline for active UI values.
- **Preserving remediation:** Keep canonical numeric values in the model and format only at the view boundary with `NumberFormatStyle`, `PercentFormatStyle`, `Measurement`, or `Duration` formatting. Keep SI symbols such as Hz/dB where appropriate, but localize the complete phrase/value for accessibility and languages that reorder units.
- **Safe sample (compile/locale validation required):**

  ```swift
  ForEach([44_100.0, 48_000.0, 88_200.0, 96_000.0, 176_400.0, 192_000.0], id: \.self) { rate in
      Text("\(rate.formatted(.number.grouping(.automatic))) Hz")
          .tag(rate)
  }

  Text(
      configuration.bands[index].gain,
      format: .number.precision(.fractionLength(1))
  )

  Text(
      metrics.cpuUsage / 100,
      format: .percent.precision(.fractionLength(1))
  )
  ```

- **Verification and acceptance:** Snapshot/assert representative output under `en_US`, `fr_FR`, `de_DE`, `ar_SA`, and a locale using non-Latin digits. Check sample rate, gain including negative values, percentages, latency, durations, and file sizes. Units and values must remain technically accurate, parse-independent, and correctly announced by VoiceOver.
- **Related:** LOC-001, LOC-004, A11Y-002, A11Y-004.

### LOC-004 — Precomposed metadata strings are not translator-reorderable for bidirectional layouts

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi Widget/Shared/WidgetTrackInfo.swift:61-87`
  - `Fonic HiFi Widget/Views/MediumWidgetView.swift:52-76`
  - `Fonic HiFi Widget/Views/LargeWidgetView.swift:53-77`
  - `Fonic HiFi Widget/Views/AccessoryInlineView.swift:16-44`
  - duplicated app model: `Fonic HiFi/Shared/WidgetTrackInfo.swift:61-87`
- **Source excerpt:**

  ```swift
  public var artistAlbum: String {
      if album.isEmpty {
          return artist
      }
      return "\(artist) — \(album)"
  }
  ```

  ```swift
  Text(entry.trackInfo.artistAlbum)
  ```

  ```swift
  Text("\(entry.trackInfo.title) - \(entry.trackInfo.artist)")
  ```

- **Why this is defective/risky:** `artistAlbum` returns a completed runtime `String`, and `Text(variable)` treats it as content rather than a localizable template. Translators cannot reorder artist and album placeholders, change the separator, or add context. Mixed Arabic/Hebrew UI plus Latin metadata can also produce confusing punctuation/order without a localized template and bidirectional isolation. The same model is duplicated in app and widget sources, so fixes can drift.
- **Preserving remediation:** Keep artist/title/album as separate data. Create a `LocalizedStringResource` (or localized catalog key with named placeholders) at the display boundary, and allow translators to reorder placeholders and punctuation. Avoid manual left/right padding or forced layout direction; SwiftUI leading/trailing layout should continue to mirror naturally. Apply the same implementation to both model copies or share one target-safe source.
- **Safe sample (compile/catalog/RTL validation required):**

  ```swift
  public var artistAlbumResource: LocalizedStringResource {
      if album.isEmpty {
          return "\(artist)"
      }
      return "\(artist) — \(album)"
  }

  // Widget view
  Text(entry.trackInfo.artistAlbumResource)
      .lineLimit(1)
  ```

  Add a translator comment in the string catalog stating that both placeholders are user-provided metadata and may contain opposite-direction text.

- **Verification and acceptance:** Launch the widget and app under Arabic and Hebrew with (a) Latin artist/album names, (b) Arabic/Hebrew names, and (c) one value in each direction. Verify natural reading order, mirrored layout, stable punctuation, no clipped minus signs/time values, and correct VoiceOver order in all widget families.
- **Related:** LOC-001, LOC-003, A11YTEST-001.

### A11YTEST-001 — Accessibility, Dynamic Type, locale, RTL, and widget accessibility have no automated coverage

- **Severity:** Informational
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFiUITests/LibraryNowPlayingSmokeTests.swift:1-117`
  - `Fonic HiFi/ContentView.swift:58-68`
  - `Fonic HiFi/Presentation/Views/NowPlaying/LiquidGlassMiniPlayer.swift:18-32`
- **Source excerpt:**

  ```swift
  let miniPlayer = app.otherElements["MiniPlayer"]
  guard miniPlayer.waitForExistence(timeout: 5) else {
      throw XCTSkip("Mini player not visible")
  }
  ```

  ```swift
  func testTabNavigationAndSettingsLinks() throws {
      // English-label smoke navigation only
  }
  ```

- **Why this is a gap:** `Fonic HiFiUITests` contains this single Swift file. It does not call `performAccessibilityAudit`, launch at accessibility content sizes, set `AppleLanguages`/`AppleLocale`, test RTL, exercise Reduce Motion/Transparency, or cover the widget. The tests query English labels directly. Both Now Playing tests query “MiniPlayer,” but the source call site assigns no `.accessibilityIdentifier("MiniPlayer")`; each test then skips rather than failing, so the most relevant interaction coverage can silently disappear. This is a verification gap, not proof that every runtime surface fails.
- **Preserving remediation:** Add stable, nonlocalized accessibility identifiers used only for automation; replace skip-on-missing for required preview data with a failure; add default and AX5/RTL test-plan configurations; run `XCUIApplication.performAccessibilityAudit()` on Home, Library, Search, Now Playing, Lyrics, Queue, Settings/EQ, Import, and error states. Keep manual VoiceOver/Switch Control/widget checks because automation does not prove scan order or usability.
- **Safe sample (Xcode/device runtime validation required):**

  ```swift
  func testLibraryAccessibilityAuditInArabicAtAX5() throws {
      let app = XCUIApplication()
      app.launchArguments += [
          "-UITestPreviewData",
          "-AppleLanguages", "(ar)",
          "-AppleLocale", "ar_SA",
          "-UIPreferredContentSizeCategoryName",
          "UICTContentSizeCategoryAccessibilityXXXL"
      ]
      app.launch()

      try app.performAccessibilityAudit()
  }
  ```

  ```swift
  LiquidGlassMiniPlayer(namespace: miniPlayerNamespace)
      .accessibilityIdentifier("miniPlayer")
  ```

- **Verification and acceptance:** CI must run the accessibility audit in at least standard English and one RTL/AX5 configuration without skips. Required elements use stable identifiers rather than localized labels. Add manual release evidence for VoiceOver focus/order, adjustable controls, Switch Control, Full Keyboard Access, Reduce Motion/Transparency, Dynamic Type AX1–AX5, contrast measurements, and all supported widget families.
- **Related:** all retained accessibility/localization findings.

---

## Rejected candidate findings

1. **No rendered contrast failure was retained.** Source uses system semantic colors, artwork-derived palettes, opacities, and Liquid Glass. Static source alone cannot establish final foreground/background pixels or a WCAG ratio. Measure each active state with Accessibility Inspector/on-device capture before filing a contrast defect.
2. **The custom playback progress slider was not called wholly inaccessible.** `CustomProgressSlider.swift:87-125` provides a 44-point region, ignores decorative children, supplies a label/value, and implements working increment/decrement actions. A device check should still assess whether elapsed/remaining time would be a better value than percent and whether A/B markers need additional announcements.
3. **A no-op adjustable action in `ProgressControlAccessibility` was not retained.** `AccessibilityEnhancements.swift:341-359` contains `break` in both directions, but the modifier has no production call site; its only visible use is a preview. It should be deleted or corrected if adopted, but prior/dead helper code alone is not a production defect.
4. **Preview-only custom controls were not treated as active defects.** `LiquidGlassTabBar` and `BottomSearchBar` contain fixed fonts/raw gestures/unconditional animations, but repository references are limited to their own previews/containers; the active app uses native `TabView`/`.searchable`.
5. **The diagnostics support indicator was not called color-only.** It changes both symbol shape (`checkmark.circle.fill` versus `xmark.circle.fill`) and color, and the surrounding `LabeledContent` supplies context. A VoiceOver value label may still improve clarity but is not enough static evidence for a retained color-only defect.
6. **No blanket “all icons are unlabeled” finding was retained.** The active Now Playing queue, favorite, shuffle, previous, play/pause, next, repeat, and A-B loop controls mostly provide explicit labels; findings target the actual omissions and semantics above.
7. **No claim was made that system `.glassEffect` fails Reduce Transparency.** The OS may adapt system glass automatically. The app's explicit `a11yAwareGlass` fallback exists (`GlassModifiers.swift:209-258,357-364`) but active `.glassSurface` uses a different modifier without that branch (`GlassModifiers.swift:82-104,332-339`). Validate on device before deciding whether to merge the modifiers.

## Open build/device checks

1. **VoiceOver hierarchy and grouping:** Inspect Library rows/tiles, Home cards, mini player, Lyrics, Queue, file rows, search results, and every icon-only control. Record labels, traits, values, hints, custom actions, and focus order.
2. **Adjustable controls:** Exercise playback progress, volume, buffer, crossfade, sleep fade, and all EQ bands with VoiceOver rotor, Switch Control, and Full Keyboard Access; verify steps, bounds, disabled state, and persistence.
3. **Dynamic Type/truncation:** Run all categories through AX5 on the smallest supported iPhone, portrait and both declared landscape orientations, with long metadata and double-length pseudolanguage. Now Playing, Home cards, segmented Library tabs, Settings details, and widgets need screenshots/results.
4. **Touch targets:** Use Accessibility Inspector to measure Favorite, A-B Loop, mini-player controls, widget controls, file rows, and custom EQ bands. Do not infer points from glyph size after remediation.
5. **Reduce Motion:** Toggle before launch and at runtime; inspect tab/player presentation, lyrics, artwork palette changes, progress updates, symbols, and widget effects.
6. **Reduce Transparency:** Compare active glass cards, recovery banner, tab accessory, Lyrics, and any system glass with the setting on/off. Confirm solid fallback readability; static code cannot prove the OS rendering.
7. **Differentiate Without Color:** Verify shuffle, repeat, favorite, import errors, EQ sign, diagnostics status, and selected tabs have a non-color cue.
8. **Contrast:** Measure text, icons, disabled controls, gradients, artwork-reactive themes, and glass surfaces in every state with an approved tool. This audit intentionally reports no unmeasured ratio.
9. **Focus/modal behavior:** Open/dismiss full Now Playing, Lyrics, Queue, Sleep Timer, track details, import/error sheets, and file details with VoiceOver and Switch Control; focus must enter, remain in, and return from each presentation predictably.
10. **Localization and bidi:** Build pseudolanguages plus at least Arabic/Hebrew and a decimal-comma locale. Verify placeholder reordering, plural categories, number/unit/date/file-size formatting, mirrored navigation, custom progress geometry, and mixed-direction metadata.
11. **Widget accessibility:** Test all six declared families in Home Screen, Lock Screen, StandBy, full-color/vibrant/accented render modes. Confirm control names/states, progress semantics, truncation, and target reachability.
12. **Automated audit:** Add stable identifiers, eliminate required-path skips, run `performAccessibilityAudit()` across state fixtures, and archive the `.xcresult`. Automation supplements rather than replaces manual assistive-technology testing.

## Reference anchors

- Apple Accessibility fundamentals and VoiceOver: `https://developer.apple.com/accessibility/`
- SwiftUI accessibility adjustable actions: `https://developer.apple.com/documentation/swiftui/view/accessibilityadjustableaction(_:)`
- SwiftUI Reduce Motion environment: `https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion`
- Xcode string catalogs: `https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog`
- Foundation format styles: `https://developer.apple.com/documentation/foundation/formatstyle`
- XCTest accessibility audits: `https://developer.apple.com/documentation/xctest/xcuiapplication/performaccessibilityaudit(for:issuehandler:)`
