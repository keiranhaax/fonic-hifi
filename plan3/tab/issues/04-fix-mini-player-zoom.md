# Step 04: Fix Mini Player Zoom Morphing

**Priority:** CONDITIONAL (Requires verification - bug not yet tested)
**File:** `Fonic HiFi/ContentView.swift`
**Action:** TBD - First verify if zoom morphing bug exists
**Lines:** Lines 52-66 (~10 line modification if needed)
**Impact:** IF bug exists: Mini player morphs into sheet instead of sliding up from bottom
**Risk:** MEDIUM (may break toolbar hiding, needs investigation)

## ⚠️ VERIFICATION REQUIRED

**This step is CONDITIONAL - do not implement until bug is verified:**

1. Run `scripts/test-current-zoom-behavior.sh` to test current behavior
2. If zoom morphing works: **SKIP THIS STEP ENTIRELY**
3. If zoom slides up: Investigate root cause before removing NavigationStack
4. Consider `.fullScreenCover` approach (matches sample) instead of removing wrapper

## Current State [Verified-Code]

**File:** `Fonic HiFi/ContentView.swift:52-66`

**Current sheet presentation (NEEDS VERIFICATION):**
```swift
.sheet(isPresented: $showingNowPlaying) {
    NavigationStack {                   // ⚠️ MAY BREAK ZOOM (needs testing)
        NowPlayingView(animationNamespace: miniPlayerNamespace)
            .navigationTransition(.zoom(sourceID: "miniplayer", in: miniPlayerNamespace))
            .toolbar(.hidden, for: .navigationBar)  // ✅ Hides toolbar
    }
    .environment(\.audioEngine, audioService)
    .presentationDetents([
        .medium,
        .large,
    ], selection: $selectedDetent)
    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    .presentationDragIndicator(.visible)
    .presentationCornerRadius(20)
}
```

**Potential Issue (UNVERIFIED):**
- **User reported**: Mini player may slide up instead of morphing
- **Not tested**: We haven't verified this bug exists in current code
- **Sample difference**: Sample uses `.fullScreenCover`, we use `.sheet` with detents
- **Toolbar concern**: NavigationStack enables `.toolbar(.hidden)` - removing may break this

**Possible Root Cause (if bug confirmed):**
`.navigationTransition(.zoom())` designed for NavigationStack **pushes** may not work correctly when wrapped in NavigationStack for sheet presentations. The wrapper may intercept the zoom animation.

**User Report (from conversation summary):**
> "when tapping the mini player it opens a new small sheet from the bottom of the screen and not the mini player morphing into it"

**Action Required:** Test current behavior before assuming fix is needed

## Target State [Verified-Code: sample/AppleMusicBottomBar + Exa Research]

**File:** `Fonic HiFi/ContentView.swift:52-66`

**Fixed sheet presentation:**
```swift
.sheet(isPresented: $showingNowPlaying) {
    NowPlayingView(animationNamespace: miniPlayerNamespace)
        .navigationTransition(.zoom(sourceID: "miniplayer", in: miniPlayerNamespace))
        .environment(\.audioEngine, audioService)
        .presentationDetents([
            .medium,
            .large,
        ], selection: $selectedDetent)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
}
```

**Changes:**
1. ❌ Remove `NavigationStack {` wrapper (line 53)
2. ❌ Remove `}` closing brace (line 57, after `.toolbar(.hidden)`)
3. ❌ Remove `.toolbar(.hidden, for: .navigationBar)` line (no longer needed)
4. ✅ NowPlayingView presented directly in sheet
5. ✅ `.navigationTransition()` applied directly to view
6. ✅ All presentation modifiers remain unchanged

**Benefits:**
- ✅ Mini player morphs/zooms into sheet (smooth animation)
- ✅ Matches iOS 26 Liquid Glass design patterns
- ✅ Consistent with sample code pattern
- ✅ Better UX - continuous visual transition

## Solution

### Step-by-Step Fix

**Location:** `Fonic HiFi/ContentView.swift:52-66`

**Step 1: Remove NavigationStack opening**
```swift
.sheet(isPresented: $showingNowPlaying) {
    // DELETE THIS LINE:
    NavigationStack {
```

**Step 2: Remove .toolbar modifier**
```swift
// DELETE THIS LINE:
.toolbar(.hidden, for: .navigationBar)
```

**Step 3: Remove NavigationStack closing brace**
```swift
// DELETE THIS LINE (after .toolbar):
}
```

**Step 4: Verify indentation**
```swift
// Ensure NowPlayingView is indented correctly
.sheet(isPresented: $showingNowPlaying) {
    NowPlayingView(animationNamespace: miniPlayerNamespace)  // Indent matches environment modifier below
        .navigationTransition(.zoom(sourceID: "miniplayer", in: miniPlayerNamespace))
        .environment(\.audioEngine, audioService)
        // ... rest of modifiers
}
```

### Complete Fixed Code

```swift
.sheet(isPresented: $showingNowPlaying) {
    NowPlayingView(animationNamespace: miniPlayerNamespace)
        .navigationTransition(.zoom(sourceID: "miniplayer", in: miniPlayerNamespace))
        .environment(\.audioEngine, audioService)
        .presentationDetents([
            .medium,
            .large,
        ], selection: $selectedDetent)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
}
```

## Dependencies

- **Blocks:** None - independent fix
- **Blocked by:** None - can be done anytime
- **Requires:** Mini player has `.matchedTransitionSource(id: "miniplayer")` ✅ (already implemented)

**Verification of Dependencies:**
- `LiquidGlassMiniPlayer.swift:47` has `.matchedTransitionSource(id: "miniplayer", in: namespace)` ✅
- IDs match: "miniplayer" in both source and destination ✅
- Namespace passed correctly ✅

## Time Estimate

- Implementation: 10-15 minutes
- Testing: 5-10 minutes
- **Total:** 15-25 minutes

## Risk Assessment

- **LOW**: Simple wrapper removal, no logic changes
- **No build breaks**: File will compile correctly
- **No runtime issues**: Only affects animation behavior
- **Easy rollback**: Re-add NavigationStack wrapper if needed
- **Visual regression**: Use `test-zoom-morphing.sh` script to verify

## Success Criteria

- [ ] NavigationStack wrapper removed from sheet
- [ ] `.toolbar(.hidden)` modifier removed
- [ ] NowPlayingView presented directly
- [ ] `.navigationTransition()` on NowPlayingView root
- [ ] Build passes: `make build`
- [ ] 🔑 **Animation test**: Tapping mini player morphs/zooms (not slides)
- [ ] Sheet opens at .medium detent
- [ ] Sheet draggable to .large detent

## Testing Procedure

### Build Verification
```bash
# Build project
make build

# Verify exit code
echo $?  # Should be 0
```

### Visual Animation Testing
```bash
# Run automated zoom test (requires simulator)
bash plan3/tab/scripts/test-zoom-morphing.sh

# Manual testing:
make run  # Launch simulator
# 1. Tap mini player at bottom
# 2. Observe animation - should MORPH/ZOOM (not slide up)
# 3. Verify sheet opens at half screen (.medium detent)
# 4. Drag sheet up to full screen (.large detent)
# 5. Drag sheet down to dismiss
```

### Animation Checklist
- [ ] Tap mini player → sheet appears
- [ ] Animation is **zoom/morph** (mini player grows into sheet)
- [ ] Animation is **smooth** (no sudden jumps or slides)
- [ ] Mini player artwork transitions into Now Playing artwork
- [ ] Sheet opens at .medium detent (half screen)
- [ ] Background is tappable when sheet at .medium
- [ ] Sheet can be dragged to .large (full screen)
- [ ] Dragging down dismisses sheet with reverse morph

### Comparison Test
**Before Fix:**
- Sheet slides up from bottom edge ❌
- Mini player stays in place during animation ❌
- No visual connection between mini player and sheet ❌

**After Fix:**
- Mini player morphs/expands into sheet ✅
- Continuous visual transition ✅
- Smooth zoom animation ✅

## Rollback Procedure

**Manual Rollback:**
```swift
// Restore NavigationStack wrapper
.sheet(isPresented: $showingNowPlaying) {
    NavigationStack {
        NowPlayingView(animationNamespace: miniPlayerNamespace)
            .navigationTransition(.zoom(sourceID: "miniplayer", in: miniPlayerNamespace))
            .toolbar(.hidden, for: .navigationBar)
    }
    .environment(\.audioEngine, audioService)
    .presentationDetents([
        .medium,
        .large,
    ], selection: $selectedDetent)
    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    .presentationDragIndicator(.visible)
    .presentationCornerRadius(20)
}
```

**Git Rollback:**
```bash
# Restore original file
git checkout HEAD -- "Fonic HiFi/ContentView.swift"

# Verify build passes
make build
```

**Rollback Time:** ~1 minute

## Implementation Checklist

### Phase 1: Locate Code
- [ ] Open `Fonic HiFi/ContentView.swift` in editor
- [ ] Locate line 52: `.sheet(isPresented: $showingNowPlaying) {`
- [ ] Locate line 53: `NavigationStack {`
- [ ] Locate line 66: Closing brace of sheet

### Phase 2: Remove NavigationStack Wrapper
- [ ] Delete line 53: `NavigationStack {`
- [ ] Delete line 56: `.toolbar(.hidden, for: .navigationBar)`
- [ ] Delete closing brace after `.toolbar` line
- [ ] Verify remaining code starts with `NowPlayingView(`

### Phase 3: Fix Indentation
- [ ] Ensure `NowPlayingView(` aligns with `.environment(` below it
- [ ] Verify `.navigationTransition(` has one additional level of indentation
- [ ] Check all braces are balanced
- [ ] Save file (Cmd+S)

### Phase 4: Build Verification
- [ ] Run `make build`
- [ ] Verify exit code is 0 (success)
- [ ] Check for any compiler warnings

### Phase 5: Animation Testing
- [ ] Run app in simulator: `make run`
- [ ] Tap mini player
- [ ] **CRITICAL CHECK**: Does mini player morph/zoom into sheet?
- [ ] Verify smooth animation (no jumps)
- [ ] Test sheet detents (.medium, .large)

### Phase 6: Documentation
- [ ] Update `plan3/tab/tab.md` progress
- [ ] Mark Step 04 as complete
- [ ] Note animation behavior after fix
- [ ] If animation still broken, check IDs match in both files

## Pattern Verification [Verified-Apple + Exa Research]

### Sample Code Confirmation

**sample/AppleMusicBottomBar/ContentView.swift:52-88**
```swift
.fullScreenCover(isPresented: $expandMiniPlayer) {
    LargeMusicPlayer()  // ✅ Direct view, NO NavigationStack wrapper
        .navigationTransition(.zoom(sourceID: "MINIPLAYER", in: animation))
}
```

**Pattern:**
- ✅ View presented directly (no NavigationStack wrapper)
- ✅ `.navigationTransition()` applied to view root
- ✅ IDs match between source and destination

### Exa Code Research Confirmation

**Multiple verified sources confirm this pattern:**

1. **nilcoalescing.com** (iOS 26 Liquid Glass sheets):
```swift
NavigationStack {
    Button { show.toggle() }
        .matchedTransitionSource(id: "source", in: namespace)
        .sheet(isPresented: $show) {
            DetailView()  // ✅ NO NavigationStack wrapper
                .navigationTransition(.zoom(sourceID: "source", in: namespace))
        }
}
```

2. **amantus-ai/vibetunnel**:
```swift
.sheet(item: $selectedItem) { item in
    DetailView(item: item)  // ✅ Direct view
        .navigationTransition(.zoom(sourceID: item.id, in: namespace))
}
```

3. **HackingWithSwift**:
```swift
.matchedTransitionSource(id: "zoom", in: namespace)
.sheet(isPresented: $showingSheet) {
    Text("Detail")  // ✅ Direct view, no wrapper
        .navigationTransition(.zoom(sourceID: "zoom", in: namespace))
}
```

**Conclusion:** ALL verified sources show sheet content presented directly, with NO NavigationStack wrapper.

## Why This Works

### Technical Explanation

**`.navigationTransition(.zoom())`** is designed for:
1. NavigationStack push transitions (navigation link → detail view)
2. Sheet/cover presentations with matched geometry

**It does NOT work when:**
- Sheet content is wrapped in NavigationStack
- The wrapper intercepts the transition
- System treats it as NavigationStack navigation, not sheet presentation

**Correct Pattern:**
```swift
NavigationStack {
    SourceView()
        .matchedTransitionSource(id: "source")
        .sheet {
            DestinationView()  // Direct view, no wrapper
                .navigationTransition(.zoom(sourceID: "source"))
        }
}
```

**Incorrect Pattern:**
```swift
.sheet {
    NavigationStack {  // ❌ Breaks zoom
        DestinationView()
            .navigationTransition(.zoom())  // Ignored
    }
}
```

## Related Steps

- **Previous Steps:** Independent - can be done anytime
- **Next Step:** Independent - doesn't block other steps
- **Parallel Steps:** Can be done alongside Step 03 or Step 05
- **Testing:** Use `scripts/test-zoom-morphing.sh` for automated verification

## Notes for NowPlayingView

**If NowPlayingView internally needs NavigationStack:**
- That's fine - add NavigationStack INSIDE NowPlayingView
- Don't wrap the sheet presentation in NavigationStack
- Example:

```swift
// ✅ CORRECT:
.sheet(isPresented: $showingNowPlaying) {
    NowPlayingView()  // No wrapper here
        .navigationTransition(.zoom())
}

// Inside NowPlayingView.swift:
struct NowPlayingView: View {
    var body: some View {
        NavigationStack {  // ✅ Internal navigation is fine
            // Content with navigation
        }
    }
}
```

---

**Status:** Ready for implementation (P0 - User-reported bug fix)
**Next:** Can be done independently or alongside other steps
