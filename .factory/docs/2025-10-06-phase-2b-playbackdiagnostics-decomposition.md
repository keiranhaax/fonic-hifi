## Overview
Phase 2B targets the 1,500+ line `PlaybackDiagnostics.swift` god file by splitting it into focused units while keeping the public surface intact. We will reorganize supporting types, isolate analysis/formatting logic, and add a regression test suite so future refactors remain safe.

## Implementation Steps
1. **Create diagnostics subfolder**
   - Introduce `Fonic HiFi/Core/Audio/Diagnostics/PlaybackDiagnostics/` to house the refactored files.
   - Update the Xcode project to remove the old `PlaybackDiagnostics.swift` reference and add the new files.

2. **Core struct file**
   - Move the `PlaybackDiagnostics` stored properties, initializer, and basic snapshots into `PlaybackDiagnosticsCore.swift`.
   - Ensure all stored properties remain `public` and default arguments are preserved so existing call sites compile without changes.

3. **Analysis extensions**
   - Extract computed properties (`healthSummary`, `priorityIssues`, `systemScore`, `dashboardStatus`, etc.) into `PlaybackDiagnosticAnalyzers.swift` as a `public extension PlaybackDiagnostics`.
   - Keep helper methods that derive metrics (e.g., `priorityIssues`) together and document any assumptions inline where clarification is needed.

4. **Formatting/export extensions**
   - Move presentation helpers (`generateExecutiveSummary`, `generateTechnicalReport`, `exportForAnalysis`) into `PlaybackDiagnosticFormatters.swift`.
   - Ensure shared private helpers (like summary builders) stay alongside these methods to avoid duplication.

5. **Supporting model types**
   - Relocate the numerous nested data models/enums (e.g., `DiagnosticHealthStatus`, `AudioEngineInfo`, `PerformanceTrendSummary`, `DiagnosticIssue`, etc.) into `PlaybackDiagnosticModels.swift`.
   - Retain existing access levels (`public`) and keep cross-referenced comments (e.g., `IssueSeverity` defined elsewhere).
   - Move the `TrendDirection`, `TimeInterval`, and `DateFormatter` extensions into `PlaybackDiagnosticUtilities.swift` to keep the analyzer/formatter files lean.

6. **Call-site review**
   - Use `rg` to confirm only `AudioMonitor` and other diagnostics components consume these APIs; no code changes should be required beyond the file moves.
   - Verify no type name collisions or missing imports arise after the split.

7. **Unit tests**
   - Add `PlaybackDiagnosticsTests.swift` covering:
     - `systemScore` and `dashboardStatus` computations for a few representative scenarios.
     - `generateExecutiveSummary` and `generateTechnicalReport` basic formatting (presence of key strings).
   - Reuse existing diagnostic model structs to build fixtures; prefer small helper builders inside the test target.

## Verification
- Run `make test` to ensure the new test suite passes and no regressions are introduced.
- Confirm the build succeeds (no warnings about missing sources) via `make build` if needed depending on test output.