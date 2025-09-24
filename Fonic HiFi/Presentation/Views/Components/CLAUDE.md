# Components CLAUDE.md

iOS 26 Liquid Glass APIs and custom implementations. Verify with apple-rag/sosumi.

## STRICT IMPLEMENTATION RULES

- **NEVER** create mock data, fake APIs, or placeholder values
- **NEVER** use TODO, FIXME, or stub comments in code
- **NEVER** comment out code - remove or implement properly
- **ALWAYS** verify implementation matches user requirements exactly
- **ALWAYS** implement complete, working solutions
- **ALWAYS** double-check before editing/commenting - implement correctly
- Comments are OK if concise and helpful for understanding

## CRITICAL DISTINCTION [IMPORTANT UPDATE]

**Native iOS 26 APIs (Available but NOT USED):**
- `.glassEffect()` - Apple's official modifier - **NOT IN CODEBASE**
- `GlassEffectContainer` - Apple's morphing container - **NOT IN CODEBASE**
- `Glass.regular`, `Glass.interactive()` - Official variants - **NOT IN CODEBASE**
- These APIs are ready to use but have NOT been implemented yet

**Custom Project Implementations (ACTUALLY IN USE):**
- `.liquidGlass()` - CUSTOM modifier (`LiquidGlassDesignSystem.swift:30`)
- `PerformanceOptimizedContainer` - CUSTOM container (`PerformanceOptimizedContainer.swift:16`)
- `LiquidGlassStyle` - CUSTOM enum for styling
- `.glassEffectID()` - CUSTOM extension for animations

## NATIVE iOS 26 LIQUID GLASS [NOT YET IMPLEMENTED]

**How to Use (When Implemented):**
```swift
Text("Hello")
    .glassEffect()  // Default capsule shape

Text("Custom")
    .glassEffect(
        Glass.regular.interactive(true),
        in: RoundedRectangle(cornerRadius: 20)
    )
```

**ACTUAL CODE IN USE** (`LiquidGlassDesignSystem.swift:30`):
```swift
// Custom implementation using Material effects
func liquidGlass(
    style: LiquidGlassStyle = .standard,
    intensity: Double = 0.8
) -> some View {
    // Uses Material(.ultraThinMaterial) not native .glassEffect()
}
```

**Interactive Glass [Verified-Apple]:**
```swift
Button("Tap Me") { }
    .glassEffect(Glass.regular.interactive(true))
// Scales, bounces, shimmers on interaction
```

**Tinted Glass [Verified-Apple]:**
```swift
.glassEffect(Glass.regular.tint(.blue))
// Use tint for meaning, not decoration
// Adapts vibrancy to background
```

## MORPHING TRANSITIONS [API Available, Not Implemented]

**Native iOS 26 (NOT IN CODE):**
```swift
// This is how Apple's API works - NOT USED YET
GlassEffectContainer { // Apple's container
    content.glassEffect() // Apple's modifier
}
```

**ACTUAL IMPLEMENTATION** (`PerformanceOptimizedContainer.swift:16`):
```swift
// Custom container - NOT Apple's GlassEffectContainer
struct PerformanceOptimizedContainer<Content: View>: View {
    // Custom performance optimizations
    // Does NOT use native .glassEffect()
}
```

**ACTUAL USAGE** (`NowPlayingView.swift:73`):
```swift
PerformanceOptimizedContainer(spacing: 0) {
    // Content using custom .liquidGlass() modifier
}
```

**Three Steps for Morphing:**
1. Wrap in `GlassEffectContainer`
2. Apply `.glassEffect()` to elements
3. Add `.glassEffectID()` with shared namespace

## PERFORMANCE OPTIMIZATION [Verified-Apple]

**Shared Sampling Regions:**
```swift
// GOOD: Single container, shared sampling
GlassEffectContainer {
    Badge1().glassEffect()
    Badge2().glassEffect()
}

// BAD: Multiple containers, redundant sampling
GlassEffectContainer { Badge1().glassEffect() }
GlassEffectContainer { Badge2().glassEffect() }
```

**Why GlassEffectContainer:**
- Prevents glass-on-glass sampling issues
- Shares sampling region for performance
- Enables morphing transitions
- Ensures visual consistency

## CUSTOM IMPLEMENTATIONS

**Our `.liquidGlass()` Wrapper:**
```swift
// Convenience modifier with presets
.liquidGlass(
    style: .standard,     // Our style enum
    intensity: 0.8
)
```

**PerformanceOptimizedContainer:**
- Custom implementation (NOT Apple's GlassEffectContainer)
- Located at `PerformanceOptimizedContainer.swift:16`
- Adds performance monitoring
- Provides fallback for reduce transparency
- Uses custom `.glassEffectID()` extension for animations

## ACCESSIBILITY [Verified-Apple]

**Automatic Adaptations:**
- Text uses vibrant colors for legibility
- Respects Reduce Transparency setting
- High contrast mode support
- Dynamic type scaling preserved

**Manual Overrides:**
```swift
.glassEffect()
    .accessibilityLabel("Premium feature")
    .accessibilityAddTraits(.isButton)
```

## SWIFTUI PERFORMANCE [Verified-Apple]

**LazyStack Usage:**
```swift
// GOOD: Lazy loading for lists
ScrollView {
    LazyVStack {
        ForEach(items) { item in
            ItemView(item).glassEffect()
        }
    }
}

// BAD: All items rendered immediately
VStack {
    ForEach(items) { ItemView($0).glassEffect() }
}
```

**Avoid GeometryReader:**
- Use alignment guides instead
- Only for absolute positioning needs
- Causes unnecessary re-renders

## ANIMATION BEST PRACTICES

**State-Driven Animations:**
```swift
@State private var isExpanded = false

var body: some View {
    GlassEffectContainer {
        content
            .animation(.smooth, value: isExpanded)
    }
}
```

**Use .task over .onAppear:**
```swift
.task {  // Async, cancellable
    await loadData()
}
// Not .onAppear { Task { await loadData() } }
```

## DEBUG

```bash
make view FILE=Presentation/Views/Components/LiquidGlassDesignSystem.swift
make profile-cpu  # Check glass effect performance
```

## KEY FILES

- `LiquidGlassDesignSystem.swift:30`: Custom `.liquidGlass()` modifier
- `PerformanceOptimizedContainer.swift:16`: Custom container (NOT Apple's)
- `LiquidGlassTabBar.swift`: Tab bar with custom glass effects
- `LiquidGlassRail.swift:36`: Uses `.glassEffect()` but NOT native
- `AccessibilityEnhancements.swift`: A11y helpers

**NOTE**: Search for `.glassEffect()` shows custom usage, not native iOS 26 API