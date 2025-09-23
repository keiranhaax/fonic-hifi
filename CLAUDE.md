# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## CRITICAL RULES
- **MANDATORY**: After file edits, ask: "Would you like me to commit these changes?"
- **MANDATORY**: Verify all iOS/Swift claims via apple-rag/sosumi BEFORE stating as facts
- **ALWAYS**: Use verification tags: [Verified-Apple], [Verified-Code], [Inference], [Unverified]
- **ALWAYS**: Use TodoWrite for complex tasks (3+ steps) to track progress
- **NEVER**: Make unverified claims about iOS/Swift features
- **NEVER**: Create files unless necessary - prefer editing existing files
- **NEVER**: Use placeholder, mock, or fake data in code
- **NEVER**: Leave commented out code in files
- **NEVER**: Create TODO or FIXME comments

## VERIFICATION PROTOCOL
Before ANY iOS/Swift claim: Search → Verify → Tag
```swift
mcp__apple-rag-mcp__search("feature") → [Verified-Apple]
mcp__sosumi__fetchAppleDocumentation("/path") → Confirm
```

## TOOL PREFERENCES
- **Search**: `make search PATTERN='text'` > Task tool > multiple Grep/Glob calls
- **Files**: Read before Edit, MultiEdit > single Edit
- **Git**: `make pr-create`, `make issues` > gh CLI directly
- **Tests**: `make test-unit` > manual xcodebuild commands
- **Lint**: `make lint` after every code change
- **Format**: `make format` before commits
- **Context**: /clear between unrelated tasks

## iOS 26 MODERN API REQUIREMENTS

**MANDATORY**: This is an iOS 26-only project with NO backwards compatibility:
- **Target**: iOS 26.0 minimum deployment target - NO fallbacks to older iOS versions
- **APIs**: Use ONLY modern iOS 26 APIs - no compatibility wrappers or conditional availability
- **Swift**: Swift 6.2 with all modern concurrency features - no legacy patterns
- **NO @available checks**: Remove all `@available(iOS 26, *)` - iOS 26 is guaranteed
- **NO if #available**: Remove all `if #available(iOS 26, *)` - always use modern APIs
- **Liquid Glass**: Use native iOS 26 `.glassEffect()` APIs directly - no custom fallbacks
- **SwiftUI**: Use iOS 26 SwiftUI enhancements without checks
- **NEVER**: Write fallback code for older iOS versions
- **NEVER**: Add compatibility layers or version checks
- **ALWAYS**: Assume iOS 26 features are available

## Fonic HiFi - High-Fidelity iOS Audio Player

A sophisticated iOS 26 audiophile music player built with Swift 6.2, SwiftUI, AVAudioEngine, and AudioKit, focusing on bit-perfect playback and format versatility.

### Required Development Tools

**Essential (via Homebrew):**
- `xcbeautify` - Xcode build output formatting
- `swiftlint` - Swift code linting
- `swiftformat` - Swift code formatting

**Enhanced Search & Navigation:**
- `ripgrep (rg)` - Ultra-fast code search
- `fd` - Fast file finder
- `fzf` - Interactive fuzzy finder
- `bat` - Syntax-highlighted file viewer
- `eza` - Modern file tree viewer

**Performance & Analysis:**
- `tokei` - Code statistics
- `hyperfine` - Benchmarking tool
- `watchman` - File watching automation

**Install all tools:**
```bash
make install-deps
```

**Check tool availability:**
```bash
make check-deps
```

## Build Commands - Using Makefile

**MANDATORY**: Always use Makefile commands for consistency and efficiency.

### Primary Build Commands
```bash
# Build for Debug (iPhone 16 Pro Simulator, iOS 26)
make build

# Build for Release
make build-release

# Build and run in simulator
make run

# Clean build artifacts and derived data
make clean

# Open project in Xcode
make open
```

### Testing Commands
```bash
# Run all tests (unit + UI)
make test

# Run unit tests only (faster)
make test-unit

# Run UI tests only
make test-ui

# Generate test coverage report
make coverage
```

### Code Quality Commands
```bash
# Run SwiftLint (ALWAYS run after code changes)
make lint

# Auto-format code with SwiftFormat
make format

# Run static analysis
make analyze
```

### Search & Navigation (ripgrep, fd, fzf)
```bash
# Fast code search
make search PATTERN='your search term'

# Find files by pattern
make find-files PATTERN='*.swift'

# Find all TODO/FIXME comments
make find-todos

# Find all ViewModels
make find-viewmodels

# Find AudioKit/audio references
make find-audio

# Find Core module references
make find-core

# Interactive file finder with preview
make find-interactive

# Interactive code search
make search-interactive
```

### Code Analysis (tokei, eza, bat)
```bash
# Show code statistics
make stats

# Statistics per feature module
make stats-features

# Visual project structure
make tree

# View file with syntax highlighting
make view FILE=path/to/file.swift
```

### Performance Benchmarking (hyperfine)
```bash
# Benchmark build performance
make benchmark-build

# Benchmark test execution
make benchmark-test

# Full performance analysis
make benchmark-all
```

### Simulator Management
```bash
# Boot iPhone 16 Pro simulator
make simulator-boot

# Shutdown all simulators
make simulator-shutdown

# List available simulators
make simulator-list
```

### Dependency Management
```bash
# Check if required tools are installed
make check-deps

# Install missing dependencies via Homebrew
make install-deps
```

### AI Assistance (Optional - requires mods/llm)
```bash
# Explain code with AI
make ai-explain FILE=path/to/file.swift

# Generate tests with AI
make ai-test-generate FILE=path/to/file.swift

# AI code review of staged changes
make ai-review

# Generate commit message with AI
make ai-commit
```

### Git & GitHub Integration
```bash
# Create pull request
make pr-create

# List GitHub issues
make issues

# Colored git diff
make diff
```

## Architecture Overview [Verified-Code]

### Audio Engine Facade Pattern [Verified-Code]

The audio system uses a sophisticated facade pattern with automatic engine selection based on audio format:

```
AudioEngineFacade (Main coordinator)
├── AVAudioEngineAdapter (Standard formats: MP3, AAC, ALAC) - IMPLEMENTED
├── AudioKitEngineAdapter (Enhanced playback with AudioKit) - IMPLEMENTED
├── SFBAudioEngineAdapter - STUB ONLY (TODO implementation)
└── FFmpegEngineAdapter - STUB ONLY (TODO implementation)
```

**Engine Selection Logic** (`Core/Audio/Factory/AudioEngineFactory.swift`): [Partially Implemented]
- Detects format via `AudioFormatDetectionManager`
- Selects optimal engine based on format capabilities
- Falls back gracefully if primary engine fails
- Maintains bit-perfect playback when possible

### Concurrency Model (Swift 6.2) [Verified-Apple]

**Actor Isolation Boundaries:** [Verified-Apple]
```swift
@MainActor: All UI components, ViewModels, AudioEngineFacade
TrackDataActor: SwiftData operations, file I/O
[Does Not Exist] ~~AudioSessionActor~~ - Uses AudioSessionManager/AudioSessionService instead
```

**Critical Threading Rules:**
1. Audio callbacks MUST dispatch to MainActor for UI updates
2. SwiftData operations MUST go through TrackDataActor
3. Use `Task { @MainActor in ... }` for audio → UI communication
4. All cross-actor types MUST conform to Sendable

**Swift 6.2 Concurrency (iOS 26):** [Verified-Apple]
- **Default Main Actor**: Async functions run on caller's actor by default
- **No Thread Hopping**: UI code stays on main thread unless explicitly moved
- **Actor-Isolated Conformances**: Mark protocol conformances with `@MainActor` when needed
- **Capture Lists for Sendable**: Use `[variable]` syntax in background closures:
  ```swift
  .visualEffect { [isPlaying] content, _ in
      content.blur(radius: isPlaying ? 2 : 0)
  }
  ```
- **No Legacy Patterns**: Use modern async/await everywhere - no completion handlers

### State Management Architecture [Verified-Code]

**Unified Playback State** (`Core/Audio/Playback/PlaybackStateManager.swift`):
```
PlaybackStateManager (Single source of truth)
├── PlaybackState (Immutable state snapshot)
├── PlaybackStateStore (Persistence layer)
└── Published to:
    ├── AudioEngineFacade
    ├── [REMOVED - Merged into AudioEngineFacade] ~~AppState~~
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

1. **[Directory Does Not Exist]** ~~Create Decoder in `Core/Audio/Decoders/`~~
2. **Update Detection** in `AudioFormatDetectionManager.detectFormat()`
3. **Map to Engine** in `AudioEngineFactory.createEngine()`
4. **[File Does Not Exist]** ~~Add UI Badge in `Presentation/Components/FormatBadge.swift`~~
5. **[Directory Does Not Exist]** ~~Test with Sample in `Files/TestAudio/`~~

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
   - [Method Does Not Exist] ~~Verify proper cleanup in `switchEngine()`~~

### Audio Playback Best Practices

**Bit-Perfect Playback Validation:** [Verified-Apple]
```swift
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playback, mode: .default, options: [])
try session.setPreferredSampleRate(Double(audioFormat.sampleRate))
try session.setActive(true)

if session.sampleRate == Double(audioFormat.sampleRate) {

}
```

**Audio Interruption Handling:** [Verified-Apple]
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

    case .ended:

    @unknown default:
        break
    }
}
```

**Background Audio Configuration:** [Verified-Apple]
- Add `audio` to `UIBackgroundModes` in Info.plist
- Configure `AVAudioSession` for background playback
- Implement Now Playing Info Center updates
- Handle remote control events

### Performance Optimization Points

**Performance Targets:** [UNVERIFIED]
- Audio switch latency: < 10ms target
- Library scan: > 1000 tracks/sec target
- Memory per 100 tracks: < 1MB target
- UI responsiveness: 60fps target

**NOTE**: These are optimization targets, not verified measurements

**Optimization Targets:**
1. `LibraryImportService`: Batch SwiftData operations
2. `AudioQueueManager`: Preload next track metadata
3. `AudioEngineFacade`: Cache engine instances
4. `TrackDataActor`: Implement pagination for large libraries

**Performance Monitoring with Instruments:** [Verified-Apple]
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

**SwiftUI Performance Optimization:** [Verified-Apple]
- Use `LazyVStack`/`LazyHStack` for large lists
- Implement `Equatable` on complex views to prevent re-renders
- Avoid `GeometryReader` unless absolutely necessary
- Use `.task` modifier instead of `.onAppear` for async work
- Profile with View Body Counter in Instruments

## SwiftData Integration [Verified-Apple]

**Model Persistence** (`Data/Models/` and `Data/Actors/TrackDataActor.swift`):
- All database operations through TrackDataActor
- Batch imports for performance
- Relationships: Artist ↔ Album ↔ Track ↔ Playlist
- Migration support via versioned schemas

## Testing Approach [Verified-Apple]

**Audio Engine Testing:**
```swift
func testEngineSwitch() async {
    let facade = AudioEngineFacade(...)
    try await facade.load(flacFile)
    XCTAssertTrue(facade.currentEngine is SFBAudioEngineAdapter)
}
```

**State Management Testing:**
```swift
func testStateSync() async {
    let manager = PlaybackStateManager()
    await manager.updateState { $0.isPlaying = true }
    XCTAssertTrue(manager.currentState.isPlaying)
}
```

**Async Testing with Confirmations:**
```swift
func testAudioInterruption() async {
    await confirmation(expectedCount: 2) { interruption in
        audioEngine.onInterruption = { _ in
            interruption()
        }
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil)
    }
}
```

**Mock Patterns for Audio Engines:**
```swift
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

    }
}
```

**UI Testing for Audio Playback:**
```bash
# Run all UI tests
make test-ui

# For specific test targeting, use xcodebuild directly:
xcodebuild test -scheme "Fonic HiFi" -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
    -only-testing:"Fonic HiFiUITests/AudioControlsUITests/testPlayPauseButton"
```

## Makefile Automation Features

### File Watching & Auto-Tasks
```bash
# Auto-lint on file changes
make watch-lint

# Auto-build on changes
make watch-build

# Auto-test on changes
make watch-test
```

### Advanced Workflows
```bash
# Full build and test cycle
make all  # Runs: clean → lint → build → test

# Parse last build for errors
make parse-errors

# Extract test results as JSON
make test-json
```

### Project Navigation Tips
- Use `make find-interactive` for exploring the codebase with live preview
- Use `make search-interactive` for real-time search as you type
- Use `make tree` to understand project structure
- Use `make stats-features` to see code distribution across modules

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

### Git Operations
- **ALWAYS** ask after file edits: "Would you like me to commit these changes?"
- Use `gh pr create` for pull requests, not web interface
- Include Co-Authored-By in commits: `Co-Authored-By: Claude <noreply@anthropic.com>`
- Never push unless explicitly requested

### Feature Development Flow
1. Use TodoWrite for tasks with 3+ steps
2. Run `make check-deps` to ensure tools are installed
3. Create feature branch from main
4. Implement with @MainActor boundaries (iOS 26 concurrency)
5. Run `make lint` to check code quality
6. Run `make format` to ensure consistent style
7. Add unit tests for business logic
8. Run `make test-unit` for fast test validation
9. Run `make build` to verify compilation
10. Run `make run` to test in iPhone 16 Pro simulator (iOS 26.0)
11. Run `make coverage` if code coverage needed
12. Profile with `make benchmark-build` if performance-critical
13. Update this CLAUDE.md if architecture changes
14. Ask to commit changes after edits
15. **NEVER** add backwards compatibility code
16. **ALWAYS** use modern iOS 26 APIs directly

### Debugging Audio Issues

**Quick Debug Commands (via Makefile):**
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

**Enhanced Debugging Commands:**

1. **Enable Verbose Logging:**
   ```swift
   // AudioEngineLogger does not exist - use os_log instead
   os_log(.debug, "Audio state: %{public}@", playbackState.description)
   ```

2. **Console.app Filtering:**
   ```bash
   log show --predicate 'subsystem == "com.fonichifi.audio"' --last 1h
   log stream --predicate 'subsystem == "com.fonichifi.audio"' --level debug
   log collect --device "iPhone 16 Pro" --start '2025-08-12 00:00:00'
   ```

3. **Symbolication for Crash Logs:**
   ```bash
   atos -arch arm64 -o "Fonic HiFi.app.dSYM/Contents/Resources/DWARF/Fonic HiFi" -l 0x100000000 0x1001234567
   symbolicatecrash crash_log.crash "Fonic HiFi.app.dSYM" > symbolicated.crash
   ```

4. **Audio Route Debugging:** [Verified-Apple]
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

## iOS 26 Liquid Glass Implementation [IMPORTANT]

**CLARIFICATION**: This project uses BOTH native iOS 26 APIs and custom implementations:

### Native iOS 26 APIs (from Apple) [Verified-Apple]:
- `.glassEffect(_:in:)` - Official SwiftUI modifier for Liquid Glass (USE DIRECTLY)
- `GlassEffectContainer` - Official Apple container for morphing glass effects (NO FALLBACKS)
- `Glass.regular`, `Glass.interactive()` - Official glass variants (ALWAYS AVAILABLE)
- `GlassEffectTransition` - Official transition support (NO COMPATIBILITY CHECKS)

**IMPORTANT**: These APIs are ALWAYS available in iOS 26. Never wrap them in availability checks.

### Custom Implementations (Project-Specific):
- `PerformanceOptimizedContainer` - Custom performance wrapper (uses iOS 26 APIs directly)
- `.liquidGlass()` modifier - Custom convenience wrapper (NO fallback logic)
- `LiquidGlassStyle` enum - Custom styling presets (iOS 26 only)
- Various performance optimization modifiers (assume iOS 26 features)

**NOTE**: The custom `PerformanceOptimizedContainer` was renamed from `GlassEffectContainer` to avoid confusion with Apple's official API of the same name.

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
- Modern Swift-first API (iOS 26 enhanced)
- Better SwiftUI integration (iOS 26 features)
- Automatic iCloud sync (iOS 26 implementation)
- Simpler relationship management

## Code Cleanup Requirements

**Remove These Patterns When Found:**
```swift
// REMOVE THIS:
if #available(iOS 26, *) {
    // iOS 26 code
} else {
    // fallback code
}

// REPLACE WITH:
// iOS 26 code directly

// REMOVE THIS:
@available(iOS 26, *)
struct MyView: View { ... }

// REPLACE WITH:
struct MyView: View { ... }
```

**iOS 26 is the ONLY target - write code as if iOS 26 is guaranteed (because it is).**