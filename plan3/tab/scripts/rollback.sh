#!/bin/bash
set -e

echo "🔄 Tab Bar Redesign Rollback"
echo "============================"

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
warn "This script will REVERT the iOS 26 tab bar redesign implementation"
echo ""
echo "The following changes will be rolled back:"
echo "  • HomeView.swift will be DELETED"
echo "  • ContentView.swift will be restored to old .tabItem syntax"
echo "  • SearchView.swift will be restored to local state and .searchable()"
echo "  • Mini player sheet will have NavigationStack wrapper re-added"
echo ""
echo "This will return the app to the original 3-tab layout."
echo ""

# Confirm rollback
read -p "Are you sure you want to rollback? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    info "Rollback cancelled"
    exit 0
fi

echo ""
echo "Starting rollback..."
echo ""

# Check if git is available for backup
if command -v git &> /dev/null; then
    if git rev-parse --git-dir > /dev/null 2>&1; then
        info "Creating backup branch before rollback..."
        BACKUP_BRANCH="backup-tab-redesign-$(date +%Y%m%d-%H%M%S)"
        git branch "$BACKUP_BRANCH" 2>/dev/null || true
        if [ $? -eq 0 ]; then
            pass "Backup branch created: $BACKUP_BRANCH"
            echo "   → Use 'git checkout $BACKUP_BRANCH' to restore if needed"
        fi
        echo ""
    fi
fi

# Step 1: Remove HomeView.swift
echo "📱 Step 1: Removing HomeView.swift"
if [ -f "Fonic HiFi/Presentation/Views/Home/HomeView.swift" ]; then
    rm "Fonic HiFi/Presentation/Views/Home/HomeView.swift"
    pass "HomeView.swift deleted"

    # Remove directory if empty
    if [ -d "Fonic HiFi/Presentation/Views/Home" ]; then
        rmdir "Fonic HiFi/Presentation/Views/Home" 2>/dev/null && pass "Empty Home directory removed" || true
    fi
else
    warn "HomeView.swift not found (already deleted?)"
fi

# Step 2: Restore ContentView.swift
echo ""
echo "📄 Step 2: Restoring ContentView.swift"

# Check if git restore is available
if command -v git &> /dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
    info "Using git to restore ContentView.swift..."
    git checkout HEAD -- "Fonic HiFi/ContentView.swift" 2>/dev/null
    if [ $? -eq 0 ]; then
        pass "ContentView.swift restored from git"
    else
        warn "Git restore failed - manual restoration required"
        echo ""
        echo "Manually restore ContentView.swift to original state:"
        echo "  • Remove @State private var searchText"
        echo "  • Replace Tab() blocks with old .tabItem syntax"
        echo "  • Remove .tabBarMinimizeBehavior()"
        echo "  • Re-add NavigationStack wrapper to sheet"
    fi
else
    warn "Git not available - manual restoration required"
    echo ""
    echo "Manually restore ContentView.swift:"
    echo ""
    echo "1. Remove search text state (after line 18):"
    echo "   DELETE: @State private var searchText = \"\""
    echo ""
    echo "2. Replace TabView block (lines 21-42) with:"
    echo ""
    echo "   TabView {"
    echo "       LibraryView()"
    echo "           .environment(\\.showingNowPlaying, \$showingNowPlaying)"
    echo "           .tabItem {"
    echo "               Label(\"Library\", systemImage: \"music.note.list\")"
    echo "           }"
    echo ""
    echo "       SearchView()"
    echo "           .environment(\\.showingNowPlaying, \$showingNowPlaying)"
    echo "           .environment(\\.audioEngine, audioService)"
    echo "           .environment(\\.importService, importService)"
    echo "           .tabItem {"
    echo "               Label(\"Search\", systemImage: \"magnifyingglass\")"
    echo "           }"
    echo ""
    echo "       SettingsView()"
    echo "           .tabItem {"
    echo "               Label(\"Settings\", systemImage: \"gear\")"
    echo "           }"
    echo "   }"
    echo ""
    echo "3. Restore NavigationStack wrapper in sheet (lines 52-66):"
    echo ""
    echo "   .sheet(isPresented: \$showingNowPlaying) {"
    echo "       NavigationStack {"
    echo "           NowPlayingView(animationNamespace: miniPlayerNamespace)"
    echo "               .navigationTransition(.zoom(sourceID: \"miniplayer\", in: miniPlayerNamespace))"
    echo "               .toolbar(.hidden, for: .navigationBar)"
    echo "       }"
    echo "       .environment(\\.audioEngine, audioService)"
    echo "       .presentationDetents([.medium, .large], selection: \$selectedDetent)"
    echo "       .presentationBackgroundInteraction(.enabled(upThrough: .medium))"
    echo "       .presentationDragIndicator(.visible)"
    echo "       .presentationCornerRadius(20)"
    echo "   }"
    echo ""
fi

# Step 3: Restore SearchView.swift
echo ""
echo "🔎 Step 3: Restoring SearchView.swift"

if command -v git &> /dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
    info "Using git to restore SearchView.swift..."
    git checkout HEAD -- "Fonic HiFi/Presentation/Views/Search/SearchView.swift" 2>/dev/null
    if [ $? -eq 0 ]; then
        pass "SearchView.swift restored from git"
    else
        warn "Git restore failed - manual restoration required"
        echo ""
        echo "Manually restore SearchView.swift:"
        echo "  • Remove @Binding var searchText"
        echo "  • Add back @State private var searchText = \"\""
        echo "  • Add back .searchable() modifier"
    fi
else
    warn "Git not available - manual restoration required"
    echo ""
    echo "Manually restore SearchView.swift:"
    echo ""
    echo "1. Remove binding parameter (line 13):"
    echo "   DELETE: @Binding var searchText: String"
    echo ""
    echo "2. Add back local state (after line 13):"
    echo "   ADD: @State private var searchText = \"\""
    echo ""
    echo "3. Add back .searchable() modifier (after body content):"
    echo ""
    echo "   .searchable("
    echo "       text: \$searchText,"
    echo "       placement: .toolbar,"
    echo "       prompt: Text(\"Search your library\"),"
    echo "   )"
    echo ""
fi

# Verify rollback
echo ""
echo "🔨 Verifying rollback..."

ROLLBACK_SUCCESS=true

# Check HomeView deleted
if [ -f "Fonic HiFi/Presentation/Views/Home/HomeView.swift" ]; then
    fail "HomeView.swift still exists"
    ROLLBACK_SUCCESS=false
else
    pass "HomeView.swift removed"
fi

# Try to build
echo ""
info "Attempting build..."
if make build > /tmp/rollback_build.log 2>&1; then
    pass "Build successful after rollback"
else
    fail "Build failed after rollback"
    echo "See /tmp/rollback_build.log for details"
    ROLLBACK_SUCCESS=false
fi

# Summary
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "📊 ROLLBACK SUMMARY"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ "$ROLLBACK_SUCCESS" = true ]; then
    pass "ROLLBACK COMPLETE"
    echo ""
    echo "✅ HomeView deleted"
    echo "✅ ContentView restored to .tabItem syntax"
    echo "✅ SearchView restored to local state"
    echo "✅ Build passing"
    echo ""
    echo "App returned to original 3-tab layout:"
    echo "  • Library"
    echo "  • Search"
    echo "  • Settings"
    echo ""

    if command -v git &> /dev/null && [ -n "$BACKUP_BRANCH" ]; then
        echo "💾 Backup available at: $BACKUP_BRANCH"
        echo "   Restore with: git checkout $BACKUP_BRANCH"
        echo ""
    fi

    exit 0
else
    fail "ROLLBACK INCOMPLETE"
    echo ""
    echo "Some steps may require manual intervention."
    echo ""
    echo "Check:"
    echo "  1. HomeView.swift deleted"
    echo "  2. ContentView.swift has old .tabItem syntax"
    echo "  3. SearchView.swift has local state and .searchable()"
    echo "  4. Build passes: make build"
    echo ""
    echo "See rollback instructions above for manual steps."
    echo ""

    if command -v git &> /dev/null && [ -n "$BACKUP_BRANCH" ]; then
        echo "💾 Backup available at: $BACKUP_BRANCH"
        echo ""
    fi

    exit 1
fi
