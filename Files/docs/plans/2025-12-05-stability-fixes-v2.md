# Stability Fixes Implementation Plan (v2 - Corrected)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix M4A playback failure, reduce launch time, and reduce CPU usage when idle.

**Architecture:** Three independent fixes targeting: (1) AudioFormat extension-to-codec mapping (matching existing ALAC expectation), (2) deferred startup tasks (respecting @MainActor), (3) playback-state-aware monitoring intervals.

**Tech Stack:** Swift 6.2, SwiftUI, SwiftData, AVFoundation

**Corrections from v1:**
- P0: Map m4a → .alac (not .aac) to match AudioFormatType and existing tests
- P1: Removed Task.detached (violates @MainActor); focus on deferring startup tasks only
- P2: Use existing `updateMonitoringInterval(to:)` method; add proper StateCoordinator wiring

---

## Task 1: Add M4A Extension Mapping Test (TDD Red Phase)

**Files:**
- Create: `Fonic HiFiTests/AudioFormatTests.swift`

**Step 1: Write the failing test**

```swift
@testable import Fonic_HiFi
import XCTest

final class AudioFormatTests: XCTestCase {
    func testFromURLHandlesM4AExtension() {
        let m4aURL = URL(fileURLWithPath: "/test/song.m4a")
        let format = AudioFormat.from(url: m4aURL)
        // Match AudioFormatType behavior: m4a -> alac
        XCTAssertEqual(format, .alac, "M4A container should map to ALAC codec (matching AudioFormatType)")
    }

    func testFromURLHandlesMP3Extension() {
        let mp3URL = URL(fileURLWithPath: "/test/song.mp3")
        let format = AudioFormat.from(url: mp3URL)
        XCTAssertEqual(format, .mp3)
    }

    func testFromURLHandlesUnknownExtension() {
        let unknownURL = URL(fileURLWithPath: "/test/song.xyz")
        let format = AudioFormat.from(url: unknownURL)
        XCTAssertNil(format, "Unknown extensions should return nil")
    }

    func testFromURLIsCaseInsensitive() {
        let upperURL = URL(fileURLWithPath: "/test/song.M4A")
        let format = AudioFormat.from(url: upperURL)
        XCTAssertEqual(format, .alac, "Extension matching should be case-insensitive")
    }
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with `XCTAssertEqual failed: ("nil") is not equal to ("Optional(Fonic_HiFi.AudioFormat.alac)")`

**Step 3: Commit test (red phase)**

```bash
git add "Fonic HiFiTests/AudioFormatTests.swift"
git commit -m "test(audio): add failing test for M4A format detection

🔴 RED phase - test fails because AudioFormat.from(url:) returns nil for .m4a

Maps m4a -> alac to match AudioFormatType.from(fileExtension:) behavior
and existing AudioFormatTypeTests assertion.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2: Fix M4A Extension Mapping (TDD Green Phase)

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Interfaces/AudioFormat.swift:102-105`

**Step 1: Implement the fix**

Replace lines 102-105:

```swift
/// Create AudioFormat from file URL
/// - Parameter url: File URL to analyze
/// - Returns: AudioFormat if recognized, nil otherwise
public static func from(url: URL) -> AudioFormat? {
    let ext = url.pathExtension.lowercased()
    switch ext {
    case "m4a": return .alac  // M4A container -> ALAC (matches AudioFormatType)
    case "aif": return .aiff  // Common alternate extension
    default: return AudioFormat(rawValue: ext)
    }
}
```

**Step 2: Run test to verify it passes**

Run: `make test`
Expected: All tests PASS including `testFromURLHandlesM4AExtension`

**Step 3: Commit fix (green phase)**

```bash
git add "Fonic HiFi/Core/Audio/Interfaces/AudioFormat.swift"
git commit -m "fix(audio): map M4A container to ALAC codec

M4A is a container format. AudioFormat.from(url:) was returning nil
because the enum only has codec cases (aac, alac), not containers.

Maps to ALAC (not AAC) to match:
- AudioFormatType.from(fileExtension:) behavior
- AudioFormatTypeTests assertion (m4a -> .alac)

This fixes playback failure for imported M4A files.

🟢 GREEN phase - test passes

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3: Defer Startup Tasks with Delays

**Why this approach:** The @MainActor constraints on DataManager and AudioEngineFacade mean we cannot move their creation off the main thread. However, we CAN defer non-critical startup tasks that run after init().

**Files:**
- Modify: `Fonic HiFi/FonicHiFiApp.swift` (performStartupTasks method, ~lines 194-221)

**Step 1: Add delays to startup tasks**

Find `performStartupTasks()` and modify:

```swift
@MainActor
private func performStartupTasks() async {
    guard let dataManager else { return }

    // Defer cleanup by 3 seconds - not launch-critical
    Task {
        try? await Task.sleep(for: .seconds(3))
        do {
            let removedCount = try await dataManager.cleanupMissingFiles()
            if removedCount > 0 {
                logger.info("Cleaned up \(removedCount) missing files from library")
            }
        } catch {
            logger.error("Failed to cleanup missing files: \(error.localizedDescription)")
        }
    }

    // Defer statistics by 5 seconds - not launch-critical
    Task {
        try? await Task.sleep(for: .seconds(5))
        do {
            let stats = try await dataManager.getLibraryStatistics()
            let statsMessage = "Library stats: \(stats.trackCount) tracks, \(stats.albumCount) albums, " +
                "\(stats.artistCount) artists"
            logger.info("\(statsMessage)")
        } catch {
            logger.error("Failed to get library statistics: \(error.localizedDescription)")
        }
    }
}
```

**Step 2: Verify build succeeds**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Run tests**

Run: `make test`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add "Fonic HiFi/FonicHiFiApp.swift"
git commit -m "perf(app): defer non-critical startup tasks

Delay cleanupMissingFiles() by 3s and getLibraryStatistics() by 5s
after app becomes interactive. These tasks are not launch-critical
and can run after the user sees the UI.

Note: DataManager/AudioEngineFacade creation remains synchronous
due to @MainActor constraints. This change reduces post-launch
CPU competition.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 4: Guard debugModelContainer with DEBUG

**Files:**
- Modify: `Fonic HiFi/Data/DataManager+Initialization.swift`

**Step 1: Guard the function definition (lines 195-236)**

```swift
#if DEBUG
/// Test creating a container with minimal models to identify which one is problematic
static func debugModelContainer() {
    // ... existing implementation unchanged ...
}
#endif
```

**Step 2: Guard the call site (line 104-105 in buildContainer)**

Find in `buildContainer()`:
```swift
// Third attempt: Try individual model validation
logger.info("Running model container debugging...")
debugModelContainer()
```

Replace with:
```swift
// Third attempt: Try individual model validation (DEBUG only)
#if DEBUG
logger.info("Running model container debugging...")
debugModelContainer()
#endif
```

**Step 3: Verify build succeeds**

Run: `make build`
Expected: BUILD SUCCEEDED (both Debug and Release)

**Step 4: Commit**

```bash
git add "Fonic HiFi/Data/DataManager+Initialization.swift"
git commit -m "perf(data): guard debugModelContainer with DEBUG flag

debugModelContainer() creates multiple ModelContainers for diagnostic
purposes. Now only runs in DEBUG builds. Both the function and its
call site are guarded.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 5: Increase Default Monitoring Interval

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift`

**Step 1: Find the initialize() method and change interval**

Find line ~193 in `initialize()`:
```swift
await monitor.startMonitoring(updateInterval: 1.0)
```

Change to:
```swift
await monitor.startMonitoring(updateInterval: 2.0)
```

**Step 2: Verify build succeeds**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift"
git commit -m "perf(audio): increase monitoring interval from 1s to 2s

Reduces CPU overhead from monitoring collectors. The 1s interval
was aggressive for normal playback; 2s provides sufficient
diagnostic granularity.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 6: Add Playback-Aware Monitoring Control

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Engine/StateCoordinator.swift`

**Context:** StateCoordinator already observes PlaybackStateManager and updates the facade. This is the right place to add monitoring control.

**Step 1: Explore StateCoordinator to find the state observation**

First, read `Fonic HiFi/Core/Audio/Coordinators/StateCoordinator.swift` to understand the existing state subscription pattern.

**Step 2: Add monitoring control based on playback state**

In the existing state subscription (likely in init or setupBindings), add:

```swift
// When playback state changes, adjust monitoring
stateManager.$currentState
    .map(\.status)
    .removeDuplicates()
    .sink { [weak self] status in
        guard let self, let monitor = self.facade?.monitor else { return }
        Task { @MainActor in
            switch status {
            case .playing:
                // Active playback needs monitoring
                await monitor.startMonitoring(updateInterval: 2.0)
            case .paused:
                // Paused - reduce monitoring frequency
                monitor.updateMonitoringInterval(to: 5.0)
            case .stopped:
                // Stopped - minimal monitoring
                await monitor.stopMonitoring()
            default:
                break
            }
        }
    }
    .store(in: &cancellables)
```

**Step 3: Verify build succeeds**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 4: Run tests**

Run: `make test`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Core/Audio/Coordinators/StateCoordinator.swift"
git commit -m "perf(audio): add playback-aware monitoring control

StateCoordinator now adjusts monitoring based on playback state:
- Playing: 2s interval (active monitoring)
- Paused: 5s interval (reduced)
- Stopped: monitoring paused (minimal CPU)

Uses existing updateMonitoringInterval(to:) from AudioMetricsScheduler.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 7: Final Verification

**Step 1: Run full test suite**

Run: `make test`
Expected: All tests PASS (including new AudioFormatTests)

**Step 2: Build release**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Run lint**

Run: `make lint`
Expected: No new violations

**Step 4: Manual verification checklist**

- [ ] Import an M4A file - should succeed
- [ ] Tap M4A file to play - should work (was failing before)
- [ ] Play an MP3 - should still work
- [ ] Pause playback - observe if CPU drops (via Activity Monitor)
- [ ] Stop playback - observe monitoring stops

**Step 5: Final commit**

```bash
git add -A
git commit -m "chore: stability fixes complete (v2)

Fixes:
- P0: M4A playback works (map .m4a to .alac codec)
- P1: Startup tasks deferred (3s/5s delays)
- P2: Monitoring interval increased (1s -> 2s) and playback-aware

Note: DataManager init remains synchronous due to @MainActor.
Full async refactor would require architectural changes.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Summary of Changes from v1

| Issue | v1 (Buggy) | v2 (Corrected) |
|-------|------------|----------------|
| P0: M4A mapping | `m4a -> .aac` | `m4a -> .alac` (matches tests) |
| P1: Launch time | Task.detached (violates @MainActor) | Defer startup tasks only |
| P1: Loading UI | AppLoadingView + async refactor | Removed (not feasible without major changes) |
| P2: Monitoring | Add new methods | Use existing `updateMonitoringInterval(to:)` |
| P2: Wiring | Vague "connect to state" | Specific StateCoordinator integration |

---

## What's NOT in This Plan (Deferred)

1. **Full async app initialization** - Requires @MainActor-safe architecture changes
2. **AppLoadingView** - Requires async init which isn't feasible currently
3. **New pauseMonitoring/resumeMonitoring methods** - Use existing API instead

---

## Task Summary

| Task | Description | Time |
|------|-------------|------|
| 1 | Add M4A test (red) | 3 min |
| 2 | Fix M4A mapping to .alac (green) | 2 min |
| 3 | Defer startup tasks with delays | 5 min |
| 4 | Guard debugModelContainer | 3 min |
| 5 | Increase monitoring interval | 2 min |
| 6 | Add playback-aware monitoring | 10 min |
| 7 | Final verification | 10 min |
| **Total** | | **~35 min** |
