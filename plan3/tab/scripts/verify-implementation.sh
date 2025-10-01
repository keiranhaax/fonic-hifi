#!/bin/bash
set -e

echo "🔍 Tab Bar Redesign Implementation Verification"
echo "==============================================="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✅ $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Track status
STEP01_STATUS=0
STEP02_STATUS=0
STEP03_STATUS=0
STEP04_STATUS=0
STEP05_STATUS=0

# Baseline Verification
echo "🔍 Verifying Current Baseline (Pre-Implementation)"
echo "================================================="

# Check .tabBarMinimizeBehavior exists
if rg '\.tabBarMinimizeBehavior\(\.onScrollDown\)' "Fonic HiFi/ContentView.swift" -q; then
    pass "tabBarMinimizeBehavior already exists (will be preserved in Step 03)"
else
    warn "tabBarMinimizeBehavior missing (expected at ContentView.swift:42)"
fi

# Check SearchView has NavigationStack
if rg 'NavigationStack' "Fonic HiFi/Presentation/Views/Search/SearchView.swift" -q; then
    pass "SearchView has NavigationStack (will be moved to ContentView in Step 05)"
else
    warn "SearchView missing NavigationStack (unexpected)"
fi

# Check .tabViewBottomAccessory exists
if rg '\.tabViewBottomAccessory' "Fonic HiFi/ContentView.swift" -q; then
    pass "tabViewBottomAccessory already exists (will be preserved)"
else
    warn "tabViewBottomAccessory missing (expected at ContentView.swift:43)"
fi

echo ""
echo "📋 Implementation Status"
echo "========================"
echo ""

# Step 01: HomeView Creation
echo "📱 Step 01: HomeView Creation"
if [ -f "Fonic HiFi/Presentation/Views/Home/HomeView.swift" ]; then
    if grep -q "Recently Played" "Fonic HiFi/Presentation/Views/Home/HomeView.swift" && \
       grep -q "Most Listened" "Fonic HiFi/Presentation/Views/Home/HomeView.swift" && \
       grep -q "Favorite Albums" "Fonic HiFi/Presentation/Views/Home/HomeView.swift"; then
        pass "HomeView exists with data sections"
        STEP01_STATUS=1
    else
        warn "HomeView exists but missing data sections"
        STEP01_STATUS=0
    fi
else
    fail "HomeView.swift not found"
    STEP01_STATUS=0
fi

# Step 02: Search Text State
echo "🔍 Step 02: ContentView Search State"
if grep -q '@State private var searchText = ""' "Fonic HiFi/ContentView.swift"; then
    pass "Search text state added to ContentView"
    STEP02_STATUS=1
else
    fail "Search text state not found in ContentView"
    STEP02_STATUS=0
fi

# Step 03: Modern Tab() Syntax
echo "📊 Step 03: Modern Tab() Syntax"
if rg 'Tab\("Home".*role:' "Fonic HiFi/ContentView.swift" -q 2>/dev/null; then
    fail "Home tab should NOT have role parameter"
    STEP03_STATUS=0
elif rg 'Tab\("Search".*role: \.search\)' "Fonic HiFi/ContentView.swift" -q; then
    if rg '\.tabBarMinimizeBehavior\(\.onScrollDown\)' "Fonic HiFi/ContentView.swift" -q; then
        # Check for 4 tabs
        TAB_COUNT=$(rg '^[[:space:]]*Tab\(' "Fonic HiFi/ContentView.swift" -c || echo "0")
        if [ "$TAB_COUNT" -eq 4 ]; then
            pass "Modern Tab() syntax with 4 tabs, search role, and tab bar behavior"
            STEP03_STATUS=1
        else
            warn "Tab() syntax correct but found $TAB_COUNT tabs (expected 4)"
            STEP03_STATUS=0
        fi
    else
        warn "Search tab correct but missing .tabBarMinimizeBehavior()"
        STEP03_STATUS=0
    fi
else
    fail "Search tab missing role: .search parameter"
    STEP03_STATUS=0
fi

# Step 04: Mini Player Zoom Fix (CONDITIONAL)
echo "🎵 Step 04: Mini Player Zoom Morphing"
SHEET_LINE=$(grep -n '.sheet(isPresented: \$showingNowPlaying)' "Fonic HiFi/ContentView.swift" | head -1 | cut -d: -f1)
if [ -n "$SHEET_LINE" ]; then
    # Check if NavigationStack appears within 5 lines of sheet
    NEXT_LINES=$(sed -n "${SHEET_LINE},$((SHEET_LINE + 5))p" "Fonic HiFi/ContentView.swift")
    if echo "$NEXT_LINES" | grep -q "NavigationStack"; then
        warn "NavigationStack wrapper still present (Step 04 may have been skipped)"
        echo "   → If zoom morphing works correctly, this is EXPECTED"
        echo "   → Run scripts/test-current-zoom-behavior.sh to verify"
        STEP04_STATUS=1  # Mark as "complete" (intentionally skipped)
    else
        if rg '\.navigationTransition\(\.zoom\(sourceID: "miniplayer"' "Fonic HiFi/ContentView.swift" -q; then
            pass "Mini player zoom morphing fixed (no NavigationStack wrapper)"
            STEP04_STATUS=1
        else
            warn "NavigationStack removed but zoom transition not found"
            STEP04_STATUS=0
        fi
    fi
else
    fail "Sheet presentation not found"
    STEP04_STATUS=0
fi

# Step 05: SearchView Binding
echo "🔎 Step 05: SearchView Text Binding"
if rg '@Binding var searchText: String' "Fonic HiFi/Presentation/Views/Search/SearchView.swift" -q; then
    if rg '@State private var searchText' "Fonic HiFi/Presentation/Views/Search/SearchView.swift" -q; then
        fail "SearchView has binding but also has local state (should be removed)"
        STEP05_STATUS=0
    elif rg '\.searchable\(' "Fonic HiFi/Presentation/Views/Search/SearchView.swift" -q; then
        warn "SearchView has binding but still has .searchable() modifier"
        STEP05_STATUS=0
    else
        pass "SearchView refactored to accept text binding"
        STEP05_STATUS=1
    fi
else
    fail "SearchView missing @Binding var searchText"
    STEP05_STATUS=0
fi

# Build Verification
echo ""
echo "🔨 Build Verification"
if make build >/dev/null 2>&1; then
    pass "Project builds successfully"
    BUILD_STATUS=1
else
    fail "Project build failed"
    echo "Run 'make build' for details"
    BUILD_STATUS=0
fi

# Summary
echo ""
echo "📊 Summary"
echo "=========="
TOTAL=$((STEP01_STATUS + STEP02_STATUS + STEP03_STATUS + STEP04_STATUS + STEP05_STATUS))
echo "Implementation steps completed: $TOTAL/5"
echo ""
echo "Step 01 (HomeView):           $([ $STEP01_STATUS -eq 1 ] && echo '✅' || echo '❌')"
echo "Step 02 (Search State):       $([ $STEP02_STATUS -eq 1 ] && echo '✅' || echo '❌')"
echo "Step 03 (Modern Tab):         $([ $STEP03_STATUS -eq 1 ] && echo '✅' || echo '❌')"
echo "Step 04 (Zoom Fix):           $([ $STEP04_STATUS -eq 1 ] && echo '✅' || echo '❌')"
echo "Step 05 (SearchView Binding): $([ $STEP05_STATUS -eq 1 ] && echo '✅' || echo '❌')"
echo "Build Status:                 $([ $BUILD_STATUS -eq 1 ] && echo '✅' || echo '❌')"
echo ""

if [ $TOTAL -eq 5 ] && [ $BUILD_STATUS -eq 1 ]; then
    pass "ALL IMPLEMENTATION STEPS COMPLETE"
    echo ""
    echo "Next Steps:"
    echo "1. Run app in simulator: make run"
    echo "2. Test tab bar behavior (4 tabs, floating search)"
    echo "3. Test mini player zoom morphing: bash plan3/tab/scripts/test-zoom-morphing.sh"
    echo "4. Verify search text persists across tab switches"
    exit 0
else
    fail "Implementation incomplete ($TOTAL/5 steps)"
    echo ""
    echo "Review failed steps above and see plan3/tab/issues/ for details"
    exit 1
fi
