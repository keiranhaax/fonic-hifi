# Fonic HiFi - Complete Implementation Plan
# "Think Different" - Execution Roadmap

**Version:** 1.1
**Created:** 2025-09-30
**Updated:** 2025-09-30 (AI-assisted time estimates)
**Author:** Claude Code (Sonnet 4.5)
**Status:** Ready for Execution

> **💡 AI-Assisted Development Note**
>
> Time estimates reflect AI coding agent capabilities (~2.5-3x faster than human development). AI excels at boilerplate generation, pattern implementation, and test scaffolding, but still requires iteration for complex algorithms (DSP, synchronization) and manual validation for audio quality and device testing.

---

## Document Purpose

This comprehensive plan transforms Fonic HiFi's strategic vision (PRD, roadmap, features, AI integration) into an executable implementation guide. It provides step-by-step instructions for building a privacy-first, audiophile-grade iOS music player that challenges the status quo.

**Source Documents:**
- `plan2/prd.md` - Product requirements & vision (192 lines)
- `plan2/roadmap.md` - Phase planning & milestones (105 lines)
- `plan2/features.md` - Market analysis & competitive landscape (554 lines)
- `plan2/ai.md` - Apple Intelligence integration strategy (818 lines)
- `plan2/tab.md` - Tab bar redesign implementation (511 lines)

---

## Executive Summary

### Vision

**"Here's to the crazy ones. The misfits. The rebels. The troublemakers."**

Fonic HiFi challenges the music player status quo by proving privacy and quality don't require compromise. While competitors force cloud sync, subscriptions, and telemetry, we deliver:

- **Bit-perfect playback** with transparent signal-path verification
- **Complete privacy** - zero network dependencies, all processing on-device
- **Modern craft** - iOS 26 Liquid Glass design with accessibility built-in
- **Professional tools** - Studio Mode for audiophiles, approachable for all users

### Current State (2025-09-30)

**Build Status:** ✅ PASSING (commit ddc088e)
**Completed Milestones:**
- ✅ Swift 6 concurrency compliance
- ✅ AVAudioEngine + AudioKit dual-engine architecture
- ✅ SwiftData persistence with TrackDataActor
- ✅ Settings UI with File Manager
- ✅ Audio format detection system
- ✅ P0 critical fixes complete (threading, MPNowPlayingInfo)
- ✅ Liquid Glass migration to iOS 26 native APIs

**Outstanding Work:** 4 implementation phases (Phase 0-3) covering 18 months

**Development Estimates:**
- **Total implementation time:** 118-164 hours (AI-assisted, ~3-4 weeks full-time equivalent)
- **Original human estimate:** 318-406 hours (~8-10 weeks full-time)
- **AI speedup factor:** ~2.5-3x overall

### Success Metrics

| Metric | Target | Timeline |
|--------|--------|----------|
| Crash-free sessions | ≥ 99.8% | Phase 0 exit |
| Bit-perfect accuracy | ≥ 95% vs hardware probes | Phase 1 exit |
| 30-day retention | ≥ 60% early adopters | Phase 2 exit |
| App Store rating | ≥ 4.6 (1k+ reviews) | Phase 4 exit |

---

## Table of Contents

1. [Phase 0: Core Stability & Instrumentation](#phase-0-core-stability--instrumentation) (Now → July 2025)
2. [Phase 1: Format & Playback Parity](#phase-1-format--playback-parity) (Aug → Oct 2025)
3. [Phase 2: Differentiators & Pro Tooling](#phase-2-differentiators--pro-tooling) (Nov 2025 → Jan 2026)
4. [Phase 3: Ecosystem & Connectivity](#phase-3-ecosystem--connectivity) (Feb → Apr 2026)
5. [Parallel Workstreams](#parallel-workstreams)
6. [Technical Architecture](#technical-architecture)
7. [Testing Strategy](#testing-strategy)
8. [Risk Management](#risk-management)
9. [Appendix: Market Context](#appendix-market-context)

---

## Phase 0: Core Stability & Instrumentation
**Timeline:** Now → July 2025 (3 months)
**Theme:** Stabilize existing PCM playback
**Priority:** P0 (Blocking production release)

### Goals

Ship a reliable local player that proves the bit-perfect path and removes show-stopper gaps. No new features—focus on making existing functionality production-ready.

### Features to Implement

#### 0.1 Gapless Playback (P0)
**Current State:** Hooks exist but not implemented
**File:** `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift`

**Implementation Steps:**
1. Complete `prepareNext()` method (line ~400)
   - Pre-load next track's AVAudioFile
   - Calculate exact buffer handoff point
   - Schedule buffer overlap during final 500ms
2. Implement buffer pre-roll (200-500ms lookahead)
3. Add regression tests with sine sweep comparison
4. Manual testing: 50-track playlist, verify zero gaps

**Success Criteria:**
- [ ] Zero audible gaps between tracks (measured <10ms silence)
- [ ] No clicks/pops at transitions
- [ ] Works across all supported formats (MP3, AAC, ALAC, WAV, AIFF)
- [ ] Regression tests pass

**Time Estimate (AI-assisted):** 4-6 hours (was 12-16h human)
- Implementation: 2-3h (AI scaffolds algorithm, requires iteration for buffer timing)
- Testing: 2-3h (manual listening tests, sine sweep validation)

**Risk:** HIGH - Complex buffer timing, engine-dependent behavior

---

#### 0.2 Bit-Perfect Validator UI Integration (P0)
**Current State:** `BitPerfectValidator` exists but results hidden
**File:** `Fonic HiFi/Core/Audio/Diagnostics/BitPerfectValidator.swift`

**Implementation Steps:**
1. Add validator status badge to Now Playing view
   - "Bit-Perfect" (green) vs "Processing Active" (yellow)
   - Tap for detailed signal-path breakdown
2. Create `SignalPathView.swift` showing:
   - Sample rate changes (if any)
   - Active DSP processing (EQ, crossfade, etc.)
   - Buffer size and latency
   - DAC compatibility status
3. Wire validator results to UI via `@Published` property
4. Add user-facing explanations for non-bit-perfect states

**Success Criteria:**
- [ ] Badge visible in Now Playing view
- [ ] Tap opens detailed signal-path breakdown
- [ ] Explanations clear to non-technical users
- [ ] Updates in real-time when toggling DSP

**Time Estimate (AI-assisted):** 2-3 hours (was 8-10h human)
- UI generation: 1-2h (AI excels at SwiftUI view scaffolding)
- Integration: 1h (wire validator to UI)

**Risk:** MEDIUM - Requires clear UX for technical concepts

---

#### 0.3 Progress Timer Reliability (P0)
**Current State:** Timer exists, occasional desync reported
**File:** `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:930-949`

**Implementation Steps:**
1. Audit timer accuracy against AVAudioEngine's `playerTime`
2. Fix drift issues (currently updates every 200ms)
3. Add test harness: 10-minute playback, verify <100ms drift
4. Ensure MPNowPlayingInfo stays in sync (P0-2 already fixed)

**Success Criteria:**
- [ ] Progress bar matches actual playback position (<100ms error)
- [ ] No drift over 10-minute playback
- [ ] Lock screen scrubber accurate
- [ ] Tests pass

**Time Estimate (AI-assisted):** 1-2 hours (was 4-6h human)
- Implementation: 30min-1h (isolated fix)
- Testing: 30min-1h (10-minute playback validation)

**Risk:** LOW - Isolated fix, existing infrastructure

---

#### 0.4 Resume Playback (Quick Win)
**Current State:** App restarts from track 1 every launch
**File:** `Fonic HiFi/Data/Services/PlaybackStateStore.swift` (NEW)

**Implementation Steps:**
1. Create `PlaybackStateStore` actor for persistence
   - Store last track ID, position, queue state
   - Use UserDefaults for quick access
2. Load state on app launch in `FonicHiFiApp.swift`
3. Restore playback position without auto-playing
4. Add Settings toggle: "Resume playback on launch" (default: off)

**Success Criteria:**
- [ ] Playback resumes from last position
- [ ] Queue state preserved
- [ ] Settings toggle works
- [ ] Doesn't auto-play (user must tap play)

**Time Estimate (AI-assisted):** 2-3 hours (was 6-8h human)
- PlaybackStateStore actor: 1-2h (AI generates from pattern)
- Integration + testing: 1h

**Risk:** LOW - Straightforward persistence

---

#### 0.5 Shake to Shuffle (Quick Win)
**Current State:** No gesture-based controls
**File:** `Fonic HiFi/Presentation/Views/Player/NowPlayingView.swift`

**Implementation Steps:**
1. Add `ShakeDetector` utility class
   - Listen for `UIEvent.EventSubtype.motionShake`
   - Debounce to prevent accidental triggers
2. Wire to shuffle command via AudioEngineFacade
3. Add haptic feedback on shuffle
4. Settings toggle: "Shake to shuffle" (default: on)

**Success Criteria:**
- [ ] Shake gesture shuffles queue
- [ ] Haptic feedback confirms action
- [ ] Settings toggle works
- [ ] Debouncing prevents double-shuffles

**Time Estimate (AI-assisted):** 1-2 hours (was 4-6h human)
- ShakeDetector utility: 30min-1h
- Integration + settings: 30min-1h

**Risk:** LOW - Simple gesture handling

---

### Phase 0 Exit Criteria

- [ ] Gapless playback works across 50-track test suite
- [ ] Bit-perfect badge visible with signal-path detail view
- [ ] Progress timer accurate over 10-minute playback
- [ ] Resume playback restores state correctly
- [ ] Shake to shuffle works reliably
- [ ] Crash-free sessions ≥ 99.8% (soak test)
- [ ] Build passing with 0 critical warnings
- [ ] Thread Performance Checker shows 0 warnings

**Phase 0 Time Summary:**
- **AI-assisted:** 10-16 hours (~3-4 days)
- **Human baseline:** 34-46 hours (~1-2 weeks)
- **Speedup:** ~2.8-3.4x

**Breakdown:**
- Gapless playback: 4-6h (complex algorithm)
- Bit-perfect UI: 2-3h (UI generation fast)
- Progress timer: 1-2h (isolated fix)
- Resume playback: 2-3h (persistence pattern)
- Shake to shuffle: 1-2h (simple gesture)

---

## Phase 1: Format & Playback Parity
**Timeline:** August → October 2025 (3 months)
**Theme:** Meet baseline audiophile expectations
**Priority:** P1 (Competitive necessity)

### Goals

Deliver format support breadth, essential DSP tools (EQ, crossfade, replay gain), and lyrics display to match competitors like VOX, Neutron, and Onkyo HF Player.

### Features to Implement

#### 1.1 FLAC Decoder Integration (P1 - BLOCKING)
**Current State:** Architecture prepared, no live decoder
**Files:**
- `Fonic HiFi/Core/Audio/Decoders/` (NEW)
- `Fonic HiFi/Core/Audio/Factory/AudioEngineFactory.swift`

**Implementation Steps:**
1. **Evaluate decoder options:**
   - **AudioKit:** Already integrated, supports FLAC via `AVAudioFile` wrapper
   - **SFBAudioEngine:** Open-source, professional-grade, supports FLAC/APE/DSD
   - **FFmpegKit:** Most comprehensive, large binary size (~8MB)
   - **Recommendation:** Start with AudioKit (zero binary impact), add SFBAudioEngine if needed

2. **AudioKit FLAC integration:**
   ```swift
   // File: Core/Audio/Engines/AudioKitEngineAdapter.swift
   func loadFLACFile(_ url: URL) async throws {
       // AudioKit's AVAudioFile wrapper handles FLAC natively
       let audioFile = try AVAudioFile(forReading: url)
       let format = audioFile.processingFormat

       // Verify bit-perfect path
       guard format.sampleRate <= 192000 else {
           throw AudioError.unsupportedSampleRate
       }

       await load(file: audioFile)
   }
   ```

3. **Update format detection:**
   ```swift
   // File: Core/Audio/Services/AudioFormatDetectionManager.swift
   func detectFormat(from url: URL) -> AudioFormat {
       let ext = url.pathExtension.lowercased()
       switch ext {
       case "flac":
           return .flac(bitDepth: detectBitDepth(url))
       // ... existing cases
       }
   }
   ```

4. **Test suite:**
   - FLAC 16/44.1 (CD quality)
   - FLAC 24/96 (hi-res)
   - FLAC 24/192 (ultra hi-res)
   - Verify bit-perfect playback with hardware probe

**Success Criteria:**
- [ ] FLAC files play without conversion
- [ ] Bit-perfect validator shows green for FLAC
- [ ] Metadata extraction works (tags, artwork)
- [ ] Gapless playback between FLAC tracks
- [ ] Tests pass for all bit depths

**Time Estimate (AI-assisted):** 6-8 hours (was 16-20h human)
- AudioKit integration: 2-3h (AI scaffolds wrapper code)
- Format detection: 1-2h (pattern-based update)
- Testing: 3h (hardware probe validation required)

**Risk:** MEDIUM - Depends on AudioKit's FLAC implementation quality

**Dependencies:** None (can start immediately)

---

#### 1.2 10-Band Parametric EQ (P1)
**Current State:** No DSP processing
**File:** `Fonic HiFi/Core/Audio/DSP/EqualizerEngine.swift` (NEW)

**Implementation Steps:**
1. **Choose EQ implementation:**
   - **AVAudioUnitEQ:** Native, lightweight, limited control
   - **AudioKit Equalizer:** More precise, parametric control
   - **Recommendation:** AudioKit for professional control

2. **Create EqualizerEngine:**
   ```swift
   // File: Core/Audio/DSP/EqualizerEngine.swift
   @MainActor
   final class EqualizerEngine {
       private var equalizer: AKEqualizerFilter?

       struct Band {
           let frequency: Double  // 20Hz - 20kHz
           let gain: Double       // -12dB to +12dB
           let q: Double          // 0.5 - 4.0
       }

       func apply(bands: [Band], to node: AVAudioNode) {
           // Configure 10-band parametric EQ
       }
   }
   ```

3. **Preset system:**
   - "Flat" (no EQ)
   - "Bass Boost"
   - "Treble Boost"
   - "Classical"
   - "Jazz"
   - "Rock"
   - "Vocal"
   - Custom presets (user-defined)

4. **UI implementation:**
   - Settings → Audio → Equalizer
   - 10 sliders with frequency labels
   - Preset picker
   - Save custom preset
   - Real-time preview (no playback restart)

**Success Criteria:**
- [ ] 10 bands controllable (32Hz, 64Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz)
- [ ] Presets work correctly
- [ ] Custom presets save/load
- [ ] No audible artifacts during adjustment
- [ ] Bit-perfect badge shows yellow when EQ active

**Time Estimate (AI-assisted):** 8-10 hours (was 20-24h human)
- EqualizerEngine: 3-4h (AI scaffolds DSP logic, requires iteration)
- Preset system: 2h (AI generates from structure)
- UI implementation: 2-3h (SwiftUI generation fast)
- Testing: 1-2h (frequency response verification)

**Risk:** MEDIUM - Real-time DSP requires careful buffer management

---

#### 1.3 Crossfade Engine (P1)
**Current State:** Hooks exist, not implemented
**File:** `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift`

**Implementation Steps:**
1. **Crossfade algorithm:**
   ```swift
   // File: Core/Audio/DSP/CrossfadeEngine.swift
   func crossfade(
       from currentTrack: AVAudioFile,
       to nextTrack: AVAudioFile,
       duration: TimeInterval  // 0-12 seconds
   ) {
       let fadeOutStart = currentTrack.duration - duration
       let fadeInEnd = duration

       // Apply logarithmic fade curves (sounds more natural)
       applyFadeOut(to: currentTrack, start: fadeOutStart, curve: .logarithmic)
       applyFadeIn(to: nextTrack, end: fadeInEnd, curve: .logarithmic)
   }
   ```

2. **Integration with gapless:**
   - Crossfade and gapless are mutually exclusive
   - Settings toggle: "Crossfade" (0s = gapless, 1-12s = crossfade)

3. **UI:**
   - Settings → Playback → Crossfade Duration
   - Slider: 0s (off) to 12s
   - Preview button to hear effect

**Success Criteria:**
- [ ] Crossfade works for 1s, 3s, 6s, 12s durations
- [ ] No clicks/pops during transition
- [ ] Logarithmic curve sounds natural
- [ ] Gapless disabled when crossfade > 0s
- [ ] Settings persist

**Time Estimate (AI-assisted):** 4-6 hours (was 12-16h human)
- CrossfadeEngine algorithm: 2-3h (AI scaffolds, requires buffer timing iteration)
- Integration: 1h
- Testing: 1-2h (manual listening for smooth transitions)

**Risk:** MEDIUM - Requires precise buffer timing

---

#### 1.4 Replay Gain (P1)
**Current State:** Metadata stored, not applied
**File:** `Fonic HiFi/Core/Audio/DSP/ReplayGainProcessor.swift` (NEW)

**Implementation Steps:**
1. **Read replay gain tags:**
   - `REPLAYGAIN_TRACK_GAIN` (dB adjustment)
   - `REPLAYGAIN_ALBUM_GAIN` (dB adjustment)
   - `REPLAYGAIN_TRACK_PEAK` (normalization ceiling)

2. **Apply gain adjustment:**
   ```swift
   // File: Core/Audio/DSP/ReplayGainProcessor.swift
   func applyReplayGain(
       to playerNode: AVAudioPlayerNode,
       mode: ReplayGainMode  // .off, .track, .album
   ) {
       let gainDB = mode == .track ? trackGain : albumGain
       let linearGain = pow(10, gainDB / 20.0)

       // Apply via AVAudioUnitVarispeed (zero latency)
       let gainNode = AVAudioUnitVarispeed()
       gainNode.rate = Float(linearGain)
   }
   ```

3. **UI:**
   - Settings → Playback → Replay Gain
   - Modes: Off, Track, Album
   - Prevent clipping toggle (default: on)

**Success Criteria:**
- [ ] Track mode normalizes per-track
- [ ] Album mode normalizes per-album
- [ ] No clipping when prevent clipping enabled
- [ ] Bit-perfect badge shows yellow when active
- [ ] Settings persist

**Time Estimate (AI-assisted):** 3-4 hours (was 8-12h human)
- ReplayGainProcessor: 1-2h (straightforward calculation)
- UI implementation: 1h
- Testing: 1h (verify no clipping)

**Risk:** LOW - Straightforward gain multiplication

---

#### 1.5 Sleep Timer (P1)
**Current State:** Not implemented
**File:** `Fonic HiFi/Presentation/ViewModels/SleepTimerViewModel.swift` (NEW)

**Implementation Steps:**
1. **Timer presets:**
   - 5 min, 10 min, 15 min, 30 min, 1 hour
   - End of current track
   - End of current album
   - Custom duration

2. **Fade-out implementation:**
   - Last 10 seconds: logarithmic fade to silence
   - Pause playback
   - Show notification: "Sleep timer ended"

3. **UI:**
   - Now Playing → Sleep Timer button
   - Picker with presets
   - Countdown display when active
   - Cancel button

**Success Criteria:**
- [ ] Timer stops playback accurately
- [ ] Fade-out smooth and natural
- [ ] Notification appears
- [ ] Works in background mode
- [ ] Cancel works immediately

**Time Estimate (AI-assisted):** 2-3 hours (was 8-10h human)
- SleepTimerViewModel: 1-2h (AI generates timer logic)
- Fade-out implementation: 30min-1h
- UI + testing: 30min-1h

**Risk:** LOW - Simple timer logic

---

#### 1.6 Variable Playback Speed (P1)
**Current State:** Not implemented
**File:** `Fonic HiFi/Core/Audio/DSP/PlaybackSpeedController.swift` (NEW)

**Implementation Steps:**
1. **Speed range:** 0.5x to 2.0x (standard range)
2. **Pitch control toggle:**
   - Preserve pitch (time-stretch algorithm)
   - Change pitch (proportional to speed)

3. **Implementation:**
   ```swift
   // File: Core/Audio/DSP/PlaybackSpeedController.swift
   func setPlaybackSpeed(
       _ speed: Double,
       preservePitch: Bool
   ) {
       let timePitchNode = AVAudioUnitTimePitch()
       timePitchNode.rate = Float(speed)

       if preservePitch {
           timePitchNode.pitch = 0  // No pitch shift
       } else {
           timePitchNode.pitch = Float((speed - 1.0) * 1200)  // Cents
       }
   }
   ```

4. **UI:**
   - Now Playing → Speed button
   - Slider: 0.5x to 2.0x
   - Preserve pitch toggle
   - Reset to 1.0x button

**Success Criteria:**
- [ ] Speed adjusts smoothly
- [ ] Preserve pitch sounds natural
- [ ] No audio artifacts
- [ ] Works with all formats
- [ ] Settings persist

**Time Estimate (AI-assisted):** 3-4 hours (was 10-12h human)
- PlaybackSpeedController: 1-2h (AVAudioUnitTimePitch wrapper)
- UI implementation: 1h
- Testing: 1h (verify no artifacts)

**Risk:** MEDIUM - Time-stretch quality varies by implementation

---

#### 1.7 A-B Loop (P1)
**Current State:** Not implemented
**File:** `Fonic HiFi/Presentation/ViewModels/ABLoopViewModel.swift` (NEW)

**Implementation Steps:**
1. **Loop state machine:**
   - Idle → A set → B set → Looping → Idle

2. **Implementation:**
   ```swift
   // File: Presentation/ViewModels/ABLoopViewModel.swift
   @Observable
   final class ABLoopViewModel {
       var pointA: TimeInterval?
       var pointB: TimeInterval?
       var isLooping: Bool = false

       func setPointA(_ time: TimeInterval) {
           pointA = time
           pointB = nil
       }

       func setPointB(_ time: TimeInterval) {
           guard let a = pointA, time > a else { return }
           pointB = time
           isLooping = true
       }

       func checkLoop(currentTime: TimeInterval) {
           guard isLooping,
                 let a = pointA,
                 let b = pointB,
                 currentTime >= b else { return }

           // Jump back to point A
           seekTo(a)
       }
   }
   ```

3. **UI:**
   - Now Playing → A-B Loop buttons
   - Point A marker (blue)
   - Point B marker (red)
   - Loop indicator in progress bar
   - Clear loop button

**Success Criteria:**
- [ ] Set A, then B creates loop
- [ ] Playback jumps from B to A
- [ ] Clear loop works
- [ ] Markers visible in progress bar
- [ ] Works seamlessly

**Time Estimate (AI-assisted):** 3-5 hours (was 10-14h human)
- ABLoopViewModel state machine: 1-2h (AI generates from spec)
- UI markers: 1-2h
- Testing: 1h (seek accuracy validation)

**Risk:** MEDIUM - Requires precise seek timing

---

#### 1.8 Lyrics Display (P1)
**Current State:** Metadata stored, no viewer
**Files:**
- `Fonic HiFi/Presentation/Views/Lyrics/LyricsView.swift` (NEW)
- `Fonic HiFi/Core/Audio/Services/LRCParser.swift` (NEW)

**Implementation Steps:**
1. **Static lyrics display:**
   ```swift
   // File: Presentation/Views/Lyrics/LyricsView.swift
   struct LyricsView: View {
       let lyrics: String

       var body: some View {
           ScrollView {
               Text(lyrics)
                   .font(.body)
                   .padding()
           }
           .navigationTitle("Lyrics")
       }
   }
   ```

2. **LRC sync support:**
   ```swift
   // File: Core/Audio/Services/LRCParser.swift
   struct LRCLine {
       let timestamp: TimeInterval
       let text: String
   }

   func parseLRC(_ content: String) -> [LRCLine] {
       // Parse [mm:ss.xx]Lyrics line format
   }
   ```

3. **Auto-scroll during playback:**
   - Highlight current line
   - Scroll to keep current line centered
   - Tap line to seek to that timestamp (LRC only)

4. **Manual import:**
   - Now Playing → Lyrics → Import .lrc file
   - Associate with current track

**Success Criteria:**
- [ ] Static lyrics display
- [ ] LRC sync works
- [ ] Auto-scroll smooth
- [ ] Tap to seek works
- [ ] Manual import saves correctly

**Time Estimate (AI-assisted):** 6-8 hours (was 16-20h human)
- LRCParser: 2-3h (AI generates from format spec, requires edge case handling)
- LyricsView UI: 2-3h (SwiftUI generation)
- Auto-scroll + testing: 2h

**Risk:** MEDIUM - LRC parsing can be fragile

---

### Phase 1 Exit Criteria

- [ ] FLAC playback works (16/44.1, 24/96, 24/192)
- [ ] 10-band EQ with 7 presets + custom
- [ ] Crossfade works (1s, 3s, 6s, 12s)
- [ ] Replay gain modes (track, album)
- [ ] Sleep timer with fade-out
- [ ] Variable speed (0.5x - 2.0x) with pitch control
- [ ] A-B loop seamless
- [ ] Lyrics display (static + LRC sync)
- [ ] Public beta released to TestFlight
- [ ] User feedback collected (50+ testers)
- [ ] QA sign-off on all features

**Phase 1 Time Summary:**
- **AI-assisted:** 35-48 hours (~1-1.5 weeks)
- **Human baseline:** 100-128 hours (~3-4 weeks)
- **Speedup:** ~2.7-2.9x

**Breakdown:**
- FLAC decoder: 6-8h (integration + testing)
- 10-band EQ: 8-10h (DSP iteration required)
- Crossfade: 4-6h (buffer timing)
- Replay gain: 3-4h (simple calculation)
- Sleep timer: 2-3h (timer logic)
- Variable speed: 3-4h (AVAudioUnitTimePitch)
- A-B loop: 3-5h (state machine)
- Lyrics: 6-8h (LRC parsing + UI)

---

## Phase 2: Differentiators & Pro Tooling
**Timeline:** November 2025 → January 2026 (3 months)
**Theme:** Exceed competitors on transparency and professional tooling
**Priority:** P2 (Competitive advantage)

### Goals

Deliver Studio Mode with pro meters, signal-path visualization, smart playlists, and batch metadata editing to differentiate from competitors.

### Features to Implement

#### 2.1 Studio Mode Toggle (P2)
**Current State:** Not implemented
**File:** `Fonic HiFi/Presentation/Views/Settings/StudioModeSettings.swift` (NEW)

**Implementation Steps:**
1. **Settings toggle:** Settings → Advanced → Studio Mode
2. **UI changes when enabled:**
   - Show technical details in Now Playing
   - Enable pro meters (next section)
   - Show signal-path visualization
   - Add reference track management

3. **Default:** OFF (keep UI simple for non-audiophiles)

**Success Criteria:**
- [ ] Toggle enables/disables Studio Mode
- [ ] UI updates immediately
- [ ] Settings persist
- [ ] No performance impact when disabled

**Time Estimate (AI-assisted):** 1-2 hours (was 4-6h human)
- Settings toggle: 30min-1h (AI generates pattern)
- UI conditional display: 30min-1h

**Risk:** LOW - Simple toggle

---

#### 2.2 Pro Meters Suite (P2)
**Current State:** `PerformanceMonitor` exists, not visible
**Files:**
- `Fonic HiFi/Presentation/Views/Meters/MetersView.swift` (NEW)
- `Fonic HiFi/Core/Audio/Analysis/MeterEngine.swift` (NEW)

**Implementation Steps:**
1. **LUFS/RMS/Peak Meters:**
   ```swift
   // File: Core/Audio/Analysis/MeterEngine.swift
   final class MeterEngine {
       func analyzeLoudness(buffer: AVAudioPCMBuffer) -> LoudnessMetrics {
           let lufs = calculateLUFS(buffer)  // ITU-R BS.1770
           let rms = calculateRMS(buffer)
           let peak = calculatePeak(buffer)

           return LoudnessMetrics(
               lufs: lufs,
               rmsDB: 20 * log10(rms),
               peakDB: 20 * log10(peak)
           )
       }
   }
   ```

2. **Spectrum Analyzer:**
   - FFT-based frequency display (20Hz - 20kHz)
   - Use AudioKit's FFT or Metal Performance Shaders
   - 30 FPS update rate
   - Logarithmic frequency scale

3. **VU Meters:**
   - Classic analog-style VU meters
   - 300ms integration time (VU standard)
   - Peak hold with slow decay

4. **UI:**
   - Studio Mode → Meters tab
   - Grid layout: LUFS/RMS/Peak (top), Spectrum (middle), VU (bottom)
   - Real-time updates (30 FPS)

**Success Criteria:**
- [ ] LUFS accurate to ±0.5 LU vs reference
- [ ] Spectrum analyzer smooth at 30 FPS
- [ ] VU meters match analog behavior
- [ ] No thermal throttling during extended use
- [ ] Accessible via Studio Mode toggle

**Time Estimate (AI-assisted):** 10-14 hours (was 24-30h human)
- MeterEngine (LUFS/RMS/Peak): 3-4h (AI scaffolds algorithms, requires validation)
- Spectrum analyzer (Metal): 4-6h (complex, Metal shaders still manual)
- VU meters: 2-3h (AI generates from spec)
- Testing: 1h (accuracy verification)

**Risk:** HIGH - Real-time visualization requires Metal optimization

---

#### 2.3 Signal-Path Visualization (P2)
**Current State:** `BitPerfectValidator` provides data, no UI
**File:** `Fonic HiFi/Presentation/Views/SignalPath/SignalPathView.swift` (NEW)

**Implementation Steps:**
1. **Data model:**
   ```swift
   struct SignalPathNode {
       let name: String           // "Source File", "AVAudioEngine", "EQ"
       let sampleRate: Int        // 44100, 48000, 96000, etc.
       let bitDepth: Int          // 16, 24, 32
       let processing: String?    // "None", "Resampling", "DSP"
   }

   struct SignalPath {
       let nodes: [SignalPathNode]
       let isBitPerfect: Bool
   }
   ```

2. **Visualization:**
   - Flow diagram: Source → Engine → DSP → Output
   - Color-code nodes: Green (bit-perfect), Yellow (processing), Red (degradation)
   - Tap node for details

3. **UI:**
   - Studio Mode → Signal Path tab
   - Automatically updates when playback changes
   - Export as PNG for debugging

**Success Criteria:**
- [ ] Shows complete signal chain
- [ ] Highlights non-bit-perfect stages
- [ ] Explains each processing step
- [ ] Export works correctly
- [ ] Updates in real-time

**Time Estimate (AI-assisted):** 4-6 hours (was 12-16h human)
- SignalPathNode data model: 1h (AI generates from spec)
- Flow diagram visualization: 2-3h (layout logic)
- PNG export: 1h
- Testing: 1h

**Risk:** MEDIUM - Complex layout logic

---

#### 2.4 Smart Playlists Engine (P2)
**Current State:** Models exist, rules engine incomplete
**Files:**
- `Fonic HiFi/Data/Models/SmartPlaylist.swift` (EXISTS)
- `Fonic HiFi/Core/Logic/SmartPlaylistEngine.swift` (NEW)

**Implementation Steps:**
1. **Rule system:**
   ```swift
   enum PlaylistRule {
       case genre(contains: String)
       case sampleRate(op: ComparisonOp, value: Int)
       case bitDepth(op: ComparisonOp, value: Int)
       case playCount(op: ComparisonOp, value: Int)
       case lastPlayed(op: DateOp, value: Date)
       case rating(op: ComparisonOp, value: Int)
   }

   enum ComparisonOp {
       case equals, greaterThan, lessThan, contains
   }
   ```

2. **Predefined smart playlists:**
   - "Hi-Res" (sample rate ≥ 96kHz)
   - "Lossless" (FLAC, ALAC, WAV, AIFF)
   - "Recently Added" (last 7 days)
   - "Never Played"
   - "Top Rated" (rating ≥ 4 stars)

3. **UI:**
   - Library → Smart Playlists
   - Rule builder with + button
   - Live preview of matching tracks
   - Save custom smart playlists

**Success Criteria:**
- [ ] Predefined playlists work
- [ ] Custom rules evaluate correctly
- [ ] Live preview updates instantly
- [ ] Rules persist across launches
- [ ] Performance acceptable with 10k+ tracks

**Time Estimate (AI-assisted):** 6-8 hours (was 16-20h human)
- PlaylistRule system: 2-3h (AI generates from enum spec)
- Query engine: 2-3h (requires optimization iteration)
- UI rule builder: 2h (SwiftUI generation)
- Testing: 1h

**Risk:** MEDIUM - Query performance with large libraries

---

#### 2.5 Listening Statistics (P2)
**Current State:** No analytics
**Files:**
- `Fonic HiFi/Data/Models/PlaybackEvent.swift` (NEW)
- `Fonic HiFi/Presentation/Views/Stats/StatisticsView.swift` (NEW)

**Implementation Steps:**
1. **Track playback events:**
   ```swift
   struct PlaybackEvent {
       let trackID: PersistentIdentifier
       let timestamp: Date
       let duration: TimeInterval  // How long played
       let completed: Bool         // Played to end?
   }
   ```

2. **Statistics to display:**
   - Total listening time (today, week, month, all-time)
   - Most played tracks (top 10)
   - Most played artists (top 10)
   - Hi-res ratio (% of playback that's ≥ 96kHz)
   - Time-of-day heatmap
   - Format breakdown (FLAC, MP3, etc.)

3. **UI:**
   - Library → Statistics tab
   - Charts using Swift Charts
   - Time range picker (day, week, month, year, all)
   - Export as CSV

**Success Criteria:**
- [ ] All statistics accurate
- [ ] Charts render smoothly
- [ ] Time range filtering works
- [ ] CSV export valid
- [ ] Privacy preserved (local only)

**Time Estimate (AI-assisted):** 6-8 hours (was 16-20h human)
- PlaybackEvent tracking: 2h (AI generates data model)
- Statistics calculations: 2-3h
- Swift Charts UI: 2h (AI generates from examples)
- CSV export: 1h

**Risk:** MEDIUM - Chart layout can be tricky

---

#### 2.6 Batch Metadata Editor (P2)
**Current State:** Single-track editing only
**File:** `Fonic HiFi/Presentation/Views/Library/BatchMetadataEditor.swift` (NEW)

**Implementation Steps:**
1. **Multi-select in library:**
   - Long-press track → Edit mode
   - Select multiple tracks
   - "Edit Metadata" button

2. **Batch operations:**
   - Set genre (all selected)
   - Set album artist (all selected)
   - Set year (all selected)
   - Add artwork (all selected)
   - Clear lyrics (all selected)

3. **Undo support:**
   ```swift
   struct MetadataTransaction {
       let trackIDs: [PersistentIdentifier]
       let oldValues: [String: Any]
       let newValues: [String: Any]
   }

   func undo(transaction: MetadataTransaction) {
       // Restore old values
   }
   ```

4. **UI:**
   - Library → Edit mode → Select tracks
   - Batch Edit sheet
   - Field picker (which fields to edit)
   - Undo/Redo buttons

**Success Criteria:**
- [ ] Multi-select works smoothly
- [ ] Batch edits apply correctly
- [ ] Undo/redo functional
- [ ] Performance acceptable with 100+ tracks
- [ ] No data loss

**Time Estimate (AI-assisted):** 8-10 hours (was 20-24h human)
- Multi-select UI: 2-3h (SwiftUI generation)
- BatchMetadataEditor logic: 3-4h (transaction management complex)
- Undo/redo system: 2h
- Testing: 1h

**Risk:** HIGH - Complex transaction management

---

#### 2.7 Duplicate Detection (P2)
**Current State:** No duplicate checking
**File:** `Fonic HiFi/Core/Logic/DuplicateDetector.swift` (NEW)

**Implementation Steps:**
1. **Detection strategies:**
   - Exact match (file hash)
   - Metadata match (artist + title + album)
   - Acoustic fingerprint (Chromaprint/AcoustID)

2. **Implementation:**
   ```swift
   actor DuplicateDetector {
       func findDuplicates(
           in tracks: [Track],
           strategy: DetectionStrategy
       ) async -> [DuplicateGroup] {
           // Group tracks by similarity
       }
   }

   struct DuplicateGroup {
       let canonical: Track
       let duplicates: [Track]
       let similarity: Double  // 0.0 - 1.0
   }
   ```

3. **UI:**
   - Library → Duplicates
   - List of duplicate groups
   - Preview both tracks side-by-side
   - Keep/Delete actions
   - Batch delete duplicates

**Success Criteria:**
- [ ] Exact duplicates detected
- [ ] Metadata duplicates detected
- [ ] False positive rate < 5%
- [ ] Keep/Delete works correctly
- [ ] Batch operations safe

**Time Estimate (AI-assisted):** 6-8 hours (was 16-20h human)
- DuplicateDetector actor: 2-3h (AI generates detection strategies)
- Exact/metadata matching: 2h (straightforward)
- Acoustic fingerprinting: 2-3h (complex, requires external library)
- UI + testing: 1h

**Risk:** MEDIUM - Acoustic fingerprinting complex

---

### Phase 2 Exit Criteria

- [ ] Studio Mode toggle functional
- [ ] Pro meters (LUFS/RMS/Peak, Spectrum, VU) accurate
- [ ] Signal-path visualization clear
- [ ] Smart playlists with 5+ predefined + custom rules
- [ ] Listening statistics with charts
- [ ] Batch metadata editor with undo
- [ ] Duplicate detection with 3 strategies
- [ ] Internal beta with audiophile testers (20+ users)
- [ ] Positive feedback on pro tooling
- [ ] Performance acceptable on iPhone 16 Pro

**Phase 2 Time Summary:**
- **AI-assisted:** 41-56 hours (~1.5-2 weeks)
- **Human baseline:** 108-136 hours (~3-4 weeks)
- **Speedup:** ~2.4-2.6x

**Breakdown:**
- Studio Mode toggle: 1-2h (simple toggle)
- Pro meters: 10-14h (Metal optimization manual)
- Signal-path viz: 4-6h (layout logic)
- Smart playlists: 6-8h (query engine)
- Statistics: 6-8h (charts + data)
- Batch editor: 8-10h (transaction management)
- Duplicate detection: 6-8h (acoustic fingerprinting)

---

## Phase 3: Ecosystem & Connectivity
**Timeline:** February → April 2026 (3 months)
**Theme:** Platform integrations
**Priority:** P3 (Market expansion)

### Goals

Deliver CarPlay, Apple Watch, SharePlay, and network transfer to match ecosystem expectations. Maintain privacy-first philosophy (no mandatory cloud services).

### Features to Implement

#### 3.1 CarPlay Integration (P3)
**Current State:** No CarPlay target
**Files:**
- `Fonic HiFi/CarPlay/` (NEW directory)
- `Info.plist` (add CarPlay entitlements)

**Implementation Steps:**
1. **Enable CarPlay:**
   - Add `com.apple.developer.carplay-audio` entitlement
   - Create `CarPlaySceneDelegate.swift`
   - Implement `CPTemplateApplicationSceneDelegate`

2. **CarPlay templates:**
   - **Now Playing:** `CPNowPlayingTemplate`
     - Album art
     - Track title/artist
     - Play/pause, next, previous buttons
   - **Library:** `CPListTemplate`
     - Recent albums
     - Playlists
     - Search (voice input only)
   - **Queue:** `CPListTemplate`
     - Current queue
     - Swipe to remove

3. **Voice control:**
   - "Play music in Fonic HiFi"
   - "Play [album name]"
   - "Play [artist name]"
   - "Shuffle my music"

4. **Safety:**
   - No complex UI while driving
   - Large touch targets (44pt minimum)
   - Voice-first interaction

**Success Criteria:**
- [ ] CarPlay connects successfully
- [ ] Now Playing shows album art + controls
- [ ] Library browsable
- [ ] Voice commands work
- [ ] App Store CarPlay review passes

**Time Estimate (AI-assisted):** 10-14 hours (was 24-30h human)
- CarPlaySceneDelegate: 3-4h (AI generates from templates)
- Templates (Now Playing, Library, Queue): 3-4h
- Voice control integration: 2-3h
- Testing on physical CarPlay: 2-3h (manual validation required)

**Risk:** HIGH - CarPlay review can be strict

---

#### 3.2 Apple Watch Companion (P3)
**Current State:** No watchOS target
**Files:**
- `Fonic HiFi Watch/` (NEW directory)
- `Fonic HiFi Watch Extension/` (NEW directory)

**Implementation Steps:**
1. **Create watchOS target:**
   - Minimum: watchOS 11.0
   - SwiftUI-based
   - Shared data via iCloud sync (optional)

2. **Watch features:**
   - **Now Playing complication:**
     - Album art (circular)
     - Track title (truncated)
   - **Remote control:**
     - Play/pause
     - Next/previous
     - Volume control (Digital Crown)
   - **Shortcuts:**
     - Quick actions (play/pause, skip)

3. **UI:**
   - Minimal design (one-glance info)
   - Large buttons for easy tapping
   - Haptic feedback

**Success Criteria:**
- [ ] Watch app installs with iPhone app
- [ ] Complication shows current track
- [ ] Remote control works
- [ ] Digital Crown adjusts volume
- [ ] No excessive battery drain

**Time Estimate (AI-assisted):** 8-12 hours (was 20-26h human)
- watchOS target setup: 2-3h (AI scaffolds project structure)
- Complication + remote control: 3-4h
- Digital Crown integration: 1-2h
- Testing on physical Watch: 2-3h (manual validation required)

**Risk:** MEDIUM - WatchKit APIs evolving rapidly

---

#### 3.3 SharePlay Integration (P3)
**Current State:** No SharePlay support
**File:** `Fonic HiFi/Core/Audio/Services/SharePlayCoordinator.swift` (NEW)

**Implementation Steps:**
1. **Enable GroupActivities:**
   - Add `com.apple.developer.group-activities` entitlement
   - Create `ListeningTogetherActivity`

2. **SharePlay features:**
   - **Synchronized playback:**
     - All participants hear same track at same time
     - Play/pause synced
     - Queue shared
   - **Queue control:**
     - Anyone can add tracks
     - Host controls playback
   - **Chat integration:**
     - "Listening together in Fonic HiFi" FaceTime banner

3. **Implementation:**
   ```swift
   struct ListeningTogetherActivity: GroupActivity {
       let trackID: PersistentIdentifier
       let metadata = GroupActivityMetadata()
   }

   @MainActor
   final class SharePlayCoordinator: ObservableObject {
       func startSession(with track: Track) async {
           let activity = ListeningTogetherActivity(trackID: track.id)
           try? await activity.activate()
       }

       func syncPlayback(position: TimeInterval) async {
           // Sync all participants to this position
       }
   }
   ```

**Success Criteria:**
- [ ] SharePlay session starts from FaceTime
- [ ] Playback synchronized across devices
- [ ] Queue updates propagate
- [ ] Latency < 500ms
- [ ] Works on iOS 26+ only (no fallbacks)

**Time Estimate (AI-assisted):** 8-10 hours (was 16-20h human)
- ListeningTogetherActivity: 2-3h (AI generates GroupActivity)
- SharePlayCoordinator: 3-4h (synchronization logic complex, requires iteration)
- Testing with multiple devices: 3h (manual testing required)

**Risk:** HIGH - Synchronization complex

---

#### 3.4 Wi-Fi Transfer Utility (P3)
**Current State:** Manual file import only
**File:** `Fonic HiFi/Core/Network/WiFiTransferService.swift` (NEW)

**Implementation Steps:**
1. **Enable local network:**
   - Add `NSLocalNetworkUsageDescription` to Info.plist
   - Add `NSBonjourServices` for service discovery

2. **Transfer protocol:**
   - HTTP server on device
   - Web interface for uploads
   - Drag-and-drop support
   - Progress tracking

3. **Implementation:**
   ```swift
   actor WiFiTransferService {
       private var httpServer: HTTPServer?

       func startServer() async throws {
           httpServer = HTTPServer(port: 8080)
           httpServer?.addHandler(for: "/upload") { request in
               // Handle file upload
           }
           try await httpServer?.start()
       }

       func stopServer() async {
           await httpServer?.stop()
       }
   }
   ```

4. **UI:**
   - Settings → Wi-Fi Transfer
   - "Start Server" button
   - Display local IP + port (e.g., http://192.168.1.100:8080)
   - QR code for easy access

5. **Security:**
   - Local network only (no internet access)
   - Password protection (optional)
   - HTTPS with self-signed cert (optional)

**Success Criteria:**
- [ ] Server starts on local network
- [ ] Web interface accessible from browser
- [ ] File uploads work
- [ ] Progress updates in real-time
- [ ] Server stops cleanly

**Time Estimate (AI-assisted):** 6-8 hours (was 16-20h human)
- WiFiTransferService actor: 2-3h (AI scaffolds HTTP server)
- Web interface: 2-3h (HTML + JavaScript generation)
- QR code + UI: 1h
- Security + testing: 1-2h

**Risk:** MEDIUM - Networking can be fragile

---

#### 3.5 NAS/DLNA Streaming (P3 - Research Track)
**Current State:** Not planned
**Status:** DEFERRED to post-Phase 3

**Rationale:**
- High complexity, low user demand
- Privacy concerns (network access)
- Focus on local-first experience

**Research questions:**
- Which protocol? (SMB, NFS, DLNA/UPnP)
- Authentication model?
- Offline caching strategy?
- Bandwidth requirements?

**If pursued later:**
- Estimate: 40-60 hours
- Risk: VERY HIGH - Protocol complexity, compatibility issues

---

### Phase 3 Exit Criteria

- [ ] CarPlay app functional with Now Playing + Library
- [ ] Apple Watch complication + remote control
- [ ] SharePlay synchronized playback
- [ ] Wi-Fi transfer server working
- [ ] All ecosystem features pass App Store review
- [ ] No privacy regressions (local-first maintained)
- [ ] App Store submission-ready build
- [ ] Marketing materials prepared

**Phase 3 Time Summary:**
- **AI-assisted:** 32-44 hours (~1-1.5 weeks)
- **Human baseline:** 76-96 hours (~2-3 weeks)
- **Speedup:** ~2.2-2.4x

**Breakdown:**
- CarPlay: 10-14h (templates + testing)
- Apple Watch: 8-12h (complications + remote)
- SharePlay: 8-10h (synchronization complex)
- Wi-Fi transfer: 6-8h (HTTP server + UI)

---

## Parallel Workstreams

These tasks can be done concurrently with phases above.

### Quick-Win Backlog

#### Library Badges
**Time:** 4-6 hours
**File:** `Fonic HiFi/Presentation/Views/Library/LibraryView.swift`

- Show file counts per format (e.g., "142 FLAC, 89 MP3")
- Total library size (GB)
- Hi-res percentage

#### Swipe Gestures & Haptics
**Time:** 6-8 hours
**File:** `Fonic HiFi/Presentation/Views/Queue/QueueView.swift`

- Swipe left to remove from queue
- Swipe right to add to favorites
- Haptic feedback on actions

#### Dynamic Island Support
**Time:** 8-12 hours (post-Phase 1)
**File:** `Fonic HiFi/Presentation/Views/DynamicIsland/LiveActivity.swift` (NEW)

- Show Now Playing in Dynamic Island
- Live Activity for background playback
- Animations on track change

### Technical Debt & Infrastructure

#### Continuous Integration
**Time:** 12-16 hours
**Setup:**
- GitHub Actions workflow
- Automated `make build`, `make test-unit`
- SwiftLint/SwiftFormat gates
- Nightly builds to TestFlight

#### Audio Regression Harness
**Time:** 16-20 hours
**File:** `Tests/AudioTests/RegressionTests.swift` (NEW)

- Sine sweep comparison (detect gapless accuracy)
- Frequency response tests (EQ validation)
- Distortion analysis (THD+N)
- Automated on every PR

#### Structured Logging
**Time:** 8-10 hours
**Refactor:** Replace `print()` with `os.Logger`

- Categories: playback, import, network, ui
- Levels: debug, info, warning, error
- Export logs for debugging

---

## Technical Architecture

### Audio Engine Facade Pattern

```
AudioEngineFacade (Main coordinator)
├── AVAudioEngineAdapter (Apple's native engine)
│   ├── Formats: MP3, AAC, ALAC, WAV, AIFF
│   ├── DSP: AVAudioUnitEQ, AVAudioUnitTimePitch
│   └── Strength: Best iOS integration
└── AudioKitEngineAdapter (AudioKit engine)
    ├── Formats: FLAC (via wrapper)
    ├── DSP: AKEqualizer, AKTimePitch, AKBooster
    └── Strength: Superior DSP quality
```

**Engine Selection Logic:**
1. Detect format via `AudioFormatDetectionManager`
2. If FLAC → AudioKitEngineAdapter
3. Else → AVAudioEngineAdapter (default)
4. Fallback gracefully if primary fails

### Concurrency Model (Swift 6.2)

**Actor Isolation Boundaries:**
- `@MainActor`: All UI components, ViewModels, AudioEngineFacade
- `TrackDataActor`: SwiftData operations, file I/O
- `FileImportProcessor`: Background file processing (P0-1 fix)
- `AudioSessionManager`: Session management (no actor)

**Critical Threading Rules:**
1. Audio callbacks dispatch to `@MainActor` via `Task { @MainActor in }`
2. SwiftData operations through `TrackDataActor`
3. All cross-actor types conform to `Sendable`
4. Weak self captures in closures

### State Management Architecture

```
PlaybackStateManager (Single source of truth)
├── PlaybackState (Immutable state snapshot)
├── PlaybackStateStore (Persistence layer)
└── Published to:
    ├── AudioEngineFacade
    └── Individual ViewModels
```

**State Flow:**
1. User action → ViewModel method
2. ViewModel → AudioEngineFacade command
3. AudioEngine → PlaybackStateManager update
4. State change → Published to all observers
5. UI updates via `@Published` properties

### SwiftData Integration

**Model Persistence:**
- All database operations through `TrackDataActor`
- Batch imports for performance
- Relationships: Artist ↔ Album ↔ Track ↔ Playlist
- Migration support via versioned schemas

---

## Testing Strategy

### Phase 0 Testing

**Gapless Playback:**
- Sine sweep test: Detect gaps > 10ms
- 50-track continuous playback
- Format mixing (MP3 → ALAC → WAV)
- Manual listening test

**Bit-Perfect Validator:**
- Hardware probe comparison (accuracy ±0.1%)
- All supported formats
- DSP disabled vs enabled states

**Progress Timer:**
- 10-minute playback drift test (< 100ms error)
- Seek accuracy (< 50ms error)
- Lock screen sync

### Phase 1 Testing

**FLAC Decoder:**
- Test files: 16/44.1, 24/96, 24/192
- Bit-perfect verification
- Gapless between FLAC tracks
- Metadata extraction accuracy

**EQ:**
- Frequency response measurement (±1dB tolerance)
- Preset accuracy verification
- Real-time adjustment latency (< 100ms)
- No audible artifacts

**Crossfade:**
- Transition smoothness (no clicks/pops)
- Durations: 1s, 3s, 6s, 12s
- Logarithmic curve validation

### Phase 2 Testing

**Pro Meters:**
- LUFS accuracy vs reference (±0.5 LU)
- RMS/Peak accuracy (±0.1 dB)
- Spectrum analyzer linearity
- VU meter integration time (300ms ±10%)

**Smart Playlists:**
- Query performance with 10k+ tracks (< 500ms)
- Rule evaluation correctness
- Live preview updates

### Phase 3 Testing

**CarPlay:**
- Physical CarPlay unit testing
- Voice command accuracy
- Safety compliance (no complex UI while driving)

**Apple Watch:**
- Complication updates (< 1s latency)
- Remote control responsiveness
- Battery impact (< 5% over 1 hour)

**SharePlay:**
- Synchronization latency (< 500ms)
- Queue propagation
- Disconnect/reconnect handling

### Device Test Matrix

| Device | iOS Version | Purpose |
|--------|-------------|---------|
| iPhone 16 Pro | 26.0 | Primary development device |
| iPhone 15 Pro | 26.0 | Testing older A17 Pro chip |
| iPad Pro (M4) | 26.0 | Large screen layout testing |
| Apple Watch Series 10 | 11.0 | watchOS companion testing |
| CarPlay unit | iOS 26 | CarPlay integration testing |

### Thread Performance Checker

**Enable in Xcode:**
- Edit Scheme → Run → Diagnostics
- Check "Thread Performance Checker"
- Build & run with 0 warnings target

**Test scenarios:**
- Import 50 files (FileImportProcessor validation)
- 1-hour continuous playback
- Rapid track skipping (10 skips/second)
- Background/foreground transitions

---

## AI-Assisted Development Methodology

### Overview

This plan assumes AI coding agent assistance (Claude Code, Cursor, etc.) for implementation, resulting in ~2.5-3x speedup over human development. Understanding where AI excels and where it struggles is critical for realistic planning.

### AI Strengths (5-10x Speedup)

**1. Boilerplate Generation**
- SwiftUI views from descriptions
- Actor/ViewModel scaffolding
- Data model creation (Swift Codable, SwiftData)
- Test suite generation from specifications

**Example:** Creating `LyricsView.swift` with auto-scrolling, highlighting, and seek gestures:
- **Human:** 6-8 hours (research + implementation + debugging)
- **AI:** 1-2 hours (describe behavior → generate → iterate once)

**2. Pattern Implementation**
- State machines (AB Loop, Sleep Timer)
- Persistence (PlaybackStateStore, UserDefaults)
- Common UI patterns (Settings toggles, pickers, sliders)

**Example:** `ABLoopViewModel` state machine:
- **Human:** 10-14 hours (design states + transitions + edge cases)
- **AI:** 1-2 hours (describe states → generate → test)

**3. Test Generation**
- Unit tests from function signatures
- SwiftUI preview code
- Mock data generation

**Example:** Generating 20 unit tests for `EqualizerEngine`:
- **Human:** 4-6 hours
- **AI:** 30-60 minutes

### AI Moderate Efficiency (2-3x Speedup)

**1. Complex Algorithms**
- DSP processing (EQ, crossfade, time-stretch)
- Audio buffer management
- Synchronization logic (SharePlay, progress timer)

**Why slower:** Requires multiple iteration cycles to get buffer timing, edge cases, and performance right.

**Example:** Crossfade algorithm with logarithmic curves:
- **Human:** 12-16 hours (research fade curves + implement + tune)
- **AI:** 4-6 hours (generate baseline → iterate on timing → manual listening tests)

**2. Metal/GPU Programming**
- Spectrum analyzer visualization
- Custom shaders for Liquid Glass effects
- Real-time waveform rendering

**Why slower:** Metal requires low-level optimization knowledge, AI generates but human must optimize.

**Example:** 30 FPS spectrum analyzer:
- **Human:** 12-16 hours (Metal Performance Shaders + optimization)
- **AI:** 6-8 hours (generate baseline → profile → optimize)

### AI Limitations (1-1.5x Speedup or None)

**1. Manual Validation (NO Speedup)**
- **Audio quality testing:** Listening tests for gapless, crossfade, EQ
- **Device testing:** CarPlay, Apple Watch physical device testing
- **Performance profiling:** Instruments, Thread Performance Checker
- **App Store submission:** Screenshots, descriptions, compliance

**Time remains unchanged:** If testing takes 3 hours manually, it takes 3 hours with AI.

**2. Architecture Decisions (Minimal Speedup)**
- **System design:** Choosing between actor patterns, state management approaches
- **Technology selection:** AudioKit vs SFBAudioEngine vs FFmpegKit
- **Privacy architecture:** Network protocol choices, data flow

**Why:** AI can generate *implementations* of decisions, not make strategic tradeoffs.

**3. Debugging Complex Issues (Minimal Speedup)**
- **Race conditions:** Thread Performance Checker warnings
- **Memory leaks:** Instruments profiling
- **Audio glitches:** Buffer underruns, timing issues

**Why:** Debugging is iterative exploration, not pattern matching.

### Iteration Expectations

**Simple Features** (UI, settings, basic logic):
- 1-2 iterations typically sufficient
- AI generates correctly on first try ~70% of the time

**Complex Features** (DSP, synchronization, Metal):
- 3-5 iterations expected
- AI generates working baseline, requires tuning for quality/performance

**Critical Features** (gapless playback, bit-perfect verification):
- 5-10 iterations possible
- AI accelerates coding, but correctness requires extensive testing

### Time Estimate Breakdown Formula

**AI-assisted time** = (Implementation time × 0.3-0.4) + (Testing time × 1.0)

**Example: FLAC Decoder (16-20h human → 6-8h AI)**
- Implementation: 12h × 0.3 = 3.6h (AI scaffolds integration)
- Testing: 4h × 1.0 = 4h (manual validation unchanged)
- **Total: ~8h**

**Example: Gapless Playback (12-16h human → 4-6h AI)**
- Implementation: 8h × 0.4 = 3.2h (complex algorithm, more iteration)
- Testing: 4h × 1.0 = 4h (listening tests unchanged)
- **Total: ~7h**

### Best Practices for AI-Assisted Development

**1. Clear Specifications**
- Provide detailed behavior descriptions
- Include edge cases and error states
- Reference existing patterns in codebase

**2. Incremental Iteration**
- Generate → Build → Test → Refine
- Don't ask for everything at once
- Validate each component before integration

**3. Leverage Existing Patterns**
- Point AI to similar implementations (e.g., "like PlaybackStateManager but for lyrics")
- Reuse actor patterns, concurrency models
- Consistency reduces iteration cycles

**4. Manual Validation Checkpoints**
- Audio quality: Always listen test
- Performance: Profile with Instruments
- Threading: Enable Thread Performance Checker
- Memory: Check for retain cycles

### Summary of Speedup by Category

| Category | Human Time | AI Time | Speedup | Rationale |
|----------|-----------|---------|---------|-----------|
| **Boilerplate** | 100h | 15-20h | 5-10x | Pure code generation |
| **Pattern implementation** | 80h | 25-30h | 3-4x | Familiar patterns, minimal iteration |
| **Complex algorithms** | 120h | 50-60h | 2-2.4x | Requires iteration + tuning |
| **Testing/validation** | 40h | 40h | 1x | Manual effort unchanged |
| **Architecture/design** | 20h | 18-20h | 1-1.1x | Human decisions required |
| **TOTAL** | **360h** | **148-170h** | **~2.5x** | Weighted average |

**Note:** These are typical ranges. Individual features may vary based on complexity and existing codebase context.

---

## Risk Management

### Critical Risks

#### 1. FLAC Decoder Licensing (Phase 1)
**Risk:** App Store rejection due to LGPL licensing of libFLAC
**Probability:** MEDIUM
**Impact:** HIGH (blocks Phase 1)

**Mitigations:**
- Use AudioKit's FLAC wrapper (already MIT licensed)
- If needed, modularize decoder for optional download
- Engage legal counsel early (before Phase 1 starts)
- Document compliance in App Store submission notes

---

#### 2. DSP Performance on Older Devices (Phase 1-2)
**Risk:** Audio glitches, thermal throttling, battery drain
**Probability:** HIGH
**Impact:** HIGH (undermines audiophile credibility)

**Mitigations:**
- Performance modes: "Full Quality" vs "Power Saver"
- Benchmark with Instruments on iPhone 15 Pro (oldest supported)
- Expose settings to disable heavy features (meters, visualization)
- Monitor thermal state and auto-disable features if overheating

---

#### 3. CarPlay Review Rejection (Phase 3)
**Risk:** App Store rejects CarPlay due to safety concerns
**Probability:** MEDIUM
**Impact:** MEDIUM (delays Phase 3 completion)

**Mitigations:**
- Follow CarPlay HIG strictly
- No complex UI (large touch targets only)
- Voice-first interaction model
- Submit for early review feedback

---

#### 4. SharePlay Synchronization Complexity (Phase 3)
**Risk:** Poor sync experience, high latency, crashes
**Probability:** HIGH
**Impact:** MEDIUM (SharePlay is nice-to-have, not critical)

**Mitigations:**
- Start with MVP (basic playback sync only)
- Gate as beta feature initially
- Extensive testing with multiple devices
- Defer if proving too complex

---

### Dependency Risks

#### External Libraries
**AudioKit:**
- **Risk:** Abandonment, breaking changes
- **Mitigation:** Fork repository, maintain internal version

**SFBAudioEngine (if used):**
- **Risk:** LGPL licensing issues
- **Mitigation:** Evaluate thoroughly before integration

#### Apple Frameworks
**Foundation Models (AI features):**
- **Risk:** iOS 26+ only, device requirements (A17 Pro+)
- **Mitigation:** Gate features behind version/device checks

**SharePlay:**
- **Risk:** API instability (relatively new)
- **Mitigation:** Extensive beta testing, defer if unstable

---

## Appendix: Market Context

### Competitive Landscape (2025)

**Premium Audiophile Players:**
1. **VOX Music Player** - Subscription model, cloud sync, comprehensive formats
2. **Neutron Player** - Professional-grade, steep learning curve, dated UI
3. **Onkyo HF Player** - Best DSD support, expensive addons, limited customization
4. **Flacbox** - Excellent NAS support, complex UI

**Mainstream Players:**
1. **Offline Music Player** - Simple, affordable, limited features
2. **Evermusic** - Cloud focus, subscription model
3. **Cs Music Player** - Basic functionality, minimal updates

### Baseline Expectations (🔹)
- FLAC/ALAC/WAV/AIFF support
- Gapless playback
- Crossfade
- EQ presets
- Lyrics display
- Folder browsing
- Sleep timer
- Replay gain
- Lock screen controls

### Premium Differentiators (⭐)
- DSD/MQA support
- Room correction
- Crossfeed
- Smart playlists
- Spectrum/VU meters
- Collaborative playlists

### Emerging Capabilities (🔥)
- AI-based organization
- AutoMix transitions
- AI-generated visualizations
- Year-in-review insights

### Fonic HiFi Positioning

**Unique Value Propositions:**
1. **Privacy-first:** Zero cloud dependencies, no telemetry, local-only processing
2. **Transparency:** Bit-perfect verification, signal-path visualization, pro meters
3. **Modern craft:** iOS 26 Liquid Glass design, Swift 6 concurrency
4. **One-time purchase:** No subscriptions (Basic free, Pro $19.99, Audiophile $39.99)

**Target Segments:**
- Audiophiles (30%) - Bit-perfect playback, DSD support, transparency
- Privacy-conscious (25%) - Offline processing, no telemetry
- Power users (20%) - Smart playlists, statistics, automation
- Music collectors (25%) - Metadata management, duplicate detection

---

## Conclusion

This plan provides a comprehensive roadmap to transform Fonic HiFi from a promising prototype into a competitive, privacy-first audiophile player. By following the phased approach, we maintain focus on core stability before expanding features, ensuring each release delivers value while building toward the full vision.

**Key Success Factors:**
1. **Disciplined phasing:** Complete Phase 0 before Phase 1, etc.
2. **Quality over speed:** Test thoroughly, iterate on feedback
3. **Privacy commitment:** No compromises, even if features take longer
4. **Community engagement:** Beta testing with audiophiles, incorporate feedback
5. **Think different:** Challenge assumptions, build for users who care

**"Because the people who are crazy enough to think they can change the world, are the ones who do."**

---

**End of Plan**
**Next Step:** Begin Phase 0 implementation with gapless playback
**Questions?** Refer to individual phase sections for detailed instructions
