# ADR 002: Audio Monitor Decomposition

- **Status**: Accepted (2025-10-10)
- **Decision Makers**: Diagnostics Working Group
- **Context**: `AudioMonitor.swift` exceeded 2,600 LOC, mixing scheduling, metrics collection, alerting, and profiling logic in a single type, which made concurrency guarantees brittle and rendered targeted testing impractical.[Verified-Code]

## Drivers

- Monitoring demanded deterministic update intervals while keeping UI publications on the main actor.[Inference]
- Alerting, analytics, and profiling evolved independently and required isolated dependencies for mocking.[Inference]
- The refactor roadmap (Phase 2A) mandated modular diagnostics components under 600 LOC each to improve maintainability and test coverage.[Verified-Code]

## Decision

1. Introduce `AudioMonitorRuntime` as the orchestration surface responsible for scheduling, engine binding, and publishing metrics or alerts through injected closures.[Verified-Code]
2. Extract scheduler and metrics responsibilities into dedicated collaborators (`AudioMetricsScheduler`, `AudioMonitorMetricsCollector`, `AudioSessionAnalytics`, and `AudioPerformanceProfiler`), all injected into the runtime.[Verified-Code]
3. Define the alert boundary via the `AudioAlertManaging` protocol and concrete `AudioAlertManager`, allowing alert rules to evolve without reintroducing large conditional blocks inside the runtime.[Verified-Code]
4. Keep `AudioMonitor` as a thin facade that wires dependencies, proxies lifecycle calls, and persists runtime objects while remaining under the 600 LOC threshold (current size 494 LOC).[Verified-Code]
5. Update diagnostics test suites to target each extracted collaborator and add focused checks for runtime scheduling, engine switching, and profiling flows.[Verified-Code]

## Consequences

- ✅ Scheduling logic now lives in `AudioMetricsScheduler`, enabling deterministic timer tests without launching the full monitor.[Verified-Code]
- ✅ Metrics and alert collectors can be mocked independently, which improved coverage across `AudioMonitoringCollectorsTests`, `AudioPerformanceAdvisorTests`, and `AudioMonitorRuntimeTests`.[Verified-Code]
- ✅ UI publishing is easier to reason about because the runtime exposes explicit closures for metrics, health status, and alerts.[Verified-Code]
- ⚠️ The facade must be kept up to date whenever new diagnostics collaborators appear; failure to wire dependencies could lead to runtime nil-injection errors. Regression tests guard against this by exercising the facade setup.[Inference]

## Implementation Notes

- `AudioMonitor` now holds references to the decomposed collaborators and forwards lifecycle events to `AudioMonitorRuntime`.[Verified-Code]
- `AudioMonitorRuntime` controls scheduler cadence, engine attachment, profiling state, and alert evaluation, ensuring all UI updates remain on the main actor.[Verified-Code]
- Profiling samples stream through `AudioPerformanceProfiler`, decoupling advanced metrics from the main runtime path.[Verified-Code]
- Alert resets and session analytics initialization happen atomically at the runtime level, preventing the stale state issues observed prior to the refactor.[Verified-Code]

## Alternatives Considered

- **Lazy splitting**: moving only profiling into a helper while leaving scheduling and alerts in the facade. Rejected because unit tests would still need to exercise large conditional blocks, limiting coverage gains.[Inference]
- **Combine-based streams**: Replacing scheduler callbacks with Combine publishers. Rejected for now to avoid additional dependencies and keep the monitoring loop test-friendly.[Inference]

## Follow-up Work

- Monitor runtime metrics counters (planned in ADR 003) to ensure scheduling intervals remain stable under heavy load.[Inference]
- Evaluate whether profiling samples should stream through `AsyncStream` once additional diagnostics subscribers appear.[Inference]
