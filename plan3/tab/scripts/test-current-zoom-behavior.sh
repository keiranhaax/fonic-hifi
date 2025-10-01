#!/bin/bash
set -e

echo "🧪 Mini Player Zoom Behavior Verification"
echo "=========================================="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
pass() { echo -e "${GREEN}✅ $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

echo ""
warn "IMPORTANT: This script verifies if Step 04 is needed"
echo ""
echo "This script will:"
echo "  1. Analyze current ContentView.swift sheet implementation"
echo "  2. Provide interactive testing instructions"
echo "  3. Determine if Step 04 (mini player zoom fix) should be implemented"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check current implementation
info "Analyzing current ContentView.swift implementation..."
echo ""

# Check if NavigationStack wrapper exists in sheet
SHEET_LINE=$(grep -n '.sheet(isPresented: \$showingNowPlaying)' "Fonic HiFi/ContentView.swift" | head -1 | cut -d: -f1)

if [ -n "$SHEET_LINE" ]; then
    pass "Found sheet presentation at line $SHEET_LINE"

    # Check next 5 lines for NavigationStack
    NEXT_LINES=$(sed -n "${SHEET_LINE},$((SHEET_LINE + 5))p" "Fonic HiFi/ContentView.swift")

    if echo "$NEXT_LINES" | grep -q "NavigationStack"; then
        warn "NavigationStack wrapper found in sheet"
        echo "   → This MAY interfere with zoom morphing"
        echo "   → Sample code uses .fullScreenCover without NavigationStack"
        HAS_NAV_STACK=1
    else
        pass "No NavigationStack wrapper in sheet"
        echo "   → Zoom morphing should work correctly"
        HAS_NAV_STACK=0
    fi

    # Check for .navigationTransition
    if rg '\.navigationTransition\(\.zoom\(sourceID: "miniplayer"' "Fonic HiFi/ContentView.swift" -q; then
        pass "Zoom transition configured (.navigationTransition)"
    else
        fail "Zoom transition not configured"
    fi

    # Check for .matchedTransitionSource on mini player
    if rg '\.matchedTransitionSource\(id: "miniplayer"' "Fonic HiFi/Presentation/Views/NowPlaying/LiquidGlassMiniPlayer.swift" -q; then
        pass "Mini player has matchedTransitionSource"
    else
        fail "Mini player missing matchedTransitionSource"
    fi
else
    fail "Sheet presentation not found in ContentView.swift"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "🎬 MANUAL TESTING REQUIRED"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ $HAS_NAV_STACK -eq 1 ]; then
    warn "NavigationStack wrapper detected - zoom may not work correctly"
    echo ""
    echo "Based on code analysis:"
    echo "  • Sheet has NavigationStack wrapper (ContentView.swift:~${SHEET_LINE})"
    echo "  • Sample code uses .fullScreenCover WITHOUT NavigationStack"
    echo "  • This difference may cause zoom morphing to fail"
    echo ""
else
    info "No NavigationStack wrapper - zoom should work"
    echo ""
fi

echo "Please test current behavior manually:"
echo ""
echo "1️⃣  BUILD AND RUN"
echo "   Run: make run"
echo "   (Or build in Xcode and launch simulator)"
echo ""
echo "2️⃣  LOCATE MINI PLAYER"
echo "   → Bottom of screen, above tab bar"
echo "   → May show \"Not Playing\" if library empty"
echo ""
echo "3️⃣  TAP MINI PLAYER"
echo "   → Tap anywhere on the mini player"
echo ""
echo "4️⃣  OBSERVE ANIMATION CAREFULLY"
echo ""
echo "   ✅ ZOOM/MORPH (CORRECT):"
echo "      • Mini player GROWS/EXPANDS into the sheet"
echo "      • Continuous visual transformation"
echo "      • Smooth scale/zoom animation"
echo "      • Album artwork transitions smoothly"
echo ""
echo "   ❌ SLIDE UP (BUG):"
echo "      • Sheet slides up from bottom edge"
echo "      • Mini player stays in place"
echo "      • No visual connection between mini player and sheet"
echo "      • Sudden appearance instead of morph"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""

# Wait for user to test
read -p "Press ENTER after you have tested the mini player animation..."
echo ""

# Collect results
echo "📋 TEST RESULTS"
echo "==============="
echo ""
read -p "Did the mini player MORPH/ZOOM into the sheet? (y/n): " MORPH_RESULT
read -p "Or did the sheet SLIDE UP from the bottom? (y/n): " SLIDE_RESULT

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "📊 ANALYSIS & RECOMMENDATION"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [[ "$MORPH_RESULT" == "y" ]]; then
    pass "ZOOM MORPHING WORKS CORRECTLY"
    echo ""
    echo "✅ **SKIP STEP 04** - No fix needed"
    echo ""
    echo "The mini player zoom morphing is working correctly despite the"
    echo "NavigationStack wrapper. Step 04 is not required."
    echo ""
    if [ $HAS_NAV_STACK -eq 1 ]; then
        info "Note: NavigationStack wrapper is present but not causing issues"
        echo "   → It enables .toolbar(.hidden) functionality"
        echo "   → Removing it would break toolbar hiding"
        echo "   → Current implementation is correct"
    fi
    echo ""
    exit 0

elif [[ "$SLIDE_RESULT" == "y" ]]; then
    fail "ZOOM MORPHING NOT WORKING - Bug confirmed"
    echo ""
    echo "⚠️  **IMPLEMENT STEP 04** with investigation"
    echo ""
    echo "The mini player zoom bug is confirmed. Before implementing Step 04:"
    echo ""
    echo "1. **Investigate root cause:**"
    echo "   • Is NavigationStack wrapper the issue?"
    echo "   • Or is it .sheet vs .fullScreenCover difference?"
    echo ""
    echo "2. **Consider alternatives:**"
    echo "   Option A: Remove NavigationStack wrapper (Step 04 original plan)"
    echo "     ⚠️  WARNING: Will break .toolbar(.hidden) functionality"
    echo "     → Need to find alternative for hiding toolbar"
    echo ""
    echo "   Option B: Switch to .fullScreenCover like sample"
    echo "     ✅ Matches sample code pattern exactly"
    echo "     ⚠️  Changes UX - no .medium detent (half-screen)"
    echo "     → Need to evaluate if this UX change is acceptable"
    echo ""
    echo "3. **Test both approaches:**"
    echo "   • Test Option A: Remove NavigationStack"
    echo "   • Test Option B: Use .fullScreenCover"
    echo "   • Choose best solution based on testing"
    echo ""
    echo "4. **Update Step 04 documentation:**"
    echo "   • Document chosen approach"
    echo "   • Note trade-offs and reasoning"
    echo ""
    exit 1
else
    warn "Test results unclear"
    echo ""
    echo "Please re-run this script and test more carefully."
    echo "Focus on whether mini player grows/expands or sheet slides up."
    echo ""
    exit 2
fi
