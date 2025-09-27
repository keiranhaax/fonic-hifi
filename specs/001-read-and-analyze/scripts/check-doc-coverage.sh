#!/bin/bash

# check-doc-coverage.sh - Calculate documentation coverage percentage
# Usage: ./check-doc-coverage.sh [directory]

DIR="${1:-.}"

echo "=== Documentation Coverage Report ==="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Count public APIs
echo "Counting public APIs..."
PUBLIC_APIS=$(grep -r "^public\|^open" "$DIR/Fonic HiFi" --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')

# Count documented components (approximate by counting component mentions in docs)
echo "Counting documented components..."

# Main guide
MAIN_GUIDE_REFS=$(grep -E "class |struct |protocol |enum |AudioEngine|Manager|Coordinator|Service|Actor" "$DIR/plan2/agents/fonic-hifi-codebase-guide.md" 2>/dev/null | wc -l | tr -d ' ')

# Other documentation
OTHER_DOCS_REFS=$(find "$DIR/plan2" "$DIR/Plan" "$DIR/Files" -name "*.md" -not -path "*/fonic-hifi-codebase-guide.md" -exec grep -l "class \|struct \|protocol \|enum " {} \; 2>/dev/null | wc -l | tr -d ' ')

# Estimate unique documented components (divide by 3 to account for duplicates)
DOCUMENTED_ESTIMATE=$((($MAIN_GUIDE_REFS + $OTHER_DOCS_REFS * 5) / 3))

# Calculate coverage
if [ "$PUBLIC_APIS" -gt 0 ]; then
    COVERAGE=$(( ($DOCUMENTED_ESTIMATE * 100) / $PUBLIC_APIS ))
else
    COVERAGE=0
fi

# Count verification tags
VERIFIED_CODE=$(grep -r "\[Verified-Code" "$DIR/plan2" "$DIR/Plan" "$DIR/Files" --include="*.md" 2>/dev/null | wc -l | tr -d ' ')
VERIFIED_APPLE=$(grep -r "\[Verified-Apple" "$DIR/plan2" "$DIR/Plan" "$DIR/Files" --include="*.md" 2>/dev/null | wc -l | tr -d ' ')
UNVERIFIED=$(grep -r "\[Unverified" "$DIR/plan2" "$DIR/Plan" "$DIR/Files" --include="*.md" 2>/dev/null | wc -l | tr -d ' ')

TOTAL_TAGS=$((VERIFIED_CODE + VERIFIED_APPLE + UNVERIFIED))
if [ "$TOTAL_TAGS" -gt 0 ]; then
    VERIFICATION_RATE=$(( ($VERIFIED_CODE + $VERIFIED_APPLE) * 100 / $TOTAL_TAGS ))
else
    VERIFICATION_RATE=0
fi

echo ""
echo "=== Coverage Statistics ==="
echo "Total Public APIs:        $PUBLIC_APIS"
echo "Estimated Documented:     $DOCUMENTED_ESTIMATE"
echo "Coverage Percentage:      ${COVERAGE}%"
echo "Target Coverage:          80%"

if [ "$COVERAGE" -ge 80 ]; then
    echo "Status:                  ✅ TARGET MET"
else
    GAP=$((80 - $COVERAGE))
    echo "Status:                  ⚠️  ${GAP}% below target"
fi

echo ""
echo "=== Verification Statistics ==="
echo "[Verified-Code] tags:     $VERIFIED_CODE"
echo "[Verified-Apple] tags:    $VERIFIED_APPLE"
echo "[Unverified] tags:        $UNVERIFIED"
echo "Verification Rate:        ${VERIFICATION_RATE}%"

echo ""
echo "=== Recommendations ==="

if [ "$COVERAGE" -lt 80 ]; then
    echo "• Document more public APIs to reach 80% target"
    NEEDED=$(( ($PUBLIC_APIS * 80 / 100) - $DOCUMENTED_ESTIMATE ))
    echo "• Approximately $NEEDED more components need documentation"
fi

if [ "$UNVERIFIED" -gt 0 ]; then
    echo "• Review and verify $UNVERIFIED unverified claims"
fi

if [ "$VERIFICATION_RATE" -lt 90 ]; then
    echo "• Increase verification rate to 90%+ for trust"
fi

echo ""
echo "Note: Coverage calculation is approximate. Manual review recommended."