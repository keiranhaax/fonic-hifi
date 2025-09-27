#!/bin/bash

# count-public-apis.sh - Count public APIs in Swift files
# Usage: ./count-public-apis.sh [directory]

DIR="${1:-.}"
SWIFT_FILES_COUNT=0
PUBLIC_CLASSES=0
PUBLIC_STRUCTS=0
PUBLIC_FUNCTIONS=0
PUBLIC_VARS=0
PUBLIC_PROTOCOLS=0
PUBLIC_ENUMS=0

echo "=== Public API Count for Fonic HiFi ==="
echo "Searching in: $DIR"
echo ""

# Count Swift files
SWIFT_FILES_COUNT=$(find "$DIR/Fonic HiFi" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
echo "Total Swift files: $SWIFT_FILES_COUNT"

# Count public classes
PUBLIC_CLASSES=$(grep -r "^public class\|^public final class\|^open class" "$DIR/Fonic HiFi" --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')

# Count public structs
PUBLIC_STRUCTS=$(grep -r "^public struct" "$DIR/Fonic HiFi" --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')

# Count public functions (approximate - may include some methods)
PUBLIC_FUNCTIONS=$(grep -r "public func\|public static func" "$DIR/Fonic HiFi" --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')

# Count public variables/properties
PUBLIC_VARS=$(grep -r "public var\|public let\|public static" "$DIR/Fonic HiFi" --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')

# Count public protocols
PUBLIC_PROTOCOLS=$(grep -r "^public protocol" "$DIR/Fonic HiFi" --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')

# Count public enums
PUBLIC_ENUMS=$(grep -r "^public enum" "$DIR/Fonic HiFi" --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "=== Public API Breakdown ==="
echo "Public Classes:   $PUBLIC_CLASSES"
echo "Public Structs:   $PUBLIC_STRUCTS"
echo "Public Protocols: $PUBLIC_PROTOCOLS"
echo "Public Enums:     $PUBLIC_ENUMS"
echo "Public Functions: $PUBLIC_FUNCTIONS"
echo "Public Vars/Lets: $PUBLIC_VARS"

TOTAL_PUBLIC=$((PUBLIC_CLASSES + PUBLIC_STRUCTS + PUBLIC_PROTOCOLS + PUBLIC_ENUMS + PUBLIC_FUNCTIONS + PUBLIC_VARS))
echo ""
echo "Total Public APIs: $TOTAL_PUBLIC"

# Find major components (classes/structs with significant public APIs)
echo ""
echo "=== Major Components (files with 3+ public declarations) ==="
for file in $(find "$DIR/Fonic HiFi" -name "*.swift" 2>/dev/null); do
    COUNT=$(grep -c "^public\|^open" "$file" 2>/dev/null || echo 0)
    if [ "$COUNT" -ge 3 ]; then
        FILENAME=$(basename "$file")
        echo "  $FILENAME: $COUNT public declarations"
    fi
done

echo ""
echo "Note: These are approximate counts. Manual review recommended for accuracy."