# Sheet Presentation Conversion Plan for Fonic HiFi
## Mini Player to Now Playing Transition - iOS 26 Only

### Executive Summary
Convert the current full-screen navigation-based presentation to a modern partial-height sheet presentation with iOS 26's automatic Liquid Glass effects. This aligns with Apple's latest design patterns and provides a more fluid, less intrusive user experience.

**IMPORTANT**: This implementation requires iOS 26.0+ with no fallback support for older iOS versions. The app's minimum deployment target must be set to iOS 26.0.

---

## Current Implementation Analysis

### Present State
- **Presentation Method**: `navigationDestination(isPresented:)`
- **Transition**: Zoom transition with matched geometry
- **Coverage**: Full screen takeover
- **Namespace**: Shared between mini player and full screen
- **Navigation**: Single NavigationStack wrapping entire TabView

### Issues with Current Approach
1. Full screen presentation is too intrusive
2. User loses context of underlying content
3. Navigation stack coupling creates complexity
4. Zoom transition requires matched geometry setup
5. Not utilizing iOS 26's new sheet capabilities

---

## Requirements and Compatibility

### iOS Version Requirement
- **Minimum iOS Version**: 26.0
- **No Fallback Support**: This implementation uses iOS 26-exclusive APIs
- **Deployment Target**: Must be set to iOS 26.0 in Xcode project settings

### Verified API Availability [Verified-Apple via Deep Research]

#### iOS 26-Exclusive APIs:
- ✅ `.tabViewBottomAccessory` (iOS 26.0+)
- ✅ `.tabBarMinimizeBehavior` (iOS 26.0+)
- ✅ `glassEffect(_:in:)` (iOS 26.0+)
- ✅ `GlassEffectContainer` (iOS 26.0+)
- ✅ Sheet zoom transitions via `navigationTransition` (iOS 26.0+)

#### APIs Available Since iOS 18+ (not iOS 26 exclusive):
- ✅ `matchedTransitionSource(id:in:)` (iOS 18.0+)
- ✅ `navigationTransition(.zoom)` (iOS 18.0+ for navigation, iOS 26.0+ for sheets)
- ✅ `presentationDetents` (iOS 16.0+)

#### Non-existent APIs (Remove from Implementation):
- ❌ `.presentationShadow()` - Does NOT exist in any iOS version

## Codex AI Recommendations

Based on analysis from OpenAI Codex v0.39.0 and verified with Apple documentation:

### Core Recommendation
> "Move the mini player presentation to `.sheet(isPresented:)` so you can supply `.presentationDetents([.fraction(...), .medium, .large])` and keep the underlying navigation stack untouched."

### Key Advantages
- Built specifically for partial-height presentations
- Decouples from navigation history
- Maintains library context
- Automatic liquid glass in iOS 26
- Native sheet morphing animations

---

## Detailed Implementation Plan

### Critical Issues Found (Codex + Apple Documentation Analysis)

#### Key Problems to Address:
1. **NowPlayingView requires namespace for MORE than matchedGeometryEffect** - Has 9 `.glassEffectID()` calls that all need namespace [Verified-Code]
2. **13 namespace-dependent calls in NowPlayingView** - 4 matchedGeometryEffect + 9 glassEffectID [Verified-Code]
3. **Double matchedTransitionSource risk** - LiquidGlassMiniPlayer already applies `.matchedTransitionSource()` at line 48
4. **Two NowPlayingContainer files** - Both NowPlayingContainer.swift and NowPlayingContainer_NoAnimation.swift need deletion
5. **Detent binding mismatch still present** - Plan inconsistently uses both constants and inline `.height(140)`

#### CRITICAL DISCOVERY - Zoom Transition Pattern [Verified-Apple via Deep Research]:
6. **Sheet CAN zoom from tab accessory** - iOS 26 extends `.navigationTransition(.zoom())` to work on sheets (confirmed in official documentation)
7. **Namespace IS required for zoom** - But for `matchedTransitionSource`, NOT `matchedGeometryEffect`
8. **Tab accessory source marking** - Done IN LiquidGlassMiniPlayer, NOT in ContentView
9. **Liquid Glass is automatic** - iOS 26 automatically applies Liquid Glass material to sheets

### Phase 1: Define Stable Detent Constants

#### 1.1 Create Detent Extension (NEW)
```swift
// Add to ContentView.swift or separate file
extension PresentationDetent {
    static let compactPlayer = Self.height(140)
    static let expandedPlayer = Self.medium
    static let fullPlayer = Self.large
}
```

#### 1.2 Use Constants Everywhere
```swift
@State private var selectedDetent: PresentationDetent = .compactPlayer

.presentationDetents(
    [.compactPlayer, .expandedPlayer, .fullPlayer],
    selection: $selectedDetent
)
```

### Phase 2: Update Namespace Usage (REVISED - Keep for Zoom Transition)

#### 2.1 NowPlayingView.swift (MAJOR REVISION NEEDED)
**PROBLEM: Cannot simply remove namespace - it's used in 13 places:** [Verified-Code]
- Line 22: `let animationNamespace: Namespace.ID` - USED by glass effects
- Line 71: `.navigationTransition(.zoom(sourceID: "miniplayer", in: animationNamespace))` - Remove/comment
- Line 230: `.matchedGeometryEffect(id: "artwork", in: animationNamespace)` - Remove
- Line 231: `.glassEffectID("artwork", in: animationNamespace)` - REQUIRES namespace
- Line 255: `.matchedGeometryEffect(id: "title", in: animationNamespace)` - Remove
- Line 256: `.glassEffectID("title", in: animationNamespace)` - REQUIRES namespace
- Line 267: `.matchedGeometryEffect(id: "artist", in: animationNamespace)` - Remove
- Line 268: `.glassEffectID("artist", in: animationNamespace)` - REQUIRES namespace
- Line 288: `.glassEffectID("trackInfo", in: animationNamespace)` - REQUIRES namespace
- Line 355: `.glassEffectID("shuffle", in: animationNamespace)` - REQUIRES namespace
- Line 373: `.glassEffectID("previous", in: animationNamespace)` - REQUIRES namespace
- Line 391: `.matchedGeometryEffect(id: "playButton", in: animationNamespace)` - Remove
- Line 392: `.glassEffectID("playPause", in: animationNamespace)` - REQUIRES namespace
- Line 411: `.glassEffectID("next", in: animationNamespace)` - REQUIRES namespace
- Line 430: `.glassEffectID("repeat", in: animationNamespace)` - REQUIRES namespace

**SOLUTION OPTIONS:**
1. Keep namespace parameter but only for glass effects (not zoom transition)
2. Remove all glass effects along with matchedGeometryEffect calls
3. Create internal @Namespace for glass effects only [RECOMMENDED]

**IMPORTANT DISCOVERY [Verified-Code]:** The `glassEffectID` helper (PerformanceOptimizedContainer.swift:68-72) internally uses TWO `matchedGeometryEffect` calls per usage:
```swift
func glassEffectID(_ id: String, in namespace: Namespace.ID) -> some View {
    self
      .matchedGeometryEffect(id: "\(id).glass", in: namespace, properties: .frame)
      .matchedGeometryEffect(id: "\(id).blur", in: namespace, properties: .position)
}
```
This means keeping glass effects REQUIRES namespace regardless of approach.

**RECOMMENDED APPROACH: Option 3 - Internal Namespace**
```swift
// In NowPlayingView.swift
struct NowPlayingView: View {
    // Remove external namespace parameter
    // let animationNamespace: Namespace.ID  // DELETE THIS

    // Create internal namespace for glass effects
    @Namespace private var glassNamespace

    var body: some View {
        // Update all glassEffectID calls to use internal namespace
        .glassEffectID("artwork", in: glassNamespace)  // Use internal
        // Remove all matchedGeometryEffect calls
        // Keep glassEffectID calls with internal namespace
    }
}
```

#### 2.2 LiquidGlassMiniPlayer.swift (KEEP namespace for zoom)
**KEEP these lines:**
- Line 19: `let namespace: Namespace.ID` - KEEP for zoom transition
- Line 48: `.matchedTransitionSource(id: "miniplayer", in: namespace)` - KEEP for zoom source

**Keep initializer as-is:**
```swift
// KEEP: LiquidGlassMiniPlayer(namespace: namespace, showingNowPlaying: $show)
```

#### 2.3 MiniPlayerView.swift (lines to modify) [Verified-Code]
**Remove all matched geometry effects:**
- Line 14: `let animationNamespace: Namespace.ID` - Remove parameter
- Line 47: `.matchedGeometryEffect(id: "artwork", in: animationNamespace)` - Remove
- Line 60: `.matchedGeometryEffect(id: "title", in: animationNamespace)` - Remove
- Line 66: `.matchedGeometryEffect(id: "artist", in: animationNamespace)` - Remove
- Line 79: `.matchedGeometryEffect(id: "playButton", in: animationNamespace)` - Remove

#### 2.4 NowPlayingContainer Files
**Delete BOTH files:**
- `NowPlayingContainer.swift` - No longer needed with sheet presentation
- `NowPlayingContainer_NoAnimation.swift` - Also obsolete

### Phase 3: Update ContentView Implementation

#### 3.1 ContentView with Zoom Transition [Verified-Apple]
```swift
@MainActor
struct ContentView: View {
    @Environment(\.importService) private var importService
    @Environment(\.audioEngine) private var audioService
    @Namespace private var animation  // REQUIRED for zoom transition
    @State private var showingNowPlaying = false
    @State private var selectedDetent: PresentationDetent = .compactPlayer

    var body: some View {
        TabView {
            LibraryView()
                .environment(\.showingNowPlaying, $showingNowPlaying)
                .tabItem {
                    Label("Library", systemImage: "music.note.list")
                }

            // Other tabs with their own NavigationStacks
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
        .preferredColorScheme(.dark)
        .tabViewBottomAccessory {
            if audioService?.currentTrack != nil && !showingNowPlaying {
                LiquidGlassMiniPlayer(
                    namespace: animation,  // Pass namespace for zoom
                    showingNowPlaying: $showingNowPlaying
                )
                .environment(\.audioEngine, audioService)
                // DO NOT add matchedTransitionSource here - LiquidGlassMiniPlayer already has it internally
            }
        }
        .sheet(isPresented: $showingNowPlaying) {
            NowPlayingView()
                .environment(\.audioEngine, audioService)
                .navigationTransition(.zoom(sourceID: "miniplayer", in: animation))  // Zoom FROM tab accessory
                .presentationDetents(
                    [.compactPlayer, .expandedPlayer, .fullPlayer],
                    selection: $selectedDetent
                )
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
                .presentationBackgroundInteraction(
                    .enabled(upThrough: .compactPlayer)
                )
        }
    }
}
```

### Phase 3: Navigation Structure Restoration

#### 3.1 LibraryView.swift
```swift
// Wrap content in NavigationStack
NavigationStack {
    VStack(spacing: 0) {
        // Existing library content
    }
}
```

#### 3.2 SettingsView.swift
```swift
// Wrap content in NavigationStack
NavigationStack {
    List {
        // Existing settings sections
    }
}
```

---

## Presentation Detents Configuration

### Detent Specifications

| Detent | Height | Use Case | Controls Visible |
|--------|--------|----------|-----------------|
| Compact | 140pt | Minimal player | Play/pause, next, track info |
| Medium | 50% screen | Expanded controls | All controls, small artwork |
| Large | Full screen | Complete experience | Full artwork, queue, lyrics |

### Interaction Behavior
```swift
.presentationBackgroundInteraction(.enabled(upThrough: .height(140)))
// User can interact with content behind at compact height

.interactiveDismissDisabled(false)
// Swipe down always dismisses

.presentationContentInteraction(.scrolls)
// Content scrolls when at maximum detent
```

---

## iOS 26 Liquid Glass Features

### Automatic Effects (iOS 26) [Verified-Apple via Deep Research]
- **Background**: Liquid glass material applied automatically to sheets in iOS 26
- **Zoom Transition**: iOS 26 extends navigationTransition to sheets, enabling zoom FROM tab accessory
- **Morphing**: Smooth morphing from mini player to sheet via `matchedTransitionSource` (iOS 18+)
- **Edges**: Bottom edges pull in at smaller heights (automatic at compact detent)
- **Adaptation**: Glass dynamically adapts to content behind using real-time blur and saturation
- **GlassEffectContainer**: iOS 26-exclusive container for grouping and morphing glass elements

### Manual Enhancements
```swift
// Additional glass refinements
.presentationBackground {
    // Custom gradient overlay if needed
    LinearGradient(
        colors: [.clear, .black.opacity(0.1)],
        startPoint: .top,
        endPoint: .bottom
    )
}

// NOTE: .presentationShadow() does NOT exist in any iOS version [Verified-Apple]
// Use standard .shadow() modifier instead if needed
```

---

## State Management

### Shared State Strategy
```swift
// Environment-based audio service
@Environment(\.audioEngine) private var audioService

// Sheet presentation state
@State private var showingNowPlaying = false

// Detent selection state - MUST use constant to prevent binding mismatch [Verified-Code]
@State private var selectedDetent: PresentationDetent = .compactPlayer
```

### State Synchronization
- Audio state remains in AudioEngineFacade
- Sheet state managed locally in ContentView
- Detent changes trigger layout updates
- Dismiss gesture handled by sheet system

---

## Animation & Motion

### Spring Animations
```swift
.animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedDetent)
```

### Accessibility Considerations
```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

// Apply conditional animations
.animation(reduceMotion ? .none : .spring(), value: selectedDetent)
```

---

## Testing Requirements

### Simulator Testing (iPhone 16 Pro, iOS 26)
1. Compact detent shows transport controls
2. Medium detent reveals expanded view
3. Large detent provides full experience
4. Drag between detents is smooth
5. Background interaction works at compact height
6. Swipe to dismiss from any detent
7. Liquid glass adapts to content

### Edge Cases
- Rotation handling
- Dynamic type scaling
- Memory pressure
- Background audio
- Interruption handling

---

## Migration Steps

### Step-by-Step Process (FINAL - iOS 26 Only)
1. Create Plan2/Sheet.md (this document) ✅
2. Set minimum deployment target to iOS 26.0 in Xcode project
3. Define PresentationDetent constants to prevent binding mismatches
4. Create internal @Namespace in NowPlayingView for glass effects
5. Remove namespace parameter from NowPlayingView
6. Remove matchedGeometryEffects from NowPlayingView (4 calls at lines 230, 255, 267, 391)
7. Update 9 glassEffectID calls to use internal namespace
8. KEEP namespace in LiquidGlassMiniPlayer for matchedTransitionSource (line 48)
9. Remove matchedGeometryEffects from MiniPlayerView (4 calls)
10. Delete both NowPlayingContainer.swift and NowPlayingContainer_NoAnimation.swift
11. Update ContentView with sheet presentation and zoom transition
12. Test zoom transition from tab accessory (iOS 26 feature)
13. Verify automatic liquid glass effects (iOS 26 feature)
14. Profile performance with Instruments

### Rollback Plan
- Git stash changes before implementation
- Keep navigation-based code in separate branch
- Can revert to navigationDestination if needed

---

## Performance Considerations

### Optimization Points
- Sheet presentation is more lightweight than navigation
- Detent changes don't rebuild entire view hierarchy
- Background blur computed by system
- Lazy loading of content per detent

### Memory Impact
- Sheet keeps underlying view in memory
- Consider releasing resources at compact detent
- Monitor for retain cycles in closures

---

## Code Examples

### Complete ContentView Implementation with Zoom Transition
```swift
@MainActor
struct ContentView: View {
    @Environment(\.importService) private var importService
    @Environment(\.audioEngine) private var audioService
    @Namespace private var animation  // Required for zoom transition
    @State private var showingNowPlaying = false
    @State private var selectedDetent: PresentationDetent = .compactPlayer

    var body: some View {
        // iOS 26-only implementation, no fallback
            TabView {
                LibraryView()
                    .environment(\.showingNowPlaying, $showingNowPlaying)
                    .tabItem {
                        Label("Library", systemImage: "music.note.list")
                    }

                // Other tabs...
            }
            .preferredColorScheme(.dark)
            .tabBarMinimizeBehavior(.onScrollDown)
            .tabViewBottomAccessory {
                if audioService?.currentTrack != nil && !showingNowPlaying {
                    LiquidGlassMiniPlayer(
                        namespace: animation,
                        showingNowPlaying: $showingNowPlaying
                    )
                    // matchedTransitionSource is already applied inside LiquidGlassMiniPlayer
                }
            }
            .sheet(isPresented: $showingNowPlaying) {
                NowPlayingView()
                    .environment(\.audioEngine, audioService)
                    .navigationTransition(.zoom(sourceID: "miniplayer", in: animation))
                    .presentationDetents(
                        [.compactPlayer, .expandedPlayer, .fullPlayer],
                        selection: $selectedDetent
                    )
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(20)
            }
    }
}
```

---

## Success Criteria

### Must Have
- [ ] App runs on iOS 26.0+ only (no fallback for older versions)
- [ ] Sheet presents at three detent sizes
- [ ] Transport controls work at compact height
- [ ] Liquid glass background automatically applied by iOS 26
- [ ] Smooth detent transitions
- [ ] Swipe to dismiss works
- [ ] Background interaction at compact height
- [ ] Zoom transition works from tab accessory to sheet

### Nice to Have
- [ ] Haptic feedback on detent changes
- [ ] Gesture velocity recognition
- [ ] Smart detent memory
- [ ] Artwork color extraction
- [ ] Parallax effects

---

## Timeline

| Phase | Duration | Deliverable |
|-------|----------|------------|
| Planning | Complete | This document |
| Implementation | 2 hours | Core sheet functionality |
| Polish | 1 hour | Animations and refinements |
| Testing | 1 hour | Simulator verification |
| Documentation | 30 min | Update CLAUDE.md |

---

## References

### Official Apple Documentation [Verified-Apple via Deep Research]
- [iOS 26 tabViewBottomAccessory](https://developer.apple.com/documentation/swiftui/view/tabviewbottomaccessory(content:)) - iOS 26.0+ exclusive
- [iOS 26 tabBarMinimizeBehavior](https://developer.apple.com/documentation/swiftui/view/tabbarminimizebehavior(_:)) - iOS 26.0+ exclusive
- [iOS 26 Liquid Glass glassEffect](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:isenabled:)) - iOS 26.0+ exclusive
- [iOS 26 GlassEffectContainer](https://developer.apple.com/documentation/swiftui/glasseffectcontainer) - iOS 26.0+ exclusive
- [iOS 18+ matchedTransitionSource](https://developer.apple.com/documentation/swiftui/view/matchedtransitionsource(id:in:)) - Available since iOS 18.0
- [iOS 18+ navigationTransition](https://developer.apple.com/documentation/swiftui/view/navigationtransition(_:)) - iOS 18.0+ for navigation, iOS 26.0+ for sheets
- [iOS 16+ presentationDetents](https://developer.apple.com/documentation/swiftui/view/presentationdetents(_:)) - Available since iOS 16.0

### WWDC Sessions
- [WWDC25: Build a SwiftUI app with the new design](https://www.youtube.com/watch?v=3MugGCtm26A)
- [WWDC25: Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/)
- [WWDC25: Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)

### Analysis Sources
- OpenAI Codex Analysis (2025-09-22)
- Exa AI Deep Research (2025-09-22)

---

## Implementation Summary (Updated with Apple Docs)

### Files Requiring Changes (VERIFIED WITH CODE-INDEX) [Verified-Code]
| File | Changes | Details |
|------|---------|---------|
| NowPlayingView.swift | Complex refactor needed | Remove 4 matchedGeometryEffects, handle 9 glassEffectID dependencies (lines 231, 256, 268, 288, 355, 373, 392, 411, 430) |
| LiquidGlassMiniPlayer.swift | NO CHANGES | Already has namespace and matchedTransitionSource internally at line 48 |
| MiniPlayerView.swift | Remove 5 items | Remove namespace parameter (line 14) and 4 matchedGeometryEffect calls (lines 47, 60, 66, 79) |
| NowPlayingContainer.swift | Delete file | Obsolete with sheet presentation - only has internal preview |
| NowPlayingContainer_NoAnimation.swift | Delete file | Also obsolete - only has internal preview |
| ContentView.swift | Add namespace + sheet | Add @Namespace, sheet with zoom, NO duplicate matchedTransitionSource |

### Verified iOS 26 APIs [Verified-Apple via Deep Research]
✅ **Confirmed iOS 26-Exclusive:**
- `.tabViewBottomAccessory` - Tab bar accessory views (iOS 26.0+)
- `.tabBarMinimizeBehavior(.onScrollDown)` - Collapsing tab bars (iOS 26.0+)
- `glassEffect(_:in:)` - Liquid Glass material (iOS 26.0+)
- `GlassEffectContainer` - Glass morphing container (iOS 26.0+)
- Sheet zoom transitions - iOS 26 extends navigationTransition to sheets
- Automatic Liquid Glass on sheets - Applied by system in iOS 26

✅ **Confirmed iOS 18+ (not iOS 26 exclusive):**
- `.matchedTransitionSource(id:in:)` - Mark zoom source view (iOS 18.0+)
- `.navigationTransition(.zoom(sourceID:in:))` - iOS 18+ for navigation, iOS 26+ for sheets
- `.presentationDetents` - Sheet height control (iOS 16.0+)

❌ **Does NOT exist:**
- `.presentationShadow()` - Use standard `.shadow()` instead

### Critical Implementation Pattern
```swift
// In ContentView:
@Namespace private var animation

// On tab accessory:
.matchedTransitionSource(id: "miniplayer", in: animation)

// On sheet content:
.navigationTransition(.zoom(sourceID: "miniplayer", in: animation))
```

### Key Insight
- **Namespace IS required** - But for zoom transition, NOT matched geometry
- **matchedTransitionSource ≠ matchedGeometryEffect** - Different APIs
- **Sheet zooms FROM tab accessory** - Not slides from bottom

## Notes

- iOS 26 automatically applies liquid glass to sheets (no manual intervention needed)
- Sheet morphing animations are handled by the system
- Consider using `.presentationCompactAdaptation(.none)` for consistent behavior
- Test with different audio formats to ensure smooth playback during transitions
- Detent constants prevent the selection binding bug Codex identified

## Critical Implementation Adjustments (Post-Codex Review)

### Issues Resolved:
1. ✅ **Glass Effect Dependencies**: NowPlayingView needs internal @Namespace for glass effects
2. ✅ **Double matchedTransitionSource**: Don't add in ContentView - already in LiquidGlassMiniPlayer
3. ✅ **navigationTransition on sheets**: Confirmed working per Apple docs
4. ✅ **Two Container Files**: Both NowPlayingContainer files need deletion
5. ✅ **Detent Constants**: Must use consistently to prevent binding mismatches

### Implementation Strategy (VERIFIED):
1. Create internal namespace in NowPlayingView for glass effects only OR remove glass effects entirely
2. Remove all matchedGeometryEffect calls (4 total verified)
3. Update all glassEffectID calls to use internal namespace (9 total verified, not 11)
4. Keep LiquidGlassMiniPlayer unchanged (already has proper setup at line 48)
5. Delete both NowPlayingContainer files (no external references found)
6. Use detent constants throughout (no inline .height(140))

### iOS 26 Zoom Transition Confirmation [Verified-Apple]
Based on deep research of official Apple documentation:
1. iOS 26 DOES extend `.navigationTransition(.zoom())` to work on sheets
2. This is a new iOS 26 feature that unifies zoom transitions across presentation styles
3. The zoom will work from tab accessory to sheet as intended
4. No fallback needed - this is confirmed functionality in iOS 26

---

*Document created: 2025-09-22*
*Author: Claude with Codex validation and Apple documentation verification*
*Status: FINAL - Verified with code-index, Apple documentation deep research, and Codex feedback*
*Last update: Confirmed iOS 26 APIs via official documentation, added iOS 26-only requirement*
*Minimum iOS Version: 26.0 (no fallback support)*