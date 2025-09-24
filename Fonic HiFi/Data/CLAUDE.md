# Data Layer CLAUDE.md

SwiftData patterns and actor isolation for iOS 26. Verify with apple-rag/sosumi.

## STRICT IMPLEMENTATION RULES

- **NEVER** create mock data, fake APIs, or placeholder values
- **NEVER** use TODO, FIXME, or stub comments in code
- **NEVER** comment out code - remove or implement properly
- **ALWAYS** verify implementation matches user requirements exactly
- **ALWAYS** implement complete, working solutions
- **ALWAYS** double-check before editing/commenting - implement correctly
- Comments are OK if concise and helpful for understanding

## ACTOR ISOLATION [Verified-Code]

**TrackDataActor:**
- `@ModelActor` - Automatic SwiftData context isolation
- ALL database operations MUST go through this actor
- Returns `PersistentIdentifier` for cross-actor references

**ACTUAL CODE** (`TrackDataActor.swift:13-14`):
```swift
@ModelActor
public actor TrackDataActor {
    // ModelActor provides automatic isolation
    private let logger = Logger(subsystem: "com.fonichifi.data", category: "TrackDataActor")
}
```

**ACTUAL PATTERN** (`LibraryImportService.swift:87-90`):
```swift
// From MainActor to TrackDataActor
importTask = Task { @MainActor in
    self.statusMessage = "Scanning for audio files..."
    let audioFiles = await self.discoverAudioFilesWithSecurityScope(from: urls)
}
```

**ACTUAL CROSS-ACTOR** (`LibraryImportService.swift:444-445`):
```swift
// Create Track via TrackDataActor (handles persistence)
let trackId = try await trackDataActor.createTrack(from: trackMetadata)
```

## SWIFTDATA iOS 26 FEATURES [Verified-Apple]

**Class Inheritance (NEW):**
- Models can now use inheritance hierarchies
- Subclasses share base properties
- Migration required for inheritance adoption

**Schema Migration [Verified-Apple]:**
```swift
// Version your schemas
struct SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [Track.self]
}

// Migration stages
enum MigrationStage {
    static let v1ToV2 = MigrationStage.lightweight  // Simple changes
    static let v2ToV3 = MigrationStage.custom {     // Complex logic
        // Deduplicate, transform data
    }
}
```

## PERFORMANCE PATTERNS

**Batch Operations:**
```swift
// GOOD: Single context save
func importTracks(_ metadatas: [TrackMetadata]) async {
    for metadata in metadatas {
        let track = Track(from: metadata)
        modelContext.insert(track)
    }
    try? modelContext.save()  // One save for all
}
```

**ACTUAL IMPLEMENTATION** (`DataManager.swift:71`):
```swift
// Actor initialization with ModelContainer
trackDataActor = TrackDataActor(modelContainer: container)
```

**Fetch Optimization:**
```swift
// Use descriptors for complex queries
let descriptor = FetchDescriptor<Track>(
    predicate: #Predicate { $0.isLossless == true },
    sortBy: [SortDescriptor(\.title)]
)
descriptor.fetchLimit = 50  // Pagination
```

## MIGRATION BEST PRACTICES [Verified-Apple]

**Schema Evolution:**
1. Create `VersionedSchema` for current release
2. Define migration stages (lightweight preferred)
3. Custom stages for data transformation
4. Test migration from all previous versions

**Custom Migration Example:**
```swift
struct V2ToV3Migration: SchemaMigrationPlan {
    func willMigrate(from: SchemaV2, to: SchemaV3, using context: ModelContext) {
        // Deduplicate before unique constraint
        let tracks = try context.fetch(FetchDescriptor<Track>())
        // Remove duplicates...
    }
}
```

## RELATIONSHIPS

**Implicit Inverse:**
- SwiftData automatically discovers inverse relationships
- Default delete rule: nullify

**Explicit Delete Rules:**
```swift
@Relationship(deleteRule: .cascade)
var tracks: [Track]  // Deletes tracks when parent deleted

@Relationship(deleteRule: .deny)
var album: Album?  // Prevents deletion if relationship exists
```

## SENDABLE CONFORMANCE

**TrackMetadata (Sendable struct):**
```swift
struct TrackMetadata: Sendable {
    let url: URL
    let title: String
    // All properties must be Sendable
}
```

**Cross-Actor Communication:**
- Pass `PersistentIdentifier` not model objects
- Use Sendable DTOs for data transfer
- Fetch models within target actor

## COMMON PATTERNS

**Import Service Flow:**
1. Extract metadata (background)
2. Create Sendable DTO
3. Pass to TrackDataActor
4. Return PersistentIdentifier
5. Update UI on MainActor

**Search Implementation:**
```swift
@ModelActor
func search(_ query: String) -> [PersistentIdentifier] {
    let predicate = #Predicate<Track> { track in
        track.title.localizedStandardContains(query) ||
        track.artist.localizedStandardContains(query)
    }
    let results = try? modelContext.fetch(FetchDescriptor(predicate: predicate))
    return results?.map(\.id) ?? []
}
```

## DEBUG & MONITORING

```bash
make profile-memory    # SwiftData memory usage
make logs-filter SUBSYSTEM='com.fonichifi.data'
```

## KEY FILES

- `TrackDataActor.swift:13`: Database operations (@ModelActor)
- `LibraryImportService.swift:42`: Batch imports (uses TrackDataActor)
- `MetadataExtractionService.swift`: File processing
- `Models/Track.swift`: SwiftData model definitions
- `DataManager.swift:71`: TrackDataActor initialization
- `RecentSearchesActor.swift`: Search history (@ModelActor)