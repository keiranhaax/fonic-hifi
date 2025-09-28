# Fonic HiFi Technical Specification

> **Archived (2025-09):** This specification references deprecated SFBAudioEngine/FFmpeg plans and is kept for historical context.

## File System

The Fonic HiFi application follows a modular architecture with clear separation of concerns. The file system structure is designed to support maintainability, testability, and scalability.

## Front-End Repository Structure

```
FonicHiFi/
├── [ACTUAL: SwiftUI @main App Structure]
│   ├── FonicHiFiApp.swift              # Main app entry point (@main)
│   ├── [NOT IMPLEMENTED] AppDelegate.swift
│   ├── [NOT IMPLEMENTED] SceneDelegate.swift
│   └── [NOT IMPLEMENTED] AppConfiguration.swift
│
├── Presentation/                       # Presentation Layer
│   ├── Views/                         # SwiftUI Views
│   │   ├── Library/                   # Library browsing views
│   │   │   ├── LibraryView.swift     # Main library view
│   │   │   ├── ArtistListView.swift  # Artists browsing view
│   │   │   ├── AlbumListView.swift   # Albums browsing view
│   │   │   ├── [NOT IMPLEMENTED] GenreListView.swift
│   │   │   ├── TrackListView.swift   # Tracks browsing view [IMPLEMENTED]
│   │   │   ├── [NOT IMPLEMENTED] QualityFilterView.swift
│   │   │   └── Components/           # Reusable library components
│   │   │
│   │   ├── Player/                    # Playback interface views
│   │   │   ├── PlayerView.swift      # Main player view
│   │   │   ├── MiniPlayerView.swift  # Mini player for navigation
│   │   │   ├── WaveformView.swift    # Audio waveform visualization
│   │   │   ├── PlaybackControlsView.swift # Playback controls
│   │   │   ├── QueueView.swift       # Playback queue management
│   │   │   └── Components/           # Reusable player components
│   │   │
│   │   ├── Playlists/                 # Playlist management views
│   │   │   ├── PlaylistsView.swift   # Playlists overview
│   │   │   ├── PlaylistDetailView.swift # Individual playlist view
│   │   │   ├── SmartPlaylistEditorView.swift # Smart playlist editor
│   │   │   └── Components/           # Reusable playlist components
│   │   │
│   │   ├── Metadata/                  # Metadata editing views
│   │   │   ├── MetadataEditorView.swift # Metadata editor main view
│   │   │   ├── BatchEditorView.swift # Batch editing interface
│   │   │   ├── ArtworkEditorView.swift # Artwork management
│   │   │   └── Components/           # Reusable metadata components
│   │   │
│   │   ├── Settings/                  # App settings views
│   │   │   ├── SettingsView.swift    # Main settings view
│   │   │   ├── AudioSettingsView.swift # Audio configuration
│   │   │   ├── LibrarySettingsView.swift # Library management
│   │   │   ├── AppearanceSettingsView.swift # UI customization
│   │   │   └── Components/           # Reusable settings components
│   │   │
│   │   └── Common/                    # Shared UI components
│   │       ├── AudioQualityBadge.swift # Audio quality indicator
│   │       ├── LoadingView.swift     # Loading state view
│   │       ├── ErrorView.swift       # Error state view
│   │       └── ...                   # Other shared components
│   │
│   ├── ViewModels/                    # MVVM ViewModels
│   │   ├── Library/                   # Library ViewModels
│   │   │   ├── LibraryViewModel.swift # Main library ViewModel
│   │   │   ├── ArtistListViewModel.swift # Artists ViewModel
│   │   │   ├── AlbumListViewModel.swift # Albums ViewModel
│   │   │   └── ...                   # Other library ViewModels
│   │   │
│   │   ├── Player/                    # Player ViewModels
│   │   │   ├── PlayerViewModel.swift # Main player ViewModel
│   │   │   ├── WaveformViewModel.swift # Waveform visualization ViewModel
│   │   │   └── ...                   # Other player ViewModels
│   │   │
│   │   ├── Playlists/                 # Playlist ViewModels
│   │   │   ├── PlaylistsViewModel.swift # Playlists ViewModel
│   │   │   ├── SmartPlaylistViewModel.swift # Smart playlist ViewModel
│   │   │   └── ...                   # Other playlist ViewModels
│   │   │
│   │   ├── Metadata/                  # Metadata ViewModels
│   │   │   ├── MetadataEditorViewModel.swift # Metadata editor ViewModel
│   │   │   └── ...                   # Other metadata ViewModels
│   │   │
│   │   └── Settings/                  # Settings ViewModels
│   │       ├── SettingsViewModel.swift # Settings ViewModel
│   │       └── ...                   # Other settings ViewModels
│   │
│   └── UIState/                       # UI State Management
│       ├── [REMOVED - Merged into AudioEngineFacade] AppState.swift
│       ├── [NOT IMPLEMENTED] NavigationState.swift
│       └── [NOT IMPLEMENTED] ThemeManager.swift
│
├── Domain/                            # Domain Layer
│   ├── Models/                        # Domain Models
│   │   ├── Track.swift               # Audio track model
│   │   ├── Album.swift               # Album model
│   │   ├── Artist.swift              # Artist model
│   │   ├── Playlist.swift            # Playlist model
│   │   ├── SmartPlaylist.swift       # Smart playlist model
│   │   ├── AudioFormat.swift         # Audio format model
│   │   └── ...                       # Other domain models
│   │
│   ├── UseCases/                      # Business Logic Use Cases
│   │   ├── Library/                   # Library use cases
│   │   │   ├── ImportMusicUseCase.swift # Music import logic
│   │   │   ├── ScanLibraryUseCase.swift # Library scanning logic
│   │   │   └── ...                   # Other library use cases
│   │   │
│   │   ├── Playback/                  # Playback use cases
│   │   │   ├── PlayTrackUseCase.swift # Track playback logic
│   │   │   ├── QueueManagementUseCase.swift # Queue management logic
│   │   │   └── ...                   # Other playback use cases
│   │   │
│   │   ├── Playlists/                 # Playlist use cases
│   │   │   ├── CreatePlaylistUseCase.swift # Playlist creation logic
│   │   │   ├── SmartFilterUseCase.swift # Smart filtering logic
│   │   │   └── ...                   # Other playlist use cases
│   │   │
│   │   └── Metadata/                  # Metadata use cases
│   │       ├── EditMetadataUseCase.swift # Metadata editing logic
│   │       ├── BatchEditUseCase.swift # Batch editing logic
│   │       └── ...                   # Other metadata use cases
│   │
│   └── Interfaces/                    # Repository Interfaces
│       ├── ILibraryRepository.swift  # Library repository interface
│       ├── IPlaybackRepository.swift # Playback repository interface
│       ├── IPlaylistRepository.swift # Playlist repository interface
│       └── IMetadataRepository.swift # Metadata repository interface
│
├── Data/                              # Data Layer
│   ├── Repositories/                  # Repository Implementations
│   │   ├── LibraryRepository.swift   # Library repository implementation
│   │   ├── PlaybackRepository.swift  # Playback repository implementation
│   │   ├── PlaylistRepository.swift  # Playlist repository implementation
│   │   └── MetadataRepository.swift  # Metadata repository implementation
│   │
│   ├── DataSources/                   # Data Sources
│   │   ├── Local/                     # Local data sources
│   │   │   ├── SwiftDataSource.swift # SwiftData source
│   │   │   ├── FileSystemDataSource.swift # File system source
│   │   │   └── UserDefaultsDataSource.swift # User defaults source
│   │   │
│   │   └── Remote/                    # Remote data sources (future)
│   │       ├── CloudDataSource.swift # Cloud storage source
│   │       └── StreamingDataSource.swift # Streaming service source
│   │
│   ├── DTOs/                          # Data Transfer Objects
│   │   ├── TrackDTO.swift            # Track data transfer object
│   │   ├── AlbumDTO.swift            # Album data transfer object
│   │   └── ...                       # Other DTOs
│   │
│   └── Mappers/                       # Data Mappers
│       ├── TrackMapper.swift         # Track entity-model mapper
│       ├── AlbumMapper.swift         # Album entity-model mapper
│       └── ...                       # Other mappers
│
├── Core/                              # Core Services
│   ├── Audio/                         # Audio Engine Services
│   │   ├── AudioEngine/               # Audio playback engine
│   │   │   ├── AudioEngineService.swift # Main audio engine service
│   │   │   ├── AVAudioEngineAdapter.swift # AVAudioEngine adapter
│   │   │   ├── SFBAudioEngineAdapter.swift # SFBAudioEngine adapter
│   │   │   └── FFmpegAdapter.swift   # FFmpeg adapter
│   │   │
│   │   ├── AudioProcessing/           # Audio processing services
│   │   │   ├── EqualizerService.swift # Equalizer implementation
│   │   │   ├── GainControlService.swift # Gain control implementation
│   │   │   └── WaveformGeneratorService.swift # Waveform generation
│   │   │
│   │   └── AudioSession/              # Audio session management
│   │       ├── AudioSessionService.swift # iOS audio session service
│   │       └── HardwareDetectionService.swift # DAC detection service
│   │
│   ├── Metadata/                      # Metadata Services
│   │   ├── TagParserService.swift    # Audio tag parsing service
│   │   ├── TagWriterService.swift    # Audio tag writing service
│   │   └── CueSheetService.swift     # CUE sheet parsing service
│   │
│   ├── FileSystem/                    # File System Services
│   │   ├── FileManagerService.swift  # File management service
│   │   ├── ImportService.swift       # File import service
│   │   └── StorageMonitorService.swift # Storage monitoring service
│   │
│   └── Background/                    # Background Processing
│       ├── BackgroundTaskService.swift # Background task service
│       └── IndexingService.swift     # Background indexing service
│
├── Utils/                             # Utilities
│   ├── Extensions/                    # Swift extensions
│   │   ├── SwiftUI+Extensions.swift  # SwiftUI extensions
│   │   ├── Foundation+Extensions.swift # Foundation extensions
│   │   └── ...                       # Other extensions
│   │
│   ├── Helpers/                       # Helper utilities
│   │   ├── Logger.swift              # Logging utility
│   │   ├── ErrorHandler.swift        # Error handling utility
│   │   └── ...                       # Other helpers
│   │
│   └── Constants/                     # Constants
│       ├── AppConstants.swift        # App-wide constants
│       ├── UIConstants.swift         # UI-related constants
│       └── ...                       # Other constants
│
├── Resources/                         # App Resources
│   ├── Assets.xcassets/              # Image assets
│   ├── Localizable.strings           # Localization strings
│   └── Info.plist                    # App info property list
│
└── Tests/                             # Test Suite
    ├── UnitTests/                     # Unit tests
    │   ├── Domain/                    # Domain layer tests
    │   ├── Data/                      # Data layer tests
    │   └── Core/                      # Core services tests
    │
    ├── IntegrationTests/              # Integration tests
    │   ├── AudioEngineTests/          # Audio engine integration tests
    │   └── ...                       # Other integration tests
    │
    └── UITests/                       # UI tests
        ├── LibraryUITests/            # Library UI tests
        ├── PlayerUITests/             # Player UI tests
        └── ...                       # Other UI tests
```

## Back-End Repository Structure (Audio Processing Libraries)

For specialized audio processing that may be developed as separate modules or frameworks:

```
FonicHiFiAudioKit/
├── Sources/
│   ├── AudioFormats/                  # Audio Format Support
│   │   ├── FLACDecoder.swift         # FLAC decoding implementation
│   │   ├── ALACDecoder.swift         # ALAC decoding implementation
│   │   ├── DSDDecoder.swift          # DSD decoding implementation
│   │   └── ...                       # Other format decoders
│   │
│   ├── DSP/                           # Digital Signal Processing
│   │   ├── Equalizer/                 # Equalizer implementation
│   │   │   ├── EqualizerNode.swift   # Equalizer processing node
│   │   │   └── EqualizerPresets.swift # Equalizer presets
│   │   │
│   │   ├── GainControl/               # Gain control implementation
│   │   │   ├── GainNode.swift        # Gain processing node
│   │   │   └── ReplayGain.swift      # ReplayGain implementation
│   │   │
│   │   └── Effects/                   # Audio effects (future)
│   │       ├── CrossfadeProcessor.swift # Crossfade implementation
│   │       └── ...                   # Other effects
│   │
│   ├── Analysis/                      # Audio Analysis
│   │   ├── WaveformGenerator.swift   # Waveform generation
│   │   ├── SpectrumAnalyzer.swift    # Spectrum analysis
│   │   └── ...                       # Other analysis tools
│   │
│   └── Hardware/                      # Hardware Integration
│       ├── DACDetector.swift         # DAC detection implementation
│       ├── OutputConfigurator.swift  # Output configuration
│       ├── BitPerfectValidatorService.swift # Service to validate bit-perfect output
│       └── ...                       # Other hardware integrations
│
├── Dependencies/                      # Third-party Dependencies
│   ├── FFmpegKit/                    # FFmpeg integration
│   ├── SFBAudioEngine/               # SFBAudioEngine integration
│   └── TagLib/                       # TagLib integration
│
└── Tests/                             # Test Suite
    ├── AudioFormatsTests/             # Format decoder tests
    ├── DSPTests/                      # DSP tests
    └── ...                           # Other tests
```

## Database Schema (SwiftData)

```swift
// Core data models for SwiftData
@Model
class TrackEntity {
    var id: UUID
    var title: String
    var artist: String
    var albumTitle: String
    var albumArtist: String?
    var composer: String?
    var genre: String?
    var year: Int?
    var trackNumber: Int?
    var discNumber: Int?
    var duration: Double
    var filePath: String
    var fileSize: Int64
    var dateAdded: Date
    var dateModified: Date
    var playCount: Int
    var lastPlayed: Date?
    var format: String
    var bitDepth: Int?
    var sampleRate: Int?
    var bitrate: Int?
    var isLossless: Bool
    var isHiRes: Bool
    var albumArtwork: Data?
    var waveformData: Data?
    var lyrics: String?
    var isOffline: Bool
    var sourceType: String // "local", "cloud", "streaming"
    
    // Relationships
    var album: AlbumEntity?
    var artistEntity: ArtistEntity?
    var playlists: [PlaylistTrackEntity]?
}

@Model
class AlbumEntity {
    var id: UUID
    var title: String
    var artist: String
    var year: Int?
    var genre: String?
    var artwork: Data?
    var dateAdded: Date
    
    // Relationships
    var tracks: [TrackEntity]?
    var artistEntity: ArtistEntity?
}

@Model
class ArtistEntity {
    var id: UUID
    var name: String
    var artwork: Data?
    
    // Relationships
    var albums: [AlbumEntity]?
    var tracks: [TrackEntity]?
}

@Model
class PlaylistEntity {
    var id: UUID
    var name: String
    var dateCreated: Date
    var dateModified: Date
    var isSmartPlaylist: Bool
    var smartRules: Data? // JSON serialized rules for smart playlists
    
    // Relationships
    var tracks: [PlaylistTrackEntity]?
}

@Model
class PlaylistTrackEntity {
    var id: UUID
    var position: Int
    var dateAdded: Date
    
    // Relationships
    var track: TrackEntity?
    var playlist: PlaylistEntity?
}

@Model
class EqualizerPresetEntity {
    var id: UUID
    var name: String
    var bands: Data // JSON serialized equalizer bands
    var isDefault: Bool
}
```

## Feature Specifications

## Feature 1: Core Music Library

### Feature Goal

Provide a comprehensive local music library that supports importing, organizing, and playing high-resolution audio files with full metadata management capabilities.

### API Relationships

• Interfaces with iOS Files app via FileProvider framework
• Integrates with TagLib for metadata parsing
• Utilizes SFBAudioEngine and FFmpegKit for extended format support
• Leverages SwiftData with Core Data fallback for metadata indexing

### Detailed Feature Requirements

#### 1. Music Import and Organization

1. Support importing music from Files app, external drives, and local storage
2. Scan, index, and parse metadata from audio files (ID3, Vorbis, .cue)
3. Organize library with sorted views (Artists, Albums, Genres, File Quality)
4. Support for FLAC, ALAC, AIFF, WAV, APE, DSD formats with priority on FLAC and ALAC
5. Parse and edit embedded tags
6. Support libraries up to 100,000+ tracks or 2TB+ storage

#### 2. Library Browsing and Navigation

7. Provide hierarchical browsing by Artist → Album → Track
8. Enable flat browsing by Albums, Tracks, Genres
9. Implement search functionality across all metadata fields
10. Display audio quality indicators and format badges
11. Support sorting by various metadata attributes
12. Implement filtering by audio quality, format, and other attributes

#### 3. Metadata Management

13. Parse and display complete metadata from audio files
14. Support for album artwork display and extraction
15. Handle embedded lyrics and display during playback
16. Support for cue sheets and track splitting
17. Provide batch editing capabilities for multiple files

#### 4. Performance Optimization

18. Implement efficient indexing for large libraries
19. Use background processing for library scanning and waveform generation
20. Implement lazy loading for artwork and detailed metadata
21. Cache frequently accessed data for performance
22. Support incremental updates to library

#### 5. User Experience

23. Provide clear visual indicators for audio quality and format
24. Implement smooth scrolling and transitions in library views
25. Support dark mode UI with minimalist aesthetic
26. Ensure accessibility compliance (VoiceOver, Dynamic Type)
27. Provide clear feedback during import and scanning operations

### Detailed Implementation Guide

#### System Architecture

##### Library Manager Service

```swift
protocol LibraryManagerService {
    // Library scanning and indexing
    func scanLibrary() async throws -> LibraryScanResult
    func importFiles(from url: URL) async throws -> ImportResult
    func updateLibrary() async throws -> LibraryScanResult
    
    // Library access
    func getArtists(sortBy: ArtistSortOption) async throws -> [Artist]
    func getAlbums(sortBy: AlbumSortOption, filterBy: AlbumFilter?) async throws -> [Album]
    func getTracks(sortBy: TrackSortOption, filterBy: TrackFilter?) async throws -> [Track]
    func getGenres() async throws -> [String]
    
    // Search
    func search(query: String, scope: SearchScope) async throws -> SearchResult
}
```

##### File System Service

```swift
protocol FileSystemService {
    func getAvailableStorage() -> StorageInfo
    func getFileMetadata(at path: String) throws -> FileMetadata
    func moveFile(from: String, to: String) throws
    func deleteFile(at path: String) throws
    func createDirectory(at path: String) throws
}
```

##### Metadata Service

```swift
protocol MetadataService {
    func readMetadata(from file: URL) throws -> AudioMetadata
    func writeMetadata(to file: URL, metadata: AudioMetadata) throws
    func extractArtwork(from file: URL) throws -> UIImage?
    func embedArtwork(to file: URL, artwork: UIImage) throws
    func parseCueSheet(at path: String) throws -> [CueTrack]
}
```

#### Database Schema Design

The database schema will use SwiftData with Core Data fallback, as outlined in the File System section. Key considerations:

##### Indexing Strategy:
- Create indexes on frequently queried fields: artist, album, title, genre
- Implement full-text search indexes for search functionality
- Use composite indexes for common query patterns

##### Migration Strategy:
- Implement versioned schema migrations
- Support incremental updates without full library rescans
- Provide fallback mechanisms for schema changes

#### Library Import Flow

1. User selects import source (Files app, external drive)
2. System scans selected location for supported audio files
3. For each file:
   a. Extract metadata using appropriate parser (ID3, Vorbis)
   b. Generate audio quality information (format, bit depth, sample rate)
   c. Extract or generate thumbnail for artwork
   d. Create database entries for track, album, artist
4. In background:
   a. Generate waveform data for visualization
   b. Process full-size artwork
   c. Calculate ReplayGain information (if enabled)
5. Update library views with new content
6. Notify user of import completion

#### Library Browsing Implementation

##### View Hierarchy
- `LibraryView`: Main container with navigation to different views
- `ArtistListView`: Displays artists with artwork and track counts
- `AlbumListView`: Displays albums with artwork, artist, and year
- `TrackListView`: Displays tracks with metadata and quality indicators
- `GenreListView`: Displays genres with associated track counts

##### ViewModels

```swift
class LibraryViewModel: ObservableObject {
    @Published var artists: [Artist] = []
    @Published var albums: [Album] = []
    @Published var tracks: [Track] = []
    @Published var genres: [String] = []
    @Published var isLoading: Bool = false
    @Published var error: Error? = nil
    
    private let libraryManager: LibraryManagerService
    
    // Methods for loading and filtering library content
    func loadArtists(sortBy: ArtistSortOption = .name) async
    func loadAlbums(sortBy: AlbumSortOption = .title, filterBy: AlbumFilter? = nil) async
    func loadTracks(sortBy: TrackSortOption = .title, filterBy: TrackFilter? = nil) async
    func loadGenres() async
    func search(query: String, scope: SearchScope = .all) async
}
```

#### Performance Optimization Techniques for Large Libraries

1. **Indexing and Database Optimization:**
   - Create composite indexes for frequently queried combinations (e.g., artist+album, genre+year)
   - Implement SQLite FTS5 for full-text search if SwiftData shows performance limitations
   - Use batch operations with optimal batch sizes (500 items) for database operations
   - Implement database sharding for libraries exceeding 50,000 tracks
   - Create separate indexes for audio quality and format filtering

2. **Lazy Loading and Pagination:**
   - Load only essential metadata during initial library scan
   - Defer waveform generation and full artwork processing to background tasks
   - Implement pagination with cursor-based approach for large result sets
   - Use virtualized lists with cell recycling for smooth scrolling
   - Implement progressive loading of complex metadata

3. **Caching Strategy:**
   - Cache album artwork at multiple resolutions using NSCache with size limits
   - Implement tiered caching system (memory → disk → regenerate)
   - Cache frequently accessed metadata in memory with LRU eviction policy
   - Persist processed data (waveforms, analyzed metadata) to avoid reprocessing
   - Implement cache warming for frequently accessed items

4. **Background Processing:**
   - Use BackgroundTasks framework for library maintenance
   - Implement priority queue for background operations with task cancellation
   - Provide user controls to pause/resume intensive operations
   - Use Task.detached with appropriate priority levels for CPU-intensive operations
   - Implement progressive processing with checkpointing for large operations

5. **Benchmarking and Monitoring:**
   - Create synthetic test libraries (10k, 50k, 100k tracks) for performance testing
   - Implement performance logging for critical operations
   - Add diagnostics for query latency and file I/O operations
   - Create performance profiles for different library sizes
   - Monitor memory usage and implement automatic resource cleanup

#### Error Handling and Recovery

6. Implement robust error handling for file access issues
7. Provide recovery mechanisms for corrupted metadata
8. Log detailed error information for troubleshooting
9. Present user-friendly error messages with actionable steps
10. Implement automatic retry mechanisms for transient errors

#### Testing Strategy

11. **Unit Tests:**
    - Test metadata parsing with various file formats
    - Test database operations and migrations
    - Test filtering and sorting logic

12. **Integration Tests:**
    - Test end-to-end import process
    - Test library browsing with large datasets
    - Test search functionality with various queries

13. **Performance Tests:**
    - Measure import speed with large libraries
    - Test scrolling performance in library views
    - Benchmark search operations

## Feature 2: Advanced Playback Engine

### Feature Goal

Provide a high-fidelity audio playback system capable of bit-perfect reproduction with extensive format support and audio enhancement capabilities, prioritizing sound quality while offering performance mode options.

### API Relationships

• Interfaces with AVFoundation for primary playback
• Utilizes SFBAudioEngine for DSD and APE support
• Leverages FFmpegKit for additional codec support
• Integrates with iOS audio session for background playback
• Connects with hardware detection services for external DACs

### Detailed Feature Requirements

#### 1. High-Fidelity Playback

1. Support lossless, gapless playback for all supported formats
2. Prioritize bit-perfect output when supported by hardware
3. Implement high-resolution format support (up to 24-bit/192kHz)
4. Provide waveform visualization synchronized with playback
5. Display quality indicators and format badges during playback
6. Support for DSD playback (future phase)

#### 2. Audio Processing

7. Implement 10-band equalizer with presets
8. Provide gain control and ReplayGain support
9. Support crossfade between tracks (configurable)
10. Implement sample rate conversion for DAC compatibility
11. Offer different performance modes (Balanced, Maximum Quality, Battery Saver)

#### 3. Playback Controls

12. Support standard playback controls (play, pause, skip, seek)
13. Implement advanced controls (repeat, shuffle, queue management)
14. Provide scrubbing through waveform visualization
15. Support background playback with lock screen controls
16. Integrate with Control Center and headphone remote controls

#### 4. Queue Management

17. Implement playback queue with drag-and-drop reordering
18. Support saving queue as playlist
19. Provide history of played tracks
20. Implement "play next" and "add to queue" functionality
21. Support clearing and shuffling queue

#### 5. Hardware Integration

22. Detect and configure for external DACs
23. Adjust output settings based on connected hardware
24. Display hardware information (connected DAC, sample rate, bit depth)
25. Support bit-perfect mode when compatible hardware is detected
26. Handle audio route changes (headphones, speakers, Bluetooth)

### Detailed Implementation Guide

#### System Architecture

##### Audio Engine Service

```swift
protocol AudioEngineService {
    // Playback control
    func play(track: Track) async throws
    func playCollection(tracks: [Track], startIndex: Int) async throws
    func pause()
    func resume()
    func stop()
    func seekTo(position: TimeInterval)
    
    // Queue management
    func getQueue() -> [Track]
    func addToQueue(track: Track)
    func addToQueue(tracks: [Track])
    func removeFromQueue(at index: Int)
    func moveInQueue(from: Int, to: Int)
    func clearQueue()
    
    // Audio processing
    func setEqualizerBands(_ bands: [Float])
    func applyEqualizerPreset(_ preset: EqualizerPreset)
    func setGain(_ gain: Float)
    func enableReplayGain(_ enabled: Bool)
    func setCrossfade(_ duration: TimeInterval)
    
    // Performance mode
    func setPerformanceMode(_ mode: PerformanceMode)
    
    // Hardware configuration
    func configureForConnectedHardware()
    func getHardwareInfo() -> HardwareInfo
}
```

##### Audio Session Service

```swift
protocol AudioSessionService {
    func configureAudioSession(category: AVAudioSession.Category, mode: AVAudioSession.Mode)
    func activateAudioSession() throws
    func deactivateAudioSession() throws
    func handleInterruption(_ notification: Notification)
    func handleRouteChange(_ notification: Notification)
}
```

##### Waveform Service

```swift
protocol WaveformService {
    func generateWaveform(for track: Track) async throws -> WaveformData
    func getWaveformData(for track: Track) async throws -> WaveformData?
    func clearWaveformCache()
}
```

#### Audio Engine Implementation

The audio engine will use a multi-layered approach:

• Primary Layer: AVAudioEngine for standard formats and iOS integration
• Extended Layer: SFBAudioEngine for high-resolution and DSD formats
• Fallback Layer: FFmpegKit for additional codec support

##### Engine Selection Logic

1. Analyze track format, bit depth, and sample rate
2. If format is standard (MP3, AAC, ALAC) and within AVAudioEngine capabilities:
   a. Use AVAudioEngine for playback
3. Else if format is high-resolution or specialized (FLAC, DSD):
   a. If SFBAudioEngine supports the format:
      i. Use SFBAudioEngine for playback
   b. Else:
      i. Use FFmpegKit to decode to PCM
      ii. Pass PCM to AVAudioEngine for playback
4. Configure output format based on:
   a. Connected hardware capabilities
   b. User's performance mode selection

#### Performance Modes Implementation

```swift
enum PerformanceMode {
    case balanced       // Default: High-quality + battery-efficient
    case maximumQuality // No compression, full waveform, high-res
    case batterySaver   // Lower resolution, simplified visuals
}
```

##### Mode Configuration

**Balanced Mode:**
- Use native format decoding when possible
- Generate medium-resolution waveforms
- Apply moderate buffer sizes
- Enable hardware acceleration when available

**Maximum Quality Mode:**
- Always use bit-perfect playback when supported
- Disable any lossy processing
- Generate high-resolution waveforms
- Use larger buffer sizes for stability
- Prioritize audio fidelity over battery life

**Battery Saver Mode:**
- Downsample high-resolution audio when playing
- Generate simplified waveforms or disable visualization
- Use smaller buffer sizes
- Optimize for minimal CPU usage
- Apply more aggressive caching

#### Waveform Visualization Implementation

##### Waveform Generation

1. For each audio file:
   a. Decode audio data in chunks
   b. Calculate peak and RMS values for each chunk
   c. Apply delta encoding compression to reduce storage size
   d. Store values in binary compressed format (Base64 encoded)
   e. Implement downsampling for high-resolution files (24-bit/192kHz)
   f. Use simplified peak-only representation for DSD files
   g. Cache results for future use

2. Visualization rendering:
   a. In Library view: show simplified waveform or static preview
   b. In Playback view: render detailed waveform with current position
   c. Support zoom levels based on performance mode
   d. Color-code waveform based on audio quality
   e. Adapt resolution and detail based on performance mode:
      - Maximum Quality: Full resolution, real-time updates
      - Balanced: Medium resolution, optimized updates
      - Battery Saver: Low resolution or static representation

##### Waveform View

```swift
struct WaveformView: View {
    let waveformData: WaveformData
    let currentPosition: TimeInterval
    let duration: TimeInterval
    let isPlaying: Bool
    let quality: AudioQuality
    
    // Interaction handlers
    var onSeek: (TimeInterval) -> Void
    
    // View implementation with Metal or SwiftUI Canvas
    // for efficient rendering
}
```

#### Hardware Integration

##### DAC Detection and Configuration

1. Monitor audio route changes via AVAudioSession
2. When external device is connected:
   a. Identify device type and capabilities
   b. Determine supported formats, sample rates, and bit depths
   c. Configure audio engine output format accordingly
   d. Update UI to show connected device information
   e. Enable bit-perfect mode if supported
   f. Validate bit-perfect output using BitPerfectValidatorService

3. When device is disconnected:
   a. Reconfigure for internal speaker or headphone output
   b. Adjust quality settings as needed

##### BitPerfectValidatorService

```swift
protocol BitPerfectValidatorService {
    // Validate if current output is truly bit-perfect
    func validateBitPerfectOutput(for track: Track) async -> BitPerfectValidationResult
    
    // Get hardware capability information
    func getHardwareCapabilities() -> HardwareCapabilities
    
    // Check if specific format can be output bit-perfectly
    func canOutputBitPerfect(format: AudioFormat) -> Bool
    
    // Maintain compatibility database
    func getDACCompatibilityInfo(for deviceID: String) -> DACCompatibilityInfo?
    
    // Update compatibility database based on validation results
    func updateDACCompatibilityInfo(for deviceID: String, result: BitPerfectValidationResult)
}

struct BitPerfectValidationResult {
    let isValid: Bool
    let actualSampleRate: Double
    let actualBitDepth: Int
    let mismatchReason: String?
    let recommendedSettings: AudioSettings?
}

struct DACCompatibilityInfo {
    let deviceName: String
    let supportedSampleRates: [Double]
    let supportedBitDepths: [Int]
    let requiresExclusiveMode: Bool
    let knownIssues: [String]?
    let recommendedSettings: AudioSettings?
}
```

##### Hardware Info Display

```swift
struct HardwareInfoView: View {
    let connectedDevice: AudioDevice?
    let currentFormat: AudioFormat
    let isBitPerfect: Bool
    
    // View implementation showing device name, format,
    // sample rate, bit depth, and bit-perfect indicator
}
```

#### Audio Processing Pipeline

##### DSP Chain

```
Input → Format Decoder → [Optional Processing] → Output

Optional Processing modules (implemented in phases):

Phase 1 (MVP):
- Equalizer (10-band) using AVAudioUnitEQ
- Gain Control (basic volume adjustment)
- Sample Rate Conversion (for hardware compatibility)

Phase 2:
- ReplayGain support
- Crossfade between tracks
- Enhanced equalizer with custom presets

Phase 3:
- Advanced DSP effects
- Spatial audio processing
- Room correction

Each module can be enabled/disabled based on:
- User preferences
- Performance mode
- Hardware capabilities
```

##### Equalizer Implementation

```swift
class EqualizerService {
    // 10 bands: 32Hz, 64Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz
    private var bands: [Float] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    private var isEnabled: Bool = false
    
    // Methods to configure equalizer
    func setBands(_ values: [Float])
    func applyPreset(_ preset: EqualizerPreset)
    func enable(_ enabled: Bool)
    
    // Internal methods to apply EQ to audio stream
    private func applyEqualization(buffer: AVAudioPCMBuffer)
}
```

#### Background Playback

##### Audio Session Configuration

```swift
func configureForBackgroundPlayback() {
    do {
        try audioSessionService.configureAudioSession(
            category: .playback,
            mode: .default
        )
        
        try audioSessionService.activateAudioSession()
        
        // Register for notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        // Configure Now Playing info
        setupNowPlayingInfo()
        
        // Configure remote command center
        setupRemoteCommandCenter()
        
    } catch {
        logger.error("Failed to configure audio session: \(error)")
    }
}
```

#### Error Handling and Recovery

1. Implement robust error handling for audio decoding issues
2. Provide fallback mechanisms for unsupported formats
3. Handle audio session interruptions gracefully
4. Implement automatic recovery from playback errors
5. Log detailed error information for troubleshooting

#### Testing Strategy

6. **Unit Tests:**
   - Test format detection and decoder selection
   - Test equalizer and audio processing modules
   - Test queue management logic

7. **Integration Tests:**
   - Test end-to-end playback with various formats
   - Test hardware detection and configuration
   - Test background playback and controls

8. **Performance Tests:**
   - Measure CPU and memory usage during playback
   - Test battery consumption in different modes
   - Benchmark waveform rendering performance

## Feature 3: Smart Playlist & Filtering

### Feature Goal

Provide a powerful system for creating dynamic playlists based on metadata attributes, allowing users to organize their music collection with precision and flexibility.

### API Relationships

• Interfaces with Library Manager for track access
• Utilizes SwiftData query predicates for filtering
• Connects with Playback Engine for playlist playback
• Leverages Combine framework for reactive updates

### Detailed Feature Requirements

#### 1. Smart Playlist Creation

1. Support creating playlists with multiple filter criteria
2. Implement complex boolean logic (AND, OR, NOT)
3. Allow filtering by audio quality, genre, artist, and custom tags
4. Support numerical comparisons (greater than, less than, equal to)
5. Allow date-based filtering (added, modified, last played)
6. Support text matching (contains, starts with, exact match)

#### 2. Filter Management

7. Save and manage multiple playlist configurations
8. Support editing existing smart playlists
9. Allow duplicating and modifying playlists
10. Provide preset filters for common scenarios
11. Support importing and exporting filter configurations

#### 3. Result Presentation

12. Sort and group results by various attributes
13. Provide visual indicators for filter matches
14. Support real-time updates as library changes
15. Allow switching between different view modes
16. Implement pagination for large result sets

#### 4. Quick Filtering

17. Support filtering within current view context
18. Provide quick filter presets (high-res only, recently added, etc.)
19. Implement search within filtered results
20. Allow temporary modifications to filters
21. Support saving quick filters as smart playlists

#### 5. Performance Optimization

22. Optimize query execution for large libraries
23. Implement caching for frequent queries
24. Use background processing for complex filters
25. Support incremental updates to filtered results
26. Provide progress indicators for long-running filters

### Detailed Implementation Guide

#### System Architecture

##### Smart Playlist Service

```swift
protocol SmartPlaylistService {
    // Playlist management
    func createSmartPlaylist(name: String, rules: [FilterRule]) async throws -> Playlist
    func updateSmartPlaylist(id: UUID, name: String?, rules: [FilterRule]?) async throws -> Playlist
    func deleteSmartPlaylist(id: UUID) async throws
    func getSmartPlaylists() async throws -> [Playlist]
    func getSmartPlaylist(id: UUID) async throws -> Playlist?
    
    // Filter execution
    func executeFilter(rules: [FilterRule]) async throws -> [Track]
    func executeQuickFilter(rule: FilterRule, in tracks: [Track]) -> [Track]
    
    // Preset management
    func saveFilterPreset(name: String, rules: [FilterRule]) async throws
    func getFilterPresets() async throws -> [FilterPreset]
}
```

##### Filter Rule Model

```swift
struct FilterRule {
    enum Attribute {
        case title, artist, albumTitle, albumArtist, genre, composer
        case year, trackNumber, discNumber, duration, playCount
        case format, bitDepth, sampleRate, bitrate
        case isLossless, isHiRes
        case dateAdded, dateModified, lastPlayed
        case custom(String)
    }
    
    enum Operator {
        // Text operators
        case contains, doesNotContain, beginsWith, endsWith, equals, notEquals
        
        // Numeric operators
        case greaterThan, lessThan, equalTo, notEqualTo
        case between, notBetween
        
        // Boolean operators
        case isTrue, isFalse
        
        // Date operators
        case before, after, on
        case inTheLast, notInTheLast
    }
    
    enum Combinator {
        case and, or
    }
    
    var attribute: Attribute
    var `operator`: Operator
    var value: Any
    var secondaryValue: Any? // For range operators like "between"
    var combinator: Combinator? // How this rule combines with the next rule
}
```

#### Database Schema Design

The smart playlist functionality will leverage the existing database schema with additional models for storing filter rules:

```swift
@Model
class PlaylistEntity {
    var id: UUID
    var name: String
    var dateCreated: Date
    var dateModified: Date
    var isSmartPlaylist: Bool
    var smartRules: Data? // JSON serialized rules for smart playlists
    
    // Relationships
    var tracks: [PlaylistTrackEntity]?
}

@Model
class FilterPresetEntity {
    var id: UUID
    var name: String
    var rules: Data // JSON serialized filter rules
    var dateCreated: Date
    var dateModified: Date
}
```

##### Rule Serialization

```swift
extension FilterRule {
    func toJSON() -> Data? {
        // Convert rule to JSON representation
    }
    
    static func fromJSON(_ data: Data) -> FilterRule? {
        // Create rule from JSON representation
    }
}
```

#### Filter Execution Engine

##### Query Builder

```swift
class QueryBuilder {
    // Build SwiftData predicates from filter rules
    func buildPredicate(from rules: [FilterRule]) -> NSPredicate {
        var predicates: [NSPredicate] = []
        var currentCombinator: FilterRule.Combinator = .and
        
        for rule in rules {
            let predicate = buildSinglePredicate(from: rule)
            predicates.append(predicate)
            
            if let nextCombinator = rule.combinator {
                currentCombinator = nextCombinator
            }
        }
        
        if currentCombinator == .and {
            return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        } else {
            return NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        }
    }
    
    private func buildSinglePredicate(from rule: FilterRule) -> NSPredicate {
        // Build predicate based on attribute, operator, and value
        switch rule.attribute {
        case .title:
            return buildStringPredicate(keyPath: "title", operator: rule.operator, value: rule.value)
        case .artist:
            return buildStringPredicate(keyPath: "artist", operator: rule.operator, value: rule.value)
        // Additional cases for other attributes
        }
    }
    
    private func buildStringPredicate(keyPath: String, operator: FilterRule.Operator, value: Any) -> NSPredicate {
        // Build string-specific predicates
        switch `operator` {
        case .contains:
            return NSPredicate(format: "%K CONTAINS[cd] %@", keyPath, value as! String)
        case .doesNotContain:
            return NSPredicate(format: "NOT (%K CONTAINS[cd] %@)", keyPath, value as! String)
        // Additional cases for other operators
        }
    }
    
    // Additional methods for building numeric, boolean, and date predicates
}
```

#### Smart Playlist Editor UI

##### View Hierarchy
- `SmartPlaylistEditorView`: Main editor view
- `FilterRuleView`: Individual rule editor
- `AttributeSelectorView`: Attribute selection
- `OperatorSelectorView`: Operator selection
- `ValueEditorView`: Value input based on attribute type

##### ViewModel

```swift
class SmartPlaylistEditorViewModel: ObservableObject {
    @Published var playlistName: String = ""
    @Published var rules: [FilterRule] = []
    @Published var matchingTracks: [Track] = []
    @Published var isExecutingFilter: Bool = false
    @Published var error: Error? = nil
    
    private let smartPlaylistService: SmartPlaylistService
    private var cancellables = Set<AnyCancellable>()
    
    // Methods for managing rules
    func addRule()
    func removeRule(at index: Int)
    func updateRule(at index: Int, rule: FilterRule)
    func moveRule(from: Int, to: Int)
    
    // Methods for filter execution
    func executeFilter() async
    func savePlaylist() async throws -> Playlist
    func updatePlaylist(id: UUID) async throws -> Playlist
    
    // Helper methods
    func getAvailableAttributes() -> [FilterRule.Attribute]
    func getOperators(for attribute: FilterRule.Attribute) -> [FilterRule.Operator]
}
```

#### Real-Time Filtering Implementation

##### Reactive Updates

```swift
func setupReactiveUpdates() {
    // Observe changes to rules and execute filter
    $rules
        .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            Task {
                await self?.executeFilter()
            }
        }
        .store(in: &cancellables)
    
    // Observe library changes and update results if needed
    NotificationCenter.default
        .publisher(for: .libraryDidUpdate)
        .debounce(for: .seconds(1.0), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            Task {
                await self?.executeFilter()
            }
        }
        .store(in: &cancellables)
}
```

#### Quick Filtering Implementation

##### Quick Filter Service

```swift
class QuickFilterService {
    // Predefined quick filters
    static let highResOnly = FilterRule(
        attribute: .isHiRes,
        operator: .isTrue,
        value: true
    )
    
    static let recentlyAdded = FilterRule(
        attribute: .dateAdded,
        operator: .inTheLast,
        value: 7,
        secondaryValue: "days"
    )
    
    static let neverPlayed = FilterRule(
        attribute: .playCount,
        operator: .equalTo,
        value: 0
    )
    
    // Apply quick filter to current view
    func applyQuickFilter(_ rule: FilterRule, to tracks: [Track]) -> [Track]
    
    // Save quick filter as smart playlist
    func saveAsSmartPlaylist(name: String, rule: FilterRule) async throws -> Playlist
}
```

#### Performance Optimization Techniques

1. **Query Optimization:**
   - Use indexed fields for filtering when possible
   - Optimize predicate structure for efficient execution
   - Limit result set size for initial preview

2. **Caching Strategy:**
   - Cache filter results for frequently used smart playlists
   - Implement incremental updates instead of full re-execution
   - Store intermediate results for complex filters

3. **Background Processing:**
   - Execute complex filters in background tasks
   - Update UI with progress indicators for long-running filters
   - Allow cancellation of filter execution

#### Error Handling and Recovery

4. Implement validation for filter rules to prevent invalid combinations
5. Provide clear error messages for filter execution failures
6. Handle edge cases like empty results or too many results
7. Implement automatic simplification for overly complex filters
8. Log detailed error information for troubleshooting

#### Testing Strategy

9. **Unit Tests:**
   - Test predicate building for various rule combinations
   - Test filter execution with different data sets
   - Test rule serialization and deserialization

10. **Integration Tests:**
    - Test end-to-end smart playlist creation and execution
    - Test performance with large libraries
    - Test reactive updates with library changes

11. **User Testing:**
    - Validate filter UI usability
    - Test complex filter creation workflows
    - Measure time to create common filter patterns

## Feature 4: Metadata Editor

### Feature Goal

Provide a comprehensive tool for viewing and editing audio file metadata, including tags, artwork, and lyrics, with batch editing capabilities to efficiently manage large music collections.

### API Relationships

• Interfaces with TagLib for metadata reading/writing
• Connects with Library Manager for track access
• Utilizes File System Service for file operations
• Integrates with Background Task Service for batch operations

### Detailed Feature Requirements

#### 1. Metadata Viewing and Editing

1. Support viewing and editing ID3, Vorbis, and other tag formats
2. Provide fields for common metadata (title, artist, album, etc.)
3. Support extended metadata fields (composer, conductor, etc.)
4. Allow editing custom tag fields
5. Implement validation for metadata fields

#### 2. Artwork Management

6. Display embedded album artwork
7. Support adding, replacing, and removing artwork
8. Handle high-resolution artwork appropriately
9. Support multiple artwork (front cover, back cover, etc.)
10. Provide image editing capabilities (crop, resize)

#### 3. Lyrics Support

11. View and edit embedded lyrics
12. Support synchronized lyrics (LRC format)
13. Allow importing lyrics from text files
14. Provide lyrics display during playback
15. Support multiple languages for lyrics

#### 4. Batch Editing

16. Edit metadata for multiple files simultaneously
17. Support pattern-based field editing
18. Implement find and replace functionality
19. Allow applying artwork to multiple albums
20. Provide preview of changes before applying

#### 5. Advanced Features

21. Support for cue sheets and track splitting
22. Implement metadata extraction from filenames
23. Provide filename formatting based on metadata
24. Support for album-level and track-level metadata
25. Implement undo/redo functionality for edits

### Detailed Implementation Guide

#### System Architecture

##### Metadata Editor Service

```swift
protocol MetadataEditorService {
    // Single file operations
    func getMetadata(for track: Track) async throws -> AudioMetadata
    func saveMetadata(for track: Track, metadata: AudioMetadata) async throws
    
    // Artwork operations
    func getArtwork(for track: Track) async throws -> [Artwork]
    func saveArtwork(for track: Track, artwork: Artwork) async throws
    func removeArtwork(for track: Track) async throws
    
    // Lyrics operations
    func getLyrics(for track: Track) async throws -> Lyrics?
    func saveLyrics(for track: Track, lyrics: Lyrics) async throws
    func removeLyrics(for track: Track) async throws
    
    // Batch operations
    func batchEdit(tracks: [Track], changes: MetadataChanges) async throws -> BatchEditResult
    func previewBatchEdit(tracks: [Track], changes: MetadataChanges) async throws -> BatchEditPreview
    
    // Advanced operations
    func extractMetadataFromFilename(track: Track, pattern: String) async throws -> AudioMetadata
    func formatFilename(track: Track, pattern: String) async throws -> String
    func splitCueSheet(cueFile: URL) async throws -> [Track]
}
```

##### Audio Metadata Model

```swift
struct AudioMetadata {
    // Common metadata
    var title: String?
    var artist: String?
    var albumTitle: String?
    var albumArtist: String?
    var composer: String?
    var conductor: String?
    var genre: String?
    var year: Int?
    var trackNumber: Int?
    var trackTotal: Int?
    var discNumber: Int?
    var discTotal: Int?
    var comment: String?
    
    // Extended metadata
    var bpm: Int?
    var key: String?
    var mood: String?
    var recordLabel: String?
    var catalogNumber: String?
    var isrc: String?
    var language: String?
    var copyright: String?
    var encodedBy: String?
    var encodingSettings: String?
    
    // Custom fields
    var customFields: [String: String]
}
```

##### Artwork Model

```swift
struct Artwork {
    enum ArtworkType {
        case frontCover
        case backCover
        case disc
        case artist
        case liner
        case other
    }
    
    var type: ArtworkType
    var image: UIImage
    var description: String?
    var mimeType: String
}
```

##### Lyrics Model

```swift
struct Lyrics {
    enum LyricsType {
        case unsynchronized
        case synchronized
    }
    
    var type: LyricsType
    var content: String
    var language: String?
    
    // For synchronized lyrics
    var timeMarkers: [TimeMarker]?
    
    struct TimeMarker {
        var time: TimeInterval
        var text: String
    }
}
```

#### Metadata Editor UI

##### View Hierarchy
- `MetadataEditorView`: Main editor container
- `BasicMetadataView`: Common metadata fields
- `ExtendedMetadataView`: Additional metadata fields
- `ArtworkEditorView`: Artwork management
- `LyricsEditorView`: Lyrics editing
- `BatchEditorView`: Batch editing interface

##### ViewModel

```swift
class MetadataEditorViewModel: ObservableObject {
    @Published var metadata: AudioMetadata
    @Published var artwork: [Artwork] = []
    @Published var lyrics: Lyrics?
    @Published var isEditing: Bool = false
    @Published var isSaving: Bool = false
    @Published var error: Error? = nil
    
    private let track: Track
    private let metadataService: MetadataEditorService
    
    // Methods for metadata operations
    func loadMetadata() async
    func saveMetadata() async throws
    func revertChanges()
    
    // Methods for artwork operations
    func loadArtwork() async
    func addArtwork(_ image: UIImage, type: Artwork.ArtworkType)
    func removeArtwork(at index: Int)
    func saveArtwork() async throws
    
    // Methods for lyrics operations
    func loadLyrics() async
    func saveLyrics() async throws
    func importLyrics(from url: URL) async throws
    func convertToSynchronized() -> Lyrics
    
    // Validation methods
    func validateMetadata() -> [ValidationError]
}
```

#### Batch Editing Implementation

##### Batch Changes Model

```swift
struct MetadataChanges {
    enum ChangeType {
        case set(value: Any)
        case clear
        case append(value: String)
        case prepend(value: String)
        case replace(search: String, replacement: String)
        case increment(start: Int, step: Int)
        case capitalize
        case lowercase
        case uppercase
    }
    
    var changes: [KeyPath<AudioMetadata, Any>: ChangeType]
    var artworkChange: ArtworkChange?
    var lyricsChange: LyricsChange?
    
    enum ArtworkChange {
        case set(artwork: Artwork)
        case clear
        case keepExisting
    }
    
    enum LyricsChange {
        case set(lyrics: Lyrics)
        case clear
        case keepExisting
    }
}
```

##### Batch Editor ViewModel

```swift
class BatchEditorViewModel: ObservableObject {
    @Published var selectedTracks: [Track] = []
    @Published var changes: MetadataChanges = MetadataChanges(changes: [:])
    @Published var previewResults: BatchEditPreview?
    @Published var isExecuting: Bool = false
    @Published var progress: Float = 0.0
    @Published var error: Error? = nil
    
    private let metadataService: MetadataEditorService
    
    // Methods for batch operations
    func previewChanges() async
    func applyChanges() async throws
    func cancelChanges()
    
    // Helper methods
    func addChange(for keyPath: KeyPath<AudioMetadata, Any>, type: MetadataChanges.ChangeType)
    func removeChange(for keyPath: KeyPath<AudioMetadata, Any>)
    func setArtworkChange(_ change: MetadataChanges.ArtworkChange)
    func setLyricsChange(_ change: MetadataChanges.LyricsChange)
}
```

#### Tag Writing Implementation

##### TagLib Integration

```swift
class TagLibService {
    // Read metadata from file
    func readTags(from url: URL) throws -> AudioMetadata {
        // Use TagLib to read metadata from file
        // Map TagLib structures to AudioMetadata model
    }
    
    // Write metadata to file
    func writeTags(to url: URL, metadata: AudioMetadata) throws {
        // Use TagLib to write metadata to file
        // Handle different tag formats based on file type
    }
    
    // Read artwork from file
    func readArtwork(from url: URL) throws -> [Artwork] {
        // Extract artwork from file using TagLib
        // Convert to Artwork model
    }
    
    // Write artwork to file
    func writeArtwork(to url: URL, artwork: [Artwork]) throws {
        // Embed artwork in file using TagLib
        // Handle different formats and sizes
    }
    
    // Read lyrics from file
    func readLyrics(from url: URL) throws -> Lyrics? {
        // Extract lyrics from file using TagLib
        // Parse synchronized lyrics if available
    }
    
    // Write lyrics to file
    func writeLyrics(to url: URL, lyrics: Lyrics) throws {
        // Embed lyrics in file using TagLib
        // Format synchronized lyrics if needed
    }
}
```

#### Non-Destructive Editing

```swift
class BackupService {
    // Create backup of file before editing
    func backupFile(at url: URL) throws -> URL {
        // Create backup copy with timestamp
        // Store in backup directory
        // Return backup URL
    }
    
    // Restore file from backup
    func restoreFile(from backupURL: URL, to originalURL: URL) throws {
        // Copy backup file back to original location
        // Verify integrity
    }
    
    // Clean up old backups
    func cleanupBackups(olderThan date: Date) throws {
        // Remove backups older than specified date
        // Keep minimum number of backups
    }
}
```

#### CUE Sheet Handling

```swift
class CueSheetService {
    // Parse CUE sheet
    func parseCueSheet(at url: URL) throws -> CueSheet {
        // Parse CUE file format
        // Extract track information
        // Map to CueSheet model
    }
    
    // Split audio file based on CUE sheet
    func splitAudioFile(audioURL: URL, cueSheet: CueSheet, outputDirectory: URL) async throws -> [URL] {
        // Use FFmpeg to split audio file
        // Apply metadata from CUE sheet
        // Return URLs of created files
    }
    
    // Create CUE sheet from tracks
    func createCueSheet(for tracks: [Track], outputURL: URL) throws {
        // Generate CUE sheet format
        // Include track metadata
        // Write to file
    }
}
```

#### Performance Optimization Techniques

1. **Batch Processing:**
   - Process files in batches to limit memory usage
   - Implement progress tracking for long operations
   - Allow cancellation of batch operations

2. **Background Execution:**
   - Use background tasks for intensive operations
   - Implement resumable operations for large batches
   - Provide notifications for completed operations

3. **Caching Strategy:**
   - Cache metadata and artwork during editing sessions
   - Implement dirty tracking to only save changed fields
   - Use memory-efficient representations for large artwork

#### Error Handling and Recovery

4. Implement robust error handling for file access issues
5. Provide automatic backup before making changes
6. Implement rollback mechanisms for failed batch operations
7. Present user-friendly error messages with recovery options
8. Log detailed error information for troubleshooting

#### Testing Strategy

9. **Unit Tests:**
   - Test metadata reading and writing with various formats
   - Test batch operation logic
   - Test validation rules

10. **Integration Tests:**
    - Test end-to-end metadata editing workflow
    - Test batch editing with large collections
    - Test CUE sheet parsing and splitting

11. **File Format Tests:**
    - Test compatibility with various tag formats
    - Test handling of corrupt or incomplete tags
    - Test preservation of existing tags not modified by the editor

## Feature Integration Points

### Integration Between Core Music Library and Advanced Playback Engine

#### Track Selection and Playback

1. Library provides track metadata and file paths to Playback Engine
2. Playback Engine reports playback status and position back to Library
3. Library updates play counts and last played timestamps

#### Audio Quality Information

4. Library provides format, bit depth, and sample rate information
5. Playback Engine configures appropriate decoder based on format
6. Library displays quality indicators based on playback capabilities

#### Waveform Visualization

7. Library initiates background waveform generation for new tracks
8. Playback Engine uses waveform data for visualization during playback
9. Library caches waveform data for future use

### Integration Between Core Music Library and Smart Playlist & Filtering

#### Library Access

1. Smart Playlist feature queries Library for tracks matching filter criteria
2. Library notifies Smart Playlist when tracks are added, removed, or modified
3. Smart Playlist updates filtered results based on library changes

#### Metadata Filtering

4. Library provides metadata attributes for filtering
5. Smart Playlist creates predicates based on these attributes
6. Library executes queries and returns matching tracks

#### Performance Optimization

7. Library provides indexing for efficient filtering
8. Smart Playlist optimizes queries for performance
9. Both components coordinate background processing

### Integration Between Core Music Library and Metadata Editor

#### Track Selection

1. Library provides tracks for editing in Metadata Editor
2. Metadata Editor reads and writes metadata for selected tracks
3. Library updates its database after metadata changes

#### Batch Operations

4. Library provides collections of tracks for batch editing
5. Metadata Editor applies changes to multiple files
6. Library updates all affected entries after batch operations

#### File System Coordination

7. Library manages file paths and organization
8. Metadata Editor works with files at these paths
9. Both components coordinate file access to prevent conflicts

### Integration Between Advanced Playback Engine and Smart Playlist & Filtering

#### Playlist Playback

1. Smart Playlist provides filtered track lists to Playback Engine
2. Playback Engine manages playback queue based on these lists
3. Smart Playlist updates can modify current playback queue

#### Playback Statistics

4. Playback Engine reports play counts and durations
5. Smart Playlist can filter based on these statistics
6. Both components share playback history data

### Integration Between Advanced Playback Engine and Metadata Editor

#### Real-time Metadata Display

1. Playback Engine displays current track metadata during playback
2. Metadata Editor can update this information in real-time
3. Playback Engine reflects metadata changes immediately

#### Lyrics Display

4. Metadata Editor manages lyrics content and timing
5. Playback Engine displays synchronized lyrics during playback
6. Both components share lyrics parsing and formatting logic

### Integration Between Smart Playlist & Filtering and Metadata Editor

#### Metadata-based Filtering

1. Metadata Editor updates track attributes
2. Smart Playlist reevaluates filters based on updated attributes
3. Both components share metadata validation logic

#### Batch Operations

4. Smart Playlist can select tracks for batch editing
5. Metadata Editor applies changes to these selections
6. Smart Playlist updates after batch operations complete

## Performance Considerations

### Large Library Optimization

1. Implement pagination for large result sets
2. Use background indexing for library scanning
3. Optimize database queries with appropriate indexes
4. Implement lazy loading for artwork and detailed metadata

### Audio Playback Efficiency

5. Use appropriate buffer sizes based on performance mode
6. Implement efficient format conversion when necessary
7. Optimize waveform rendering for smooth visualization
8. Minimize processing during battery-saving mode

### Background Processing

9. Coordinate background tasks to prevent CPU overload
10. Prioritize playback performance over background operations
11. Implement cancellation for non-critical background tasks
12. Use low-priority queues for metadata processing

### Memory Management

13. Implement proper caching strategies for artwork and waveforms
14. Release unused resources when memory pressure occurs
15. Use appropriate image resolutions based on display requirements
16. Implement memory-efficient data structures for large collections

### Battery Optimization

17. Provide user-selectable performance modes
18. Reduce processing during battery-saving mode
19. Optimize background operations when on battery power
20. Implement efficient sleep/wake behavior

## Security and Privacy Considerations

### Privacy-First Design Philosophy

1. Implement strict privacy-by-default approach with no data collection
2. Create privacy onboarding screen explaining the app's privacy commitment
3. Provide detailed privacy policy accessible from settings
4. Implement privacy indicators for any feature that could potentially access external services
5. Use anonymous identifiers if any analytics are implemented (opt-in only)

### File System Access

6. Use proper sandboxing for file access with explicit user permissions
7. Implement secure file operations with comprehensive error handling
8. Provide clear user permissions dialogs with explanations
9. Protect backup files with appropriate permissions and optional encryption
10. Implement secure deletion for sensitive files when requested

### Metadata Privacy

11. Keep all metadata processing strictly on-device with no external transmission
12. Implement secure local storage for all metadata with optional encryption
13. Never transmit library information without explicit user opt-in consent
14. Provide granular controls for what metadata can be shared if user enables external services
15. Implement metadata anonymization for any shared data (if user opts in)
16. Allow users to audit what metadata is stored and how it's used

### External Service Integration

17. Implement OAuth 2.0 with PKCE for all external service authentication
18. Use encrypted connections (TLS 1.3+) for all network traffic
19. Minimize data sharing with external services to only what's necessary
20. Provide clear privacy controls with granular permissions for each service
21. Implement connection security indicators in the UI
22. Allow users to revoke access to external services at any time
23. Store authentication tokens securely in the iOS Keychain

### User Data Protection

24. Implement secure storage for user preferences using iOS Keychain
25. Protect playback history and statistics with local-only storage
26. Provide options to disable history tracking entirely
27. Allow users to clear usage data with one-tap option
28. Comply with GDPR, CCPA, and other privacy regulations
29. Implement data portability for user-generated content
30. Use SecureEnclave for any sensitive cryptographic operations

### Network Security

31. Implement certificate pinning for API connections
32. Use App Transport Security (ATS) with no exceptions
33. Implement network activity indicators for user awareness
34. Provide offline mode with clear indicators when network features are unavailable
35. Implement bandwidth usage monitoring and controls

## Accessibility Considerations

### VoiceOver Support

1. Implement proper accessibility labels for all UI elements
2. Provide meaningful descriptions for audio quality indicators
3. Ensure logical navigation flow for screen readers
4. Test all features with VoiceOver enabled

### Dynamic Type

5. Support dynamic text sizing throughout the app
6. Ensure layouts adapt to larger text sizes
7. Maintain readability at all text sizes
8. Test with various text size settings

### Reduce Motion

9. Provide alternative animations for users with motion sensitivity
10. Implement static alternatives to waveform animations
11. Respect system settings for reduced motion
12. Test with reduced motion enabled

### Color and Contrast

13. Ensure sufficient contrast for all UI elements
14. Do not rely solely on color for conveying information
15. Provide alternative indicators for color-blind users
16. Test with various color filters enabled

### Haptic Feedback

17. Implement appropriate haptic feedback for interactions
18. Provide alternative feedback mechanisms
19. Respect system settings for haptic feedback
20. Test with various haptic settings