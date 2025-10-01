# Liquid Glass Migration: AI Agent Guide

**Mission**: Replace custom Liquid Glass implementations with iOS 26 native APIs
**Work**: 43 replacements across 11 files | **Time**: 20-28 hours | **Target**: iOS 26.0+

---

## Quick Reference: Custom → Native

| Custom | Native | Notes |
|--------|--------|-------|
| `PerformanceOptimizedContainer` | `GlassEffectContainer` | 9 instances (production only) |
| `.liquidGlass()` | `.glassEffect()` | 24 instances |
| Custom `.glassEffectID()` | Apple's `.glassEffectID()` | 13 instances (auto-fixed) |
| `LiquidGlassStyle.ultraThin` | `.glassEffect(.clear)` | Material-based |
| `LiquidGlassStyle.standard` | `.glassEffect(.regular)` | Material-based |
| `LiquidGlassStyle.thick` | `.glassEffect(.regular)` | Material-based |
| `intensity: 0.8` | `.tint(.white.opacity(0.8))` | Opacity modifier |
| `LiquidGlassButton` | `Button { }.buttonStyle(.glass)` | 9 instances |
| `LiquidGlassCard` | Content with `.glassEffect()` | 1 instance (BottomSearchBar only) |

---

## ⚠️ Phase 0: Visual Fidelity Gate (REQUIRED FIRST)

**CRITICAL**: Custom APIs use SwiftUI `Material` (`.regularMaterial`, `.thickMaterial`). Native iOS 26 uses `Glass` effect with different rendering.

**Create comparison harness BEFORE any migration:**

```swift
// File: Fonic HiFi/Presentation/Views/Debug/MaterialVsGlassComparisonView.swift
struct MaterialVsGlassComparisonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                // Test 1: ultraThin → clear
                ComparisonRow(
                    title: "ultraThin → clear",
                    material: { Text("Material").background(.thinMaterial) },
                    glass: { Text("Glass").glassEffect(.clear) }
                )

                // Test 2: standard → regular
                ComparisonRow(
                    title: "standard → regular",
                    material: { Text("Material").background(.regularMaterial) },
                    glass: { Text("Glass").glassEffect(.regular) }
                )

                // Test 3: thick → regular
                ComparisonRow(
                    title: "thick → regular",
                    material: { Text("Material").background(.thickMaterial) },
                    glass: { Text("Glass").glassEffect(.regular) }
                )

                // Test 4: intensity mappings (0.6, 0.7, 0.8, 0.9)
                VStack {
                    ForEach([0.6, 0.7, 0.8, 0.9], id: \.self) { intensity in
                        ComparisonRow(
                            title: "intensity: \(intensity)",
                            material: { Text("Material \(intensity)").background(.regularMaterial.opacity(intensity)) },
                            glass: { Text("Glass \(intensity)").glassEffect(.regular.tint(.white.opacity(intensity))) }
                        )
                    }
                }
            }
        }
        .background(.purple.gradient) // Test on colored backgrounds
    }
}

struct ComparisonRow<MaterialContent: View, GlassContent: View>: View {
    let title: String
    @ViewBuilder let material: () -> MaterialContent
    @ViewBuilder let glass: () -> GlassContent

    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            HStack(spacing: 20) {
                VStack {
                    material()
                    Text("CURRENT (Material)").font(.caption)
                }
                VStack {
                    glass()
                    Text("PROPOSED (Glass)").font(.caption)
                }
            }
        }
        .padding()
    }
}
```

**Gate Requirements:**
1. Build comparison view
2. Test on varied backgrounds (light, dark, gradient, image)
3. Design approval for visual equivalence OR approved tint adjustments
4. Document approved mappings for Phase 2/3

**DO NOT PROCEED without visual approval** - Material and Glass render differently.

---

## Phase 1: Container Replacement (9 instances)

**Delete File**: `Fonic HiFi/Presentation/Views/Components/PerformanceOptimizedContainer.swift`

**LiquidGlassExamples.swift** (5 replacements):
```swift
Line 20:  PerformanceOptimizedContainer(spacing: 0) { → GlassEffectContainer(spacing: 0) {
Line 151: PerformanceOptimizedContainer(spacing: 0) { → GlassEffectContainer(spacing: 0) {
Line 269: PerformanceOptimizedContainer(spacing: 0) { → GlassEffectContainer(spacing: 0) {
Line 453: PerformanceOptimizedContainer(spacing: 0) { → GlassEffectContainer(spacing: 0) {
Line 527: PerformanceOptimizedContainer(spacing: 0) { → GlassEffectContainer(spacing: 0) {
```

**LiquidGlassRail.swift** (3 replacements):
```swift
Line 33:  PerformanceOptimizedContainer { → GlassEffectContainer {
Line 102: PerformanceOptimizedContainer { → GlassEffectContainer {
Line 266: PerformanceOptimizedContainer { → GlassEffectContainer {
```

**NowPlayingView.swift** (1 replacement):
```swift
Line 79: PerformanceOptimizedContainer(spacing: 0) { → GlassEffectContainer(spacing: 0) {
```

**Verify**:
```bash
make build
grep -r "PerformanceOptimizedContainer" --include="*.swift" "Fonic HiFi/"  # Should return 0
```

**Critical Note**: Deleting `PerformanceOptimizedContainer.swift` removes custom `.glassEffectID()` extension. Code automatically switches to Apple's native implementation (different semantics - no dual `matchedGeometryEffect`). Verify morphing animations still work in LiquidGlassRail.

---

## Phase 2: Core Views (6 + 5 components)

**Apply tint adjustments from Phase 0 visual test.**

**NowPlayingView.swift** (6 `.liquidGlass()` replacements):
```swift
Line 102: .liquidGlass(style: .ultraThin)
       → .glassEffect(.clear)

Line 224: .liquidGlass(style: .standard, intensity: 0.8)
       → .glassEffect(.regular.tint(.white.opacity(0.8)))

Line 285: .liquidGlass(style: .thick)
       → .glassEffect(.regular)

Line 340: .liquidGlass(style: .standard)
       → .glassEffect(.regular)

Line 458: .liquidGlass(style: .ultraThin)
       → .glassEffect(.clear)

Line 474: .liquidGlass(style: .standard)
       → .glassEffect(.regular)
```

**NowPlayingView.swift** (5 LiquidGlassButton → native):
```swift
Lines 346, 365, 383, 402, 420:
// BEFORE:
LiquidGlassButton(style: .standard) {
    action()
} content: {
    Icon()
}

// AFTER:
Button {
    action()
} label: {
    Icon()
}
.buttonStyle(.glass)
```

**LiquidGlassRail.swift**: Already complete (5 `.glassEffect()` calls stay, 3 containers fixed in Phase 1)

---

## Phase 3: Examples (18 + 4 components)

**LiquidGlassExamples.swift** (18 replacements):
```swift
Line 28:  .liquidGlass(style: .ultraThin) → .glassEffect(.clear)
Line 41:  .liquidGlass(style: .standard, intensity: 0.8) → .glassEffect(.regular.tint(.white.opacity(0.8)))
Line 45:  .liquidGlass(style: .thick, intensity: 0.9) → .glassEffect(.regular)
Line 155: .liquidGlass(style: .thick) → .glassEffect(.regular)
Line 160: .liquidGlass(style: .standard) → .glassEffect(.regular)
Line 164: .liquidGlass(style: .ultraThin, intensity: 0.6) → .glassEffect(.clear)
Line 223: .liquidGlass(style: .ultraThin) → .glassEffect(.clear)
Line 305: .liquidGlass(style: .standard) → .glassEffect(.regular)
Line 333: .liquidGlass(style: .thick) → .glassEffect(.regular)
Line 372: .liquidGlass(style: .ultraThin, intensity: 0.8) → .glassEffect(.clear)
Line 398: .liquidGlass( → .glassEffect(.regular)
Line 488: .liquidGlass(style: .standard) → .glassEffect(.regular)
Line 515: .liquidGlass(style: .thick) → .glassEffect(.regular)
Line 533: .liquidGlass(style: .standard) → .glassEffect(.regular)
Line 551: .liquidGlass(style: .standard) → .glassEffect(.regular)
Line 555: .liquidGlass(style: .thick) → .glassEffect(.regular)
Line 604: .liquidGlass(style: .ultraThin) → .glassEffect(.clear)
Line 613: .liquidGlass(style: .standard, intensity: 0.7) → .glassEffect(.regular.tint(.white.opacity(0.7)))
```

**LiquidGlassExamples.swift** (4 LiquidGlassButton → native):
Lines 132, 179, 325, 504: Same pattern as NowPlayingView

---

## Phase 4: Cleanup (3 files + docs)

**BottomSearchBar.swift**:
```swift
Line 33: LiquidGlassCard { Content() } → Content().glassEffect(.regular)
```

**LiquidGlassTabBar.swift**: Re-evaluate `.clearGlassFix()` workaround (may not be needed in iOS 26 release)

**LiquidGlassMiniPlayer.swift**: Re-evaluate `.clearGlassFix()` workaround

**LiquidGlassDesignSystem.swift**: Add deprecation markers:
```swift
@available(*, deprecated, message: "Use .glassEffect() instead")
func liquidGlass(style: LiquidGlassStyle = .standard, intensity: Double = 1.0) -> some View

@available(*, deprecated, message: "Use Button { }.buttonStyle(.glass) instead")
struct LiquidGlassButton<Content: View>: View

@available(*, deprecated, message: "Use .glassEffect() instead")
struct LiquidGlassCard<Content: View>: View
```

**Note**: Keep `LiquidGlassDesignSystem.swift` - contains 3 `.liquidGlass()` calls inside component implementations. Symbol stays alive until components fully refactored.

**CLAUDE.md**: Update Liquid Glass section to mark custom APIs as deprecated

---

## Verification Commands

```bash
# Build passes
make build

# Zero custom APIs in production (excludes deprecated definitions)
grep -r "PerformanceOptimizedContainer" --include="*.swift" "Fonic HiFi/"  # Should return 0
grep -r "\.liquidGlass(" --include="*.swift" "Fonic HiFi/" | grep -v "LiquidGlassDesignSystem.swift"  # Should return 0

# Native APIs used
grep -r "GlassEffectContainer" --include="*.swift" "Fonic HiFi/" | wc -l  # Should be 9+
grep -r "\.glassEffect(" --include="*.swift" "Fonic HiFi/" | wc -l        # Should be 29+ (5 existing + 24 new)
```

---

## Success Criteria

- [ ] Phase 0: Visual fidelity test approved (Material vs Glass comparison)
- [ ] All 9 `PerformanceOptimizedContainer` → `GlassEffectContainer`
- [ ] All 24 `.liquidGlass()` → `.glassEffect()` with correct tinting
- [ ] All 13 `.glassEffectID()` use Apple's native implementation
- [ ] 9 `LiquidGlassButton` → `Button { }.buttonStyle(.glass)`
- [ ] 1 `LiquidGlassCard` → `.glassEffect()`
- [ ] `make build` passes with no errors
- [ ] Morphing animations work in LiquidGlassRail (verify native `.glassEffectID()` behavior)
- [ ] No visual regressions from Material → Glass conversion
- [ ] Frame rate stable or improved

---

## Style Conversion Cheat Sheet

```swift
// Pattern 1: Simple style
.liquidGlass(style: .ultraThin)        → .glassEffect(.clear)
.liquidGlass(style: .standard)         → .glassEffect(.regular)
.liquidGlass(style: .thick)            → .glassEffect(.regular)

// Pattern 2: With intensity (adjust per Phase 0 results)
.liquidGlass(style: .standard, intensity: 0.8)  → .glassEffect(.regular.tint(.white.opacity(0.8)))
.liquidGlass(style: .ultraThin, intensity: 0.6) → .glassEffect(.clear)

// Pattern 3: Interactive (iOS only)
.liquidGlass(style: .standard)         → .glassEffect(.regular.interactive())

// Pattern 4: Custom tint
.liquidGlass(style: .standard)         → .glassEffect(.regular.tint(.blue.opacity(0.4)))
```

---

## Notes for AI Agents

### Count Verification [Verified-Code]
Counts derived from `grep` on 2025-09-30:
- `.liquidGlass()`: 30 total (24 production + 3 in LiquidGlassDesignSystem.swift + 2 in PerformanceOptimizedContainer.swift + 1 in docs)
- `PerformanceOptimizedContainer`: 12 total (9 production + 3 self-refs in definition file)
- `LiquidGlassButton`: 14 total (9 production + 2 definitions + 3 in docs)
- `LiquidGlassCard`: 6 total (1 production + 2 definitions + 3 in docs)

### Keep These (No Migration Needed)
- **Keep**: `.glassPerformanceProfiled()` (13 instances) - valid utility, no conflict
- **Keep**: `GlassEffectMemoryManager` - custom utility, not shadowing Apple API
- **Keep**: `.clearGlassFix()` (4 instances) - beta workaround, re-evaluate after iOS 26 release
- **Delete**: `GlassMorphingContainer` - defined but never used
- **Delete**: Entire `PerformanceOptimizedContainer.swift` file

### Critical Migration Notes
- **After Phase 1**: All `.glassEffectID()` calls automatically use Apple's native API (custom extension removed)
- **Material vs Glass**: Different rendering engines - visual comparison required before migration
- **Native `.glassEffectID()`**: Uses single identifier, not dual `matchedGeometryEffect` calls like custom implementation
- **iOS 26 Only**: This project targets iOS 26.0 minimum - no backwards compatibility needed

### File Handling Strategy
- **DELETE**: `PerformanceOptimizedContainer.swift` (Phase 1)
- **DEPRECATE**: `LiquidGlassDesignSystem.swift` (Phase 4 - add markers, keep file)
- **IGNORE**: `iOS26_Features_Documentation.swift` (documentation only)