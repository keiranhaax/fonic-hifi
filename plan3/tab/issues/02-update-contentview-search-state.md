# Step 02: Add Search Text State to ContentView

**Priority:** Implementation Step 2A (Required before Step 2B)
**File:** `Fonic HiFi/ContentView.swift`
**Action:** Add search text state property at ContentView level
**Lines:** +1 line (after line 18)
**Impact:** Enables search text to persist across tab switches
**Risk:** LOW (single line addition, no side effects)

## Current State

**File:** `Fonic HiFi/ContentView.swift:16-18`

**Current state block:**
```swift
@Namespace private var miniPlayerNamespace
@State private var showingNowPlaying = false
@State private var selectedDetent: PresentationDetent = .medium
```

**Problem:**
- ❌ No search text state at ContentView level
- ❌ Search state currently managed locally in SearchView (will be changed in Step 05)
- ❌ Search text doesn't persist when switching tabs

## Target State

**File:** `Fonic HiFi/ContentView.swift:16-19`

**New state block:**
```swift
@Namespace private var miniPlayerNamespace
@State private var showingNowPlaying = false
@State private var selectedDetent: PresentationDetent = .medium
@State private var searchText = ""  // ← ADD THIS LINE
```

**Benefits:**
- ✅ Search text managed at parent level (ContentView)
- ✅ State persists across tab switches
- ✅ Can be passed as binding to SearchView
- ✅ Matches sample code pattern [Verified-Code: sample/AppleMusicBottomBar/ContentView.swift:11]

## Solution

### Edit ContentView.swift

**Location:** After line 18

**Add this line:**
```swift
@State private var searchText = ""
```

**Complete updated state block:**
```swift
@Namespace private var miniPlayerNamespace
@State private var showingNowPlaying = false
@State private var selectedDetent: PresentationDetent = .medium
@State private var searchText = ""
```

## Dependencies

- **Blocks:** Step 2B (Replace TabView block - needs this state)
- **Blocked by:** None - can start immediately after Step 1
- **Requires:** Step 1 (HomeView) should be complete first (recommended)

## Time Estimate

- Implementation: 2-5 minutes
- Testing: 1-2 minutes
- **Total:** 3-7 minutes

## Risk Assessment

- **LOW**: Single line addition, no impact on existing code
- **No build breaks**: File will compile with this change
- **No runtime impact**: State is created but not used yet (will be used in Step 2B)
- **Easy rollback**: Simply delete the added line

## Success Criteria

- [ ] Line added after line 18 in ContentView.swift
- [ ] Exact text: `@State private var searchText = ""`
- [ ] Build passes: `make build`
- [ ] No compiler errors
- [ ] No compiler warnings for unused variable (will be used in Step 2B)

## Testing Procedure

### Build Verification
```bash
# Build project
make build

# Verify no errors
echo $?  # Should be 0

# Check for compiler warnings (expected: unused variable warning until Step 2B)
make lint
```

### Code Verification
```bash
# Verify line was added correctly
grep -n "searchText" "Fonic HiFi/ContentView.swift"

# Should show new line with @State private var searchText = ""
```

## Rollback Procedure

```bash
# Edit ContentView.swift and remove the added line
# OR use git if you haven't committed yet:
git diff "Fonic HiFi/ContentView.swift"  # Verify only searchText line changed
git checkout HEAD -- "Fonic HiFi/ContentView.swift"  # Restore original

# Verify build still passes
make build
```

**Rollback Time:** ~10 seconds

## Implementation Checklist

### Phase 1: Edit File
- [ ] Open `Fonic HiFi/ContentView.swift` in editor
- [ ] Locate line 18: `@State private var selectedDetent: PresentationDetent = .medium`
- [ ] Position cursor at end of line 18
- [ ] Press Enter to create new line
- [ ] Type: `@State private var searchText = ""`
- [ ] Verify indentation matches surrounding lines

### Phase 2: Verify Syntax
- [ ] Check syntax highlighting is correct
- [ ] Verify no red error indicators in editor
- [ ] Save file (Cmd+S)

### Phase 3: Build Verification
- [ ] Run `make build`
- [ ] Verify exit code is 0 (success)
- [ ] ⚠️ Compiler may warn about unused variable (this is EXPECTED)
- [ ] Unused warning will disappear after Step 2B

### Phase 4: Documentation
- [ ] Update `plan3/tab/tab.md` progress
- [ ] Mark Step 02 as complete
- [ ] Note: Variable is unused until Step 2B (this is expected)

## Related Steps

- **Previous Step:** `issues/01-create-homeview.md` (should be complete)
- **Next Step:** `issues/03-replace-tabview-block.md` (REQUIRES this step)
- **Dependent Steps:** Step 05 (SearchView refactor) will consume this binding

## Pattern Verification

**Matches Sample Code** [Verified-Code]:

`sample/AppleMusicBottomBar/AppleMusicBottomBar/ContentView.swift:11`
```swift
@State private var searchText = ""  // ✅ Exact same pattern
```

**Why at ContentView level?**
1. **State persistence**: Search text persists across tab switches
2. **Parent controls children**: ContentView passes binding to SearchView
3. **Single source of truth**: One state, multiple consumers
4. **Apple Music pattern**: Verified working implementation

**Alternative considered:**
- SearchView owns state ❌ - Loses state on tab switch
- AppStorage ❌ - Persists across app launches (not desired)
- ObservableObject ❌ - Overkill for single String property

## Expected Compiler Behavior

### After Step 2A (This Step)
```
⚠️ Warning: Variable 'searchText' was never mutated; consider changing to 'let' constant
⚠️ Warning: Immutable value 'searchText' was never used
```

**This is EXPECTED** - Variable will be used in Step 2B

### After Step 2B (Next Step)
```
✅ No warnings - searchText will be passed to SearchView as binding
```

---

**Status:** Ready for implementation
**Next:** Proceed to Step 03 (Replace TabView block) immediately after completing this step
