# Fonic HiFi – Post-Audit Implementation Plan

_Last updated: 2025-09-28_

## 1. Context
Multiple AI assessments (Amp, Codex, Gemini, GPT-5, Grok, Opus, Qwen, Supernova, Zai) surfaced systemic issues across the audio, data, and infrastructure layers. Many critical fixes have landed (SwiftData relationships, remote command wiring, concurrency hygiene), but a focused follow-up is required to close the remaining gaps before the next stability sprint.

This document consolidates the verified outstanding items as of 2025-09-28 and groups them by urgency. File references use repository-relative paths with line numbers for quick navigation.

---

## 2. Confirmed Improvements (No Further Action Needed)
- **SwiftData relationships repaired** → `Fonic HiFi/Data/Models/Album.swift:107`, `Fonic HiFi/Data/Models/Artist.swift:57`
- **Remote commands enabled** → `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:231` (`enableRemoteCommands()` now invoked)
- **Combine publishers isolated to main thread** → `Fonic HiFi/Core/Audio/Playback/PlaybackStateManager.swift:40`

These fixes resolved the build-blocking regressions identified in December 2024 audits.

---

## 3. Outstanding Work by Priority

### Phase 1 – Crash & Build Safeguards (P0)
1. **Replace residual `try!`/fatal fallbacks**
   - `Fonic HiFi/FonicHiFiApp.swift:81`: app init still escalates to `try! DataManager()` when all fallbacks fail.
   - `Fonic HiFi/Data/DataManager.swift:614`: preview builder falls back to `try! ModelContainer`.
   - `Fonic HiFi/FonicHiFiApp_Debug.swift:32`: debug harness retains a `try! DataManager()` last-resort path.
   - **Action**: propagate errors to a user-visible failure state (alert/placeholder), ensure previews use guarded fallbacks without crashing, and give the debug harness the same graceful degradation.

2. **Guard Mach API usage**
   - `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:369`: direct Mach API calls without `#if canImport(Mach)` or availability checks.
   - **Action**: wrap imports/usages with `#if canImport(Mach)` and provide zero/placeholder metrics when unavailable.

### Phase 2 – Performance & Threading (P0)
3. **Move import pipeline off `@MainActor`**
   - `Fonic HiFi/Data/Services/LibraryImportService.swift:15,146`: synchronous FileManager work and metadata extraction occur on the main actor.
   - **Action**: convert service to a non-main actor (or split responsibilities), perform file I/O on a background actor/task, marshal UI updates back onto `@MainActor`.

4. **Paginate library statistics & heavy fetches**
   - `Fonic HiFi/Data/DataManager.swift:89`: `getLibraryStatistics()` fetches entire tables on the main context.
   - **Action**: use `fetchCount`, batched fetches, or existing pagination helpers to avoid loading full collections for large libraries.

### Phase 3 – Architecture Cleanup (P1)
5. **Remove unused CloudKit entitlement**
   - `Fonic HiFi/Fonic_HiFi.entitlements:8`: CloudKit capability still declared despite privacy-first stance.
   - **Action**: delete entitlement to prevent App Store review confusion.

6. **Unify logging on `os.Logger`**
   - `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:1041`: custom `Logger` stub still shadows `os.Logger` and prints to stdout.
   - **Action**: remove stub, import `OSLog`, and instantiate `Logger(subsystem:category:)` with structured log levels (consider signposts for playback phases).

7. **Optimize progress timer updates**
   - `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:930`: timer closure spawns a new `Task` for each tick.
   - **Action**: await engine state directly within the `@MainActor` closure or refactor to `AsyncClock`/`AsyncSequence` to reduce actor churn.

---

## 4. Additional Medium-Priority Follow-Ups (After P0/P1)
- **Complete audio session centralization** → remove remaining direct `AVAudioSession` calls from adapters once `AudioSessionManager` handles activation/deactivation end-to-end.
- **Preview safety audit** → ensure every preview helper uses `isStoredInMemoryOnly` containers and never touches on-disk stores.
- **Documentation** → add rationale for the custom Liquid Glass stack and update architecture notes once the above fixes land.

---

## 5. Suggested Execution Order & Validation

| Phase | Tasks | Validation |
|-------|-------|-----------|
| Phase 1 | Fatal fallback removal, Mach guards | `make build`; launch app with intentionally broken data store; confirm graceful UI fallback |
| Phase 2 | Import threading, statistics pagination | `make build`; bulk-import sample library; observe MainActor instrumentation for stalls |
| Phase 3 | Entitlement cleanup, logging unification, timer fix | `make build`; smoke playback; review logs and Instruments for reduced churn |

After each phase, run `make build` (and `make test-unit` once tests exist) plus a manual playback/import smoke test.

---

## 6. Risk Notes
- Leaving `try!` in initialization paths risks unfriendly crashes for corrupted stores.
- Un-guarded Mach APIs can break builds on simulator or future targets.
- Main-thread import I/O will not scale to the 100k-track goal; fixing it reduces regression risk before large-library testing.

---

## 7. Next Checkpoint
Revisit this plan after Phase 1 completion (target: within the next sprint). Update the document with status, new findings, and attach build/test logs.
