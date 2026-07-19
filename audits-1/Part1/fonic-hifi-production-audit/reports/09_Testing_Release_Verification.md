# Test and Release Verification Audit

## Conclusion

**Release verification is not trustworthy yet.** The repository contains substantial static test surface—**91 unit/integration test source files plus 3 support files, 451 unit-test declarations (397 XCTest methods and 54 Swift Testing `@Test`s), and 3 UI-test methods**—but names and counts are not proof of exercised production behavior. Static inspection found a CI/Xcode configuration contradiction that prevents the declared iOS 26 lane from being a credible gate, no versioned shared scheme/test plan, unit/UI aliases that run the same undifferentiated command, **26 conditional `XCTSkip` call sites**, **28 real-time `Task.sleep` call sites**, vacuous audio assertions, fake “integration” fixtures that are not audio, all SwiftData tests using in-memory stores, no real V1→V2 store migration, and no accessibility/device-audio release matrix.

The existing tests provide useful logic-level coverage for queue models, metadata plumbing, cache behavior, and collaborators. They do **not** prove decoding, audible playback, gaplessness, crossfade/EQ signal behavior, audio-session interruption recovery, route/remote-command behavior, persistent-store migration, production initialization, large on-disk libraries, or accessibility on supported configurations.

**Execution boundary:** this Linux audit environment has no Xcode or Apple SDKs. I did **not** run, compile, sign, archive, launch, or measure these tests, and I do not claim that any test currently passes. Counts below are static source counts only.

### Findings count

| Severity | Count |
|---|---:|
| Critical | 0 |
| High | 1 |
| Medium | 12 |
| Low | 0 |
| Informational | 3 |
| **Total** | **16** |

## Static inventory

| Item | Static result |
|---|---:|
| Unit-target Swift files | 94 (91 test sources + 3 support sources) |
| XCTest unit methods | 397 |
| Swift Testing `@Test` declarations | 54 |
| UI test methods | 3 |
| Assertion tokens (`XCTAssert`, `XCTFail`, `XCTUnwrap`, `#expect`, `#require`) | 1,519 |
| Conditional `XCTSkip` call sites | 26 across 9 files |
| Real-time `Task.sleep` call sites in unit/support tests | 28 |
| `XCTAssertTrue(true, ...)` call sites | 4 |
| Checked-in `.xctestplan` files | 0 |
| Checked-in shared `.xcscheme` files | 0 |
| Checked-in `.xcresult` bundles/current raw coverage JSON | 0 |
| SwiftData test configurations with `isStoredInMemoryOnly: true` | 13 |
| SwiftData test configurations with `isStoredInMemoryOnly: false` | 0 |

## Findings table

| ID | Severity | Confidence | Summary |
|---|---|---|---|
| TRV-001 | High | Confirmed by static evidence | CI selects Xcode 16.1 while the build requires iOS 26.2, and the Makefile overrides `xcode-select` anyway |
| TRV-002 | Medium | Confirmed by static evidence | The test action is not versioned in a shared scheme or test plan |
| TRV-003 | Medium | Confirmed by static evidence | `test-unit` and `test-ui` are aliases of the same command and cannot prove either target executed |
| TRV-004 | Medium | Confirmed by static evidence | UI smoke tests convert missing core UI into skips/optional taps and omit postconditions |
| TRV-005 | Medium | Confirmed by static evidence | Audio/EQ tests contain vacuous assertions and accept any error instead of the required failure |
| TRV-006 | Medium | Confirmed by static evidence | The import→playback “integration” path uses invalid fake FLAC bytes, fake metadata, and a test-only playback pipeline |
| TRV-007 | Informational | UNVERIFIED — needs build/device check | Natural completion, auto-advance, gapless boundaries, and real crossfade output have no end-to-end test |
| TRV-008 | Medium | Confirmed by static evidence | Real sleeps and wall-clock polling make async/timer tests slow and scheduler-sensitive |
| TRV-009 | Medium | Probable | Tests share production `UserDefaults`, App Group state, singletons, and even delete the host sandbox Music directory |
| TRV-010 | Medium | Confirmed by static evidence | Persistence tests never open an on-disk store; the migration test does not perform V1→V2 migration |
| TRV-011 | Medium | Confirmed by static evidence | “High-volume” and performance tests use synthetic in-memory workloads and one-shot wall-clock thresholds |
| TRV-012 | Informational | UNVERIFIED — needs build/device check | Accessibility has no audit, VoiceOver interaction, Dynamic Type, Reduce Motion, localization, or device-size test matrix |
| TRV-013 | Informational | Confirmed by static evidence | Coverage enforcement is coarse, omits the widget/critical-path thresholds, and has no current repository evidence |
| TRV-014 | Medium | Confirmed by static evidence | CI does not build/archive the Release configuration or run analysis/sanitizer/release-validation gates |
| TRV-015 | Medium | Confirmed by static evidence | CI treats conditional skips as success; capability-dependent suites can disappear without failing release |
| TRV-016 | Medium | UNVERIFIED — needs build/device check | No physical-device audio acceptance lane exists for routes, interruptions, background playback, remote controls, or bit-perfect claims |

---

## Full findings

### TRV-001 — CI toolchain selection cannot satisfy the declared iOS 26 build

- **Severity:** High
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `.github/workflows/ci.yml:9-17`
    > `runs-on: macos-15`
    > `- name: Select Xcode 16.1`
    > `run: sudo xcode-select -s /Applications/Xcode_16.1.app`
  - `Makefile:12-18,32-34`
    > `SDK = iphonesimulator26.0`
    > `SIMULATOR_OS = 26.2`
    > `export DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer`
  - `Fonic HiFi.xcodeproj/project.pbxproj:600-618,664-683`
    > `IPHONEOS_DEPLOYMENT_TARGET = 26.0;`
    > `SWIFT_VERSION = 6.0;`
- **Why this is defective/risky:** Xcode 16.1 cannot provide the iOS 26.0 SDK or iOS 26.2 simulator requested by the Makefile. In addition, GNU Make exports `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, so the workflow's `xcode-select` step does not reliably select `/Applications/Xcode_16.1.app` for `make`. The gate can fail before tests start or silently use a different Xcode than the workflow claims. Nothing about production compilation or tests is verified while this contradiction exists.
- **Remediation:** Pin one installed Xcode 26.x toolchain, derive the simulator destination from installed runtimes, and fail immediately if the selected SDK/runtime is absent. Do not hard-code a conflicting `DEVELOPER_DIR` in the Makefile.
- **Paste-ready sample (runner label/path must be matched to the actual CI fleet):**

```yaml
jobs:
  build-and-test:
    runs-on: [self-hosted, macOS, arm64, xcode-26-2]
    env:
      DEVELOPER_DIR: /Applications/Xcode_26.2.app/Contents/Developer
    steps:
      - uses: actions/checkout@v4
      - name: Verify Apple toolchain
        shell: bash
        run: |
          set -euo pipefail
          xcodebuild -version
          test "$(xcrun --sdk iphonesimulator --show-sdk-version)" = "26.2"
          xcrun simctl list devices available | grep -F "iPhone 17 Pro"
      - name: Test
        run: make test DEVELOPER_DIR="$DEVELOPER_DIR"
```

Remove `export DEVELOPER_DIR := ...` from `Makefile`, or change it to an overridable default such as `DEVELOPER_DIR ?= ...` and export that value. This sample requires validation on the chosen Xcode runner.
- **Verification / acceptance criteria:**
  1. A clean runner prints exactly the intended Xcode and iOS Simulator SDK versions.
  2. The requested simulator exists before `xcodebuild` starts.
  3. `xcodebuild -showBuildSettings` reports `SDKROOT=iphonesimulator26.2` (or the intentionally selected compatible 26.x SDK).
  4. A clean checkout reaches test execution without an SDK/destination error.
- **Related:** TRV-002, TRV-003, TRV-014.

### TRV-002 — No shared scheme or test plan defines the release test action

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Makefile:245-255`
    > `xcodebuild test ... -scheme "$(SCHEME)" ... -enableCodeCoverage YES`
  - `Fonic HiFi.xcodeproj/xcuserdata/keiran.xcuserdatad/xcschemes/xcschememanagement.plist:5-21`
    > `<key>SchemeUserState</key>`
    > `<key>Fonic HiFi.xcscheme_^#shared#^_</key>`
  - `Fonic HiFi.xcodeproj/project.pbxproj:194-234` confirms both test targets exist, but the repository contains no `Fonic HiFi.xcodeproj/xcshareddata/xcschemes/*.xcscheme` and no `.xctestplan`.
- **Why this is defective/risky:** The command assumes an autogenerated `Fonic HiFi` scheme. A clean CI checkout has no versioned TestAction specifying unit/UI targets, configurations, language/region, parallelization, repetition, sanitizer options, launch arguments, or coverage targets. Local user metadata naming a scheme is not a portable TestAction. It remains unverified whether both test targets are included on a fresh runner.
- **Remediation:** Commit a shared scheme and a test plan. Make the plan explicitly list `Fonic HiFiTests` and `Fonic HiFiUITests`, enable app/widget coverage intentionally, and define deterministic configurations.
- **Production-quality test-plan skeleton:**

```json
{
  "configurations": [
    {
      "id": "A1111111-1111-1111-1111-111111111111",
      "name": "Default",
      "options": {
        "language": "en",
        "region": "US"
      }
    },
    {
      "id": "A2222222-2222-2222-2222-222222222222",
      "name": "Accessibility XXL",
      "options": {
        "environmentVariableEntries": [
          {
            "key": "UITEST_ACCESSIBILITY_XXL",
            "value": "1",
            "enabled": true
          }
        ]
      }
    }
  ],
  "defaultOptions": {
    "codeCoverage": true,
    "targetForVariableExpansion": {
      "containerPath": "container:Fonic HiFi.xcodeproj",
      "identifier": "38D04CDC2DE570D80047CB93",
      "name": "Fonic HiFi"
    }
  },
  "testTargets": [
    {
      "target": {
        "containerPath": "container:Fonic HiFi.xcodeproj",
        "identifier": "38D04D142DE571000047CB93",
        "name": "Fonic HiFiTests"
      }
    },
    {
      "target": {
        "containerPath": "container:Fonic HiFi.xcodeproj",
        "identifier": "38D04E052DE571500047CB93",
        "name": "Fonic HiFiUITests"
      }
    }
  ],
  "version": 1
}
```

Create this through Xcode 26, attach it to a shared `Fonic HiFi.xcscheme`, and review the generated schema before committing.
- **Verification / acceptance criteria:**
  1. `xcodebuild -list -json -project "Fonic HiFi.xcodeproj"` lists the shared scheme on a clean checkout.
  2. `xcodebuild test -scheme "Fonic HiFi" -testPlan "Fonic HiFi" ...` reports non-zero executed counts for both targets.
  3. No test selection depends on `xcuserdata`.
- **Related:** TRV-001, TRV-003, TRV-015.

### TRV-003 — Unit and UI commands are indistinguishable aliases

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:** `Makefile:244-271`
  > `test: ... xcodebuild test ... -scheme "$(SCHEME)"`
  > `test-unit: ... @$(MAKE) test`
  > `test-ui: ... @$(MAKE) test`
- **Why this is defective/risky:** Neither alias selects a target. A green `make test-unit` does not prove unit tests ran, and a green `make test-ui` does not prove the UI target launched. The single CI invocation cannot provide target-specific counts, retries, timeouts, artifacts, or failure ownership.
- **Remediation:** Run and archive the two targets separately, then have `test` depend on both. Fail if either result bundle has zero executed tests.
- **Paste-ready Makefile sample:**

```make
UNIT_RESULT_BUNDLE = $(BUILD_DIR)/UnitTests.xcresult
UI_RESULT_BUNDLE = $(BUILD_DIR)/UITests.xcresult

.PHONY: test test-unit test-ui
test: test-unit test-ui

test-unit: check-deps
	@rm -rf "$(UNIT_RESULT_BUNDLE)"
	@set -o pipefail && $(XCODEBUILD) test \
		-project "$(PROJECT_NAME).xcodeproj" \
		-scheme "$(SCHEME)" \
		-testPlan "Fonic HiFi" \
		-destination "$(DESTINATION)" \
		-only-testing:"Fonic HiFiTests" \
		-resultBundlePath "$(UNIT_RESULT_BUNDLE)" \
		-enableCodeCoverage YES | $(XCBEAUTIFY)

test-ui: check-deps
	@rm -rf "$(UI_RESULT_BUNDLE)"
	@set -o pipefail && $(XCODEBUILD) test \
		-project "$(PROJECT_NAME).xcodeproj" \
		-scheme "$(SCHEME)" \
		-testPlan "Fonic HiFi" \
		-destination "$(DESTINATION)" \
		-only-testing:"Fonic HiFiUITests" \
		-resultBundlePath "$(UI_RESULT_BUNDLE)" | $(XCBEAUTIFY)
```

Validate `-testPlan`/`-only-testing` syntax with the committed Xcode 26 scheme.
- **Verification / acceptance criteria:** Unit and UI result bundles each contain at least one executed test, target-specific summaries are uploaded, and either zero count fails CI.
- **Related:** TRV-002, TRV-004, TRV-015.

### TRV-004 — UI smoke tests skip or ignore missing core behavior

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:** `Fonic HiFiUITests/LibraryNowPlayingSmokeTests.swift:28-45,64-84,87-117`
  > `guard miniPlayer.waitForExistence(timeout: 5) else { throw XCTSkip("Mini player not visible") }`
  > `if audioEngineRow.waitForExistence(timeout: 5) { ... }`
  > `searchField.typeText("test\n")`
  > `if control.waitForExistence(timeout: 3) { control.tap() }`
- **Why this is defective/risky:** Missing Mini Player/Now Playing UI—the principal playback surface—becomes a passing skip. The Settings row and every Now Playing control may be absent without failure. Search typing has no result/empty/error assertion. Tapping controls has no state postcondition. Two of three UI methods can skip their playback portion, and the third can finish after typing text. These tests prove little beyond basic navigation.
- **Remediation:** Seed a deterministic current track in the UI-test launch mode, add stable accessibility identifiers, require core elements, and assert observable state transitions after every action.
- **Production-quality sample:**

```swift
// Production views
LiquidGlassMiniPlayer(namespace: miniPlayerNamespace)
    .accessibilityIdentifier("player.mini")

Button(action: playNext) { Image(systemName: "forward.fill") }
    .accessibilityIdentifier("player.next")

Text(audioService?.currentTrack?.title ?? "Not Playing")
    .accessibilityIdentifier("player.title")

// UI test
func testNextTrackChangesDisplayedTrack() {
    let app = launchPreviewApp()
    let miniPlayer = app.otherElements["player.mini"]
    XCTAssertTrue(miniPlayer.waitForExistence(timeout: 5), "Seeded mini player is required")
    miniPlayer.tap()

    let title = app.staticTexts["player.title"]
    let next = app.buttons["player.next"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    XCTAssertTrue(next.isHittable)

    let before = title.label
    next.tap()
    let changed = NSPredicate(format: "label != %@", before)
    expectation(for: changed, evaluatedWith: title)
    waitForExpectations(timeout: 5)
}
```

The preview service must seed at least two real model tracks and a deterministic playback facade/test engine; do not skip when that contract fails.
- **Verification / acceptance criteria:**
  1. All three UI tests execute without skips on the designated simulator.
  2. Missing Mini Player, Settings destination, queue/control, or search result causes failure.
  3. Play/pause, next/previous, shuffle, repeat, seek, queue presentation, and search each have a postcondition.
  4. Identifiers—not localized labels—drive element lookup.
- **Related:** TRV-003, TRV-012, TRV-015.

### TRV-005 — Audio tests contain test theater and over-broad error assertions

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFiTests/AVAudioEngineAdapterTests.swift:197-224,240-260`
    > `// The real verification is that frequency/bandwidth ARE applied`
    > `XCTAssertTrue(true, "Shelf filters should be used ...")`
    > `XCTAssertTrue(adapter.isEQEnabled)`
  - `Fonic HiFiTests/AudioKitEngineAdapterTests.swift:69-83`
    > `// verify no crash`
    > `XCTAssertTrue(true, "prepareNext completed without error")`
  - `Fonic HiFiTests/AVAudioEngineAdapterTests.swift:64-94`
    > `catch { // Expected path }`
- **Why this is defective/risky:** `XCTAssertTrue(true)` cannot fail. EQ tests assert a Boolean state flag rather than AVAudioUnitEQ frequency, bandwidth, filter type, preamp gain, graph bypass, or rendered signal. Seek tests accept any thrown error, including an unrelated engine/configuration failure. Therefore these names do not verify production DSP or error contracts.
- **Remediation:** Expose a read-only test snapshot of configured DSP state, render deterministic PCM offline for transfer-function assertions, and assert exact `AudioError` cases.
- **Production-quality samples:**

```swift
// Internal read-only diagnostic seam in AVAudioEngineAdapter
struct EQBandSnapshot: Equatable {
    let frequency: Float
    let bandwidth: Float
    let gain: Float
    let filterType: AVAudioUnitEQFilterType
    let bypass: Bool
}

func eqSnapshotForTesting() -> [EQBandSnapshot] {
    eqNode.bands.map {
        EQBandSnapshot(
            frequency: $0.frequency,
            bandwidth: $0.bandwidth,
            gain: $0.gain,
            filterType: $0.filterType,
            bypass: $0.bypass
        )
    }
}

func testEQAppliesBandParametersAndPreamp() async {
    let adapter = AVAudioEngineAdapter()
    var config = EqualizerConfiguration.default
    config.bands[5] = EQBand(frequency: 1_500, gain: 6, bandwidth: 0.5)
    config.isEnabled = true

    await adapter.applyEQ(config)

    let band = adapter.eqSnapshotForTesting()[5]
    XCTAssertEqual(band.frequency, 1_500, accuracy: 0.1)
    XCTAssertEqual(band.bandwidth, 0.5, accuracy: 0.001)
    XCTAssertEqual(band.gain, 6, accuracy: 0.001)
    XCTAssertFalse(band.bypass)
}

func testNegativeSeekThrowsExactError() async throws {
    let url = try makePCMTestAudioFile(testCase: self)
    let adapter = AVAudioEngineAdapter()
    try await adapter.load(url: url)

    do {
        try await adapter.seek(to: -1)
        XCTFail("Expected invalidSeekPosition")
    } catch let error as AudioError {
        XCTAssertEqual(error, .invalidSeekPosition(-1))
    } catch {
        XCTFail("Unexpected error type: \(error)")
    }
}
```

The snapshot seam and AVFoundation enum types must be compiled under Xcode 26. Add an offline-render test that compares measured gain at each EQ center frequency to the requested response; state inspection alone still does not prove signal output.
- **Verification / acceptance criteria:** No unconditional assertions remain; every failure test checks the exact case/payload; EQ tests fail when frequency, bandwidth, shelf type, gain, preamp, or bypass wiring is intentionally mutated.
- **Related:** TRV-006, TRV-007, TRV-016.

### TRV-006 — “Integration” playback uses fake bytes, fake metadata, and a test-only controller

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFiTests/Support/ImportTestFixtures.swift:40-64,145-165`
    > `let url = ... "track\(index).flac"`
    > `let data = Data(repeating: ..., count: byteCount)`
    > `TestMetadataExtractor ... audioFormat: "FLAC", duration: 180, sampleRate: 96_000`
  - `Fonic HiFiTests/ImportPlaybackIntegrationTests.swift:37-64,69-112,115-164`
    > `let engine = TestAudioEngineService()`
    > `let pipeline = TestPlaybackPipeline(...)`
    > `try await engine.load(url: current.url)`
    > `playInvocations += 1`
- **Why this is defective/risky:** The `.flac` files are arbitrary repeated bytes and cannot be decoded as FLAC. Metadata is fabricated independently of file contents. `TestPlaybackPipeline` is not a production type and `TestAudioEngineService.load` only appends a URL. The test proves its own fake increments counters; it does not exercise `MetadataExtractionService`, `AudioFormatDetectionManager`, `AudioEngineFacade`, `PlaybackController`, `AudioEngineFactory`, AudioKit/AVAudioEngine decoding, audio-session activation, or audible output.
- **Remediation:** Commit a small legally distributable audio corpus and execute the production import and playback graph. Keep pure unit fakes, but do not label the fake-only test as end-to-end integration.
- **Production-quality fixture/test sample:**

```swift
private func audioFixture(_ name: String, ext: String) throws -> URL {
    try XCTUnwrap(
        Bundle(for: Self.self).url(
            forResource: name,
            withExtension: ext,
            subdirectory: "AudioFixtures"
        )
    )
}

func testRealFLACImportsMetadataAndLoadsNativeEngine() async throws {
    let source = try audioFixture("stereo-sine-24bit-96k", ext: "flac")
    let detector = AudioFormatDetectionManager()
    let extractor = MetadataExtractionService(formatDetectionService: detector)
    let metadata = try await extractor.extractTrackMetadata(from: source)

    XCTAssertEqual(metadata.audioFormat, AudioFormat.flac.rawValue)
    XCTAssertEqual(metadata.sampleRate, 96_000, accuracy: 1)
    XCTAssertEqual(metadata.bitDepth, 24)
    XCTAssertEqual(metadata.channels, 2)

    let adapter = AVAudioEngineAdapter()
    try await adapter.load(url: source)
    XCTAssertEqual(await adapter.audioFormat, .flac)
    XCTAssertGreaterThan(await adapter.duration, 0)
}
```

Resource membership and async actor access require Xcode 26 compilation. Add FLAC, ALAC/M4A, WAV/AIFF, MP3/AAC, mono, 24/96, 24/192, tagged artwork/ReplayGain, truncated/corrupt, zero-length, and unsupported fixtures with provenance documented.
- **Verification / acceptance criteria:**
  1. Mutating fixture bytes to corrupt data makes the appropriate test fail with a decoding error.
  2. Metadata assertions derive from file contents, not a stub.
  3. A simulator integration lane loads each supported fixture through the selected production adapter.
  4. A physical-device lane proves actual playback separately (TRV-016).
- **Related:** TRV-005, TRV-007, TRV-010, TRV-016.

### TRV-007 — Natural completion/gapless/crossfade output remains unverified

- **Severity:** Informational
- **Confidence:** UNVERIFIED — needs build/device check
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Engine/PlaybackController.swift:102-120,266-305,330-342`
    > `engine.setCompletionHandler { ... handleTrackCompletion() }`
    > `await engine.prepareNext(url: nextTrack.url)`
    > `await onTrackComplete()`
  - `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:167-186`
    > `playbackController.onTrackComplete = ... try await self.queueCoordinator.playNext()`
  - `Fonic HiFiTests/PlaybackControllerTests.swift:9-133,362-436` covers pause, stop, seek, crossfade call arguments, and sample-rate ordering, but its engine stub does not capture/invoke a completion handler.
- **Why this is risky / remains unverified:** Production auto-advance crosses engine callback → main actor → facade → queue coordinator → next load/play. No test invokes that callback. Existing crossfade tests assert method arguments, not overlapping signal, timing, track identity after completion, completion races, final-track repeat modes, or a gap duration. A gapless product claim requires signal/device evidence, not a prepared-URL counter.
- **Remediation:** Add completion injection to the engine spy, an integration test through `AudioEngineFacade`, offline waveform boundary analysis, and a device acceptance test.
- **Production-quality logic test sample:**

```swift
@MainActor
private final class CompletionEngineSpy: AudioEngineService {
    private var completion: (() -> Void)?
    private(set) var loaded: [URL] = []
    private(set) var playCount = 0
    // Implement the remaining protocol members with deterministic state.

    func setCompletionHandler(_ handler: @escaping () -> Void) { completion = handler }
    func load(url: URL) async throws { loaded.append(url) }
    func play() async throws { playCount += 1 }
    func finishNaturally() { completion?() }
}

@Test @MainActor
func naturalCompletionAdvancesExactlyOnce() async throws {
    let harness = makeFacadeHarness(engine: CompletionEngineSpy(), queueCount: 2)
    try await harness.facade.play(track: harness.tracks[0])

    harness.engine.finishNaturally()
    await fulfillment(of: [harness.secondTrackStarted], timeout: 1)

    #expect(harness.engine.loaded == [harness.tracks[0].url, harness.tracks[1].url])
    #expect(harness.engine.playCount == 2)
    #expect(harness.facade.currentTrack?.id == harness.tracks[1].id)
}
```

Use an explicit confirmation/expectation rather than a sleep. The harness must inject the production facade/controller/coordinator, not reimplement them.
- **Verification / acceptance criteria:** exact-once auto-advance for normal completion; no advance for explicit stop; repeat-one/all/end-of-queue behavior; cancellation during completion; no stale callback after engine switch; offline rendered boundary has no unintended zero/silence above the agreed threshold (for example, no gap >10 ms); physical-device gap/crossfade listening and capture matrix passes.
- **Related:** TRV-006, TRV-016.

### TRV-008 — Real sleeps make async and timer tests scheduler-dependent

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFiTests/SleepTimerManagerTests.swift:20-31,36-51,54-74`
    > `Task.sleep(for: .milliseconds(1500))`
    > `Task.sleep(for: .milliseconds(2500))`
  - `Fonic HiFiTests/PlaybackStateManagerTests.swift:19-29,42-50,76-100`
    > `// Wait for async delivery via RunLoop.main`
    > `Task.sleep(for: .milliseconds(100))`
  - `Fonic HiFiTests/FormatDetectionServiceConcurrencyTests.swift:100-125`
    > `Task.sleep(for: .milliseconds(50)); task.cancel()`
  - Static inventory found 28 `Task.sleep` call sites in unit/support tests.
- **Why this is defective/risky:** Passing depends on CI load and timer scheduling. Fixed sleeps can be too short (flake) or unnecessarily long. Cancellation tests do not prove the operation reached the cancellable point before cancellation. The Sleep Timer suite alone waits about 5.5 seconds. What remains unverified is ordering and cancellation, not elapsed wall time.
- **Remediation:** Inject a sleeper/clock, wait for observable callbacks/conditions, and use a controlled continuation to advance time deterministically.
- **Production-quality sample:**

```swift
// Production seam
public typealias SleepOperation = @Sendable (Duration) async throws -> Void
private let sleep: SleepOperation

public init(sleep: @escaping SleepOperation = { try await Task.sleep(for: $0) }) {
    self.sleep = sleep
}

// Replace Task.sleep(for: .seconds(1)) with:
try await sleep(.seconds(1))

// Test clock
actor ControlledSleeper {
    private var waiters: [CheckedContinuation<Void, Error>] = []

    func sleep(_: Duration) async throws {
        try await withCheckedThrowingContinuation { waiters.append($0) }
    }

    func advanceOneTick() {
        precondition(!waiters.isEmpty)
        waiters.removeFirst().resume()
    }
}

@Test @MainActor
func timerCompletesAfterExactTicks() async {
    let clock = ControlledSleeper()
    let timer = SleepTimerManager(sleep: clock.sleep)
    var completions = 0
    timer.onComplete = { completions += 1 }
    timer.start(seconds: 2)

    await clock.advanceOneTick()
    #expect(timer.remainingSeconds == 1)
    await clock.advanceOneTick()
    #expect(timer.remainingSeconds == 0)
    #expect(completions == 1)
}
```

The continuation store must also resume/cancel outstanding waiters during teardown; compile and actor-isolation-check under Swift 6/Xcode 26.
- **Verification / acceptance criteria:** no fixed sleep is used to observe state; cancellation waits for a “started” confirmation before canceling; timer tests complete in milliseconds and pass under 100 repeated executions and randomized order.
- **Related:** TRV-009, TRV-011.

### TRV-009 — Shared process/sandbox state breaks test isolation

- **Severity:** Medium
- **Confidence:** Probable
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Queue/QueueState.swift:314-357`
    > `private static let persistenceKey = "com.fonichifi.queue.state"`
    > `UserDefaults.standard.set(...)`
  - `Fonic HiFi/Core/Audio/Queue/AudioQueueManager.swift:655-665`
    > `notifyTracksChanged()` / `notifyCurrentTrackChanged()` both `saveState()`
  - `Fonic HiFiTests/AudioQueueManagerTests.swift:292-312` writes/restores/clears that global state without setup/teardown isolation.
  - `Fonic HiFiTests/ImportPipelineTests.swift:429-434`
    > `documentsURL.appendingPathComponent("Music")`
    > `try FileManager.default.removeItem(at: musicURL)`
  - `Fonic HiFiTests/MetricsTests.swift:8-17` and `AudioEngineManagerTests.swift:8-12` mutate the same global Metrics sink and `UserDefaults.standard` key.
- **Why this is defective/risky:** Queue mutations in many tests implicitly overwrite the same production key. Metrics suites replace one global sink. App Group suites and singletons likewise share state. Parallel or failed tests can contaminate one another. The cleanup helper deletes the entire host app's `Documents/Music`, not a test-owned directory; it can race with other import tests and destroys debugging evidence. Parallelization is not explicitly disabled because there is no test plan (TRV-002).
- **Remediation:** Inject storage into queue/metrics/import components, use a UUID-named defaults suite and temporary root per test, and clean only owned resources in teardown. Serialize only the few unavoidable App Group/device tests.
- **Production-quality storage seam:**

```swift
protocol QueueStatePersisting: Sendable {
    func save(_ state: QueueState) throws
    func load() throws -> QueueState?
    func clear()
}

struct UserDefaultsQueueStateStore: QueueStatePersisting, @unchecked Sendable {
    let defaults: UserDefaults
    let key: String

    func save(_ state: QueueState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try encoder.encode(state), forKey: key)
    }

    func load() throws -> QueueState? {
        guard let data = defaults.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(QueueState.self, from: data)
    }

    func clear() { defaults.removeObject(forKey: key) }
}

// Test setup
let suite = "AudioQueueManagerTests.\(UUID().uuidString)"
let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
let store = UserDefaultsQueueStateStore(defaults: defaults, key: "queue")
let queue = AudioQueueManager(stateStore: store)
```

Similarly inject `musicContainerURL` and delete only that UUID directory. This requires a small initializer change and Xcode compilation.
- **Verification / acceptance criteria:** tests pass with parallel execution and randomized order for 100 repetitions; no test accesses the production queue/defaults key unless explicitly testing migration; no test removes `Documents/Music`; App Group tests run in a dedicated serialized/device lane.
- **Related:** TRV-002, TRV-008, TRV-015.

### TRV-010 — Persistent-store and migration behavior is not exercised

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFiTests/MigrationPlanTests.swift:7-16,38-49`
    > `let schema = Schema(SchemaV2.models)`
    > `isStoredInMemoryOnly: true`
    > `RecentSearchMigrationPlan.migrateTrackBookmarkHashes(in: context)`
  - `Fonic HiFi/Data/DataManager+Initialization.swift:43-57,123-180`
    > production uses `isStoredInMemoryOnly: false`, an App Group container, then retries with `RecentSearchMigrationPlan` and finally an in-memory fallback.
  - Across the test target, 13 SwiftData configurations are in-memory and zero are explicitly on-disk.
- **Why this is defective/risky:** The migration test creates the current V2 model, edits a V2 `Track`, and calls the helper directly. It never creates a V1 file, closes it, reopens it through the production `ModelContainer(... migrationPlan:)`, verifies relationships, or tests rollback/recovery. SQLite/WAL durability, App Group path/permissions, corrupt stores, low disk, crash during migration, and fallback UI are unverified.
- **Remediation:** Build golden on-disk V1 stores in a temporary directory, migrate through the production container builder, and reopen the V2 store before asserting every user-owned field and relationship.
- **Production-quality migration sample (compile against the exact SwiftData initializer in Xcode 26):**

```swift
@MainActor
func testV1StoreMigratesToV2OnDisk() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    let storeURL = root.appendingPathComponent("library.store")

    do {
        let v1Schema = Schema(SchemaV1.models)
        let v1Config = ModelConfiguration(
            "MigrationFixture",
            schema: v1Schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let v1 = try ModelContainer(for: v1Schema, configurations: [v1Config])
        let track = SchemaV1.TrackV1(
            url: URL(fileURLWithPath: "/Music/reference.flac"),
            title: "Reference",
            artist: "Artist",
            album: "Album",
            audioFormat: "FLAC"
        )
        track.sourceURLString = "file:///Music/reference.flac"
        track.sourceURLBookmark = Data("bookmark".utf8)
        v1.mainContext.insert(track)
        try v1.mainContext.save()
    }

    let v2Schema = Schema(SchemaV2.models)
    let v2Config = ModelConfiguration(
        "MigrationFixture",
        schema: v2Schema,
        url: storeURL,
        allowsSave: true,
        cloudKitDatabase: .none
    )
    let migrated = try ModelContainer(
        for: v2Schema,
        migrationPlan: RecentSearchMigrationPlan.self,
        configurations: [v2Config]
    )
    let tracks = try migrated.mainContext.fetch(FetchDescriptor<Track>())
    let track = try XCTUnwrap(tracks.first)
    XCTAssertEqual(track.title, "Reference")
    XCTAssertNotNil(track.sourceURLHash)
    XCTAssertNotNil(track.sourceBookmarkHash)
}
```

- **Verification / acceptance criteria:** a real V1 fixture migrates without data loss; V2 reopens in a fresh container; track/album/artist/playlist relationships, favorites, counts, ReplayGain, bookmarks, and hashes survive; corrupt/locked/low-disk failures surface the intended recovery state without overwriting the original store.
- **Related:** TRV-006, TRV-011, TRV-014.

### TRV-011 — Library scale/performance tests do not model production storage or establish stable metrics

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFiTests/ImportValidationScenarioTests.swift:6-27` creates 12 files per folder at depth 3 (84 synthetic files total), uses a 1.5 ms fake extractor, and only asserts counters.
  - `Fonic HiFiTests/LibraryStatisticsPerformanceTests.swift:8-16,25-29,68-86`
    > `isStoredInMemoryOnly: true`
    > `let totalTracks = 10_000`
    > `CFAbsoluteTimeGetCurrent()`
    > `XCTAssertLessThan(elapsed, 1.8)`
  - No `XCTClockMetric`, `XCTMemoryMetric`, `XCTCPUMetric`, or committed baseline appears in the test target.
- **Why this is defective/risky:** An 84-file fake import is not high volume for a music library and does not decode or copy realistic files. A one-shot, in-memory, debug-build wall-clock threshold varies by runner and excludes SQLite/App Group I/O, artwork, metadata parsing, memory, scrolling, cancellation, and contention. It may be flaky while still missing production regressions.
- **Remediation:** Separate correctness, benchmark, and device/UI performance lanes. Use on-disk stores and real metadata fixtures, XCTest metrics with baselines, multiple iterations, and representative 10k/50k libraries.
- **Production-quality benchmark pattern:**

```swift
func testOnDiskStatisticsBenchmark() throws {
    let fixture = try OnDiskLibraryFixture.make(trackCount: 10_000, artworkEvery: 10)
    addTeardownBlock { fixture.remove() }

    let options = XCTMeasureOptions()
    options.iterationCount = 10
    measure(
        metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()],
        options: options
    ) {
        let done = expectation(description: "statistics")
        Task { @MainActor in
            _ = try await fixture.dataManager.getLibraryStatistics(forceRefresh: true)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
    }
}
```

Add a non-performance correctness assertion outside `measure`; adapt `forceRefresh` as an explicit test seam if the current API lacks it. Verify this pattern does not deadlock with MainActor under Xcode 26.
- **Verification / acceptance criteria:** 10 iterations on a fixed release-build device/runner; baseline and allowed regression committed; peak memory/CPU/time reported; on-disk 10k and 50k libraries; import cancellation, duplicate scan, pagination, search, and first-frame UI responsiveness meet product budgets.
- **Related:** TRV-008, TRV-010, TRV-014.

### TRV-012 — Accessibility verification is absent

- **Severity:** Informational
- **Confidence:** UNVERIFIED — needs build/device check
- **Evidence:**
  - `Fonic HiFiUITests/LibraryNowPlayingSmokeTests.swift:10-17,28-117` launches only `-UITestPreviewData` and contains no accessibility audit/configuration.
  - `Fonic HiFi/Presentation/Views/Components/CustomProgressSlider.swift:87-125` implements a custom adjustable accessibility element.
  - `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:158-160,175-203,375-506` exposes escape, queue, progress, A-B loop, shuffle, transport, and repeat interactions whose focus order/state announcements matter.
  - `Fonic HiFi.xcodeproj/project.pbxproj:610-618,674-683` targets only device family 1 in test configurations; no multi-device plan exists.
- **Why this is risky / remains unverified:** Labels in source do not prove VoiceOver focus order, adjustable actions, state announcements, hit regions, contrast, Dynamic Type clipping, Reduce Motion, Switch Control, localization, or landscape/small-screen behavior. The UI suite never changes accessibility settings or invokes XCTest's accessibility audit.
- **Remediation:** Add automated accessibility audits and explicit interaction tests, then run a manual physical-device matrix for behavior automation cannot certify.
- **Production-quality UI test sample:**

```swift
func testNowPlayingAccessibilityAtAccessibilityXXXL() throws {
    let app = XCUIApplication()
    app.launchArguments += [
        "-UITestPreviewData",
        "-UIPreferredContentSizeCategoryName",
        "UICTContentSizeCategoryAccessibilityXXXL"
    ]
    app.launch()

    XCTAssertTrue(app.otherElements["player.mini"].waitForExistence(timeout: 5))
    app.otherElements["player.mini"].tap()

    try app.performAccessibilityAudit(
        for: [.contrast, .dynamicType, .hitRegion, .sufficientElementDescription]
    )

    XCTAssertTrue(app.buttons["player.next"].isHittable)
    XCTAssertTrue(app.otherElements["player.progress"].exists)
}
```

Confirm the exact `performAccessibilityAudit` option API in Xcode 26. Add stable identifiers and an explicit UI test for `accessibilityAdjustableAction` on the custom progress slider.
- **Verification / acceptance criteria:** zero unwaived audit failures on small/large supported iPhones; VoiceOver can reach and operate all transport/queue/sleep/EQ controls in logical order; accessibility XXXL has no clipped or inaccessible primary action; Reduce Motion removes nonessential zoom/spring behavior; contrast passes in all artwork-derived themes; English plus at least one long-string locale passes.
- **Related:** TRV-004, TRV-016.

### TRV-013 — Coverage gate is coarse and current evidence is not retained in the repository

- **Severity:** Informational
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Makefile:23-27,273-285`
    > `COVERAGE_MIN_PERCENT ?= 40`
    > `APP_COVERAGE_MIN_PERCENT ?= 40`
    > `xccov ... > build/coverage.json`
  - `scripts/coverage_summary.py:15-20,76-85,128-140`
    > selects one `.app` and the first `.xctest`; thresholds only overall and app.
  - `.github/workflows/ci.yml:31-57` uploads coverage artifacts and re-fails a non-zero coverage status.
  - `.gitignore:8-11` ignores `build/`; no current `.xcresult` or coverage JSON is checked in.
- **Why this is risky / remains unverified:** The gate has no widget-extension threshold, no critical-file threshold, no changed-lines coverage, and no branch/behavioral criterion. The first `.xctest` statistic may represent only one of unit/UI targets. Historical markdown is not current release evidence and was not treated as proof. Line coverage cannot demonstrate audio output, accessibility, migration, or device behavior.
- **Remediation:** Keep the app threshold, add widget and critical-module/diff thresholds, record commit/toolchain metadata, and retain the raw `.xcresult` and summary for every protected-branch/release run.
- **Production-quality script extension:**

```python
def require_target(targets, suffix, threshold, failures):
    matches = [target for target in targets if target.get("name", "").endswith(suffix)]
    if not matches:
        failures.append(f"Coverage target {suffix} not found")
        return
    covered = sum(int(t.get("coveredLines", 0)) for t in matches)
    executable = sum(int(t.get("executableLines", 0)) for t in matches)
    pct = compute_pct(covered, executable)
    if pct + 1e-9 < threshold:
        failures.append(f"{suffix} coverage {pct:.2f}% is below {threshold:.2f}%")

require_target(targets, ".app", args.app_threshold, failures)
require_target(targets, ".appex", args.widget_threshold, failures)
```

Also walk `files` in `coverage.json` and enforce reviewed budgets for playback, persistence/migration, and accessibility-support code. Threshold values should be ratcheted from a fresh trusted baseline rather than guessed.
- **Verification / acceptance criteria:** each CI summary includes commit SHA, Xcode/SDK, executed/pass/fail/skip counts, app/widget/critical-path coverage, and links to retained result bundles; protected branches reject regressions; skipped lines and generated/test code are classified intentionally.
- **Related:** TRV-001, TRV-014, TRV-015.

### TRV-014 — Release configuration and release-only failure modes are not gated

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `.github/workflows/ci.yml:19-39` runs install, lint, `make build`, `make test`, and coverage only.
  - `Makefile:160-185` shows `make build` builds `CONFIGURATION_DEBUG` and first reruns tests.
  - `Makefile:187-199` defines `build-release`, but CI never invokes it.
  - No archive/export/analyze/sanitizer action appears in `.github/workflows/ci.yml`.
- **Why this is defective/risky:** Optimized compilation, `#if DEBUG` differences, whole-module optimization, extension embedding, archive validation, entitlements, resource copying, dead stripping, and signing/export can regress while Debug simulator tests remain green. Sanitizer/race diagnostics and static analyzer findings are not release gates. What remains unverified is the actual distributable artifact.
- **Remediation:** Add Release generic-device archive and analyzer jobs on pull requests, and signed export/App Store validation in a protected release workflow. Add separate ASan/TSan jobs where supported.
- **Production-quality CI sample:**

```yaml
- name: Analyze
  run: |
    set -o pipefail
    xcodebuild analyze \
      -project "Fonic HiFi.xcodeproj" \
      -scheme "Fonic HiFi" \
      -configuration Debug \
      -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2"

- name: Unsigned Release archive verification
  run: |
    set -o pipefail
    rm -rf build/FonicHiFi.xcarchive
    xcodebuild archive \
      -project "Fonic HiFi.xcodeproj" \
      -scheme "Fonic HiFi" \
      -configuration Release \
      -destination "generic/platform=iOS" \
      -archivePath build/FonicHiFi.xcarchive \
      CODE_SIGNING_ALLOWED=NO
    test -d build/FonicHiFi.xcarchive/Products/Applications/Fonic\ HiFi.app
    test -d build/FonicHiFi.xcarchive/Products/Applications/Fonic\ HiFi.app/PlugIns/Fonic\ HiFi\ Widget.appex
```

A separate credentials-scoped release job should sign/export and run App Store validation; never expose signing secrets to untrusted pull requests.
- **Verification / acceptance criteria:** clean Release archive succeeds; widget is embedded; expected entitlements/privacy/Info keys are present; signed export validates; analyzer has no accepted-new issue; sanitizer lanes pass; the exact archived commit/result bundle is traceable to release.
- **Related:** TRV-001, TRV-010, TRV-011, TRV-013.

### TRV-015 — Conditional skips are not a failing release signal

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFiTests/AudioKitEngineAdapterTests.swift:6-10,21-25,38-42,69-89,105-140` contains eight engine-availability skip sites and one silent early `return` at lines 55-59.
  - `Fonic HiFiTests/AppGroupManagerTests.swift:32-35,62-65,94-97,111-114,127-130` skips all persistence tests when App Group defaults are unavailable.
  - `Fonic HiFiTests/WidgetArtworkCacheTests.swift:12-20` skips the class when the App Group cache is unavailable.
  - `Fonic HiFiUITests/LibraryNowPlayingSmokeTests.swift:38-41,102-105` skips core playback UI.
  - `.github/workflows/ci.yml:28-39` checks only the command exit status; skipped XCTest cases do not make `xcodebuild test` fail.
- **Why this is defective/risky:** A runner can lose AudioKit initialization, App Group entitlements, widget storage, or seeded Mini Player behavior and still report a successful suite. Static inventory found 26 skip call sites across 9 files. The silent `guard ... else { return }` is even less visible. The most environment-sensitive production behavior is therefore easiest to omit from a release run.
- **Remediation:** Classify skips: unit tests should inject capabilities and never skip; device-only tests may skip outside their designated lane, but the designated lane must fail if prerequisites are missing. Parse `.xcresult` and reject unexpected skips.
- **Paste-ready skip gate (validate `xcresulttool` schema with Xcode 26):**

```bash
#!/usr/bin/env bash
set -euo pipefail
bundle=${1:?usage: verify_skips.sh TestResults.xcresult}
json=$(mktemp)
trap 'rm -f "$json"' EXIT
xcrun xcresulttool get test-results tests --path "$bundle" --format json > "$json"
python3 - "$json" <<'PY'
import json, sys
root = json.load(open(sys.argv[1]))
skipped = []
def walk(value):
    if isinstance(value, dict):
        if str(value.get("testStatus", "")).lower() == "skipped":
            skipped.append(value.get("name", "<unknown>"))
        for child in value.values(): walk(child)
    elif isinstance(value, list):
        for child in value: walk(child)
walk(root)
if skipped:
    print("Unexpected skipped tests:\n" + "\n".join(sorted(skipped)), file=sys.stderr)
    raise SystemExit(1)
PY
```

Use a reviewed allowlist only for explicitly quarantined/device-inapplicable cases, with owner and expiry.
- **Verification / acceptance criteria:** zero unexpected skips on protected branches; AudioKit/App Group/UI prerequisites missing in their required lanes cause failure; no test silently returns because setup failed; skip count is shown in release evidence.
- **Related:** TRV-003, TRV-004, TRV-006, TRV-016.

### TRV-016 — No physical-device media acceptance lane covers the product's highest-risk behavior

- **Severity:** Medium
- **Confidence:** UNVERIFIED — needs build/device check
- **Evidence:**
  - `Makefile:15-18,248-255` hard-codes `platform=iOS Simulator` for tests.
  - `.github/workflows/ci.yml:8-57` has only one simulator-oriented build/test job and no device farm/manual release gate.
  - `Fonic HiFiTests/AudioSessionServiceTests.swift:5-48` tests enum mappings/descriptions only.
  - `Fonic HiFi/Core/Audio/Services/AudioSessionManager.swift:69-147,193-286,342-433` contains real session setup, remote command registration, interruptions, route changes, and media-services reset behavior not exercised by those tests.
  - `Fonic HiFiTests/BitPerfectValidatorTests.swift:7-93` supplies mocked capabilities/device data; it does not validate hardware output.
- **Why this is risky / remains unverified:** Simulator execution cannot prove speaker/headphone/USB DAC/Bluetooth/AirPlay routing, actual sample rate, interruptions, background/lock-screen continuation, remote controls, media-services reset, gaplessness, or bit-perfect output. Mocked “USB DAC” capabilities prove aggregation logic only. These are release-defining behaviors for an offline audiophile player.
- **Remediation:** Establish an Xcode 26 physical-device acceptance lane plus a signed manual matrix. Instrument tests may assert route/sample-rate/preconditions, but waveform/null and human/device checks remain necessary.
- **Production-quality device precondition/test sample:**

```swift
@MainActor
final class DeviceAudioAcceptanceTests: XCTestCase {
    func testConfiguredRoutePlaysReferenceFile() async throws {
        let expectedPort = try XCTUnwrap(
            ProcessInfo.processInfo.environment["EXPECTED_AUDIO_PORT_TYPE"],
            "Device lane must declare its attached route"
        )
        let session = AVAudioSession.sharedInstance()
        XCTAssertTrue(
            session.currentRoute.outputs.contains { $0.portType.rawValue == expectedPort },
            "Required route is not attached: \(session.currentRoute.outputs)"
        )

        let source = try XCTUnwrap(
            Bundle(for: Self.self).url(
                forResource: "stereo-sine-24bit-96k",
                withExtension: "flac",
                subdirectory: "AudioFixtures"
            )
        )
        let adapter = AVAudioEngineAdapter(sessionManager: AudioSessionManager())
        try await adapter.load(url: source)
        try await adapter.play()

        let advanced = expectation(description: "playhead advances")
        Task { @MainActor in
            while await adapter.currentTime <= 0 { await Task.yield() }
            advanced.fulfill()
        }
        await fulfillment(of: [advanced], timeout: 2)
        XCTAssertEqual(session.sampleRate, 96_000, accuracy: 1)
        await adapter.stop()
    }
}
```

The expected sample rate must reflect each route's documented capability; do not universally require 96 kHz. Add external capture/null analysis where a bit-perfect claim is made.
- **Verification / acceptance criteria:**
  1. Required matrix: built-in speaker, wired/USB-C headphones, supported USB DAC, Bluetooth, AirPlay; 44.1/48/96 kHz and supported bit depths.
  2. Phone/Siri/alarm interruption begin/end, headphone unplug, route switch, screen lock/background, media-services reset, and Control Center/headset remote commands recover correctly.
  3. Now Playing title/artwork/duration/rate/elapsed time remain synchronized.
  4. Gapless/crossfade captured output meets agreed gap/overlap bounds.
  5. Bit-perfect claims have external null/analyzer evidence; otherwise UI wording is limited to what is actually measured.
- **Related:** TRV-005, TRV-006, TRV-007, TRV-012, TRV-015.

---

## Rejected candidate findings

1. **“Coverage failures are swallowed by CI.” — Rejected.** `.github/workflows/ci.yml:31-39` temporarily captures the status to upload artifacts, but lines 51-57 explicitly re-fail when the saved status is non-zero.
2. **“Test source directories are not members of test targets.” — Rejected.** `Fonic HiFi.xcodeproj/project.pbxproj:194-234` uses `fileSystemSynchronizedGroups` for both test directories. The unresolved issue is scheme/TestAction selection, not source-group membership (TRV-002).
3. **“Tests are compile-time disabled.” — Rejected.** No `#if false`, XCTest expected-failure, or Swift Testing disabled trait was found in the test target. Conditional runtime skips remain (TRV-015).
4. **“The repository proves 347/454 tests pass.” — Rejected.** README/status/build logs and historical coverage notes are not current execution evidence, and this environment cannot run Xcode. They were not used as proof.
5. **“A historical build log proves the current test target does not compile.” — Rejected.** Logs are archived observations, not live source/configuration proof under the audit rules. A clean Xcode 26 build is an open check.
6. **“No assertions exist.” — Rejected.** Static inventory found 1,519 assertion tokens and many meaningful logic assertions. Findings target specific vacuous assertions, fakes, and unverified production boundaries rather than dismissing the whole suite.

## Open build/device checks

1. **Clean toolchain proof:** On a fresh matching macOS/Xcode 26.x runner, record `xcodebuild -version`, SDKs, destinations, `xcodebuild -list -json`, resolved packages, and build settings.
2. **Compile and execute each target separately:** Produce unit and UI `.xcresult` bundles; report executed/pass/fail/skip counts; fail zero-count/skip-policy violations.
3. **Repeatability:** Run unit tests 100 times with randomized ordering and supported parallelization. Run timer/concurrency suites under high CPU load after clock injection.
4. **Sanitizers:** Run ASan/UBSan on simulator and TSan on concurrency-safe test selections supported by the chosen Xcode/runtime; inspect leaks separately on device.
5. **Real audio corpus:** Decode/import/load the committed supported/corrupt fixture matrix; retain metadata and error results.
6. **Physical-device media matrix:** Execute TRV-016 routes/interruption/background/remote/gapless/crossfade/Now Playing checks and retain signed evidence.
7. **Persistent library matrix:** Migrate golden V1 stores, reopen V2 stores, test corrupt/locked/low-disk cases, and benchmark 10k/50k on-disk libraries.
8. **Accessibility matrix:** Run XCTest accessibility audits plus VoiceOver, Dynamic Type accessibility XXXL, Reduce Motion, Increased Contrast, Switch Control, landscape, and long-string localization on supported devices.
9. **Release artifact:** Analyze, archive Release, embed widget, sign/export in the protected workflow, and validate the exact artifact intended for distribution.

## Release acceptance gate (minimum)

A release candidate is acceptable only when all of the following are attached to the candidate commit:

- Fresh Xcode 26.x toolchain/destination proof.
- Non-zero, separately reported unit and UI execution with **zero unexpected skips**.
- No failures across required repetition/concurrency lanes.
- App, widget, critical-path, and changed-lines coverage meeting reviewed ratcheted budgets.
- Clean analyzer/sanitizer results or explicitly approved, expiring waivers.
- Successful Release archive, widget embedding check, signed export, and distribution validation.
- Passing real-format import/playback fixture matrix.
- Passing on-disk migration/recovery/large-library matrix.
- Passing accessibility automated/manual matrix.
- Passing physical-device playback/route/interruption/background/remote/gapless evidence.
