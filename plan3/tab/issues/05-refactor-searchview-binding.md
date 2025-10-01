# Step 05: Refactor SearchView to Accept Text Binding

**Priority:** Implementation Step 3 (Critical - Unblocks build after Step 03)
**File:** `Fonic HiFi/Presentation/Views/Search/SearchView.swift`
**Action:** Accept search text as binding, remove local state and `.searchable()` modifier
**Lines:** 3 changes (1 addition, 2 deletions)
**Impact:** Search text managed by ContentView, persists across tab switches
**Risk:** MEDIUM (Fixes build break from Step 03)

## Current State [Verified-Code]

**File:** `Fonic HiFi/Presentation/Views/Search/SearchView.swift`

**Current struct declaration (Line 13):**
```swift
struct SearchView: View {
```

**Current local search state (Line 15):**
```swift
@State private var searchText = ""
```

**Current .searchable modifier (Lines 56-60):**
```swift
.searchable(
    text: $searchText,
    placement: .toolbar,
    prompt: Text("Search your library"),
)
```

**Problems:**
- ❌ SearchView owns search state (should be ContentView-level)
- ❌ `.searchable()` owned by SearchView (should be in Tab content)
- ❌ Search text doesn't persist when switching tabs
- ❌ Doesn't accept binding from ContentView (Step 03 expects this)
- ❌ Build FAILS after Step 03 until this step is complete

## Target State [Verified-Code: sample pattern]

**File:** `Fonic HiFi/Presentation/Views/Search/SearchView.swift`

**New struct declaration (Line 13):**
```swift
struct SearchView: View {
    @Binding var searchText: String  // ← ADD THIS
```

**Remove local state (Line 15):**
```swift
// DELETE THIS LINE:
@State private var searchText = ""
```

**Remove .searchable modifier (Lines 56-60):**
```swift
// DELETE THESE LINES:
.searchable(
    text: $searchText,
    placement: .toolbar,
    prompt: Text("Search your library"),
)
```

**Benefits:**
- ✅ Search text managed by ContentView (parent controls state)
- ✅ State persists across tab switches
- ✅ `.searchable()` owned by Tab content (matches sample pattern)
- ✅ Build succeeds (fixes error from Step 03)
- ✅ Matches verified pattern from sample code

## Solution

### Change 1: Add Binding Parameter (Line 13)

**Location:** After `struct SearchView: View {`

**Before:**
```swift
struct SearchView: View {
    @Environment(\.dataManager) private var dataManager
```

**After:**
```swift
struct SearchView: View {
    @Binding var searchText: String
    @Environment(\.dataManager) private var dataManager
```

### Change 2: Remove Local State (Line 15)

**Location:** Remove line 15

**Before:**
```swift
struct SearchView: View {
    @Binding var searchText: String
    @Environment(\.dataManager) private var dataManager
    @State private var searchText = ""  // ← DELETE THIS LINE
    @State private var searchResults: SearchResults? = nil
```

**After:**
```swift
struct SearchView: View {
    @Binding var searchText: String
    @Environment(\.dataManager) private var dataManager
    @State private var searchResults: SearchResults? = nil
```

### Change 3: Remove NavigationStack Wrapper (Lines 23-55)

**Location:** SearchView body currently wraps content in NavigationStack

**Before:**
```swift
var body: some View {
    NavigationStack {
        Group {
            // search results content
        }
        .navigationTitle("Search")
    }
    .searchable(...)
}
```

**After:**
```swift
var body: some View {
    Group {
        // search results content
    }
    .navigationTitle("Search")
    .onChange(of: searchText) { oldValue, newValue in
        // ... search logic
    }
}
```

**Note:** NavigationStack will be moved to ContentView Tab content (Step 03), not removed entirely

### Change 4: Remove .searchable Modifier (Lines 56-60)

**Location:** Find and remove entire `.searchable()` modifier block

**Before:**
```swift
// ... view content
.searchable(
    text: $searchText,
    placement: .toolbar,
    prompt: Text("Search your library"),
)
.onChange(of: searchText) { oldValue, newValue in
    // ... search logic
}
```

**After:**
```swift
// ... view content
.onChange(of: searchText) { oldValue, newValue in
    // ... search logic
}
```

**Note:** `.searchable()` will be moved to ContentView Tab content (Step 03), not removed entirely

## Dependencies

- **Blocks:** Build success - CRITICAL FIX
- **Blocked by:** Step 03 (ContentView TabView replacement) - MUST be done first
- **Requires:** Step 02 (ContentView search text state) - Already in place

## Time Estimate

- Implementation: 20-25 minutes (4 changes)
- Testing: 5-10 minutes
- **Total:** 25-35 minutes

## Risk Assessment

- **MEDIUM**: Fixes build break from Step 03 (critical)
- **Build dependency**: Must be done immediately after Step 03
- **Search functionality**: Must verify `.onChange` still works correctly
- **Easy rollback**: Restore local state and `.searchable()` modifier

## Expected Build Behavior

### Before This Step (After Step 03)

**Compiler Error:**
```
❌ Missing argument for parameter 'searchText' in call
   SearchView(searchText: $searchText)
   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Note: 'SearchView' expects no parameters
      struct SearchView: View { ... }
```

### After This Step

```
✅ Build Succeeded
```

## Success Criteria

- [ ] `@Binding var searchText: String` added to struct
- [ ] Local `@State private var searchText` removed
- [ ] `.searchable()` modifier removed (lines 56-60)
- [ ] `.onChange(of: searchText)` modifier remains
- [ ] Build passes: `make build`
- [ ] Search functionality works correctly
- [ ] Search text persists across tab switches

## Testing Procedure

### Build Verification
```bash
# Build project (should succeed after this step)
make build

# Verify exit code
echo $?  # Should be 0

# Run lint
make lint  # Should have no errors
```

### Functionality Testing
```bash
# Run app in simulator
make run

# Manual testing:
# 1. Tap Search tab
# 2. Tap search field
# 3. Type "test"
# 4. Verify search results appear
# 5. Switch to Library tab
# 6. Switch back to Search tab
# 7. Verify search text still shows "test" (persisted)
```

### Search Functionality Checklist
- [ ] Tapping search tab opens SearchView
- [ ] Search field appears in toolbar/navigation bar
- [ ] Tapping search field activates keyboard
- [ ] Typing triggers search results
- [ ] Search returns tracks/albums/artists/playlists
- [ ] Switching tabs preserves search text
- [ ] Returning to search tab shows previous results
- [ ] Recent searches still work (existing functionality)

## Rollback Procedure

**Manual Rollback:**
```swift
// Restore struct declaration (remove binding)
struct SearchView: View {
    @Environment(\.dataManager) private var dataManager
    // ... other properties

// Restore local state (add back)
@State private var searchText = ""

// Restore .searchable modifier (add back)
.searchable(
    text: $searchText,
    placement: .toolbar,
    prompt: Text("Search your library"),
)
```

**Git Rollback:**
```bash
# Restore original file
git checkout HEAD -- "Fonic HiFi/Presentation/Views/Search/SearchView.swift"

# Verify file restored
cat "Fonic HiFi/Presentation/Views/Search/SearchView.swift" | grep "searchText"
```

**Rollback Time:** ~1-2 minutes

## Implementation Checklist

### Phase 1: Add Binding Parameter
- [ ] Open `Fonic HiFi/Presentation/Views/Search/SearchView.swift`
- [ ] Locate line 13: `struct SearchView: View {`
- [ ] Position cursor after opening brace, press Enter
- [ ] Type: `@Binding var searchText: String`
- [ ] Verify indentation matches other properties

### Phase 2: Remove Local State
- [ ] Locate line with `@State private var searchText = ""`
- [ ] Select entire line
- [ ] Delete line (Cmd+Delete or Backspace)
- [ ] Verify no duplicate searchText properties remain

### Phase 3: Remove .searchable Modifier
- [ ] Search file for `.searchable(`
- [ ] Locate entire modifier block (lines 56-60)
- [ ] Select all 5 lines (opening line + 4 parameter lines)
- [ ] Delete selected lines
- [ ] Verify `.onChange(of: searchText)` remains after deletion

### Phase 4: Verify Syntax
- [ ] Check syntax highlighting is correct
- [ ] Verify no red error indicators
- [ ] Check all uses of `searchText` still work
- [ ] Save file (Cmd+S)

### Phase 5: Build Verification
- [ ] Run `make build`
- [ ] Verify exit code is 0 (success)
- [ ] ✅ **BUILD SHOULD SUCCEED** (fixes Step 03 error)
- [ ] Check for any compiler warnings

### Phase 6: Functionality Testing
- [ ] Run app: `make run`
- [ ] Test search functionality (see checklist above)
- [ ] Verify search text persists across tab switches
- [ ] Test recent searches still work

### Phase 7: Documentation
- [ ] Update `plan3/tab/tab.md` progress
- [ ] Mark Step 05 as complete
- [ ] Note: Build is now passing (all steps complete)
- [ ] Document any issues encountered

## Critical Notes

### 🚨 Build Coordination with Step 03

**This step FIXES THE BUILD broken by Step 03**

- Step 03 breaks build intentionally
- This step (Step 05) fixes the build
- **Do these steps in same session** (15-60 min total)

**Workflow:**
1. Complete Step 03 - Build fails ⚠️
2. **Immediately** start Step 05 (this step)
3. Complete Step 05 - Build succeeds ✅

### Verification Points

**After adding binding parameter:**
- SearchView now requires `searchText` parameter in initializer ✅
- ContentView passes `$searchText` binding (Step 03) ✅
- State lives at ContentView level ✅

**After removing local state:**
- No duplicate `searchText` properties ✅
- SearchView uses binding from parent ✅

**After removing .searchable:**
- Tab content owns `.searchable()` (Step 03) ✅
- SearchView receives search text via binding ✅
- Search field still appears in toolbar ✅

## Related Steps

- **Previous Step:** `issues/03-replace-tabview-block.md` (MUST be complete first)
- **Parallel Step:** `issues/04-fix-mini-player-zoom.md` (can be done anytime)
- **Next Step:** Testing and verification (all steps complete)

## Pattern Verification

**Matches Sample Code Pattern** [Verified-Code]:

`sample/AppleMusicBottomBar/ContentView.swift:11`
```swift
@State private var searchText = ""  // At ContentView level
```

`sample/AppleMusicBottomBar/ContentView.swift:141`
```swift
.searchable(text: $searchText, placement: .toolbar)  // In Tab content
```

**Pattern:**
1. Parent (ContentView) owns state
2. `.searchable()` in Tab content controls search field
3. Child view (SearchView) receives binding
4. `.onChange()` in child reacts to text changes

**Our Implementation:**
```swift
// ContentView.swift (Step 02)
@State private var searchText = ""

// ContentView.swift (Step 03)
Tab("Search", ..., role: .search) {
    NavigationStack {
        SearchView(searchText: $searchText)
            .searchable(text: $searchText, ...)  // ✅ Tab owns .searchable
    }
}

// SearchView.swift (Step 05 - this step)
struct SearchView: View {
    @Binding var searchText: String  // ✅ Receives binding

    var body: some View {
        // ...
        .onChange(of: searchText) { _, newValue in  // ✅ Reacts to changes
            searchAllContent()
        }
    }
}
```

## Why This Pattern Works

### Benefits of Parent-Owned State

1. **State Persistence**: Search text persists when switching tabs
2. **Single Source of Truth**: One state, multiple consumers
3. **Predictable Flow**: Parent controls state, children react
4. **Testability**: Easier to test with controlled state

### Benefits of Tab-Owned .searchable

1. **iOS 26 Pattern**: Matches modern Tab() API design
2. **Search Field Placement**: Automatically appears in toolbar
3. **Keyboard Management**: System handles keyboard presentation
4. **Cancel Button**: System provides cancel functionality

### Alternative Considered (Rejected)

**SearchView owns state + .searchable:**
- ❌ Search text lost when switching tabs
- ❌ Parent can't control search state
- ❌ Doesn't match sample code pattern
- ❌ Not compatible with `Tab(role: .search)` architecture

---

**Status:** Ready for implementation (CRITICAL - Unblocks build from Step 03)
**Next:** Complete immediately after Step 03 to fix build break
