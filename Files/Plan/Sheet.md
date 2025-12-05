# Sheet Presentation Conversion Plan for Fonic HiFi
## Mini Player to Now Playing Transition - iOS 26 Only

### Executive Summary [Verified Implementation]
Convert the current full-screen navigation zoom transition to a modern three-level sheet presentation system with iOS 26 zoom transitions that matches standard iOS music apps (Apple Music, Spotify). The sheet morphs from the mini player using zoom transition, opens at medium height (50%) by default, then can expand to full screen with a swipe up gesture. iOS 26's Liquid Glass effects are applied automatically.

**Key Three-Level Behavior** [Verified-Apple]:
1. **Tab Accessory Mini Player** - Always visible with working play/pause/next controls
2. **Medium Sheet (50%)** - Opens on tap, background remains interactive
3. **Full Screen Sheet** - Expands on swipe up, complete Now Playing experience

**Interactive Controls** [Verified-Code]:
- Play/pause button functional (LiquidGlassMiniPlayer lines 115-124)
- Next track button functional (lines 126-135)
- Tap to expand working (line 50)
- Live track updates (lines 70-79)

**IMPORTANT**: This implementation requires iOS 26.0+ with no fallback support for older iOS versions. The app's minimum deployment target must be set to iOS 26.0.

---

## Current Implementation Analysis

### Present State [Verified-Code]
- **Presentation Method**: `navigationDestination(isPresented:)` at line 46
- **Transition**: Zoom transition with matched geometry
- **Coverage**: Full screen takeover
- **Namespace**: Defined at ContentView line 15, passed to LiquidGlassMiniPlayer at line 42
- **Navigation**: Single NavigationStack wrapping entire TabView
- **Tab Accessory**: LiquidGlassMiniPlayer at lines 40-45 with namespace parameter

### Issues with Current Approach
1. Full screen presentation is too intrusive - immediately covers entire screen
2. User loses context of underlying content - no partial view option
3. Navigation stack coupling creates complexity
4. Zoom transition requires matched geometry setup
5. Not utilizing iOS 26's sheet detent system for progressive disclosure
6. Doesn't match standard iOS music app behavior (Apple Music pattern)

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
- ✅ Sheet zoom transitions - VERIFIED (iOS 26.0+) when sheet content wrapped in NavigationStack [Verified via Exa Research & Nil Coalescing]

#### APIs Available Since Earlier iOS Versions [Verified-Apple]:
- ✅ `matchedTransitionSource(id:in:)` (iOS 18.0+) - For navigation transitions only
- ✅ `navigationTransition(.zoom)` (iOS 18.0+) - Navigation stacks, extended to sheets in iOS 26.0+
- ✅ `presentationDetents` (iOS 16.0+) - Supports .medium and .large detents
- ✅ `presentationBackgroundInteraction` (iOS 16.4+) - Enable with .enabled(upThrough: .medium)
- ✅ `presentationDragIndicator` (iOS 16.0+) - Shows visual drag affordance

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

### Existing Implementation Reference: ContentView_Safe.swift

The project contains `ContentView_Safe.swift` which uses basic sheet presentation without zoom transitions. This serves as a fallback reference but lacks the modern iOS 26 zoom transition capabilities we're implementing.

Key differences from our target implementation:
- ContentView_Safe uses `.safeAreaInset` instead of `.tabViewBottomAccessory`
- No namespace or zoom transitions
- Basic sheet presentation without detents
- Missing album color tinting feature

## Reference Implementation: Halie Project Pattern

### How Halie Implements Tab Accessory with Sheet

Based on the Halie health app project (MainTabView.swift), here's the proven pattern:

#### 1. Tab View Accessory Structure
```swift
// Halie's MainTabView.swift:116-120
.tabViewBottomAccessory {
    TabAccessoryView()  // Mini view with live data
        .environmentObject(appState)
}
```

#### 2. Key Implementation Features from Halie:
- **Interactive Glass Effect**: Uses `.glassButton(tint:)` with dynamic intensity
- **Live Data Updates**: Real-time updates in the accessory view
- **Sheet Presentation**: Tapping opens detailed view with fluid transition
- **Auto-hide on scroll**: `.tabBarMinimizeBehavior(.onScrollDown)`
- **Glass material adaptation**: Dynamically adjusts based on interaction

#### 3. Three-Level Interaction Pattern:
1. **Tab Accessory** (Persistent): Shows quick status/controls
2. **Sheet at Medium** (50%): Opens on tap for expanded controls
3. **Sheet at Large** (Full): Drag up for complete experience

#### 4. Accessibility Support:
- Full VoiceOver with descriptive labels
- Progress percentages announced
- Hints for expanding to detailed view

---

## Detailed Implementation Plan for Fonic HiFi

### Critical Issues Found (Codex + Apple Documentation Analysis)

#### Key Problems to Address:
1. **NowPlayingView requires namespace for MORE than matchedGeometryEffect** - Has 9 `.glassEffectID()` calls that all need namespace [Verified-Code]
2. **13 namespace-dependent calls in NowPlayingView** - 4 matchedGeometryEffect + 9 glassEffectID [Verified-Code]
3. **Double matchedTransitionSource risk** - LiquidGlassMiniPlayer already applies `.matchedTransitionSource()` at line 48
4. **Two NowPlayingContainer files** - Both NowPlayingContainer.swift and NowPlayingContainer_NoAnimation.swift need deletion
5. **Detent binding mismatch still present** - Plan inconsistently uses both constants and inline `.height(140)`

#### Updated Findings - Sheet Presentation Pattern:
6. **Sheet zoom transition confirmed** - `.navigationTransition(.zoom(_:))` works with sheet content when the sheet wraps a NavigationStack on iOS 26 [Verified-Apple].
7. **Zoom morphing remains primary animation** - Keep the zoom-based morph between mini player and sheet for continuity with pre-sheet navigation.
8. **Tab accessory interaction** - Tap triggers sheet presentation at medium detent.
9. **Liquid Glass is automatic** - iOS 26 automatically applies Liquid Glass material to sheets.

### Phase 1: Sheet Configuration for Music App Pattern

#### 1.1 Use Built-in Detents (Simplified)
```swift
// No custom detents needed - use iOS built-in .medium and .large
@State private var selectedDetent: PresentationDetent = .medium  // Start at 50%
```

#### 1.2 Configure Sheet Presentation
```swift
.sheet(isPresented: $showingNowPlaying) {
    NowPlayingView()
        .presentationDetents(
            [.medium, .large],  // Two levels: 50% and full
            selection: $selectedDetent
        )
        .presentationBackgroundInteraction(
            .enabled(upThrough: .medium)  // Interactive behind at 50%
        )
        .presentationDragIndicator(.visible)
}
```

### Phase 2: Update Namespace Usage (Keep Shared Namespace)

#### 2.1 NowPlayingView.swift (Trim Redundancy, Keep Zoom)
- Keep `let animationNamespace: Namespace.ID`; the shared namespace is required for both the zoom transition and every `glassEffectID` call.
- Keep `.navigationTransition(.zoom(sourceID: "miniplayer", in: animationNamespace))` so the sheet morph matches the tab accessory.
- Remove the redundant `.matchedGeometryEffect` modifiers on `artwork`, `title`, `artist`, and `playButton`—the paired `glassEffectID` helper already applies the geometry matching Liquid Glass needs.
- Leave the nine `glassEffectID` calls untouched, still referencing the shared namespace.

#### 2.2 LiquidGlassMiniPlayer.swift (Retain Namespace Source)
- Keep the `namespace` parameter and the existing `.matchedTransitionSource(id: "miniplayer", in: namespace)`—this view is the source of the zoom transition.
- Optional future enhancement: layer in dynamic tinting using `.glassEffect(.regular.tint(dominantColor))` once a color-extraction helper exists.

#### 2.3 MiniPlayerView.swift (Legacy Fallback)
- Used only by legacy previews and `ContentView_Safe`. Remove its explicit `.matchedGeometryEffect` modifiers so it no longer conflicts with the sheet-driven namespace.
- Drop the unused `animationNamespace` parameter once those modifiers are gone.
- If the fallback continues to use it, rely on the sheet zoom path for animation rather than geometry matching here.

#### 2.4 NowPlayingContainer Files
**Delete BOTH files:**
- `NowPlayingContainer.swift` - Obsolete with sheet presentation.
- `NowPlayingContainer_NoAnimation.swift` - Obsolete fallback.

### Phase 3: Update ContentView Implementation (Following Halie Pattern)

#### 3.1 ContentView with Sheet Presentation [Matching Halie's TabAccessoryView Pattern]
```swift
@MainActor
struct ContentView: View {
    @Environment(\.importService) private var importService
    @Environment(\.audioEngine) private var audioService

    @Namespace private var miniPlayerNamespace  // KEEP for zoom transition
    @State private var showingNowPlaying = false
    @State private var selectedDetent: PresentationDetent = .medium  // Start at medium height

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
        .tabBarMinimizeBehavior(.onScrollDown)  // Halie pattern: auto-hide on scroll
        .tabViewBottomAccessory {
            // Following Halie's TabAccessoryView pattern
            if audioService?.currentTrack != nil && !showingNowPlaying {
                LiquidGlassMiniPlayer(
                    namespace: miniPlayerNamespace,  // Pass namespace for zoom
                    showingNowPlaying: $showingNowPlaying
                )
                .environment(\.audioEngine, audioService)
                // LiquidGlassMiniPlayer already marks the matchedTransitionSource internally
            }
        }
        .sheet(isPresented: $showingNowPlaying) {
            NavigationStack {  // Required for zoom transition
                NowPlayingView(animationNamespace: miniPlayerNamespace)  // Pass namespace
                    .navigationTransition(.zoom(sourceID: "miniplayer", in: miniPlayerNamespace))
                    .toolbar(.hidden, for: .navigationBar)
            }
            .environment(\.audioEngine, audioService)
            .presentationDetents(
                [.medium, .large],  // 50% and full screen
                selection: $selectedDetent
            )
            .presentationBackgroundInteraction(
                .enabled(upThrough: .medium)  // Interactive at 50%
            )
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
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

### Detent Specifications (Revised for Music App Pattern)

| Level | Component | Height | Use Case | User Action |
|-------|-----------|--------|----------|-------------|
| 1 | Tab Accessory | 74pt | Mini player always visible | Tap to expand |
| 2 | Sheet Medium | 50% screen | Default sheet presentation | Swipe up for more |
| 3 | Sheet Large | Full screen | Complete Now Playing view | Swipe down to reduce |

**Key Behavior Changes**:
- Sheet opens at `.medium` (50%) by default, NOT full screen
- User can see and interact with library content behind at medium height
- Matches Apple Music and Spotify behavior patterns

### Interaction Behavior
```swift
.presentationBackgroundInteraction(.enabled(upThrough: .medium))
// User can interact with content behind at medium height

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

// Detent selection state - start the sheet at medium height
@State private var selectedDetent: PresentationDetent = .medium
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
1. Medium detent shows transport controls
2. Large detent reveals expanded view
3. Full-screen detent provides complete experience
4. Drag between detents is smooth
5. Background interaction works at medium height
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

### Step-by-Step Process (Updated for Music App Behavior)
1. Create Plan2/Sheet.md (this document) ✅
2. Set minimum deployment target to iOS 26.0 in Xcode project.
3. Use `ContentView_Safe.swift` as a reference and update the real `ContentView.swift`:
   - Replace the `navigationDestination` flow with `.sheet`.
   - Keep the shared `@Namespace` and pass it into LiquidGlassMiniPlayer and NowPlayingView.
   - Add `.tabViewBottomAccessory`, `.presentationDetents([.medium, .large])`, and `.presentationBackgroundInteraction(.enabled(upThrough: .medium))`.
4. Simplify `NowPlayingView.swift`:
   - Keep the external namespace parameter.
   - Remove the redundant `.matchedGeometryEffect` modifiers while leaving all nine `glassEffectID` calls.
   - Keep `.navigationTransition(.zoom(sourceID: "miniplayer", in: animationNamespace))`.
5. Update `LiquidGlassMiniPlayer.swift`:
   - Retain the namespace parameter and existing `.matchedTransitionSource`.
   - Make no functional changes beyond wiring it into the new ContentView flow (optional tinting lives in future enhancements).
6. Simplify `MiniPlayerView.swift` (legacy fallback):
   - Remove the `.matchedGeometryEffect` calls.
   - Drop the now-unused namespace parameter.
7. Clean up obsolete files:
   - Delete `NowPlayingContainer.swift`.
   - Delete `NowPlayingContainer_NoAnimation.swift`.
8. Test the three-level behavior:
   - Tap mini player → opens at medium detent.
   - Swipe up → expands to large.
   - Swipe down → returns to medium or dismisses.
9. Verify Liquid Glass and interactions on iPhone 16 Pro (iOS 26) simulator.
10. Optional polish: introduce a color-extraction helper and apply tinted glass once core behavior is verified.

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

### Complete ContentView Implementation (With Zoom Transition)
```swift
@MainActor
struct ContentView: View {
    @Environment(\.importService) private var importService
    @Environment(\.audioEngine) private var audioService

    @Namespace private var miniPlayerNamespace  // Required for zoom
    @State private var showingNowPlaying = false
    @State private var selectedDetent: PresentationDetent = .medium  // Start at 50%

    var body: some View {
        // iOS 26-only implementation with zoom transition
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
                        namespace: miniPlayerNamespace,
                        showingNowPlaying: $showingNowPlaying
                    )
                    .environment(\.audioEngine, audioService)
                }
            }
            .sheet(isPresented: $showingNowPlaying) {
                NavigationStack {  // Required for zoom transition
                    NowPlayingView(animationNamespace: miniPlayerNamespace)
                        .navigationTransition(.zoom(sourceID: "miniplayer", in: miniPlayerNamespace))
                        .toolbar(.hidden, for: .navigationBar)
                }
                .environment(\.audioEngine, audioService)
                .presentationDetents(
                    [.medium, .large],  // 50% and full screen
                    selection: $selectedDetent
                )
                .presentationBackgroundInteraction(
                    .enabled(upThrough: .medium)  // Interactive at 50%
                )
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
            }
    }
}
```

---

## Success Criteria (Updated Based on Halie Pattern)

### Must Have
- [ ] App runs on iOS 26.0+ only (no fallback for older versions)
- [ ] Tab accessory mini player always visible when playing
- [ ] Sheet opens at medium (50%) height when tapping mini player
- [ ] Background interaction works at medium detent (like Halie)
- [ ] Drag up expands to full screen
- [ ] Drag down reduces to 50% or dismisses
- [ ] Liquid glass automatically applied by iOS 26
- [ ] Auto-hide tab bar on scroll (.tabBarMinimizeBehavior)

### Nice to Have (From Halie Features)
- [ ] Live updates in mini player (waveform visualization)
- [ ] Haptic feedback on detent changes
- [ ] Glass intensity adaptation based on interaction
- [ ] Morphing animations between states
- [ ] Accessibility announcements for state changes

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

### Verified Through Deep Research (2025-09-23)

- **Exa AI Research Pro**: Confirmed iOS 26 sheets support zoom transitions when wrapped in NavigationStack. The research synthesized official Apple documentation, WWDC 2025 sessions, and verified that `navigationTransition(.zoom)` works with sheets when the sheet content is inside a NavigationStack.
- **Nil Coalescing Tutorial**: ["Presenting Liquid Glass sheets in SwiftUI on iOS 26"](https://nilcoalescing.com/blog/PresentingLiquidGlassSheetsInSwiftUI) - Shows working implementation with morphing transition from toolbar button to sheet using matchedTransitionSource.
- **Stewart Lynch Video**: ["Mastering iOS 26 Toolbars & Modal Sheets"](https://www.youtube.com/watch?v=IiLDbrtBsn0) - Demonstrates zoom transition from toolbar to sheet presentation with glass buttons.

---

## Implementation Summary (Updated with Apple Docs)

### Files Requiring Changes (VERIFIED WITH CODE-INDEX) [Verified-Code]
| File | Changes | Details |
|------|---------|---------|
| NowPlayingView.swift | Keep namespace for zoom | Keep namespace parameter for zoom transition, remove 4 matchedGeometryEffects, keep 9 glassEffectID calls |
| LiquidGlassMiniPlayer.swift | Keep namespace source | Retain namespace (lines 19, 48) for zoom; optional future tinting can layer on `.glassEffect(.regular.tint(_))` |
| MiniPlayerView.swift | Simplify legacy fallback | Remove matchedGeometryEffect calls (lines 47, 60, 66, 79) and drop the now-unused namespace parameter |
| NowPlayingContainer.swift | Delete file | Obsolete with sheet presentation - only has internal preview |
| NowPlayingContainer_NoAnimation.swift | Delete file | Also obsolete - only has internal preview |
| ContentView.swift | Add zoom sheet | Keep @Namespace, wrap sheet in NavigationStack, add navigationTransition |

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

### Implementation Pattern (Sheet + Zoom Reference)
```swift
@Namespace private var miniPlayerNamespace

TabView {
    // ... tabs ...
}
.tabViewBottomAccessory {
    LiquidGlassMiniPlayer(
        namespace: miniPlayerNamespace,
        showingNowPlaying: $showingNowPlaying
    )
}
.sheet(isPresented: $showingNowPlaying) {
    NavigationStack {
        NowPlayingView(animationNamespace: miniPlayerNamespace)
            .navigationTransition(.zoom(sourceID: "miniplayer", in: miniPlayerNamespace))
    }
    .presentationDetents([.medium, .large])
}
```

### Key Insights
- **Zoom transition stays** thanks to the shared namespace flowing from `ContentView` into both views.
- **Tab accessory mirrors Halie** while reusing existing LiquidGlassMiniPlayer behavior.
- **Liquid Glass remains automatic** on sheets; custom tinting is optional polish.

## Notes

- iOS 26 automatically applies liquid glass to sheets (no manual intervention needed)
- Sheet morphing animations are handled by the system
- Consider using `.presentationCompactAdaptation(.none)` for consistent behavior
- Test with different audio formats to ensure smooth playback during transitions
- Detent constants prevent the selection binding bug Codex identified
- Dynamic color tinting lives in optional polish once the core flow is shipped

## Critical Implementation Adjustments (Post-Codex Review)

### Issues Resolved (Post-Codex Revisions):
1. ✅ **Glass Effect Dependencies**: Keep the shared namespace flowing from ContentView; remove only the redundant matched geometry in NowPlayingView.
2. ✅ **Mini Player Namespace**: Retain LiquidGlassMiniPlayer’s namespace parameter and source marker—no duplicate `.matchedTransitionSource` calls in ContentView.
3. ✅ **navigationTransition on sheets**: Confirmed—keep the zoom transition by hosting the sheet content inside a NavigationStack.
4. ✅ **Two Container Files**: Both NowPlayingContainer files need deletion.
5. ✅ **Use built-in detents**: `.medium` and `.large` (no custom constants needed).

### Implementation Strategy (Sheet + Zoom Pattern):
1. Keep the external namespace flowing from the root so glass effects and zoom share the same namespace.
2. Remove redundant `matchedGeometryEffect` modifiers from NowPlayingView (4 total verified) while keeping `glassEffectID` calls that rely on the namespace.
3. Ensure every `glassEffectID` call continues to use the shared namespace (9 total verified).
4. Update LiquidGlassMiniPlayer while retaining the namespace parameter and `.matchedTransitionSource`, layering any optional color tinting afterward if pursued.
5. Treat ColorExtractionService.swift as a future enhancement rather than a blocker for sheet conversion.
6. Delete both NowPlayingContainer files (no external references found).
7. Use `.medium` and `.large` detents for the sheet.

### Sheet Presentation Approach (Zoom Path)
1. Sheet presentation uses the zoom transition; wrap the sheet content in a NavigationStack to enable it.
2. Focus on the three-level interaction pattern (tab accessory → medium sheet → large sheet).
3. Keep LiquidGlassMiniPlayer as the morphing source with the shared namespace.
4. Liquid Glass effects apply automatically in iOS 26.

---

*Document created: 2025-09-22*
*Author: Claude with Halie project reference*
*Status: VERIFIED - All APIs confirmed with Apple documentation*
*Last update: 2025-09-23 - Verified APIs with Apple RAG and sosumi*
*Minimum iOS Version: 26.0 (no fallback support)*

**Verification Summary**:
- ✅ Sheet detents work as documented (iOS 16.0+)
- ✅ Background interaction confirmed (iOS 16.4+)
- ✅ Tab accessory confirmed (iOS 26.0+)
- ✅ Interactive controls verified in code
- ✅ Liquid glass tinting with `.tint(_:)` confirmed (iOS 26.0+) [Verified-Apple]
- ✅ Zoom transition CONFIRMED for sheets when wrapped in NavigationStack [Verified via Exa Research]

**Album Color Tinting Feature** [Added 2025-09-23]:
- Uses native iOS 26 `.glassEffect(.regular.tint(color))` API
- Extracts dominant color from track artwork
- Animates color transitions when track changes
- Follows Apple Music pattern of dynamic theming