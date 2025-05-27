# Milestone 2: Core Audio Infrastructure - Detailed Plan

## Overview
Build the foundation for bit-perfect audio playback with support for multiple audio formats and engines.

## Architecture Diagram
```
┌─────────────────────────────────────────────────────────────┐
│                      AudioEngineService                       │
│                        (Protocol)                             │
├─────────────────────────────────────────────────────────────┤
│ + play(track: Track)                                         │
│ + pause()                                                    │
│ + seek(to: TimeInterval)                                     │
│ + setVolume(_ volume: Float)                                 │
│ + currentTime: TimeInterval { get }                          │
│ + duration: TimeInterval { get }                             │
│ + isPlaying: Bool { get }                                    │
│ + audioFormat: AudioFormat? { get }                          │
└─────────────────────────────────────────────────────────────┘
                               │
                    ┌──────────┴──────────┐
                    │                     │
         ┌──────────▼──────────┐ ┌───────▼──────────┐
         │  AVAudioEngineImpl  │ │ SFBAudioEngineImpl│
         │  (Standard formats) │ │  (High-res/DSD)   │
         └─────────────────────┘ └──────────────────┘
                    │                     │
         ┌──────────▼─────────────────────▼──────────┐
         │          AudioSessionManager              │
         │    (Handles iOS audio session config)     │
         └───────────────────────────────────────────┘
```

## Subtasks Breakdown

### Task 2.1: Audio Foundation Layer
**Dependencies**: None
**Deliverables**:
- [ ] Create `/Core/Audio/` directory structure
- [ ] Define `AudioFormat` enum with all supported formats
- [ ] Create `AudioError` enum for error handling
- [ ] Define `AudioEngineService` protocol
- [ ] Create `AudioEngineConfiguration` struct

```swift
// AudioFormat.swift
enum AudioFormat: String, CaseIterable {
    case mp3, aac, alac, flac, wav, aiff, ape, dsd
    
    var fileExtension: String { rawValue }
    var requiresSpecialEngine: Bool {
        switch self {
        case .flac, .ape, .dsd: return true
        default: return false
        }
    }
}

// AudioError.swift
enum AudioError: LocalizedError {
    case unsupportedFormat
    case fileNotFound
    case decodingFailed(String)
    case engineInitializationFailed
    case playbackFailed(String)
}

// AudioEngineConfiguration.swift
struct AudioEngineConfiguration {
    let bufferSize: Int
    let sampleRate: Double?
    let bitDepth: Int?
    let enableBitPerfect: Bool
}
```

---

### Task 2.2: Audio Session Management
**Dependencies**: Task 2.1
**Deliverables**:
- [ ] Create `AudioSessionManager` class
- [ ] Configure AVAudioSession for music playback
- [ ] Handle route changes (headphones, speakers)
- [ ] Implement interruption handling
- [ ] Add Now Playing info support

```swift
// AudioSessionManager.swift
final class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    func configureSession() throws
    func handleRouteChange(_ notification: Notification)
    func handleInterruption(_ notification: Notification)
    func updateNowPlayingInfo(for track: Track)
}
```

---

### Task 2.3: Format Detection Service
**Dependencies**: Task 2.1
**Deliverables**:
- [ ] Create `AudioFormatDetector` service
- [ ] Implement file header analysis
- [ ] Extract sample rate, bit depth, channels
- [ ] Validate file integrity
- [ ] Create format quality badge system

```swift
// AudioFormatDetector.swift
struct AudioFileInfo {
    let format: AudioFormat
    let sampleRate: Int
    let bitDepth: Int
    let channels: Int
    let bitrate: Int?
    let duration: TimeInterval
    let fileSize: Int64
}

protocol AudioFormatDetectorService {
    func detectFormat(at url: URL) async throws -> AudioFileInfo
    func validateFile(at url: URL) async throws -> Bool
}
```

---

### Task 2.4: AVAudioEngine Implementation
**Dependencies**: Tasks 2.1, 2.2, 2.3
**Deliverables**:
- [ ] Create `AVAudioEngineImpl` class
- [ ] Implement basic playback (play, pause, stop)
- [ ] Add seek functionality
- [ ] Implement volume control
- [ ] Handle standard formats (MP3, AAC, ALAC)

```swift
// AVAudioEngineImpl.swift
final class AVAudioEngineImpl: AudioEngineService {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    
    init() throws
    func play(track: Track) async throws
    func pause()
    func seek(to time: TimeInterval)
    // ... other protocol methods
}
```

---

### Task 2.5: Audio Engine Factory
**Dependencies**: Task 2.4
**Deliverables**:
- [ ] Create `AudioEngineFactory` 
- [ ] Implement engine selection logic
- [ ] Add fallback mechanism
- [ ] Create engine pooling for performance

```swift
// AudioEngineFactory.swift
final class AudioEngineFactory {
    static func createEngine(for format: AudioFormat) throws -> AudioEngineService {
        switch format {
        case .mp3, .aac, .alac, .wav, .aiff:
            return try AVAudioEngineImpl()
        case .flac, .ape, .dsd:
            return try SFBAudioEngineImpl() // Phase 2
        }
    }
}
```

---

### Task 2.6: Playback State Management
**Dependencies**: Tasks 2.4, 2.5
**Deliverables**:
- [ ] Create `PlaybackState` enum
- [ ] Implement `PlaybackStateManager`
- [ ] Add state change notifications
- [ ] Handle error states gracefully

```swift
// PlaybackState.swift
enum PlaybackState {
    case idle
    case loading
    case playing
    case paused
    case seeking
    case error(AudioError)
}

// PlaybackStateManager.swift
@MainActor
final class PlaybackStateManager: ObservableObject {
    @Published private(set) var state: PlaybackState = .idle
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
}
```

---

### Task 2.7: Audio Queue Management
**Dependencies**: Task 2.6
**Deliverables**:
- [ ] Create `AudioQueue` class
- [ ] Implement queue operations (add, remove, reorder)
- [ ] Add shuffle and repeat modes
- [ ] Implement gapless playback preparation

```swift
// AudioQueue.swift
final class AudioQueue: ObservableObject {
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var currentIndex: Int?
    @Published var shuffleMode: ShuffleMode = .off
    @Published var repeatMode: RepeatMode = .off
    
    func add(_ track: Track)
    func remove(at index: Int)
    func move(from: Int, to: Int)
    func next() -> Track?
    func previous() -> Track?
}
```

---

### Task 2.8: Bit-Perfect Validation
**Dependencies**: Tasks 2.4, 2.5
**Deliverables**:
- [ ] Create `BitPerfectValidator` service
- [ ] Check hardware capabilities
- [ ] Verify sample rate matching
- [ ] Implement bypass for DSP/effects
- [ ] Add visual indicator system

```swift
// BitPerfectValidator.swift
struct BitPerfectStatus {
    let isActive: Bool
    let sourceSampleRate: Int
    let outputSampleRate: Int
    let sourceBitDepth: Int
    let outputBitDepth: Int
    let hasProcessing: Bool
}

protocol BitPerfectValidatorService {
    func validateBitPerfect(for info: AudioFileInfo) -> BitPerfectStatus
    func canAchieveBitPerfect(with device: AudioDevice) -> Bool
}
```

---

### Task 2.9: Audio Monitoring & Metrics
**Dependencies**: All previous tasks
**Deliverables**:
- [ ] Create `AudioMetricsCollector`
- [ ] Monitor CPU/memory usage
- [ ] Track buffer underruns
- [ ] Log format conversion overhead
- [ ] Performance mode switching logic

```swift
// AudioMetricsCollector.swift
struct AudioMetrics {
    let cpuUsage: Float
    let memoryUsage: Int64
    let bufferUnderruns: Int
    let decodingLatency: TimeInterval
}

final class AudioMetricsCollector {
    func startMonitoring()
    func stopMonitoring()
    func currentMetrics() -> AudioMetrics
}
```

---

### Task 2.10: Integration & Testing
**Dependencies**: All previous tasks
**Deliverables**:
- [ ] Create `AudioService` facade
- [ ] Write unit tests for each component
- [ ] Create audio format test suite
- [ ] Performance benchmarks
- [ ] Memory leak detection

```swift
// AudioService.swift (Facade)
final class AudioService: ObservableObject {
    private let engineFactory: AudioEngineFactory
    private let sessionManager: AudioSessionManager
    private let formatDetector: AudioFormatDetectorService
    private let stateManager: PlaybackStateManager
    private let queue: AudioQueue
    
    func play(_ track: Track) async throws
    func pause()
    func next()
    func previous()
    // Convenience methods combining all services
}
```

---

## Testing Strategy

### Unit Tests Required:
1. **Format Detection Tests**
   - Test each supported format
   - Verify metadata extraction
   - Test corrupted file handling

2. **Playback Tests**
   - Play/pause/seek operations
   - State transitions
   - Error handling

3. **Queue Tests**
   - Add/remove/reorder operations
   - Shuffle algorithms
   - Repeat mode logic

### Integration Tests:
1. **End-to-end playback**
   - Load file → Detect format → Select engine → Play
   - Format switching during playback
   - Background audio handling

### Performance Tests:
1. **Memory usage** during playback
2. **CPU usage** for different formats
3. **Battery drain** measurements
4. **Format switching** speed

---

## Dependencies & Interfaces

### External Dependencies:
- **AVFoundation** (iOS built-in)
- **MediaPlayer** framework (Now Playing)
- **SFBAudioEngine** (to be added in Task 2.5 extension)

### Internal Interfaces:
```swift
// Core protocols that other modules will use
protocol AudioPlaybackDelegate: AnyObject {
    func playbackStateDidChange(_ state: PlaybackState)
    func playbackTimeDidUpdate(current: TimeInterval, duration: TimeInterval)
    func playbackDidEncounterError(_ error: AudioError)
}

protocol AudioQueueDelegate: AnyObject {
    func queueDidUpdate(_ queue: [Track])
    func currentTrackDidChange(_ track: Track?)
}
```

---

## Risk Mitigation

### Technical Risks:
1. **Audio glitches**: Implement robust buffering
2. **Format incompatibility**: Comprehensive format testing
3. **Memory pressure**: Efficient buffer management
4. **Background audio**: Proper session handling

### Mitigation Strategies:
- Early testing with various file formats
- Progressive enhancement (basic → advanced features)
- Fallback mechanisms for unsupported formats
- Extensive error handling and recovery

---

## Success Criteria

### Functional:
- [ ] Play MP3, AAC, ALAC without issues
- [ ] Gapless playback between tracks
- [ ] Smooth seeking without audio artifacts
- [ ] Background audio continues properly
- [ ] Correct Now Playing information

### Performance:
- [ ] < 100ms to start playback
- [ ] < 50ms to pause/resume
- [ ] < 5% CPU usage during playback
- [ ] No memory leaks after 1 hour
- [ ] Battery life meets targets

### Quality:
- [ ] Bit-perfect output for supported formats
- [ ] No audio dropouts or glitches
- [ ] Proper error messages for failures
- [ ] Smooth state transitions
- [ ] Thread-safe operations