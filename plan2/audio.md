AudioKit Integration Fix Plan (Revised)

  Prerequisites:

  1. Verify AudioKit Package in Xcode
    - Check that AudioKit SwiftPM dependency (https://github.com/AudioKit/AudioKit.git) is listed in
  Target → Fonic HiFi
    - Confirm AudioKit product is added under Frameworks/Libraries
    - Package.resolved shows version 5.6.5

  Implementation Steps:

  1. Replace Mock Implementation in AudioKitEngineAdapter.swift

  Lines to modify: 8-29, throughout the file
  // Add import at top
  import AudioKit  // AudioPlayer ships in the AudioKit product already linked in Xcode
  // If additional nodes from AudioKitEX are needed later, add that product to the project file before importing.

  // Replace mock components (lines 18-26) with:
  private let engine = AudioEngine()
  private let player = AudioPlayer()
  private let mixer = Mixer()

  // In init, wire them up:
  mixer.addInput(player)
  engine.output = mixer
  do {
    try engine.start()
  } catch {
    throw AudioError.engineInitializationFailed(
      reason: "AudioKit failed to start: \(error.localizedDescription)"
    )
  }
  // Update the adapter initializer to `init() throws` so this failure bubbles up to the factory.

  2. Update All Service Methods

  - load(url:):
  let file = try AudioFile(url: url)
  try player.load(file: file)
  - play(): player.play()
  - pause(): player.pause()
  - stop(): player.stop() and reset _currentTime = 0
  - seek(to:): player.play(from: time), then player.pause() if !_isPlaying
  - setVolume(_:): player.volume = AUValue(clampedVolume)
  - Update getters: Read from player.currentTime, player.duration, player.isPlaying

  3. Clean Up Mock Code

  - Delete lines 311-358 (MockAudioKitEngine and MockAudioKitPlayer classes)
  - Decide whether to keep the progress timer; if retained, read from `player.currentTime`, otherwise rely on
    AudioKit callbacks

  4. Enable AudioKit in AudioEngineFactory.swift

  - Line 26: Change `.audioKitEngine` availability to `true`.
  - Introduce a `preferredEngine` input (for example via `AudioEngineConfiguration` or a lightweight preference service) so `selectEngineType` honors an explicit AudioKit choice before applying the existing heuristics, and make sure `PlaybackCoordinator` forwards the user's picker selection when requesting an engine.
  - When the adapter initializer throws, catch it in `createEngine` and immediately `registerEngine(.audioKitEngine, isAvailable: false)` so callers fall back to AVAudioEngine without leaving AudioKit flagged as usable.
  - Remove the stale "AudioKit is mock" comments while updating the selection logic.

  5. Update Documentation

  - CLAUDE.md line 65: Update the entry to describe the basic AudioKit playback path (avoid promising advanced
    DSP work that is still pending)
  - Tasks/ARCHITECTURE_IMPROVEMENTS_COMPLETED.md lines 32-34: Note that mocks were replaced and call out any
    remaining AudioKit follow-ups
  - Remove or reword lingering references to mock implementations

  6. Build and Test

  xcodebuild -scheme "Fonic HiFi" \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
    build
  - Launch app and select AudioKit in Settings
  - Test playback functionality

  Files to Modify:

  1. Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift - Replace mocks with real AudioKit
  2. Fonic HiFi/Core/Audio/Factory/AudioEngineFactory.swift - Enable AudioKit (line 26)
  3. CLAUDE.md - Update documentation
  4. Tasks/ARCHITECTURE_IMPROVEMENTS_COMPLETED.md - Update status

  Follow-up Tasks:

  1. Add test coverage in Fonic HiFiTests for AudioKit path
  2. Update build instructions with dependency setup
  3. Capture screenshots of AudioKit working for documentation

  This implementation will provide real AudioKit functionality with proper audio playback, replacing all
   mock implementations.

> create a plan in the plan2 folder.

⏺ code-index - find_files (MCP)(pattern: "Plan2/*")
                                                                                                       

⏺ I'll create a comprehensive plan document for the AudioKit integration in the Plan2 folder. Let me
  check if the folder exists first.

⏺ Bash(ls -la | grep -i plan)
  ⎿  No matches found

⏺ Bash(find . -type d -name "Plan*" 2>/dev/null | head -10)
  ⎿  (No content)

⏺ Let me create a comprehensive plan document that will be saved to the Plan2 folder. Since I'm in plan
  mode, I'll outline what the document will contain:

  Plan Document to Create: Plan2/AudioKit_Integration_Plan.md

  Here's the complete plan document that will be created:

  # AudioKit Integration Implementation Plan

  ## Executive Summary
  Replace the mock AudioKit implementation in Fonic HiFi with real AudioKit components to enable proper
  audio playback functionality. AudioKit package is already linked in the project (v5.6.5) but currently
   uses mock implementations.

  ## Current State Analysis

  ### Issues Identified
  1. **Mock Implementation**: `AudioKitEngineAdapter.swift` contains MockAudioKitEngine and
  MockAudioKitPlayer instead of real AudioKit components
  2. **Disabled in Factory**: AudioEngineFactory has AudioKit marked as unavailable (`audioKitEngine:
  false`)
  3. **Documentation Mismatch**: Documentation refers to AudioKit as "STUB ONLY" despite package being
  linked
  4. **No Real Functionality**: Current implementation cannot actually play audio through AudioKit

  ### Files Affected
  - `Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift` (393 lines)
  - `Fonic HiFi/Core/Audio/Factory/AudioEngineFactory.swift` (242 lines)
  - `CLAUDE.md` (documentation)
  - `Tasks/ARCHITECTURE_IMPROVEMENTS_COMPLETED.md` (documentation)

  ## Implementation Steps

  ### Step 1: Verify AudioKit Package Configuration
  **Objective**: Confirm AudioKit dependency is properly linked
  **Actions**:
  1. Open project in Xcode
  2. Navigate to Target → Fonic HiFi → Package Dependencies
  3. Verify https://github.com/AudioKit/AudioKit.git is listed
  4. Confirm version 5.6.5 in Package.resolved
  5. Ensure AudioKit product is in Frameworks/Libraries

  ### Step 2: Replace Mock Components with Real AudioKit
  **File**: `Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift`

  #### 2.1 Update Imports (Lines 8-10)
  ```swift
  import Foundation
  import AVFoundation
  import Combine
  import AudioKit       // AudioPlayer lives in the main AudioKit product in v5.6.5
  // If additional nodes are needed later, add the AudioKitEX product to the project before importing it.

  2.2 Replace Mock Components (Lines 18-26)

  Remove:
  // Note: AudioKit imports will be added when dependency is available
  // private let engine = AudioEngine()
  // private let player = AudioPlayer()

  private let mockEngine = MockAudioKitEngine()
  private let mockPlayer = MockAudioKitPlayer()

  Replace With:
  private let engine = AudioEngine()
  private let player = AudioPlayer()
  private let mixer = Mixer()

  2.3 Update Initialization (Lines 80-84)

  private func setupAudioKitEngine() throws {
      mixer.addInput(player)
      engine.output = mixer

      do {
          try engine.start()
      } catch {
          throw AudioError.engineInitializationFailed(
              reason: "AudioKit failed to start: \(error.localizedDescription)"
          )
      }
  }

  Update the adapter initializer to `init() throws` and let callers surface failures so the factory can
  disable AudioKit and fall back to AVAudioEngine when start-up fails.

  Step 3: Update Service Methods

  3.1 Load Method (Lines 94-109)

  public func load(url: URL) async throws {
      do {
          let file = try AudioFile(url: url)
          try player.load(file: file)

          // Keep existing duration calculation
          let avFile = try AVAudioFile(forReading: url)
          currentFile = avFile
          _duration = Double(avFile.length) / avFile.fileFormat.sampleRate
          _currentTime = 0
      } catch {
          throw AudioError.decodingFailed(reason: "Failed to load file: \(error.localizedDescription)")
      }
  }

  Note: Keep the `AVAudioFile` around only if you need Core Audio metadata/metrics. Otherwise reuse the
  `AudioFile` instance to avoid redundant disk reads for large assets.

  3.2 Play Method (Lines 111-126)

  public func play() async throws {
      guard currentFile != nil else {
          throw AudioError.playbackFailed(reason: "No file loaded")
      }

      player.play()
      _isPlaying = true
      startProgressPolling()
  }

  3.3 Pause Method (Lines 128-133)

  public func pause() async {
      player.pause()
      _isPlaying = false
      stopProgressPolling()
  }

  3.4 Stop Method (Lines 135-141)

  public func stop() async {
      player.stop()
      _isPlaying = false
      _currentTime = 0
      stopProgressPolling()
  }

  3.5 Seek Method (Lines 143-172)

  public func seek(to time: TimeInterval) async throws {
      player.play(from: time)
      _currentTime = time

      // If we were paused, pause again after seeking
      if !_isPlaying {
          player.pause()
      }
  }

  3.6 SetVolume Method (Lines 174-179)

  public func setVolume(_ volume: Float) async {
      let clampedVolume = max(0.0, min(1.0, volume))
      player.volume = AUValue(clampedVolume)
      _volume = clampedVolume
  }

  3.7 Update Progress Handling (Lines 288-302)

  If you keep the timer-based polling, update the body to:

  private func updateProgress() async {
      guard _isPlaying else { return }

      _currentTime = player.currentTime

      // Check if we've reached the end
      if _currentTime >= _duration {
          _isPlaying = false
          stopProgressPolling()
          completionHandler?()
      }
  }

  Alternatively, remove the timer and rely on `player.completionHandler`/Combine publishers to push time
  updates when AudioKit fires callbacks.

  Step 4: Remove Mock Classes

  Lines to Delete: 311-358
  - Remove entire MockAudioKitEngine class
  - Remove entire MockAudioKitPlayer class

  Step 5: Enable AudioKit in Factory

  File: Fonic HiFi/Core/Audio/Factory/AudioEngineFactory.swift

  5.1 Enable AudioKit (Line 26)

  private var availableEngines: [AudioEngineType: Bool] = [
      .avAudioEngine: true,
      .audioKitEngine: true,  // CHANGE from false to true
      .sfbAudioEngine: false,
      .ffmpegEngine: false
  ]

  5.2 Honor user-selected engines

  - Pull the `preferredAudioEngine` choice from `AudioSettingsView` (e.g., via `AudioEngineConfiguration` or a dedicated preference provider) and hand it to `selectEngineType` before running the legacy heuristics.
  - Update `PlaybackCoordinator.ensureEngineForFormat` to recreate or swap engines when the preference changes so AudioKit can actually be instantiated.

  5.3 Handle Startup Failures

  - Make `createEngine` catch the throwing `AudioKitEngineAdapter` initializer.
  - When a failure occurs, call `registerEngine(.audioKitEngine, isAvailable: false)` and fall back to AVAudioEngine so the UI stops advertising an unusable path.
  - Log the failure for diagnostics so we can revisit configuration issues.

  5.4 Remove Mock Comments (Lines 96-99, 106-109, 113-116)

  Remove lingering "AudioKit is mock" references while updating the selection logic.

  Step 6: Update Documentation

  6.1 CLAUDE.md (Line 65)

  ├── AudioKitEngineAdapter - Implemented basic playback via AudioKit

  6.2 Tasks/ARCHITECTURE_IMPROVEMENTS_COMPLETED.md (Lines 32-34)

  **Actions Taken**:
  - Replaced mock AudioKit types with AudioEngine, AudioPlayer, and Mixer wiring
  - Enabled AudioKit in AudioEngineFactory for user selection when initialization succeeds
  - Document outstanding DSP/metrics work as future improvements

  Testing Plan

  Build Verification

  xcodebuild -scheme "Fonic HiFi" \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
    build

  Functional Testing

  1. Launch app in simulator
  2. Navigate to Settings → Audio Settings
  3. Select "AudioKit" from Audio Engine picker
  4. Load an audio file
  5. Test play/pause/stop/seek functionality
  6. Verify volume control works
  7. Check that audio actually plays through speakers

  Integration Testing

  1. Test switching between AVAudioEngine and AudioKit
  2. Verify state persistence when changing engines
  3. Test various audio formats (MP3, AAC, WAV, FLAC)
  4. Monitor for memory leaks during playback

  Risk Mitigation

  Potential Issues

  1. AudioKit API Changes: Version 5.6.5 may have different APIs than documented
    - Mitigation: Consult AudioKit documentation and adapt as needed
  2. Performance Impact: AudioKit may use more CPU/memory
    - Mitigation: Profile with Instruments, optimize buffer sizes
  3. Format Compatibility: Some formats may not work with AudioKit
    - Mitigation: Fall back to AVAudioEngine for unsupported formats

  Success Criteria

  - AudioKit components compile without errors
  - Audio plays through AudioKit when selected
  - All playback controls function correctly
  - No crashes or memory leaks
  - Documentation accurately reflects implementation

  Timeline

  - Step 1-2: 30 minutes (Replace mock components)
  - Step 3: 45 minutes (Update service methods)
  - Step 4-5: 15 minutes (Cleanup and enable)
  - Step 6: 15 minutes (Documentation)
  - Testing: 30 minutes
  - Total: ~2.5 hours

  Follow-up Tasks

  1. Add unit tests for AudioKit adapter
  2. Create integration tests for engine switching
  3. Performance profiling and optimization
  4. Add support for AudioKit effects (reverb, EQ)
  5. Implement AudioKit-specific features (time stretching, pitch shifting)

  This comprehensive plan document will guide the AudioKit integration implementation with clear steps,
  code examples, and testing procedures. Would you like me to save this plan to the Plan2 folder?

  Todos
  ☐ Replace mock AudioKit implementation with real AudioKit components
  ☐ Import AudioKit (and add AudioKitEX only if the product is linked)
  ☐ Wire up real AudioKit engine, player, and mixer
  ☐ Update service methods to use real AudioKit APIs
  ☐ Remove mock AudioKit classes
  ☐ Honor user-selected engine in AudioEngineFactory and PlaybackCoordinator
  ☐ Downgrade AudioKit availability when initialization fails
  ☐ Update documentation to reflect real implementation
  ☐ Build and test AudioKit integration

