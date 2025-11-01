## Overview
Focus on three parallel tracks aligned with refactor roadmap: (1) decompose oversized diagnostics files (`AudioMonitor`, `BitPerfectValidator`), (2) modernize library presentation flow to use view models + pagination helpers, (3) establish CI/testing scaffolding while cleaning up remaining hygiene (debug `fatalError`, lingering `print`).

## Track A – Diagnostics Decomposition
1. **Extract shared types**
   - Create `Core/Audio/Diagnostics/Monitoring/AudioMonitoringTypes.swift` for structs/enums/protocols currently embedded in `AudioMonitor.swift`.
   - Introduce lightweight protocols (`SystemMetricsCollecting`, `EngineMetricsCollecting`, `AlertManaging`, `AudioProfiling`) to formalize responsibilities.
2. **Split collectors & alert logic**
   - Move system/engine metric loops into `SystemMetricsCollector.swift` and `EngineMetricsCollector.swift` implementing new protocols.
   - Extract alert configuration + evaluation into `AudioAlertManager.swift`.
   - Isolate profiling helpers into `AudioPerformanceProfiler.swift` (reusing existing profiler logic or scaffolding if not present).
3. **Refactor orchestrator**
   - Slim `AudioMonitor.swift` to <400 LOC by composing the new collaborators via dependency-injected initializers with default implementations.
   - Update imports/callers to use the reorganized API (no behavior change).
4. **BitPerfectValidator split**
   - Repeat pattern: move data types to `BitPerfectValidationTypes.swift`, analysis routines to `BitPerfectAnalyzers.swift`, and reporting to `BitPerfectReports.swift`; leave orchestrator minimal.
5. **Unit tests**
   - Add targeted tests (`AudioMonitoringCollectorsTests`, `BitPerfectValidatorTests`) verifying collector outputs, alert thresholds, and validator decisions using fakes.
6. **Regression check**
   - Run `make lint` and `make test` to confirm suite still passes.

## Track B – Library Presentation Modernization
1. **Assess current bindings**
   - Review `LibraryView.swift` and related ViewModels to map existing `@Query` usage and `DispatchQueue.main.async` hops.
2. **Introduce pagination-aware view model pipeline**
   - Ensure `LibraryViewModel` exposes async pagination API backed by `PaginatedModelFetch` (already implemented in Phase 3A).
   - Refactor `LibraryView` to consume view-model state via `@StateObject` / `@Environment` injection; remove direct SwiftData queries.
   - Replace `DispatchQueue.main.async` with `Task { @MainActor … }` or view-model published updates.
3. **UI updates**
   - Ensure loading/error/empty states align with new data flow; reuse glass helpers where applicable.
4. **Coverage**
   - Add/extend tests (e.g., `LibraryViewModelTests`, SwiftUI snapshot or state-driven tests) to validate pagination and refresh behavior.
5. **Regression check**
   - Run `make lint` and `make test`.

## Track C – CI & Hygiene Completion
1. **Resolve remaining hygiene**
   - Convert the debug app’s lingering `fatalError` into a guarded logging path or `preconditionFailure` limited to debug builds.
   - Audit repository for remaining `print` statements outside ignored paths; replace with `Log` categories per plan.
2. **CI scaffolding**
   - Add `.github/workflows/ci.yml` executing `make lint`, `make build`, `make test`.
   - Ensure Makefile targets already cover exit codes appropriately.
3. **Coverage reporting**
   - Capture current coverage into `docs/testing/coverage-YYYY-MM-DD.md` (if per plan) once tests expanded.
   - Update `STATUS.md` with phase progress (Phase 2 foundation, tests, CI status) post work.
4. **Documentation artifacts**
   - Add ADR stubs if mandated during this phase (e.g., `docs/adr/002-audio-monitor-decomposition.md`).
5. **Final verification**
   - Run full suite via `make lint` and `make test` to confirm CI reproducibility locally.

## Dependencies & Coordination
- Complete Track A extractions before expanding tests relying on new modules.
- Track B refactor should align with pagination helpers delivered in Phase 3A to avoid duplicate logic.
- Track C’s CI workflow should be committed only after lint/test pass with new diagnostics and library changes.

## Deliverables
- New modular diagnostics files with unit tests and reduced LOC.
- Library presentation layer using view model + pagination pipeline, no direct SwiftData queries or manual main queue hops.
- Operational CI workflow, updated STATUS.md, coverage doc, and resolved hygiene issues.
- Verified by passing `make lint` and `make test`.
