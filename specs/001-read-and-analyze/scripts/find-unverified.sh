#!/bin/bash

# find-unverified.sh - Find all unverified claims in documentation
# Usage: ./find-unverified.sh [directory]

DIR="${1:-.}"
UNVERIFIED_COUNT=0
FILES_WITH_UNVERIFIED=0

echo "=== Unverified Claims Report ==="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Searching in: $DIR"
echo ""

# Find all markdown files
MARKDOWN_FILES=$(find "$DIR/plan2" "$DIR/Plan" "$DIR/Files" -name "*.md" 2>/dev/null)

echo "=== Files with [Unverified] Tags ==="
echo ""

for file in $MARKDOWN_FILES; do
    if [ -f "$file" ]; then
        # Count unverified tags in this file
        COUNT=$(grep -c "\[Unverified\]" "$file" 2>/dev/null || echo 0)

        if [ "$COUNT" -gt 0 ]; then
            FILES_WITH_UNVERIFIED=$((FILES_WITH_UNVERIFIED + 1))
            UNVERIFIED_COUNT=$((UNVERIFIED_COUNT + COUNT))

            RELATIVE_PATH=${file#$DIR/}
            echo "📄 $RELATIVE_PATH: $COUNT unverified claim(s)"

            # Show the actual unverified claims with line numbers
            grep -n "\[Unverified\]" "$file" 2>/dev/null | while IFS=: read -r line_num content; do
                # Truncate long lines
                if [ ${#content} -gt 80 ]; then
                    content="${content:0:77}..."
                fi
                echo "   Line $line_num: $content"
            done
            echo ""
        fi
    fi
done

# Also check for missing verification tags (potential unverified claims)
echo "=== Potential Unverified Claims (technical statements without tags) ==="
echo ""

# Look for common technical keywords without nearby verification tags
KEYWORDS="uses|implements|extends|@MainActor|@Published|Task|async|await|protocol|class|struct"

for file in $MARKDOWN_FILES; do
    if [ -f "$file" ]; then
        RELATIVE_PATH=${file#$DIR/}

        # Find lines with technical keywords but no verification tags on the same line
        POTENTIAL=$(grep -E "($KEYWORDS)" "$file" 2>/dev/null | grep -v "\[Verified\|Unverified\]" | head -3)

        if [ -n "$POTENTIAL" ]; then
            echo "📄 $RELATIVE_PATH: Check these lines:"
            echo "$POTENTIAL" | while IFS= read -r line; do
                if [ ${#line} -gt 80 ]; then
                    line="${line:0:77}..."
                fi
                echo "   ? $line"
            done
            echo ""
        fi
    fi
done

echo "=== Summary ==="
echo "Total [Unverified] tags found: $UNVERIFIED_COUNT"
echo "Files containing unverified claims: $FILES_WITH_UNVERIFIED"

# Count verified tags for comparison
VERIFIED_CODE=$(grep -r "\[Verified-Code" "$DIR/plan2" "$DIR/Plan" "$DIR/Files" --include="*.md" 2>/dev/null | wc -l | tr -d ' ')
VERIFIED_APPLE=$(grep -r "\[Verified-Apple" "$DIR/plan2" "$DIR/Plan" "$DIR/Files" --include="*.md" 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "For comparison:"
echo "  [Verified-Code] tags: $VERIFIED_CODE"
echo "  [Verified-Apple] tags: $VERIFIED_APPLE"

if [ "$UNVERIFIED_COUNT" -gt 0 ]; then
    echo ""
    echo "=== Actions Needed ==="
    echo "1. Review each [Unverified] claim"
    echo "2. Attempt to verify against codebase or Apple docs"
    echo "3. Update tags to [Verified-Code] or [Verified-Apple] if evidence found"
    echo "4. Document why verification impossible if claim must remain [Unverified]"
fi

echo ""
echo "Tip: Run 'make search PATTERN=\"claim text\"' to verify specific claims"