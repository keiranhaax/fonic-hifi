## Goal
Automate the Phase 3C “manual validation” step so the AI agent can deterministically verify the streaming import pipeline without human intervention.

## Proposed Solution
1. **Add an Import Validation Harness**
   - Create a new XCTest case (e.g., `ImportValidationScenarioTests`) under `Fonic HiFiTests/` that orchestrates an end-to-end import run mirroring the manual checklist (large nested tree, duplicate mix, varying file sizes).
   - Leverage helpers to build temporary directory trees with configurable depth/width, file size patterns (small, large), and intentional duplicates.

2. **Scenario Coverage**
   - **Nested Volume Scenario**: reuse the existing 84-file generator but extend it to parameterize depth and breadth; assert 100% completion, zero errors, and verify throughput metrics increase.
   - **Duplicate Mix Scenario**: pre-seed TrackDataActor with a subset of files, run import, assert duplicates skipped and errors logged with “Duplicate” messaging; validate library count unchanged.
   - **Permission-Stress Scenario**: mix scoped/unscoped URLs (simulate via generated bookmarks) and ensure security scopes are released (existing discover helper already verifies – reassert).

3. **Metrics & Logging Assertions**
   - Capture log output via `LogCapture` utility (existing or lightweight test-only helper) to assert discovery/progress metrics fire at expected intervals.
   - Validate new metrics counters (success, failure, elapsed) reported in `LibraryImportService`.

4. **Reusable Test Utilities**
   - Factor current nested-directory helper into `Fonic HiFiTests/Support/ImportTestFixtures.swift` to share scenario builders and reduce duplication.
   - Add helper to seed TrackDataActor with manufactured metadata for duplicate testing.

5. **CI/Automation Integration**
   - Ensure new scenarios run via `make test`; update `tasks.md` Phase 3C bullet to reference automated validation.

## Verification
- Run `make lint` and `make test`. 
- Confirm new scenario tests pass and metrics assertions hold.
- Document automation completion in `tasks.md`.
