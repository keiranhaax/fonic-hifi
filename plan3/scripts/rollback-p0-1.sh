#!/bin/bash
# Rollback P0-1: LibraryImportService Threading

echo "⏪ Rolling back LibraryImportService to @MainActor version"

# Stash current changes
git stash push -m "WIP: LibraryImportService threading fix - $(date +%Y-%m-%d_%H-%M-%S)"

# Restore from last commit
git checkout HEAD -- "Fonic HiFi/Data/Services/LibraryImportService.swift"

# Remove FileImportProcessor if created
if [ -f "Fonic HiFi/Data/Actors/FileImportProcessor.swift" ]; then
    git rm "Fonic HiFi/Data/Actors/FileImportProcessor.swift" 2>/dev/null || true
    rm -f "Fonic HiFi/Data/Actors/FileImportProcessor.swift"
    echo "✅ Removed FileImportProcessor.swift"
fi

echo "✅ Rolled back. Changes in stash."
echo "To re-apply: git stash list && git stash pop"
