# Core/Audio CLAUDE.md

Module-specific guidance for the audio subsystem. Always verify iOS/Swift claims with apple-rag/sosumi.

## STRICT IMPLEMENTATION RULES

- **NEVER** create mock data, fake APIs, or placeholder values
- **NEVER** use TODO, FIXME, or stub comments in code
- **NEVER** comment out code - remove or implement properly
- **ALWAYS** verify implementation matches user requirements exactly
- **ALWAYS** implement complete, working solutions
- **ALWAYS** double-check before editing/commenting - implement correctly
- Comments are OK if concise and helpful for understanding

## CRITICAL THREADING RULES [Verified-Code]

**MainActor Boundaries:**
- AudioEngineFacade: `@MainActor` class - ALL methods run on main thread
- UI Updates: Use `Task { @MainActor in ... }` from audio callbacks
- Audio Callbacks: Dispatch to MainActor for state changes

**ACTUAL PATTERN** (`AVAudioEngineAdapter.swift:184-186`):
```swift
// Audio callback runs on Core Audio's background thread
Task { @MainActor [weak self] in
    self?.handlePlaybackCompletionSync()
}
```

**ACTUAL PATTERN** (`AudioEngineFacade.swift:602-604`):
```swift
// UserDefaults change notification
Task { @MainActor in
    await self.handlePreferenceChange()
}
```

## AUDIO ENGINE ARCHITECTURE

### Engine Selection Logic [Verified-Code]
```
AudioEngineFacade.swift:20 (Main Coordinator)
├── AVAudioEngineAdapter.swift (MP3, AAC, ALAC) - COMPLETE
└── AudioKitEngineAdapter.swift (Enhanced DSP) - COMPLETE
```

**ACTUAL CODE** (`AudioEngineFacade.swift:20`):
```swift
@MainActor
public final class AudioEngineFacade: ObservableObject {
    @Published public private(set) var currentTrack: Track?
    @Published public private(set) var isPlaying = false
}
```

**Format Detection Flow:**
1. `AudioFormatDetectionManager.detectFormat()` → AudioFormat
2. `AudioEngineFactory.createEngine()` → Appropriate adapter
3. Fallback chain if primary fails

## AVAudioSession Configuration [Verified-Apple]

**Background Audio Setup:**
```swift
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playback, mode: .default)
try session.setPreferredSampleRate(Double(format.sampleRate))
try session.setActive(true)
```

**Interruption Handling [Verified-Apple]:**
```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleInterruption),
    name: AVAudioSession.interruptionNotification,
    object: nil
)
```

**Route Change Detection [Verified-Apple]:**
```swift
// Monitor AVAudioSession.routeChangeNotification
// Check session.currentRoute for output changes
```

## STATE MANAGEMENT

**PlaybackStateManager Flow:**
1. User action → ViewModel
2. ViewModel → AudioEngineFacade
3. Engine → PlaybackStateManager update
4. Published state → All observers
5. UI updates via @Published

**Critical State Transitions:**
- play() → Check engine ready → Update state
- pause() → Immediate state update → Engine pause
- stop() → Clear current track → Reset state

## BIT-PERFECT VALIDATION [Verified-Apple]

**Validation Steps:**
1. Check `session.sampleRate == format.sampleRate`
2. Verify no format conversion in engine
3. Monitor for rate changes during playback
4. Log any sample rate mismatches

## NOW PLAYING INFO [Verified-Apple]

**Required for Background:**
```swift
MPNowPlayingInfoCenter.default().nowPlayingInfo = [
    MPMediaItemPropertyTitle: track.title,
    MPMediaItemPropertyArtist: track.artist,
    MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
    MPMediaItemPropertyPlaybackDuration: duration
]
```

## COMMON ISSUES & SOLUTIONS

**Threading Crashes:**
- Missing `@MainActor` on facade methods
- Synchronous UI updates from background
- Fix: Wrap in `Task { @MainActor in ... }`

**ACTUAL FIX** (`AVAudioEngineAdapter.swift:427-429`):
```swift
// Called from Task { @MainActor in } to avoid crashes
private func handlePlaybackCompletionSync() {
    assertMainThread()
    // Implementation
}
```

**Audio Interruptions:**
- Check `InterruptionType.began/ended`
- Resume only if `shouldResume` option present
- Save playback position before interruption

**Background Playback:**
- Add `audio` to UIBackgroundModes in Info.plist
- Configure AVAudioSession before playback
- Update Now Playing Info regularly

## PERFORMANCE TARGETS

- Audio switch latency: < 10ms
- Engine initialization: < 50ms
- State update → UI: < 16ms (60fps)

## DEBUG COMMANDS

```bash
make profile-audio      # Audio latency profiling
make memory-leaks      # Check for audio leaks
make logs-stream       # Live audio subsystem logs
```

## KEY FILES

- `AudioEngineFacade.swift:20`: Main coordinator (@MainActor)
- `PlaybackStateManager.swift`: State management
- `AudioSessionManager.swift`: Session handling (NOT AudioSessionActor)
- `BitPerfectValidator.swift`: Validation logic
- `AVAudioEngineAdapter.swift`: AVAudioEngine implementation
- `AudioKitEngineAdapter.swift`: AudioKit implementation
- `ProgressTimerManager.swift:17`: Timer with Task { @MainActor in }