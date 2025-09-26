# Fonic HiFi Codebase Guide

## 1. Introduction
Fonic HiFi is an iOS 26 SwiftUI application for iPhone (defaulting to the iPhone 16 Pro simulator) focused on delivering lossless, bit-perfect playback for very large local music libraries (100k+ tracks) with aspirational support for USB DAC detection, gapless transitions, waveform visualizations, and import automation. Multiple AI-led audits (Amp, Codex, Gemini, GPT‑5, Grok, Opus, Qwen, Supernova, Zai) converge on a three-layer architecture (`Core/Audio`, `Data`, `Presentation`) powered by Swift 6.2, SwiftData, Combine, AVAudioEngine/AudioKit adapters, and structured concurrency. The repository currently contains ~100 Swift files (~25k LOC) organized under `Fonic HiFi/`, with supplemental plans and specs under `plan2/` and `Files/`.

### Key Patterns and Conventions
- **Concurrency**: Heavy reliance on `@MainActor`, `Task { @MainActor in }`, `ModelActor`, and TaskGroups; several agents flag overuse of main-actor confinement for I/O-heavy flows.
- **State management**: `AudioEngineFacade` orchestrates playback via `PlaybackStateManager`, `AudioQueueManager`, and `AudioSessionManager`; SwiftData models are accessed through actors (`TrackDataActor`, `RecentSearchesActor`).
- **Error handling**: Fatal errors and `try!` persist in startup and debug paths; logging mixes a custom `Logger` wrapper and `os.Logger`.
- **Testing**: Tests exist structurally (`Fonic HiFiTests/`, `Fonic HiFiUITests/`), yet multiple analyses report zero or minimal coverage.

## 2. Project Structure
The top-level layout emphasizes a clean separation between runtime code, assets, and planning materials.

```text
Fonic-HiFi/
├── Fonic HiFi/                  # Main iOS target sources
│   ├── Core/Audio/              # Engine facade, adapters, services, diagnostics
│   ├── Data/                    # SwiftData models, actors, services
│   ├── Presentation/            # SwiftUI environments, views, components
│   ├── Utils/                   # Shared helpers (e.g., MainActor utilities)
│   ├── Assets.xcassets/         # Design assets and icons
│   ├── FonicHiFiApp*.swift      # Entry points (prod & debug)
│   └── Info.plist, entitlements # App configuration
├── Fonic HiFi.xcodeproj/        # Xcode project/workspace metadata
├── plan2/                       # AI-generated plans, PRDs, roadmaps
│   └── agents/                  # Source of this guide and nine analytical reports
├── Plan/, Files/, sample/       # Supplemental specs, fixtures, demos
└── Makefile                     # Build/test automation commands
```

### Folder Highlights (AI Insights)
- **`Core/Audio/`**: Provides the playback pipeline. Amp and GPT‑5 call out actor isolation issues in `AudioSessionManager.swift`, heavy main-thread work in `AudioEngineFacade.swift`, and duplicated session ownership between the facade and adapters.
- **`Core/Audio/Engines/`**: Houses `AVAudioEngineAdapter` and `AudioKitEngineAdapter`. GPT‑5 and Opus recommend guarding Mach APIs and centralizing session activation here.
- **`Core/Audio/Playback/`**: `PlaybackStateManager`, `PlaybackState`, and `PlaybackStateStore` manage state transitions. Codex and Zai recommend normalizing transitions, batching progress updates, and making publishers private.
- **`Data/Models/`**: SwiftData entities (`Album`, `Artist`, `Track`, etc.). Gemini, Fixes, and Grok note missing `@Relationship` annotations and placeholder computed properties, making relationship queries non-functional.
- **`Data/Services/`**: Metadata import/export workflows; multiple agents spot synchronous file I/O on `@MainActor` and missing transactional rollback.
- **`Presentation/Views/`**: SwiftUI screens using environment-injected services. Supernova and Opus caution about overuse of `@MainActor` and debug prints.
- **`plan2/agents/`**: Ten AI analyses sourcing this guide; each focuses on concurrency, performance, security, or architectural refinement.

## 3. Core Components and Modules
### 3.1 Audio Subsystem (`Core/Audio/`)
1. **AudioEngineFacade (@MainActor)**
   - Entry point for playback commands (`initialize`, `play`, `pause`, `seek`).
   - Coordinates `AudioSessionManager`, `AudioQueueManager`, `PlaybackStateManager`, and engine adapters.
   - **Action steps**:
     1. Inspect lifecycle methods (`initialize`, `shutdown`) for remote command enablement (missing per GPT‑5).
     2. Review `ProgressTimerManager` integration; Amp and GPT‑5 advise replacing nested `Task` creation with direct `await` on `@MainActor`.
     3. Replace the custom `Logger` shadow with `os.Logger(subsystem:category:)` for unified logging.

2. **AudioSessionManager**
   - Manages AVAudioSession categories, interruptions, remote commands.
   - **Known issues** (Amp): ObjC selector handlers dispatch to `DispatchQueue.main.async` then fire `Task`—violates Swift 6 actor rules.
   - **Fix workflow**:
     - Replace `DispatchQueue.main.async` with `Task { @MainActor in ... }`.
     - Ensure `enableRemoteCommands` is called during facade initialization.

3. **AudioQueueManager**
   - Maintains playback queue, shuffle/repeat modes.
   - **Optimization opportunities** (Codex, Zai): Preserve original `Track` identity (store `PersistentIdentifier`), cache shuffle sequence, add queue persistence, guard index mutations.

4. **Engine Adapters** (`AVAudioEngineAdapter`, `AudioKitEngineAdapter`)
   - Provide concrete playback backends.
   - **Checklist**:
     - Guard Mach telemetry (`#if canImport(Mach)`) per GPT‑5.
     - Route session activation/deactivation through `AudioSessionManager` to prevent duplicate observers.
     - Dispatch audio callbacks with `Task { @MainActor in ... }` to maintain UI/state safety (Gemini).

### 3.2 Data Layer (`Data/`)
1. **SwiftData Models**
   - Entities for tracks, albums, artists, playlists, recent searches.
   - **Immediate tasks** (Fixes, Gemini): Add `@Relationship` macros linking `Album/Artist` to `Track`; implement computed properties (trackCount, totalDuration) using real relationships.

2. **DataManager (@MainActor)**
   - Central access point for SwiftData contexts, library statistics, exports.
   - **Step-by-step analysis**:
     1. Audit functions for `Int.max` fetches; implement pagination or streaming (GPT‑5).
     2. Move intensive stats/exports onto background contexts (Codex).
     3. Provide preview builders that rely on in-memory stores (GPT‑5, Supernova).

3. **LibraryImportService**
   - Imports files, extracts metadata, persists tracks via `TrackDataActor`.
   - **Remediation sequence** (Codex, Fixes, Amp):
     1. Remove `@MainActor` annotation or delegate file I/O to a background actor.
     2. Wrap security-scoped resource access correctly (Codex).
     3. Reverse copy/commit order or add rollback to avoid orphaned files (Gemini).

4. **TrackDataActor (@ModelActor)**
   - Manages CRUD operations for tracks.
   - **Guidance**: Provide async file operations (`FileManager` checks) to avoid blocking main thread (Amp).

### 3.3 Presentation Layer (`Presentation/`)
- **Environments**: `AudioEnvironment`, `NowPlayingEnvironment` set up dependency injection.
- **Views**: `LibraryView`, `NowPlayingView`, `SearchView`, `SettingsView` etc.
- **AI notes**:
  - Service-based DI currently bypasses dedicated view models; Amp suggests adopting explicit MVVM for testability.
  - Debug components contain `print` statements; GPT‑5 & Supernova recommend gating under `#if DEBUG` or unified logging.
  - Custom “Liquid Glass” components intentionally replace Apple’s glass effect; Fixes confirm design rationale and recommend documenting it.

### 3.4 Utilities (`Utils/`, `Core/Audio/Diagnostics/`)
- `MainActorHelpers.swift` ensures main-thread dispatch.
- Diagnostics include `AudioMonitor`, `BitPerfectValidator`—both ship full implementations; ensure their metrics feed surfaces like dashboards and alerts (Codex, GPT‑5).

## 4. Dependencies and Environment Setup
### 4.1 Toolchain & Frameworks
| Dependency | Notes |
|------------|-------|
| Xcode 26.x + iOS 26 SDK | Required for Swift 6.2 concurrency features and iPhone simulator support.
| Swift 6.2 | Concurrency enforcement triggers reported actor violations.
| SwiftData | Persistence layer; missing relationships are current blockers.
| AVFoundation / AVAudioEngine | Primary playback engine.
| AudioKit (optional) | Alternative adapter requiring thread-safe bridging.
| Combine | Used for state publishers; must be contained to main actor.
| Makefile targets | `make build`, `make test-unit`, `make test-ui`, `make lint`, `make format`, `make run` (README instructions).

### 4.2 Setup Steps
1. **Install Tooling**
   - Xcode 16+ from Apple Developer portal.
   - Command-line tools (`xcode-select --install`).
2. **Clone Repository**
   - `git clone git@github.com:<org>/Fonic-HiFi.git`
3. **Install Swift Package Dependencies**
   - Open project in Xcode (`make open`) to resolve Swift Package Manager dependencies.
4. **Configure Simulator**
   - Use iPhone 16 Pro, iOS 26.0 as default per Makefile.
5. **Run Build/Test**
   - `make build`
   - `make test-unit` (may fail until coverage is implemented; track failures per Amp/Opus).
6. **Lint & Format**
   - `make lint`
   - `make format`
7. **Environment Variables & Entitlements**
   - Review `Fonic_HiFi.entitlements` (Gemini, GPT‑5 note CloudKit entry vs privacy stance); remove unused capabilities before signing.

### 4.3 Configuration Tips
- Centralize audio session configuration by injecting a single `AudioSessionManager` instance (GPT‑5).
- Remove `fatalError` paths in app initialization—use user-visible error screens and fallback modes (GPT‑5, Opus, Supernova).
- Guard preview data builders to avoid Swift 6 Sendable violations (Grok’s build failure report).

## 5. Key Algorithms and Logic
### 5.1 Playback Lifecycle
Pseudo-workflow synthesized from `AudioEngineFacade` and agent guidance:

```pseudo
initializeFacade():
  sessionManager.configureSession()
  sessionManager.enableRemoteCommands()
  queueManager.restoreQueueIfAvailable()
  stateManager.transition(to: .idle)

play(track):
  ensureEngineForFormat(track.format)
  queueManager.focus(on: track)
  stateManager.transition(.loading(track))
  engine.load(track)
  engine.play()
  startProgressTimer()
  stateManager.transition(.playing(currentTime: 0, duration: track.duration))
```

**Optimization Steps** (Codex, GPT‑5, Zai):
1. Add capability check before reusing an existing engine to handle differing formats.
2. Batch progress timer updates to ~0.2s and avoid nested `Task` to reduce actor churn.
3. Record transitions via helper `transition(next:allowingSame:)` to enforce valid state graph (Codex).

### 5.2 Queue Management
```pseudo
updateShuffleSequence():
  if shuffleModeChanged:
    shuffleSequence = fisherYates(range: tracks.count)
    move currentIndex to front if needed
```

**Enhancements** (Zai): cache shuffle sequences, maintain `trackIndexMap` for O(1) removals, persist queue to disk for resume.

### 5.3 Import Pipeline
```pseudo
importFiles(urls):
  for url in urls:
    worker.copyIntoSandbox(url)
    metadata = extractor.extractTrackMetadata(copiedURL)
    if trackExists(copiedURL):
      skip
    dataActor.createTrack(metadata)
    updateProgress()
```

**Fix Plan** (Codex, Gemini, Amp):
1. Start security scope only when required; always stop if started.
2. Move heavy I/O off `@MainActor` using background actors.
3. Commit metadata atomically before copying files or add rollback for failure cases.
4. Implement async file existence checks to keep UI responsive.

### 5.4 Diagnostics & Validation
- Use `BitPerfectValidator` to confirm hardware capabilities; currently returns placeholders—wire to actual AVAudioSession sample rate/bus info (Codex).
- Replace custom `Logger` wrappers with `os.Logger` and add signposts for playback phases.

## 6. Testing and Quality Assurance
### Current State
- Agents (Amp, Opus, Grok, Supernova) report negligible test coverage; UI automation exists structurally but lacks cases.

### Recommended Strategy
1. **Unit Tests**
   - Focus on `PlaybackStateManager`, `AudioQueueManager`, `AudioEngineFacade` transitions.
   - Example stub (Amp):
     ```swift
     @Test func audioEngineStateTransitions() async throws {
         let facade = TestAudioEngineFacade()
         try await facade.initialize()
         try await facade.play(track: mockTrack)
         #expect(facade.isPlaying)
     }
     ```
2. **Integration Tests**
   - Validate import pipeline (metadata extraction + track persistence) using in-memory SwiftData containers.
3. **UI Tests**
   - Cover launch, library browsing, playback controls, DAC detection UI; integrate `make test-ui` into CI.
4. **CI/CD**
   - Add GitHub Actions or Xcode Cloud steps running `make lint`, `make test-unit`, `make test-ui`.
5. **Coverage Goals**
   - Short term: 50% for audio/data modules.
   - Long term: 80–90% across core subsystems (Amp roadmap).

## 7. Documentation and Maintenance
### Contribution Workflow
1. **Branching**
   - Create feature branches via `make pr-create` or git CLI.
2. **Implementation**
   - Follow Swift 6 coding conventions (two-space indent, `// MARK:` boundaries, explicit access control).
   - Favor `final` classes and `Sendable` models.
3. **Testing & Validation**
   - Run `make build`, `make test-unit`, `make lint`; attach logs for known flaky tests.
4. **Code Review**
   - Request reviewers familiar with touched area (audio vs presentation) as per repository guidelines.
   - Address concurrency risks and format handling in PR description (per PR template expectations).
5. **Documentation Updates**
   - Update `README`, architecture docs, and this guide when adding new modules or correcting analyses.
   - Note rationales for custom UI components (per Fixes’ findings on Liquid Glass).
6. **Version Control Practices**
   - Commits should be atomic with imperative subject lines (<72 chars).
   - Avoid committing licensed audio; keep sample libraries local.

### Maintenance Backlog (AI-sourced)
- Remove CloudKit entitlements if unused (Gemini, GPT‑5).
- Convert fatal paths to recoverable flows with user-friendly messaging (GPT‑5, Opus, Supernova).
- Standardize logging across modules (GPT‑5, Codex).
- Document engine selection rules and performance modes for clarity (Fixes roadmap).

## 8. Troubleshooting and FAQs
| Question | Resolution |
|----------|------------|
| **Why does the build fail with "Sendable conformance" errors in previews?** | Convert static preview data instances to computed properties returning fresh model instances (Grok). Ensure preview builders use in-memory data stores and avoid non-Sendable singletons (GPT‑5). |
| **Remote commands (Control Center/lock screen) do nothing. How do I fix this?** | In `AudioEngineFacade.initialize()`, call `await audioSessionManager.enableRemoteCommands()`. Ensure delegate callbacks use `Task { @MainActor in ... }` to avoid actor violations (Amp, GPT‑5). |
| **Imports duplicate tracks or leave orphaned files.** | Normalize duplicate detection to the destination URL, treat security-scoped access as optional, and wrap metadata persistence + file copy in a transaction or rollback routine (Codex, Gemini). |
| **Playback stutters or UI freezes during large imports.** | Offload import processing to a dedicated actor or background queue; batch progress updates; throttle timer to 0.2s (Codex, Amp, Zai). |
| **Why do `fatalError` crashes still occur on startup?** | Replace `fatalError` in `FonicHiFiApp.swift` and `DataManager.swift` with thrown errors handled by an error scene or alert (GPT‑5, Opus, Supernova). |
| **How should I fix thread-safety warnings about Combine subjects?** | Make `statePublisher`/`transitionPublisher` private and expose main-thread `AnyPublisher`s (`receive(on: RunLoop.main)`), preventing off-main sends (Amp). |
| **What steps reduce memory leaks in adapters?** | Cancel timers in `deinit`, release AudioKit resources in a cleanup method invoked via `Task` on actor destruction, and ensure `[weak self]` capture in timers (Opus, GPT‑5, Supernova). |
| **How do I restore queue state across launches?** | Serialize `QueueState` (tracks, index, modes) before shutdown, store in SwiftData via `QueueState` model, reload during initialization (Zai). |

## 9. Appendices
### 9.1 Glossary
- **Bit-Perfect Playback**: Audio pipeline guaranteeing no resampling from source to DAC.
- **SwiftData**: Apple’s declarative persistence framework introduced in Swift 6.
- **ModelActor**: Concurrency feature that encapsulates SwiftData context to maintain isolation.
- **Liquid Glass**: Custom SwiftUI design system replicating Apple’s glass effect with optimized performance.

### 9.2 Recommended Refactor Roadmap (Synthesized)
1. **Week 1** (Amp, GPT‑5): Fix actor isolation in `AudioSessionManager`, privatize Combine publishers, audit `@MainActor` usage, guard Mach APIs, remove `fatalError`, standardize logging.
2. **Week 2–3** (Codex, Fixes, Zai): Refactor import pipeline off main actor, implement SwiftData relationships, optimize queue/state transitions, enable remote commands, add lazy loading & caching.
3. **Week 4** (Supernova, Gemini): Establish unit/integration UI tests, add performance monitoring, remove overstated entitlements, document liquid glass system.

### 9.3 Performance Benchmarks (Targets)
- **Crash rate**: <0.1% (Amp).
- **App launch time**: <2 seconds (Amp).
- **Audio latency**: <50 ms (Amp).
- **Memory usage**: <200 MB standard operation (Amp).
- **Library search latency**: <150 ms for 100k tracks (Fixes).

### 9.4 External References
- Apple Swift 6 Concurrency Guide (`sosumi`) for actor best practices.
- AudioKit documentation for background thread callbacks.
- Apple Human Interface Guidelines (Liquid Glass, iOS 26 updates) referenced in `/Plan` and `/Files`.

---
**Maintainers**: Update this document whenever major architectural changes, dependency updates, or troubleshooting discoveries occur. Link related PRs and issue IDs for traceability.
