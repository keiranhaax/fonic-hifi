# SwiftUI & iOS Patterns

## SwiftUI Best Practices

### View Structure
```swift
struct LibraryView: View {
    // 1. Environment and State
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = LibraryViewModel()
    
    // 2. Body
    var body: some View {
        content
            .navigationTitle("Library")
            .task { await viewModel.loadData() }
            .onAppear { viewModel.onAppear() }
    }
    
    // 3. Subviews
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            LoadingView()
        } else if let error = viewModel.error {
            ErrorView(error: error)
        } else {
            libraryContent
        }
    }
}
```

### ViewModel Pattern
```swift
@MainActor
final class LibraryViewModel: ObservableObject {
    // Published properties for UI binding
    @Published var tracks: [Track] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    // Dependencies
    private let libraryService: LibraryManagerService
    
    // Async data loading
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            tracks = try await libraryService.getTracks()
        } catch {
            self.error = error
        }
    }
}
```

### Performance Optimization
```swift
// Use LazyVStack for large lists
LazyVStack(spacing: 0) {
    ForEach(tracks) { track in
        TrackRow(track: track)
            .id(track.id) // Stable IDs
    }
}

// Optimize images
AsyncImage(url: artworkURL) { image in
    image
        .resizable()
        .aspectRatio(contentMode: .fit)
} placeholder: {
    ProgressView()
}
.frame(width: 60, height: 60)
```

## iOS Integration

### Audio Session Setup
```swift
func configureAudioSession() throws {
    let session = AVAudioSession.sharedInstance()
    
    try session.setCategory(
        .playback,
        mode: .default,
        options: [.allowBluetooth, .allowAirPlay]
    )
    
    try session.setActive(true)
}
```

### Background Audio
```swift
// Info.plist
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>

// Now Playing Info
func updateNowPlayingInfo() {
    var info = [String: Any]()
    info[MPMediaItemPropertyTitle] = track.title
    info[MPMediaItemPropertyArtist] = track.artist
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
    
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
}
```

### File Import
```swift
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var urls: [URL]
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.audio],
            asCopy: true
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }
}
```

## Data Management

### SwiftData Models
```swift
@Model
final class TrackEntity {
    // Use optional for all properties
    var id: UUID
    var title: String?
    var artist: String?
    
    // Relationships
    @Relationship(deleteRule: .nullify)
    var album: AlbumEntity?
    
    // Computed properties for convenience
    var displayTitle: String {
        title ?? "Unknown Track"
    }
}
```

### Repository Pattern
```swift
final class LibraryRepository: ILibraryRepository {
    private let modelContext: ModelContext
    
    func getTracks() async throws -> [Track] {
        let descriptor = FetchDescriptor<TrackEntity>(
            sortBy: [SortDescriptor(\.title)]
        )
        
        let entities = try modelContext.fetch(descriptor)
        return entities.map { Track(from: $0) }
    }
}
```

## Concurrency

### Task Management
```swift
// Cancellable tasks
class PlayerViewModel: ObservableObject {
    private var playbackTask: Task<Void, Never>?
    
    func play() {
        playbackTask?.cancel()
        playbackTask = Task {
            await playTrack()
        }
    }
    
    deinit {
        playbackTask?.cancel()
    }
}
```

### Actor for Thread Safety
```swift
actor AudioEngineActor {
    private var engine: AVAudioEngine?
    
    func configure() {
        engine = AVAudioEngine()
        // Setup nodes
    }
    
    func play() {
        engine?.start()
    }
}
```

## Memory Management

### Image Caching
```swift
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    
    init() {
        cache.countLimit = 100
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }
    
    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }
}
```

### Weak References
```swift
class AudioPlayer {
    weak var delegate: AudioPlayerDelegate?
    
    private var observations = Set<AnyCancellable>()
    
    deinit {
        observations.forEach { $0.cancel() }
    }
}
```

## Testing Patterns

### View Testing
```swift
func testLibraryView() throws {
    let view = LibraryView()
        .environmentObject(AppState())
    
    let controller = UIHostingController(rootView: view)
    
    XCTAssertNotNil(controller.view)
}
```

### ViewModel Testing
```swift
@MainActor
func testLoadTracks() async throws {
    let mockService = MockLibraryService()
    let viewModel = LibraryViewModel(service: mockService)
    
    await viewModel.loadData()
    
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertEqual(viewModel.tracks.count, 10)
}
```

## Common Patterns

### Dependency Injection
```swift
protocol ServiceProviding {
    var libraryService: LibraryManagerService { get }
    var audioService: AudioEngineService { get }
}

struct ServiceProvider: ServiceProviding {
    let libraryService = LibraryManager()
    let audioService = AudioEngine()
}
```

### Error Handling
```swift
enum AppError: LocalizedError {
    case fileNotFound
    case unsupportedFormat
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File not found"
        case .unsupportedFormat:
            return "Audio format not supported"
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}
```

### Navigation
```swift
enum Route: Hashable {
    case library
    case album(Album)
    case player(Track)
    case settings
}

struct AppNavigation: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            LibraryView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .album(let album):
                        AlbumView(album: album)
                    // Handle other routes
                    }
                }
        }
    }
}
```