## Overview
- The master plan targets production readiness by addressing safety regressions, reducing oversized classes, introducing structured logging, implementing true SwiftData pagination, and establishing an automated test/CI baseline.
- Work is split into sequential phases (0–5) covering verification, safety fixes, large-scale refactors, data-layer performance, testing infrastructure, and observability/documentation.

## Key Priorities & Tasks
1. **Phase 0 Baseline**
   - Validate repo state, capture metrics (lint/build, print counts, LOC), confirm test harness status, and reproduce duplicate-import bug.
   - Produce baseline report in `docs/refactor/baseline-2025-10-07.md`.
2. **Phase 1 Safety & Hygiene**
   - Fix duplicate detection by expanding Track metadata & actor logic, add regression tests.
   - Ensure security-scoped URLs are released correctly.
   - Replace production `print()`s with `Log.logger`, remove `fatalError` paths, eliminate force unwraps.
   - Adjust format detection concurrency off the main actor and add concurrency tests.
3. **Phase 2 Structural Refactors**
   - Decompose giant audio/diagnostics classes into modular components with targeted tests.
   - Modularize `AudioEngineFacade`, split LiquidGlass and BitPerfect modules, clean up UI concurrency, and modernize Library presentation around `LibraryViewModel`.
   - Deliver updated architecture documentation and LOC reductions.
4. **Phase 3 Data Performance**
   - Implement true pagination with `PaginatedFetchDescriptor`, optimize fetch counts, update view models, and add performance tests and benchmarks.
   - Improve library statistics and import batching with bounded concurrency and logging.
5. **Phase 4 Testing & CI**
   - Configure `make test`, add support utilities, enforce lint/test in Makefile and CI workflow.
   - Build substantial unit, integration, and coverage-reporting suites targeting ≥65% coverage.
6. **Phase 5 Observability & Docs**
   - Finalize logging categories, add metrics, update CLAUDE/AGENTS/ADR/README, and capture postmortem.
   - Provide knowledge-transfer artifacts.

## Dependencies & Coordination
- Phase 1 must complete before large refactors (Phase 2) to avoid conflicts.
- Data pagination (Phase 3) depends on Phase 4’s testing scaffolding for verification.
- Documentation updates (Phase 5) trail all code changes; weekly cadence ensures alignment across workstreams.

## Risks & Mitigations
- SwiftData migrations risk data corruption → use preview branches & backups.
- Audio refactors may regress behaviour → comprehensive tests before splitting, use feature toggles.
- CI flakiness → deterministic suites, allow reruns.
- Schedule slip → overlapping phases with weekly checkpoints.

## Success Metrics
- Zero duplicate imports/security-scope warnings and elimination of crash paths (`fatalError`, force unwraps).
- Remove all production `print()`s; reduce key files below target LOC.
- Achieve ≥65% overall test coverage, ≥2× import throughput improvement, and <500 ms library pagination latency.

## Immediate Next Steps
- Execute Phase 0 verification tasks and publish baseline report.
- Initiate duplicate-detection fix and logging cleanup (Phase 1A/1B).
- Begin drafting test scaffolding and LibraryView refactor brief to unblock later phases.
- Prototype optimized `ModelContext.fetchCount` replacement for pagination work.
