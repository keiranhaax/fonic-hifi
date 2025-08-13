# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Fonic HiFi - High-Fidelity iOS Audio Player

A sophisticated iOS audiophile music player built with Swift 6, SwiftUI, and AudioKit, focusing on bit-perfect playback and format versatility.

## Build Commands

```bash
# Build for Debug (iOS Simulator - iPhone 16 Pro, iOS 26)
xcodebuild -scheme "Fonic HiFi" -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' build

# Build for Release
xcodebuild -scheme "Fonic HiFi" -sdk iphonesimulator -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' build

# Run Unit Tests
xcodebuild test -scheme "Fonic HiFi" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' -only-testing:"Fonic HiFiTests"

# Run UI Tests
xcodebuild test -scheme "Fonic HiFi" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' -only-testing:"Fonic HiFiUITests"

# Clean Build
xcodebuild clean -scheme "Fonic HiFi"

# Open in Xcode
open "Fonic HiFi.xcodeproj"
```

## Architecture Overview

### Audio Engine Facade Pattern

The audio system uses a sophisticated facade pattern with automatic engine selection based on audio format:

```
AudioEngineFacade (Main coordinator)
├── AVAudioEngineAdapter (Standard formats: MP3, AAC, ALAC)
├── AudioKitEngineAdapter (DSP-heavy formats, equalizer support)
├── SFBAudioEngineAdapter (High-res: FLAC, DSD, MQA)
└── FFmpegEngineAdapter (Exotic formats: OGG, OPUS, APE)
```

**Engine Selection Logic** (`Core/Audio/Factory/AudioEngineFactory.swift`):
- Detects format via `AudioFormatDetectionManager`
- Selects optimal engine based on format capabilities
- Falls back gracefully if primary engine fails
- Maintains bit-perfect playback when possible

### Concurrency Model (Swift 6.2)

**Actor Isolation Boundaries:**
```swift
@MainActor: All UI components, ViewModels, AudioEngineFacade
TrackDataActor: SwiftData operations, file I/O
AudioSessionActor: Audio session configuration (implicit)
```

**Critical Threading Rules:**
1. Audio callbacks MUST dispatch to MainActor for UI updates
2. SwiftData operations MUST go through TrackDataActor
3. Use `Task { @MainActor in ... }` for audio → UI communication
4. All cross-actor types MUST conform to Sendable

**Swift 6.2 Concurrency Updates:**
- **Default Main Actor**: Async functions now run on caller's actor by default
- **No Thread Hopping**: UI code stays on main thread unless explicitly moved
- **Actor-Isolated Conformances**: Mark protocol conformances with `@MainActor` when needed
- **Capture Lists for Sendable**: Use `[variable]` syntax in background closures:
  ```swift
  .visualEffect { [isPlaying] content, _ in
      // Safe: using captured copy, not self.isPlaying
      content.blur(radius: isPlaying ? 2 : 0)
  }
  ```

### State Management Architecture

**Unified Playback State** (`Core/Audio/Playback/PlaybackStateManager.swift`):
```
PlaybackStateManager (Single source of truth)
├── PlaybackState (Immutable state snapshot)
├── PlaybackStateStore (Persistence layer)
└── Published to:
    ├── AudioEngineFacade
    ├── AppState (Global UI state)
    └── Individual ViewModels
```

**State Flow:**
1. User action → ViewModel method
2. ViewModel → AudioEngineFacade command
3. AudioEngine → PlaybackStateManager update
4. State change → Published to all observers
5. UI updates via @Published properties

## Critical Implementation Patterns

### Adding a New Audio Format

1. **Create Decoder** in `Core/Audio/Decoders/`
2. **Update Detection** in `AudioFormatDetectionManager.detectFormat()`
3. **Map to Engine** in `AudioEngineFactory.createEngine()`
4. **Add UI Badge** in `Presentation/Components/FormatBadge.swift`
5. **Test with Sample** in `Files/TestAudio/`

### Fixing Audio Playback Issues

**Common Issues & Solutions:**

1. **Threading Crashes**
   - Check for missing `@MainActor` annotations
   - Verify `Task { @MainActor in ... }` wrapping
   - Look for synchronous UI updates from background threads

2. **State Desynchronization**
   - Ensure single PlaybackStateManager instance
   - Check for duplicate state updates
   - Verify proper state transition validation

3. **Engine Switching Failures**
   - Review format detection logic
   - Check engine capability matrix
   - Verify proper cleanup in `switchEngine()`

### Audio Playback Best Practices

**Bit-Perfect Playback Validation:**
```swift
// Configure AVAudioSession for bit-perfect playback
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playback, mode: .default, options: [])
try session.setPreferredSampleRate(Double(audioFormat.sampleRate))
try session.setActive(true)

// Validate bit-perfect path
if session.sampleRate == Double(audioFormat.sampleRate) {
    // Bit-perfect playback achieved
}
```

**Audio Interruption Handling:**
```swift
// Register for interruption notifications
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleInterruption),
    name: AVAudioSession.interruptionNotification,
    object: nil
)

@objc func handleInterruption(_ notification: Notification) {
    guard let info = notification.userInfo,
          let type = info[AVAudioSessionInterruptionTypeKey] as? UInt,
          let interruption = AVAudioSession.InterruptionType(rawValue: type) else { return }
    
    switch interruption {
    case .began:
        // Pause playback
    case .ended:
        // Resume if appropriate
    @unknown default:
        break
    }
}
```

**Background Audio Configuration:**
- Add `audio` to `UIBackgroundModes` in Info.plist
- Configure `AVAudioSession` for background playback
- Implement Now Playing Info Center updates
- Handle remote control events

### Performance Optimization Points

**Critical Metrics:**
- Audio switch latency: < 10ms (current: 8ms)
- Library scan: > 1000 tracks/sec
- Memory per 100 tracks: < 1MB
- UI responsiveness: 60fps always

**Optimization Targets:**
1. `LibraryImportService`: Batch SwiftData operations
2. `AudioQueueManager`: Preload next track metadata
3. `AudioEngineFacade`: Cache engine instances
4. `TrackDataActor`: Implement pagination for large libraries

**Performance Monitoring with Instruments:**
```bash
# Profile CPU usage
instruments -t "Time Profiler" -D cpu_profile.trace "Fonic HiFi.app"

# Monitor memory allocations
instruments -t "Allocations" -D memory.trace "Fonic HiFi.app"

# Audio latency profiling
instruments -t "System Trace" -D audio.trace "Fonic HiFi.app"

# Memory graph debugging
xcrun xctrace record --template "Allocations" --output memory_graph.trace --attach "Fonic HiFi"
```

**SwiftUI Performance Optimization:**
- Use `LazyVStack`/`LazyHStack` for large lists
- Implement `Equatable` on complex views to prevent re-renders
- Avoid `GeometryReader` unless absolutely necessary
- Use `.task` modifier instead of `.onAppear` for async work
- Profile with View Body Counter in Instruments

## SwiftData Integration

**Model Persistence** (`Data/Models/` and `Data/Actors/TrackDataActor.swift`):
- All database operations through TrackDataActor
- Batch imports for performance
- Relationships: Artist ↔ Album ↔ Track ↔ Playlist
- Migration support via versioned schemas

## Testing Approach

**Audio Engine Testing:**
```swift
// Test pattern for engine switching
func testEngineSwitch() async {
    let facade = AudioEngineFacade(...)
    try await facade.load(flacFile)  // Should use SFBAudioEngine
    XCTAssertTrue(facade.currentEngine is SFBAudioEngineAdapter)
}
```

**State Management Testing:**
```swift
// Test pattern for state synchronization
func testStateSync() async {
    let manager = PlaybackStateManager()
    await manager.updateState { $0.isPlaying = true }
    XCTAssertTrue(manager.currentState.isPlaying)
}
```

**Async Testing with Confirmations:**
```swift
// Test async events with confirmations
func testAudioInterruption() async {
    await confirmation(expectedCount: 2) { interruption in
        audioEngine.onInterruption = { _ in
            interruption()
        }
        // Simulate interruption
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil)
    }
}
```

**Mock Patterns for Audio Engines:**
```swift
// Protocol-based mocking
protocol AudioEngineProtocol {
    func play() async throws
    func pause() async
}

class MockAudioEngine: AudioEngineProtocol {
    var playCalled = false
    func play() async throws {
        playCalled = true
    }
    func pause() async {
        // Mock implementation
    }
}
```

**UI Testing for Audio Playback:**
```bash
# Run specific UI test for audio controls
xcodebuild test -scheme "Fonic HiFi" -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
    -only-testing:"Fonic HiFiUITests/AudioControlsUITests/testPlayPauseButton"
```

## Current Development Status

**Completed Milestones:**
- ✅ Swift 6 concurrency compliance
- ✅ Threading crash fixes (dispatch queue assertions resolved)
- ✅ Unified state management (PlaybackStateManager)
- ✅ Settings UI with File Manager
- ✅ Audio format detection system

**In Progress:**
- 🚧 Engine consolidation (merging AVAudio + AudioKit)
- 🚧 Now Playing screen implementation
- 🚧 Queue management UI

**Known Issues:**
- Engine switching latency spikes on first switch
- Memory leak in AudioKit DSP chain (workaround: periodic cleanup)
- SwiftData relationship faulting performance

## Development Workflow Patterns

### Feature Development Flow
1. Create feature branch from main
2. Implement with @MainActor boundaries
3. Add unit tests for business logic
4. Manual test on iPhone 16 Pro simulator
5. Profile with Instruments if performance-critical
6. Update this CLAUDE.md if architecture changes

### Debugging Audio Issues

**Enhanced Debugging Commands:**

1. **Enable Verbose Logging:**
   ```swift
   AudioEngineLogger.verboseMode = true
   os_log(.debug, "Audio state: %{public}@", playbackState.description)
   ```

2. **Console.app Filtering:**
   ```bash
   # Filter logs by subsystem
   log show --predicate 'subsystem == "com.fonichifi.audio"' --last 1h
   
   # Stream live logs
   log stream --predicate 'subsystem == "com.fonichifi.audio"' --level debug
   
   # Export crash logs
   log collect --device "iPhone 16 Pro" --start '2025-08-12 00:00:00'
   ```

3. **Symbolication for Crash Logs:**
   ```bash
   # Symbolicate crash report
   atos -arch arm64 -o "Fonic HiFi.app.dSYM/Contents/Resources/DWARF/Fonic HiFi" -l 0x100000000 0x1001234567
   
   # Use symbolicatecrash tool
   symbolicatecrash crash_log.crash "Fonic HiFi.app.dSYM" > symbolicated.crash
   ```

4. **Audio Route Debugging:**
   ```swift
   // Monitor route changes
   NotificationCenter.default.addObserver(
       self,
       selector: #selector(routeChanged),
       name: AVAudioSession.routeChangeNotification,
       object: nil
   )
   
   @objc func routeChanged(_ notification: Notification) {
       let session = AVAudioSession.sharedInstance()
       print("Current route: \(session.currentRoute)")
       print("Available inputs: \(session.availableInputs ?? [])")
   }
   ```

5. **Memory Debugging:**
   ```bash
   # Detect memory leaks
   leaks --atExit -- "Fonic HiFi.app"
   
   # Memory graph debugging in Xcode
   # Debug > Debug Memory Graph (while app is running)
   ```

6. **Audio MIDI Setup Verification:**
   - Open `/Applications/Utilities/Audio MIDI Setup.app`
   - Check format settings match app requirements
   - Verify sample rate capabilities
   - Test with different output devices

## Project-Specific Context

**Audio Quality Philosophy:**
- Bit-perfect playback is the primary goal
- Format support breadth over depth
- User control over processing chain
- Transparency in signal path

**Privacy & Security:**
- No cloud services or analytics
- All data stored locally
- No network permissions required
- File access limited to user-selected directories

**Target Audience:**
- Audiophiles requiring bit-perfect playback
- Users with diverse format collections
- Privacy-conscious individuals
- iOS power users

## Architecture Decision Records

**Why Multiple Audio Engines?**
- AVAudioEngine: Best iOS integration, limited format support
- AudioKit: Superior DSP, higher CPU usage
- SFBAudioEngine: True bit-perfect, complex setup
- Trade-off: Complexity for flexibility

**Why Actor-Based Concurrency?**
- Swift 6 strict concurrency eliminates races
- Clear isolation boundaries
- Compile-time safety
- Future-proof architecture

**Why SwiftData over Core Data?**
- Modern Swift-first API
- Better SwiftUI integration
- Automatic iCloud sync (future)
- Simpler relationship management