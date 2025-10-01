#!/bin/bash
set -e

echo "🔍 Fonic HiFi P0 Fix Verification"
echo "=================================="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✅ $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# P0-1: LibraryImportService
echo "📦 P0-1: LibraryImportService Threading"
if rg "@MainActor" "Fonic HiFi/Data/Services/LibraryImportService.swift" | grep -q "class LibraryImportService"; then
    fail "LibraryImportService still @MainActor"
    P01_STATUS=0
else
    if rg "actor FileImportProcessor" -q "Fonic HiFi/Data/Actors/"; then
        pass "FileImportProcessor actor exists, LibraryImportService refactored"
        P01_STATUS=1
    else
        fail "FileImportProcessor actor not found"
        P01_STATUS=0
    fi
fi

# P0-2: MPNowPlayingInfo
echo "🎵 P0-2: MPNowPlayingInfo Elapsed Time"
if rg "MPNowPlayingInfoPropertyElapsedPlaybackTime.*=.*time" "Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift" -q; then
    if rg "changePlaybackPositionCommand" "Fonic HiFi/Core/Audio/Services/AudioSessionManager.swift" -q; then
        pass "Elapsed time updates + scrubber support"
        P02_STATUS=1
    else
        warn "Elapsed time updates but scrubber missing"
        P02_STATUS=0
    fi
else
    fail "Elapsed time still hardcoded to 0"
    P02_STATUS=0
fi

# P0-3: try! Removal
echo "⚠️  P0-3: try! Removal"
TRY_MATCHES=$(rg "\\btry!" --type swift "Fonic HiFi/" -n || true)
TRY_MATCHES=$(echo "$TRY_MATCHES" | grep -v "// try!" || true)
if [ -z "$TRY_MATCHES" ]; then
    pass "All try! removed"
    P03_STATUS=1
else
    TRY_COUNT=$(echo "$TRY_MATCHES" | wc -l | tr -d ' ')
    fail "Found $TRY_COUNT remaining try!"
    echo "Files with try!:"
    echo "$TRY_MATCHES" | head -5
    P03_STATUS=0
fi

# P0-4: Mach API Guard
echo "🔧 P0-4: Mach API Guard"
if rg "#if canImport\(Mach\)" "Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift" -q; then
    pass "Mach API guarded with conditional compilation"
    P04_STATUS=1
else
    fail "Mach API not guarded"
    P04_STATUS=0
fi

# Summary
echo ""
echo "📊 Summary"
echo "=========="
TOTAL=$((P01_STATUS + P02_STATUS + P03_STATUS + P04_STATUS))
echo "Completed: $TOTAL/4 P0 fixes"

if [ $TOTAL -eq 4 ]; then
    pass "ALL P0 FIXES COMPLETE"
    exit 0
else
    fail "P0 fixes incomplete ($TOTAL/4)"
    exit 1
fi
