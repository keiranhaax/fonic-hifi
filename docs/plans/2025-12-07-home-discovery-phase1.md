# Home Screen Discovery Phase 1 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform HomeView from basic sections into a discovery experience with Recently Added, Artists, Genres, Albums sections, and Quick Action buttons (Shuffle All, Surprise Me).

**Architecture:** Extend existing HomeView with new section components. Add DataManager query methods for artists, genres, and albums. Use existing patterns (HomeSection wrapper, carousel/grid layouts, glass effects).

**Tech Stack:** SwiftUI, SwiftData, iOS 26 Liquid Glass (.glassEffect, .buttonSizing)

---

## Task 1: Add Artist Query Method to DataManager

**Files:**
- Modify: `Fonic HiFi/Data/DataManager+Recent.swift`
- Test: `Fonic HiFiTests/DataManagerRecentTests.swift`

**Step 1: Write the failing test**

Add to `DataManagerRecentTests.swift`:

```swift
func testGetAllArtistsReturnsSortedByName() async throws {
    try insertArtist(name: "Zeppelin")
    try insertArtist(name: "ABBA")
    try insertArtist(name: "Metallica")
    try manager.mainContext.save()

    let artists = try await manager.getAllArtists(limit: 10)
    XCTAssertEqual(artists.count, 3)
    XCTAssertEqual(artists.map(\.name), ["ABBA", "Metallica", "Zeppelin"])
}

private func insertArtist(name: String) throws {
    let artist = Artist(name: name)
    manager.mainContext.insert(artist)
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "Value of type 'DataManager' has no member 'getAllArtists'"

**Step 3: Write minimal implementation**

Add to `DataManager+Recent.swift`:

```swift
func getAllArtists(limit: Int = 50) async throws -> [Artist] {
    var descriptor = FetchDescriptor<Artist>(
        sortBy: [SortDescriptor(\.sortName, order: .forward)]
    )
    descriptor.fetchLimit = limit

    do {
        return try mainContext.fetch(descriptor)
    } catch {
        logger.error("Failed to get artists: \(error.localizedDescription)")
        throw DataManagerError.fetchFailed(error)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Data/DataManager+Recent.swift" "Fonic HiFiTests/DataManagerRecentTests.swift"
git commit -m "feat(data): add getAllArtists query method"
```

---

## Task 2: Add Unique Genres Query Method to DataManager

**Files:**
- Modify: `Fonic HiFi/Data/DataManager+Recent.swift`
- Test: `Fonic HiFiTests/DataManagerRecentTests.swift`

**Step 1: Write the failing test**

Add to `DataManagerRecentTests.swift`:

```swift
func testGetUniqueGenresReturnsDistinctGenresSorted() async throws {
    try insertTrack(name: "Track1", genre: "Rock")
    try insertTrack(name: "Track2", genre: "Jazz")
    try insertTrack(name: "Track3", genre: "Rock") // Duplicate
    try insertTrack(name: "Track4", genre: "Electronic")
    try insertTrack(name: "Track5", genre: nil) // No genre
    try manager.mainContext.save()

    let genres = try await manager.getUniqueGenres()
    XCTAssertEqual(genres, ["Electronic", "Jazz", "Rock"])
}

// Update insertTrack helper to accept genre parameter
private func insertTrack(
    name: String,
    dateAdded: Date = Date(),
    lastPlayed: Date? = nil,
    genre: String? = nil
) throws {
    let track = Track(
        url: temporaryDirectory.appendingPathComponent("\(name).mp3"),
        title: name,
        artist: "Artist",
        album: "Album"
    )
    track.dateAdded = dateAdded
    track.lastPlayed = lastPlayed
    track.genre = genre
    manager.mainContext.insert(track)
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "Value of type 'DataManager' has no member 'getUniqueGenres'"

**Step 3: Write minimal implementation**

Add to `DataManager+Recent.swift`:

```swift
func getUniqueGenres() async throws -> [String] {
    let descriptor = FetchDescriptor<Track>()

    do {
        let tracks = try mainContext.fetch(descriptor)
        let genres = Set(tracks.compactMap(\.genre))
        return genres.sorted()
    } catch {
        logger.error("Failed to get unique genres: \(error.localizedDescription)")
        throw DataManagerError.fetchFailed(error)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Data/DataManager+Recent.swift" "Fonic HiFiTests/DataManagerRecentTests.swift"
git commit -m "feat(data): add getUniqueGenres query method"
```

---

## Task 3: Add All Albums Query Method to DataManager

**Files:**
- Modify: `Fonic HiFi/Data/DataManager+Recent.swift`
- Test: `Fonic HiFiTests/DataManagerRecentTests.swift`

**Step 1: Write the failing test**

Add to `DataManagerRecentTests.swift`:

```swift
func testGetAllAlbumsReturnsSortedByDateAdded() async throws {
    let baseDate = Date()
    try insertAlbum(title: "Old Album", dateAdded: baseDate.addingTimeInterval(-3600))
    try insertAlbum(title: "New Album", dateAdded: baseDate)
    try insertAlbum(title: "Mid Album", dateAdded: baseDate.addingTimeInterval(-1800))
    try manager.mainContext.save()

    let albums = try await manager.getAllAlbums(limit: 10)
    XCTAssertEqual(albums.count, 3)
    XCTAssertEqual(albums.map(\.title), ["New Album", "Mid Album", "Old Album"])
}

private func insertAlbum(title: String, dateAdded: Date = Date()) throws {
    let album = Album(title: title, albumArtist: "Artist")
    album.dateAdded = dateAdded
    manager.mainContext.insert(album)
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "Value of type 'DataManager' has no member 'getAllAlbums'"

**Step 3: Write minimal implementation**

Add to `DataManager+Recent.swift`:

```swift
func getAllAlbums(limit: Int = 50) async throws -> [Album] {
    var descriptor = FetchDescriptor<Album>(
        sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
    )
    descriptor.fetchLimit = limit

    do {
        return try mainContext.fetch(descriptor)
    } catch {
        logger.error("Failed to get albums: \(error.localizedDescription)")
        throw DataManagerError.fetchFailed(error)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Data/DataManager+Recent.swift" "Fonic HiFiTests/DataManagerRecentTests.swift"
git commit -m "feat(data): add getAllAlbums query method"
```

---

## Task 4: Create QuickActionsSection Component

**Files:**
- Create: `Fonic HiFi/Presentation/Views/Home/Sections/QuickActionsSection.swift`

**Step 1: Create the section file**

```swift
//
//  QuickActionsSection.swift
//  Fonic HiFi
//
//  Quick action buttons for Shuffle All and Surprise Me
//

import SwiftUI

@MainActor
struct QuickActionsSection: View {
    @Environment(\.audioEngine) private var audioEngine

    let onShuffleAll: () -> Void
    let onSurpriseMe: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button {
                onShuffleAll()
            } label: {
                Label("Shuffle All", systemImage: "shuffle")
                    .frame(maxWidth: .infinity)
            }
            .buttonSizing(.flexible)
            .glassEffect(.regular.interactive())

            Button {
                onSurpriseMe()
            } label: {
                Label("Surprise Me", systemImage: "dice")
                    .frame(maxWidth: .infinity)
            }
            .buttonSizing(.flexible)
            .glassEffect(.regular.interactive())
        }
        .padding(.horizontal)
    }
}

#Preview {
    QuickActionsSection(
        onShuffleAll: { print("Shuffle") },
        onSurpriseMe: { print("Surprise") }
    )
    .padding()
}
```

**Step 2: Build to verify it compiles**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Home/Sections/QuickActionsSection.swift"
git commit -m "feat(home): add QuickActionsSection with Shuffle All and Surprise Me buttons"
```

---

## Task 5: Create ArtistsSection Component

**Files:**
- Create: `Fonic HiFi/Presentation/Views/Home/Sections/ArtistsSection.swift`

**Step 1: Create the section file**

```swift
//
//  ArtistsSection.swift
//  Fonic HiFi
//
//  Horizontal scrolling artist avatars section
//

import SwiftUI

@MainActor
struct ArtistsSection: View {
    let artists: [Artist]
    let onArtistTap: (Artist) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Artists")
                .font(.title2.bold())
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(artists) { artist in
                        ArtistAvatarView(artist: artist)
                            .onTapGesture {
                                onArtistTap(artist)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct ArtistAvatarView: View {
    let artist: Artist

    var body: some View {
        VStack(spacing: 8) {
            Group {
                if let artworkData = artist.artwork,
                   let uiImage = UIImage(data: artworkData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "music.mic")
                        .font(.title)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGray5))
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())

            Text(artist.name)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 80)
        }
    }
}

#Preview {
    ArtistsSection(
        artists: [],
        onArtistTap: { _ in }
    )
}
```

**Step 2: Build to verify it compiles**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Home/Sections/ArtistsSection.swift"
git commit -m "feat(home): add ArtistsSection with circular artist avatars"
```

---

## Task 6: Create GenresSection Component

**Files:**
- Create: `Fonic HiFi/Presentation/Views/Home/Sections/GenresSection.swift`

**Step 1: Create the section file**

```swift
//
//  GenresSection.swift
//  Fonic HiFi
//
//  Horizontal scrolling genre pills section
//

import SwiftUI

@MainActor
struct GenresSection: View {
    let genres: [String]
    let onGenreTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Browse by Genre")
                .font(.title2.bold())
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(genres, id: \.self) { genre in
                        GenrePillView(genre: genre)
                            .onTapGesture {
                                onGenreTap(genre)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct GenrePillView: View {
    let genre: String

    var body: some View {
        Text(genre)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular.interactive())
    }
}

#Preview {
    GenresSection(
        genres: ["Rock", "Jazz", "Electronic", "Classical", "Hip-Hop"],
        onGenreTap: { _ in }
    )
}
```

**Step 2: Build to verify it compiles**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Home/Sections/GenresSection.swift"
git commit -m "feat(home): add GenresSection with glass pill styling"
```

---

## Task 7: Create AlbumsSection Component

**Files:**
- Create: `Fonic HiFi/Presentation/Views/Home/Sections/AlbumsSection.swift`

**Step 1: Create the section file**

```swift
//
//  AlbumsSection.swift
//  Fonic HiFi
//
//  Horizontal scrolling albums carousel section
//

import SwiftUI

@MainActor
struct AlbumsSection: View {
    let title: String
    let albums: [Album]
    let onAlbumTap: (Album) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.bold())
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(albums) { album in
                        HomeAlbumCardView(album: album)
                            .onTapGesture {
                                onAlbumTap(album)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct HomeAlbumCardView: View {
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyArtworkView(album: album, size: 140, cornerRadius: 8)

            Text(album.title)
                .font(.callout.bold())
                .lineLimit(1)

            Text(album.albumArtist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 140)
    }
}

#Preview {
    AlbumsSection(
        title: "Albums",
        albums: [],
        onAlbumTap: { _ in }
    )
}
```

**Step 2: Build to verify it compiles**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Home/Sections/AlbumsSection.swift"
git commit -m "feat(home): add AlbumsSection carousel component"
```

---

## Task 8: Create RecentlyAddedSection Component

**Files:**
- Create: `Fonic HiFi/Presentation/Views/Home/Sections/RecentlyAddedSection.swift`

**Step 1: Create the section file**

```swift
//
//  RecentlyAddedSection.swift
//  Fonic HiFi
//
//  Hero section showing recently added tracks with large artwork
//

import SwiftUI

@MainActor
struct RecentlyAddedSection: View {
    let tracks: [Track]
    let onTrackTap: (Track) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Added")
                .font(.title2.bold())
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(tracks) { track in
                        RecentlyAddedCardView(track: track)
                            .onTapGesture {
                                onTrackTap(track)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct RecentlyAddedCardView: View {
    let track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyArtworkView(track: track, size: 160, cornerRadius: 12)

            Text(track.title)
                .font(.callout.bold())
                .lineLimit(1)

            Text(track.artist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 160)
    }
}

#Preview {
    RecentlyAddedSection(
        tracks: [],
        onTrackTap: { _ in }
    )
}
```

**Step 2: Build to verify it compiles**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Home/Sections/RecentlyAddedSection.swift"
git commit -m "feat(home): add RecentlyAddedSection with large artwork cards"
```

---

## Task 9: Update HomeView with New Sections

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/Home/HomeView.swift`

**Step 1: Update HomeView state properties**

Replace the state section with:

```swift
@MainActor
struct HomeView: View {
    @Environment(\.dataManager) private var dataManager
    @Environment(\.audioEngine) private var audioEngine
    @Environment(\.showingNowPlaying) private var showingNowPlaying

    // Fresh library state
    @State private var recentlyAdded: [Track] = []
    @State private var artists: [Artist] = []
    @State private var genres: [String] = []
    @State private var albums: [Album] = []

    // Active library state (existing)
    @State private var recentlyPlayed: [Track] = []
    @State private var mostListened: [Track] = []
    @State private var favoriteAlbums: [Album] = []

    // UI state
    @State private var isLoading = true
    @State private var selectedArtist: Artist?
    @State private var selectedGenre: String?
    @State private var selectedAlbum: Album?
```

**Step 2: Update body with new sections**

Replace the body with:

```swift
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading your music...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isEmpty {
                    EmptyHomeView()
                } else {
                    contentView
                }
            }
            .navigationTitle("Home")
            .task {
                await loadData()
            }
            .sheet(item: $selectedArtist) { artist in
                ArtistDetailView(artist: artist)
            }
            .sheet(item: $selectedAlbum) { album in
                AlbumDetailView(album: album)
            }
        }
    }

    private var isEmpty: Bool {
        recentlyAdded.isEmpty && artists.isEmpty && genres.isEmpty && albums.isEmpty &&
        recentlyPlayed.isEmpty && mostListened.isEmpty && favoriteAlbums.isEmpty
    }

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Quick Actions
                QuickActionsSection(
                    onShuffleAll: shuffleAll,
                    onSurpriseMe: surpriseMe
                )

                // Recently Added (hero section)
                if !recentlyAdded.isEmpty {
                    RecentlyAddedSection(tracks: recentlyAdded) { track in
                        playTrack(track)
                    }
                }

                // Your Artists
                if !artists.isEmpty {
                    ArtistsSection(artists: artists) { artist in
                        selectedArtist = artist
                    }
                }

                // Browse by Genre
                if !genres.isEmpty {
                    GenresSection(genres: genres) { genre in
                        selectedGenre = genre
                    }
                }

                // Albums
                if !albums.isEmpty {
                    AlbumsSection(title: "Albums", albums: albums) { album in
                        selectedAlbum = album
                    }
                }

                // Recently Played (if user has history)
                if !recentlyPlayed.isEmpty {
                    HomeSection(title: "Recently Played") {
                        CarouselView(tracks: recentlyPlayed)
                    }
                }

                // Most Listened (if user has history)
                if !mostListened.isEmpty {
                    HomeSection(title: "Most Listened") {
                        CarouselView(tracks: mostListened)
                    }
                }

                // Favorite Albums
                if !favoriteAlbums.isEmpty {
                    AlbumsSection(title: "Favorite Albums", albums: favoriteAlbums) { album in
                        selectedAlbum = album
                    }
                }
            }
            .padding(.vertical)
        }
    }
```

**Step 3: Update loadData with new queries**

Replace loadData with:

```swift
    private func loadData() async {
        isLoading = true

        guard let dataManager else {
            isLoading = false
            return
        }

        do {
            // Fresh library data
            recentlyAdded = try await dataManager.getRecentlyAddedTracks(limit: 10)
            artists = try await dataManager.getAllArtists(limit: 15)
            genres = try await dataManager.getUniqueGenres()
            albums = try await dataManager.getAllAlbums(limit: 10)

            // Active library data
            recentlyPlayed = try await dataManager.getRecentlyPlayedTracks(limit: 10)
            mostListened = try await dataManager.getMostListenedTracks(limit: 10)
            favoriteAlbums = try await dataManager.getFavoriteAlbums(limit: 10)
        } catch {
            // Silently handle errors - home screen shows empty state gracefully
        }

        isLoading = false
    }
```

**Step 4: Add action methods**

Add after loadData:

```swift
    private func shuffleAll() {
        guard let dataManager, let audioEngine else { return }
        Task {
            do {
                let allTracks = try await dataManager.getRecentlyAddedTracks(limit: 1000)
                guard !allTracks.isEmpty else { return }

                audioEngine.queueManager.setQueue(allTracks.shuffled())
                if let first = audioEngine.queueManager.currentQueue.first {
                    try await audioEngine.play(track: first)
                    showingNowPlaying.wrappedValue = true
                }
            } catch {
                // Handle error silently
            }
        }
    }

    private func surpriseMe() {
        // Phase 4: Will use Foundation Models
        // For now: same as shuffle
        shuffleAll()
    }

    private func playTrack(_ track: Track) {
        guard let audioEngine else { return }
        Task {
            do {
                try await audioEngine.play(track: track)
                showingNowPlaying.wrappedValue = true
            } catch {
                // Handle error silently
            }
        }
    }
```

**Step 5: Build to verify it compiles**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Home/HomeView.swift"
git commit -m "feat(home): integrate all discovery sections into HomeView"
```

---

## Task 10: Run Full Test Suite and Verify

**Step 1: Run all tests**

Run: `make test`
Expected: All tests pass (311+ tests)

**Step 2: Run the app in simulator**

Run: `make run`
Expected: App launches, Home screen shows new sections when library has content

**Step 3: Manual verification checklist**

- [ ] Empty library shows welcome message
- [ ] Quick Action buttons appear and have glass effect
- [ ] Recently Added section shows imported tracks
- [ ] Your Artists section shows circular avatars
- [ ] Browse by Genre shows glass pills
- [ ] Albums section shows album artwork
- [ ] Tapping Shuffle All plays music
- [ ] Tapping artist opens detail sheet
- [ ] Tapping album opens detail sheet

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat(home): complete Phase 1 Home Discovery implementation

- Add getAllArtists, getUniqueGenres, getAllAlbums queries
- Create QuickActionsSection with Shuffle All/Surprise Me buttons
- Create ArtistsSection with circular avatars
- Create GenresSection with glass pills
- Create AlbumsSection carousel
- Create RecentlyAddedSection hero section
- Integrate all sections into HomeView
- Wire up navigation and playback actions"
```

---

## Summary

This plan implements Phase 1 of the Home Screen Discovery feature:

| Task | Component | Lines of Code |
|------|-----------|---------------|
| 1-3 | DataManager query methods | ~60 |
| 4 | QuickActionsSection | ~40 |
| 5 | ArtistsSection | ~50 |
| 6 | GenresSection | ~40 |
| 7 | AlbumsSection | ~45 |
| 8 | RecentlyAddedSection | ~45 |
| 9 | HomeView integration | ~100 |
| 10 | Testing & verification | - |

**Total estimated implementation time:** 45-60 minutes

---

Plan complete and saved to `docs/plans/2025-12-07-home-discovery-phase1.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
