# Tasks: Fonic HiFi Critical Improvements

**Input**: Design documents from `/specs/002-to-implement-this/`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/, quickstart.md

## Execution Flow Summary
- Total Tasks: 48
- Parallel Tasks: 21 marked with [P]
- Priority: Week 1 (Critical) → Week 2-3 (Performance) → Week 4 (Architecture)
- No test infrastructure per requirements

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Convention
- iOS mobile app: `Fonic HiFi/` for source code
- Specifications: `specs/002-to-implement-this/`

---

## Phase 3.1: Project Setup & Configuration (3 tasks)

- [X] T001 Verify project builds with Swift 6.2 strict concurrency checking enabled
- [X] T002 [P] Configure Xcode project settings for iOS 26.0 minimum deployment target
- [X] T003 [P] Update Info.plist to ensure audio background mode is properly configured

## Phase 3.2: Week 1 - Critical Stability Fixes (FR-001 to FR-006) (12 tasks)

### Concurrency Fixes (FR-001, FR-005)
- [X] T004 Fix actor isolation violations in `Fonic HiFi/Core/Audio/Services/AudioSessionManager.swift` - replace DispatchQueue.main.async with Task { @MainActor in }
- [X] T005 Update audio callbacks in `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift` to use Task { @MainActor in } pattern
- [X] T006 Update audio callbacks in `Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift` to use Task { @MainActor in } pattern
- [X] T007 [P] Add [weak self] capture lists to all timer callbacks in `Fonic HiFi/Core/Audio/Engine/ProgressTimerManager.swift`
- [X] T008 [P] Privatize Combine publishers in `Fonic HiFi/Core/Audio/Playback/PlaybackStateManager.swift` and expose only main-thread AnyPublishers

### Remote Commands (FR-002)
- [X] T009 Enable remote commands in `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift` initialize() method
- [X] T010 Implement remote command handlers in `Fonic HiFi/Core/Audio/Services/AudioSessionManager.swift`
- [X] T011 Add Now Playing info updates in `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift` when track changes

### Interruption Handling (FR-003)
- [X] T012 Implement audio interruption handling in `Fonic HiFi/Core/Audio/Services/AudioSessionManager.swift` with proper state restoration

### Error Handling (FR-004, FR-006)
- [X] T013 Replace all fatalError() calls with recoverable errors in `Fonic HiFi/FonicHiFiApp.swift`
- [X] T014 [P] Replace all try! with proper error handling in `Fonic HiFi/Data/Services/DataManager.swift`
- [X] T015 [P] Standardize logging using os.Logger in `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift`

## Phase 3.3: Week 2-3 - Performance Optimizations (FR-007 to FR-014) (16 tasks)

### Data Model Updates (FR-008)
- [X] T016 [P] Add @Relationship macros to `Fonic HiFi/Data/Models/Album.swift`
- [X] T017 [P] Add @Relationship macros to `Fonic HiFi/Data/Models/Artist.swift`
- [X] T018 [P] Add @Relationship macros to `Fonic HiFi/Data/Models/Track.swift`
- [X] T019 [P] Implement computed properties (trackCount, totalDuration) in `Fonic HiFi/Data/Models/Album.swift`
- [X] T020 [P] Implement computed properties (trackCount, albumCount) in `Fonic HiFi/Data/Models/Artist.swift`

### Async I/O Operations (FR-007, FR-012)
- [X] T021 Move file I/O operations off @MainActor in `Fonic HiFi/Data/Services/LibraryImportService.swift`
- [X] T022 Implement transactional import with rollback in `Fonic HiFi/Data/Services/LibraryImportService.swift`
- [X] T023 [P] Create ImportSession actor in `Fonic HiFi/Data/Services/ImportSession.swift` per data-model.md specification

### Performance Optimizations (FR-009, FR-010, FR-011, FR-013, FR-014)
- [X] T024 Implement pagination (100 items per page) in `Fonic HiFi/Data/Services/DataManager.swift` for large queries
- [X] T025 [P] Create TrackCache actor in `Fonic HiFi/Core/Audio/Cache/TrackCache.swift` with LRU eviction
- [X] T026 [P] Create SearchCache actor in `Fonic HiFi/Data/Services/SearchCache.swift` with TTL expiration
- [ ] T027 Batch progress timer updates to 0.2s intervals in `Fonic HiFi/Core/Audio/Engine/ProgressTimerManager.swift`
- [ ] T028 Optimize queue state transitions in `Fonic HiFi/Core/Audio/Queue/AudioQueueManager.swift` with cached shuffle sequences
- [ ] T029 [P] Implement AudioMetrics struct in `Fonic HiFi/Core/Audio/Diagnostics/AudioMetrics.swift` per data-model.md
- [ ] T030 [P] Implement ImportMetrics struct in `Fonic HiFi/Data/Services/ImportMetrics.swift` per data-model.md
- [ ] T031 Add background queue for metadata extraction in `Fonic HiFi/Data/Services/LibraryImportService.swift`

## Phase 3.4: Week 4 - Architecture & Quality (FR-015 to FR-028) (17 tasks)

### Architecture Improvements (FR-015, FR-016, FR-017)
- [ ] T032 Consolidate audio session management - remove duplicate session handling from engine adapters
- [ ] T033 Fix memory leaks in engine switching - add cleanup in `Fonic HiFi/Core/Audio/Factory/AudioEngineFactory.swift`
- [ ] T034 Implement real bit-perfect validation logic in `Fonic HiFi/Core/Audio/Diagnostics/BitPerfectValidator.swift`

### Contract Implementations
- [ ] T035 Implement AudioSessionManaging protocol from contracts in `Fonic HiFi/Core/Audio/Services/AudioSessionManager.swift`
- [ ] T036 Implement ImportSessionProtocol from contracts in `Fonic HiFi/Data/Services/ImportSession.swift`
- [ ] T037 Implement PlaybackCoordinating protocol from contracts in `Fonic HiFi/Core/Audio/Coordinators/PlaybackCoordinator.swift`
- [ ] T038 Implement PerformanceMonitoring protocol from contracts in `Fonic HiFi/Core/Audio/Diagnostics/PerformanceMonitor.swift`

### Queue Persistence (FR-020, FR-021)
- [ ] T039 [P] Implement queue persistence in `Fonic HiFi/Core/Audio/Queue/QueueState.swift`
- [ ] T040 Add shuffle sequence preservation in `Fonic HiFi/Core/Audio/Queue/AudioQueueManager.swift`
- [ ] T041 Implement queue restoration on app launch in `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift`

### Monitoring (FR-022, FR-023, FR-024)
- [ ] T042 [P] Implement audio latency tracking in `Fonic HiFi/Core/Audio/Diagnostics/AudioMonitor.swift`
- [ ] T043 [P] Add memory usage tracking in `Fonic HiFi/Core/Audio/Diagnostics/PerformanceMonitor.swift`
- [ ] T044 Add app launch time tracking in `Fonic HiFi/FonicHiFiApp.swift`

### User Experience (FR-025, FR-026, FR-027, FR-028)
- [ ] T045 [P] Add progress indicators for long operations in `Fonic HiFi/Presentation/Views/LibraryView.swift`
- [ ] T046 [P] Implement user-friendly error messages in `Fonic HiFi/Presentation/Views/Components/ErrorView.swift`
- [ ] T047 Ensure 60fps UI performance with frame rate monitoring
- [ ] T048 Verify background audio and Now Playing info updates work correctly

---

## Dependencies

### Critical Path
1. T001 (build verification) blocks all other tasks
2. T004-T008 (concurrency fixes) should complete before any other audio work
3. T016-T020 (data relationships) block T024 (pagination)
4. T021-T023 (async I/O) should complete before T031 (background queue)
5. T035-T038 (contract implementations) can run after respective fixes

### Parallel Execution Groups

**Group 1: Data Model Updates (can run together)**
```
Task: "Add @Relationship macros to Album.swift"
Task: "Add @Relationship macros to Artist.swift"
Task: "Add @Relationship macros to Track.swift"
Task: "Implement computed properties in Album.swift"
Task: "Implement computed properties in Artist.swift"
```

**Group 2: Cache Implementation (independent files)**
```
Task: "Create TrackCache actor with LRU eviction"
Task: "Create SearchCache actor with TTL expiration"
Task: "Implement AudioMetrics struct"
Task: "Implement ImportMetrics struct"
```

**Group 3: Monitoring (different subsystems)**
```
Task: "Implement audio latency tracking"
Task: "Add memory usage tracking"
Task: "Add progress indicators for long operations"
Task: "Implement user-friendly error messages"
```

---

## Implementation Notes

### Threading Pattern
All UI updates MUST use:
```swift
Task { @MainActor in
    // UI update code
}
```

### Memory Management Pattern
All callbacks MUST use:
```swift
timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
    guard let self = self else { return }
    // Timer code
}
```

### Error Handling Pattern
Replace:
```swift
fatalError("Something went wrong")
```
With:
```swift
throw AudioEngineError.configurationFailed("Something went wrong")
```

---

## Validation Checklist
- [x] All 28 functional requirements have corresponding tasks
- [x] All contracts have implementation tasks (T035-T038)
- [x] All entities have model update tasks (T016-T020)
- [x] Parallel tasks operate on different files
- [x] Each task specifies exact file path
- [x] No [P] tasks modify the same file
- [x] Dependencies are clearly documented
- [x] Priority matches spec (Week 1 critical, Week 2-3 performance, Week 4 architecture)

---

## Next Steps
1. Execute T001-T003 (setup) first
2. Focus on T004-T015 (Week 1 critical stability)
3. Then T016-T031 (Week 2-3 performance)
4. Finally T032-T048 (Week 4 architecture)
5. Run quickstart.md validation after each phase

**Total Effort Estimate**: 4 weeks as per specification
**Risk Areas**: Concurrency fixes (T004-T008), Data migration (T016-T020)