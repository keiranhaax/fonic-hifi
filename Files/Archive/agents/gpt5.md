Executive summary
The project exhibits a solid modular structure with clear layering (Presentation, Core/Audio, Data), strong use of Swift concurrency annotations (@MainActor, ModelActor), and a thoughtful audio engine abstraction. However, several high-impact issues undermine correctness and reliability:
- Audio session ownership is inconsistent (singleton vs injected instances; ad-hoc activation in adapter), risking race conditions and duplicate observers.
- Logging is fragmented and shadowed by a local Logger type, causing inconsistencies with other modules using OSLog.
- Debug-only patterns (fatalError, try!, widespread print) leak into runtime paths, risking crashes and noisy logs.
- AVAudioEngine adapter includes Mach APIs without import guards, which will fail to compile on iOS unless guarded.
- Progress updates and state changes are handled on MainActor but introduce avoidable reentrancy/task churn.
- Some preview and persistence utilities risk touching non-ephemeral stores; exported data routines can be memory-heavy.

Prioritized action list (P0–P2, effort, rationale)
1) P0 Audio session authority and lifecycle (M)
- Single source of truth: Inject one AudioSessionManager instance into all audio components; remove singleton usage in AVAudioEngineAdapter; avoid direct AVAudioSession.setActive in adapters and move all session category/activation into the manager.
- Wire remote command enablement during initialization; ensure idempotent registration.
Impact: Prevents duplicate observers, undefined behavior across engine swaps, and session state drift.

2) P0 Replace fatalError/try!/print in app code paths (S-M)
- Replace [Swift.fatalError()](Fonic HiFi/FonicHiFiApp.swift:43) and [Swift.try!](Fonic HiFi/FonicHiFiApp_Debug.swift:14) with user-visible error UI and resilient fallbacks; gate [Swift.print()](Fonic HiFi/Presentation/Views/Debug/DebugTrackRowView.swift:35) behind #if DEBUG or central logger.
Impact: Eliminates production crashes and reduces performance/log noise.

3) P0 Compile-time fix for Mach usage (S)
- Guard Mach telemetry in [AVAudioEngineAdapter.swift](Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift) with canImport(Mach) and add import Mach or remove completely on iOS.
Impact: Fixes build break; avoids private API pitfalls.

4) P1 Unify logging on os.Logger (M)
- Remove file-private Logger shadow in [AudioEngineFacade.swift](Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift); adopt os.Logger everywhere with consistent categories; use signposts for performance sections.
Impact: Structured logs and better performance diagnostics with Console/OSSignpost.

5) P1 Engine selection and format handling (M)
- Ensure engine selection honors detected format on every load; don’t early-return when a currentEngine exists if it cannot satisfy format requirements; persist current engine type preference cleanly.
Impact: Correct playback routing for future format-specific adapters.

6) P1 Progress update loop refinement (S)
- In [AudioEngineFacade.swift](Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift), avoid spawning nested Task in each timer tick; await async engine properties directly on MainActor; coalesce update rate if UI jank is observed.
Impact: Reduces actor hops and scheduling overhead.

7) P1 Preview safety and testability (S)
- Ensure previews use in-memory containers only; replace fatalError in preview helpers with preconditionFailure in DEBUG or safe throws, and prevent previews from using on-disk stores.
Impact: Avoids accidental on-disk writes and stabilizes previews.

8) P2 Export/data scale safety (S)
- Avoid Int.max fetch limits in [DataManager.swift](Fonic HiFi/Data/DataManager.swift); introduce pagination/streaming for exports.
Impact: Prevents memory spikes on large libraries.

9) P2 Remote command enablement (S)
- Call AudioSessionManager.enableRemoteCommands() during facade initialize; add disable during shutdown.
Impact: Ensures system media controls function.

Architecture and module map
Mermaid
graph TD
  subgraph Presentation (SwiftUI)
    ContentView[ContentView.swift] --> LibraryView[LibraryView.swift]
    LibraryView --> TrackListView[TrackListView.swift]
    LibraryView --> NowPlayingView[NowPlayingView.swift]
    NowPlayingView -->|Environment| AudioEngineFacade
  end
  subgraph Core.Audio
    AudioEngineFacade[AudioEngineFacade.swift]
    PlaybackStateManager[PlaybackStateManager.swift]
    AudioQueueManager[AudioQueueManager.swift]
    AudioSessionManager[AudioSessionManager.swift]
    AVAdapter[AVAudioEngineAdapter.swift]
    AudioKitAdapter[AudioKitEngineAdapter.swift]
    FormatDetect[AudioFormatDetectionManager.swift]
    Monitor[AudioMonitor.swift]
    Validator[BitPerfectValidator.swift]
    AudioEngineFactory[AudioEngineFactory.swift]
  end
  subgraph Data (SwiftData)
    DataManager[DataManager.swift]
    TrackDataActor[TrackDataActor.swift]
    RecentSearchesActor[RecentSearchesActor.swift]
    MetadataExtractor[MetadataExtractionService.swift]
    ImportService[LibraryImportService.swift]
    Models[Models/*.swift]
  end

  ContentView --> DataManager
  NowPlayingView --> AudioEngineFacade
  AudioEngineFacade --> PlaybackStateManager
  AudioEngineFacade --> AudioQueueManager
  AudioEngineFacade --> AudioSessionManager
  AudioEngineFacade --> Monitor
  AudioEngineFacade --> Validator
  AudioEngineFacade --> FormatDetect
  AudioEngineFacade --> AudioEngineFactory
  AudioEngineFactory --> AVAdapter
  AudioEngineFactory --> AudioKitAdapter
  ImportService --> TrackDataActor
  ImportService --> MetadataExtractor
  DataManager --> ImportService
  DataManager --> TrackDataActor
  DataManager --> RecentSearchesActor

Dependency and flow highlights
- UI depends on AudioEngineFacade via environment in [NowPlayingView.swift](Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingView.swift).
- Facade orchestrates playback, queue updates, progress timer, monitoring, and validation, and fans out to AudioSessionManager, FormatDetection, factory, adapters.
- Data layer uses SwiftData with actor-based write paths (TrackDataActor, RecentSearchesActor) to maintain isolation; [LibraryImportService.swift](Fonic HiFi/Data/Services/LibraryImportService.swift) coordinates scanning, copy to app sandbox, metadata extraction, and persistence.

Issue catalog with root cause, impact, severity, fixes
1) Multiple AudioSessionManager instances and direct AVAudioSession manipulation
- Evidence:
  - Facade injects or constructs manager: [AudioEngineFacade.swift](Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift)
  - Adapter uses singleton: [AVAudioEngineAdapter.swift](Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift)
  - Adapter also calls AVAudioSession.setCategory/active directly: [Swift.AVAudioSession.setActive(_:)](Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:162)
- Root cause: Mixed DI and singleton with direct session manipulation.
- Impact: Duplicate observers, session state drift, race conditions with activation/deactivation, hard-to-debug playback issues.
- Severity: High.
- Recommendation:
  - Remove singleton use and accept a manager in adapter initializer; centralize all session category/activation logic in AudioSessionManager; expose methods like configure(category:mode:options:) and activate/deactivate with idempotence.
  - Have AudioEngineFacade coordinate session activation order: configure -> activate -> load -> play; mirror on stop/pause/shutdown.

2) Logging fragmentation and name shadowing
- Evidence:
  - Local Logger type + extension: [AudioEngineFacade.swift](Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift)
  - Other files import OSLog and use os.Logger initializers.
- Root cause: Custom Logger shadows OSLog.Logger type in one file; project-wide inconsistency.
- Impact: Confusing, harder to filter logs, lost integration with unified logging and signposts.
- Severity: Medium.
- Recommendation:
  - Replace the local Logger with os.Logger via import OSLog and consistent categories; optional wrapper typealias to Logger = os.Logger for ergonomics; add signpost intervals for playback/monitoring.

3) Debug constructs leaking to production paths
- Evidence:
  - [Swift.fatalError()](Fonic HiFi/FonicHiFiApp.swift:43) on app init failure.
  - [Swift.try!](Fonic HiFi/FonicHiFiApp_Debug.swift:14) for DataManager in debug app, OK if guarded.
  - Heavy [Swift.print()](Fonic HiFi/Presentation/Views/Debug/DebugTrackRowView.swift:35) usage across UI and engine code.
- Root cause: Debug scaffolding left in main flows.
- Impact: Crashes in production, performance/logging overhead, App Store policy risk.
- Severity: High (fatalError), Medium (prints).
- Recommendation:
  - Replace fatalError with error handling/alert sheet and fallback to limited UI.
  - Wrap print in #if DEBUG or switch to os.Logger with appropriate levels.
  - Replace try! with do/catch even in debug app, or #if DEBUG commentary made explicit.

4) AVAudioEngineAdapter Mach usage without guards
- Evidence: getCurrentCPUUsage and getCurrentMemoryUsage use Mach APIs without imports/guards in [AVAudioEngineAdapter.swift](Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift).
- Root cause: Missing import Mach and platform availability checks.
- Impact: Build failures; risk of private API concerns if misused.
- Severity: High (build).
- Recommendation:
  - Add canImport(Mach) guards and import Mach; otherwise return sentinel values or remove the metrics.

5) Progress timer re-entrancy and extra tasks
- Evidence:
  - In [AudioEngineFacade.swift](Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift) tick closure, a nested Task is created to await engine metrics and then MainActor.run again.
- Root cause: Redundant task creation; both facade and adapter are @MainActor.
- Impact: Extra work scheduling; potential coalescing issues.
- Severity: Medium.
- Recommendation:
  - Await engine.currentTime/duration inline in the MainActor timer and update state without an inner Task.

6) Engine selection logic is overly permissive
- Evidence: [AudioEngineFacade.ensureEngineForFormat(_:)](Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift) early-returns if an engine exists, regardless of format differences.
- Root cause: Incomplete engine-format matrix and reassignment policy.
- Impact: Future non-PCM formats or AudioKit-specific cases would fail or degrade quality.
- Severity: Medium.
- Recommendation:
  - Add capability checks (e.g., adapter.canHandle(formatInfo)) and recreate engine as needed; persist engine preference clearly and reconcile with UserDefaults only when idle.

7) Remote commands never enabled
- Evidence:
  - AudioSessionManager.enableRemoteCommands exists but not called during init; facade sets delegate only.
- Root cause: Missing orchestration step in initialize.
- Impact: System media controls do not function.
- Severity: Medium.
- Recommendation:
  - Call enableRemoteCommands() in [Swift.AudioEngineFacade.initialize()](Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift) and disable in shutdown().

8) Preview and persistence behavior
- Evidence:
  - Previews: DataManager.makePreviewDataManager() constructs a live DataManager that uses disk store; [Swift.fatalError()](Fonic HiFi/Data/DataManager.swift:423) in previewContainer fallback.
- Root cause: Preview helpers not strictly isolated to memory-only stores.
- Impact: Previews may mutate on-disk data or crash developer previews.
- Severity: Medium.
- Recommendation:
  - Ensure preview-only builders always use in-memory ModelContainer and never fatalError; return stubbed services in DEBUG.

9) Export scalability
- Evidence:
  - [SwiftData fetch with Int.max limit](Fonic HiFi/Data/DataManager.swift:232) for exports.
- Root cause: Single batch aggregation for potentially large libraries.
- Impact: High memory usage; potential OOM.
- Severity: Medium.
- Recommendation:
  - Paginate or stream encode tracks in batches; re-use SwiftDataPagination util.

10) Minor correctness and quality
- PlaybackStateManager.duration property returns epoch seconds rather than interval between transitions (logic likely unintended).
- Dead code: audioQueue in [AudioEngineFacade.swift](Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift) not used.
- Widespread asserts/assertMainThread are good for debug but should be #if DEBUG gated.

Targeted refactor sketches
A) Centralize audio session control
- AudioSessionManager: add explicit configuration/activation API and idempotence; adapters remove direct AVAudioSession calls.
- Example: adopt in facade before load/play; remove activation from adapter.

B) Unify logging
- In [AudioEngineFacade.swift](Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift), delete the private Logger and extension. At top: import OSLog. Then:
  code:
  import OSLog
  final class AudioEngineFacade: ObservableObject {
    private let logger = Logger(subsystem: "com.fonichifi.audio", category: "AudioEngineFacade")
    // ...
    logger.log("message") // or logger.debug/info/warning/error using @available wrappers
  }
- Replace print across modules with logger.info/debug at appropriate levels; gate verbose debug with #if DEBUG or a runtime flag.

C) Guard Mach metrics or remove
- In [AVAudioEngineAdapter.swift](Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift), add:
  code:
  #if canImport(Mach)
  import Mach
  #endif
  // ...
  #if canImport(Mach)
    // Mach-based metrics
  #else
    return 0 // or a safe default
  #endif

D) Progress timer update simplification
- In [AudioEngineFacade.swift](Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift), within progressTimer.start closure:
  code:
  progressTimer.start(pollInterval: 0.2) { [weak self] in
    guard let self = self, let engine = self.currentEngine, self.currentState.isPlaying else { return }
    let current = await engine.currentTime
    let dur = await engine.duration
    self.stateManager.updateTime(current, duration: dur)
  }

E) Facade initialize/shutdown lifecycle
- Add:
  - await sessionManager.configureAudioSession()
  - await sessionManager.enableRemoteCommands()
  - On shutdown: await sessionManager.disableRemoteCommands(); await sessionManager.deactivateAudioSession()

Edge cases and scalability considerations
- Missing file paths: NowPlayingView checks file existence and aborts; ensure UI surfaces error to user instead of silent dismiss; optionally auto-remove broken items via DataManager.cleanupMissingFiles().
- Large libraries: Use SwiftDataPagination for lists; batch export/import already chunked in [LibraryImportService.swift](Fonic HiFi/Data/Services/LibraryImportService.swift) with batchSize=10; consider tunable batch size and backpressure based on device thermal state from Monitor.
- Session interruptions/route changes: Facade handles delegate callbacks; ensure resume policies are user-controlled (don’t auto-resume over earpiece changes unless desired).
- Background audio: Info.plist UIBackgroundModes=audio is set ([Info.plist](Fonic HiFi/Info.plist)); verify AudioSessionManager.category remains .playback consistently.
- Privacy strings: If any future microphone/recording features added, include NSMicrophoneUsageDescription preemptively only when used.

Standards, style, compliance
- Adopt consistent OSLog with privacy modifiers; add signposts for load/play/seek and frame-time critical paths.
- Ensure SwiftLint rules for force_unwrap, print, todo fixme; run make lint and fix.
- Entitlements: [Fonic_HiFi.entitlements](Fonic HiFi/Fonic_HiFi.entitlements) include CloudKit; if the app ships “without network permissions,” re-evaluate whether CloudKit capability is needed; having CloudKit entitlement may be harmless but inconsistent with project guidance.

Estimated effort
- P0 session + logging + Mach guards: 1–2 days
- P1 engine selection, progress timer, previews: 1–1.5 days
- P2 export pagination, remote commands enabling, lint cleanup: 0.5–1 day

Evidence index (selected)
- Session direct activation calls: [Swift.AVAudioSession.setActive(_:)](Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:162), [Swift.AVAudioSession.setActive(_:options:)](Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:224)
- Crash and force unwrap: [Swift.fatalError()](Fonic HiFi/FonicHiFiApp.swift:43), [Swift.try!](Fonic HiFi/FonicHiFiApp_Debug.swift:14)
- Widespread print debugging: [Swift.print()](Fonic HiFi/Presentation/Views/Debug/DebugTrackRowView.swift:35), [Swift.print()](Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingView.swift:152)
- Concurrency usage sanity: @MainActor types and Task usage across modules (multiple findings enumerated in prior scans).

Proposed next steps (execution order)
1) Implement P0 changes: session authority, logging unification, Mach guards.
2) Implement P1 engine capability checks + progress timer simplification + preview isolation.
3) Implement P2 export pagination + remote command enable/disable wiring + lint cleanup.
4) Run make build, make test-unit, and smoke test playback and background control center behavior on iPhone 16 Pro simulator; capture logs and verify signposts.

Appendix: risk ratings
- High: Production crash, build break, data loss, session race (items 1, 3, 4).
- Medium: Behavior inconsistency, performance overhead, user control gaps (items 2, 5, 6, 7, 8, 9).
- Low: Code hygiene, minor correctness (state duration), dead code.

If you want, I can draft targeted diffs for the P0 items (AudioSessionManager API, removing Logger shadow, Mach guards, replacing fatalError in app init) and stage them for review.

Executive summary
The codebase is well-structured with a clear separation of concerns across Presentation (SwiftUI), Core/Audio (facade, adapters, state, diagnostics), and Data (SwiftData, actors, services). Concurrency model alignment is strong, with @MainActor applied where appropriate and ModelActor used for persistence. However, several high-impact issues threaten stability and correctness:
- Audio session lifecycle is fragmented across a singleton and direct AVAudioSession calls, creating race risks and conflicting ownership.
- Logging is inconsistent and locally shadowed by a custom Logger type, hampering observability and best-practice diagnostics.
- Debug constructs (fatalError, try!, widespread print) appear in runtime paths, risking crashes and noisy logs.
- AVAudioEngine adapter includes Mach APIs without platform guards, likely breaking on iOS builds.
- Progress timer architecture introduces unnecessary Task churn and actor hops.
- Export routines and certain preview helpers can scale poorly or use non-ephemeral stores.

Prioritized action items (with effort)
P0 (High priority)
1) Centralize audio session authority and lifecycle (M)
- Eliminate singleton usage in adapter; inject the single AudioSessionManager instance created by the facade. Move all AVAudioSession category/activation exclusively into the manager. Remove direct calls in adapter like [Swift.AVAudioSession.setActive(_:)](Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:162) and [Swift.AVAudioSession.setActive(_:options:)](Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:224).
- Facade initialize(): configure session, enable remote commands, then load/play. Shutdown(): disable remote commands, deactivate session.

2) Remove crashy debug constructs and noisy logs (S–M)
- Replace [Swift.fatalError()](Fonic HiFi/FonicHiFiApp.swift:43) with non-fatal UI error path and a safe fallback state.
- Replace [Swift.try!](Fonic HiFi/FonicHiFiApp_Debug.swift:14) with do/catch even in debug.
- Gate print statements behind #if DEBUG or route through os.Logger.

3) Guard or remove Mach-based metrics (S)
- Surround Mach telemetry in adapter with #if canImport(Mach) … #endif or replace with safe stubs. The current code in [AVAudioEngineAdapter.swift](Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift) uses Mach APIs and will likely fail to compile on iOS.

P1 (Medium priority)
4) Unify logging using os.Logger and signposts (M)
- Remove custom Logger shadow in [AudioEngineFacade.swift](Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift); standardize on os.Logger with consistent subsystem/category, and add signposts around playback critical paths.

5) Engine capability checks and engine swapping (M)
- Update ensureEngineForFormat to evaluate current engine’s capability; recreate engine if the new format requires it instead of early return in [AudioEngineFacade.ensureEngineForFormat](Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift).

6) Simplify progress timer loop to reduce Task churn (S)
- In the timer tick, await engine properties directly on MainActor and update state—avoid nested Task { … } in [AudioEngineFacade.swift](Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift).

7) Preview and persistence safety (S)
- Ensure all preview helpers use in-memory stores only and avoid [Swift.fatalError()](Fonic HiFi/Data/DataManager.swift:423) in preview paths.

P2 (Lower priority)
8) Export scalability (S)
- Replace Int.max fetch in exports with paging to prevent memory spikes in [DataManager.swift](Fonic HiFi/Data/DataManager.swift).

9) Remote command enable/disable wiring (S)
- Call enableRemoteCommands() during facade initialize and disable in shutdown; see [AudioSessionManager](Fonic HiFi/Core/Audio/Services/AudioSessionManager.swift).

10) Code hygiene and small correctness
- Fix PlaybackStateManager duration fields and prune dead code (unused audioQueue), guard asserts with #if DEBUG across the codebase.

Architecture and module map
- Presentation: SwiftUI views and environment integration
- Core.Audio: Facade, adapters, session, state, diagnostics, factory, queue
- Data: SwiftData models, actors, metadata extraction, import service
- Shared utils/helpers

Mermaid
graph TD
  subgraph Presentation (SwiftUI)
    ContentView[ContentView.swift] --> LibraryView[LibraryView.swift]
    LibraryView --> TrackListView[TrackListView.swift]
    LibraryView --> NowPlayingView[NowPlayingView.swift]
    NowPlayingView -->|Environment| AudioEngineFacade
  end
  subgraph Core.Audio
    AudioEngineFacade[AudioEngineFacade.swift]
    PlaybackStateManager[PlaybackStateManager.swift]
    AudioQueueManager[AudioQueueManager.swift]
    AudioSessionManager[AudioSessionManager.swift]
    AVAdapter[AVAudioEngineAdapter.swift]
    AudioKitAdapter[AudioKitEngineAdapter.swift]
    FormatDetect[AudioFormatDetectionManager.swift]
    Monitor[AudioMonitor.swift]
    Validator[BitPerfectValidator.swift]
    EngineFactory[AudioEngineFactory.swift]
  end
  subgraph Data (SwiftData)
    DataManager[DataManager.swift]
    TrackDataActor[TrackDataActor.swift]
    RecentSearchesActor[RecentSearchesActor.swift]
    MetadataExtractor[MetadataExtractionService.swift]
    ImportService[LibraryImportService.swift]
    Models[Models/*.swift]
  end

  ContentView --> DataManager
  NowPlayingView --> AudioEngineFacade
  AudioEngineFacade --> PlaybackStateManager
  AudioEngineFacade --> AudioQueueManager
  AudioEngineFacade --> AudioSessionManager
  AudioEngineFacade --> Monitor
  AudioEngineFacade --> Validator
  AudioEngineFacade --> FormatDetect
  AudioEngineFacade --> EngineFactory
  EngineFactory --> AVAdapter
  EngineFactory --> AudioKitAdapter
  ImportService --> TrackDataActor
  ImportService --> MetadataExtractor
  DataManager --> ImportService
  DataManager --> TrackDataActor
  DataManager --> RecentSearchesActor

Key findings (root cause, impact, severity, fixes)
1) Audio session lifecycle fragmentation
- Evidence: Direct session calls in [Swift.AVAudioSession.setActive(_:)](Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:162) and [Swift.AVAudioSession.setActive(_:options:)](Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:224); singleton in adapter vs injected manager in facade.
- Impact: Race conditions, duplicate observers, mis-synced session state across engine swaps.
- Severity: High.
- Fix:
  - Remove direct AVAudioSession usage from adapter; inject AudioSessionManager into adapter constructor.
  - AudioSessionManager provides idempotent configure/activate/deactivate and command enablement. Facade orchestrates order.

2) Debug constructs in runtime flows
- Evidence: [Swift.fatalError()](Fonic HiFi/FonicHiFiApp.swift:43), [Swift.try!](Fonic HiFi/FonicHiFiApp_Debug.swift:14), pervasive [Swift.print()](Fonic HiFi/Presentation/Views/Debug/DebugTrackRowView.swift:35), [Swift.print()](Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingView.swift:152).
- Impact: Crashes in production, performance overhead, console spam.
- Severity: High (fatalError), Medium (print).
- Fix:
  - Replace fatalError with user-facing error and fallback UI; wrap prints with #if DEBUG or swap to os.Logger.

3) Mach telemetry without guards
- Evidence: CPU/memory metrics in [AVAudioEngineAdapter.swift](Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift) rely on Mach APIs without #if canImport(Mach).
- Impact: Build failures or App Store concerns if misused.
- Severity: High.
- Fix: Add #if canImport(Mach) around imports/usage or remove and rely on system metrics via Monitor.

4) Logging fragmentation and shadowing
- Evidence: Custom Logger struct and extension shadowing os.Logger in [AudioEngineFacade.swift](Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift).
- Impact: Inconsistent logs; lost signpost/OSLog benefits.
- Severity: Medium.
- Fix: Replace with os.Logger; standardize subsystems and categories; add signposts around initialize/play/seek/stop.

5) Progress timer task churn
- Evidence: Nested Task and MainActor.run inside timer tick in [AudioEngineFacade.swift](Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift).
- Impact: Extra scheduling; risk of reentrancy.
- Severity: Medium.
- Fix: In the @MainActor timer closure, directly await engine.currentTime/duration and update state synchronously.

6) Engine selection permissiveness
- Evidence: ensureEngineForFormat returns early if an engine exists in [AudioEngineFacade.ensureEngineForFormat](Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift).
- Impact: Incorrect engine retained when formats require different adapters in the future.
- Severity: Medium.
- Fix: Add adapter.canHandle(format) and recreate engine if necessary; persist preference cleanly and only apply when idle.

7) Remote commands not enabled
- Evidence: AudioSessionManager has enableRemoteCommands(), but initialize() doesn’t call it in [AudioEngineFacade](Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift).
- Impact: Control Center and system controls won’t work.
- Severity: Medium.
- Fix: Call enableRemoteCommands() post configure; disable on shutdown.

8) Preview and persistence safety
- Evidence: previewContainer uses fatalError in fallback [Swift.fatalError()](Fonic HiFi/Data/DataManager.swift:423); preview builder may use disk-backed container through the standard initializer.
- Impact: Crashes or accidental disk writes during previews.
- Severity: Medium.
- Fix: In previews, always use in-memory ModelContainer; avoid fatalError, using safe stubs in DEBUG.

9) Export scalability
- Evidence: Int.max-like fetch in export builder in [DataManager.swift](Fonic HiFi/Data/DataManager.swift).
- Impact: Memory spikes on large libraries.
- Severity: Medium.
- Fix: Page through Track entities and stream-encode JSON.

10) Minor correctness
- PlaybackStateManager: duration/time bookkeeping and transition durations should reflect elapsed time between transitions rather than timestamp echo. Confirm and adjust.

Security and configuration
- Background audio is declared in [Info.plist](Fonic HiFi/Info.plist). Ensure session category remains .playback to respect background behavior via manager (not the adapter).
- Entitlements include CloudKit in [Fonic_HiFi.entitlements](Fonic HiFi/Fonic_HiFi.entitlements). If the app “ships without network permissions,” consider removing CloudKit entitlements for least privilege and policy clarity.
- No sensitive usage descriptions present (e.g., microphone)—appropriate since no capture APIs are used.

Performance hotspots and mitigations
- Timer and state update cadence: Use 0.2s or device-adaptive intervals when UI is throttled by thermal state; integrate with AudioMonitor signposts.
- Logging performance: Replace print with os.Logger; use .fault/.error sparingly; guard verbose debug behind builds or runtime flags.
- View recomposition: Large SwiftUI views (e.g., NowPlayingView) are wrapped with a performance-optimized container; keep expensive work off body recomputations and use @State/@ObservedObject carefully.

Actionable refactor sketches
A) Session centralization (adapter removal of direct session calls)
- Remove direct AVAudioSession calls in adapter and rely on manager:
  - Before play: Facade calls sessionManager.configureAudioSession() and sessionManager.activateAudioSession()
  - After stop/shutdown: Facade calls sessionManager.deactivateAudioSession()
  - Remove calls like [Swift.AVAudioSession.setActive(_:)](Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:162) and [Swift.AVAudioSession.setActive(_:options:)](Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:224)

B) Logging unification (Facade example)
- Replace custom Logger:
  - Remove the custom Logger struct/extension in [AudioEngineFacade.swift](Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift)
  - Use os.Logger, e.g., Logger(subsystem: "com.fonichifi.audio", category: "AudioEngineFacade")

C) Timer closure simplification
- In [AudioEngineFacade.swift](Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift), change the timer closure to avoid nested Task per tick; await engine values directly on MainActor and call stateManager.updateTime.

D) Mach guard
- Wrap Mach usage in [AVAudioEngineAdapter.swift](Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift) with #if canImport(Mach) or remove.

Edge cases and resilience
- Missing file path handling already logs; consider surfacing UI errors and optionally batch-clean missing files via DataManager.cleanupMissingFiles() on startup (already called in [Fonic HiFiApp](Fonic HiFi/FonicHiFiApp.swift)).
- Interruption handling: Resumption policy should be user-respecting (don’t auto-resume unexpectedly); current behavior conditionally resumes on shouldResume in [AudioEngineFacade.handleSessionInterruption](Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift).
- Background audio: Confirm remote commands are enabled and NowPlaying info is maintained during background playback.

Estimated effort
- P0: Session lifecycle, logging unification, Mach guards: 1–2 days
- P1: Engine selection/capability, timer simplification, preview safety: 1–1.5 days
- P2: Export paging, remote command wiring, lint cleanup: 0.5–1 day

Evidence index (selected)
- Session direct calls: [Swift.AVAudioSession.setActive(_:)](Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:162), [Swift.AVAudioSession.setActive(_:options:)](Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:224)
- Crash/force: [Swift.fatalError()](Fonic HiFi/FonicHiFiApp.swift:43), [Swift.try!](Fonic HiFi/FonicHiFiApp_Debug.swift:14)
- Print usage: [Swift.print()](Fonic HiFi/Presentation/Views/Debug/DebugTrackRowView.swift:35), [Swift.print()](Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingView.swift:152)
- Concurrency patterns: Extensive @MainActor usage in core types and Task boundaries across modules per prior scans.

Final recommendation
Address P0 items first to stabilize session behavior, logging, and builds, followed by P1 progress/engine improvements and P2 scale/cleanup. This sequence maximizes risk reduction and improves diagnosability while keeping scope controlled for rapid verification with make build, make test-unit, and simulator playback validation.
