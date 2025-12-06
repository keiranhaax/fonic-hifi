# Sleep Timer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add sleep timer that auto-pauses playback after a user-selected duration with optional fade-out.

**Architecture:** SleepTimerManager is a @MainActor ObservableObject using Task-based scheduling (following AudioMetricsScheduler pattern). UI is a sheet overlay presented from NowPlayingContent header. Timer fires pause() on AudioEngineFacade with optional volume fade-out.

**Tech Stack:** Swift 6.2, SwiftUI, Combine, @MainActor concurrency

---

## Task 1: Create SleepTimerManager with TDD

**Files:**
- Create: `Fonic HiFi/Core/Services/SleepTimerManager.swift`
- Create: `Fonic HiFiTests/Core/SleepTimerManagerTests.swift`

### Step 1.1: Write failing test for timer state

**File:** `Fonic HiFiTests/Core/SleepTimerManagerTests.swift`

```swift
@testable import Fonic_HiFi
import Combine
import XCTest

@MainActor
final class SleepTimerManagerTests: XCTestCase {

    func testStartTimerSetsActiveState() async throws {
        let manager = SleepTimerManager()

        XCTAssertFalse(manager.isActive)
        XCTAssertEqual(manager.remainingSeconds, 0)

        manager.start(seconds: 60)

        XCTAssertTrue(manager.isActive)
        XCTAssertEqual(manager.remainingSeconds, 60)
    }
}
```

### Step 1.2: Run test to verify it fails

```bash
make test
```

Expected: FAIL with "Cannot find 'SleepTimerManager' in scope"

### Step 1.3: Write minimal SleepTimerManager

**File:** `Fonic HiFi/Core/Services/SleepTimerManager.swift`

```swift
import Combine
import Foundation
import os

/// Manages sleep timer countdown and triggers pause when complete.
@MainActor
public final class SleepTimerManager: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var isActive: Bool = false
    @Published public private(set) var remainingSeconds: Int = 0

    // MARK: - Private

    private let logger = Log.logger(.audio)
    private var timerTask: Task<Void, Never>?

    // MARK: - Init

    public init() {}

    deinit {
        timerTask?.cancel()
    }

    // MARK: - Public API

    /// Start sleep timer with specified duration.
    public func start(seconds: Int) {
        stop()
        remainingSeconds = seconds
        isActive = true
        logger.debug("Sleep timer started: \(seconds)s")
    }

    /// Stop and reset the timer.
    public func stop() {
        timerTask?.cancel()
        timerTask = nil
        isActive = false
        remainingSeconds = 0
        logger.debug("Sleep timer stopped")
    }
}
```

### Step 1.4: Run test to verify it passes

```bash
make test
```

Expected: PASS

### Step 1.5: Commit

```bash
git add "Fonic HiFi/Core/Services/SleepTimerManager.swift" "Fonic HiFiTests/Core/SleepTimerManagerTests.swift"
git commit -m "feat(timer): add SleepTimerManager with start/stop state

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2: Add Countdown Logic

**Files:**
- Modify: `Fonic HiFi/Core/Services/SleepTimerManager.swift`
- Modify: `Fonic HiFiTests/Core/SleepTimerManagerTests.swift`

### Step 2.1: Write failing test for countdown

**Add to** `SleepTimerManagerTests.swift`:

```swift
func testTimerCountsDown() async throws {
    let manager = SleepTimerManager()

    manager.start(seconds: 3)

    // Wait 1.5 seconds
    try await Task.sleep(for: .milliseconds(1500))

    // Should have counted down by ~1-2 seconds
    XCTAssertTrue(manager.isActive)
    XCTAssertLessThanOrEqual(manager.remainingSeconds, 2)
    XCTAssertGreaterThanOrEqual(manager.remainingSeconds, 1)

    manager.stop()
}
```

### Step 2.2: Run test to verify it fails

```bash
make test
```

Expected: FAIL - remainingSeconds stays at 3

### Step 2.3: Add countdown task to start()

**Modify** `SleepTimerManager.swift` - replace `start(seconds:)`:

```swift
/// Start sleep timer with specified duration.
public func start(seconds: Int) {
    stop()
    remainingSeconds = seconds
    isActive = true
    logger.debug("Sleep timer started: \(seconds)s")

    timerTask = Task { @MainActor [weak self] in
        while let self, self.isActive, self.remainingSeconds > 0 {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { break }
            self.remainingSeconds -= 1
        }

        if let self, self.remainingSeconds == 0 {
            self.timerComplete()
        }
    }
}

private func timerComplete() {
    logger.info("Sleep timer complete")
    isActive = false
    // Pause will be wired in Task 3
}
```

### Step 2.4: Run test to verify it passes

```bash
make test
```

Expected: PASS

### Step 2.5: Commit

```bash
git add "Fonic HiFi/Core/Services/SleepTimerManager.swift" "Fonic HiFiTests/Core/SleepTimerManagerTests.swift"
git commit -m "feat(timer): add countdown logic to SleepTimerManager

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3: Wire Timer to AudioEngineFacade

**Files:**
- Modify: `Fonic HiFi/Core/Services/SleepTimerManager.swift`
- Modify: `Fonic HiFiTests/Core/SleepTimerManagerTests.swift`

### Step 3.1: Write failing test for pause callback

**Add to** `SleepTimerManagerTests.swift`:

```swift
func testTimerTriggersOnComplete() async throws {
    let manager = SleepTimerManager()
    var didComplete = false

    manager.onComplete = {
        didComplete = true
    }

    manager.start(seconds: 1)

    // Wait for timer to complete
    try await Task.sleep(for: .milliseconds(1500))

    XCTAssertTrue(didComplete, "onComplete should have been called")
    XCTAssertFalse(manager.isActive)
    XCTAssertEqual(manager.remainingSeconds, 0)
}
```

### Step 3.2: Run test to verify it fails

```bash
make test
```

Expected: FAIL - "Value of type 'SleepTimerManager' has no member 'onComplete'"

### Step 3.3: Add onComplete callback

**Modify** `SleepTimerManager.swift` - add property and update timerComplete():

```swift
// MARK: - Published State

@Published public private(set) var isActive: Bool = false
@Published public private(set) var remainingSeconds: Int = 0

/// Callback triggered when timer completes. Wire to AudioEngineFacade.pause().
public var onComplete: (() -> Void)?
```

**Update** `timerComplete()`:

```swift
private func timerComplete() {
    logger.info("Sleep timer complete")
    isActive = false
    onComplete?()
}
```

### Step 3.4: Run test to verify it passes

```bash
make test
```

Expected: PASS

### Step 3.5: Commit

```bash
git add "Fonic HiFi/Core/Services/SleepTimerManager.swift" "Fonic HiFiTests/Core/SleepTimerManagerTests.swift"
git commit -m "feat(timer): add onComplete callback for pause integration

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 4: Add Fade-Out Support

**Files:**
- Modify: `Fonic HiFi/Core/Services/SleepTimerManager.swift`
- Modify: `Fonic HiFiTests/Core/SleepTimerManagerTests.swift`

### Step 4.1: Write failing test for fade-out callback

**Add to** `SleepTimerManagerTests.swift`:

```swift
func testFadeOutCallsVolumeCallback() async throws {
    let manager = SleepTimerManager()
    var volumeChanges: [Float] = []

    manager.onVolumeChange = { volume in
        volumeChanges.append(volume)
    }
    manager.fadeOutDuration = 2  // 2 second fade

    manager.start(seconds: 3)

    // Wait for fade-out to begin (starts at 2 seconds remaining)
    try await Task.sleep(for: .milliseconds(2500))

    // Should have at least one volume change
    XCTAssertFalse(volumeChanges.isEmpty, "Should have volume changes during fade")
    if let lastVolume = volumeChanges.last {
        XCTAssertLessThan(lastVolume, 1.0, "Volume should decrease during fade")
    }

    manager.stop()
}
```

### Step 4.2: Run test to verify it fails

```bash
make test
```

Expected: FAIL - "Value of type 'SleepTimerManager' has no member 'onVolumeChange'"

### Step 4.3: Add fade-out support

**Modify** `SleepTimerManager.swift`:

```swift
// MARK: - Published State

@Published public private(set) var isActive: Bool = false
@Published public private(set) var remainingSeconds: Int = 0

/// Callback triggered when timer completes. Wire to AudioEngineFacade.pause().
public var onComplete: (() -> Void)?

/// Callback for volume changes during fade-out. Wire to AudioEngineFacade.setVolume().
public var onVolumeChange: ((Float) -> Void)?

/// Duration of fade-out in seconds. 0 = no fade.
public var fadeOutDuration: Int = 0

// MARK: - Private

private let logger = Log.logger(.audio)
private var timerTask: Task<Void, Never>?
private var originalVolume: Float = 1.0
```

**Replace** `start(seconds:)` with fade-out logic:

```swift
/// Start sleep timer with specified duration.
/// - Parameter seconds: Total timer duration
/// - Parameter currentVolume: Current audio volume for fade-out restoration
public func start(seconds: Int, currentVolume: Float = 1.0) {
    stop()
    remainingSeconds = seconds
    originalVolume = currentVolume
    isActive = true
    logger.debug("Sleep timer started: \(seconds)s, fade: \(fadeOutDuration)s")

    timerTask = Task { @MainActor [weak self] in
        while let self, self.isActive, self.remainingSeconds > 0 {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { break }
            self.remainingSeconds -= 1

            // Handle fade-out
            if self.fadeOutDuration > 0, self.remainingSeconds <= self.fadeOutDuration {
                let progress = Float(self.remainingSeconds) / Float(self.fadeOutDuration)
                let newVolume = self.originalVolume * progress
                self.onVolumeChange?(newVolume)
            }
        }

        if let self, self.remainingSeconds == 0 {
            self.timerComplete()
        }
    }
}
```

**Update** `timerComplete()` to restore volume:

```swift
private func timerComplete() {
    logger.info("Sleep timer complete")
    isActive = false
    onComplete?()
    // Restore volume after a brief delay (for next play)
    Task { @MainActor [weak self] in
        try? await Task.sleep(for: .milliseconds(500))
        if let self {
            self.onVolumeChange?(self.originalVolume)
        }
    }
}
```

**Update** `stop()` to restore volume:

```swift
/// Stop and reset the timer.
public func stop() {
    timerTask?.cancel()
    timerTask = nil
    if isActive {
        // Restore original volume if stopped mid-fade
        onVolumeChange?(originalVolume)
    }
    isActive = false
    remainingSeconds = 0
    logger.debug("Sleep timer stopped")
}
```

### Step 4.4: Update first test to pass currentVolume

**Modify** `testStartTimerSetsActiveState`:

```swift
func testStartTimerSetsActiveState() async throws {
    let manager = SleepTimerManager()

    XCTAssertFalse(manager.isActive)
    XCTAssertEqual(manager.remainingSeconds, 0)

    manager.start(seconds: 60, currentVolume: 1.0)

    XCTAssertTrue(manager.isActive)
    XCTAssertEqual(manager.remainingSeconds, 60)
}
```

**Update other tests similarly** with `currentVolume: 1.0` parameter.

### Step 4.5: Run tests to verify they pass

```bash
make test
```

Expected: PASS

### Step 4.6: Commit

```bash
git add "Fonic HiFi/Core/Services/SleepTimerManager.swift" "Fonic HiFiTests/Core/SleepTimerManagerTests.swift"
git commit -m "feat(timer): add fade-out support with volume callbacks

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 5: Create SleepTimerSheet UI

**Files:**
- Create: `Fonic HiFi/Presentation/Views/NowPlaying/SleepTimerSheet.swift`

### Step 5.1: Create basic sheet structure

**File:** `Fonic HiFi/Presentation/Views/NowPlaying/SleepTimerSheet.swift`

```swift
import SwiftUI

/// Sheet for configuring and monitoring the sleep timer.
struct SleepTimerSheet: View {
    @ObservedObject var timerManager: SleepTimerManager
    @Environment(\.dismiss) private var dismiss

    // MARK: - Timer Presets

    private let presets: [(label: String, seconds: Int)] = [
        ("5 min", 5 * 60),
        ("10 min", 10 * 60),
        ("15 min", 15 * 60),
        ("30 min", 30 * 60),
        ("45 min", 45 * 60),
        ("1 hour", 60 * 60),
    ]

    // MARK: - State

    @State private var enableFadeOut: Bool = true
    @State private var fadeOutDuration: Double = 30

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                if timerManager.isActive {
                    activeTimerSection
                } else {
                    presetSection
                    fadeOutSection
                }
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var activeTimerSection: some View {
        Section {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(.orange)
                    .font(.title2)

                VStack(alignment: .leading) {
                    Text("Time Remaining")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(formatTime(timerManager.remainingSeconds))
                        .font(.system(.title, design: .monospaced, weight: .medium))
                }

                Spacer()
            }
            .padding(.vertical, 8)

            Button(role: .destructive) {
                timerManager.stop()
            } label: {
                HStack {
                    Spacer()
                    Text("Cancel Timer")
                    Spacer()
                }
            }
        } header: {
            Text("Active Timer")
        }
    }

    private var presetSection: some View {
        Section {
            ForEach(presets, id: \.seconds) { preset in
                Button {
                    startTimer(seconds: preset.seconds)
                } label: {
                    HStack {
                        Text(preset.label)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "moon.zzz")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Set Timer")
        } footer: {
            Text("Playback will pause when the timer ends.")
        }
    }

    private var fadeOutSection: some View {
        Section {
            Toggle("Fade Out", isOn: $enableFadeOut)

            if enableFadeOut {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text("\(Int(fadeOutDuration)) seconds")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $fadeOutDuration, in: 10...60, step: 5)
                }
            }
        } header: {
            Text("Fade Out")
        } footer: {
            Text("Gradually reduce volume before pausing.")
        }
    }

    // MARK: - Helpers

    private func startTimer(seconds: Int) {
        timerManager.fadeOutDuration = enableFadeOut ? Int(fadeOutDuration) : 0
        timerManager.start(seconds: seconds, currentVolume: 1.0)
        dismiss()
    }

    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

#Preview {
    SleepTimerSheet(timerManager: SleepTimerManager())
}
```

### Step 5.2: Build to verify compilation

```bash
make build
```

Expected: Build succeeds

### Step 5.3: Commit

```bash
git add "Fonic HiFi/Presentation/Views/NowPlaying/SleepTimerSheet.swift"
git commit -m "feat(ui): add SleepTimerSheet with presets and fade-out toggle

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 6: Integrate into NowPlayingContent

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift`

### Step 6.1: Add timer manager and sheet state

**Near the top of NowPlayingContent** (after existing @State properties, around line 20):

```swift
@StateObject private var sleepTimerManager = SleepTimerManager()
@State private var showSleepTimerSheet = false
```

### Step 6.2: Add timer button to header bar

**Find the `headerBar` computed property** and add the timer button. The header should look like:

```swift
private var headerBar: some View {
    HStack(spacing: 16) {
        // Sleep timer button
        Button {
            showSleepTimerSheet = true
        } label: {
            ZStack {
                Image(systemName: sleepTimerManager.isActive ? "moon.zzz.fill" : "moon.zzz")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(sleepTimerManager.isActive ? .orange : .white)

                // Badge showing remaining time
                if sleepTimerManager.isActive {
                    Text(formatTimerBadge(sleepTimerManager.remainingSeconds))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.orange, in: Capsule())
                        .offset(x: 12, y: -10)
                }
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)

        Spacer()

        Text("Now Playing")
            .font(.headline)
            .foregroundStyle(.white)

        Spacer()

        AirPlayRouteButton()
            .frame(width: 44, height: 44)
            .tint(.white)
    }
    .padding(.horizontal, 16)
}
```

### Step 6.3: Add helper method for timer badge

**Add near other helper methods:**

```swift
private func formatTimerBadge(_ seconds: Int) -> String {
    let minutes = seconds / 60
    if minutes >= 60 {
        return "\(minutes / 60)h"
    } else {
        return "\(minutes)m"
    }
}
```

### Step 6.4: Add sheet modifier and wire callbacks

**Add at the end of the body's VStack**, after existing .sheet modifiers:

```swift
.sheet(isPresented: $showSleepTimerSheet) {
    SleepTimerSheet(timerManager: sleepTimerManager)
        .presentationDetents([.medium])
}
.onAppear {
    // Wire sleep timer to audio engine
    sleepTimerManager.onComplete = { [weak audioService] in
        Task { @MainActor in
            await audioService?.pause()
        }
    }
    sleepTimerManager.onVolumeChange = { [weak audioService] volume in
        Task { @MainActor in
            await audioService?.setVolume(volume)
        }
    }
}
```

### Step 6.5: Build and run to verify

```bash
make build && make run
```

Expected: App launches, timer button visible in Now Playing header

### Step 6.6: Commit

```bash
git add "Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift"
git commit -m "feat(ui): integrate sleep timer into Now Playing header

- Add moon.zzz button with active state indicator
- Show remaining time badge when timer active
- Wire timer callbacks to AudioEngineFacade

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 7: Run Full Test Suite and Coverage

**Files:**
- None (verification only)

### Step 7.1: Run all tests

```bash
make test
```

Expected: All tests pass including new SleepTimerManagerTests

### Step 7.2: Check coverage

```bash
make coverage-check
```

Expected: Coverage should remain at or above current baseline

### Step 7.3: Run linter

```bash
make lint
```

Expected: No new violations

---

## Summary Checklist

- [ ] Task 1: Create SleepTimerManager with basic state
- [ ] Task 2: Add countdown logic
- [ ] Task 3: Wire onComplete callback
- [ ] Task 4: Add fade-out support
- [ ] Task 5: Create SleepTimerSheet UI
- [ ] Task 6: Integrate into NowPlayingContent
- [ ] Task 7: Run tests and coverage check

**Estimated time:** 1.5-2 hours

---

## Notes

### What This Plan Does NOT Include

- **"End of track" option** - Deferred; requires track duration integration
- **Custom time picker** - Presets cover common cases; can add later
- **Persist timer across app restarts** - Timer is ephemeral by design

### Testing Strategy

Tests focus on:
1. State management (isActive, remainingSeconds)
2. Countdown behavior
3. Callback firing (onComplete, onVolumeChange)
4. Fade-out volume calculation

UI testing is manual - verify button appears and sheet presents.
