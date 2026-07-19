# Backend Audio & Data Audit — Fonic HiFi

**Scope:** `Fonic HiFi/` app target (Core/Audio, Data, persistence, concurrency) + `Fonic HiFiTests/`.
**Method:** Static read-only review on Linux (no compile). Every finding cites file:lines with a verbatim excerpt read this session.
**Reference standards used:** `.claude/reference/swift62-concurrency.md` (the real house standard). Note: `.claude/reference/project-config.md` is boilerplate copied from an unrelated HealthKit app ("Halie Heart" — HealthKit entitlements, `SWIFT_VERSION: 6.0`, CoreData/CloudKit) and does **not** describe this project; I did not hold the code to its (wrong) contents, but the mismatch is itself worth fixing before release.

---

## Summary (worst first)

- **Headphones unplugged does NOT pause playback.** `StateCoordinator.handleRouteChange` logs `oldDeviceUnavailable` and does nothing — music keeps blasting from the phone speaker. This is the single most user-visible audio bug and the exact scenario Apple warns about. (High)
- **Gapless/crossfade is broken on the AVAudioEngine (lossless) path.** `AVAudioEngineAdapter` never overrides `crossfade(...)`, so it inherits the protocol default = `load()`→`play()` (a hard stop-restart). `load()` also calls `stop()` which **deactivates the AVAudioSession** (`notifyOthersOnDeactivation`) on every track change → guaranteed audible gap + ducking. Directly contradicts the "gapless" product goal. (High)
- **The default engine is AudioKit, not the bit-perfect AVAudioEngine path, and the AudioKit path is not bit-perfect.** Factory selects AudioKit for `.balanced` (the default) and `.quality`; the AudioKit chain always routes through a `Mixer` + `TimePitch` node (never bypassed even at rate 1.0), and its `isBitPerfect` never checks sample-rate match. "Bit-perfect" is effectively unverified/false on the shipping default. (High)
- **FLAC is misclassified as not-natively-supported**, forcing every FLAC (a core audiophile format) onto the AudioKit/extra-DSP path; the AVAudioEngine fallback would then fail to load it. (High)
- **IO buffer duration is never configured.** All the `AVAudioEngineConfig` helpers (`ioBufferDuration`, `optimalBufferSize`, `optimalFormat`, `sampleRateConverterSettings`) are dead code — `setPreferredIOBufferDuration` is never called. Hi-res playback runs at whatever default buffer the system picks → underrun/glitch risk. (Medium-High)
- **Queue state is serialized to `UserDefaults` synchronously on the main actor on every track change/enqueue/move**, and `validateForPersistence()` does a `FileManager.fileExists` stat for every track + history entry on each save. Main-thread jank during playback with large queues. (Medium)
- **AVAudioEngine seek reports wrong `currentTime` after seeking** (`scheduleSegment` resets `sampleTime` to 0), so the scrubber/now-playing jumps back to near-zero after a seek. (Medium)
- **Interruption *behavior* is untested end-to-end** and route-change pause behavior is absent + untested. `ImportSession` (a parallel import actor) reads metadata before acquiring security scope. (Medium/Low)
- **Good news:** no `try!`, no `fatalError`/`preconditionFailure` in production code, no `DispatchQueue.*`, no force-unwraps/`as!` in the audio core, only one justified `@unchecked Sendable`. Security-scoped resource handling on the *live* import path (`FileImportProcessor`) is correctly `defer`-balanced. Concurrency hygiene is generally strong.

---

## Findings

### [SEVERITY: High] Headphones/route disconnect does not pause playback
- **File:** `Fonic HiFi/Core/Audio/Coordinators/StateCoordinator.swift:191-205`
- **Evidence:**
```swift
public func handleRouteChange(_ change: AudioRouteChange) {
    logger.info("Audio route changed: \(change.currentRoute) (reason: \(change.reason))")
    switch change.reason {
    case .oldDeviceUnavailable:
        // Headphones were unplugged, might want to pause
        logger.info("Output device became unavailable")
    case .newDeviceAvailable:
        logger.info("New output device available")
    default:
        break
    }
}
```
- **Why it matters:** When wired headphones are unplugged or Bluetooth disconnects, iOS routes to the built-in speaker. Every well-behaved audio app (and Apple's HIG) pauses on `oldDeviceUnavailable` so audio doesn't suddenly blast out loud in public. Here it only logs. `pause()` is wired for interruptions and the remote pause command but never for route loss (verified: only two `facade.pause()` call sites, lines 177 and 217).
- **Fix:** Track play state and pause on device loss. `StateCoordinator` already holds `facade` and `stateManager`; make the handler act:
```swift
public func handleRouteChange(_ change: AudioRouteChange) {
    logger.info("Audio route changed: \(change.currentRoute) (reason: \(change.reason))")
    switch change.reason {
    case .oldDeviceUnavailable:
        // Output device (headphones/BT) removed → pause, matching system behavior.
        guard stateManager.currentState.isPlaying, let facade else { return }
        logger.info("Output device removed while playing — pausing")
        Task { @MainActor in await facade.pause() }
    default:
        break
    }
}
```
Add a `StateCoordinatorTests` case that feeds an `AudioRouteChange(reason: .oldDeviceUnavailable, …)` while `.playing` and asserts `facade.currentState` becomes `.paused`.

---

### [SEVERITY: High] Gapless/crossfade unimplemented on AVAudioEngine path; track transitions deactivate the session
- **File:** `Fonic HiFi/Core/Audio/Interfaces/AudioEngineService.swift:131-137` (default), `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:282-302` (`stop()` deactivates session), `Fonic HiFi/Core/Audio/Engine/PlaybackController.swift:75-120` (auto-advance calls `play`→`load`)
- **Evidence:** `AVAudioEngineAdapter` implements `prepareNext` but has **no** `crossfade(...)` override, so it uses the protocol default:
```swift
/// Default crossfade loads and plays the new track immediately
func crossfade(to url: URL, duration _: TimeInterval, playbackRate: Double, gainDB: Float) async throws {
    try await load(url: url)
    await setPlaybackRate(playbackRate)
    await applyReplayGain(gainDB)
    try await play()
}
```
And `AVAudioEngineAdapter.load()` (line 174) begins with `await stop()`, whose tail deactivates the session:
```swift
public func stop() async {
    primaryPlayerNode.stop()
    secondaryPlayerNode.stop()
    ...
    do {
        try await sessionManager.activateSession(false)   // setActive(false, .notifyOthersOnDeactivation)
    } catch { ... }
}
```
On natural track end, `PlaybackController.handleTrackCompletion` → facade `onTrackComplete` → `queueCoordinator.playNext()` → (crossfadeDuration is 0 by default) `playbackController.play(track:)` → `engine.load()` → `stop()` → session deactivate, then re-activate in `play()`. The prepared secondary player from `prepareNext` is never swapped in.
- **Why it matters:** For an audiophile player whose headline feature is gapless playback, every track boundary produces an audible gap, and tearing the session down/up mid-album interrupts other audio and can cause a click/gap and Now-Playing flicker. The `prepareNext` work is wasted on this engine.
- **Fix:** Implement a real dual-player transition in `AVAudioEngineAdapter` (it already has `secondaryPlayerNode`/`secondaryTimePitchNode` and `preparedFile`). Override `crossfade` to swap to the already-scheduled secondary player instead of stop/load/play, and crucially **do not deactivate the session on track-to-track transitions** — only deactivate on a true user stop. Concretely:
  1. Remove the `activateSession(false)` call from `stop()`; instead add an explicit `teardownSession()` the facade calls only from user-initiated `AudioEngineFacade.stop()`.
  2. Add:
```swift
public func crossfade(to url: URL, duration: TimeInterval, playbackRate: Double, gainDB: Float) async throws {
    // If we prepared this URL on the inactive player, just switch to it.
    let target = isPrimaryActive ? secondaryPlayerNode : primaryPlayerNode
    if hasNextPrepared, preparedFile?.url == url {
        target.play()                       // already scheduled at nil in prepareNext
        (isPrimaryActive ? primaryPlayerNode : secondaryPlayerNode).stop()
        isPrimaryActive.toggle()
        audioFile = preparedFile
        preparedFile = nil; hasNextPrepared = false
        return
    }
    // Fall back to load+play WITHOUT session teardown:
    try await loadWithoutSessionTeardown(url: url)
    try await play()
}
```
  Keep `setPlaybackRate`/`applyReplayGain` applied to the target chain before `play()`. This preserves the existing node graph and completion-handler dispatch pattern.

---

### [SEVERITY: High] Default engine is AudioKit and is not bit-perfect (TimePitch always in chain)
- **File:** `Fonic HiFi/Core/Audio/Factory/AudioEngineFactory.swift:107-146`, `Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift:64-68, 257-260, 348-356`
- **Evidence:** Selection prefers AudioKit for the default `.balanced` mode and for `.quality`:
```swift
case .balanced:
    if availableEngines[.audioKitEngine] == true, AudioEngineType.audioKitEngine.canHandle(format) {
        return .audioKitEngine
    }
```
AudioKit's graph always inserts a `TimePitch` per player and a shared `Mixer`, none bypassed at unity:
```swift
private func setupAudioKitEngine() throws {
    mixer.addInput(primaryPitch)
    mixer.addInput(secondaryPitch)
    engine.output = mixer
    ...
}
```
and its bit-perfect claim ignores sample-rate/format entirely:
```swift
public var isBitPerfect: Bool {
    get async { configuration.performanceMode == .quality && abs(currentGainDB) < .ulpOfOne }
}
```
- **Why it matters:** `TimePitch` (an AU time/pitch processor) and an extra float mixer sit in the signal path even at rate 1.0 and gain 0, so samples are re-processed — not bit-perfect. Meanwhile the real bit-perfect logic (sample-rate match, unity volume, EQ bypass) lives only in `AVAudioEngineAdapter.isBitPerfect` (lines 161-171), which is *not* the default engine. A product marketed as bit-perfect ships a default path that isn't.
- **Fix:** For `enableBitPerfect`/`.quality`, prefer `AVAudioEngineAdapter` (which has true EQ-bypass and rate-1.0-unmodified paths) and reserve AudioKit for formats AVFoundation can't decode. Minimal change in `selectEngineType`:
```swift
case .quality:
    if configuration.enableBitPerfect, canUseAVAudioEngine(for: format) {
        return .avAudioEngine          // true bit-perfect chain
    }
    if availableEngines[.audioKitEngine] == true, AudioEngineType.audioKitEngine.canHandle(format) {
        return .audioKitEngine
    }
```
And make `AudioKitEngineAdapter.isBitPerfect` honest: return `false` whenever `primaryPitch.rate != 1.0`, gain ≠ 0, OR the output sample rate ≠ file sample rate (compare `currentFile?.fileFormat.sampleRate` to `AVAudioSession.sharedInstance().sampleRate`). Better: bypass/omit `TimePitch` when `rate == 1.0` so unity playback is genuinely untouched.

---

### [SEVERITY: High] FLAC classified as not natively supported → forced off the bit-perfect engine
- **File:** `Fonic HiFi/Core/Audio/Engines/AVAudioEngineConfig.swift:156-165`, consumed at `Fonic HiFi/Core/Audio/Factory/AudioEngineFactory.swift:148-150` and `Core/Audio/Factory/AudioEngineType.swift:52`
- **Evidence:**
```swift
public static func isFormatNativelySupported(_ format: AudioFormat) -> Bool {
    switch format {
    case .mp3, .aac, .alac, .wav, .aiff:
        true
    case .flac, .ape, .dsd:
        false
    ...
```
- **Why it matters:** FLAC is the flagship lossless format for this audience. `AVAudioFile(forReading:)` (used in `AVAudioEngineAdapter.load`) decodes FLAC natively on iOS 11+. Marking it unsupported forces FLAC onto the AudioKit/extra-DSP path, and if AudioKit init fails the factory "falls back to AVAudioEngine anyway" (`AudioEngineFactory.createEngine` line 179) — which contradicts this flag and would otherwise be claimed unsupported. Net: FLAC never gets the bit-perfect AVAudioEngine path.
- **Fix:** Move FLAC into the supported set (keep APE/DSD false — those genuinely need a decoder AVFoundation lacks):
```swift
case .mp3, .aac, .alac, .wav, .aiff, .flac:
    true
case .ape, .dsd:
    false
```
Verify on-device that `AVAudioFile(forReading:)` opens your FLAC test assets (it should); keep AudioKit only as the APE/DSD path.

---

### [SEVERITY: Medium] Preferred IO buffer duration never set; hi-res buffer/format helpers are dead code
- **File:** `Fonic HiFi/Core/Audio/Services/AudioSessionManager.swift:69-96` (config sets only category), `Fonic HiFi/Core/Audio/Engines/AVAudioEngineConfig.swift:16-25, 30-56, 109-151` (never invoked)
- **Evidence:** `configureAudioSession()` sets category/mode/options and nothing else — no `setPreferredIOBufferDuration`, no `setPreferredSampleRate` here (rate is set later per-track in `PlaybackController.play`). A repo-wide search shows `optimalBufferSize(for mode:)`, `ioBufferDuration(for mode:)`, `optimalFormat(...)`, and `sampleRateConverterSettings(...)` have **no call sites** (only `isFormatNativelySupported` is used). `AudioEngineConfiguration.bufferSize` (default 512) is therefore never applied to the session.
```swift
try session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
// … no setPreferredIOBufferDuration / setPreferredSampleRate here
```
- **Why it matters:** For 96/192 kHz hi-res content the default IO buffer may be too small, risking dropouts/underruns (the very thing `BufferUnderrunTracker` is trying to count). The carefully-written buffer/latency tuning is inert.
- **Fix:** In `PlaybackController.play` (where sample rate is already requested) also request a buffer duration derived from performance mode, and apply it in `AudioSessionManager`:
```swift
// AudioSessionManager
public func setPreferredIOBufferDuration(_ seconds: TimeInterval) async {
    do { try session.setPreferredIOBufferDuration(seconds) }
    catch { logger.warning("Failed to set IO buffer duration: \(error.localizedDescription)") }
}
// PlaybackController.play, after setPreferredSampleRate(info.sampleRate):
await sessionManager.setPreferredIOBufferDuration(
    AVAudioEngineConfig.ioBufferDuration(for: engineManager.configuration.performanceMode)
)
```
Delete or wire up the remaining unused `AVAudioEngineConfig` helpers so the bit-perfect intent is real.

---

### [SEVERITY: Medium] Queue persistence: synchronous JSON encode + per-track filesystem stat on the main actor, on every mutation
- **File:** `Fonic HiFi/Core/Audio/Queue/AudioQueueManager.swift:655-665` (auto-save on every change), `Fonic HiFi/Core/Audio/Queue/QueueState.swift:322-327, 361-405` (`save()` + `validateForPersistence()`)
- **Evidence:**
```swift
private func notifyTracksChanged() {
    delegate?.audioQueue(self, didUpdateTracks: tracks)
    saveState()      // ← fires on enqueue/insert/move/remove/clear
}
private func notifyCurrentTrackChanged() {
    delegate?.audioQueue(self, didChangeCurrentTrack: currentTrack, at: currentIndex)
    saveState()      // ← fires on every track advance
}
```
`saveState()` → `validateForPersistence()` stats every track and every history entry:
```swift
let validTracks = tracks.filter { track in
    FileManager.default.fileExists(atPath: track.url.path)
}
...
history: history.filter { track in FileManager.default.fileExists(atPath: track.url.path) },
```
then `save()` JSON-encodes the whole `QueueState` and writes to `UserDefaults` — all on the `@MainActor` (`AudioQueueManager` is `@MainActor`).
- **Why it matters:** On track advance during playback (and it advances automatically), the main thread does N filesystem `stat` calls (N = queue size + history, capped 50) plus a full JSON encode + `UserDefaults` write. With a large album/playlist queue this is measurable main-thread jank that can hitch the UI and, on slow storage, contend with the audio render prep. `UserDefaults` is also the wrong store for a potentially large, frequently-rewritten blob.
- **Fix:** (a) Debounce/coalesce saves (only persist on a timer or on app-background, not on every mutation), (b) move the `fileExists` validation off the main actor — do it lazily at *restore* time, not on every save, and (c) persist to a file in Application Support via a background actor instead of `UserDefaults`. Minimal first step:
```swift
private var saveDebounce: Task<Void, Never>?
private func scheduleSave() {
    saveDebounce?.cancel()
    saveDebounce = Task { [weak self] in
        try? await Task.sleep(for: .seconds(2))
        guard let self, !Task.isCancelled else { return }
        await Task.detached { self.saveState() }.value   // encode off the main actor
    }
}
```
Call `scheduleSave()` from the notify methods instead of `saveState()`, and drop the per-save `fileExists` filtering (keep it only in `restoreState`).

---

### [SEVERITY: Medium] AVAudioEngine `currentTime` is wrong after a seek
- **File:** `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:118-132` (currentTime), `304-345` (seek via `scheduleSegment`)
- **Evidence:** `currentTime` derives seconds from the player node's `sampleTime`:
```swift
if let file = audioFile {
    let sampleRate = file.processingFormat.sampleRate
    return Double(playerTime.sampleTime) / sampleRate
}
```
but `seek` reschedules a *segment* starting at the seek frame and restarts the player:
```swift
activePlayer.scheduleSegment(file, startingFrame: framePosition,
    frameCount: AVAudioFrameCount(framesToPlay), at: nil) { ... }
if wasPlaying { activePlayer.play() }
```
After `stop()`+`scheduleSegment`+`play()`, the node's `sampleTime` counter restarts near 0, so `currentTime` reports ~0 instead of the seek target, until the facade's own state catches up.
- **Why it matters:** The lock-screen scrubber and in-app progress read `engine.currentTime` (e.g. `PlaybackController.startProgressTracking`, `pause`, `refreshNowPlayingMetadata`). After scrubbing forward, position visibly snaps back toward zero — a confusing, glitchy UX for a premium player, and it corrupts listening-session `durationListened` math.
- **Fix:** Track a seek offset and add it to the node-relative time:
```swift
private var seekFrameOffset: AVAudioFramePosition = 0
// in seek(), after validating framePosition:
seekFrameOffset = framePosition
// in load()/stop(): seekFrameOffset = 0
// in currentTime:
let sampleRate = file.processingFormat.sampleRate
return Double(seekFrameOffset + playerTime.sampleTime) / sampleRate
```
Reset `seekFrameOffset` to 0 on fresh `scheduleFile` (normal play) and on `stop`/`load`.

---

### [SEVERITY: Medium] `ImportSession` extracts metadata before acquiring security scope
- **File:** `Fonic HiFi/Data/Services/ImportSession.swift:179-199, 298-308`
- **Evidence:** `addItem` reads metadata straight off the caller's URL; security scope is only started later, inside `copyFile`:
```swift
public func addItem(_ url: URL) async throws {
    let destinationURL = self.generateUniqueDestinationURL(for: url)
    let metadata = try await self.metadataExtractor.extractTrackMetadata(from: url) // ← no start-accessing
    ...
}
private func copyFile(from sourceURL: URL, to destinationURL: URL) async throws {
    let startedAccessing = sourceURL.startAccessingSecurityScopedResource()
    defer { if startedAccessing { sourceURL.stopAccessingSecurityScopedResource() } }
    try self.fileManager.copyItem(at: sourceURL, to: destinationURL)
}
```
- **Why it matters:** For files chosen via the Files app / document picker, reading before `startAccessingSecurityScopedResource()` fails with a permission error, so this transactional import path would reject legitimate files. The **live** app path (`LibraryImportService` → `FileImportProcessor`) handles scope correctly, so this is currently latent, but it's a loaded footgun if anyone routes imports through `ImportSession`.
- **Fix:** Acquire scope for the whole item lifetime in `addItem` (or resolve via the stored bookmark as `FileImportProcessor.resolveSecurityScopedURL` does), mirroring the working path:
```swift
public func addItem(_ url: URL) async throws {
    let started = url.startAccessingSecurityScopedResource()
    defer { if started { url.stopAccessingSecurityScopedResource() } }
    let destinationURL = self.generateUniqueDestinationURL(for: url)
    let metadata = try await self.metadataExtractor.extractTrackMetadata(from: url)
    ...
}
```
Or delete `ImportSession` entirely if `FileImportProcessor` is the intended single path (reduces the maintained surface).

---

### [SEVERITY: Medium] Artwork stored inline in the SwiftData model → whole-blob loads on bulk fetches
- **File:** `Fonic HiFi/Data/Models/Track.swift:109-110`, bulk fetches in `Fonic HiFi/Data/Actors/TrackDataActor.swift:514-557` (`loadSourceHashCache`), `689-713` (`cleanupMissingFiles`), `947-959` (`getUniqueGenres`)
- **Evidence:**
```swift
/// Album artwork (stored as Data)
public var artwork: Data?
```
`loadSourceHashCache` fetches full `Track` rows (500 at a time) only to read three hash strings:
```swift
// Fetch full Track models in batches (SwiftData doesn't support field projection)
let tracks = try modelContext.fetch(descriptor)
for track in tracks {
    if let hash = track.sourceURLHash { urlHashes.insert(hash) }
    ...
}
```
- **Why it matters:** With artwork bytes embedded in the `Track` entity, every `FetchDescriptor<Track>` that materializes rows pulls the artwork blobs into memory. During an import's duplicate scan (`loadSourceHashCache`) or `cleanupMissingFiles` on a large library this can spike memory hard and is pure waste when only hashes/paths are needed.
- **Fix:** Mark artwork for external storage so it isn't loaded until touched:
```swift
@Attribute(.externalStorage) public var artwork: Data?
```
(Album artwork on `Album` similarly.) This is a lightweight-migration-safe change. For the hash scan, keep the batching but the external-storage attribute means blobs stay on disk unless accessed. Longer term, store artwork as files keyed by hash and keep only a path/þumbnail in the model.

---

### [SEVERITY: Low] `AudioKitEngineAdapter` completion is timer-polled at 0.1 s and can advance late/gappy
- **File:** `Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift:309-334`
- **Evidence:**
```swift
updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
    guard let self else { return }
    Task { @MainActor in await self.updateProgress() }
}
...
private func updateProgress() async {
    guard _isPlaying else { return }
    _currentTime = activePlayer.currentTime
    _duration = activePlayer.duration
    if _currentTime >= _duration { _isPlaying = false; stopProgressPolling(); completionHandler?() }
}
```
- **Why it matters:** On the (currently default) AudioKit engine, end-of-track is detected by a 0.1 s wall-clock poll comparing `currentTime >= duration`, not by a real render-complete callback. That's up to ~100 ms of slop at each boundary — a small but audible gap for gapless material, and it can miss the exact end if `currentTime` plateaus just under `duration`. `[weak self]` is correct so no leak.
- **Fix:** Use AudioKit `AudioPlayer.completionHandler` (fires on actual playback completion) to drive `completionHandler`, and keep the timer only for progress UI:
```swift
activePlayer.completionHandler = { [weak self] in
    Task { @MainActor in self?.completionHandler?() }
}
```
Combined with the gapless fix above, prefer scheduling the next buffer rather than detecting end + reloading.

---

### [SEVERITY: Low] `project-config.md` house reference is the wrong project
- **File:** `.claude/reference/project-config.md:1-25` (and throughout)
- **Evidence:**
```
# iOS 26 Project Configuration Reference (Fonic HiFi Audio Player)
...
SWIFT_VERSION: 6.0
<!-- Halie_Heart.entitlements -->
<key>com.apple.developer.healthkit</key>
```
- **Why it matters:** The stated build settings (`SWIFT_VERSION: 6.0` vs the project's Swift 6.2), entitlements (HealthKit/CloudKit), and folder structure ("HalieHeart/…") describe a different app. Anyone using this as the source of truth for release config (background modes for audio, `UIBackgroundModes: audio`, code-signing) will be misled. I did **not** flag code against this document; the doc itself is the defect.
- **Fix:** Replace with the actual Fonic HiFi config: `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, Swift 6.2 + `SWIFT_STRICT_CONCURRENCY = complete`, `UIBackgroundModes = [audio]`, App Group `group.…` used by `DataManager+Initialization` (`WidgetConstants.appGroupIdentifier`), and the real Core/Data/Domain/Presentation layout. (iOS 26 minimum is correct and should stay.)

---

## Test Coverage Notes

- **Broad backend coverage exists** (~94 test files): engines, factory, queue (shuffle/repeat/state), state manager, playback controller, import pipeline (`FileImportProcessorTests`, `ImportPipelineTests`, `ImportValidationScenarioTests`), `TrackDataActor`, monitoring/diagnostics, and `QueueState` persistence. Concurrency-oriented suites (`FormatDetectionServiceConcurrencyTests`, `MainActorHelpersTests`) are present.
- **Interruption handling is only model-tested, not behavior-tested.** `AudioSessionInterruptionTests` (lines 5-64) verifies the `AudioSessionInterruption` struct/notification parsing and `recommendedAction`, but nothing asserts that a `.began` interruption actually pauses the engine through `StateCoordinator`/`AudioEngineFacade`, nor that `.ended(shouldResume:true)` resumes. Add end-to-end tests that drive `facade.audioSessionDidInterrupt(.began)` / `.ended(shouldResume:true)` and assert state transitions.
- **No route-change / headphone-unplug test at all** — consistent with the missing behavior (Finding 1). Add a `.oldDeviceUnavailable` → paused test alongside the fix.
- **No gapless/crossfade assertion for the AVAudioEngine path.** `PlaybackControllerTests.crossfadeUsesConfigurationAndPreparesNextTrack` exercises a mock engine's `crossfade`; it does not catch that the real `AVAudioEngineAdapter` has no `crossfade` override (Finding 2). Add a test that the concrete adapter transitions without a session deactivation.
- **No bit-perfect assertion on the shipping default engine.** `BitPerfectValidatorTests` covers the validator, but there is no test that the *selected* engine for `.balanced`/`.quality` is actually sample-accurate/unity (Finding 3/4). A selection test asserting FLAC + `.quality` picks the AVAudioEngine bit-perfect path would lock in the fix.
- **Seek correctness after `scheduleSegment` is untested** for reported `currentTime` (Finding 6).

## Architecture Observations (non-defect, brief)

- **Clean modular decomposition:** `AudioEngineFacade` composes `AudioEngineManager` / `PlaybackController` / `QueueCoordinator` / `StateCoordinator` / `ProgressTimerManager`, all `@MainActor`, with engine work behind the `AudioEngineService` protocol. Progress timing is centralized in one cancellable structured-`Task` (`ProgressTimerManager`) — good, avoids the old per-adapter timer races.
- **Concurrency hygiene is strong and matches the house doc:** no `DispatchQueue.*`, no `try!`/`fatalError` in production, Core-Audio completion blocks correctly hop to `@MainActor` via `Task { @MainActor [weak self] in … }` (`AVAudioEngineAdapter.play/seek/prepareNext`), remote-command targets likewise. The single `@unchecked Sendable` (`AudioPlaybackSettingsStore.DefaultsBox` wrapping `UserDefaults`) is justified (thread-safe, immutable, actor-confined) — consistent with `swift62-concurrency.md`.
- **Persistence split:** `TrackDataActor` is a `@ModelActor` (own context, off-main) for writes; `DataManager` exposes `mainContext` (autosave on) for `@Query` UI and a `backgroundContext` (autosave off). Cross-context propagation relies on SwiftData's save-merge; consider a brief note/verification that actor-side saves refresh `@Query` views (this is the "resolve library relations / playback churn" area). Not a defect, but the multi-context model is the main place subtle staleness bugs would hide.
- **Import copies files into `Documents/Music`** (`FileImportProcessor.copyFile`) rather than relying solely on bookmarks — reasonable for a guaranteed-offline player, at the cost of ~2× storage; source URL + bookmark are also retained for dedupe. Security-scope handling on this path is correctly `defer`-balanced across success/error/directory branches (`emitDiscoveredFiles`, `resolveSecurityScopedURL`, `bookmarkData`).
- **Robust launch fallbacks:** `DataManager` has layered container fallbacks (migration plan → minimal → in-memory read-only) surfaced via a recovery banner; app init defers cleanup/stats/backfill off the launch path. Good production resilience.
- **`AVAsset(url:)`** (deprecated sync initializer) is used in `MetadataExtractionService`; it loads properties async so it doesn't block, but prefer `AVURLAsset(url:)` going forward.
