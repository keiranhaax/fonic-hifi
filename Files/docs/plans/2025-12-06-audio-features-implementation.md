# Audio Features Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Wire orphaned audio settings to engine, add completion routing for auto-advance, implement resume playback, AVAudioEngine gapless/playback-speed, and 10-band EQ.

**Architecture:** Three-phase approach: (1) Foundation - connect settings UI to engine, wire completion handlers for auto-advance, persist playback position; (2) Core Audio - dual-player gapless in AVAudioEngine, TimePitch for playback speed; (3) Advanced - parametric EQ with DSP indicator.

**Tech Stack:** Swift 6.2, AVFoundation (AVAudioEngine, AVAudioUnitTimePitch, AVAudioUnitEQ), AudioKit, SwiftUI, SwiftData, iOS 26

---

## Phase 1: Foundation

### Task 1: Settings Bridge Service - Create Service

**Files:**
- Create: `Fonic HiFi/Core/Services/AudioSettingsService.swift`
- Test: `Fonic HiFiTests/Core/Services/AudioSettingsServiceTests.swift`

**Step 1: Write the failing test**

```swift
// Fonic HiFiTests/Core/Services/AudioSettingsServiceTests.swift
import XCTest
@testable import Fonic_HiFi

@MainActor
final class AudioSettingsServiceTests: XCTestCase {

    func test_syncGaplessEnabled_updatesStore() async throws {
        // Given
        let store = AudioPlaybackSettingsStore()
        let service = AudioSettingsService(settingsStore: store)

        // When
        await service.syncGaplessEnabled(true)

        // Then
        let isEnabled = await store.isGaplessEnabled()
        XCTAssertTrue(isEnabled)
    }

    func test_syncCrossfadeDuration_updatesStore() async throws {
        // Given
        let store = AudioPlaybackSettingsStore()
        let service = AudioSettingsService(settingsStore: store)

        // When
        await service.syncCrossfadeDuration(5.0)

        // Then
        let duration = await store.crossfadeDuration()
        XCTAssertEqual(duration, 5.0)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "AudioSettingsService not found"

**Step 3: Write minimal implementation**

```swift
// Fonic HiFi/Core/Services/AudioSettingsService.swift
import Foundation
import SwiftUI

/// Bridges @AppStorage settings to AudioPlaybackSettingsStore and AudioEngineFacade
@MainActor
public final class AudioSettingsService: ObservableObject {
    private let settingsStore: AudioPlaybackSettingsStore

    public init(settingsStore: AudioPlaybackSettingsStore) {
        self.settingsStore = settingsStore
    }

    /// Sync gapless setting from UI to engine store
    public func syncGaplessEnabled(_ enabled: Bool) async {
        await settingsStore.setGaplessEnabled(enabled)
    }

    /// Sync crossfade duration from UI to engine store
    public func syncCrossfadeDuration(_ duration: TimeInterval) async {
        await settingsStore.setCrossfadeDuration(duration)
    }

    /// Sync replay gain mode from UI to engine store
    public func syncReplayGainMode(_ mode: ReplayGainMode) async {
        await settingsStore.setReplayGainMode(mode)
    }

    /// Sync playback rate from UI to engine store
    public func syncPlaybackRate(_ rate: Double) async {
        await settingsStore.setPlaybackRate(rate)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Core/Services/AudioSettingsService.swift" "Fonic HiFiTests/Core/Services/AudioSettingsServiceTests.swift"
git commit -m "feat(audio): add AudioSettingsService to bridge UI to engine store"
```

---

### Task 2: Settings Bridge Service - Wire to AudioSettingsView

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/Settings/AudioSettingsView.swift`

**Step 1: Read the current implementation**

Check current @AppStorage usage in AudioSettingsView.swift (lines 10-19 approximately).

**Step 2: Add service injection and onChange handlers**

```swift
// In AudioSettingsView.swift, add after existing @AppStorage declarations:

@Environment(\.audioEngine) private var audioEngine
@StateObject private var settingsService: AudioSettingsService

// In body, wrap toggles/sliders with .onChange:

Toggle("Gapless Playback", isOn: $enableGaplessPlayback)
    .onChange(of: enableGaplessPlayback) { _, newValue in
        Task {
            await settingsService.syncGaplessEnabled(newValue)
            await audioEngine.updateConfiguration(
                audioEngine.engineManager.configuration.with(enableGapless: newValue)
            )
        }
    }

Slider(value: $crossfadeDuration, in: 0...12, step: 0.5)
    .onChange(of: crossfadeDuration) { _, newValue in
        Task {
            await settingsService.syncCrossfadeDuration(newValue)
            await audioEngine.updateCrossfadeDuration(newValue)
        }
    }
```

**Step 3: Run to verify settings now propagate**

Run: `make run`
Manual test: Change gapless toggle, verify via debug logs that engine receives update.

**Step 4: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Settings/AudioSettingsView.swift"
git commit -m "feat(settings): wire AudioSettingsView to engine via AudioSettingsService"
```

---

### Task 3: Completion Routing - Add Handler to AudioKitEngineAdapter

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift`
- Test: `Fonic HiFiTests/Core/Audio/Engines/AudioKitEngineAdapterTests.swift`

**Step 1: Write the failing test**

```swift
// Add to AudioKitEngineAdapterTests.swift
func test_completionHandler_calledWhenPlaybackEnds() async throws {
    // Given
    let adapter = AudioKitEngineAdapter()
    var handlerCalled = false
    adapter.setCompletionHandler {
        handlerCalled = true
    }

    // When - simulate playback completion
    // This requires a short audio file or mock

    // Then
    XCTAssertTrue(handlerCalled)
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "setCompletionHandler not found"

**Step 3: Add completion handler property and method**

```swift
// In AudioKitEngineAdapter.swift, add property:
private var completionHandler: (() -> Void)?

// Add method:
public func setCompletionHandler(_ handler: @escaping () -> Void) {
    completionHandler = handler
}

// In the playback monitoring loop or AudioPlayer completion callback,
// call the handler when track ends naturally:
private func handlePlaybackCompletion() {
    Task { @MainActor [weak self] in
        self?.completionHandler?()
    }
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift" "Fonic HiFiTests/Core/Audio/Engines/AudioKitEngineAdapterTests.swift"
git commit -m "feat(audio): add completion handler to AudioKitEngineAdapter"
```

---

### Task 4: Completion Routing - Wire PlaybackController to Call setCompletionHandler

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Controllers/PlaybackController.swift`
- Test: `Fonic HiFiTests/Core/Audio/Controllers/PlaybackControllerTests.swift`

**Step 1: Write the failing test**

```swift
// Add to PlaybackControllerTests.swift
func test_play_setsCompletionHandler() async throws {
    // Given
    let mockEngine = MockAudioEngine()
    let controller = PlaybackController(engine: mockEngine, ...)

    // When
    await controller.play(track: testTrack)

    // Then
    XCTAssertTrue(mockEngine.completionHandlerWasSet)
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL

**Step 3: Add completion handler wiring in play()**

```swift
// In PlaybackController.swift, in play(track:) method, after engine.load():

engine.setCompletionHandler { [weak self] in
    Task { @MainActor in
        guard let self = self else { return }
        // Auto-advance to next track if gapless enabled or normal playback
        if self.configuration.enableGapless || self.queueCoordinator.hasNext {
            await self.queueCoordinator.playNext()
        } else {
            self.stateManager.setState(.stopped)
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Core/Audio/Controllers/PlaybackController.swift" "Fonic HiFiTests/Core/Audio/Controllers/PlaybackControllerTests.swift"
git commit -m "feat(audio): wire completion handler in PlaybackController for auto-advance"
```

---

### Task 5: Resume Playback - Add lastPosition to QueueState

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Queue/QueueState.swift`
- Test: `Fonic HiFiTests/Core/Audio/Queue/QueueStateTests.swift`

**Step 1: Write the failing test**

```swift
// Add to QueueStateTests.swift
func test_lastPosition_persistsAndRestores() throws {
    // Given
    var state = QueueState()
    state.lastPosition = 42.5

    // When
    try state.save()
    let restored = QueueState.load()

    // Then
    XCTAssertEqual(restored?.lastPosition, 42.5)
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "lastPosition not found"

**Step 3: Add lastPosition property**

```swift
// In QueueState.swift, add property:
public var lastPosition: TimeInterval = 0

// Ensure it's included in Codable encoding/decoding (already automatic for structs)
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Core/Audio/Queue/QueueState.swift" "Fonic HiFiTests/Core/Audio/Queue/QueueStateTests.swift"
git commit -m "feat(queue): add lastPosition to QueueState for resume support"
```

---

### Task 6: Resume Playback - Save Position on Pause/Stop

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Queue/AudioQueueManager.swift`
- Modify: `Fonic HiFi/Core/Audio/Controllers/PlaybackController.swift`

**Step 1: Write the failing test**

```swift
// Add to AudioQueueManagerTests.swift
func test_savePosition_updatesQueueState() async throws {
    // Given
    let manager = AudioQueueManager()

    // When
    await manager.saveCurrentPosition(35.0)

    // Then
    let state = manager.currentState
    XCTAssertEqual(state.lastPosition, 35.0)
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL

**Step 3: Add saveCurrentPosition method**

```swift
// In AudioQueueManager.swift:
public func saveCurrentPosition(_ position: TimeInterval) {
    queueState.lastPosition = position
    try? queueState.save()
}

// In PlaybackController.swift pause() and stop() methods:
func pause() async {
    let currentTime = await engine.currentTime
    await queueManager.saveCurrentPosition(currentTime)
    await engine.pause()
    // ... rest of pause logic
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Core/Audio/Queue/AudioQueueManager.swift" "Fonic HiFi/Core/Audio/Controllers/PlaybackController.swift"
git commit -m "feat(queue): save playback position on pause/stop for resume"
```

---

### Task 7: Resume Playback - Restore Position on Launch

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift`

**Step 1: Modify initialize() to seek to saved position**

```swift
// In AudioEngineFacade.swift initialize() method, after queue restore:
if queueManager.restoreState() {
    logger.info("Restored persisted queue state")
    if let restoredTrack = queueManager.currentTrack {
        uiStateStore.currentTrack = createTrackFromAudioTrack(restoredTrack)
        uiStateStore.showMiniPlayer = true

        // NEW: Restore playback position
        let savedPosition = queueManager.currentState.lastPosition
        if savedPosition > 0 {
            logger.info("Restoring playback position: \(savedPosition)s")
            // Don't auto-play, just prepare for resume
            Task {
                try? await playbackController.load(track: restoredTrack)
                await playbackController.seek(to: savedPosition)
            }
        }
    }
}
```

**Step 2: Run to verify resume works**

Run: `make run`
Manual test: Play track, pause at 30s, force-quit app, relaunch, verify position shows 30s.

**Step 3: Commit**

```bash
git add "Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift"
git commit -m "feat(audio): restore playback position on app launch"
```

---

## Phase 2: Core Audio Features

### Task 8: AVAudioEngine Playback Speed - Add TimePitch Node

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift`
- Test: `Fonic HiFiTests/Core/Audio/Engines/AVAudioEngineAdapterTests.swift`

**Step 1: Write the failing test**

```swift
// Add to AVAudioEngineAdapterTests.swift
func test_setPlaybackRate_changesRate() async throws {
    // Given
    let adapter = AVAudioEngineAdapter()
    try await adapter.setupEngine()

    // When
    await adapter.setPlaybackRate(1.5)

    // Then
    let rate = await adapter.currentPlaybackRate
    XCTAssertEqual(rate, 1.5)
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "setPlaybackRate not found"

**Step 3: Add AVAudioUnitTimePitch node**

```swift
// In AVAudioEngineAdapter.swift:

// Add property:
private var timePitchNode: AVAudioUnitTimePitch?
public private(set) var currentPlaybackRate: Double = 1.0

// In setupEngine(), insert node between player and mixer:
private func setupEngine() throws {
    // ... existing setup ...

    // Create and attach TimePitch node
    timePitchNode = AVAudioUnitTimePitch()
    engine.attach(timePitchNode!)

    // Connect: playerNode → timePitchNode → mainMixerNode
    engine.connect(playerNode, to: timePitchNode!, format: nil)
    engine.connect(timePitchNode!, to: engine.mainMixerNode, format: nil)

    // ... rest of setup ...
}

// Add method:
public func setPlaybackRate(_ rate: Double) async {
    let clampedRate = max(0.5, min(2.0, rate))
    timePitchNode?.rate = Float(clampedRate)
    currentPlaybackRate = clampedRate
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift" "Fonic HiFiTests/Core/Audio/Engines/AVAudioEngineAdapterTests.swift"
git commit -m "feat(audio): add AVAudioUnitTimePitch for playback speed in AVAudioEngineAdapter"
```

---

### Task 9: Playback Speed UI Control

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift`

**Step 1: Add playback speed slider to Now Playing**

```swift
// In NowPlayingContent.swift, add state:
@State private var playbackSpeed: Double = 1.0

// Add UI control (near volume slider or in a menu):
Menu {
    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { speed in
        Button(action: {
            playbackSpeed = speed
            Task {
                await audioEngine.updatePlaybackRate(speed)
            }
        }) {
            HStack {
                Text("\(speed, specifier: "%.2f")x")
                if playbackSpeed == speed {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
} label: {
    Label("\(playbackSpeed, specifier: "%.1f")x", systemImage: "speedometer")
}
```

**Step 2: Run to verify UI works**

Run: `make run`
Manual test: Open Now Playing, tap speed menu, select 1.5x, verify playback speed changes.

**Step 3: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift"
git commit -m "feat(ui): add playback speed control to Now Playing"
```

---

### Task 10: AVAudioEngine Dual-Player for Gapless - Add Secondary Player

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift`
- Test: `Fonic HiFiTests/Core/Audio/Engines/AVAudioEngineAdapterTests.swift`

**Step 1: Write the failing test**

```swift
// Add to AVAudioEngineAdapterTests.swift
func test_prepareNext_schedulesOnSecondaryPlayer() async throws {
    // Given
    let adapter = AVAudioEngineAdapter()
    try await adapter.setupEngine()
    let nextURL = Bundle(for: type(of: self)).url(forResource: "test", withExtension: "mp3")!

    // When
    try await adapter.prepareNext(url: nextURL)

    // Then
    XCTAssertTrue(adapter.hasNextPrepared)
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL

**Step 3: Add secondary player node and prepareNext implementation**

```swift
// In AVAudioEngineAdapter.swift:

// Add properties:
private var primaryPlayerNode: AVAudioPlayerNode!
private var secondaryPlayerNode: AVAudioPlayerNode!
private var primaryTimePitch: AVAudioUnitTimePitch!
private var secondaryTimePitch: AVAudioUnitTimePitch!
private var activePrimary = true
private var preparedFile: AVAudioFile?
public private(set) var hasNextPrepared = false

// Rename playerNode → primaryPlayerNode, add secondary in setupEngine:
private func setupEngine() throws {
    primaryPlayerNode = AVAudioPlayerNode()
    secondaryPlayerNode = AVAudioPlayerNode()
    primaryTimePitch = AVAudioUnitTimePitch()
    secondaryTimePitch = AVAudioUnitTimePitch()

    engine.attach(primaryPlayerNode)
    engine.attach(secondaryPlayerNode)
    engine.attach(primaryTimePitch)
    engine.attach(secondaryTimePitch)

    // Primary chain
    engine.connect(primaryPlayerNode, to: primaryTimePitch, format: nil)
    engine.connect(primaryTimePitch, to: engine.mainMixerNode, format: nil)

    // Secondary chain
    engine.connect(secondaryPlayerNode, to: secondaryTimePitch, format: nil)
    engine.connect(secondaryTimePitch, to: engine.mainMixerNode, format: nil)
}

// Implement prepareNext:
public func prepareNext(url: URL) async throws {
    let inactivePlayer = activePrimary ? secondaryPlayerNode : primaryPlayerNode
    preparedFile = try AVAudioFile(forReading: url)
    inactivePlayer?.scheduleFile(preparedFile!, at: nil)
    hasNextPrepared = true
}

// Add swap method:
private func swapPlayers() {
    activePrimary.toggle()
    let oldPlayer = activePrimary ? secondaryPlayerNode : primaryPlayerNode
    oldPlayer?.stop()
    hasNextPrepared = false
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift" "Fonic HiFiTests/Core/Audio/Engines/AVAudioEngineAdapterTests.swift"
git commit -m "feat(audio): add dual-player architecture to AVAudioEngineAdapter for gapless"
```

---

### Task 11: Home Screen Data Loading

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/Home/HomeView.swift`
- Modify: `Fonic HiFi/Data/DataManager.swift`

**Step 1: Add queries to DataManager**

```swift
// In DataManager.swift, add methods:

public func getRecentlyPlayed(limit: Int = 10) async throws -> [Track] {
    let descriptor = FetchDescriptor<Track>(
        predicate: #Predicate { $0.lastPlayedAt != nil },
        sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
    )
    descriptor.fetchLimit = limit
    return try await trackDataActor.fetch(descriptor)
}

public func getMostListened(limit: Int = 10) async throws -> [Track] {
    let descriptor = FetchDescriptor<Track>(
        sortBy: [SortDescriptor(\.playCount, order: .reverse)]
    )
    descriptor.fetchLimit = limit
    return try await trackDataActor.fetch(descriptor)
}
```

**Step 2: Uncomment and implement loadData() in HomeView**

```swift
// In HomeView.swift:

private func loadData() async {
    isLoading = true
    defer { isLoading = false }

    do {
        recentlyPlayed = try await dataManager.getRecentlyPlayed(limit: 10)
        mostListened = try await dataManager.getMostListened(limit: 10)
    } catch {
        logger.error("Failed to load home data: \(error)")
    }
}
```

**Step 3: Run to verify home shows data**

Run: `make run`
Manual test: Import some tracks, play them, go to Home tab, verify data appears.

**Step 4: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Home/HomeView.swift" "Fonic HiFi/Data/DataManager.swift"
git commit -m "feat(home): implement data loading for recently played and most listened"
```

---

## Phase 3: Advanced Audio (EQ)

### Task 12: EQ Configuration Model

**Files:**
- Create: `Fonic HiFi/Core/Audio/DSP/EqualizerConfiguration.swift`
- Test: `Fonic HiFiTests/Core/Audio/DSP/EqualizerConfigurationTests.swift`

**Step 1: Write the failing test**

```swift
// Fonic HiFiTests/Core/Audio/DSP/EqualizerConfigurationTests.swift
import XCTest
@testable import Fonic_HiFi

final class EqualizerConfigurationTests: XCTestCase {

    func test_defaultConfiguration_has10Bands() {
        let config = EqualizerConfiguration.default
        XCTAssertEqual(config.bands.count, 10)
    }

    func test_bands_haveCorrectFrequencies() {
        let config = EqualizerConfiguration.default
        let expectedFrequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        for (index, band) in config.bands.enumerated() {
            XCTAssertEqual(band.frequency, expectedFrequencies[index])
        }
    }
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL

**Step 3: Write the implementation**

```swift
// Fonic HiFi/Core/Audio/DSP/EqualizerConfiguration.swift
import Foundation

public struct EQBand: Codable, Equatable, Sendable {
    public let frequency: Float  // Hz
    public var gain: Float       // dB, -12 to +12
    public var bandwidth: Float  // octaves, typically 1.0

    public init(frequency: Float, gain: Float = 0, bandwidth: Float = 1.0) {
        self.frequency = frequency
        self.gain = max(-12, min(12, gain))
        self.bandwidth = bandwidth
    }
}

public struct EqualizerConfiguration: Codable, Equatable, Sendable {
    public var bands: [EQBand]
    public var isEnabled: Bool
    public var presetName: String?

    public static let `default` = EqualizerConfiguration(
        bands: [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000].map {
            EQBand(frequency: $0)
        },
        isEnabled: false,
        presetName: "Flat"
    )

    public static let presets: [String: EqualizerConfiguration] = [
        "Flat": .default,
        "Bass Boost": EqualizerConfiguration(
            bands: [
                EQBand(frequency: 32, gain: 6),
                EQBand(frequency: 64, gain: 5),
                EQBand(frequency: 125, gain: 4),
                EQBand(frequency: 250, gain: 2),
                EQBand(frequency: 500, gain: 0),
                EQBand(frequency: 1000, gain: 0),
                EQBand(frequency: 2000, gain: 0),
                EQBand(frequency: 4000, gain: 0),
                EQBand(frequency: 8000, gain: 0),
                EQBand(frequency: 16000, gain: 0),
            ],
            isEnabled: true,
            presetName: "Bass Boost"
        ),
        // Add more presets as needed
    ]
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Core/Audio/DSP/EqualizerConfiguration.swift" "Fonic HiFiTests/Core/Audio/DSP/EqualizerConfigurationTests.swift"
git commit -m "feat(audio): add EqualizerConfiguration model with 10-band support"
```

---

### Task 13: EQ Node Integration in AVAudioEngineAdapter

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift`
- Test: `Fonic HiFiTests/Core/Audio/Engines/AVAudioEngineAdapterTests.swift`

**Step 1: Write the failing test**

```swift
// Add to AVAudioEngineAdapterTests.swift
func test_applyEQ_updatesEQNode() async throws {
    // Given
    let adapter = AVAudioEngineAdapter()
    try await adapter.setupEngine()
    var config = EqualizerConfiguration.default
    config.bands[0].gain = 6.0  // Boost 32Hz
    config.isEnabled = true

    // When
    await adapter.applyEQ(config)

    // Then
    XCTAssertTrue(adapter.isEQEnabled)
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL

**Step 3: Add AVAudioUnitEQ to signal chain**

```swift
// In AVAudioEngineAdapter.swift:

// Add properties:
private var eqNode: AVAudioUnitEQ?
public private(set) var isEQEnabled = false
private var eqConfiguration = EqualizerConfiguration.default

// In setupEngine(), add EQ node after TimePitch:
private func setupEngine() throws {
    // ... existing setup ...

    // Create 10-band EQ
    eqNode = AVAudioUnitEQ(numberOfBands: 10)
    engine.attach(eqNode!)

    // Configure bands
    let frequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    for (index, freq) in frequencies.enumerated() {
        eqNode!.bands[index].filterType = .parametric
        eqNode!.bands[index].frequency = freq
        eqNode!.bands[index].bandwidth = 1.0
        eqNode!.bands[index].gain = 0
        eqNode!.bands[index].bypass = false
    }

    // Chain: playerNode → timePitch → EQ → mixer
    engine.connect(primaryPlayerNode, to: primaryTimePitch, format: nil)
    engine.connect(primaryTimePitch, to: eqNode!, format: nil)
    engine.connect(eqNode!, to: engine.mainMixerNode, format: nil)
}

// Add method:
public func applyEQ(_ configuration: EqualizerConfiguration) async {
    eqConfiguration = configuration
    isEQEnabled = configuration.isEnabled

    guard let eq = eqNode else { return }

    for (index, band) in configuration.bands.enumerated() where index < 10 {
        eq.bands[index].gain = band.gain
        eq.bands[index].bypass = !configuration.isEnabled
    }
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift" "Fonic HiFiTests/Core/Audio/Engines/AVAudioEngineAdapterTests.swift"
git commit -m "feat(audio): add 10-band AVAudioUnitEQ to AVAudioEngineAdapter"
```

---

### Task 14: EQ UI View

**Files:**
- Create: `Fonic HiFi/Presentation/Views/Settings/EqualizerView.swift`

**Step 1: Create the EQ view with sliders**

```swift
// Fonic HiFi/Presentation/Views/Settings/EqualizerView.swift
import SwiftUI

struct EqualizerView: View {
    @Environment(\.audioEngine) private var audioEngine
    @State private var configuration = EqualizerConfiguration.default
    @State private var isDSPActive = false

    private let frequencyLabels = ["32", "64", "125", "250", "500", "1K", "2K", "4K", "8K", "16K"]

    var body: some View {
        VStack(spacing: 20) {
            // DSP Warning Banner
            if isDSPActive {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                    Text("DSP Active - Bit-perfect disabled")
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(8)
                .background(.orange.opacity(0.2))
                .cornerRadius(8)
            }

            // Enable Toggle
            Toggle("Enable Equalizer", isOn: $configuration.isEnabled)
                .onChange(of: configuration.isEnabled) { _, newValue in
                    isDSPActive = newValue
                    Task { await applyConfiguration() }
                }

            // Preset Picker
            Picker("Preset", selection: $configuration.presetName) {
                ForEach(Array(EqualizerConfiguration.presets.keys), id: \.self) { name in
                    Text(name).tag(name as String?)
                }
            }
            .onChange(of: configuration.presetName) { _, newValue in
                if let preset = newValue, let config = EqualizerConfiguration.presets[preset] {
                    configuration = config
                    Task { await applyConfiguration() }
                }
            }

            // Band Sliders
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<10, id: \.self) { index in
                    VStack {
                        Slider(
                            value: $configuration.bands[index].gain,
                            in: -12...12,
                            step: 0.5
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 30, height: 150)
                        .disabled(!configuration.isEnabled)
                        .onChange(of: configuration.bands[index].gain) { _, _ in
                            Task { await applyConfiguration() }
                        }

                        Text(frequencyLabels[index])
                            .font(.caption2)

                        Text("\(configuration.bands[index].gain, specifier: "%.1f")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .navigationTitle("Equalizer")
    }

    private func applyConfiguration() async {
        await audioEngine.applyEQ(configuration)
    }
}
```

**Step 2: Run to verify UI renders**

Run: `make run`
Manual test: Navigate to Settings → Equalizer, verify sliders appear and work.

**Step 3: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Settings/EqualizerView.swift"
git commit -m "feat(ui): add 10-band equalizer view with DSP active indicator"
```

---

### Task 15: Wire EQ to Settings Navigation

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/Settings/SettingsView.swift`

**Step 1: Add navigation link to EqualizerView**

```swift
// In SettingsView.swift, add in the audio section:
NavigationLink(destination: EqualizerView()) {
    Label("Equalizer", systemImage: "slider.horizontal.3")
}
```

**Step 2: Run full integration test**

Run: `make run`
Manual test: Settings → Equalizer → Enable → Adjust bands → Play music → Verify EQ affects sound.

**Step 3: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Settings/SettingsView.swift"
git commit -m "feat(settings): add equalizer navigation link"
```

---

## Summary

| Sprint | Tasks | Key Deliverables |
|--------|-------|------------------|
| 1 | 1-7 | Settings bridge, completion routing, resume playback |
| 2 | 8-11 | AVAudioEngine playback speed, dual-player gapless, home data |
| 3 | 12-15 | 10-band EQ with DSP indicator |

**Total Tasks:** 15
**Estimated Time:** 4-6 hours for experienced developer

---

Plan complete and saved to `Files/docs/plans/2025-12-06-audio-features-implementation.md`.

**Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**
