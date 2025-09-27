#!/bin/bash

# count-documented-apis.sh - Count documented APIs in markdown files
# Usage: ./count-documented-apis.sh [directory]

DIR="${1:-.}"
DOCUMENTED_COMPONENTS=0
DOCUMENTED_IN_GUIDE=0
DOCUMENTED_IN_AI=0

echo "=== Documented API Count for Fonic HiFi ==="
echo "Searching in: $DIR"
echo ""

# Count components documented in main guide
echo "=== Components in Main Guide (plan2/agents/fonic-hifi-codebase-guide.md) ==="
if [ -f "$DIR/plan2/agents/fonic-hifi-codebase-guide.md" ]; then
    # Count major components (headers with specific patterns)
    FACADES=$(grep -c "AudioEngineFacade\|AudioSessionManager\|AudioQueueManager" "$DIR/plan2/agents/fonic-hifi-codebase-guide.md" || echo 0)
    ADAPTERS=$(grep -c "AVAudioEngineAdapter\|AudioKitEngineAdapter" "$DIR/plan2/agents/fonic-hifi-codebase-guide.md" || echo 0)
    DATA_LAYER=$(grep -c "DataManager\|TrackDataActor\|LibraryImportService" "$DIR/plan2/agents/fonic-hifi-codebase-guide.md" || echo 0)
    COORDINATORS=$(grep -c "PlaybackCoordinator\|QueueCoordinator\|StateCoordinator" "$DIR/plan2/agents/fonic-hifi-codebase-guide.md" || echo 0)
    DIAGNOSTICS=$(grep -c "AudioMonitor\|BitPerfectValidator\|DACCompatibilityInfo" "$DIR/plan2/agents/fonic-hifi-codebase-guide.md" || echo 0)

    echo "  Audio Facades/Managers: $FACADES mentions"
    echo "  Engine Adapters: $ADAPTERS mentions"
    echo "  Data Layer: $DATA_LAYER mentions"
    echo "  Coordinators: $COORDINATORS mentions"
    echo "  Diagnostics: $DIAGNOSTICS mentions"

    DOCUMENTED_IN_GUIDE=$((FACADES + ADAPTERS + DATA_LAYER + COORDINATORS + DIAGNOSTICS))
fi

# Count components in AI analysis files
echo ""
echo "=== Components in AI Analyses (plan2/agents/*.md) ==="
for file in "$DIR"/plan2/agents/*.md; do
    if [ -f "$file" ] && [ "$(basename "$file")" != "fonic-hifi-codebase-guide.md" ]; then
        FILENAME=$(basename "$file" .md)
        COUNT=$(grep -c "class\|struct\|protocol\|enum" "$file" 2>/dev/null || echo 0)
        if [ "$COUNT" -gt 0 ]; then
            echo "  $FILENAME: $COUNT component references"
            DOCUMENTED_IN_AI=$((DOCUMENTED_IN_AI + COUNT))
        fi
    fi
done

# Count components in Plan files
echo ""
echo "=== Components in Plan Files (Plan/*.md) ==="
for file in "$DIR"/Plan/*.md; do
    if [ -f "$file" ]; then
        FILENAME=$(basename "$file" .md)
        COUNT=$(grep -c "AudioEngine\|PlaybackState\|Queue\|Track\|Album" "$file" 2>/dev/null || echo 0)
        if [ "$COUNT" -gt 0 ]; then
            echo "  $FILENAME: $COUNT component references"
        fi
    fi
done

# Count verification tags
echo ""
echo "=== Verification Tag Statistics ==="
VERIFIED_CODE=$(grep -r "\[Verified-Code" "$DIR/plan2" "$DIR/Plan" "$DIR/Files" --include="*.md" 2>/dev/null | wc -l | tr -d ' ')
VERIFIED_APPLE=$(grep -r "\[Verified-Apple" "$DIR/plan2" "$DIR/Plan" "$DIR/Files" --include="*.md" 2>/dev/null | wc -l | tr -d ' ')
UNVERIFIED=$(grep -r "\[Unverified" "$DIR/plan2" "$DIR/Plan" "$DIR/Files" --include="*.md" 2>/dev/null | wc -l | tr -d ' ')

echo "  [Verified-Code] tags: $VERIFIED_CODE"
echo "  [Verified-Apple] tags: $VERIFIED_APPLE"
echo "  [Unverified] tags: $UNVERIFIED"

TOTAL_TAGS=$((VERIFIED_CODE + VERIFIED_APPLE + UNVERIFIED))
if [ "$TOTAL_TAGS" -gt 0 ]; then
    VERIFIED_PERCENT=$(( (VERIFIED_CODE + VERIFIED_APPLE) * 100 / TOTAL_TAGS ))
    echo "  Verification rate: ${VERIFIED_PERCENT}%"
fi

echo ""
echo "=== Summary ==="
echo "Main guide references: $DOCUMENTED_IN_GUIDE"
echo "AI analysis references: $DOCUMENTED_IN_AI"
echo ""
echo "Note: These counts measure mentions, not unique components."
echo "A single component may be counted multiple times."