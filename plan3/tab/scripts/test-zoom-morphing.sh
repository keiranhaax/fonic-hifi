#!/bin/bash
set -e

echo "🎬 Mini Player Zoom Morphing Test"
echo "=================================="

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

# Check if xcrun simctl is available
if ! command -v xcrun &> /dev/null; then
    fail "xcrun not found - Xcode command line tools required"
    exit 1
fi

# Configuration
SCHEME="Fonic HiFi"
DEVICE_NAME="iPhone 16 Pro"
OS_VERSION="26.0"

echo ""
info "This script will:"
echo "  1. Boot iPhone 16 Pro simulator (iOS 26.0)"
echo "  2. Build and install Fonic HiFi"
echo "  3. Launch the app"
echo "  4. Provide manual testing instructions for zoom morphing"
echo ""

# Check if simulator is available
info "Checking for iPhone 16 Pro simulator..."
DEVICE_UDID=$(xcrun simctl list devices "iPhone 16 Pro" | grep "iPhone 16 Pro (${OS_VERSION})" | grep -v "unavailable" | head -1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')

if [ -z "$DEVICE_UDID" ]; then
    fail "iPhone 16 Pro (iOS ${OS_VERSION}) simulator not found"
    echo ""
    echo "Available simulators:"
    xcrun simctl list devices available | grep "iPhone"
    echo ""
    echo "Create simulator in Xcode: Window → Devices and Simulators → Add Device"
    exit 1
fi

pass "Found iPhone 16 Pro: $DEVICE_UDID"

# Boot simulator if not already booted
echo ""
info "Booting simulator..."
BOOT_STATUS=$(xcrun simctl list devices | grep "$DEVICE_UDID" | grep -c "Booted" || true)

if [ "$BOOT_STATUS" -eq 0 ]; then
    xcrun simctl boot "$DEVICE_UDID" 2>/dev/null || true
    sleep 2
    pass "Simulator booted"
else
    pass "Simulator already booted"
fi

# Open Simulator app
open -a Simulator

# Wait for simulator to be ready
info "Waiting for simulator to be ready..."
sleep 3

# Build and install app
echo ""
info "Building Fonic HiFi..."
if make build > /tmp/fonic_build.log 2>&1; then
    pass "Build successful"
else
    fail "Build failed"
    echo "See /tmp/fonic_build.log for details"
    exit 1
fi

# Install app (using xcodebuild to get app path)
echo ""
info "Installing app to simulator..."
xcodebuild \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$DEVICE_UDID" \
    -derivedDataPath /tmp/FonicHiFi_DerivedData \
    install > /tmp/fonic_install.log 2>&1

if [ $? -eq 0 ]; then
    pass "App installed"
else
    warn "Install may have failed - trying to launch anyway"
fi

# Get bundle identifier
BUNDLE_ID="com.fonicmusic.Fonic-HiFi"

# Launch app
echo ""
info "Launching Fonic HiFi..."
xcrun simctl launch "$DEVICE_UDID" "$BUNDLE_ID" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    pass "App launched"
else
    fail "Failed to launch app"
    echo "You may need to launch manually in the simulator"
fi

# Manual testing instructions
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "🧪 MANUAL TESTING REQUIRED"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "The simulator is now running Fonic HiFi."
echo ""
echo "🎯 TEST PROCEDURE FOR ZOOM MORPHING:"
echo ""
echo "1️⃣  LOCATE MINI PLAYER"
echo "   → Look at bottom of screen above tab bar"
echo "   → Should show liquid glass mini player"
echo "   → May show \"Not Playing\" if library is empty"
echo ""
echo "2️⃣  TAP MINI PLAYER"
echo "   → Tap anywhere on the mini player"
echo ""
echo "3️⃣  OBSERVE ANIMATION (CRITICAL)"
echo ""
echo "   ✅ EXPECTED (CORRECT):"
echo "      • Mini player GROWS/EXPANDS/MORPHS into the sheet"
echo "      • Smooth zoom/scale animation"
echo "      • Continuous visual transformation"
echo "      • Album artwork transitions smoothly"
echo "      • Sheet appears at half-screen height (.medium detent)"
echo ""
echo "   ❌ INCORRECT (BUG NOT FIXED):"
echo "      • Sheet slides up from bottom edge"
echo "      • Mini player stays in place during animation"
echo "      • No visual connection between mini player and sheet"
echo "      • Sudden appearance instead of morph"
echo ""
echo "4️⃣  TEST SHEET BEHAVIOR"
echo "   → Sheet should open at .medium detent (half screen)"
echo "   → Drag sheet up → should expand to full screen (.large)"
echo "   → Drag sheet down → should dismiss with reverse morph"
echo "   → Background should be tappable when at .medium"
echo ""
echo "5️⃣  REPEAT TEST"
echo "   → Tap mini player again after dismissing"
echo "   → Verify morphing works consistently"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""

# Wait for user input
echo "Press ENTER when you have completed manual testing..."
read -r

# Collect test results
echo ""
echo "📋 TEST RESULTS"
echo "==============="
echo ""
read -p "Did the mini player MORPH/ZOOM into the sheet? (y/n): " MORPH_RESULT
read -p "Was the animation smooth and continuous? (y/n): " SMOOTH_RESULT
read -p "Did the sheet open at .medium detent (half screen)? (y/n): " DETENT_RESULT
read -p "Could you drag the sheet to .large (full screen)? (y/n): " DRAG_RESULT

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "📊 TEST SUMMARY"
echo "═══════════════════════════════════════════════════════════"
echo ""

TOTAL_PASS=0

if [[ "$MORPH_RESULT" == "y" ]]; then
    pass "Mini player morphing animation"
    TOTAL_PASS=$((TOTAL_PASS + 1))
else
    fail "Mini player morphing animation"
    echo "   → Mini player should grow/expand into sheet, not slide up"
fi

if [[ "$SMOOTH_RESULT" == "y" ]]; then
    pass "Smooth continuous animation"
    TOTAL_PASS=$((TOTAL_PASS + 1))
else
    fail "Animation not smooth"
    echo "   → Check for sudden jumps or discontinuities"
fi

if [[ "$DETENT_RESULT" == "y" ]]; then
    pass "Sheet opens at .medium detent"
    TOTAL_PASS=$((TOTAL_PASS + 1))
else
    fail "Sheet detent incorrect"
    echo "   → Sheet should open at half-screen height"
fi

if [[ "$DRAG_RESULT" == "y" ]]; then
    pass "Sheet draggable to .large"
    TOTAL_PASS=$((TOTAL_PASS + 1))
else
    fail "Sheet drag behavior"
    echo "   → Sheet should be draggable between .medium and .large"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"

if [ $TOTAL_PASS -eq 4 ]; then
    echo ""
    pass "ALL TESTS PASSED (4/4) - ZOOM MORPHING WORKING CORRECTLY"
    echo ""
    echo "🎉 Step 04 (Mini Player Zoom Fix) is VERIFIED"
    echo ""
    exit 0
else
    echo ""
    fail "SOME TESTS FAILED ($TOTAL_PASS/4)"
    echo ""
    echo "⚠️  Step 04 (Mini Player Zoom Fix) needs debugging"
    echo ""
    echo "Troubleshooting:"
    echo "1. Verify NavigationStack removed from sheet in ContentView.swift"
    echo "2. Check IDs match: 'miniplayer' in both source and destination"
    echo "3. Verify .matchedTransitionSource() on mini player"
    echo "4. Verify .navigationTransition() on NowPlayingView"
    echo ""
    echo "See: plan3/tab/issues/04-fix-mini-player-zoom.md for details"
    echo ""
    exit 1
fi
