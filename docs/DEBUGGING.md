# Audio Debugging Guide

## Quick Debug Commands (via Makefile)

```bash
# Find all audio-related code
make find-audio

# Search for specific audio patterns
make search PATTERN='AudioEngine'

# Find all TODO/FIXME in audio code
make find-todos

# Interactive search for debugging
make search-interactive

# View specific file with highlighting
make view FILE=Core/Audio/AudioEngineFacade.swift
```

## Enhanced Debugging Commands

### 1. Enable Verbose Logging

```swift
// AudioEngineLogger does not exist - use os_log instead
import OSLog

let logger = Logger(subsystem: "com.fonichifi.audio", category: "playback")
logger.debug("Audio state: \(playbackState.description)")
```

### 2. Console.app Filtering

```bash
# Show recent logs
make logs-show

# Stream live logs
make logs-stream

# Filter by subsystem
make logs-filter SUBSYSTEM='com.fonichifi.audio'
```

### 3. Symbolication for Crash Logs

```bash
# Symbolicate crash logs
make symbolicate CRASH_LOG=path/to/crash.log
```

### 4. Audio Route Debugging [Verified-Apple]

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

### 5. Memory Debugging

```bash
# Detect memory leaks
make memory-leaks

# Memory graph debugging
make memory-graph

# Memory graph debugging in Xcode
# Debug > Debug Memory Graph (while app is running)
```

### 6. Audio MIDI Setup Verification

- Open `/Applications/Utilities/Audio MIDI Setup.app`
- Check format settings match app requirements
- Verify sample rate capabilities
- Test with different output devices

## Common Audio Issues

### Threading Crashes
- Check for missing `@MainActor` annotations
- Verify `Task { @MainActor in ... }` wrapping
- Look for synchronous UI updates from background threads

### State Desynchronization
- Ensure single PlaybackStateManager instance
- Check for duplicate state updates
- Verify proper state transition validation

### Engine Switching Failures
- Review format detection logic
- Check engine capability matrix
- Verify engine cleanup in facade coordinators

## Performance Profiling

```bash
# Profile CPU usage
make profile-cpu

# Monitor memory allocations
make profile-memory

# Audio latency profiling
make profile-audio

# Memory graph debugging
make memory-graph

# Check for memory leaks
make memory-leaks
```

## AVAudioSession Best Practices [Verified-Apple]

### Bit-Perfect Playback Validation

```swift
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playback, mode: .default, options: [])
try session.setPreferredSampleRate(Double(audioFormat.sampleRate))
try session.setActive(true)

if session.sampleRate == Double(audioFormat.sampleRate) {
    // Bit-perfect playback confirmed
}
```

### Audio Interruption Handling

```swift
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
        // Handle interruption began
    case .ended:
        // Handle interruption ended
    @unknown default:
        break
    }
}
```

### Background Audio Configuration

- Add `audio` to `UIBackgroundModes` in Info.plist
- Configure `AVAudioSession` for background playback
- Implement Now Playing Info Center updates
- Handle remote control events