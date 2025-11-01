## Objectives
1. Complete remaining Phase 2A/2D decomposition work for diagnostics and Liquid Glass subsystems while preserving actor safety.  
2. Finish Phase 2E/2F concurrency and UI migration tasks so LibraryView consumes paginated data via LibraryViewModel.  
3. Address Phase 3A SwiftData counting inefficiency and establish Phase 5 CI/coverage scaffolding without regressing existing suites.

## Workstream A – Diagnostics Subsystem Cleanup
- **AudioMonitor split**: Extract timer/scheduling logic into `AudioMetricsScheduler` that uses `Task`/`AsyncSequence`; move metrics history/alert analysis into lightweight structs; keep monitor as thin orchestrator.  
- **Replace DispatchQueue timers**: Introduce `Task`-driven periodic loops with cancellation tokens; ensure teardown cancels tasks cleanly.  
- **Unit coverage**: Add targeted tests verifying scheduler cadence, cancellation, and that collectors receive callbacks in deterministic order (mock collectors + clock).  

## Workstream B – Liquid Glass & BitPerfect decomposition (Phase 2D)
- **LiquidGlassDesignSystem**: Break into modifiers (`GlassModifiers.swift`), components (`GlassControls.swift`), and preview/demo helpers (`GlassShowcase.swift`); migrate deprecated API usage to iOS 26 `.glassEffect()`.  
- **BitPerfectValidator**: Split analyzer/result builders into `BitPerfectAnalyzerCore`, `BitPerfectDeviceInspector`, etc.; add focused tests for validation branches (e.g., mismatched sample rate, DAC compatibility).  
- **Shared utilities**: Relocate reusable scoring math into `DiagnosticsScoring.swift` for reuse by monitor tests.

## Workstream C – Concurrency Cleanup & UI Boundary (Phase 2E/2F)
- **Replace residual DispatchQueue.main.async**: Update BottomSearchBar, AccessibilityEnhancements, and any remaining views to use `Task { @MainActor in … }` or `MainActor.run`.  
- **LibraryView migration**: Route data access through LibraryViewModel by injecting repositories; swap direct `@Query` with async pagination calls from `PaginatedModelFetch`.  
- **UI state wiring**: Ensure LibraryView consumes `@ObservedObject` view model state and supports incremental loading, preserving accessibility features.  
- **Tests**: Expand LibraryViewModel tests for pagination behavior (loading next page, duplicate avoidance) and concurrency (ensure Task cancellation on refresh).

## Workstream D – SwiftData Count Helper (Phase 3A)
- Replace the materializing `fetchCount` with a dedicated `FetchDescriptor` using `persistentModelContext.fetchCount(_:)` or bespoke aggregate query.  
- Add tests confirming large datasets don’t allocate full arrays (assert minimal fetch time using instrumentation/mocks where feasible).

## Workstream E – CI & Observability (Phase 5)
- **Automation scripts**: Add GitHub Actions workflows running `make lint`, `make build`, `make test`; cache dependencies where safe.  
- **Coverage reporting**: Integrate `make coverage` (or swift test coverage flags) with summary artifact upload.  
- **Status tracking**: (Pending user approval per documentation rules) prepare STATUS.md refresh summarizing completed phases once the above work lands.

## Verification Plan
1. `make lint` to ensure style/concurrency rules after major refactors.  
2. `make test` for full regression plus new suites (AudioMonitorSchedulerTests, BitPerfectAnalyzerTests, LibraryViewModelPaginationTests).  
3. For CI pipeline, validate via `gh workflow run` dry-run or local act invocation if available.

## Risks & Mitigations
- **Large refactors touching many files**: Stage work in smaller PR-sized commits (e.g., diagnostics split first) to keep reviewable.  
- **Concurrency regressions**: Use `@MainActor` annotations and actor-isolated stores; rely on existing async tests plus new scheduler tests.  
- **CI setup**: Ensure workflows respect project rule of using `make` targets exclusively and avoid secret exposure.