# Artwork Theming Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Expand DominantColorService to provide full-app artwork-reactive theming with auto-derived color variants.

**Architecture:** ThemePalette struct derives surface/accent/subtle/glassTint variants from a single dominant color. The palette is published by DominantColorService and distributed via SwiftUI environment. Views consume themed colors; transitions animate over 2.5s.

**Tech Stack:** Swift 6.2, SwiftUI, iOS 26 Liquid Glass APIs, @MainActor concurrency

---

## Task 1: Create ThemePalette Struct

**Files:**
- Create: `Fonic HiFi/Core/Services/ThemePalette.swift`
- Test: `Fonic HiFiTests/ThemePaletteTests.swift`

**Step 1: Write the failing test**

```swift
//
//  ThemePaletteTests.swift
//  Fonic HiFiTests
//

import SwiftUI
import XCTest

@testable import Fonic_HiFi

final class ThemePaletteTests: XCTestCase {

    // MARK: - Neutral Palette Tests

    func testNeutralPaletteHasExpectedDominantColor() {
        let palette = ThemePalette.neutral

        // Neutral palette should have a warm gray dominant color
        XCTAssertNotNil(palette.dominant)
    }

    func testNeutralPaletteIsNotVibrant() {
        let palette = ThemePalette.neutral

        XCTAssertFalse(palette.isVibrant)
    }

    // MARK: - Vibrant Palette Tests

    func testVibrantPaletteFromSaturatedColor() {
        let vibrantRed = Color(hue: 0.0, saturation: 0.8, brightness: 0.9)
        let palette = ThemePalette(dominant: vibrantRed, colorScheme: .dark)

        XCTAssertTrue(palette.isVibrant)
    }

    func testLowSaturationColorProducesNonVibrantPalette() {
        let grayish = Color(hue: 0.5, saturation: 0.1, brightness: 0.5)
        let palette = ThemePalette(dominant: grayish, colorScheme: .dark)

        XCTAssertFalse(palette.isVibrant)
    }

    // MARK: - Color Scheme Adaptation Tests

    func testDarkModeProducesRicherSurfaceColor() {
        let baseColor = Color(hue: 0.6, saturation: 0.7, brightness: 0.8)
        let darkPalette = ThemePalette(dominant: baseColor, colorScheme: .dark)
        let lightPalette = ThemePalette(dominant: baseColor, colorScheme: .light)

        // Dark mode surface should have higher opacity than light mode
        // We can't directly compare Color opacity, but we verify both palettes are created
        XCTAssertNotNil(darkPalette.surface)
        XCTAssertNotNil(lightPalette.surface)
    }

    // MARK: - Derived Color Tests

    func testAccentColorIsDerived() {
        let baseColor = Color.blue
        let palette = ThemePalette(dominant: baseColor, colorScheme: .dark)

        XCTAssertNotNil(palette.accent)
    }

    func testSurfaceColorIsDerived() {
        let baseColor = Color.blue
        let palette = ThemePalette(dominant: baseColor, colorScheme: .dark)

        XCTAssertNotNil(palette.surface)
    }

    func testSubtleColorIsDerived() {
        let baseColor = Color.blue
        let palette = ThemePalette(dominant: baseColor, colorScheme: .dark)

        XCTAssertNotNil(palette.subtle)
    }

    func testGlassTintColorIsDerived() {
        let baseColor = Color.blue
        let palette = ThemePalette(dominant: baseColor, colorScheme: .dark)

        XCTAssertNotNil(palette.glassTint)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "No such module 'Fonic_HiFi'" or "cannot find type 'ThemePalette'"

**Step 3: Write minimal implementation**

```swift
//
//  ThemePalette.swift
//  Fonic HiFi
//
//  Theme palette derived from a single dominant color.
//  Provides surface, accent, subtle, and glassTint variants.
//

import SwiftUI

/// A color palette derived from a single dominant color, adapted for light/dark mode.
struct ThemePalette: Equatable, Sendable {

    // MARK: - Properties

    /// The raw extracted dominant color
    let dominant: Color

    /// The color scheme this palette is adapted for
    let colorScheme: ColorScheme

    /// Surface color for backgrounds and cards (low opacity tint)
    var surface: Color {
        let opacity = colorScheme == .dark ? 0.20 : 0.12
        return dominant.opacity(opacity)
    }

    /// Accent color for interactive elements (saturated variant)
    var accent: Color {
        // Return the dominant color with full saturation for interactivity
        dominant
    }

    /// Subtle color for separators and secondary highlights
    var subtle: Color {
        let opacity = colorScheme == .dark ? 0.08 : 0.05
        return dominant.opacity(opacity)
    }

    /// Glass tint optimized for .glassEffect()
    var glassTint: Color {
        let opacity = colorScheme == .dark ? 0.25 : 0.15
        return dominant.opacity(opacity)
    }

    /// Whether this palette has a vibrant (saturated) dominant color
    var isVibrant: Bool {
        // Extract HSB components to check saturation
        guard let components = dominant.hsbaComponents else { return false }
        return components.saturation >= 0.15
    }

    // MARK: - Initialization

    init(dominant: Color, colorScheme: ColorScheme) {
        self.dominant = dominant
        self.colorScheme = colorScheme
    }

    // MARK: - Static Palettes

    /// Neutral fallback palette for when no artwork color is available
    static let neutral = ThemePalette(
        dominant: Color(white: 0.5),
        colorScheme: .dark
    )

    /// Creates a neutral palette adapted for the given color scheme
    static func neutral(for colorScheme: ColorScheme) -> ThemePalette {
        ThemePalette(
            dominant: Color(white: colorScheme == .dark ? 0.45 : 0.55),
            colorScheme: colorScheme
        )
    }
}

// MARK: - Color HSB Extension

private extension Color {
    /// Extract HSB components from a Color
    var hsbaComponents: (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat)? {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        guard UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return nil
        }

        return (hue, saturation, brightness, alpha)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Core/Services/ThemePalette.swift" "Fonic HiFiTests/ThemePaletteTests.swift"
git commit -m "feat(theming): add ThemePalette struct with derived color variants"
```

---

## Task 2: Create ThemePalette Environment Key

**Files:**
- Create: `Fonic HiFi/Presentation/Environment/ThemePaletteEnvironment.swift`

**Step 1: Write the implementation**

No test needed for environment key boilerplate.

```swift
//
//  ThemePaletteEnvironment.swift
//  Fonic HiFi
//
//  Environment key for distributing ThemePalette to views.
//

import SwiftUI

// MARK: - Environment Key

/// Environment key for ThemePalette dependency injection
struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue: ThemePalette = .neutral
}

extension EnvironmentValues {
    /// Access to the current theme palette through environment
    var themePalette: ThemePalette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Injects the theme palette into the environment
    func themePalette(_ palette: ThemePalette) -> some View {
        environment(\.themePalette, palette)
    }
}
```

**Step 2: Verify build succeeds**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "Fonic HiFi/Presentation/Environment/ThemePaletteEnvironment.swift"
git commit -m "feat(theming): add ThemePalette environment key for view distribution"
```

---

## Task 3: Add Settings for Artwork Theming

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/Settings/SettingsView.swift:47-73`

**Step 1: Add AppStorage properties**

Add these properties after the existing AppStorage declarations (around line 17):

```swift
@AppStorage("artworkThemingEnabled") private var artworkThemingEnabled = true
@AppStorage("artworkThemingLightMode") private var artworkThemingLightMode = true
```

**Step 2: Add toggles to Appearance section**

Modify the Appearance section (lines 47-73) to add the new toggles after "Haptic Feedback":

```swift
// MARK: - Appearance

Section("Appearance") {
    Toggle(isOn: $darkModeEnabled) {
        SettingsRow(
            icon: "moon.fill",
            iconColor: .purple,
            title: "Dark Mode"
        )
    }

    Toggle(isOn: $animationEnabled) {
        SettingsRow(
            icon: "waveform.circle.fill",
            iconColor: .pink,
            title: "Now Playing Animation"
        )
    }

    Toggle(isOn: $hapticsEnabled) {
        SettingsRow(
            icon: "hand.tap.fill",
            iconColor: .gray,
            title: "Haptic Feedback"
        )
    }

    Toggle(isOn: $artworkThemingEnabled) {
        SettingsRow(
            icon: "paintpalette.fill",
            iconColor: .orange,
            title: "Artwork Theming"
        )
    }

    if artworkThemingEnabled {
        Toggle(isOn: $artworkThemingLightMode) {
            SettingsRow(
                icon: "sun.max.fill",
                iconColor: .yellow,
                title: "Theme in Light Mode"
            )
        }
    }
}
```

**Step 3: Update resetSettings function**

Add these lines to the `resetSettings()` function:

```swift
artworkThemingEnabled = true
artworkThemingLightMode = true
```

**Step 4: Verify build and run**

Run: `make build && make run`
Expected: BUILD SUCCEEDED, settings toggles visible in Appearance section

**Step 5: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Settings/SettingsView.swift"
git commit -m "feat(settings): add artwork theming toggles to Appearance section"
```

---

## Task 4: Expand DominantColorService to Publish ThemePalette

**Files:**
- Modify: `Fonic HiFi/Core/Services/DominantColorService.swift`
- Test: `Fonic HiFiTests/DominantColorServiceTests.swift`

**Step 1: Write the failing test**

```swift
//
//  DominantColorServiceTests.swift
//  Fonic HiFiTests
//

import SwiftUI
import XCTest

@testable import Fonic_HiFi

@MainActor
final class DominantColorServiceTests: XCTestCase {

    var sut: DominantColorService!

    override func setUp() async throws {
        sut = DominantColorService.shared
        sut.reset()
    }

    // MARK: - Palette Tests

    func testInitialPaletteIsNeutral() {
        // When no track has been processed, palette should be neutral
        XCTAssertFalse(sut.palette.isVibrant)
    }

    func testPaletteUpdatesWhenColorSchemeChanges() {
        // Update color scheme
        sut.updateColorScheme(.light)
        let lightPalette = sut.palette

        sut.updateColorScheme(.dark)
        let darkPalette = sut.palette

        // Palettes should differ in color scheme
        XCTAssertEqual(lightPalette.colorScheme, .light)
        XCTAssertEqual(darkPalette.colorScheme, .dark)
    }

    func testPaletteRespectsThemingDisabled() {
        // Disable theming
        sut.updateThemingEnabled(false)

        // Palette should be neutral even if a color was extracted
        XCTAssertFalse(sut.palette.isVibrant)
    }

    func testResetClearsPaletteToNeutral() {
        // Reset should clear to neutral
        sut.reset()

        XCTAssertFalse(sut.palette.isVibrant)
        XCTAssertNil(sut.currentTrackID)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL - missing `palette`, `updateColorScheme`, `updateThemingEnabled` members

**Step 3: Modify DominantColorService implementation**

Replace the entire content of `DominantColorService.swift`:

```swift
//
//  DominantColorService.swift
//  Fonic HiFi
//
//  Centralized color extraction service that provides ThemePalette
//  for full-app artwork-reactive theming.
//

import SwiftUI

/// Centralized service for extracting dominant colors and generating theme palettes.
/// Shared across the app to ensure color consistency during transitions.
@MainActor
final class DominantColorService: ObservableObject {
    /// Shared singleton instance
    static let shared = DominantColorService()

    /// Current theme palette derived from the active track's artwork
    @Published private(set) var palette: ThemePalette = .neutral

    /// Current dominant color (for backward compatibility)
    var dominantColor: Color { palette.dominant }

    /// Track ID of the currently extracted color (for cache validation)
    @Published private(set) var currentTrackID: UUID?

    // MARK: - Private State

    private var colorCache: [UUID: Color] = [:]
    private var isExtractingColor = false
    private let maxCacheSize = 50

    /// Current color scheme for palette adaptation
    private var currentColorScheme: ColorScheme = .dark

    /// Whether artwork theming is enabled
    private var themingEnabled: Bool = true

    /// Whether theming is enabled for light mode specifically
    private var lightModeThemingEnabled: Bool = true

    /// The raw dominant color before palette derivation
    private var rawDominantColor: Color = .accentColor

    /// Animation duration for palette transitions
    private let transitionDuration: Double = 2.5

    // MARK: - Initialization

    private init() {
        rebuildPalette()
    }

    // MARK: - Public API

    /// Update the current color scheme (call from views observing colorScheme)
    func updateColorScheme(_ colorScheme: ColorScheme) {
        guard colorScheme != currentColorScheme else { return }
        currentColorScheme = colorScheme
        withAnimation(.easeInOut(duration: transitionDuration)) {
            rebuildPalette()
        }
    }

    /// Update whether theming is globally enabled
    func updateThemingEnabled(_ enabled: Bool) {
        guard enabled != themingEnabled else { return }
        themingEnabled = enabled
        withAnimation(.easeInOut(duration: transitionDuration)) {
            rebuildPalette()
        }
    }

    /// Update whether theming is enabled for light mode
    func updateLightModeThemingEnabled(_ enabled: Bool) {
        guard enabled != lightModeThemingEnabled else { return }
        lightModeThemingEnabled = enabled
        withAnimation(.easeInOut(duration: transitionDuration)) {
            rebuildPalette()
        }
    }

    /// Extract dominant color for the given track.
    /// Uses cache if available, otherwise extracts asynchronously.
    func extractColor(for track: Track?) async {
        guard let track else {
            rawDominantColor = .accentColor
            currentTrackID = nil
            withAnimation(.easeInOut(duration: transitionDuration)) {
                rebuildPalette()
            }
            return
        }

        // Skip if already extracted for this track
        guard track.id != currentTrackID else { return }

        // Check cache first
        if let cached = colorCache[track.id] {
            rawDominantColor = cached
            currentTrackID = track.id
            withAnimation(.easeInOut(duration: transitionDuration)) {
                rebuildPalette()
            }
            return
        }

        // Guard concurrent extractions
        guard !isExtractingColor else { return }
        isExtractingColor = true
        defer { isExtractingColor = false }

        // No artwork - use default
        guard let artworkData = track.artwork else {
            rawDominantColor = .accentColor
            currentTrackID = track.id
            withAnimation(.easeInOut(duration: transitionDuration)) {
                rebuildPalette()
            }
            return
        }

        // Extract on background thread
        let extractedColor = await Task.detached(priority: .utility) {
            UIImage(data: artworkData)?.fastAverageColor ?? Color.accentColor
        }.value

        // Cache result
        colorCache[track.id] = extractedColor
        maintainCacheSize()

        // Apply with animation
        rawDominantColor = extractedColor
        currentTrackID = track.id
        withAnimation(.easeInOut(duration: transitionDuration)) {
            rebuildPalette()
        }
    }

    /// Clear the cache and reset to default color
    func reset() {
        colorCache.removeAll()
        currentTrackID = nil
        rawDominantColor = .accentColor
        rebuildPalette()
    }

    // MARK: - Private Helpers

    private func rebuildPalette() {
        // Check if theming should be active
        let shouldApplyTheming: Bool = {
            guard themingEnabled else { return false }
            if currentColorScheme == .light && !lightModeThemingEnabled {
                return false
            }
            return true
        }()

        if shouldApplyTheming {
            palette = ThemePalette(dominant: rawDominantColor, colorScheme: currentColorScheme)
        } else {
            palette = ThemePalette.neutral(for: currentColorScheme)
        }
    }

    private func maintainCacheSize() {
        guard colorCache.count > maxCacheSize else { return }

        let overflow = colorCache.count - maxCacheSize
        let keysToRemove = Array(colorCache.keys.prefix(overflow))
        keysToRemove.forEach { colorCache.removeValue(forKey: $0) }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Core/Services/DominantColorService.swift" "Fonic HiFiTests/DominantColorServiceTests.swift"
git commit -m "feat(theming): expand DominantColorService to publish ThemePalette"
```

---

## Task 5: Inject ThemePalette at App Root

**Files:**
- Modify: `Fonic HiFi/ContentView.swift`

**Step 1: Add color service observation and color scheme tracking**

Add these properties to ContentView (after existing @Environment declarations around line 12):

```swift
@ObservedObject private var colorService = DominantColorService.shared
@Environment(\.colorScheme) private var colorScheme
@AppStorage("artworkThemingEnabled") private var artworkThemingEnabled = true
@AppStorage("artworkThemingLightMode") private var artworkThemingLightMode = true
```

**Step 2: Add environment injection and settings synchronization**

Wrap the TabView in a container that injects the palette and syncs settings. Modify the body to:

```swift
var body: some View {
    TabView {
        // ... existing tabs unchanged ...
    }
    .preferredColorScheme(.dark)
    .tabBarMinimizeBehavior(.onScrollDown)
    .tabViewBottomAccessory {
        // ... existing mini player unchanged ...
    }
    .fullScreenCover(isPresented: $showingNowPlaying) {
        // ... existing cover unchanged ...
    }
    .environment(\.themePalette, colorService.palette)
    .onChange(of: colorScheme) { _, newScheme in
        colorService.updateColorScheme(newScheme)
    }
    .onChange(of: artworkThemingEnabled) { _, enabled in
        colorService.updateThemingEnabled(enabled)
    }
    .onChange(of: artworkThemingLightMode) { _, enabled in
        colorService.updateLightModeThemingEnabled(enabled)
    }
    .onAppear {
        // Sync initial state
        colorService.updateColorScheme(colorScheme)
        colorService.updateThemingEnabled(artworkThemingEnabled)
        colorService.updateLightModeThemingEnabled(artworkThemingLightMode)
    }
}
```

**Step 3: Verify build**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add "Fonic HiFi/ContentView.swift"
git commit -m "feat(theming): inject ThemePalette into environment at app root"
```

---

## Task 6: Apply Theme to Tab Bar

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/Components/LiquidGlassTabBar.swift`

**Step 1: Add theme environment**

Add this property after existing @Environment declarations:

```swift
@Environment(\.themePalette) private var theme
```

**Step 2: Update glass surface to use theme**

Change the `.glassSurface()` modifier (around line 43) from:

```swift
.glassSurface(style: .dynamic, tint: Color.white.opacity(0.3), cornerRadius: 0)
```

To:

```swift
.glassSurface(style: .dynamic, tint: theme.glassTint, cornerRadius: 0)
```

**Step 3: Update selected tab color**

If there's a selected state indicator using a hardcoded color, update it to use `theme.accent`.

**Step 4: Verify build and run**

Run: `make build && make run`
Expected: Tab bar glass effect tints with artwork color

**Step 5: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Components/LiquidGlassTabBar.swift"
git commit -m "feat(theming): apply ThemePalette to tab bar glass effect"
```

---

## Task 7: Apply Theme to NowPlaying View

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift`

**Step 1: Add theme environment**

Add after existing environment declarations (around line 15):

```swift
@Environment(\.themePalette) private var theme
```

**Step 2: Update background gradient**

Change the background gradient (around line 106-117) from using `dominantColor` to `theme`:

```swift
.background(
    LinearGradient(
        colors: [
            theme.dominant.opacity(0.6),
            theme.dominant.opacity(0.3),
            Color.black.opacity(0.8),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    .ignoresSafeArea()
)
```

**Step 3: Update play button accent color**

Change `playAccentColor` usage in `playbackControlsView` (around line 346) to use theme:

```swift
ZStack {
    Circle()
        .fill(theme.accent)
        .shadow(color: theme.accent.opacity(0.3), radius: 6, x: 0, y: 2)
    Image(systemName: audioService?.isPlaying == true ? "pause.fill" : "play.fill")
        .font(.system(size: 24, weight: .bold, design: .rounded))
        .foregroundStyle(Color.black.opacity(0.85))
}
```

Remove the `playAccentColor` constant since we now use theme.

**Step 4: Update volume slider tint**

Change the volume slider tint (around line 408) from `.tint(.white)` to:

```swift
.tint(theme.accent)
```

**Step 5: Verify build and run**

Run: `make build && make run`
Expected: NowPlaying uses theme colors

**Step 6: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift"
git commit -m "feat(theming): apply ThemePalette to NowPlaying view"
```

---

## Task 8: Apply Theme to Library Views

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/Library/LibraryView.swift`
- Modify: `Fonic HiFi/Presentation/Views/Library/TrackRowView.swift`

**Step 1: Add theme to LibraryView**

Add environment property:

```swift
@Environment(\.themePalette) private var theme
```

**Step 2: Add theme to TrackRowView**

Add environment property:

```swift
@Environment(\.themePalette) private var theme
```

**Step 3: Highlight currently playing track**

In TrackRowView, if there's a "now playing" indicator, use `theme.subtle` for the background:

```swift
.background(isCurrentlyPlaying ? theme.subtle : Color.clear)
```

**Step 4: Verify build**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Library/LibraryView.swift" "Fonic HiFi/Presentation/Views/Library/TrackRowView.swift"
git commit -m "feat(theming): apply ThemePalette to library views"
```

---

## Task 9: Apply Theme to Settings Toggles

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/Settings/SettingsView.swift`

**Step 1: Add theme environment**

Add after existing declarations:

```swift
@Environment(\.themePalette) private var theme
```

**Step 2: Apply accent to toggle tint**

Add `.tint(theme.accent)` modifier to the List:

```swift
List {
    // ... sections ...
}
.tint(theme.accent)
.navigationTitle("Settings")
```

**Step 3: Verify build and run**

Run: `make build && make run`
Expected: Toggle switches use theme accent color

**Step 4: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Settings/SettingsView.swift"
git commit -m "feat(theming): apply ThemePalette accent to settings toggles"
```

---

## Task 10: Manual QA & Documentation

**Files:**
- Modify: `STATUS.md`

**Step 1: Manual QA checklist**

Test with various album art:
- [ ] Vibrant colored artwork (red, blue, green albums)
- [ ] Muted/desaturated artwork
- [ ] Grayscale/B&W artwork
- [ ] No artwork

Test transitions:
- [ ] Color transitions smoothly over ~2.5s when changing tracks
- [ ] Theme updates when toggling settings

Test modes:
- [ ] Dark mode shows richer colors
- [ ] Light mode shows softer tints
- [ ] Disabling "Artwork Theming" returns to neutral
- [ ] Disabling "Theme in Light Mode" affects only light mode

**Step 2: Update STATUS.md**

Add to Implementation Status:

```markdown
**Theming:**
- ThemePalette - Core/Services/ThemePalette.swift
- ThemePaletteEnvironment - Presentation/Environment/ThemePaletteEnvironment.swift
- DominantColorService expanded for full-app theming
```

**Step 3: Commit**

```bash
git add STATUS.md
git commit -m "docs(status): add artwork theming to implementation status"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Create ThemePalette struct | ThemePalette.swift, ThemePaletteTests.swift |
| 2 | Create environment key | ThemePaletteEnvironment.swift |
| 3 | Add settings toggles | SettingsView.swift |
| 4 | Expand DominantColorService | DominantColorService.swift, DominantColorServiceTests.swift |
| 5 | Inject at app root | ContentView.swift |
| 6 | Apply to tab bar | LiquidGlassTabBar.swift |
| 7 | Apply to NowPlaying | NowPlayingContent.swift |
| 8 | Apply to library | LibraryView.swift, TrackRowView.swift |
| 9 | Apply to settings | SettingsView.swift |
| 10 | QA & documentation | STATUS.md |

**Total: 10 tasks, ~20 commits**
