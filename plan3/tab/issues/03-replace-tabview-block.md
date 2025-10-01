# Step 03: Replace TabView Block with Modern Tab() Syntax

**Priority:** Implementation Step 2B (Critical - Breaks build until Step 05 complete)
**File:** `Fonic HiFi/ContentView.swift`
**Action:** Replace old `.tabItem` syntax with modern `Tab()` syntax
**Lines:** Lines 21-40 (~20 line replacement)
**Impact:** 4 tabs (Home, Library, Settings, Search), floating search bubble, dynamic tab bar
**Risk:** HIGH (Build will fail until Step 05 complete)

## Current State [Verified-Code]

**File:** `Fonic HiFi/ContentView.swift:21-40`

**Current TabView block (TO REMOVE):**
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

**Problems:**
- ❌ Uses deprecated `.tabItem` syntax (iOS 13-17 pattern)
- ❌ No Home tab (required for Phase 1)
- ❌ Search is standard tab, not floating bubble
- ✅ `.tabBarMinimizeBehavior(.onScrollDown)` already exists (ContentView.swift:42)
- ❌ Search state managed in SearchView (should use ContentView binding)

## Target State [Verified-Code: sample/AppleMusicBottomBar]

**File:** `Fonic HiFi/ContentView.swift:21-42`

**New TabView block (TO ADD):**
```swift
TabView {
    Tab("Home", systemImage: "house.fill") {
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
        NavigationStack {
            SearchView(searchText: $searchText)
                .searchable(text: $searchText, placement: .toolbar, prompt: Text("Search Library"))
                .environment(\.showingNowPlaying, $showingNowPlaying)
                .environment(\.audioEngine, audioService)
                .environment(\.importService, importService)
        }
    }
}
.tabBarMinimizeBehavior(.onScrollDown)
```

**Benefits:**
- ✅ Modern `Tab()` syntax (iOS 18.0+)
- ✅ Home tab first position with `house.fill` icon
- ✅ Search tab uses `role: .search` for floating bubble
- ✅ NavigationStack wrapper around SearchView (required for `.searchable()`)
- ✅ `.searchable()` modifier inside Tab content (matches sample)
- ✅ Search text binding from ContentView (Step 02)
- ✅ Preserves `.tabBarMinimizeBehavior(.onScrollDown)` (already exists at ContentView.swift:42)

## Solution

### Complete Replacement Code

**Location:** Replace lines 21-40 in ContentView.swift

**Remove old code, add new code:**
```swift
TabView {
    Tab("Home", systemImage: "house.fill") {
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
        NavigationStack {
            SearchView(searchText: $searchText)
                .searchable(text: $searchText, placement: .toolbar, prompt: Text("Search Library"))
                .environment(\.showingNowPlaying, $showingNowPlaying)
                .environment(\.audioEngine, audioService)
                .environment(\.importService, importService)
        }
    }
}
.tabBarMinimizeBehavior(.onScrollDown)
```

## Dependencies

- **Blocks:** Step 05 (SearchView refactor) - BUILD WILL FAIL until complete
- **Blocked by:** Step 02 (Add searchText state) - MUST be done first
- **Requires:** Step 01 (HomeView.swift exists) - Referenced in code

## Time Estimate

- Implementation: 30-45 minutes
- Testing: 10-15 minutes (after Step 05 complete)
- **Total:** 40-60 minutes (including Step 05 coordination)

## Risk Assessment

- **HIGH**: Build will fail after this step until Step 05 complete
- **Build error**: `SearchView` initializer will fail (needs `searchText` binding parameter)
- **Coordination**: Must complete Step 05 within same session
- **Rollback**: Requires restoring old TabView block

## Expected Build Failure

### After This Step (Before Step 05)

**Compiler Error:**
```
❌ Missing argument for parameter 'searchText' in call
   SearchView(searchText: $searchText)
   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Note: 'SearchView' expects no parameters
      struct SearchView: View { ... }
```

**This is EXPECTED** - SearchView doesn't have `searchText` parameter yet (will be added in Step 05)

### After Step 05 (Complete)

```
✅ Build Succeeded
```

## Success Criteria

- [ ] Old TabView block removed (lines 21-40)
- [ ] New TabView block added with 4 tabs
- [ ] Home tab first position with `house.fill` icon
- [ ] Search tab has `role: .search` parameter
- [ ] NavigationStack wraps SearchView
- [ ] `.searchable()` modifier inside Tab content
- [ ] `.tabBarMinimizeBehavior(.onScrollDown)` applied to TabView
- [ ] ⚠️ Build will FAIL (expected until Step 05 complete)

## Testing Procedure

### Build Verification (After Step 05 Complete)
```bash
# Build project (will fail until Step 05 complete)
make build

# After Step 05:
make build  # Should succeed

# Verify exit code
echo $?  # Should be 0
```

### Manual Testing (After Step 05 Complete)
1. Run app in simulator: `make run`
2. Verify 4 tabs appear in tab bar
3. Check tab order: Home, Library, Settings, Search
4. Verify Search appears as floating bubble on right
5. Tap each tab and verify navigation works
6. Scroll down in any tab and verify tab bar shrinks
7. Scroll up and verify tab bar expands

### Visual Testing
- [ ] Tab bar shows 4 tabs
- [ ] Home, Library, Settings grouped on left
- [ ] Search appears as floating bubble on right
- [ ] Tab icons match: house.fill, music.note.list, gear, magnifyingglass
- [ ] Tab bar has iOS 26 Liquid Glass bubble styling

## Rollback Procedure

**Manual Rollback:**
```swift
// Restore old TabView block (lines 21-40)
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

**Git Rollback:**
```bash
# If you haven't committed yet:
git diff "Fonic HiFi/ContentView.swift"  # Review changes
git checkout HEAD -- "Fonic HiFi/ContentView.swift"  # Restore original

# Verify build passes
make build
```

**Rollback Time:** ~1-2 minutes

## Implementation Checklist

### Phase 1: Locate Code
- [ ] Open `Fonic HiFi/ContentView.swift` in editor
- [ ] Locate line 21: Start of `TabView {`
- [ ] Locate line 40: End of TabView closing brace
- [ ] Select entire TabView block (lines 21-40)

### Phase 2: Replace Code
- [ ] Delete selected TabView block
- [ ] Paste new TabView code from Solution above
- [ ] Verify indentation matches surrounding code
- [ ] Save file (Cmd+S)

### Phase 3: Verify Syntax
- [ ] Check syntax highlighting is correct
- [ ] Verify all braces are balanced
- [ ] Check environment modifiers are correct
- [ ] Verify `$searchText` binding syntax (dollar sign)

### Phase 4: Attempt Build (WILL FAIL)
- [ ] Run `make build`
- [ ] ⚠️ **EXPECTED ERROR**: `Missing argument for parameter 'searchText' in call`
- [ ] Note error message (confirms SearchView needs update)
- [ ] Proceed immediately to Step 05

### Phase 5: Documentation
- [ ] Update `plan3/tab/tab.md` progress
- [ ] Mark Step 03 as complete
- [ ] Note: Build is broken until Step 05 (this is expected)
- [ ] Add timestamp for coordination with Step 05

## Critical Notes

### 🚨 Build Coordination

**This step BREAKS THE BUILD intentionally**

- Build will fail after this step
- Error is expected: SearchView needs `searchText` binding parameter
- **Do NOT attempt to fix error here** - proceed to Step 05 immediately
- Estimated time between Step 03 and Step 05: 5-10 minutes

### Coordination with Step 05

**Workflow:**
1. Complete Step 03 (this step) - Build fails ⚠️
2. Immediately start Step 05 - Add searchText binding to SearchView
3. Complete Step 05 - Build succeeds ✅

**Session Planning:**
- Reserve 45-60 minutes for Steps 03 + 05 together
- Do not start Step 03 unless you can complete Step 05 in same session
- Have Step 05 documentation ready before starting this step

## Related Steps

- **Previous Step:** `issues/02-update-contentview-search-state.md` (MUST be complete)
- **Next Step:** `issues/05-refactor-searchview-binding.md` (MUST do immediately)
- **Parallel Step:** `issues/04-fix-mini-player-zoom.md` (can be done anytime)

## Pattern Verification

**Matches Sample Code** [Verified-Code]:

`sample/AppleMusicBottomBar/AppleMusicBottomBar/ContentView.swift:135-144`
```swift
Tab("Search", systemImage: "magnifyingglass", role: .search) {
    NavigationStack {
        List {}
            .searchable(text: $searchText, placement: .toolbar)
    }
}
```

**Key Differences from Sample:**
- Sample uses `List {}` placeholder
- Fonic HiFi uses `SearchView(searchText: $searchText)` with real implementation
- Both use `NavigationStack` wrapper ✅
- Both have `.searchable()` inside Tab content ✅
- Both use `role: .search` for floating bubble ✅

**What NOT to do (original plan was wrong):**
- ❌ Do NOT use `.tabViewSearchActivation()` (sample doesn't use it)
- ❌ Do NOT put `.searchable()` on TabView (goes inside Tab content)
- ❌ Do NOT forget NavigationStack wrapper (required for search field)

---

**Status:** Ready for implementation (Coordinate with Step 05)
**Next:** IMMEDIATELY proceed to Step 05 after completing this step (build will be broken)
