# Work Package 4 candidate map

Baseline: `main` at `459db9bfd18d17960e8fd2ff8defc4701085532e`.

## Retained opportunities

| ID | Opportunity | Priority | Refactor risk | Why retained |
|---|---|---:|---:|---|
| WP4-R01 | Consolidate the SwiftUI audio presentation-state boundary and remove view-owned mirrors of engine/queue state | P0 | High | Active root-to-view path; mixed Observation/Combine/custom-environment ownership; 23 files reference `AudioEngineFacade`; current SwiftUI tests do not verify invalidation. |
| WP4-R02 | Separate queue mutations from delegate notification and persistence side effects | P0 | Medium | Active queue owner; logical mutations can trigger repeated synchronous snapshot validation/encoding/writes; existing tests form a good characterization base but cannot count persistence requests. |
| WP4-R03 | Give each library section explicit request ownership and distinguish initial load from pagination | P0 | Medium | Active Library path; local `isLoading` does not become stored state until after await; no generation/cancellation guard; one global load flag drives both blocking and tail UI. |
| WP4-R04 | Move file-system operations and operation state out of `FileManagerView` | P1 | Medium | Active Settings path; ten state fields, direct singleton I/O, detached copy work, error swallowing, and UIKit presentation live in one SwiftUI view; no direct tests. |
| WP4-R05 | Create one `TrackDataActor` insertion kernel, then split pure mapping/support concerns before any actor boundary redesign | P1 | Medium | Active 1,218-line actor with 39 functions across five domains; single and batch creation duplicate persisted mapping and relationship logic; characterization tests exist. |
| WP4-R06 | Own `AsyncStream` producer lifetime and cancellation in `FileImportProcessor` | P1 | Medium | Active import path; three stream builders spawn unowned producer tasks without `onTermination`; no early-termination test; Apple documents termination cleanup. |
| WP4-R07 | Use one injectable process-metrics provider instead of Mach probes inside `AVAudioEngineAdapter` | P1 | Low-Medium | Active engine duplicates system metrics responsibility; dedicated collector already exists and is tested; extraction narrows audio-engine responsibility and makes metrics deterministic in tests. |
| WP4-R08 | Compile one canonical app/widget shared-data contract | P1 | Medium | Three active contract pairs are executable-body identical today but compiled from separate roots; drift can break app/widget decoding without a compile error. |

## Rejected or deferred candidates

| ID | Candidate | Disposition | Reason |
|---|---|---|---|
| RC-01 | Split `PlaybackDiagnosticModels.swift` and `AudioMonitoringService.swift` solely because they are the two largest files | Rejected | Both are declaration aggregations with no executable functions or state/Task/I/O coupling; size alone is not enough. |
| RC-02 | Broadly decompose `AVAudioEngineAdapter` | Rejected for this work package | Audio graph, format, gapless, EQ, and completion behavior are device-sensitive. Only the isolated metrics extraction is safe to plan without Xcode/device validation. |
| RC-03 | Move `LibraryView` private row/detail views into separate files | Rejected as standalone work | File navigation would improve, but behavior, state ownership, and testability would not. Do it only while implementing WP4-R03. |
| RC-04 | Extract smart-playlist evaluation from `PlaylistDetailView` | Deferred to WP5 | The containing presentation path appears orphaned. Reachability/cleanup must be decided before investing in it. |
| RC-05 | Merge `ImportSession` and `FileImportProcessor` | Deferred to WP5 | `ImportSession` appears test-only while `FileImportProcessor` is active. Decide retention/removal before architecture work. |
| RC-06 | Split `GlassModifiers.swift` because it exceeds 500 lines | Rejected | It is an aggregation of small named modifiers without the ownership/coupling evidence required for a high-value refactor. |

## Prioritization logic

- P0: Establishes correctness-sensitive ownership boundaries that other refactors depend on.
- P1: High-value isolation work that can follow after P0 characterization tests.
- No source changes are authorized or included.
- Any P0 implementation is a significant architectural change and requires explicit user approval before editing the repository.
