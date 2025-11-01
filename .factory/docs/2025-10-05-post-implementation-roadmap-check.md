## Status Check Against Master Plan

### Phase 1A – Import Hygiene
- ✅ Security scope handling centralized via `SecurityScopedAccessing` (confirmed in `FileImportProcessor` + `LibraryImportService`).
- ✅ Track metadata now persists `sourceURL*` fields and `trackExists` predicate references them (`TrackDataActor.swift`).
- ⚠️ SwiftData migration/backfill plan for existing data not yet implemented; `Track` schema update relies on future migration work.
- ⚠️ `ImportSession.copyFile` still manages scopes directly and should adopt the accessor in later consolidation.

### Phase 1B – Crash & Logging Hygiene
- ❌ `fatalError("Unable to create fallback DataManager container")` remains (`DataManager.swift:779`).
- ❌ Numerous production `print()` calls persist across audio, data, and UI layers (see `AVAudioEngineAdapter.swift`, `AudioSessionManager.swift`, `PlaybackStateManager.swift`, multiple views).
- ❌ Force-unwrap sites (e.g., `SearchCache.swift:237`) still pending audit.

### Phase 1C – Concurrency Cleanup
- ❌ `FormatDetectionService` stays `@MainActor`; metadata extraction still hops to main actor. Concurrency stress tests absent.

### Later Phases (Unchanged)
- Phase 2 structural decompositions (AudioMonitor, PlaybackDiagnostics, AudioEngineFacade, UI pagination) untouched.
- Phase 3 data-layer pagination/perf, Phase 4 testing/CI foundation, and Phase 5 observability/docs remain outstanding per `refactor/refactor.md`.

## Recommended Next Actions
1. Kick off Phase 1B: replace `print` usage with the central logger, remove `fatalError`, and audit force unwraps with accompanying tests.
2. Plan SwiftData migration/backfill for existing tracks and align remaining import components (`ImportSession`) with the accessor abstraction.
3. Revisit `FormatDetectionService` isolation to unblock Phase 1C once crash/logging cleanup is underway.