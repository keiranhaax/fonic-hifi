# iOS 26 Tab Bar Redesign - Apple Music Style

**Status**: Ready for Implementation
**Date**: 2025-09-30
**Objective**: Migrate to modern iOS 26 tab bar with floating search, Apple Music-style search behavior with scopes, and Home tab

---

## Critical Insights from Codex [Verified-Apple]

**Search is a TabView-Level Concern in iOS 26**

The key architectural insight: Search state and keyboard activation are controlled by **TabView modifiers**, not SearchView. This creates the Apple Music experience where:

1. Tapping search bubble opens large Liquid Glass search field
2. Tapping search bubble again activates keyboard
3. Search queries local music library (tracks/albums/artists/playlists)
4. Canceling search returns to previous tab

**Required APIs** (iOS 26.0+):
- `.searchable(text:placement:)` - Creates large glass search field with keyboard
- `.tabViewSearchActivation(.searchTabSelection)` - Handles tap-to-reactivate-keyboard + cancel-to-previous-tab behavior
- `Tab(..., role: .search)` - Creates floating search bubble (iOS 18.0+)

**Sample Reference**: `sample/AppleMusicBottomBar/AppleMusicBottomBar/ContentView.swift:93`

---

## Visual Requirements (from User Screenshots)

### Tab Bar Layout
```
┌─────────────────────────────────────────────────────┐
│  [Home]  [Library]  [Settings]  ...  [🔍 Search]   │
│    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^        ^^^^         │
│         Main tabs (left)            Floating        │
└─────────────────────────────────────────────────────┘
```

### Search Behavior (Apple Music Style)
1. **First tap on search bubble**: Opens search view with large glass field
2. **Second tap on search bubble**: Keyboard appears for input
3. **When typing**: Searches local music library (tracks/albums/artists/playlists)
4. **Cancel search**: Returns to previously active tab (Home, Library, or Settings)

### Mini Player Position
- **Location**: Above tab bar (using `.tabViewBottomAccessory`)
- **Visibility**: Always visible, even with empty library
- **Style**: Liquid Glass with native iOS 26 `.glassEffect()`
- **Empty state**: Shows "Not Playing" with placeholder, buttons remain interactive but disabled

---

## Implementation Plan

### Phase 1: Create Home Tab

#### File: `Fonic HiFi/Presentation/Views/Home/HomeView.swift`
**Action**: Create new file
**Lines**: ~45 lines

```swift
//
//  HomeView.swift
//  Fonic HiFi
//
//  iOS 26 Home tab with recently played and most listened sections
//

import SwiftUI

/// Main home view showing music discovery and recent activity
@MainActor
struct HomeView: View {
    @Environment(\.showingNowPlaying) private var showingNowPlaying

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Recently Played Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recently Played")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        Text("No tracks yet")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    }

                    // Most Listened Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Most Listened")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        Text("No tracks yet")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    }
                }
                .padding(.top, 24)
            }
            .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeView()
}
```

**Why This Design**:
- Simple placeholder for Phase 1 (can be enhanced later with actual data)
- Follows SwiftUI best practices with proper spacing
- Includes sections for "Recently Played" and "Most Listened" (future data hooks)
- Uses `.secondary` text color for empty states (iOS 26 standard)

---

### Phase 2: Update ContentView with TabView-Level Search

#### File: `Fonic HiFi/ContentView.swift`

#### Step 2A: Add Search State (After line 18)

**Current state block (lines 16-18)**:
```swift
@Namespace private var miniPlayerNamespace
@State private var showingNowPlaying = false
@State private var selectedDetent: PresentationDetent = .medium
```

**Add after line 18**:
```swift
@State private var searchText = ""
```

#### Step 2B: Replace TabView Block (Lines 21-40)

**Current code (TO REMOVE)**:
```swift
TabView {
    LibraryView()
        .environment(\.showingNowPlaying, $showingNowPlaying)
        .tabItem {
            Label("Library", systemImage: "music.note.list")
        }

    SearchView()
        .environment(\.showingNowPlaying, $showingNowPlaying)
        .environment(\.audioEngine, audioService)
        .environment(\.importService, importService)
        .tabItem {
            Label("Search", systemImage: "magnifyingglass")
        }

    SettingsView()
        .tabItem {
            Label("Settings", systemImage: "gear")
        }
}
```

**New code (TO ADD)**:
```swift
TabView {
    Tab("Home", systemImage: "house") {
        HomeView()
            .environment(\.showingNowPlaying, $showingNowPlaying)
    }

    Tab("Library", systemImage: "music.note.list") {
        LibraryView()
            .environment(\.showingNowPlaying, $showingNowPlaying)
    }

    Tab("Settings", systemImage: "gear") {
        SettingsView()
    }

    Tab("Search", systemImage: "magnifyingglass", role: .search) {
        SearchView(searchText: $searchText)
            .environment(\.showingNowPlaying, $showingNowPlaying)
            .environment(\.audioEngine, audioService)
            .environment(\.importService, importService)
    }
}
.searchable(text: $searchText, placement: .automatic, prompt: Text("Search Library"))
.tabViewSearchActivation(.searchTabSelection)
.tabBarMinimizeBehavior(.onScrollDown)
```

**Key Changes Explained**:

1. **Lines 1-4**: Home tab (new, first position)
2. **Lines 6-9**: Library tab (modern syntax, second position)
3. **Lines 11-13**: Settings tab (modern syntax, third position)
4. **Lines 15-20**: Search tab with `role: .search` - only text binding passed to SearchView
5. **Line 22**: `.searchable()` on TabView - creates large glass search field for local library
6. **Line 23**: `.tabViewSearchActivation(.searchTabSelection)` - tap-to-keyboard + cancel-to-previous-tab
7. **Line 24**: `.tabBarMinimizeBehavior(.onScrollDown)` - tab bar shrinks on scroll

#### Step 2C: Fix Mini Player Visibility (Line 44)

**Current code**:
```swift
if let audioService, audioService.currentTrack != nil, !showingNowPlaying {
```

**Change to**:
```swift
if let audioService, !showingNowPlaying {
```

**Reason**: Remove `audioService.currentTrack != nil` guard so mini player always visible (even in empty library state).

---

### Phase 3: Refactor SearchView to Accept Text Binding

#### File: `Fonic HiFi/Presentation/Views/Search/SearchView.swift`

#### Step 3A: Update struct declaration (Line 13)

**Current**:
```swift
struct SearchView: View {
```

**Change to**:
```swift
struct SearchView: View {
    @Binding var searchText: String
```

#### Step 3B: Remove local search state (Line 15)

**Remove this line**:
```swift
@State private var searchText = ""
```

**Reason**: Search text now comes from parent ContentView binding.

#### Step 3C: Remove .searchable modifier (Lines 56-60)

**Remove these lines**:
```swift
.searchable(
    text: $searchText,
    placement: .toolbar,
    prompt: Text("Search your library"),
)
```

**Reason**: `.searchable()` now controlled by TabView, not SearchView.

**Note**: No changes needed to `searchAllContent()` function - it already searches local library correctly.

---

## Files Changed Summary

### Create (1 file):
1. ✨ **`Fonic HiFi/Presentation/Views/Home/HomeView.swift`** (~45 lines)
   - New Home tab with placeholder sections

### Modify (2 files):
1. ✏️ **`Fonic HiFi/ContentView.swift`** (3 changes)
   - Add search text state property (after line 18, 1 line)
   - Replace TabView block with modern Tab() syntax (lines 21-40, ~24 lines)
   - Fix mini player guard (line 44, 1 change)

2. ✏️ **`Fonic HiFi/Presentation/Views/Search/SearchView.swift`** (3 changes)
   - Add text binding parameter to struct (after line 13, 1 line)
   - Remove local searchText state (line 15, 1 deletion)
   - Remove .searchable modifier (lines 56-60, 5 deletions)

### Keep As-Is (1 file):
✅ **`Fonic HiFi/Presentation/Views/NowPlaying/LiquidGlassMiniPlayer.swift`**
   - **IMPORTANT**: Keep existing `.disabled()` and `.opacity()` modifiers on buttons (lines 122-123, 135-136)
   - **Reason**: Codex confirmed these are correct UX - prevent haptic feedback on empty taps
   - No changes needed to this file

---

## Expected Behavior After Implementation

### ✅ Tab Bar
- **Count**: 4 tabs total
- **Main tabs** (left side): Home, Library, Settings (grouped together)
- **Floating tab** (right side): Search (separated, magnifying glass icon)
- **Scroll behavior**: Tab bar shrinks when scrolling down content
- **Visual style**: Native iOS 26 Liquid Glass bubble styling

### ✅ Search Experience (Apple Music Style)
- **First tap on search**: Opens SearchView with large glass search field visible
- **Second tap on search**: Keyboard appears for input
- **Search prompt**: "Search Library" placeholder text
- **Search results**: Returns tracks/albums/artists/playlists from local music library
- **Cancel search**: Keyboard dismisses, returns to previous tab (Home/Library/Settings)

### ✅ Mini Player
- **Visibility**: Always visible above tab bar (Apple Music style)
- **Empty state**: Shows "Not Playing" / "No Artist" with placeholder artwork
- **Buttons**: Always interactive-looking but disabled when no track
- **Actions**: `.disabled()` prevents action + haptic feedback when no track
- **Morphing**: Zoom transition to Now Playing sheet (existing implementation preserved)

### ✅ Home Tab
- **Position**: First tab (leftmost)
- **Content**: Placeholder with "Recently Played" and "Most Listened" sections
- **Navigation**: Standard NavigationStack with title "Home"
- **Future-ready**: Easy to hook up real data later

---

## iOS 26 APIs Used [Verified-Apple]

| API | Platform | Purpose |
|-----|----------|---------|
| `Tab(..., role: .search)` | iOS 18.0+ | Creates floating search tab on right side |
| `.searchable(text:placement:)` | iOS 26.0+ | Large glass search field with keyboard |
| `.tabViewSearchActivation(.searchTabSelection)` | iOS 26.0+ | Tap-to-keyboard + cancel-to-previous-tab |
| `.tabViewBottomAccessory` | iOS 26.0+ | Places mini player above tab bar |
| `.tabBarMinimizeBehavior(.onScrollDown)` | iOS 26.0+ | Dynamic tab bar shrinking on scroll |

**Note**: All APIs work perfectly in iOS 26.0 target (no backwards compatibility needed per project requirements).

---

## Testing Checklist

### Tab Bar Tests
- [ ] 4 tabs visible in tab bar
- [ ] Home, Library, Settings appear on left side (grouped)
- [ ] Search appears as floating magnifying glass icon on right side
- [ ] Tapping each tab navigates correctly
- [ ] Tab bar shrinks when scrolling down content in any tab
- [ ] Tab bar expands when scrolling up or tapping tab bar area
- [ ] Modern bubble-style tab icons (iOS 26 Liquid Glass)

### Search Experience Tests (Apple Music Style)
- [ ] First tap on search bubble opens SearchView
- [ ] Large glass search field visible when search view opens
- [ ] Second tap on search bubble activates keyboard
- [ ] Search field shows "Search Library" placeholder text
- [ ] Typing in search field shows results from local music library
- [ ] Search returns tracks, albums, artists, and playlists correctly
- [ ] Cancel button dismisses keyboard and search view
- [ ] After cancel, returns to previously active tab (Home/Library/Settings)
- [ ] Search state persists across tab switches
- [ ] Recent searches still work (existing functionality)

### Mini Player Tests
- [ ] Mini player visible at app launch (empty library)
- [ ] Shows "Not Playing" text when no track
- [ ] Shows "No Artist" text when no track
- [ ] Album artwork shows placeholder (gray gradient with music note icon)
- [ ] Play/pause button visible and looks interactive
- [ ] Next button visible and looks interactive
- [ ] Buttons show disabled styling (.opacity 0.4) when no track
- [ ] Tapping buttons when disabled = no action, no haptic feedback
- [ ] Import a track → mini player updates with real data
- [ ] Play a track → buttons become enabled and functional
- [ ] Tapping mini player opens Now Playing sheet with zoom morph

### Home Tab Tests
- [ ] Home tab appears first (leftmost position)
- [ ] Home tab icon is "house" symbol
- [ ] Tapping Home tab shows navigation title "Home"
- [ ] "Recently Played" section header visible
- [ ] "Most Listened" section header visible
- [ ] Both sections show "No tracks yet" placeholder
- [ ] Scrolling works correctly in Home view
- [ ] Tab bar minimizes when scrolling down Home content

---

## Implementation Notes

### Build Process
1. **Phase 1**: Create HomeView.swift (build should pass)
2. **Phase 2**: Update ContentView.swift TabView block (build will fail - SearchView needs text binding)
3. **Phase 3**: Update SearchView.swift to accept text binding (build should pass)
4. **Verification**: Run `make build` to verify all phases complete

### Potential Issues

**Issue 1**: HomeView not found during ContentView compilation
- **Cause**: File not added to Xcode target
- **Fix**: Ensure HomeView.swift has "Fonic HiFi" target membership checked

**Issue 2**: SearchView initializer error after Phase 2
- **Expected**: Build will fail after Phase 2 until Phase 3 complete
- **Reason**: SearchView needs text binding parameter added
- **Fix**: Complete Phase 3 to add text binding to SearchView

**Issue 3**: Tab bar doesn't show floating search
- **Cause**: `role: .search` parameter might be missing or incorrect
- **Fix**: Verify exact syntax: `Tab("Search", systemImage: "magnifyingglass", role: .search)`

**Issue 4**: Keyboard doesn't appear on second tap
- **Cause**: `.tabViewSearchActivation()` modifier missing or incorrect
- **Fix**: Verify exact syntax: `.tabViewSearchActivation(.searchTabSelection)`

### Git Commit Strategy
**Recommended**: Single atomic commit after all 3 phases complete and verified

**Commit message:**
```
Add iOS 26 tab bar redesign with Apple Music-style search

- Add HomeView with placeholder sections for Recently Played/Most Listened
- Migrate ContentView to modern Tab() syntax with role: .search
- Implement TabView-level search for local music library
- Add .tabViewSearchActivation for tap-to-keyboard behavior
- Mini player now always visible (empty library state supported)
- SearchView refactored to accept search text via binding
- Tab bar matches Apple Music iOS 26 design pattern

Local library search only - no Apple Music scope placeholders

Refs: sample/AppleMusicBottomBar, Codex guidance, plan2/tab.md
```

---

## Architecture Decision: Why TabView-Level Search?

**Previous Approach (SearchView-owned state)**:
- SearchView controlled its own `@State private var searchText`
- `.searchable()` modifier on SearchView
- No tap-to-reactivate-keyboard behavior

**New Approach (TabView-owned state)** [Codex Recommendation]:
- ContentView controls `@State private var searchText`
- `.searchable()` and `.tabViewSearchActivation()` modifiers on TabView
- Text binding passed down to SearchView
- Creates Apple Music-style search experience

**Benefits**:
1. **Keyboard reactivation**: Second tap on search bubble brings keyboard back
2. **Cancel behavior**: Canceling search returns to previous tab (not stuck in search)
3. **State persistence**: Search text persists across tab switches
4. **Clean architecture**: Local library search only, no fake scopes

**Trade-offs**:
- SearchView less self-contained (requires text binding from parent)
- ContentView manages search state for child
- Better UX, slightly more coupling

**Codex's rationale**: "To mirror Apple Music's search flow, wire the search tab into SwiftUI's new search-handling APIs at the TabView level."

---

## Reference Materials

### Sample Code
- `sample/AppleMusicBottomBar/AppleMusicBottomBar/ContentView.swift` - Tab bar implementation
- `sample/AppleMusicMiniPlayer/AppleMusicMiniPlayer/View/ExpandableMusicPlayer.swift` - Mini player patterns

### Documentation
- Apple Documentation: TabRole.search (iOS 18.0+)
- Apple Documentation: tabViewSearchActivation (iOS 26.0+)
- Apple Documentation: searchScopes (iOS 26.0+)
- Apple Documentation: tabViewBottomAccessory (iOS 26.0+)
- iOS 26 Design Guidelines: Liquid Glass tab bars

### Related Plans
- `Plan/Sheet.md` - Now Playing sheet implementation (already done)
- `plan2/liquid.md` - Liquid Glass migration (completed 2025-09-30)

---

## Future Enhancements (Not in This Plan)

### Home Tab Data Integration
- Hook up actual "Recently Played" track list from SwiftData
- Hook up actual "Most Listened" track list from SwiftData
- Add horizontal scrolling track carousels
- Add album artwork for recent tracks
- Add play buttons for quick playback

### Apple Music Integration (Future Feature)
- Implement Apple Music API search via MusicKit
- Add search scope picker when implemented
- Add streaming capability
- Handle authentication and subscription checks
- Merge Apple Music results with local library

### Mini Player Improvements
- Add waveform visualization when track playing
- Add scrubbing gesture support
- Add previous track button
- Add shuffle/repeat state indicators

### Tab Bar Customization
- Allow user to reorder tabs (iOS 26 `.tabViewCustomization`)
- Allow user to hide/show tabs
- Persist tab customization with @AppStorage

---

**End of Plan** - Ready for implementation with codex's verified approach