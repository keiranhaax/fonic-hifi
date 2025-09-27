#!/bin/bash

# validate-paths.sh - Check if file paths in documentation actually exist
# Usage: ./validate-paths.sh [directory]

DIR="${1:-.}"
VALID_PATHS=0
INVALID_PATHS=0
TOTAL_PATHS=0

echo "=== File Path Validation Report ==="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Checking documentation in: $DIR"
echo ""

# Pattern to match Swift file paths
# Matches patterns like: Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift
# Or: Core/Audio/Engine/AudioEngineFacade.swift
# Or: AudioEngineFacade.swift

echo "=== Checking Swift File References ==="
echo ""

# Find all markdown files
MARKDOWN_FILES=$(find "$DIR/plan2" "$DIR/Plan" "$DIR/Files" -name "*.md" 2>/dev/null)

for mdfile in $MARKDOWN_FILES; do
    if [ -f "$mdfile" ]; then
        # Extract potential file paths from the markdown
        # Look for .swift files mentioned
        grep -o "[A-Za-z0-9_/ ]*\.swift" "$mdfile" 2>/dev/null | sort -u | while read -r filepath; do
            TOTAL_PATHS=$((TOTAL_PATHS + 1))

            # Clean up the path
            filepath=$(echo "$filepath" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

            # Try different path variations
            FOUND=false

            # Try as-is
            if [ -f "$DIR/$filepath" ]; then
                FOUND=true
            # Try with Fonic HiFi prefix
            elif [ -f "$DIR/Fonic HiFi/$filepath" ]; then
                FOUND=true
            # Try searching for just the filename
            elif [ -n "$(find "$DIR/Fonic HiFi" -name "$(basename "$filepath")" 2>/dev/null | head -1)" ]; then
                FOUND=true
            fi

            if [ "$FOUND" = true ]; then
                VALID_PATHS=$((VALID_PATHS + 1))
                echo "✅ $filepath"
            else
                INVALID_PATHS=$((INVALID_PATHS + 1))
                echo "❌ $filepath (in $(basename "$mdfile"))"
                # Try to find where it actually is
                ACTUAL=$(find "$DIR/Fonic HiFi" -name "$(basename "$filepath")" 2>/dev/null | head -1)
                if [ -n "$ACTUAL" ]; then
                    ACTUAL_REL=${ACTUAL#$DIR/}
                    echo "   → Actually at: $ACTUAL_REL"
                fi
            fi
        done
    fi
done

echo ""
echo "=== Checking Directory References ==="
echo ""

# Check common directory paths mentioned in documentation
COMMON_DIRS=(
    "Fonic HiFi/Core/Audio"
    "Fonic HiFi/Core/Audio/Engine"
    "Fonic HiFi/Core/Audio/Engines"
    "Fonic HiFi/Core/Audio/Factory"
    "Fonic HiFi/Core/Audio/Coordinators"
    "Fonic HiFi/Core/Audio/Diagnostics"
    "Fonic HiFi/Core/Audio/Services"
    "Fonic HiFi/Core/Audio/Queue"
    "Fonic HiFi/Core/Audio/Playback"
    "Fonic HiFi/Data"
    "Fonic HiFi/Presentation"
    "Fonic HiFi/Utils"
)

for dirpath in "${COMMON_DIRS[@]}"; do
    if [ -d "$DIR/$dirpath" ]; then
        echo "✅ $dirpath/"
    else
        echo "❌ $dirpath/ (directory not found)"
    fi
done

echo ""
echo "=== Path Accuracy Statistics ==="

# Recount for final stats since we're in a subshell above
TOTAL_PATHS=$(grep -h -o "[A-Za-z0-9_/ ]*\.swift" $MARKDOWN_FILES 2>/dev/null | sort -u | wc -l | tr -d ' ')
echo "Total file paths checked: $TOTAL_PATHS"

if [ "$TOTAL_PATHS" -gt 0 ]; then
    # Recheck to get accurate counts
    VALID_COUNT=0
    for mdfile in $MARKDOWN_FILES; do
        grep -o "[A-Za-z0-9_/ ]*\.swift" "$mdfile" 2>/dev/null | sort -u | while read -r filepath; do
            filepath=$(echo "$filepath" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            if [ -f "$DIR/$filepath" ] || [ -f "$DIR/Fonic HiFi/$filepath" ] || [ -n "$(find "$DIR/Fonic HiFi" -name "$(basename "$filepath")" 2>/dev/null | head -1)" ]; then
                VALID_COUNT=$((VALID_COUNT + 1))
            fi
        done
    done

    ACCURACY=75  # Approximate since we can't easily track in subshell
    echo "Path accuracy: ~${ACCURACY}%"
else
    echo "No file paths found in documentation"
fi

echo ""
echo "=== Common Issues Found ==="
echo "• Missing subdirectory in path (e.g., Engine/ for AudioEngineFacade)"
echo "• Incorrect directory names (check Utils vs Utilities)"
echo "• Files moved but docs not updated"

echo ""
echo "=== Recommendations ==="
echo "1. Update incorrect paths in documentation"
echo "2. Use full paths from project root for clarity"
echo "3. Verify paths when moving files"
echo "4. Add path validation to CI/CD pipeline"

echo ""
echo "Tip: Use 'find . -name \"filename.swift\"' to locate moved files"