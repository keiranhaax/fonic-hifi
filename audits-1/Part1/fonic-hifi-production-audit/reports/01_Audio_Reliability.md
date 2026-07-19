# 01 — Audio Reliability Audit

**Snapshot audited:** `main` at `459db9bfd18d17960e8fd2ff8defc4701085532e`
**Audit date:** 2026-07-09
**Evidence boundary:** active application, widget, test, entitlement, Info.plist, and Xcode-project source only. README/plans/logs were not used as proof. The repository was not modified.
**Tooling boundary:** static inspection only; this Linux environment has no Xcode or Apple SDK. No compilation, simulator, signing, Instruments, TestFlight, or physical-device result is claimed.

## Conclusion

**Not production-ready for audiophile playback reliability.** The active code has three high-severity paths: overlapping uncancelled play requests can commit stale tracks; audio-session ownership is split between different manager instances and the native adapter deactivates the session during load; and interruption/headphone-unplug handling can resume playback that was not playing before the interruption or continue through the speaker after route loss. Eighteen additional medium findings affect engine selection, M4A/lossless classification, exposed-but-unplayable formats, bit-perfect claims, gapless/crossfade, queue persistence and controls, native seek/A-B looping, remote commands, media-services reset, sleep timer, EQ/DSP, diagnostics, and widget synchronization.

Background capability and the basic Now Playing path are present: the active Info.plist declares audio background mode, the session uses `.playback`, metadata is written to `MPNowPlayingInfoCenter`, and standard play/pause/next/previous/position commands are registered. Those positives do not compensate for the state, routing, and recovery defects below.

### Retained finding counts

| Severity | Count |
|---|---:|
| Critical | 0 |
| High | 3 |
| Medium | 18 |
| Low | 0 |
| Informational | 0 |
| **Total** | **21** |

| Confidence | Count |
|---|---:|
| Confirmed by static evidence | 18 |
| Probable | 3 |
| UNVERIFIED — needs build/device check | 0 retained findings; device-only questions are separated below |

## Findings summary

| ID | Severity | Confidence | Summary |
|---|---|---|---|
| AUD-ENG-001 | Medium | Confirmed by static evidence | The AVAudioEngine preference is ignored for formats AudioKit can handle. |
| AUD-ENG-002 | High | Probable | Independent play tasks can finish out of order and play/clear the wrong track. |
| AUD-SESSION-001 | High | Probable | Session ownership is split; native load deactivates the session after the controller activates it. |
| AUD-FORMAT-001 | Medium | Confirmed by static evidence | Every `.m4a` is classified as ALAC/lossless, including AAC-in-M4A. |
| AUD-FORMAT-002 | Medium | Confirmed by static evidence | OGG, Opus, WavPack, and APE are exposed for import without a playable routing path. |
| AUD-CONFIG-001 | Medium | Confirmed by static evidence | Bit-perfect, sample-rate, and buffer controls are persisted UI only and do not configure playback. |
| AUD-BIT-001 | Medium | Confirmed by static evidence | Bit-perfect validation cache is not keyed by track or route. |
| AUD-BIT-002 | Medium | Confirmed by static evidence | The UI can label a heuristic session check “Bit-perfect” without observing the active engine graph. |
| AUD-TRANSITION-001 | Medium | Confirmed by static evidence | Gapless and native-engine crossfade controls do not implement seamless transitions. |
| AUD-TRANSITION-002 | Medium | Confirmed by static evidence | Pausing/cancelling an AudioKit crossfade leaves the engine and displayed track inconsistent. |
| AUD-DSP-001 | Medium | Confirmed by static evidence | EQ/replay-gain behavior silently varies by engine, and persisted EQ is not restored to playback. |
| AUD-QUEUE-001 | Medium | Confirmed by static evidence | Queue edit offsets target the wrong tracks whenever currentIndex is not zero. |
| AUD-QUEUE-002 | Medium | Confirmed by static evidence | Repeat-one traps manual Next and Previous on the same track. |
| AUD-RECOVERY-001 | Medium | Confirmed by static evidence | Queue validation drops the resume position and shuffled restore re-applies an index sequence to shuffled data. |
| AUD-SEEK-001 | Medium | Probable | Native seek loses the absolute frame offset; A-B looping is a 500 ms polling loop with swallowed failures. |
| AUD-SESSION-002 | High | Confirmed by static evidence | Interruption intent is not tracked and headphone unplug does not pause. |
| AUD-REMOTE-001 | Medium | Confirmed by static evidence | Skip-forward/backward commands advertise success but are never handled. |
| AUD-RESET-001 | Medium | Confirmed by static evidence | Media-services reset reconfigures only AVAudioSession, not either invalidated engine or Now Playing/commands. |
| AUD-SLEEP-001 | Medium | Confirmed by static evidence | Sleep timer lifetime is tied to a dismissed view and fade starts/restores from hard-coded full volume. |
| AUD-DIAG-001 | Medium | Confirmed by static evidence | Engine diagnostics contain fixed/zero measurements while the native output tap is always installed. |
| AUD-WIDGET-001 | Medium | Confirmed by static evidence | Widget progress is frozen and queue-mode synchronization is missed by perpetual 500 ms polling. |

---

## Full findings

### AUD-ENG-001 — AVAudioEngine preference is ignored

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Presentation/Views/Settings/AudioSettingsView.swift:11-29`
    > `@AppStorage("preferredAudioEngine") private var preferredAudioEngine = "AVAudioEngine"`
    > `Text("AVAudioEngine").tag("AVAudioEngine")`
    > `Text("AudioKit").tag("AudioKit")`
  - `Fonic HiFi/Core/Audio/Factory/AudioEngineFactory.swift:90-137`
    > `case "AudioKit", "AudioKitEngine":`
    > `return .audioKitEngine`
    > `case .balanced:`
    > `return .audioKitEngine`
- **Defect and execution path:** The picker presents two authoritative choices and defaults to `"AVAudioEngine"`. The factory explicitly recognizes only AudioKit strings. For MP3/AAC/ALAC/WAV/AIFF under the default balanced configuration, an AV preference falls through and AudioKit is selected. The UI choice and engine diagnostics can therefore disagree with the engine actually producing audio. The deferred-switch logic cannot fix the mismatch because it asks this same selector on the next load.
- **Remediation:** Parse both persisted values into `AudioEngineType`, validate `canHandle`, and only fall back to performance-mode selection when the requested engine cannot handle the detected format. Keep the current deferred-switch architecture.
- **Unapplied production patch (requires Xcode compile/test):**

```swift
private func preferredEngineType(for format: AudioFormat) -> AudioEngineType? {
    let stored = UserDefaults.standard.string(forKey: "preferredAudioEngine")
    let requested: AudioEngineType? = switch stored {
    case "AVAudioEngine": .avAudioEngine
    case "AudioKit", "AudioKitEngine": .audioKitEngine
    default: nil
    }

    guard let requested,
          availableEngines[requested] == true,
          requested.canHandle(format) else { return nil }
    return requested
}

// First line of selectEngineType(for:configuration:)
if let preferred = preferredEngineType(for: format) { return preferred }
```

- **Verification and acceptance:** Add factory tests for each stored picker value across WAV, AAC, FLAC, and an unsupported format. Acceptance: AV selection returns `.avAudioEngine` for its supported formats; AudioKit selection returns `.audioKitEngine`; incompatible preferences fall back deterministically. Run **R2**.
- **Related:** AUD-SESSION-001, AUD-DSP-001, AUD-TRANSITION-001.

### AUD-ENG-002 — Play requests are not serialized or cancelled

- **Severity:** High
- **Confidence:** Probable
- **Evidence:**
  - `Fonic HiFi/Presentation/Views/Library/TrackRowView.swift:90-103`
    > `audioService.setCurrentTrack(track)`
    > `Task {`
    > `try await audioService.play(track: track)`
    > `audioService.setCurrentTrack(nil)`
  - `Fonic HiFi/Core/Audio/Engine/PlaybackController.swift:75-119`
    > `let info = try await formatDetectionManager.detectFormat(at: track.url)`
    > `try await sessionManager.activateAudioSession()`
    > `let engine = try await engineManager.ensureEngine(for: info)`
    > `try await engine.load(url: audioTrack.url)`
    > `try await engine.play()`
- **Defect and execution path:** Every tap creates an independent unstructured task. `AudioEngineFacade` and `PlaybackController` are MainActor-isolated but reentrant at every `await`; there is no request generation, task handle, cancellation check after suspension, or URL/track identity check before committing queue/UI/engine state. If A is slow to detect and B is tapped next, B may begin playback and then A may resume and replace it. Conversely, A’s late failure handler clears B’s current track and dismisses Now Playing. This is a common rapid-selection race, not merely cosmetic state drift.
- **Remediation:** Give the facade one owned `playRequestTask`/monotonic request ID. Cancel the prior request before a new selection; check cancellation and request identity after format detection, session activation, engine creation, load, and before every state commit. Error cleanup must be conditional on the failing request still owning the UI.
- **Unapplied production code:** Not supplied; safely fixing this spans the facade/controller/UI boundary and engine mutation rollback. A partial local patch would create new stale-state paths.
- **Verification and acceptance:** Add a controllable format-detector stub that suspends A, completes B first, then releases A. Acceptance: only B is loaded/played, A cannot clear B, and cancellation leaves queue, Now Playing, and widget state on B. Run **R3** for repeated physical-device taps.
- **Related:** AUD-TRANSITION-002, AUD-RESET-001, AUD-WIDGET-001.

### AUD-SESSION-001 — Audio-session ownership is split and native load deactivates after activation

- **Severity:** High
- **Confidence:** Probable
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Engine/PlaybackController.swift:75-102`
    > `try await sessionManager.activateAudioSession()`
    > `let engine = try await engineManager.ensureEngine(for: info)`
    > `try await engine.load(url: audioTrack.url)`
  - `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:110-114`
    > `public init(sessionManager: any AudioSessionManaging = AudioSessionManager.shared)`
  - `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:173-180`
    > `public func load(url: URL) async throws {`
    > `    await stop()`
  - `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:282-300`
    > `primaryPlayerNode.stop()`
    > `try await sessionManager.activateSession(false)`
  - `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:217-258`
    > `// Audio session is managed by AudioSessionManager, not here`
    > `activePlayer.play()`
- **Defect and execution path:** The facade/controller owns a newly constructed `AudioSessionManager`, while a factory-created native adapter defaults to the unrelated singleton. The controller activates its manager, then `AVAudioEngineAdapter.load` calls `stop`, which deactivates the singleton session immediately before playback. `play()` assumes someone else owns activation and does not reactivate. At minimum the two managers’ `_isSessionActive` state diverges; on device this can produce silence/activation errors and incorrect recovery. The AudioKit adapter has the opposite imbalance: its `stop()` never deactivates the session, so other apps may not be notified after Fonic stops.
- **Remediation:** Make the controller/facade the sole session owner. Inject the same session service into factory-created engines only for read-only route queries, or remove session activation/deactivation from adapters entirely. Order should be: configure category/preferences → activate once → configure/load engine → play; stop/shutdown should stop engines then deactivate once with `.notifyOthersOnDeactivation`.
- **Unapplied production code:** Not supplied; constructor/factory injection and lifecycle ordering must be changed atomically across both engines.
- **Verification and acceptance:** Unit-test event order with one shared recording session stub. Acceptance for native load: `activate` occurs after any adapter teardown and no adapter deactivation occurs during load. Acceptance for explicit stop: exactly one deactivate. Run **R3**, **R9**.
- **Related:** AUD-ENG-001, AUD-SESSION-002, AUD-RESET-001.

### AUD-FORMAT-001 — M4A container is always reported as ALAC/lossless

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Interfaces/AudioFormat.swift:63-70`
    > `case .mp3, .aac:`
    > `false`
    > `default:`
    > `true`
  - `Fonic HiFi/Core/Audio/Interfaces/AudioFormat.swift:99-108`
    > `case "m4a": return .alac`
  - `Fonic HiFi/Core/Audio/Services/AudioFormatDetectionManager.swift:61-76`
    > `guard let format = AudioFormat.from(url: url) else {`
    > `return try await manager.detectUsingAVAsset(url: url, format: format, fileSize: fileSize)`
- **Defect and execution path:** M4A is a container that commonly carries either AAC or ALAC. Detection fixes the codec to ALAC before reading the stream description and returns that value unchanged. AAC-in-M4A is shown as Apple Lossless, marked lossless, given ALAC bit-depth assumptions, routed/validated as ALAC, and sent to widget quality badges as lossless. This materially invalidates an audiophile app’s format and quality claims.
- **Remediation:** Treat extension as a container hint. After loading `CMAudioFormatDescription`, map `mFormatID`/codec subtype to AAC or ALAC (and reject unknown codecs); use extension only as fallback.
- **Unapplied production patch (requires Apple-SDK symbol verification):**

```swift
private func resolvedFormat(
    streamDescription: UnsafePointer<AudioStreamBasicDescription>?,
    fallback: AudioFormat
) -> AudioFormat {
    guard let formatID = streamDescription?.pointee.mFormatID else { return fallback }
    return switch formatID {
    case kAudioFormatMPEG4AAC, kAudioFormatMPEG4AAC_HE, kAudioFormatMPEG4AAC_HE_V2: .aac
    case kAudioFormatAppleLossless: .alac
    case kAudioFormatLinearPCM: fallback
    default: fallback
    }
}
```

Use the resolved value for `AudioFileInfo.format` and bit-depth estimation.
- **Verification and acceptance:** Add AAC-LC `.m4a`, HE-AAC `.m4a`, and ALAC `.m4a` fixtures. Acceptance: codec, `isLossless`, engine route, displayed quality, and bit-perfect validation use the actual stream codec. Run **R4**.
- **Related:** AUD-FORMAT-002, AUD-BIT-002, AUD-WIDGET-001.

### AUD-FORMAT-002 — Import UI exposes formats the playback detector cannot represent

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Presentation/Views/Import/FileImportView.swift:72-87`
    > `UTType(filenameExtension: "ogg")`
    > `UTType(filenameExtension: "opus")`
    > `UTType(filenameExtension: "wv")`
    > `UTType(filenameExtension: "ape")`
  - `Fonic HiFi/Data/Actors/FileImportProcessor.swift:58-60`
    > `"mp3", "m4a", "aac", "flac", "alac", "wav", "aiff", "aif", "ape", "wv", "ogg", "opus"`
  - `Fonic HiFi/Core/Audio/Services/AudioFormatDetectionManager.swift:61-64`
    > `guard let format = AudioFormat.from(url: url) else {`
    > `throw DetectionError.unknownFormat(url)`
  - `Fonic HiFi/Core/Audio/Interfaces/AudioFormat.swift:11-31`
    > `case mp3`
    > `case ape`
    > `case dsd`
    > `case unknown`
- **Defect and execution path:** OGG, Opus, and WavPack are accepted by the picker/import extension list but have no `AudioFormat` case, so playback detection deterministically throws `unknownFormat`. APE has an enum case but no registered format adapter (`defaultAdapters()` is empty) and neither engine declares support; the factory’s last resort is the native engine. Users can therefore select/import library items that the active playback path cannot route. A broad `.audio` picker type further exposes unsupported codecs.
- **Remediation:** Define one canonical capability registry used by picker, import validation, format detection, and engine selection. Until a decoder and tests exist, remove OGG/Opus/WV/APE from allowed types and reject them before copy/import with a user-facing unsupported-format reason. Do not advertise theoretical enum capabilities as production support.
- **Unapplied production code:** Not supplied; either removal or decoder adoption requires a product decision and fixture/device validation.
- **Verification and acceptance:** Parameterized import-to-play integration tests must cover every exposed extension. Acceptance: every selectable format either reaches audible playback and metadata extraction or is rejected before import with no dead library row. Run **R4**.
- **Related:** AUD-FORMAT-001, AUD-TRANSITION-001.

### AUD-CONFIG-001 — Bit-perfect, buffer, and sample-rate controls do not configure audio

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Presentation/Views/Settings/AudioSettingsView.swift:11-84`
    > `@AppStorage("enableBitPerfectPlayback") private var enableBitPerfectPlayback = false`
    > `@AppStorage("audioBufferSize") private var audioBufferSize = 512.0`
    > `@AppStorage("sampleRate") private var sampleRate = 44100.0`
    > `Toggle("Enable Bit-Perfect Playback", isOn: $enableBitPerfectPlayback)`
    > `Picker("Sample Rate", selection: $sampleRate)`
  - `Fonic HiFi/Core/Audio/Engine/AudioPlaybackSettingsStore.swift:23-42`
    > `if let storedCrossfade = defaults.value.object(forKey: Keys.crossfadeDuration) as? Double {`
    > `if let storedReplayGain = defaults.value.string(forKey: Keys.replayGainMode),`
    > `if let storedRate = defaults.value.object(forKey: Keys.playbackRate) as? Double {`
    > `config = config.with(enableGapless: isGaplessEnabled())`
  - `Fonic HiFi/Core/Audio/Interfaces/AudioEngineConfiguration.swift:49-67`
    > `bufferSize: Int = 512,`
    > `sampleRate: Double? = nil,`
    > `enableBitPerfect: Bool = true,`
- **Defect and execution path:** These controls write unrelated `UserDefaults` keys but have no `onChange` bridge into `AudioEngineFacade`, and the settings store does not read them during initialization. Playback keeps the configuration defaults: bit-perfect enabled internally regardless of the UI toggle, source-rate preference rather than the selected rate, and a 512-frame logical value that neither adapter applies. The UI explicitly promises quality/latency effects that do not occur.
- **Remediation:** Either remove the controls for this release or add validated configuration mutations and persistence keys, with explicit “preferred/requested” wording for sample rate. Read actual route sample rate after activation and surface mismatch. Adapters must apply supported buffer settings or report them unavailable.
- **Unapplied production code:** Not supplied; adding setters without implementing adapter behavior would preserve the deception.
- **Verification and acceptance:** Unit tests must toggle each control, relaunch/merge settings, and inspect the exact engine configuration. Device acceptance must compare selected vs actual session sample rate and I/O buffer duration. Run **R3**, **R5**.
- **Related:** AUD-BIT-002, AUD-DIAG-001, AUD-SESSION-001.

### AUD-BIT-001 — Bit-perfect cache is not keyed by track or route

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Diagnostics/BitPerfectValidator.swift:20-22`
    > `private var lastValidationResult: BitPerfectValidationResult?`
    > `private var lastValidationTimestamp: Date?`
  - `Fonic HiFi/Core/Audio/Diagnostics/BitPerfectValidator.swift:45-61`
    > `if let cachedResult = getCachedValidationResult() {`
    > `return cachedResult`
    > `let result = await validationEngine.validate(`
    > `sourceFormat: sourceFormat`
  - `Fonic HiFi/Core/Audio/Diagnostics/BitPerfectValidator.swift:162-175`
    > `Date().timeIntervalSince(lastTimestamp) < validationCacheTimeout`
    > `return lastResult`
- **Defect and execution path:** The singleton validator is used on play and diagnostic refresh. If a second track or route is validated within five seconds, it receives the first result regardless of URL, sample rate, bit depth, channels, output UID, active session sample rate, volume, or processing state. Fast skips between 44.1/16 and 96/24, or a DAC connect/disconnect, can therefore display the prior track/route as “Bit-perfect.”
- **Remediation:** Key the cache by all validation inputs or remove the five-second cache. Invalidate on route/configuration changes, EQ/replay gain/playback-rate changes, and media-services reset.
- **Unapplied production patch sketch (requires Codable/Hashable choices):**

```swift
private struct ValidationCacheKey: Hashable {
    let sourceURL: URL
    let sourceRate: Int
    let sourceDepth: UInt16
    let sourceChannels: UInt8
    let routeUID: String?
    let activeRate: Int
    let outputVolumeMilli: Int
}

private var cachedValidation: (key: ValidationCacheKey,
                               result: BitPerfectValidationResult,
                               timestamp: Date)?
```

Only return when both key and TTL match.
- **Verification and acceptance:** Inject a fake device/session source; validate A then B within the TTL and change route without advancing time. Acceptance: B and the new route are independently evaluated. Run **R5**.
- **Related:** AUD-BIT-002, AUD-RESET-001.

### AUD-BIT-002 — “Bit-perfect” is asserted without observing the active engine signal path

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Diagnostics/BitPerfectValidationEngine.swift:28-31,141-145`
    > `let deviceCapabilities = await deviceManager.currentCapabilities(using: session)`
    > `let sessionAnalysis = analyzeSession(session)`
    > `let processingDetection = await processingAnalyzer.detectProcessing(in: session)`
    > `let isValid = sampleRateMatches &&`
    > `!processingDetection.hasProcessing`
  - `Fonic HiFi/Core/Audio/Diagnostics/BitPerfectProcessingAnalyzer.swift:38-49`
    > `isOtherAudioPlaying: session.isOtherAudioPlaying,`
    > `outputVolume: session.outputVolume,`
    > `mode: session.mode,`
    > `hasSpatialAudioEnabled: session.currentRoute.outputs.contains(where: \.isSpatialAudioEnabled),`
  - `Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift:18-23,64-67`
    > `private let primaryPlayer = AudioPlayer()`
    > `private let primaryPitch: TimePitch`
    > `private let mixer = Mixer()`
    > `configuration.performanceMode == .quality && abs(currentGainDB) < .ulpOfOne`
  - `Fonic HiFi/Presentation/Views/NowPlaying/DiagnosticsDetailView.swift:24-47`
    > `Text(result.isValid ? "Bit-perfect" : "Issues detected")`
- **Defect and execution path:** The validator cannot see active EQ, AudioKit TimePitch/Mixer processing, AV mixer/submix conversion, app/player volume, replay gain, playback rate, converter format, or whether the engine selected for this track matches the source. Device bit depth/sample-rate support is estimated from port type, not negotiated stream state. Nevertheless the result is rendered as a definitive “Bit-perfect.” This is a false certainty for the product’s core audiophile promise.
- **Remediation:** Rename the current result to a route/configuration compatibility check and never emit definitive bit-perfect status from session heuristics alone. Add an engine-provided immutable signal-path snapshot (source processing format, every node, rate/gain/EQ state, mixer/output format, actual route) and require all stages to prove unity/no conversion. If iOS cannot prove exclusive unmodified delivery, display “compatible / not verified,” not “Bit-perfect.”
- **Unapplied production code:** Not supplied; a boolean patch would perpetuate an unverifiable claim.
- **Verification and acceptance:** Unit tests must force rate ≠ 1, replay gain, EQ, non-unity app volume, source/output mismatch, Bluetooth, and route switch; none may produce definitive bit-perfect. Hardware acceptance requires captured known samples through a supported wired DAC. Run **R5**.
- **Related:** AUD-CONFIG-001, AUD-BIT-001, AUD-DSP-001, AUD-DIAG-001.

### AUD-TRANSITION-001 — Gapless/native crossfade controls do not produce seamless transitions

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Engine/PlaybackController.swift:266-274`
    > `guard engineManager.configuration.enableGapless || engineManager.configuration.crossfadeDuration > 0,`
    > `await engine.prepareNext(url: nextTrack.url)`
  - `Fonic HiFi/Core/Audio/Coordinators/QueueCoordinator.swift:39-55`
    > `if engineManager.configuration.crossfadeDuration > 0,`
    > `try await playbackController.crossfade(to: nextTrack, displayTrack: track)`
    > `try await playbackController.play(track: track, queueEntry: nextTrack)`
  - `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:374-400`
    > `let inactivePlayer = isPrimaryActive ? secondaryPlayerNode : primaryPlayerNode`
    > `inactivePlayer.scheduleFile(file, at: nil) { [weak self] in`
    > `hasNextPrepared = true`
  - `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:67,289-295`
    > `private var isPrimaryActive = true`
    > `preparedFile = nil`
    > `hasNextPrepared = false`
    > `isPrimaryActive = true`
  - `Fonic HiFi/Core/Audio/Interfaces/AudioEngineService.swift:131-137`
    > `func crossfade(to url: URL, duration _: TimeInterval, playbackRate: Double, gainDB: Float) async throws {`
    > `try await load(url: url)`
    > `try await play()`
- **Defect and execution path:** Preparing the inactive native node does not schedule a start time, call `play`, swap active nodes, or promote `preparedFile`. Natural completion calls queue `playNext`; with crossfade off it runs a normal load, which stops players and discards the prepared file, creating a gap. AVAudioEngineAdapter does not override `crossfade`, so selecting a nonzero duration still performs an immediate load/play with no fade. AudioKit’s natural crossfade begins only after its completion poll decides the old track has ended, too late for overlap; its gapless-only path also reloads rather than promotes the prepared player.
- **Remediation:** Implement transitions as an engine state machine. Preload compatible formats, schedule the next node at an exact render/sample time, atomically promote it, and distinguish true gapless from timed crossfade. For incompatible sample-rate/channel changes, explicitly report a non-gapless fallback. Disable unsupported controls per engine until implemented.
- **Unapplied production code:** Not supplied; render-timeline scheduling cannot be safely patched without hardware/audio fixtures.
- **Verification and acceptance:** Use synthesized files with boundary impulses and continuous phase. Capture output; gapless acceptance is no inserted/removed frames beyond the documented tolerance. Crossfade acceptance is measured overlap for the selected duration on automatic and manual transitions, both engines, mixed sample rates, background, and route changes. Run **R6**.
- **Related:** AUD-TRANSITION-002, AUD-ENG-001, AUD-DSP-001.

### AUD-TRANSITION-002 — Cancelling an AudioKit crossfade leaves split playback state

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift:206-237`
    > `inactivePlayer.volume = 0`
    > `inactivePlayer.play()`
    > `crossfadeTask = Task { @MainActor [weak self] in`
  - `Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift:143-158`
    > `crossfadeTask?.cancel()`
    > `activePlayer.pause()`
    > `inactivePlayer.pause()`
  - `Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift:371-386`
    > `guard !Task.isCancelled else { return }`
    > `await finishCrossfade(with: file)`
- **Defect and execution path:** The queue/UI switches to the next track before the fade task completes. If Pause, Stop, another crossfade, or task cancellation occurs mid-fade, the loop returns without restoring volumes or selecting a winner. On Pause, `currentFile` remains the old track, both players retain partial volumes, and Resume starts only `activePlayer` (the old track) while UI/queue/Now Playing show the new track. This is a deterministic cancellation-state defect.
- **Remediation:** Use a transition token and `withTaskCancellationHandler`; cancellation must execute one MainActor-isolated reconciliation path that either rolls back to the old player or commits the new player, normalizes both volumes, updates file/time state, and stops the loser. UI/queue commitment should occur with engine commitment, not before it.
- **Unapplied production code:** Not supplied; the correct policy (rollback vs commit) is a product decision and must update controller state atomically.
- **Verification and acceptance:** Deterministic adapter tests should pause/stop/skip at 25%, 50%, and 75% fade. Acceptance: one player remains authoritative; resumed audio, current file, queue, timer, Now Playing, and volume all identify the same track. Run **R6**.
- **Related:** AUD-ENG-002, AUD-TRANSITION-001.

### AUD-DSP-001 — DSP capability and persistence silently diverge by engine

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Factory/AudioEngineFactory.swift:124-137`
    > `case .balanced:`
    > `return .audioKitEngine`
  - `Fonic HiFi/Core/Audio/Interfaces/AudioEngineService.swift:126-156`
    > `func applyReplayGain(_: Float) async {`
    > `func applyEQ(_: EqualizerConfiguration) async {`
    > `get async { false }`
  - `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:247-263`
    > `if await engine.supportsEQ {`
    > `logger.warning("Current engine does not support EQ")`
    > `public func reapplyEQConfiguration() async {`
  - `Fonic HiFi/Presentation/Views/Settings/EqualizerView.swift:133-153`
    > `configuration = await store.equalizerConfiguration()`
    > `private func applyConfiguration() {`
    > `await audioEngine?.applyEQ(configuration)`
- **Defect and execution path:** The default AudioKit adapter does not override EQ support, so the fully interactive Equalizer UI persists enabled state and shows “DSP Active” while playback remains unchanged. The native adapter supports EQ but inherits the no-op replay-gain implementation, so Replay Gain silently does nothing on that engine. Persisted EQ is never loaded/applied during facade initialization and `reapplyEQConfiguration` has no active call site after engine creation/switch. Users therefore cannot trust DSP state, and switching engines changes sound features without feedback.
- **Remediation:** Add an explicit engine capability model (`supportsEQ`, replay gain, rate, gapless, crossfade) and gate controls/selection. Implement equivalent DSP or clearly disable it. Load the persisted EQ once during facade initialization and apply it after each successful engine creation before playback; if unsupported, expose an actionable UI state rather than a log.
- **Unapplied production code:** Not supplied; applying persisted EQ without capability/UI changes could unexpectedly alter existing users’ output and invalidate bit-perfect mode.
- **Verification and acceptance:** Tests must cover every feature × engine combination, relaunch with enabled EQ, and engine switches. Acceptance: UI state reflects actual processing; unsupported features cannot appear active; output gain/response changes are measured. Run **R2**, **R5**, **R6**.
- **Related:** AUD-ENG-001, AUD-BIT-002, AUD-TRANSITION-001.

### AUD-QUEUE-001 — Queue edits use the wrong absolute index

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Presentation/Views/Queue/QueueView.swift:40-66`
    > `let remaining = audioService?.queueManager.queueState.remainingTracks ?? []`
    > `let actualFrom = fromIndex + 1`
    > `let actualTo = destination + 1`
    > `let actualIndex = index + 1`
- **Defect and execution path:** The visible Up Next list is `tracks[(currentIndex + 1)...]`, but edit callbacks assume the current track is always array index zero. If currentIndex is 4, deleting visible row 0 removes absolute index 1, not 5; moving can reorder history or the current track. This corrupts the live queue after any progression beyond its first item.
- **Remediation:** Convert relative indices using `currentIndex + 1` as the base and implement a queue API that accepts `IndexSet` plus SwiftUI destination semantics atomically. Do not duplicate array-index arithmetic in the view.
- **Unapplied production code:** Not supplied for move because `onMove` destination semantics and `AudioQueueManager.move(from:to:)` do not currently match, especially when moving to the end. A delete-only patch would leave move corruption.
- **Verification and acceptance:** UI/unit tests with currentIndex 0, middle, and last must delete/move first, middle, and final Up Next rows. Acceptance: exact selected IDs move/remove, current track ID is unchanged, and persisted queue matches. Run **R7**.
- **Related:** AUD-RECOVERY-001, AUD-WIDGET-001.

### AUD-QUEUE-002 — Repeat-one also repeats manual Next/Previous

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Coordinators/QueueCoordinator.swift:39-72`
    > `guard let nextTrack = queueManager.next() else {`
    > `guard let previousTrack = queueManager.previous() else {`
  - `Fonic HiFi/Core/Audio/Queue/QueueRepeatMode.swift:124-136,154-164`
    > `case .one:`
    > `return currentIndex // Stay on same track`
- **Defect and execution path:** Repeat-one should affect automatic completion, while explicit user Next/Previous normally remains navigable. Here both automatic completion and manual controls use the same repeat-aware queue operation. With repeat-one enabled, lock-screen, mini-player, full-player, and intent Next/Previous reload the same track indefinitely.
- **Remediation:** Separate automatic advancement from explicit navigation. Pass an `AdvanceReason` or add manual next/previous operations that ignore `.one` but still respect queue bounds/shuffle; completion retains `.one` behavior.
- **Unapplied production code:** Not supplied; the behavior must be changed consistently for queue, remote commands, widget intents, and tests.
- **Verification and acceptance:** Acceptance: natural completion repeats current under `.one`; manual Next/Previous changes track when a neighbor exists; shuffle and repeat-all continue to work. Run **R7**, **R10**.
- **Related:** AUD-REMOTE-001, AUD-WIDGET-001.

### AUD-RECOVERY-001 — Queue resume position is dropped and shuffled order is restored incorrectly

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Queue/AudioQueueManager.swift:572-591`
    > `lastPlaybackPosition: playbackPosition,`
    > `let validatedState = state.validateForPersistence()`
    > `try validatedState.save()`
  - `Fonic HiFi/Core/Audio/Queue/QueueState.swift:392-404`
    > `return QueueState(`
    > `shuffleSequence: validShuffleSequence,`
    > `timestamp: Date(),`
    > `)`
  - `Fonic HiFi/Core/Audio/Queue/AudioQueueManager.swift:610-630`
    > `originalOrder = validatedState.tracks // Store original order`
    > `shuffleMode = validatedState.shuffleMode`
    > `shuffleSequence = savedShuffleSequence`
    > `tracks = shuffledTracks`
- **Defect and execution path:** Every save with a real position constructs the correct value and immediately loses it during validation. The facade’s “restored playback position” path therefore cannot receive a nonzero saved value. For shuffled queues, persistence stores the currently shuffled track array plus an index sequence that was defined against the pre-shuffle original array. Restore declares the shuffled array to be original order, triggers another shuffle in `didSet`, then applies the old sequence again. Order/current index can change across launch and turning shuffle off cannot recover the actual original order.
- **Remediation:** Preserve clamped `lastPlaybackPosition`. Persist canonical original-order track IDs separately from traversal/shuffle order and restore backing fields without invoking mode observers until all state is coherent. Validate sequences as a full permutation mapped by stable IDs, not raw positions after filtering.
- **Unapplied safe local patch for the position loss (compile/test required):**

```swift
return QueueState(
    tracks: validTracks,
    currentIndex: validCurrentIndex,
    shuffleMode: shuffleMode,
    repeatMode: repeatMode,
    hasNext: hasNext,
    hasPrevious: hasPrevious,
    history: history.filter { track in
        FileManager.default.fileExists(atPath: track.url.path)
    },
    shuffleSequence: validShuffleSequence,
    timestamp: Date(),
    lastPlaybackPosition: max(0, lastPlaybackPosition)
)
```

No shuffle patch is supplied because the persisted schema must change.
- **Verification and acceptance:** Round-trip a queue at 87.5 seconds and a deterministic shuffled queue across a new manager. Acceptance: exact track ID/current ID/order/modes/position survive; turning shuffle off restores the canonical order; missing files do not duplicate/drop remaining IDs. Run **R7**, **R9**.
- **Related:** AUD-QUEUE-001, AUD-WIDGET-001.

### AUD-SEEK-001 — Native seek loses absolute offset; A-B loop is coarse and failure-blind

- **Severity:** Medium
- **Confidence:** Probable
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:118-128`
    > `return Double(playerTime.sampleTime) / sampleRate`
  - `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:304-344`
    > `let framePosition = AVAudioFramePosition(time * sampleRate)`
    > `startingFrame: framePosition,`
    > `activePlayer.play()`
  - `Fonic HiFi/Core/Audio/Engine/PlaybackController.swift:276-289`
    > `progressTimer.start(pollInterval: 0.5) { [weak self] in`
    > `if let seekTarget = loopCheckHandler?(time) {`
    > `try? await engine.seek(to: seekTarget)`
- **Defect and execution path:** After a player node is stopped and a segment is scheduled from a nonzero source frame, player-node time is relative to the new schedule. The adapter never adds the seek frame offset, so its next progress poll can reset 120 seconds to near zero. That breaks UI time, Now Playing, restored position, and A-B behavior on the native engine. Independently, A-B can overshoot B by nearly 500 ms and silently disables effective looping when seek fails; this is not sample-accurate section repeat.
- **Remediation:** Track `scheduledStartFrame`/`scheduledStartTime` and derive absolute source time from node time. Reset the offset on full-file load/stop and atomically update it on seek. For A-B, schedule a segment ending at B or use render/sample-time scheduling; propagate failures into playback state/diagnostics.
- **Unapplied production code:** Not supplied; AVAudioPlayerNode timeline semantics and rate changes require Xcode/device validation.
- **Verification and acceptance:** Seek repeatedly at 0%, 25%, 75%, near-end, paused, playing, and non-1× rate. Acceptance: engine/UI/Now Playing remain within one render buffer of target. Loop a known impulse at A/B for 100 cycles with bounded frame error and visible error on failed seek. Run **R7**.
- **Related:** AUD-RECOVERY-001, AUD-REMOTE-001.

### AUD-SESSION-002 — Interruption intent and route-loss safety are not preserved

- **Severity:** High
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Services/AudioSessionManager.swift:368-385`
    > `let shouldResume = interruptionOption == resumeFlag`
  - `Fonic HiFi/Core/Audio/Coordinators/StateCoordinator.swift:170-185`
    > `await facade.pause()`
    > `case let .ended(shouldResume):`
    > `try? await facade.resume()`
  - `Fonic HiFi/Core/Audio/Coordinators/StateCoordinator.swift:190-204`
    > `case .oldDeviceUnavailable:`
    > `logger.info("Output device became unavailable")`
- **Defect and execution path:** The coordinator does not remember whether Fonic was actually playing before the interruption. A paused track can receive `.began`, remain paused, then be started by `.ended(shouldResume: true)`, violating user intent. The option is a bitmask but is compared for exact equality rather than `contains`, so future/additional flags can suppress a valid resume. On headphone/Bluetooth route loss, playback is not paused and can continue through the speaker, creating a common privacy and user-safety failure.
- **Remediation:** Record a per-interruption `wasPlayingBeforeInterruption` flag and resume only when both that flag and `.shouldResume` are true; clear it after handling. Parse options as an OptionSet. On `.oldDeviceUnavailable`, pause immediately when the previous output was private/wired/Bluetooth, then refresh route/sample-rate/bit-perfect state.
- **Unapplied local option parsing patch (compile/test required):**

```swift
let raw = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
let options = AVAudioSession.InterruptionOptions(rawValue: raw)
let shouldResume = options.contains(.shouldResume)
```

State-intent and route changes still require the broader remediation.
- **Verification and acceptance:** Tests: paused-before interruption never auto-starts; playing-before + shouldResume resumes once; playing-before without flag stays paused; combined option bits work. Device acceptance: unplug wired/USB/Bluetooth output during playback and confirm no speaker leakage. Run **R8**.
- **Related:** AUD-SESSION-001, AUD-BIT-001, AUD-RESET-001.

### AUD-REMOTE-001 — Skip commands are enabled but discarded

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Services/AudioSessionManager.swift:243-265`
    > `commandCenter.skipForwardCommand.isEnabled = true`
    > `await self?.delegate?.audioSessionDidReceiveCommand(.skipForward(skipEvent.interval))`
    > `commandCenter.skipBackwardCommand.isEnabled = true`
    > `return .success`
  - `Fonic HiFi/Core/Audio/Coordinators/StateCoordinator.swift:213-227`
    > `case let .seek(time):`
    > `try? await facade.seek(to: time)`
    > `default:`
    > `logger.debug("Unhandled remote command: \(command)")`
- **Defect and execution path:** Control Center/headset/CarPlay can show 15-second skip controls. Tapping them returns success immediately, but the coordinator logs them as unhandled and playback does not move. Other remote commands also return success before their asynchronous operation can fail, so system UI receives false success.
- **Remediation:** Either disable skip commands for music or implement clamped relative seeks. Dynamically enable next/previous/seek based on queue/playback state. Where the MediaPlayer callback cannot await, acknowledge the dispatch separately but record/reflect operation failure in Now Playing/state rather than silently swallowing it.
- **Unapplied command handling patch (compile/test required):**

```swift
case let .skipForward(interval):
    try? await facade.seek(to: min(facade.currentTime + interval, facade.duration))
case let .skipBackward(interval):
    try? await facade.seek(to: max(facade.currentTime - interval, 0))
```

- **Verification and acceptance:** Inject all `RemoteCommand` cases. Acceptance: every enabled command has an observable effect or is disabled; relative seeks clamp safely; Now Playing elapsed time updates. Run **R10**.
- **Related:** AUD-SEEK-001, AUD-QUEUE-002.

### AUD-RESET-001 — Media-services reset does not rebuild invalid audio objects

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Services/AudioSessionManager.swift:359-365`
    > `name: AVAudioSession.mediaServicesWereResetNotification,`
  - `Fonic HiFi/Core/Audio/Services/AudioSessionManager.swift:417-433`
    > `try await self?.configureAudioSession()`
    > `if self?._isSessionActive == true {`
    > `try await self?.activateAudioSession()`
  - `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:654-667`
    > `public func audioSessionDidInterrupt(_ interruption: AudioInterruptionType) async {`
    > `public func audioSessionRouteDidChange(_ change: AudioRouteChange) async {`
    > `public func audioSessionDidReceiveCommand(_ command: RemoteCommand) async {`
- **Defect and execution path:** After media services reset, existing AVAudioEngine/AudioKit audio objects may be invalid and must be recreated/reconnected. The notification is consumed inside the session manager and never reaches the engine manager. The app keeps the stale engine, completion handlers/taps, and state; it does not reload the current file/position, reapply DSP/rate/gain, restore remote commands/Now Playing, or report recovery failure. Reconfiguring only the session cannot restore playback.
- **Remediation:** Add a media-reset delegate event. Snapshot track, position, was-playing, queue, rate/gain/EQ; stop and invalidate the old engine; reconfigure/activate the session; construct a fresh engine; reload/seek/reapply state; rebuild Now Playing/commands; resume only when previously playing. Fail into an actionable error state.
- **Unapplied production code:** Not supplied; recovery must be transactional across session, engine, queue, DSP, and UI.
- **Verification and acceptance:** Unit-test the event with an engine factory that marks old instances unusable. Acceptance: only a new engine is called; paused/playing intent and position are preserved; failure is surfaced. Run **R8** using Apple’s media-services-reset test path on device/simulator where available.
- **Related:** AUD-SESSION-001, AUD-SESSION-002, AUD-BIT-001, AUD-DSP-001.

### AUD-SLEEP-001 — Sleep timer is view-scoped and its fade assumes full volume

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:23-32`
    > `@StateObject private var sleepTimerManager = SleepTimerManager()`
  - `Fonic HiFi/ContentView.swift:70-82`
    > `.fullScreenCover(isPresented: $showingNowPlaying) {`
    > `NowPlayingContent(`
    > `dismiss: { showingNowPlaying = false }`
  - `Fonic HiFi/Core/Services/SleepTimerManager.swift:33-35`
    > `deinit {`
    > `timerTask?.cancel()`
  - `Fonic HiFi/Presentation/Views/NowPlaying/SleepTimerSheet.swift:127-130`
    > `timerManager.start(seconds: seconds, currentVolume: 1.0)`
- **Defect and execution path:** Dismissing Now Playing destroys the owner and cancels an active timer, so the advertised sleep timer does not reliably survive normal navigation. It is also not persisted/reconstructed across process suspension/relaunch. The sheet always tells the fade logic that volume is 1.0; if playback is at 0.2, fade start can jump close to full volume and completion/cancellation restores full volume. The slider’s persisted volume then disagrees with the engine.
- **Remediation:** Own one `SleepTimerManager` at app/audio-facade scope, represent expiry as an absolute `Date`, and inject it into the view. Store/read the engine’s actual app volume, update the shared volume state during fade, and restore only if no user volume change occurred after fade began.
- **Unapplied production code:** Not supplied; moving ownership and reconciling volume changes requires app-level dependency injection.
- **Verification and acceptance:** Set a short timer at 20% volume, dismiss Now Playing, lock/background, change views, and cancel during fade. Acceptance: one timer remains active, no upward volume step occurs, pause fires once at expiry, and user volume intent is preserved. Run **R11**.
- **Related:** AUD-SESSION-001, AUD-WIDGET-001.

### AUD-DIAG-001 — Engine metrics are synthetic while native monitoring overhead is unconditional

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift:240-253`
    > `cpuUsage: 0.0,`
    > `bufferUnderruns: 0,`
    > `bufferFillLevel: 1.0,`
    > `renderLatency: 0.0,`
  - `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:404-417`
    > `decodingLatency: 0.001, // AVAudioEngine has very low latency`
    > `bufferFillLevel: 1.0,`
    > `droppedFrames: 0,`
    > `renderLatency: 0.005,`
  - `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:561-582`
    > `engine.mainMixerNode.installTap(`
    > `guard buffer.frameLength == 0 else { return }`
    > `await tracker.increment()`
  - `Fonic HiFi/Presentation/Views/NowPlaying/DiagnosticsDetailView.swift:95-113`
    > `LabeledContent("CPU") {`
    > `LabeledContent("Buffer Underruns") {`
    > `LabeledContent("Render Latency") {`
- **Defect and execution path:** The default AudioKit engine can report perfect zero errors/latency without measurement. The native engine displays fixed latency/fill/drop values and equates a zero-frame tap callback with underrun, which is not a reliable underrun detector. These values feed diagnostics, scores, alerts, and exports as facts. Meanwhile the native output tap runs on every render even though broader runtime monitoring defaults off in Release; the tap’s diagnostic value is not established.
- **Remediation:** Mark unavailable fields as optional/unsupported, not zero. Populate only from measured timestamps/render callbacks/session latency or remove the field. Gate taps behind the runtime-monitoring setting and remove them atomically when disabled; keep the realtime block allocation/lock free. Never derive quality/reliability scores from placeholders.
- **Unapplied production code:** Not supplied; metric semantics and realtime-safe collection need a measured design.
- **Verification and acceptance:** Engine contract tests must distinguish unavailable from measured zero. Inject underrun/error signals and ensure counters change. Instruments acceptance: compare CPU/wakeups/audio glitches with diagnostics off/on and prove bounded overhead. Run **R13**.
- **Related:** AUD-BIT-002, AUD-CONFIG-001.

### AUD-WIDGET-001 — Widget time and queue modes become stale while the app polls forever

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Services/WidgetDataCoordinator.swift:71-93`
    > `while !Task.isCancelled {`
    > `let currentId = state.currentTrack?.id`
    > `let currentCount = state.tracks.count`
    > `try? await Task.sleep(for: .milliseconds(500))`
  - `Fonic HiFi/Shared/AppGroupManager.swift:50-64`
    > `abs(last.duration - state.duration) < 0.1 {`
    > `// Only time changed - skip write for efficiency`
    > `return`
  - `Fonic HiFi Widget/Views/MediumWidgetView.swift:81-105`
    > `.frame(width: geometry.size.width * CGFloat(entry.progress))`
    > `Text(formatTime(entry.playbackState.currentTime))`
  - `Fonic HiFi/Core/Services/WidgetDataCoordinator.swift:184-203`
    > `playbackRate: state.isPlaying ? 1.0 : 0.0`
- **Defect and execution path:** Playback-state updates occur, but `AppGroupManager` intentionally discards elapsed-time-only changes. Widget views do not interpolate from timestamp/rate or use a timer-range view, so their progress/time remain frozen at the last meaningful state even when the timeline reloads. Queue polling misses shuffle/repeat changes because it compares only track ID/count; direct in-app mode toggles do not call full widget sync. Polling on MainActor twice per second continues while idle and is still insufficient for correctness. Non-1× playback would be wrong even with interpolation because 1.0 is exported.
- **Remediation:** Replace polling with explicit queue mutation/state publishers or coordinator callbacks. Persist timestamp plus actual playback rate and derive effective elapsed time in widget entries, bounded by duration; use supported timer/progress rendering and a budget-conscious timeline. Sync shuffle/repeat immediately on mutation.
- **Unapplied production code:** Not supplied; WidgetKit timeline/interpolation and queue observation should be revised together.
- **Verification and acceptance:** Tests should inject a clock, advance 60 seconds at 0.5×/1×/2×, and assert bounded progress. Toggle shuffle/repeat without changing track/count and assert App Group update/reload. Measure idle wakeups. Run **R12**, **R13**.
- **Related:** AUD-QUEUE-001, AUD-QUEUE-002, AUD-RECOVERY-001, AUD-SLEEP-001.

---

## Rejected candidate findings

These candidates were investigated but not retained because active source disproved them or static evidence was insufficient.

| Candidate | Disposition and active evidence |
|---|---|
| Background audio capability is missing | **Rejected.** `Fonic HiFi/Info.plist:7-10` declares `UIBackgroundModes/audio`; `AudioSessionManager.swift:74-84` configures `.playback`. Device endurance still belongs in R9. |
| Runtime diagnostics polling is always enabled in Release | **Rejected as stated.** `AudioEngineFacade.swift:119-127` defaults it to false outside DEBUG. AUD-DIAG-001 is narrower: the native render tap is still unconditional and data semantics are invalid. |
| Now Playing metadata is absent | **Rejected.** `PlaybackController.swift:308-327` writes title/artist/album/duration/elapsed/rate/artwork through the session manager, and pause writes rate zero. Staleness/remote behavior remains in R10. |
| FLAC is categorically unsupported | **Rejected.** Active routing detects `.flac`, selects AudioKit by default, and opens through `AVAudioFile`. Static Linux inspection cannot establish the actual OS/fixture support matrix; validate in R4 rather than claim failure. |
| AudioKit EQ has a hidden implementation elsewhere | **Rejected after active-source search.** The adapter has no `applyEQ`/`supportsEQ` override; AUD-DSP-001 is retained from the protocol default and active call path. |
| Widget button intent stubs definitely execute instead of main-app implementations | **Not retained.** `Fonic HiFi Widget/Intents/WidgetIntents.swift:15-67` contains no-op `perform()` bodies while the app target has same-named implementations. Module/intent dispatch behavior must be proven with generated AppIntents metadata and device invocation; see R12. If the extension body executes, this becomes a High widget-control defect. |
| A separate missing `MPNowPlayingInfoCenter.playbackState` assignment is necessarily a bug | **Not retained.** The app supplies elapsed time and playback rate, which is a valid Now Playing state path; device/control-center behavior is required before asserting an additional property requirement. |

## Open build/device/runtime checks

All checks below are **UNVERIFIED — needs build/device check**. They are intentionally separate from static findings.

1. **R1 — Build gate:** Open the exact commit in Xcode 26 with iOS 26 SDK. Clean-build app/widget/tests under Release and Debug with Swift 6 complete concurrency; run the complete unit/UI suite. No success is claimed here.
2. **R2 — Engine selection/switch:** Log selected engine type from a non-sensitive identifier. Test both picker values with MP3, AAC, ALAC, WAV, AIFF, and FLAC while stopped, paused, and playing; verify deferred switching, feature capabilities, state, volume, rate, and Now Playing.
3. **R3 — Session activation/order:** On device, test first play, rapid track changes, stop/resume, repeated native loads, other-audio handoff, and AudioKit/native switches. Capture AVAudioSession category/route/sample-rate/active errors without filenames or personal route names.
4. **R4 — Format/FLAC/lossless matrix:** Use known fixtures: AAC-LC/HE-AAC/ALAC M4A, MP3, WAV/AIFF PCM variants, FLAC 16/24/32-bit and 44.1–192 kHz, mono/stereo/multichannel, malformed/truncated files, plus every exposed import extension. Verify metadata, import, route, duration, seek, playback, and explicit rejection.
5. **R5 — Bit-perfect/DSP:** With a documented wired USB DAC, compare source vs actual negotiated session/engine formats and captured output where possible. Exercise system/app volume, rate, replay gain, EQ, Bluetooth/AirPlay, route changes, and mixed-rate queue. Acceptance wording must remain “unverified” unless the full path is proven.
6. **R6 — Gapless/crossfade/cancellation:** Capture two synthesized continuous/impulse files across both engines. Measure frame discontinuity and overlap; pause/skip/stop at multiple points during crossfade; test background/lock and mixed sample rates.
7. **R7 — Queue/seek/A-B:** Exercise middle-index queue edits, every repeat/shuffle combination, relaunch restore, missing files, manual vs automatic advance, native seek at rate changes, and 100-cycle A-B loop boundary accuracy.
8. **R8 — Interruptions/routes/reset:** Test phone call, Siri, alarm, app suspension, AirPods/Bluetooth/wired/USB unplug, route sample-rate change, and media-services reset. Verify prior play intent, no speaker leakage, fresh engine reconstruction, and error recovery.
9. **R9 — Background endurance/recovery:** Play local lossless queues for at least 30 minutes with screen locked and app backgrounded; verify auto-advance, saved position, memory/energy, other-audio handoff, termination/relaunch, and no unsupported background work.
10. **R10 — Remote commands/Now Playing:** Validate lock screen, Control Center, wired/Bluetooth controls, and CarPlay where supported: command availability/results, next/previous under repeat-one, relative/absolute seek, metadata/artwork/rate/elapsed updates, and queue end.
11. **R11 — Sleep timer:** Start at low volume, dismiss full-screen player, background/lock, change volume during fade, cancel mid-fade, and let expire. Verify no volume jump, one pause, persistence/lifetime, and correct UI state.
12. **R12 — Widget/App Intents:** Inspect generated AppIntents metadata for app and extension and tap every widget control while foregrounded, backgrounded, suspended, and terminated. Verify which `perform()` executes, state synchronization, queue modes, non-1× progress, timeline budget, and graceful unavailable-app behavior.
13. **R13 — Diagnostics overhead:** Instruments Time Profiler, Energy Log, System Trace, and audio captures with diagnostics/tap off/on. Verify realtime callback safety, wakeups, memory growth, metric truthfulness, and zero audible regression.
