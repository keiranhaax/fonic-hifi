# Example: Verified Liquid Glass API Search

## User Question

"How do I add Liquid Glass effects to my SwiftUI views in iOS 26?"

## Search Execution

### Tier 1: Apple RAG Search

**Query:**
```
mcp__apple-rag-mcp__search(
    query: "iOS 26 Liquid Glass glassEffect API SwiftUI 2025",
    result_count: 5
)
```

**Results:** ✅ SUCCESS

**Key Findings:**

1. **API Signature:**
```swift
nonisolated func glassEffect(
    _ glass: Glass = .regular,
    in shape: some Shape = DefaultGlassEffectShape()
) -> some View
```

2. **Platform Availability:**
- iOS 26.0+
- iPadOS 26.0+
- macOS 26.0+
- Mac Catalyst 26.0+
- tvOS 26.0+
- watchOS 26.0+

3. **Code Examples from Documentation:**

**Basic Usage:**
```swift
Text("Hello, World!")
    .font(.title)
    .padding()
    .glassEffect()
```

**Custom Shape:**
```swift
Text("Hello, World!")
    .font(.title)
    .padding()
    .glassEffect(in: .rect(cornerRadius: 16.0))
```

**Tinted + Interactive:**
```swift
Text("Hello, World!")
    .font(.title)
    .padding()
    .glassEffect(.regular.tint(.orange).interactive())
```

4. **Related Components:**
- `GlassEffectContainer` - Combine multiple Liquid Glass shapes
- `Glass.regular` - Default variant
- `Glass.clear` - Clear variant
- `.tint()` - Add color tinting
- `.interactive()` - Add touch/pointer reactions

**Source URLs:**
- https://developer.apple.com/documentation/swiftui/view/glasseffect
- https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
- https://developer.apple.com/documentation/swiftui/glasseffectcontainer

**WWDC Session:**
- WWDC25 Session 323: "Build a SwiftUI app with the new design"

## Verification Tag

**[Verified-Apple-iOS26]** - Official Apple documentation

## Final Response

---

According to Apple's iOS 26 documentation [Verified-Apple-iOS26], you use the `.glassEffect()` modifier to apply Liquid Glass effects to SwiftUI views.

### Basic Usage

```swift
Text("Hello, World!")
    .font(.title)
    .padding()
    .glassEffect()
```

By default, SwiftUI uses the `.regular` variant with a `Capsule` shape.

### Customization Options

**Custom Shape:**
```swift
Text("Hello, World!")
    .glassEffect(in: .rect(cornerRadius: 16.0))
```

**Tinted with Interactivity:**
```swift
Text("Hello, World!")
    .glassEffect(.regular.tint(.orange).interactive())
```

The `.interactive()` modifier makes the glass react to touch and pointer interactions with scaling, bouncing, and shimmering effects.

### Combining Multiple Glass Elements

Use `GlassEffectContainer` to group multiple Liquid Glass views for better performance and morphing transitions:

```swift
GlassEffectContainer {
    HStack {
        Text("Badge 1").glassEffect()
        Text("Badge 2").glassEffect()
    }
}
```

The container allows glass shapes to blend together and morph during transitions.

**Sources:**
- API Reference: https://developer.apple.com/documentation/swiftui/view/glasseffect
- Tutorial: https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
- WWDC25 Session 323: https://developer.apple.com/videos/play/wwdc2025/323/

---

## Time Taken

- Search: ~3 seconds
- Result processing: ~2 seconds
- Total: ~5 seconds

## Confidence Level

**High** - Found in official Apple documentation with code examples
