# Fonic HiFi Best Practices Guide

## Overview

This guide establishes coding standards, architectural patterns, and development practices for the Fonic HiFi project. It synthesizes learnings from the codebase analysis and aligns with the CLAUDE.md excellence rules.

## Swift 6 & Concurrency Best Practices

### Actor Isolation Guidelines

#### 1. **Clear Actor Boundaries**

```swift
// ✅ CORRECT: Explicit actor isolation
@MainActor
final class NowPlayingViewModel: ObservableObject {
    @Published private(set) var currentTrack: Track?
    private let audioEngine: AudioEngineActor
    
    func play() async {
        // Explicit async boundary when crossing actors
        await audioEngine.startPlayback()
    }
}

// ✅ CORRECT: Dedicated actor for audio processing
actor AudioEngineActor {
    private var engine: AVAudioEngine
    
    func startPlayback() {
        // All audio processing isolated here
    }
}

// ❌ WRONG: Mixed responsibilities
class BadViewModel {
    var engine: AVAudioEngine // Direct engine access
    
    func play() {
        DispatchQueue.global().async {
            self.engine.start() // Thread safety nightmare
        }
    }
}
```

#### 2. **Sendable Conformance**

```swift
// ✅ CORRECT: Immutable data crossing actors
struct TrackInfo: Sendable {
    let id: UUID
    let title: String
    let duration: TimeInterval
}

// ✅ CORRECT: Thread-safe reference type
final class AudioBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer: AVAudioPCMBuffer
    
    func read() -> AVAudioPCMBuffer {
        lock.withLock { buffer }
    }
}

// ❌ WRONG: Mutable reference without protection
class BadTrackInfo {
    var title: String // Mutable without synchronization
}
```

### Error Handling Patterns

#### 1. **Typed Errors with Context**

```swift
// ✅ CORRECT: Specific, informative errors
enum AudioEngineError: LocalizedError {
    case formatNotSupported(codec: String, supportedFormats: [String])
    case deviceNotAvailable(deviceID: String)
    case bufferAllocationFailed(size: Int, availableMemory: Int)
    
    var errorDescription: String? {
        switch self {
        case .formatNotSupported(let codec, let supported):
            return "Format '\(codec)' not supported. Supported formats: \(supported.joined(separator: ", "))"
        case .deviceNotAvailable(let deviceID):
            return "Audio device '\(deviceID)' is not available"
        case .bufferAllocationFailed(let size, let available):
            return "Failed to allocate \(size) bytes (available: \(available))"
        }
    }
}

// ❌ WRONG: Generic errors without context
enum BadError: Error {
    case somethingWentWrong
    case invalidFormat
}
```

#### 2. **Error Recovery Strategies**

```swift
// ✅ CORRECT: Graceful error handling with recovery
func playTrack(_ track: Track) async {
    do {
        try await primaryEngine.play(track)
    } catch AudioEngineError.formatNotSupported {
        // Try fallback engine
        do {
            try await fallbackEngine.play(track)
        } catch {
            // Notify user with actionable message
            showError("Unable to play \(track.format) files. Consider converting to supported format.")
        }
    } catch {
        // Log for debugging
        logger.error("Playback failed: \(error)")
        // Show user-friendly error
        showError("Playback failed. Please try again.")
    }
}
```

### Memory Management

#### 1. **Weak References in Closures**

```swift
// ✅ CORRECT: Prevent retain cycles
class AudioPlayer {
    private var progressTimer: Timer?
    
    func startProgressUpdates() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updateProgress()
        }
    }
    
    deinit {
        progressTimer?.invalidate()
    }
}

// ❌ WRONG: Strong reference cycle
class BadPlayer {
    var timer: Timer?
    
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.update() // Strong reference to self
        }
    }
}
```

## SwiftUI Best Practices

### View Composition

#### 1. **Small, Focused Views**

```swift
// ✅ CORRECT: Decomposed views
struct NowPlayingView: View {
    @StateObject private var viewModel = NowPlayingViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            AlbumArtworkView(track: viewModel.currentTrack)
            TrackInfoView(track: viewModel.currentTrack)
            PlaybackControlsView(viewModel: viewModel)
            ProgressView(viewModel: viewModel)
        }
    }
}

// Individual components
private struct AlbumArtworkView: View {
    let track: Track?
    
    var body: some View {
        // Focused on just artwork display
    }
}

// ❌ WRONG: Monolithic view
struct BadNowPlayingView: View {
    var body: some View {
        VStack {
            // 200+ lines of nested views
            // Complex logic mixed with UI
            // Impossible to test or reuse
        }
    }
}
```

#### 2. **State Management Hierarchy**

```swift
// ✅ CORRECT: Clear ownership and data flow
struct LibraryView: View {
    @StateObject private var libraryState = LibraryState() // Owns state
    
    var body: some View {
        NavigationStack {
            LibraryContent(
                tracks: libraryState.tracks,
                onTrackSelected: libraryState.selectTrack
            )
        }
    }
}

struct LibraryContent: View {
    let tracks: [Track] // Read-only data
    let onTrackSelected: (Track) -> Void // Action callback
    
    var body: some View {
        // Pure view, no business logic
    }
}
```

### Performance Optimization

#### 1. **Lazy Loading**

```swift
// ✅ CORRECT: Efficient list rendering
struct TrackListView: View {
    let tracks: [Track]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(tracks) { track in
                    TrackRowView(track: track)
                        .frame(height: 72)
                }
            }
        }
    }
}

// ✅ CORRECT: On-demand image loading
struct AlbumArtView: View {
    let artworkURL: URL?
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .task {
                        await loadImage()
                    }
            }
        }
    }
    
    private func loadImage() async {
        guard let url = artworkURL else { return }
        image = await ImageCache.shared.image(for: url)
    }
}
```

#### 2. **View Identity and Diffing**

```swift
// ✅ CORRECT: Stable identities for smooth animations
struct PlaylistView: View {
    let playlists: [Playlist]
    
    var body: some View {
        ForEach(playlists) { playlist in
            PlaylistRow(playlist: playlist)
                .id(playlist.id) // Stable identity
        }
    }
}

// ✅ CORRECT: Equatable for expensive views
struct WaveformView: View, Equatable {
    let audioData: AudioData
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.audioData.id == rhs.audioData.id
    }
    
    var body: some View {
        // Expensive waveform rendering
        // Only re-renders when audioData actually changes
    }
}
```

## Architecture Patterns

### Dependency Injection

```swift
// ✅ CORRECT: Protocol-based dependencies
protocol AudioEngineProtocol {
    func play(_ track: Track) async throws
    func pause()
    func stop()
}

@MainActor
final class NowPlayingViewModel: ObservableObject {
    private let audioEngine: AudioEngineProtocol
    private let dataService: DataServiceProtocol
    
    // Testable with mock dependencies
    init(
        audioEngine: AudioEngineProtocol = AudioEngine.shared,
        dataService: DataServiceProtocol = DataService.shared
    ) {
        self.audioEngine = audioEngine
        self.dataService = dataService
    }
}

// ✅ CORRECT: Environment injection for system-wide deps
struct FonicHiFiApp: App {
    let audioEngine = AudioEngine.shared
    let dataService = DataService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioEngine)
                .environmentObject(dataService)
        }
    }
}
```

### Service Layer Design

```swift
// ✅ CORRECT: Single responsibility services
protocol MetadataServiceProtocol {
    func extractMetadata(from url: URL) async throws -> TrackMetadata
}

final class MetadataService: MetadataServiceProtocol {
    func extractMetadata(from url: URL) async throws -> TrackMetadata {
        // Focused on just metadata extraction
    }
}

// ✅ CORRECT: Composition of services
final class LibraryImportService {
    private let metadataService: MetadataServiceProtocol
    private let storageService: StorageServiceProtocol
    private let validationService: ValidationServiceProtocol
    
    func importFile(_ url: URL) async throws -> Track {
        // Validate file
        try await validationService.validate(url)
        
        // Extract metadata
        let metadata = try await metadataService.extractMetadata(from: url)
        
        // Store in library
        return try await storageService.store(url, metadata: metadata)
    }
}
```

## Testing Best Practices

### Unit Testing Patterns

```swift
// ✅ CORRECT: Comprehensive test with mocks
final class AudioEngineTests: XCTestCase {
    var sut: AudioEngineFacade!
    var mockEngine: MockAudioEngine!
    var mockStateManager: MockStateManager!
    
    override func setUp() {
        super.setUp()
        mockEngine = MockAudioEngine()
        mockStateManager = MockStateManager()
        sut = AudioEngineFacade(
            engine: mockEngine,
            stateManager: mockStateManager
        )
    }
    
    func testPlayStartsPlayback() async throws {
        // Given
        let track = Track.fixture()
        mockEngine.playResult = .success(())
        
        // When
        try await sut.play(track)
        
        // Then
        XCTAssertEqual(mockEngine.playCallCount, 1)
        XCTAssertEqual(mockEngine.lastPlayedTrack, track)
        XCTAssertEqual(mockStateManager.currentState, .playing)
    }
    
    func testPlayHandlesEngineFailure() async {
        // Given
        let track = Track.fixture()
        mockEngine.playResult = .failure(AudioError.engineFailure)
        
        // When/Then
        await assertThrowsError {
            try await sut.play(track)
        } errorHandler: { error in
            XCTAssertEqual(error as? AudioError, .engineFailure)
            XCTAssertEqual(mockStateManager.currentState, .error)
        }
    }
}
```

### Integration Testing

```swift
// ✅ CORRECT: Real component integration
final class AudioPlaybackIntegrationTests: XCTestCase {
    func testEndToEndPlayback() async throws {
        // Given
        let audioEngine = AudioEngine()
        let testFile = Bundle.test.url(forResource: "test", withExtension: "mp3")!
        
        // When
        try await audioEngine.load(testFile)
        try await audioEngine.play()
        
        // Then
        XCTAssertTrue(audioEngine.isPlaying)
        
        // Wait for playback
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Verify progress
        XCTAssertGreaterThan(audioEngine.currentTime, 0)
        XCTAssertLessThan(audioEngine.currentTime, audioEngine.duration)
    }
}
```

## Code Quality Standards

### Documentation

```swift
// ✅ CORRECT: Comprehensive documentation
/// Manages audio playback with support for multiple formats and bit-perfect output.
///
/// The facade coordinates between different audio engines based on format capabilities
/// and system resources. It ensures thread-safe state management and provides a
/// unified API for the UI layer.
///
/// Example usage:
/// ```swift
/// let facade = AudioEngineFacade()
/// try await facade.play(track)
/// ```
///
/// - Note: All methods must be called from the main actor context.
public final class AudioEngineFacade: ObservableObject {
    /// The current playback state.
    /// Published to trigger UI updates when state changes.
    @Published public private(set) var state: PlaybackState = .stopped
    
    /// Starts playback of the specified track.
    /// - Parameter track: The track to play.
    /// - Throws: `AudioError` if playback cannot be started.
    /// - Complexity: O(1) for cached formats, O(n) for format detection.
    public func play(_ track: Track) async throws {
        // Implementation
    }
}
```

### Code Organization

```swift
// ✅ CORRECT: Logical grouping with extensions
// MARK: - AudioEngineFacade+Playback.swift
extension AudioEngineFacade {
    func play(_ track: Track) async throws { }
    func pause() { }
    func stop() { }
}

// MARK: - AudioEngineFacade+Queue.swift
extension AudioEngineFacade {
    func enqueue(_ track: Track) { }
    func skipToNext() async throws { }
    func skipToPrevious() async throws { }
}

// MARK: - AudioEngineFacade+State.swift
extension AudioEngineFacade {
    func saveState() async throws { }
    func restoreState() async throws { }
}
```

## Performance Guidelines

### Benchmarking

```swift
// ✅ CORRECT: Performance measurement
func measureImportPerformance() {
    let files = Array(repeating: testFile, count: 1000)
    
    measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
        let importer = LibraryImporter()
        Task {
            await importer.import(files)
        }
    }
}

// ✅ CORRECT: Runtime performance tracking
func trackPerformance<T>(
    operation: String,
    threshold: TimeInterval = 0.1,
    block: () async throws -> T
) async rethrows -> T {
    let start = CFAbsoluteTimeGetCurrent()
    defer {
        let duration = CFAbsoluteTimeGetCurrent() - start
        if duration > threshold {
            logger.warning("\(operation) took \(duration)s (threshold: \(threshold)s)")
        }
        Analytics.track(.performanceMetric, properties: [
            "operation": operation,
            "duration": duration
        ])
    }
    return try await block()
}
```

## Security & Privacy

### Data Protection

```swift
// ✅ CORRECT: No data collection
final class Analytics {
    static func track(_ event: AnalyticsEvent, properties: [String: Any] = [:]) {
        #if DEBUG
        // Only log in debug builds
        print("Analytics: \(event) - \(properties)")
        #endif
        // No actual tracking in production
    }
}

// ✅ CORRECT: Secure file handling
func importFile(from url: URL) async throws {
    // Verify file access permissions
    guard url.startAccessingSecurityScopedResource() else {
        throw ImportError.accessDenied
    }
    defer { url.stopAccessingSecurityScopedResource() }
    
    // Validate file before processing
    try validateFile(at: url)
    
    // Process with sandboxed access
    try await processFile(url)
}
```

## Debugging & Logging

```swift
// ✅ CORRECT: Structured logging
import OSLog

extension Logger {
    static let audio = Logger(subsystem: "com.fonichifi", category: "Audio")
    static let ui = Logger(subsystem: "com.fonichifi", category: "UI")
    static let data = Logger(subsystem: "com.fonichifi", category: "Data")
}

// Usage
Logger.audio.debug("Starting playback for track: \(track.id)")
Logger.audio.error("Playback failed: \(error.localizedDescription)")

// ✅ CORRECT: Debug-only assertions
#if DEBUG
extension AudioEngine {
    func validateState() {
        assert(Thread.isMainThread, "Must be called on main thread")
        assert(engine.isRunning || state == .stopped, "Invalid state")
    }
}
#endif
```

## Conclusion

These best practices ensure Fonic HiFi maintains high code quality, performance, and reliability. Regular code reviews should verify adherence to these standards. As the project evolves, this guide should be updated to reflect new learnings and patterns.