# Research & Technical Analysis

**Feature**: Fonic HiFi Critical Improvements
**Date**: 2025-09-26
**Status**: Complete

## Executive Summary
This document consolidates research findings from the fonic-hifi-codebase-guide.md analysis (10 AI agents) and current codebase examination. All technical decisions are based on Swift 6.2 concurrency requirements, iOS 26 APIs, and the need to support 100k+ track libraries with bit-perfect playback.

## Critical Issues Analysis

### 1. Swift 6 Concurrency Violations

**Issue**: Multiple concurrency violations causing crashes
- `AudioSessionManager` uses `DispatchQueue.main.async` followed by `Task`, violating Swift 6 actor rules
- Audio callbacks dispatch to main thread without proper actor isolation
- Combine subjects accessed from multiple threads

**Decision**: Adopt `Task { @MainActor in }` pattern throughout
**Rationale**: Swift 6 strict concurrency requires actor-aware transitions
**Alternatives considered**:
- Keep DispatchQueue: Rejected - not Swift 6 compliant
- Custom executors: Rejected - unnecessary complexity

### 2. Remote Command Support

**Issue**: Control Center and lock screen controls non-functional
- `enableRemoteCommands()` never called during initialization
- Missing Now Playing info updates
- No command target setup

**Decision**: Initialize remote commands in `AudioEngineFacade.initialize()`
**Rationale**: Central initialization ensures proper lifecycle management
**Alternatives considered**:
- Separate RemoteCommandManager: Rejected - adds unnecessary indirection
- View-level initialization: Rejected - violates separation of concerns

### 3. Memory Management Issues

**Issue**: Memory leaks during engine switching
- AudioKit resources not properly released
- Timers not cancelled in deinit
- Strong reference cycles in callbacks

**Decision**: Implement proper cleanup with `[weak self]` capture lists
**Rationale**: Prevents retain cycles while maintaining Swift 6 sendability
**Alternatives considered**:
- Manual retain/release: Rejected - not idiomatic Swift
- Unowned references: Rejected - can crash if object deallocated

### 4. Performance Bottlenecks

**Issue**: UI freezes during large library operations
- File I/O on @MainActor in `LibraryImportService`
- Fetching all tracks with `Int.max` limit
- Synchronous metadata extraction

**Decision**: Move I/O to background actors, implement pagination
**Rationale**: Keeps UI responsive while maintaining data consistency
**Alternatives considered**:
- GCD queues: Rejected - not actor-safe
- Operation queues: Rejected - overcomplicated for this use case

### 5. Missing Data Relationships

**Issue**: SwiftData queries fail for albums/artists
- Missing `@Relationship` macros
- Computed properties return placeholders
- No inverse relationships defined

**Decision**: Add bidirectional `@Relationship` annotations
**Rationale**: SwiftData requires explicit relationships for queries
**Alternatives considered**:
- Manual relationship management: Rejected - error-prone
- Denormalization: Rejected - data consistency issues

## Technical Decisions

### Threading Architecture

**Decision**: Three-actor system
```swift
@MainActor: UI, AudioEngineFacade, ViewModels
@ModelActor: SwiftData operations (TrackDataActor)
Background: File I/O, metadata extraction
```

**Rationale**: Clear isolation boundaries prevent race conditions
**Implementation Pattern**:
```swift
// Audio callback to UI
Task { @MainActor [weak self] in
    self?.updateUI()
}

// Data operations
await trackDataActor.performDatabaseOperation()

// File I/O
Task.detached {
    let data = await loadFile()
    await MainActor.run { updateUI(data) }
}
```

### Error Handling Strategy

**Decision**: Layered error handling
1. Replace `fatalError` with thrown errors
2. Catch at service boundaries
3. Present user-friendly messages at UI layer

**Rationale**: Prevents crashes while maintaining debuggability
**Error Types**:
- `AudioEngineError`: Playback failures
- `ImportError`: File/metadata issues
- `DataError`: SwiftData operations

### Performance Optimization

**Decision**: Multi-level optimization
1. **Pagination**: 100-item pages for large queries
2. **Caching**: LRU cache for frequently accessed tracks
3. **Batching**: Progress updates every 0.2s
4. **Lazy loading**: Load metadata on demand

**Rationale**: Balances memory usage with responsiveness
**Targets**:
- Library search: <150ms for 100k tracks
- Memory usage: <200MB typical operation
- UI: Consistent 60fps

### Monitoring Implementation

**Decision**: Lightweight metrics collection
- Audio latency via `AudioMonitor`
- Memory tracking via `os_proc_available_memory()`
- Crash tracking via custom logger

**Rationale**: No external dependencies, minimal overhead
**Alternatives considered**:
- Firebase: Rejected - privacy concerns
- Custom analytics: Rejected - overcomplicated

## Implementation Priority

### Week 1: Stability (Critical)
1. Fix concurrency violations (FR-001, FR-005)
2. Enable remote commands (FR-002)
3. Handle interruptions (FR-003)
4. Replace fatal errors (FR-004)
5. Standardize logging (FR-006)

### Week 2-3: Performance (High)
1. Async file I/O (FR-007)
2. Add relationships (FR-008)
3. Optimize queue (FR-009)
4. Implement pagination (FR-010)
5. Batch updates (FR-011)

### Week 4: Architecture (Medium)
1. Consolidate sessions (FR-015)
2. Fix memory leaks (FR-016)
3. Validate bit-perfect (FR-017)
4. User experience (FR-025-028)

## Risk Mitigation

### Risk 1: Breaking existing functionality
**Mitigation**: Incremental changes with feature flags

### Risk 2: Performance regression
**Mitigation**: Profile before/after each optimization

### Risk 3: Data migration issues
**Mitigation**: Backup before relationship changes

### Risk 4: Audio glitches
**Mitigation**: Extensive device testing before release

## Platform-Specific Considerations

### iOS 26 Requirements
- Use native `.glassEffect()` without fallbacks
- Assume iOS 26 APIs always available
- No backwards compatibility code

### Swift 6.2 Compliance
- Enable strict concurrency checking
- All types must be Sendable or @unchecked Sendable
- Actor isolation must be explicit

### Device Constraints
- iPhone 16 Pro as primary target
- Support background audio
- Handle audio route changes
- Respect low power mode

## Validation Criteria

### Success Metrics
- \u2705 Crash rate < 0.1%
- \u2705 App launch < 2 seconds
- \u2705 Audio latency < 50ms
- \u2705 Memory < 200MB typical
- \u2705 Search < 150ms for 100k tracks

### User Experience
- \u2705 No UI freezes during import
- \u2705 Immediate remote command response
- \u2705 Smooth 60fps scrolling
- \u2705 Clear error messages
- \u2705 Background playback works

## Conclusion

All technical decisions have been validated against the requirements and existing codebase. The three-actor architecture with proper isolation boundaries will eliminate concurrency crashes. Performance optimizations will handle 100k+ track libraries smoothly. The implementation can proceed to Phase 1 design.