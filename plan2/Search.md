# Search Tab Implementation Plan

## Overview
Add a dedicated Search tab to Fonic HiFi, following the Apple Music Bottom Bar sample pattern while leveraging existing DataManager search APIs and components.

## Core Architecture

### 1. SearchView.swift Implementation
```swift
@MainActor
struct SearchView: View {
    @Environment(\.dataManager) private var dataManager
    @State private var searchText = ""
    @State private var searchResults = SearchResults()
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            // Implementation details...
        }
        .searchable(
            text: $searchText,
            placement: .toolbar,
            prompt: Text("Search your library")
        )
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await performSearch(newValue)
            }
        }
    }

    private func performSearch(_ query: String) async {
        guard let dataManager else { return }

        // Note: DataManager is @MainActor, so searches still execute on main actor
        // For true background execution, would need a background ModelContext
        let results = await Task.detached(priority: .userInitiated) {
            do {
                return try await searchAllContent(query, dataManager: dataManager)
            } catch {
                // Log error and return empty results
                print("Search failed: \(error)")
                return SearchResults()
            }
        }.value

        await MainActor.run {
            searchResults = results
        }
    }

    // Helper function to aggregate all searches
    private func searchAllContent(_ query: String, dataManager: DataManager) async throws -> SearchResults {
        async let tracks = try dataManager.searchTracks(query)
        async let albums = try dataManager.searchAlbums(query)
        async let artists = try dataManager.searchArtists(query)
        async let playlists = try dataManager.searchPlaylists(query)

        return try await SearchResults(
            tracks: tracks,
            albums: albums,
            artists: artists,
            playlists: playlists
        )
    }
}
```

### 2. DataManager.searchPlaylists Method
```swift
public func searchPlaylists(_ query: String, limit: Int = 50) async throws -> [Playlist] {
    let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !searchQuery.isEmpty else { return [] }

    var descriptor = FetchDescriptor<Playlist>(
        predicate: #Predicate<Playlist> { playlist in
            playlist.name.localizedStandardContains(searchQuery) ||
            playlist.playlistDescription?.localizedStandardContains(searchQuery) ?? false  // CORRECT property
        },
        sortBy: [SortDescriptor(\.name)]
    )
    descriptor.fetchLimit = limit
    return try mainContext.fetch(descriptor)
}
```

### 3. RecentSearchesActor Implementation (Using @ModelActor)
```swift
// In Data/Actors/RecentSearchesActor.swift
import SwiftData
import Foundation

@ModelActor
actor RecentSearchesActor {
    // @ModelActor provides modelExecutor and modelContainer
    // No need for manual ModelContext - it's provided as modelContext

    func addSearch(_ query: String) async throws {
        let search = RecentSearch(query: query, timestamp: Date())
        modelContext.insert(search)
        try modelContext.save()

        // Cleanup old searches (keep last 20)
        let descriptor = FetchDescriptor<RecentSearch>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let allSearches = try modelContext.fetch(descriptor)
        if allSearches.count > 20 {
            for search in allSearches.suffix(from: 20) {
                modelContext.delete(search)
            }
            try modelContext.save()
        }
    }

    func getRecentSearches(limit: Int = 10) async throws -> [RecentSearch] {
        var descriptor = FetchDescriptor<RecentSearch>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }
}
```

### 4. DataManager Schema Update with Migration
```swift
// In DataManager.init()
// Use versioned schema for consistency with migration plan
let modelConfiguration = ModelConfiguration(
    for: SchemaV1.self,  // Use versioned schema
    isStoredInMemoryOnly: false,
    allowsSave: true,
    cloudKitDatabase: .none
)

// Supply an explicit migration plan with versioned schema
do {
    container = try ModelContainer(
        for: SchemaV1.self,  // Use versioned schema
        migrationPlan: RecentSearchMigrationPlan.self,
        configurations: [modelConfiguration]
    )
} catch {
    throw DataManagerError.initializationFailed(error)
}

// Initialize RecentSearchesActor with @ModelActor pattern
self.recentSearchesActor = RecentSearchesActor(modelContainer: container)
```

### 5. SearchPlaylistResultsView (Dedicated Component)
```swift
// New file: SearchPlaylistResultsView.swift
struct SearchPlaylistResultsView: View {
    let playlists: [Playlist]  // Pre-filtered, no internal filtering

    var body: some View {
        List(playlists) { playlist in
            PlaylistRowView(playlist: playlist)
                .onTapGesture {
                    // Navigate to playlist detail
                }
        }
    }
}
```

### 6. ContentView.swift Updates
```swift
// First, add to ContentView's properties:
@Environment(\.dataManager) private var dataManager  // ADD THIS LINE

// Then in the TabView, add the Search tab:
SearchView()
    .environment(\.showingNowPlaying, $showingNowPlaying)
    .environment(\.audioEngine, audioService)
    .environment(\.importService, importService)
    // Note: dataManager and modelContext are already provided at app level (FonicHiFiApp.swift:52-55)
    // so they don't need to be passed again here, but are available via @Environment
    .tabItem {
        Label("Search", systemImage: "magnifyingglass")
    }
// The surrounding TabView already applies `.tabBarMinimizeBehavior(.onScrollDown)`
// and `.tabViewBottomAccessory { LiquidGlassMiniPlayer(...) }`, matching the iOS 26
// Apple Music sample. Adding this tab preserves that behavior.
```

## Files to Create

1. **`Fonic HiFi/Presentation/Views/Search/SearchView.swift`**
   - Main search interface with @MainActor annotations
   - Debounced search with task cancellation
   - Sectioned results display
   - Applies `.searchable(text:placement:prompt:)` to match Apple Music sample

2. **`Fonic HiFi/Presentation/Views/Search/SearchResults.swift`**
   - Value type `struct SearchResults` holding tracks/albums/artists/playlists

3. **`Fonic HiFi/Presentation/Views/Search/SearchPlaylistResultsView.swift`**
   - Dedicated playlist results without double-filtering
   - Uses PlaylistRowView for consistency

4. **`Fonic HiFi/Data/Models/RecentSearch.swift`**
   - SwiftData model for search history
   ```swift
   @Model
   final class RecentSearch {
       var query: String
       var timestamp: Date
       var resultCount: Int

       init(query: String, timestamp: Date, resultCount: Int = 0) {
           self.query = query
           self.timestamp = timestamp
           self.resultCount = resultCount
       }
   }
   ```

5. **`Fonic HiFi/Data/Actors/RecentSearchesActor.swift`**
   - Actor for managing recent searches using @ModelActor pattern
   - Automatic ModelContext provision via @ModelActor
   - Auto-cleanup of old searches (20 item limit)

6. **`Fonic HiFi/Data/Migration/RecentSearchMigrationPlan.swift`**
   - Migration plan and versioned schema for adding RecentSearch
   ```swift
   import SwiftData

   // Versioned schema that includes all models
   enum SchemaV1: VersionedSchema {
       static var versionIdentifier = Schema.Version(1, 0, 0)
       static var models: [any PersistentModel.Type] {
           [Track.self, Artist.self, Album.self, Playlist.self, RecentSearch.self]
       }
   }

   // Migration plan (lightweight migration for adding new model)
   enum RecentSearchMigrationPlan: SchemaMigrationPlan {
       static var schemas: [any VersionedSchema.Type] {
           [SchemaV1.self]
       }

       static var stages: [MigrationStage] {
           []  // Empty stages = lightweight migration
       }
   }
   ```

## Files to Modify

1. **`Fonic HiFi/Data/DataManager.swift`**
   - Add `searchPlaylists` method with correct `playlistDescription` property
   - Update schema to include `RecentSearch`
   - Add migration handling for schema changes
   - Initialize and expose `recentSearchesActor`
   - Add recent search management methods

2. **`Fonic HiFi/ContentView.swift`**
   - Add Search tab with all required environments
   - Use existing `.tabItem` pattern (not new `Tab` API)
   - Thread through all dependencies

## Implementation Order

1. Create `RecentSearch.swift` model
2. Create `RecentSearchMigrationPlan.swift` for schema migration
3. Create `RecentSearchesActor.swift` using @ModelActor pattern
4. Update `DataManager.swift` (schema with migration plan, `searchPlaylists`, recent search APIs)
5. Add `SearchResults.swift` value type
6. Create `SearchPlaylistResultsView.swift` for clean playlist display
7. Build `SearchView.swift` with debounced off-main search, error handling, and toolbar `.searchable`
8. Update `ContentView.swift` with @Environment for dataManager and new tab

## Key Design Decisions

### Search Strategy
- **Use DataManager APIs exclusively** - No duplicate filtering with `.matches()`
- **Debounced search** - 300ms delay with task cancellation
- **Search UI** - `.searchable` in the toolbar with Apple Music-style prompt
- **Concurrency Note** - DataManager is @MainActor, so searches still run on main actor
  - For true background search, would need background ModelContext (future enhancement)

### Playlist Handling
- **Option A chosen**: Dedicated `SearchPlaylistResultsView`
- Prevents double-filtering issue in `PlaylistListView`
- Pre-filtered results passed to view

### Recent Searches
- **SwiftData persistence** with 20-item limit
- **@ModelActor pattern** for RecentSearchesActor (matches TrackDataActor)
- **Explicit migration plan** via RecentSearchMigrationPlan (no container reset)
- **Concurrency-safe** with automatic ModelContext management

### UI Components
- **Reuse existing views**: TrackListView, AlbumGridView, ArtistListView
- **Pass `.constant("")` bindings** to prevent re-filtering
- **Standard `.searchable` modifier** with `placement: .toolbar` and prompt matching Apple Music sample

## Testing Requirements

1. **Schema Migration**
   - First launch with new RecentSearch model
   - Existing data preservation

2. **Search Performance**
   - Debouncing with rapid typing
   - Task cancellation verification
   - Large library performance (1000+ tracks)

3. **Recent Searches**
   - Persistence across app launches
   - 20-item limit enforcement
   - Cleanup of old entries

4. **UI Consistency**
   - All environments properly threaded
   - Navigation from results to detail views
   - Keyboard handling and dismissal

## Potential Issues & Solutions

### Issue: Cross-actor hops
**Solution**: Use @ModelActor pattern for RecentSearchesActor, keep DataManager operations @MainActor

### Issue: Double-filtering in PlaylistListView
**Solution**: Use dedicated SearchPlaylistResultsView with pre-filtered results

### Issue: Missing dataManager environment
**Solution**: Add `@Environment(\.dataManager)` to ContentView properties

### Issue: Schema migration failure
**Solution**: Explicit RecentSearchMigrationPlan with error throwing (preserves user libraries)

### Issue: Throwing search APIs
**Solution**: Wrap searches in do-catch blocks, return empty SearchResults on error

### Issue: ModelContext not Sendable
**Solution**: Use @ModelActor pattern which provides concurrency-safe ModelContext

## Success Criteria

- [ ] Search tab appears in tab bar with magnifying glass icon
- [ ] Search is responsive with debouncing
- [ ] All content types searchable (tracks, albums, artists, playlists)
- [ ] Recent searches persist and display
- [ ] No performance degradation with large libraries
- [ ] Proper navigation to detail views from results
- [ ] Clean integration with existing UI components