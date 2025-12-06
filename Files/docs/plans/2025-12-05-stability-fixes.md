# Stability Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix M4A playback failure, reduce 8.86s launch time to <2s, and eliminate 100% CPU usage when idle.

**Architecture:** Three independent fixes targeting: (1) AudioFormat extension-to-codec mapping, (2) async service initialization with loading UI, (3) playback-state-aware monitoring intervals.

**Tech Stack:** Swift 6.2, SwiftUI, SwiftData, AVFoundation

---

## Task 1: Add M4A Extension Mapping Test (TDD Red Phase)

**Files:**
- Create: `Fonic HiFiTests/AudioFormatTests.swift`

**Step 1: Write the failing test**

```swift
@testable import Fonic_HiFi
import XCTest

final class AudioFormatTests: XCTestCase {
    func testFromURLHandlesM4AExtension() {
        let m4aURL = URL(fileURLWithPath: "/test/song.m4a")
        let format = AudioFormat.from(url: m4aURL)
        XCTAssertEqual(format, .aac, "M4A container should map to AAC codec")
    }

    func testFromURLHandlesMP3Extension() {
        let mp3URL = URL(fileURLWithPath: "/test/song.mp3")
        let format = AudioFormat.from(url: mp3URL)
        XCTAssertEqual(format, .mp3)
    }

    func testFromURLHandlesUnknownExtension() {
        let unknownURL = URL(fileURLWithPath: "/test/song.xyz")
        let format = AudioFormat.from(url: unknownURL)
        XCTAssertNil(format, "Unknown extensions should return nil")
    }
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with `XCTAssertEqual failed: ("nil") is not equal to ("Optional(Fonic_HiFi.AudioFormat.aac)")`

**Step 3: Commit test (red phase)**

```bash
git add "Fonic HiFiTests/AudioFormatTests.swift"
git commit -m "test(audio): add failing test for M4A format detection

🔴 RED phase - test fails because AudioFormat.from(url:) returns nil for .m4a

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2: Fix M4A Extension Mapping (TDD Green Phase)

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Interfaces/AudioFormat.swift:102-105`

**Step 1: Implement the fix**

Replace lines 102-105:

```swift
/// Create AudioFormat from file URL
/// - Parameter url: File URL to analyze
/// - Returns: AudioFormat if recognized, nil otherwise
public static func from(url: URL) -> AudioFormat? {
    let ext = url.pathExtension.lowercased()
    switch ext {
    case "m4a": return .aac
    default: return AudioFormat(rawValue: ext)
    }
}
```

**Step 2: Run test to verify it passes**

Run: `make test`
Expected: All tests PASS including `testFromURLHandlesM4AExtension`

**Step 3: Commit fix (green phase)**

```bash
git add "Fonic HiFi/Core/Audio/Interfaces/AudioFormat.swift"
git commit -m "fix(audio): map M4A container to AAC codec

M4A is a container format that typically holds AAC audio.
AudioFormat.from(url:) was returning nil because the enum
only has codec cases (aac, alac), not container formats.

This fixes playback failure for imported M4A files.

🟢 GREEN phase - test passes

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3: Create AppLoadingView

**Files:**
- Create: `Fonic HiFi/Presentation/Views/App/AppLoadingView.swift`

**Step 1: Write the loading view**

```swift
//
//  AppLoadingView.swift
//  Fonic HiFi
//

import SwiftUI

/// Lightweight loading view shown during async app initialization
struct AppLoadingView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "waveform")
                    .font(.system(size: 64))
                    .foregroundStyle(.white.opacity(0.8))
                    .symbolEffect(.variableColor.iterative)

                Text("Fonic HiFi")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                ProgressView()
                    .tint(.white)
            }
        }
    }
}

#Preview {
    AppLoadingView()
}
```

**Step 2: Verify build succeeds**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/App/AppLoadingView.swift"
git commit -m "feat(ui): add AppLoadingView for async initialization

Lightweight loading view shown during app startup while
services initialize in background.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 4: Add AppLoadingState Enum

**Files:**
- Modify: `Fonic HiFi/FonicHiFiApp.swift:12` (add after imports)

**Step 1: Add the enum before @main**

Insert at line 12 (after imports, before @main):

```swift
/// Tracks app initialization state for async loading
enum AppLoadingState: Sendable {
    case loading
    case ready(DataManager, AudioEngineFacade, LibraryImportService?, ArtworkService?, WidgetDataCoordinator?)
    case failed(Error)
}
```

**Step 2: Verify build succeeds**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "Fonic HiFi/FonicHiFiApp.swift"
git commit -m "feat(app): add AppLoadingState enum for async init

Enables tracking initialization progress:
- .loading: Services initializing in background
- .ready: Services available, show main UI
- .failed: Show error recovery UI

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 5: Refactor FonicHiFiApp to Async Pattern

**Files:**
- Modify: `Fonic HiFi/FonicHiFiApp.swift`

**Step 1: Replace synchronous init with async loading state**

Replace the entire FonicHiFiApp struct (lines 13-463) with:

```swift
@main
struct FonicHiFiApp: App {
    // MARK: - State

    @State private var loadingState: AppLoadingState = .loading
    @State private var showInitializationError = false
    @State private var isUsingFallbackServices = false

    private let logger = Log.logger(.app)
    private let appLaunchStartTime = Date()
    private let performanceMonitor = PerformanceMonitor()

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            rootView
                .task {
                    await initializeServicesAsync()
                }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        switch loadingState {
        case .loading:
            AppLoadingView()
        case let .ready(dataManager, audioService, importService, artworkService, widgetCoordinator):
            mainAppView(
                dataManager: dataManager,
                audioService: audioService,
                importService: importService,
                artworkService: artworkService,
                widgetCoordinator: widgetCoordinator
            )
        case let .failed(error):
            RecoveryUnavailableView(
                launchError: LaunchError(message: error.localizedDescription),
                fallbackError: nil
            )
        }
    }

    private func mainAppView(
        dataManager: DataManager,
        audioService: AudioEngineFacade,
        importService: LibraryImportService?,
        artworkService: ArtworkService?,
        widgetCoordinator: WidgetDataCoordinator?
    ) -> some View {
        ContentView()
            .audioEngine(audioService)
            .dataManager(dataManager)
            .libraryRepository(dataManager.makeLibraryRepository())
            .importService(importService)
            .artworkService(artworkService)
            .modelContext(dataManager.mainContext)
            .modelContainer(dataManager.container)
            .task {
                await initializeAppServices(audioService: audioService, dataManager: dataManager, widgetCoordinator: widgetCoordinator)
            }
            .overlay(alignment: .top) {
                if let recoveryState = dataManager.importRecoveryState {
                    RecoveryModeBanner(state: recoveryState)
                } else if isUsingFallbackServices {
                    RecoveryModeBanner(
                        state: .init(
                            mode: .ephemeralStorage,
                            headline: "Limited Mode Active",
                            message: "Fonic HiFi is using fallback services due to initialization issues.",
                            guidance: "Restart the app after the issue is resolved to return to full functionality."
                        )
                    )
                }
            }
            .alert("Initialization Issue", isPresented: $showInitializationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The app encountered an issue during startup and is running with limited functionality.")
            }
    }

    // MARK: - Async Initialization

    @MainActor
    private func initializeServicesAsync() async {
        logger.info("Starting async service initialization...")

        do {
            // Run DataManager creation off main thread
            let services = try await Task.detached(priority: .userInitiated) {
                try FonicHiFiApp.makePrimaryServicesAsync(performanceMonitor: PerformanceMonitor())
            }.value

            loadingState = .ready(
                services.dataManager!,
                services.audioService,
                services.importService,
                services.artworkService,
                services.widgetCoordinator
            )
            isUsingFallbackServices = services.dataManager?.isFallback ?? false

            let launchDuration = Date().timeIntervalSince(appLaunchStartTime)
            logger.info("Services initialized in \(String(format: "%.2f", launchDuration))s")

        } catch {
            logger.error("Service initialization failed: \(error.localizedDescription)")

            // Try fallback
            let fallback = FonicHiFiApp.makeFallbackServices(
                performanceMonitor: performanceMonitor,
                errorLogger: logger
            )

            if let dataManager = fallback.dataManager {
                loadingState = .ready(
                    dataManager,
                    fallback.audioService,
                    fallback.importService,
                    fallback.artworkService,
                    fallback.widgetCoordinator
                )
                isUsingFallbackServices = true
                showInitializationError = true
            } else {
                loadingState = .failed(error)
            }
        }
    }

    @MainActor
    private func initializeAppServices(
        audioService: AudioEngineFacade,
        dataManager: DataManager,
        widgetCoordinator: WidgetDataCoordinator?
    ) async {
        do {
            try await audioService.initialize()
            logger.info("Audio service initialized")

            IntentDependencyProvider.shared.configure(
                audioEngine: audioService,
                widgetCoordinator: widgetCoordinator
            )

            // Defer startup tasks
            await performDeferredStartupTasks(dataManager: dataManager)

            let launchDuration = Date().timeIntervalSince(appLaunchStartTime)
            await performanceMonitor.recordAppLaunchTime(launchDuration)
            logger.info("App fully ready in \(String(format: "%.2f", launchDuration))s")

        } catch {
            logger.error("Audio initialization failed: \(error.localizedDescription)")
            await performanceMonitor.recordError(error, context: "Audio initialization")
        }
    }

    @MainActor
    private func performDeferredStartupTasks(dataManager: DataManager) async {
        // Delay cleanup by 3 seconds
        Task {
            try? await Task.sleep(for: .seconds(3))
            do {
                let removedCount = try await dataManager.cleanupMissingFiles()
                if removedCount > 0 {
                    logger.info("Cleaned up \(removedCount) missing files")
                }
            } catch {
                logger.error("Cleanup failed: \(error.localizedDescription)")
            }
        }

        // Delay statistics by 5 seconds
        Task {
            try? await Task.sleep(for: .seconds(5))
            do {
                let stats = try await dataManager.getLibraryStatistics()
                logger.info("Library: \(stats.trackCount) tracks, \(stats.albumCount) albums, \(stats.artistCount) artists")
            } catch {
                logger.error("Statistics failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Service Construction (keep existing static methods)

    @MainActor
    static func makePrimaryServicesAsync(performanceMonitor: PerformanceMonitor) throws -> AppServices {
        let dataManager = try DataManager()
        let playbackStateManager = PlaybackStateManager()
        let audioMonitor = AudioMonitor(performanceMonitor: performanceMonitor)
        let queueManager = AudioQueueManager()
        let audioService = AudioEngineFacade(
            stateManager: playbackStateManager,
            queueManager: queueManager,
            monitor: audioMonitor
        )
        let importService = LibraryImportService(
            trackDataActor: dataManager.trackDataActor,
            metadataExtractor: dataManager.metadataExtractor
        )
        let artworkService = ArtworkService(container: dataManager.container)
        let widgetCoordinator = WidgetDataCoordinator(
            stateManager: playbackStateManager,
            queueManager: queueManager,
            artworkService: artworkService
        )
        return AppServices(
            dataManager: dataManager,
            audioService: audioService,
            importService: importService,
            artworkService: artworkService,
            widgetCoordinator: widgetCoordinator,
            recoveryError: nil
        )
    }
}

// MARK: - Supporting Types

struct LaunchError: Identifiable, LocalizedError {
    let id = UUID()
    let message: String
    var errorDescription: String? { message }
}

private extension FonicHiFiApp {
    struct AppServices {
        let dataManager: DataManager?
        let audioService: AudioEngineFacade
        let importService: LibraryImportService?
        let artworkService: ArtworkService?
        let widgetCoordinator: WidgetDataCoordinator?
        let recoveryError: DataManagerError?
    }

    static func makeFallbackServices(
        performanceMonitor: PerformanceMonitor,
        errorLogger: Logger
    ) -> AppServices {
        let playbackStateManager = PlaybackStateManager()
        let audioMonitor = AudioMonitor(performanceMonitor: performanceMonitor)
        let queueManager = AudioQueueManager()
        let audioService = AudioEngineFacade(
            stateManager: playbackStateManager,
            queueManager: queueManager,
            monitor: audioMonitor
        )

        if let fallbackManager = DataManager.makeFallbackDataManager()
            ?? DataManager.makePreviewDataManager() {
            let importService = LibraryImportService(
                trackDataActor: fallbackManager.trackDataActor,
                metadataExtractor: fallbackManager.metadataExtractor
            )
            let artworkService = ArtworkService(container: fallbackManager.container)
            let widgetCoordinator = WidgetDataCoordinator(
                stateManager: playbackStateManager,
                queueManager: queueManager,
                artworkService: artworkService
            )
            return AppServices(
                dataManager: fallbackManager,
                audioService: audioService,
                importService: importService,
                artworkService: artworkService,
                widgetCoordinator: widgetCoordinator,
                recoveryError: nil
            )
        }

        return AppServices(
            dataManager: nil,
            audioService: audioService,
            importService: nil,
            artworkService: nil,
            widgetCoordinator: nil,
            recoveryError: .emergencyFallbackFailed(NSError(domain: "FonicHiFi", code: -1))
        )
    }
}
```

**Step 2: Verify build succeeds**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Verify tests pass**

Run: `make test`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add "Fonic HiFi/FonicHiFiApp.swift"
git commit -m "feat(app): refactor to async initialization pattern

- Replace synchronous init() with async .task{} loading
- Show AppLoadingView immediately on launch
- Run DataManager creation off main thread
- Defer cleanup/statistics tasks by 3-5 seconds
- Fixes 8.86s launch time by unblocking main thread

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 6: Guard debugModelContainer with DEBUG

**Files:**
- Modify: `Fonic HiFi/Data/DataManager+Initialization.swift:195-236`

**Step 1: Wrap debugModelContainer in #if DEBUG**

Replace lines 194-236:

```swift
    #if DEBUG
    /// Test creating a container with minimal models to identify which one is problematic
    static func debugModelContainer() {
        initLogger.info("Starting model container debugging")

        let modelTypes: [(String, any PersistentModel.Type)] = [
            ("Track", Track.self),
            ("Artist", Artist.self),
            ("Album", Album.self),
            ("Playlist", Playlist.self),
            ("RecentSearch", RecentSearch.self),
        ]

        for (name, modelType) in modelTypes {
            do {
                initLogger.info("Testing individual model: \(name)")
                let container = try ModelContainer(for: modelType)
                initLogger.info("✓ \(name) model container created successfully")

                // Test creating a context
                let context = ModelContext(container)
                initLogger.info("✓ \(name) model context created successfully")
            } catch {
                initLogger.error("✗ \(name) model failed: \(error)")
            }
        }

        // Test combinations
        initLogger.info("Testing model combinations...")

        do {
            let container = try ModelContainer(for: Track.self, Artist.self)
            initLogger.info("✓ Track + Artist combination works")
        } catch {
            initLogger.error("✗ Track + Artist combination failed: \(error)")
        }

        do {
            let container = try ModelContainer(for: Track.self, Album.self)
            initLogger.info("✓ Track + Album combination works")
        } catch {
            initLogger.error("✗ Track + Album combination failed: \(error)")
        }
    }
    #endif
```

**Step 2: Update call site in buildContainer**

Modify line 105 in buildContainer to:

```swift
                #if DEBUG
                logger.info("Running model container debugging...")
                debugModelContainer()
                #endif
```

**Step 3: Verify build succeeds**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add "Fonic HiFi/Data/DataManager+Initialization.swift"
git commit -m "perf(data): guard debugModelContainer with DEBUG flag

debugModelContainer() creates 5+ ModelContainers for diagnostic
purposes and adds overhead to the fallback initialization path.
Now only runs in DEBUG builds.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 7: Add Playback-State-Aware Monitoring

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:193`
- Modify: `Fonic HiFi/Core/Audio/Diagnostics/AudioMonitor.swift`

**Step 1: Change default monitoring interval in initialize()**

In `AudioEngineFacade.swift`, change line 193 from:

```swift
await monitor.startMonitoring(updateInterval: 1.0)
```

to:

```swift
// Use 2.0s interval to reduce CPU; monitoring pauses when idle
await monitor.startMonitoring(updateInterval: 2.0)
```

**Step 2: Add pauseMonitoring method to AudioMonitor**

Add after line 50 in AudioMonitor.swift (after the reporter property):

```swift
    /// Pauses monitoring to reduce CPU when idle
    public func pauseMonitoring() async {
        logger.info("Pausing monitoring (idle)")
        await runtime.stopMonitoring()
    }

    /// Resumes monitoring with specified interval
    public func resumeMonitoring(interval: TimeInterval = 2.0) async {
        logger.info("Resuming monitoring with \(interval)s interval")
        await runtime.startMonitoring(every: interval)
    }
```

**Step 3: Verify build succeeds**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add "Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift" "Fonic HiFi/Core/Audio/Diagnostics/AudioMonitor.swift"
git commit -m "perf(audio): reduce monitoring overhead with 2s interval

- Change default monitoring interval from 1.0s to 2.0s
- Add pauseMonitoring() and resumeMonitoring() methods
- Reduces CPU usage when app is idle

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 8: Connect Monitoring to Playback State

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift`

**Step 1: Find setupStateBindings and add monitoring control**

Locate `setupStateBindings()` method and add state observation:

```swift
// Inside setupStateBindings(), add:
stateManager.$currentState
    .receive(on: DispatchQueue.main)
    .sink { [weak self] state in
        guard let self else { return }
        Task { @MainActor in
            switch state.status {
            case .playing:
                await self.monitor.resumeMonitoring(interval: 2.0)
            case .paused, .stopped:
                await self.monitor.pauseMonitoring()
            default:
                break
            }
        }
    }
    .store(in: &cancellables)
```

**Step 2: Verify build succeeds**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Run all tests**

Run: `make test`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add "Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift"
git commit -m "perf(audio): pause monitoring when playback stops

Connect monitoring lifecycle to playback state:
- Start monitoring when playing
- Pause monitoring when paused/stopped
- Eliminates 100% CPU usage when idle

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 9: Final Verification

**Step 1: Run full test suite**

Run: `make test`
Expected: All 282+ tests PASS

**Step 2: Build release**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Manual verification checklist**

- [ ] Launch app - should show loading UI immediately
- [ ] Loading UI transitions to main content in <2s
- [ ] Import an M4A file
- [ ] Tap M4A file to play - should work
- [ ] Play an MP3 - should work
- [ ] Pause playback - CPU should drop significantly
- [ ] Resume playback - monitoring resumes

**Step 4: Final commit**

```bash
git add -A
git commit -m "chore: stability fixes complete

Fixes:
- P0: M4A playback now works (map .m4a to .aac codec)
- P1: Launch time reduced from 8.86s to <2s (async init)
- P2: CPU usage drops when idle (playback-aware monitoring)

All 282+ tests pass.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Summary

| Task | Description | Time |
|------|-------------|------|
| 1 | Add M4A test (red) | 3 min |
| 2 | Fix M4A mapping (green) | 2 min |
| 3 | Create AppLoadingView | 3 min |
| 4 | Add AppLoadingState enum | 2 min |
| 5 | Refactor to async init | 15 min |
| 6 | Guard debugModelContainer | 3 min |
| 7 | Add monitoring pause/resume | 5 min |
| 8 | Connect to playback state | 5 min |
| 9 | Final verification | 10 min |
| **Total** | | **~48 min** |
