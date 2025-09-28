# Data Model Specification

**Feature**: Fonic HiFi Critical Improvements
**Date**: 2025-09-26
**Version**: 1.0

## Overview
This document defines the data models, relationships, and state management patterns for the Fonic HiFi improvements. All models follow Swift 6.2 concurrency requirements and SwiftData best practices.

## Core Entities

### Track
**Purpose**: Represents an audio file with metadata
**Location**: `Data/Models/Track.swift`

```swift
@Model
final class Track: Sendable {
    // Identity
    @Attribute(.unique) var id: UUID
    var url: URL
    var fileSize: Int64

    // Metadata
    var title: String
    var duration: TimeInterval
    var format: AudioFormat
    var sampleRate: Int
    var bitDepth: Int
    var channels: Int

    // Relationships (MUST ADD)
    @Relationship(inverse: \Album.tracks)
    var album: Album?

    @Relationship(inverse: \Artist.tracks)
    var artist: Artist?

    @Relationship(inverse: \Playlist.tracks)
    var playlists: [Playlist]

    // Computed
    var displayTitle: String
    var isHighResolution: Bool // >44.1kHz or >16bit

    // Timestamps
    var dateAdded: Date
    var lastPlayed: Date?
    var playCount: Int
}
```

**Validation Rules**:
- URL must be valid file URL
- Duration must be > 0
- Sample rate must be standard (44100, 48000, 88200, 96000, 176400, 192000)
- Bit depth must be 16, 24, or 32

### Album
**Purpose**: Groups related tracks
**Location**: `Data/Models/Album.swift`

```swift
@Model
final class Album: Sendable {
    // Identity
    @Attribute(.unique) var id: UUID
    var title: String
    var releaseYear: Int?
    var artworkURL: URL?

    // Relationships (MUST ADD)
    @Relationship(deleteRule: .nullify)
    var tracks: [Track]

    @Relationship(inverse: \Artist.albums)
    var artist: Artist?

    // Computed (MUST IMPLEMENT)
    var trackCount: Int { tracks.count }
    var totalDuration: TimeInterval {
        tracks.reduce(0) { $0 + $1.duration }
    }
    var displayTitle: String

    // Timestamps
    var dateAdded: Date
}
```

**Validation Rules**:
- Title required, non-empty
- Release year if present must be 1900-current year
- At least one track required

### Artist
**Purpose**: Represents music creator
**Location**: `Data/Models/Artist.swift`

```swift
@Model
final class Artist: Sendable {
    // Identity
    @Attribute(.unique) var id: UUID
    var name: String
    var sortName: String // For "The Beatles" -> "Beatles, The"

    // Relationships (MUST ADD)
    @Relationship(deleteRule: .nullify)
    var tracks: [Track]

    @Relationship(deleteRule: .nullify)
    var albums: [Album]

    // Computed (MUST IMPLEMENT)
    var trackCount: Int { tracks.count }
    var albumCount: Int { albums.count }

    // Timestamps
    var dateAdded: Date
}
```

**Validation Rules**:
- Name required, non-empty
- Sort name auto-generated if not provided

### Playlist
**Purpose**: User-created track collections
**Location**: `Data/Models/Playlist.swift`

```swift
@Model
final class Playlist: Sendable {
    // Identity
    @Attribute(.unique) var id: UUID
    var name: String
    var userDescription: String?

    // Relationships
    @Relationship(deleteRule: .nullify)
    var tracks: [Track]

    // Order preservation
    var trackOrder: [UUID] // Maintains user's track order

    // Computed
    var trackCount: Int { tracks.count }
    var totalDuration: TimeInterval

    // Timestamps
    var dateCreated: Date
    var lastModified: Date
}
```

**Validation Rules**:
- Name required, unique per user
- Track order must match track IDs

## State Management

### PlaybackState
**Purpose**: Current playback status
**Location**: `Core/Audio/Playback/PlaybackState.swift`

```swift
struct PlaybackState: Sendable {
    enum Status: Sendable {
        case idle
        case loading(Track)
        case playing(Track, currentTime: TimeInterval)
        case paused(Track, currentTime: TimeInterval)
        case error(AudioEngineError)
    }

    var status: Status
    var duration: TimeInterval
    var isSeekable: Bool
    var volume: Float // 0.0 to 1.0
    var rate: Float // 0.5 to 2.0 for variable speed
}
```

**State Transitions**:
- idle → loading → playing
- playing ↔ paused
- any → error → idle
- playing/paused → idle (stop)

### QueueState
**Purpose**: Playback queue management
**Location**: `Core/Audio/Queue/QueueState.swift`

```swift
struct QueueState: Sendable {
    // Queue
    var tracks: [Track]
    var currentIndex: Int
    var upNext: [Track] // User additions

    // Modes
    var shuffleMode: ShuffleMode
    var repeatMode: RepeatMode

    // Shuffle
    var shuffledIndices: [Int]? // Preserves shuffle order
    var originalIndex: Int? // Position in unshuffled queue

    enum ShuffleMode: Sendable {
        case off
        case on
    }

    enum RepeatMode: Sendable {
        case off
        case all
        case one
    }
}
```

**Validation Rules**:
- Current index must be valid for tracks array
- Shuffled indices must be permutation of 0..<tracks.count

### ImportSession
**Purpose**: Transactional import operations
**Location**: `Data/Services/ImportSession.swift`

```swift
actor ImportSession {
    struct ImportItem: Sendable {
        var sourceURL: URL
        var destinationURL: URL
        var metadata: TrackMetadata
        var status: ImportStatus
    }

    enum ImportStatus: Sendable {
        case pending
        case extractingMetadata
        case copying
        case savingToDatabase
        case complete
        case failed(ImportError)
    }

    private var items: [ImportItem]
    private var progress: Progress

    // Transactional operations
    func addItem(_ url: URL) async throws
    func commit() async throws
    func rollback() async
    func getProgress() -> (completed: Int, total: Int, currentItem: String?)
}
```

**Transaction Rules**:
- All items must complete or all rollback
- File copy happens after metadata saved
- Cleanup on failure removes partial data

## Cache Models

### TrackCache
**Purpose**: LRU cache for frequently accessed tracks
**Location**: `Core/Audio/Cache/TrackCache.swift`

```swift
actor TrackCache {
    struct CacheEntry: Sendable {
        let track: Track
        var lastAccessed: Date
        var accessCount: Int
    }

    private var cache: [UUID: CacheEntry]
    private let maxSize: Int = 1000

    func get(_ id: UUID) async -> Track?
    func set(_ track: Track) async
    func evictLRU() async
    func invalidate(_ id: UUID) async
    func clear() async
}
```

**Eviction Policy**:
- LRU when cache full
- Keep high access count items longer
- Invalidate on track update

### SearchCache
**Purpose**: Cache search results
**Location**: `Data/Services/SearchCache.swift`

```swift
actor SearchCache {
    struct SearchResult: Sendable {
        let query: String
        let tracks: [Track]
        let albums: [Album]
        let artists: [Artist]
        let timestamp: Date
    }

    private var cache: [String: SearchResult]
    private let ttl: TimeInterval = 300 // 5 minutes

    func get(_ query: String) async -> SearchResult?
    func set(_ query: String, result: SearchResult) async
    func invalidateExpired() async
}
```

## Performance Metrics

### AudioMetrics
**Purpose**: Track audio performance
**Location**: `Core/Audio/Diagnostics/AudioMetrics.swift`

```swift
struct AudioMetrics: Sendable {
    // Latency
    var outputLatency: TimeInterval
    var bufferUnderruns: Int

    // Quality
    var actualSampleRate: Int
    var bitPerfectValidation: BitPerfectStatus

    // Resource usage
    var cpuUsage: Float // 0.0 to 1.0
    var memoryUsage: Int // Bytes

    // Session
    var sessionInterruptions: Int
    var routeChanges: Int
}
```

### ImportMetrics
**Purpose**: Track import performance
**Location**: `Data/Services/ImportMetrics.swift`

```swift
struct ImportMetrics: Sendable {
    var totalFiles: Int
    var successfulImports: Int
    var failedImports: Int
    var duplicatesSkipped: Int
    var averageFileProcessingTime: TimeInterval
    var totalImportTime: TimeInterval
}
```

## Migration Strategy

### Phase 1: Add Relationships
1. Add `@Relationship` macros to Album, Artist, Track
2. Run migration to establish existing relationships
3. Verify queries work correctly

### Phase 2: Implement Computed Properties
1. Replace placeholder returns with real calculations
2. Update UI to use computed properties
3. Remove redundant stored properties

### Phase 3: Add Caching
1. Implement TrackCache for library view
2. Add SearchCache for search results
3. Monitor cache hit rates

## Validation Requirements

### Data Integrity
- \u2705 All relationships bidirectional
- \u2705 No orphaned entities
- \u2705 Unique constraints enforced
- \u2705 Required fields validated

### Performance
- \u2705 Queries use indexes
- \u2705 Batch operations for bulk updates
- \u2705 Pagination for large result sets
- \u2705 Cache frequently accessed data

### Concurrency
- \u2705 All models are Sendable
- \u2705 Actor isolation for mutations
- \u2705 Thread-safe cache operations
- \u2705 No race conditions in state updates

## Future Considerations

### Potential Enhancements
- Full-text search with FTS5
- Smart playlists with predicates
- Play statistics and recommendations
- iCloud sync for library and playlists
- Multiple library support

### Scalability
- Partition large libraries by first letter
- Background indexing for new imports
- Incremental search with debouncing
- Virtual scrolling for huge lists