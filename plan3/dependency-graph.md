# Task Dependency Graph

## Visual Dependency Map

```
P0-1: LibraryImportService ──┬──> Thread Perf Checker ──> Build Validation
                              │
P0-2: MPNowPlayingInfo ───────┼──> Device Testing ────────> Build Validation
                              │
P0-3: try! Removal ───────────┤
                              │
P0-4: Mach API Guard ─────────┘
```

## Critical Path

**Longest path:** P0-1 (4-6 hours) → Thread Perf Checker (30 min) → Build Validation

**Parallel execution possible:** After P0-1 complete, P0-2, P0-3, P0-4 can run concurrently

## Execution Order (Optimal)

1. **P0-1 first** (BLOCKING) - LibraryImportService (highest impact, enables Thread Perf Checker validation)
2. **Enable Thread Performance Checker** (BLOCKING) - Required for validation
3. **P0-2, P0-3, P0-4 in parallel** (CONCURRENT) - Independent fixes
4. **Device Testing** (BLOCKING) - Requires physical device, 1-2 hour session
5. **Instruments Profiling** (BLOCKING) - Final validation
6. **P1 Tasks** (FUTURE) - After all P0 complete

## Blockers

| Task | Blocks | Reason |
|------|--------|--------|
| P0-1 | Thread Perf Checker validation | Can't verify threading until refactored |
| P0-1 | Pagination integration (P1) | Requires background processing |
| Device Testing | Production release | Critical scenarios only testable on device |
| All P0 fixes | P1 optimization tasks | Foundation must be solid first |

## Time Estimates by Phase

| Phase | Time | Can Parallelize |
|-------|------|-----------------|
| Phase 0: Setup | 30 min | No |
| Phase 1: P0-1 | 4-6 hours | No (blocks others) |
| Phase 2: P0-2 | 2-3 hours | Yes (after P0-1) |
| Phase 3: P0-3 | 3-4 hours | Yes (after P0-1) |
| Phase 4: P0-4 | 30 min | Yes (after P0-1) |
| Phase 5: Validation | 2-3 hours | No (needs all P0 complete) |
| Phase 6: Documentation | 30 min | No |
| **Total** | **13-18 hours** | - |
