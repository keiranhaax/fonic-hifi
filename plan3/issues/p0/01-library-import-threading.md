# P0-1: LibraryImportService Threading Fix

**Priority:** P0 (Critical - Blocks production release)
**File:** `Data/Services/LibraryImportService.swift:15`
**Issue:** `@MainActor` annotation blocks UI thread during file I/O operations
**Impact:** 10 files = 500ms-2s UI freeze, poor user experience
**Risk:** App Store rejection for unresponsive UI

## Current State

```swift
@MainActor  // ← Blocks UI for ALL operations
public final class LibraryImportService: ObservableObject {
    @Published var progress: Double = 0.0
    // ... 9 other @Published properties

    private func processSingleFile(_ url: URL) async {
        // FileManager operations on main thread
        let exists = FileManager.default.fileExists(atPath: url.path)
        // Metadata extraction on main thread
        let metadata = try await extractMetadata(from: url)
    }
}
```

## Root Cause

All `@Published` properties require `@MainActor`, forcing entire class onto main thread. File I/O and metadata extraction (heavy operations) block UI updates.

## Solution

Create background actor for file processing, keep `@MainActor` only for UI-bound properties.

```swift
actor FileImportProcessor {
    func processFiles(_ urls: [URL]) async -> [ImportResult] {
        // Heavy I/O work here (off main thread)
    }
}

@MainActor
class LibraryImportService: ObservableObject {
    @Published var progress: Double = 0
    private let processor = FileImportProcessor()

    func importFiles(from urls: [URL]) async {
        let results = await processor.processFiles(urls)
        self.progress = 1.0  // UI update on main thread
    }
}
```

## Dependencies

- **Blocks:** None (can start immediately)
- **Blocked by:** Pagination integration (P1 task)

## Time Estimate

- Implementation: 3-4 hours
- Testing: 1-2 hours
- **Total:** 4-6 hours

## Risk Assessment

- **HIGH:** Security-scoped resources must cross actor boundary
  - **Mitigation:** `startAccessingSecurityScopedResource()` in actor context
- **HIGH:** Complex existing logic (342 lines modified in b7e6743)
  - **Mitigation:** Incremental refactor with tests at each step
- **MEDIUM:** Potential state synchronization issues
  - **Mitigation:** Use async stream for progress updates

## Success Criteria

- [ ] FileImportProcessor actor created
- [ ] LibraryImportService refactored to delegate file I/O
- [ ] Thread Performance Checker: 0 warnings
- [ ] Manual test: Import 50 files, UI remains responsive
- [ ] Tests pass
- [ ] `scripts/verify-fixes.sh` shows P0-1 ✅

## Rollback Procedure

```bash
bash scripts/rollback-p0-1.sh
# Restores @MainActor version, removes FileImportProcessor
# Rollback time: ~30 seconds
```

## Implementation Checklist

### Phase 1: Create Actor
- [ ] Create `Fonic HiFi/Data/Actors/FileImportProcessor.swift`
- [ ] Implement `processFiles(_:) async -> [ImportResult]`
- [ ] Handle security-scoped resources in actor context
- [ ] Add comprehensive documentation

### Phase 2: Refactor Service
- [ ] Keep `@MainActor` on LibraryImportService class
- [ ] Add `private let processor = FileImportProcessor()`
- [ ] Delegate file I/O to processor
- [ ] Update progress from results

### Phase 3: Testing
- [ ] Create `LibraryImportServiceTests.swift`
- [ ] Test threading safety
- [ ] Test progress updates
- [ ] Test error handling

### Phase 4: Validation
- [ ] Enable Thread Performance Checker
- [ ] Import 50 files, verify 0 warnings
- [ ] Manual UI responsiveness test
- [ ] Run `scripts/verify-fixes.sh`

## Related Issues

- **P1:** Pagination integration (will use this actor pattern)
- **P1:** Import cancellation support (future enhancement)
