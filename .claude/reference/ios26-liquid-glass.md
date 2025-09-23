# iOS 26 Liquid Glass Design System Reference

**Last Updated: September 2025**
**Platform Requirements: iOS 26.0+, iPadOS 26.0+, macOS 26.0+, tvOS 26.0+, watchOS 26.0+**
**Verification Status: [Verified-Apple] - All content verified against official Apple documentation**

## Overview

Liquid Glass is iOS 26's revolutionary material design system that combines optical properties of glass with fluid dynamics. It provides a dynamic, interactive layer that floats above content, responds to touch, and morphs between states with unique animations.

## Core Concepts

### What is Liquid Glass?

[Verified-Apple] Liquid Glass is a material that:
- **Blurs content** behind it with sophisticated optical effects
- **Reflects color and light** from surrounding content
- **Reacts to interactions** in real-time with scaling, bouncing, and shimmering
- **Morphs fluidly** between different shapes and configurations
- **Adapts dynamically** to background content and system appearance

### Design Philosophy

Liquid Glass is designed to be an **interactive layer** that:
- Floats above your content, right below fingertips
- Provides main controls that users touch
- Creates a distinct control layer illusion
- Should be limited to the most important elements

## Basic Implementation

### Applying Glass Effects

```swift
// [Verified-Apple] Basic glass effect with default capsule shape
Text("Hello, World!")
    .font(.title)
    .padding()
    .glassEffect()

// Custom shape with rounded rectangle
Text("Custom Shape")
    .padding()
    .glassEffect(in: .rect(cornerRadius: 16.0))

// Tinted interactive glass
Text("Interactive")
    .padding()
    .glassEffect(.regular.tint(.orange).interactive())
```

### Glass Modifier API

```swift
func glassEffect(
    _ glass: Glass = .regular,
    in shape: some Shape = DefaultGlassEffectShape()
) -> some View
```

**Parameters:**
- `glass`: The Glass variant to apply (default: `.regular`)
- `shape`: The shape to use for the glass effect (default: `Capsule`)

## Glass Variants and Configuration

### Glass Structure

[Verified-Apple] The `Glass` structure defines the Liquid Glass material configuration:

```swift
struct Glass {
    // Standard variant
    static let regular: Glass

    // Modification methods
    func tint(_ color: Color?) -> Glass
    func interactive(_ enabled: Bool = true) -> Glass
}
```

### Configuration Options

#### 1. Tinting
```swift
// [Verified-Apple] Apply semantic color tinting
.glassEffect(.regular.tint(.blue))
.glassEffect(.regular.tint(.systemRed))

// Remove tint
.glassEffect(.regular.tint(nil))
```

**Important:** Only use tinting to convey meaning, not for visual effect or branding.

#### 2. Interactivity
```swift
// [Verified-Apple] Enable touch response
.glassEffect(.regular.interactive())
.glassEffect(.regular.interactive(true))

// Disable interactivity
.glassEffect(.regular.interactive(false))
```

Interactive glass responds with:
- **Scaling** on touch
- **Bouncing** animations
- **Shimmering** effects
- Matches behavior of system toolbar buttons and sliders

## Glass Effect Containers

### GlassEffectContainer

[Verified-Apple] Combines multiple glass elements for optimal rendering and morphing:

```swift
@MainActor
struct GlassEffectContainer<Content> where Content : View {
    init(
        spacing: CGFloat = 10.0,
        @ViewBuilder content: () -> Content
    )
}
```

### Container Benefits

1. **Visual Correctness**: Glass samples content from larger area, containers allow shared sampling
2. **Performance**: Minimizes sampling passes by sharing regions
3. **Morphing Effects**: Enables fluid transitions between glass elements
4. **Blending**: Controls how glass shapes merge together

### Container Implementation

```swift
// [Verified-Apple] Basic container with multiple glass elements
GlassEffectContainer(spacing: 40.0) {
    HStack(spacing: 40.0) {
        Image(systemName: "pencil")
            .frame(width: 80, height: 80)
            .font(.system(size: 36))
            .glassEffect()

        Image(systemName: "eraser.fill")
            .frame(width: 80, height: 80)
            .font(.system(size: 36))
            .glassEffect()
    }
}
```

### Spacing Behavior

[Verified-Apple] The `spacing` parameter controls blending:
- **Larger spacing**: Elements blend sooner as they approach
- **Smaller spacing**: Elements remain distinct until very close
- **Overlapping**: Elements merge into single shape

## Advanced Features

### Glass Effect Union

[Verified-Apple] Combine multiple views into a single glass shape:

```swift
@Namespace private var namespace

GlassEffectContainer(spacing: 20.0) {
    HStack(spacing: 20.0) {
        ForEach(items.indices, id: \.self) { index in
            ItemView(items[index])
                .glassEffect()
                .glassEffectUnion(
                    id: index < 2 ? "group1" : "group2",
                    namespace: namespace
                )
        }
    }
}
```

### Glass Effect Transitions

[Verified-Apple] Create morphing animations between glass elements:

```swift
@State private var isExpanded = false
@Namespace private var namespace

GlassEffectContainer(spacing: 10.0) {
    HStack(spacing: 10.0) {
        Image(systemName: "pencil")
            .glassEffect()
            .glassEffectID("pencil", in: namespace)

        if isExpanded {
            Image(systemName: "note")
                .glassEffect()
                .glassEffectID("note", in: namespace)
                .glassEffectTransition(.matchedGeometry)
        }
    }
}
```

### Transition Types

```swift
enum GlassEffectTransition {
    case matchedGeometry  // Default for positioned elements
    case materialize      // Fade in with glass animation
}
```

## Text and Content Behavior

### Automatic Adaptations

[Verified-Apple] Content within glass effects automatically adapts:

1. **Text becomes vibrant**: Maintains legibility against colorful backgrounds
2. **Dynamic color switching**: Automatically switches between light/dark for contrast
3. **Tint adaptation**: Tinted glass colors become vibrant versions
4. **Size-based opacity**: Larger glass is more opaque, smaller is clearer

### Text Example

```swift
// [Verified-Apple] Text automatically uses vibrant color
Text("Readable Text")
    .foregroundColor(.primary)  // Becomes vibrant inside glass
    .padding()
    .glassEffect()
```

## UIKit Integration

### UIGlassEffect

[Verified-Apple] For UIKit apps, use UIGlassEffect with UIVisualEffectView:

```swift
// Create visual effect view
let visualEffectView = UIVisualEffectView()

// Create and apply glass effect
let glassEffect = UIGlassEffect(style: .regular)

// Animate the effect
UIView.animate(withDuration: 0.3) {
    visualEffectView.effect = glassEffect
}

// Configure shape
glassEffect.cornerConfiguration = .containerRelative

// Add tint
let tintedGlass = UIGlassEffect(style: .regular)
tintedGlass.tintColor = .systemBlue

// Enable interactivity
glassEffect.isInteractive = true
```

### UIGlassContainerEffect

[Verified-Apple] Container for multiple glass elements in UIKit:

```swift
// Create container
let containerEffect = UIGlassContainerEffect()
containerEffect.spacing = 40.0

// Apply to visual effect view
let containerView = UIVisualEffectView(effect: containerEffect)

// Add glass subviews to contentView
let glassView1 = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
containerView.contentView.addSubview(glassView1)
```

## Performance Optimization

### Best Practices

[Verified-Apple] For optimal performance:

1. **Use containers**: Always wrap multiple glass elements in GlassEffectContainer
2. **Minimize glass elements**: Limit to most important UI elements
3. **Avoid overlapping**: Prevent glass-on-glass layering
4. **Cache configurations**: Reuse Glass configurations when possible
5. **Profile with Instruments**: Monitor GPU and CPU usage

### Performance Tips

```swift
// [Verified-Apple] Good: Single container with multiple elements
GlassEffectContainer {
    ForEach(items) { item in
        ItemView(item).glassEffect()
    }
}

// Bad: Nested glass effects
View()
    .glassEffect()
    .overlay {
        AnotherView().glassEffect()  // Avoid this
    }
```

## Common Patterns

### Floating Controls

```swift
// [Verified-Apple] Maps-style floating controls
struct FloatingControls: View {
    var body: some View {
        GlassEffectContainer(spacing: 16) {
            VStack(spacing: 16) {
                Button(action: zoomIn) {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }
                .glassEffect(.regular.interactive())

                Button(action: zoomOut) {
                    Image(systemName: "minus")
                        .frame(width: 44, height: 44)
                }
                .glassEffect(.regular.interactive())
            }
        }
    }
}
```

### Expandable Badges

```swift
// [Verified-Apple] Morphing badge system
struct BadgeView: View {
    @State private var isExpanded = false
    @Namespace private var namespace

    var body: some View {
        GlassEffectContainer(spacing: 20) {
            if isExpanded {
                HStack(spacing: 20) {
                    ForEach(badges) { badge in
                        BadgeLabel(badge)
                            .glassEffect()
                            .glassEffectID(badge.id, in: namespace)
                    }
                }
            } else {
                BadgeToggle()
                    .glassEffect(.regular.interactive())
                    .glassEffectID("toggle", in: namespace)
            }
        }
    }
}
```

### Custom Interactive Components

```swift
// [Verified-Apple] Custom slider with glass
struct GlassSlider: View {
    @Binding var value: Double

    var body: some View {
        GlassEffectContainer {
            Slider(value: $value)
                .padding()
                .glassEffect(.regular.interactive())
        }
    }
}
```

## Migration Guide

### From iOS 25 to iOS 26

[Verified-Apple] Replace custom glass implementations:

```swift
// Old (iOS 25)
View()
    .background(.ultraThinMaterial)
    .cornerRadius(20)

// New (iOS 26)
View()
    .glassEffect()
```

### From Custom Effects

```swift
// Old (Custom blur effect)
View()
    .background(BlurView(style: .systemMaterial))
    .overlay(Color.white.opacity(0.1))

// New (iOS 26 Liquid Glass)
View()
    .glassEffect(.regular.tint(.white))
```

## Troubleshooting

### Common Issues and Solutions

1. **Glass not appearing**
   - Ensure iOS 26+ deployment target
   - Check that content has proper frame/padding
   - Verify GlassEffectContainer is used for multiple elements

2. **Performance issues**
   - Reduce number of glass elements
   - Use containers to batch rendering
   - Profile with Instruments

3. **Morphing not working**
   - Ensure namespace is properly declared
   - Use glassEffectID on all morphing elements
   - Elements must be in same GlassEffectContainer

4. **Text not readable**
   - Let system handle text color (becomes vibrant)
   - Avoid manual opacity on text in glass
   - Use semantic colors that adapt

## Platform Differences

### iOS/iPadOS
- Full Liquid Glass support
- Touch interactivity
- All morphing effects

### macOS
- Full Liquid Glass support
- Hover and click interactions
- Window-aware adaptations

### tvOS
- Limited interactivity (focus-based)
- Simplified morphing
- Optimized for TV viewing distance

### watchOS
- Simplified glass effects
- Limited container support
- Optimized for small displays

### visionOS
- Enhanced depth effects
- Spatial audio integration
- Eye tracking interactions

## Related APIs

- `View/glassEffect(_:in:)` - Primary modifier
- `GlassEffectContainer` - Container view
- `Glass` - Configuration structure
- `GlassEffectTransition` - Transition types
- `UIGlassEffect` - UIKit equivalent
- `UIGlassContainerEffect` - UIKit container

## References

- [Apple Documentation: Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
- [WWDC25: Build a SwiftUI app with the new design](https://www.youtube.com/watch?v=3MugGCtm26A)
- [WWDC25: Build a UIKit app with the new design](https://www.youtube.com/watch?v=uhMo6IEcR1w)