## Goal
Advance Phase 2 of the refactor roadmap by completing the diagnostics/audio decomposition track and preparing for subsequent structural work called out in `refactor/refactor.md`.

## Scope
1. **Finalize Track A diagnostics split**
   - Finish modularizing `BitPerfectValidator` by tightening the new collaborators’ APIs, wiring them into the project file, and ensuring existing call sites/tests stay green.
   - Extract any remaining shared types/utilities referenced by Audio/Diagnostics modules into dedicated files where plan calls for separation.
   - Add targeted unit coverage for the newly separated collaborators (device manager, processing analyzer, recommendation engine) to safeguard behaviour before moving to the next refactor stream.

2. **Prepare for Library presentation modernization (Phase 2F preview)**
   - Audit current `LibraryView` to map dependencies on `DataManager` pagination and `LibraryViewModel` so that upcoming work can proceed smoothly once diagnostics track is complete.
   - Document required changes (in code comments or TODO tracker) without modifying files yet.

3. **Readiness for Phase 3 pagination work**
   - Capture notes on how the diagnostics refactor intersects with DataManager pagination to avoid conflicts later.

## Deliverables
- Clean modular diagnostics files with tests and updated project references (no behaviour regressions).
- Short internal note outlining LibraryView refactor touchpoints (kept in task tracker or developer notes).
- Updated TODO entries reflecting completed diagnostics tasks and upcoming LibraryView/pagination items.

## Out of Scope
- Making structural changes to LibraryView/DataManager right now (only analysis/prep).
- CI/test scaffolding, broader logging cleanup, or documentation updates from later phases.

## Validation
- `make test` must pass after diagnostics adjustments.
- No new lint blockers introduced (acknowledging legacy warnings already tracked).
