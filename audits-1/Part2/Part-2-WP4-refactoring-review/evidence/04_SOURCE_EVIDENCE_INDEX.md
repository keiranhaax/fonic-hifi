# Work Package 4 source evidence index

Repository baseline: `main` at `459db9bfd18d17960e8fd2ff8defc4701085532e`.

This index contains the source evidence used to retain or reject refactoring candidates. Previous audit reports were treated as leads only. Every excerpt below was re-read in the repository checkout.

## WP4-R01 — Consolidate the SwiftUI audio presentation-state boundary

### Active dependency path

- `Fonic HiFi/FonicHiFiApp.swift:103-110` injects the live `AudioEngineFacade` into `ContentView`.
- `Fonic HiFi/ContentView.swift:58-78` builds the mini-player and Now Playing UI from that injected object.
- `Fonic HiFi/Presentation/Views/Queue/QueueView.swift:11,31-49` reads nested queue state from the same object.

### Evidence

`Fonic HiFi/Presentation/Environment/AudioEnvironment.swift:14-23`

```swift
struct AudioEngineKey: EnvironmentKey {
    static let defaultValue: AudioEngineFacade? = nil
}

extension EnvironmentValues {
    var audioEngine: AudioEngineFacade? {
        get { self[AudioEngineKey.self] }
        set { self[AudioEngineKey.self] = newValue }
    }
}
```

`Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:40-45,64-69`

```swift
public var currentState: PlaybackState { stateCoordinator.currentState }
public var queueState: QueueState { stateCoordinator.queueState }
public var isPlaying: Bool { currentState.isPlaying }
public var playbackProgress: Double { currentState.progress ?? 0.0 }
public var currentTime: TimeInterval { currentState.currentTime ?? 0.0 }
public var duration: TimeInterval { currentState.duration ?? 0.0 }
...
@Published public private(set) var currentTrack: Track?
@Published public private(set) var showMiniPlayer: Bool = false
@Published public private(set) var diagnosticsStatus: DiagnosticsStatus = .empty
@Published public var abLoopState = ABLoopState()
```

The frequently changing playback and queue values are computed through `PlaybackStateManager` and `AudioQueueManager`, while only a different subset is manually proxied through Combine.

`Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:555-569`

```swift
uiStateStore.$currentTrack
    .receive(on: RunLoop.main)
    .sink { [weak self] track in self?.currentTrack = track }
...
uiStateStore.$diagnosticsStatus
    .receive(on: RunLoop.main)
    .sink { [weak self] status in self?.diagnosticsStatus = status }
```

`Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:23-50`

```swift
@State private var isFavorite = false
@State private var playbackSpeed: Double = 1.0
@AppStorage("volume") private var volumeStorage: Double = 1.0
@AppStorage("isShuffleEnabled") private var isShuffleEnabled: Bool = false
@AppStorage("repeatMode") private var repeatModeRawValue: String = QueueRepeatMode.none.rawValue
```

`Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift:660-679`

```swift
let newMode: QueueShuffleMode = isShuffleEnabled ? .off : .random
audioService.setShuffleMode(newMode)
isShuffleEnabled = newMode != .off
...
let newMode: QueueRepeatMode = switch repeatMode { ... }
audioService.setRepeatMode(newMode)
repeatModeRawValue = newMode.rawValue
```

`Fonic HiFi/Presentation/Views/Queue/QueueView.swift:31-49`

```swift
if let current = audioService?.queueManager.queueState.currentTrack { ... }
...
let remaining = audioService?.queueManager.queueState.remainingTracks ?? []
```

### Test boundary observed

- `AudioEngineFacadeOrchestratorTests.swift:88-113` verifies `setCurrentTrack` propagation.
- No tracked test references `NowPlayingContent`.
- No tracked test verifies SwiftUI invalidation when `PlaybackStateManager` or `AudioQueueManager` changes under the custom environment key.

### Official source used

Apple, “Managing model data in your app”: https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app. Apple states that a SwiftUI view forms dependencies by reading properties of an observable model and updates when those tracked properties change. The page also documents type-based environment injection for observable models.

Apple, “Optimize SwiftUI performance with Instruments,” WWDC25 session 306: https://developer.apple.com/videos/play/wwdc2025/306/. Apple demonstrates that broad observation dependencies can cause unnecessary body updates and recommends scoping dependencies to the state a view actually uses.

## WP4-R02 — Separate queue mutation from notification and persistence side effects

### Active dependency path

`Fonic HiFi/FonicHiFiApp.swift:324,360,393` constructs `AudioQueueManager`; the manager is passed through `AudioEngineFacade`, playback coordination, widget coordination, intents, and queue UI.

### Evidence

`Fonic HiFi/Core/Audio/Queue/AudioQueueManager.swift:326-338`

```swift
tracks = newTracks
originalOrder = newTracks
...
currentIndex = startIndex
markNavigationStateDirty()
notifyTracksChanged()
notifyCurrentTrackChanged()
```

`Fonic HiFi/Core/Audio/Queue/AudioQueueManager.swift:655-664`

```swift
private func notifyTracksChanged() {
    delegate?.audioQueue(self, didUpdateTracks: tracks)
    saveState()
}

private func notifyCurrentTrackChanged() {
    delegate?.audioQueue(self, didChangeCurrentTrack: currentTrack, at: currentIndex)
    saveState()
}
```

A single `replaceQueue` operation therefore invokes the full persistence path twice.

`Fonic HiFi/Core/Audio/Queue/QueueState.swift:321-326,359-365,399-400`

```swift
let data = try encoder.encode(self)
UserDefaults.standard.set(data, forKey: Self.persistenceKey)
...
let validTracks = tracks.filter { track in
    FileManager.default.fileExists(atPath: track.url.path)
}
...
history: history.filter { track in
    FileManager.default.fileExists(atPath: track.url.path)
}
```

### Test boundary observed

- `AudioQueueManagerTests.swift:157-188` checks delegate counts for mutations.
- `AudioQueueManagerTests.swift:292-311` checks save/restore behavior.
- No test injects a persistence collaborator or asserts one persistence request per logical mutation.

## WP4-R03 — Give each library section explicit request ownership and load phase

### Active dependency path

`Fonic HiFi/ContentView.swift:33-39` creates `LibraryView` with `LibraryViewModel`; this is the active Library tab.

### Evidence

`Fonic HiFi/Presentation/ViewModels/Library/LibraryViewModel.swift:33-44`

```swift
private struct PaginationState<Item: Sendable> {
    var items: [Item] = []
    var nextPage: Int = 0
    var hasMore: Bool = true
    var isLoading: Bool = false
    var lastQuery: String?
}

private var trackState = PaginationState<TrackEntity>()
private var albumState = PaginationState<AlbumEntity>()
private var artistState = PaginationState<ArtistEntity>()
private var playlistState = PaginationState<PlaylistEntity>()
```

`Fonic HiFi/Presentation/ViewModels/Library/LibraryViewModel.swift:143-188`

```swift
private func fetchPage<Item>(state: PaginationState<Item>, ...) async -> PaginationState<Item> {
    if state.isLoading { return state }
    var nextState = state
    ...
    nextState.isLoading = true
    isLoadingSection = section
    let page = try await loader(targetPage, effectiveQuery)
    ...
    nextState.isLoading = false
    return nextState
}
```

The owning `trackState`, `albumState`, `artistState`, or `playlistState` is assigned only after the awaited function returns. A second request can therefore read the old stored state while the first request owns only a local `nextState`. There is no task handle or request generation to prevent an older query result from being assigned after a newer query.

`Fonic HiFi/Presentation/Views/Library/LibraryView.swift:162-177,336-369`

```swift
.onChange(of: selectedTab) { _, newValue in
    Task { @MainActor in
        await refresh(for: newValue)
    }
}
...
searchTask = Task { @MainActor in
    try? await Task.sleep(for: .milliseconds(300))
    guard !Task.isCancelled else { return }
    await refresh(for: tab)
}
```

`Fonic HiFi/Presentation/Views/Library/LibraryView.swift:301-309` maps the one `isLoadingSection` value to a full-screen loading message, while each section also renders a tail spinner.

### Test boundary observed

`LibraryViewModelTests.swift` contains four sequential pagination/error/query tests. It does not test overlapping queries, out-of-order completion, cancellation, concurrent section loads, or distinct initial-versus-pagination phases.

## WP4-R04 — Extract file-system operations and state from FileManagerView

### Active dependency path

`Fonic HiFi/Presentation/Views/Settings/SettingsView.swift:112-123` navigates to `FileManagerView` from the active Settings tab.

### Evidence

`Fonic HiFi/Presentation/Views/Settings/FileManagerView.swift:25-34`

```swift
@State private var currentDirectory: URL = FileManagerView.defaultDirectory
@State private var directoryContents: [FileItem] = []
@State private var selectedItems: Set<FileItem> = []
@State private var isLoading = false
@State private var showingDeleteConfirmation = false
@State private var showingFileImporter = false
@State private var searchText = ""
@State private var sortOption: SortOption = .name
@State private var showingDetails = false
@State private var selectedFileForDetails: FileItem?
```

`Fonic HiFi/Presentation/Views/Settings/FileManagerView.swift:195-233`

```swift
let contents = try FileManager.default.contentsOfDirectory(at: currentDirectory, includingPropertiesForKeys: [...])
...
let resourceValues = try url.resourceValues(forKeys: [...])
...
} catch {
    logger.error("Failed to load directory contents ...")
}
```

`Fonic HiFi/Presentation/Views/Settings/FileManagerView.swift:265-275`

```swift
for item in selectedItems {
    do {
        try FileManager.default.removeItem(at: item.url)
    } catch {
        logger.error("Failed to delete file ...")
    }
}
selectedItems.removeAll()
```

`Fonic HiFi/Presentation/Views/Settings/FileManagerView.swift:309-343` performs security-scope handling and detached copy work inside the view. `FileManagerView.swift:366-395` presents a UIKit alert by walking `UIApplication.shared.connectedScenes` from the SwiftUI view.

### Test boundary observed

No tracked test references `FileManagerView`. The direct singleton file-system access, detached task, and UIKit presentation make the file operations difficult to test without the UI and real filesystem.

## WP4-R05 — Create one TrackDataActor insertion kernel before splitting responsibilities

### Active dependency path

`TrackDataActor` has 32 token references across 13 product/test files. It is created by `DataManager`, used by the import pipeline, listening-session service, smart search, and tests.

### Evidence

`Fonic HiFi/Data/Actors/TrackDataActor.swift` contains 1,218 physical lines, 39 function declarations, 18 catch blocks, and public groups for creation, queries, updates, listening sessions, and recommendation support.

`TrackDataActor.swift:262-311` and `TrackDataActor.swift:318-370` independently repeat the same sequence:

```swift
let resolvedArtist = resolvedArtistName(metadata.artist)
let resolvedAlbum = resolvedAlbumTitle(metadata.album)
let resolvedAlbumArtist = resolvedAlbumArtistName(...)
let track = Track(...)
applyTrackMetadata(metadata, to: track)
modelContext.insert(track)
_ = try linkAlbumArtistRelationships(...)
```

The single method saves one track; the batch method repeats the mapping and relationship logic and saves once after the loop. This creates two change points for the same persisted representation.

### Test boundary observed

`TrackDataActorTests.swift:6-64` separately exercises single creation, batch creation, and relationship creation. These tests provide a characterization base, but there is no parameterized parity test proving that single and batch paths persist identical metadata and relationships.

## WP4-R06 — Own AsyncStream producer lifetime and cancellation in FileImportProcessor

### Active dependency path

`LibraryImportService.swift:62-65` constructs `FileImportProcessor`; `LibraryImportService.swift:228-231` consumes its processing stream in the active import flow.

### Evidence

`Fonic HiFi/Data/Actors/FileImportProcessor.swift:102-105`

```swift
func discoverAudioFilesStream(from urls: [URL]) -> AsyncStream<DiscoveredAudioFile> {
    AsyncStream { continuation in
        Task { await self.emitDiscoveredFiles(from: urls, to: continuation) }
    }
}
```

`FileImportProcessor.swift:143-155`

```swift
return AsyncStream<ProcessedFileResult> { continuation in
    Task {
        await Self.emitProcessedFiles(..., to: continuation)
    }
}
```

`FileImportProcessor.swift:237-256` uses the same unowned producer-task pattern for the failure stream. None of the three builders assigns `continuation.onTermination` or retains the producer task for cancellation.

The outer service does own an `importTask` and a `discoveryTask` (`LibraryImportService.swift:49,90-105,193-225`), but cancellation of the consumer does not explicitly own or cancel all inner producer tasks.

### Test boundary observed

`FileImportProcessorTests.swift` covers successful, duplicate, mixed-result, directory-discovery, async-sequence, and aggregate flows. It contains no cancellation/early-consumer-termination test. `LibraryImportServiceTests.swift:40` tests service cancellation, not producer termination inside `FileImportProcessor`.

### Official source used

Apple, `AsyncStream.Continuation.onTermination`: https://developer.apple.com/documentation/swift/asyncstream/continuation/ontermination. The documentation states that task cancellation invokes `onTermination` and that the callback is the place to perform required cleanup.

Apple, `AsyncStream`: https://developer.apple.com/documentation/swift/asyncstream. Apple’s example sets `continuation.onTermination` to stop the underlying producer.

## WP4-R07 — Use one process-metrics provider instead of Mach probes inside the audio engine

### Active dependency path

`AVAudioEngineAdapter` is a production engine adapter. `SystemMetricsCollector` is used by `AudioMonitor` and has dedicated collector tests.

### Evidence

`Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:404-417`

```swift
let cpuUsage = getCurrentCPUUsage()
let memoryUsage = getCurrentMemoryUsage()
return AudioMetrics(cpuUsage: cpuUsage, memoryUsage: memoryUsage, ...)
```

`AVAudioEngineAdapter.swift:585-634` contains two direct `task_info` implementations. Its CPU method derives a percentage from `mach_task_basic_info.resident_size`:

```swift
return Float(info.resident_size) / Float(1024 * 1024 * 1024) * 100
```

`Fonic HiFi/Core/Audio/Diagnostics/SystemMetricsCollector.swift:301-350` already owns system CPU and memory collection, including delta-based CPU ticks and the same resident-memory query.

### Test boundary observed

`AVAudioEngineAdapterTests.swift:109-117` asserts only that metrics are nonnegative. `AudioMonitoringCollectorsTests.swift:74-105` exercises the dedicated collector. The adapter cannot inject a metrics source, so tests cannot prove that its values come from the canonical collector.

## WP4-R08 — Compile one canonical app/widget contract

### Active dependency path

The app writes the contract through `WidgetDataCoordinator` and `AppGroupManager`; the widget reads it through `NowPlayingEntry` and widget views.

### Evidence

The following app/widget pairs are identical from source line 8 onward; only their file header comments differ:

- `Fonic HiFi/Shared/WidgetConstants.swift` and `Fonic HiFi Widget/Shared/WidgetConstants.swift`
- `Fonic HiFi/Shared/WidgetPlaybackState.swift` and `Fonic HiFi Widget/Shared/WidgetPlaybackState.swift`
- `Fonic HiFi/Shared/WidgetTrackInfo.swift` and `Fonic HiFi Widget/Shared/WidgetTrackInfo.swift`

Exact hashes and unified diffs are in `03_WIDGET_CONTRACT_COMPARISON.md`.

`Fonic HiFi.xcodeproj/project.pbxproj:79-104,183-185,236-248` shows separate file-system-synchronized app and widget roots, which explains why the same declarations currently compile in separate modules.

### Test boundary observed

The app test target contains `WidgetPlaybackStateTests` and `WidgetTrackInfoTests`, but there is no cross-target fixture proving that an app-encoded payload decodes through independently compiled widget declarations and vice versa. Separate source copies can drift without a compiler error.

## Rejected or deferred candidates

### RC-01 — Split the two largest diagnostics model files because they are large

Rejected as size-only. `PlaybackDiagnosticModels.swift` has 1,252 lines but 60 data/enum declarations and no functions, tasks, file I/O, or state wrappers. `AudioMonitoringService.swift` has 910 lines but 34 data/enum declarations and no executable functions. File organization may be improved opportunistically, but the scan found no high-value behavior-preserving refactor justified by size alone.

### RC-02 — Split the AVAudioEngine graph implementation because the adapter is 707 lines

Rejected as a broad first move. Graph setup, format reconnection, gapless preparation, EQ, playback completion, and state are tightly coupled and device-sensitive. Only the process-metrics concern in WP4-R07 is sufficiently isolated for a safe first extraction. Broader graph changes require Xcode, audio fixtures, and device testing.

### RC-03 — Move LibraryView’s private row/detail types into separate files

Rejected as a standalone recommendation. `LibraryView.swift` is 818 lines and contains 14 type declarations, but moving private view structs without fixing request ownership, load phases, or test boundaries would be navigation-only churn. Component extraction is acceptable only as a mechanical step within WP4-R03 and must preserve behavior and identity.

### RC-04 — Extract the smart-playlist evaluator from PlaylistDetailView now

Deferred to Work Package 5 reachability/cleanup assessment. `PlaylistDetailView` is referenced only by `PlaylistListView` and `SearchPlaylistResultsView`; `PlaylistListView` is referenced only by its preview, and `SearchPlaylistResultsView` has no external reference. Refactoring this code before deciding whether the orphaned path remains would invest in potentially removable code.

### RC-05 — Consolidate ImportSession with FileImportProcessor in Work Package 4

Deferred to Work Package 5. `ImportSession` is referenced by its own tests but has no production constructor/reference, while `LibraryImportService` actively constructs `FileImportProcessor`. The first decision is whether `ImportSession` is obsolete, not how to refactor both implementations.

### RC-06 — Split GlassModifiers.swift because it exceeds 500 lines

Rejected as size-only. The file is an aggregation of small, independently named SwiftUI modifiers and does not show the state ownership, I/O, or concurrency coupling required for a high-value refactor in this work package.
