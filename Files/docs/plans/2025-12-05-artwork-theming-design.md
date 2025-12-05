# Artwork Theming Design

**Date:** 2025-12-05
**Status:** Approved

## Overview

Expand the existing `DominantColorService` to provide full-app artwork-reactive theming. The entire UI responds to album artwork colors with gradual, ambient transitions.

## Design Decisions

| Aspect | Decision |
|--------|----------|
| **Scope** | Full app immersion — all UI reacts to artwork |
| **Transitions** | Gradual 2-3s ambient blend |
| **Palette** | Single dominant color + auto-derived variants |
| **Fallback** | Sophisticated neutral gray |
| **Light/Dark** | Same color, adaptive intensity + per-mode toggle |
| **Control** | Simple on/off |

## Section 1: Color Extraction & Palette Generation

The existing `DominantColorService` becomes the foundation. It will generate a `ThemePalette` from the single extracted color.

### ThemePalette Structure

- `dominant` — The raw extracted color
- `surface` — Lightened variant for backgrounds/cards (15-20% opacity tint)
- `accent` — Saturated variant for buttons, sliders, interactive elements
- `subtle` — Very light tint for list separators, secondary text highlights
- `glassTint` — Optimized for `.glassEffect(.regular.tint(color))`

### Derivation Logic

Each variant is computed from `dominant` using HSB adjustments:
- `surface`: Brightness increased, saturation reduced
- `accent`: Saturation boosted for vibrancy
- `subtle`: Very low opacity variant
- `glassTint`: Tuned for optimal glass effect appearance

Computation happens synchronously after extraction, adding negligible overhead.

### Fallback Palette

When artwork is missing or the extracted color's saturation falls below a threshold (e.g., < 0.15), the service returns a pre-defined "neutral" palette — warm gray tones that feel intentional and elegant.

## Section 2: Palette Distribution & SwiftUI Integration

### Distribution Mechanism

The `DominantColorService` (already a `@MainActor` singleton) publishes the computed `ThemePalette` instead of just a single `Color`:

```swift
@Published private(set) var palette: ThemePalette
```

### Environment-Based Access

Inject the palette into the SwiftUI environment so any view can access themed colors:

```swift
.environment(\.themePalette, colorService.palette)
```

Views access colors via:

```swift
@Environment(\.themePalette) var theme
// ...
.foregroundStyle(theme.accent)
.glassEffect(.regular.tint(theme.glassTint))
```

### Transition Animation

The service wraps palette updates in `withAnimation(.easeInOut(duration: 2.5))`. SwiftUI's color interpolation works automatically with `@Published` properties, so all subscribed views animate smoothly.

### Light/Dark Adaptation

`ThemePalette` stores the base `dominant` color. Computed properties (`surface`, `accent`, etc.) read `@Environment(\.colorScheme)` and adjust brightness/opacity:
- **Dark mode:** Richer, more saturated colors
- **Light mode:** Softer, more subtle tints

## Section 3: UI Element Application

### NowPlaying & Mini Player (existing, enhanced)

- Background gradient uses `palette.surface`
- Play/pause, skip buttons use `palette.accent`
- Progress slider track/thumb uses `palette.accent`
- Glass effects use `palette.glassTint`

### Tab Bar & Navigation

- `LiquidGlassTabBar` receives `.glassEffect(.regular.tint(palette.glassTint))`
- Selected tab icon uses `palette.accent`
- Unselected icons remain system gray for contrast

### Library Views

- List row backgrounds get subtle `palette.surface` at ~5% opacity
- Currently-playing track row gets stronger highlight using `palette.subtle`
- Section headers can pick up a faint tint

### Buttons & Controls

- Primary action buttons use `palette.accent`
- Sliders throughout Settings use `palette.accent` for filled track
- Toggle switches tint with `palette.accent`

### Widgets & Live Activity

Widgets already extract artwork color independently. Consider syncing to use the same palette logic for consistency, or leave self-contained.

## Section 4: Settings & User Preferences

### Add to Existing "Appearance" Section

Two new rows below existing toggles:

| Icon | Label | Type |
|------|-------|------|
| `paintpalette.fill` | Artwork Theming | Toggle |
| `sun.max.fill` | Theme in Light Mode | Toggle (conditional) |

The "Theme in Light Mode" toggle only appears when Artwork Theming is enabled.

### Persistence

```swift
@AppStorage("artworkThemingEnabled") var artworkThemingEnabled = true
@AppStorage("artworkThemingLightMode") var artworkThemingLightMode = true
@AppStorage("artworkThemingDarkMode") var artworkThemingDarkMode = true
```

### Behavior When Disabled

When theming is off (or off for the current color scheme), `DominantColorService` returns the neutral fallback palette. Views always read from `palette` — they just get different values.

### Default State

Enabled by default in both modes — users discover the feature immediately.

## Section 5: Implementation Plan

### File Changes

| File | Change |
|------|--------|
| `DominantColorService.swift` | Expand to publish `ThemePalette`; add palette derivation logic |
| `ThemePalette.swift` | New struct with computed color variants |
| `ThemePaletteEnvironment.swift` | New environment key for `\.themePalette` |
| `SettingsView.swift` | Add two toggles to Appearance section |
| `ContentView.swift` | Inject palette into environment at root |
| Various views | Replace hardcoded colors with `theme.accent`, `theme.surface`, etc. |

### Testing Approach

- **Unit tests:** `ThemePalette` derivation logic — verify computed variants
- **Unit tests:** Fallback behavior — verify low-saturation triggers neutral palette
- **Manual QA:** Visual review across diverse album art (vibrant, muted, grayscale, no artwork)
- **Performance:** Confirm palette computation adds < 1ms overhead

### Rollout Safety

- Defaults to ON — users see it immediately
- Simple on/off toggle provides escape hatch
- No data migration needed — purely additive UI change
