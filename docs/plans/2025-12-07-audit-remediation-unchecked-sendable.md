# Audit Remediation: Remove Production `@unchecked Sendable`

**Status:** Implemented on 2026-07-15

**Goal:** Remove the remaining production `@unchecked Sendable` escape hatch while preserving playback-settings behavior and stored-data compatibility.

**Concurrency model:** `AudioPlaybackSettingsStore` is an actor. Its `UserDefaults` reference is stored and accessed only as actor-isolated state, so a separate unchecked wrapper is unnecessary.

## Current Findings

The original Glass findings are no longer actionable:

- `3a339e8` removed the unused `GlassPerformanceProfiler`.
- `8cc11d0` removed the unused `GlassEffectMemoryManager`.

Before this remediation, the only production occurrence was `DefaultsBox` in `AudioPlaybackSettingsStore`. The following test-only annotations remain intentionally out of scope:

- `StubAlertManager` in `Fonic HiFiTests/AudioMonitorTests.swift`.
- `MockSecurityScopedAccessor` in `Fonic HiFiTests/ImportPipelineTests.swift`.

Those test doubles require a separate audit because their isolation and synchronization contracts differ from the production actor addressed here.

## Implemented Changes

- Removed `DefaultsBox` and its `@unchecked Sendable` conformance.
- Stored `UserDefaults` directly as private actor-isolated state.
- Preserved the public initializer, public methods, persistence keys, default values, and encoded equalizer payload.
- Added a focused test that performs concurrent reads and writes through the actor, validates observed values, and verifies deterministic sentinel values afterward.
- Used a unique `UserDefaults` suite for the concurrency test and removed its persistent domain after completion.

No dependency, project-file, signing, entitlement, schema, or migration change was required.

## Verification

- Production search for `@unchecked Sendable` and `nonisolated(unsafe)`: no matches.
- `AudioPlaybackSettingsStoreTests`: 5 passed, 0 failed.
- `AudioPlaybackSettingsStoreTests` with Thread Sanitizer: 5 passed, 0 failed, with no reported races.
- Complete `Fonic HiFiTests` unit target: 432 passed, 0 failed.
- `git diff --check`: passed.

Validation used the main `Fonic HiFi` scheme with Xcode 27 and the booted iPhone 17 running iOS 27.0. iOS 26 runtime validation is `UNVERIFIED`: iOS 26.5 simulators were installed but not booted, and the verification workflow did not mutate simulator state by booting one automatically.

The build emitted pre-existing warnings in unrelated production and test files. No warning or error originated from the files changed by this remediation.

## Acceptance Criteria

- Production Swift source contains no `@unchecked Sendable` or `nonisolated(unsafe)` occurrence.
- Playback-setting persistence behavior and keys remain unchanged.
- Concurrent access is routed through `AudioPlaybackSettingsStore` actor methods.
- Focused normal and Thread Sanitizer tests pass.
- The complete unit-test target passes.
