# Phase 2: Album Glass Morph Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the Home-exclusive album morph interaction where tapping an album card morphs it (via Liquid Glass) to an expanded track list overlay, and tapping a track dismisses and plays in the mini player.

**Architecture:** GlassEffectContainer wraps album cards + overlay. State controls which album (if any) is expanded. Expanded view shows track list with accent-tinted glass. Track tap triggers dismiss → play flow without navigating to NowPlaying.

**Tech Stack:** SwiftUI, iOS 26 Liquid Glass APIs (GlassEffectContainer, .glassEffectID, .glassEffectTransition), DominantColorService for accent colors, AudioEngineFacade for playback.

---

## Files Overview

| Action | Path |
|--------|------|
| Create | `Fonic HiFi/Presentation/Views/Home/Sections/ExpandableAlbumCard.swift` |
| Create | `Fonic HiFi/Presentation/Views/Home/Sections/ExpandedAlbumOverlay.swift` |
| Modify | `Fonic HiFi/Presentation/Views/Home/Sections/AlbumsSection.swift` |
| Modify | `Fonic HiFi/Presentation/Views/Home/HomeView.swift` |
| Create | `Fonic HiFiTests/ExpandableAlbumCardTests.swift` |

---

## Task 1: Create ExpandableAlbumCard Component

**Files:**
- Create: `Fonic HiFi/Presentation/Views/Home/Sections/ExpandableAlbumCard.swift`
- Test: `Fonic HiFiTests/ExpandableAlbumCardTests.swift`

**Step 1: Write the failing test**

```swift
// Fonic HiFiTests/ExpandableAlbumCardTests.swift
import SwiftUI
import Testing
@testable import Fonic_HiFi

@MainActor
struct ExpandableAlbumCardTests {
    @Test("Album card initializes with correct album data")
    func albumCardInitializesWithCorrectData() throws {
        let album = Album(title: "Test Album", albumArtist: "Test Artist", year: 2024)

        // Verify album properties are accessible
        #expect(album.title == "Test Album")
        #expect(album.albumArtist == "Test Artist")
        #expect(album.year == 2024)
    }

    @Test("ExpandableAlbumCard exists and is a View")
    func expandableAlbumCardIsView() throws {
        let album = Album(title: "Test", albumArtist: "Artist")
        let namespace = Namespace().wrappedValue

        let card = ExpandableAlbumCard(
            album: album,
            namespace: namespace,
            isExpanded: false,
            onTap: {}
        )

        // Card should be constructible
        #expect(type(of: card.body) != Never.self)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "Cannot find 'ExpandableAlbumCard' in scope"

**Step 3: Write minimal implementation**

```swift
// Fonic HiFi/Presentation/Views/Home/Sections/ExpandableAlbumCard.swift
//
//  ExpandableAlbumCard.swift
//  Fonic HiFi
//
//  Album card that supports glass morphing for Home screen expansion
//

import SwiftUI

@MainActor
struct ExpandableAlbumCard: View {
    let album: Album
    let namespace: Namespace.ID
    let isExpanded: Bool
    let onTap: () -> Void

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
        .glassEffect()
        .glassEffectID(album.id, in: namespace)
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    @Previewable @Namespace var namespace
    ExpandableAlbumCard(
        album: Album(title: "Sample Album", albumArtist: "Sample Artist"),
        namespace: namespace,
        isExpanded: false,
        onTap: {}
    )
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Home/Sections/ExpandableAlbumCard.swift" "Fonic HiFiTests/ExpandableAlbumCardTests.swift"
git commit -m "feat(home): add ExpandableAlbumCard with glass effect ID"
```

---

## Task 2: Create ExpandedAlbumOverlay Component

**Files:**
- Create: `Fonic HiFi/Presentation/Views/Home/Sections/ExpandedAlbumOverlay.swift`
- Test: `Fonic HiFiTests/ExpandableAlbumCardTests.swift` (add tests)

**Step 1: Write the failing test**

```swift
// Add to Fonic HiFiTests/ExpandableAlbumCardTests.swift
@Test("ExpandedAlbumOverlay exists and shows track list")
func expandedAlbumOverlayShowsTrackList() throws {
    let album = Album(title: "Test", albumArtist: "Artist")
    let namespace = Namespace().wrappedValue

    let overlay = ExpandedAlbumOverlay(
        album: album,
        namespace: namespace,
        accentColor: .blue,
        onTrackTap: { _ in },
        onDismiss: {}
    )

    #expect(type(of: overlay.body) != Never.self)
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "Cannot find 'ExpandedAlbumOverlay' in scope"

**Step 3: Write minimal implementation**

```swift
// Fonic HiFi/Presentation/Views/Home/Sections/ExpandedAlbumOverlay.swift
//
//  ExpandedAlbumOverlay.swift
//  Fonic HiFi
//
//  Expanded album view with track list, shown when album card is tapped on Home
//

import SwiftData
import SwiftUI

@MainActor
struct ExpandedAlbumOverlay: View {
    let album: Album
    let namespace: Namespace.ID
    let accentColor: Color
    let onTrackTap: (Track) -> Void
    let onDismiss: () -> Void

    @Query private var tracks: [Track]

    init(
        album: Album,
        namespace: Namespace.ID,
        accentColor: Color,
        onTrackTap: @escaping (Track) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.album = album
        self.namespace = namespace
        self.accentColor = accentColor
        self.onTrackTap = onTrackTap
        self.onDismiss = onDismiss

        // Filter tracks by album
        let albumTitle = album.title
        let albumArtist = album.albumArtist
        _tracks = Query(
            filter: #Predicate<Track> { track in
                track.album == albumTitle && track.albumArtist == albumArtist
            },
            sort: [
                SortDescriptor(\Track.discNumber),
                SortDescriptor(\Track.trackNumber)
            ]
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with artwork and album info
            headerView

            // Track list
            trackListView
        }
        .frame(maxWidth: 360)
        .glassEffect(.regular.tint(accentColor))
        .glassEffectID(album.id, in: namespace)
        .glassEffectTransition(.matchedGeometry)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
        .onTapGesture {
            // Tap outside track list dismisses
        }
    }

    private var headerView: some View {
        HStack(spacing: 16) {
            LazyArtworkView(album: album, size: 80, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(album.albumArtist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let year = album.year {
                    Text(String(year))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var trackListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(tracks) { track in
                    TrackRowView(track: track) {
                        onTrackTap(track)
                    }

                    if track.id != tracks.last?.id {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
        }
        .frame(maxHeight: 300)
    }
}

private struct TrackRowView: View {
    let track: Track
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text("\(track.trackNumber)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .trailing)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.body)
                        .lineLimit(1)

                    if track.artist != track.albumArtist {
                        Text(track.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(track.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @Namespace var namespace
    ExpandedAlbumOverlay(
        album: Album(title: "Sample Album", albumArtist: "Sample Artist", year: 2024),
        namespace: namespace,
        accentColor: .blue,
        onTrackTap: { _ in },
        onDismiss: {}
    )
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Home/Sections/ExpandedAlbumOverlay.swift" "Fonic HiFiTests/ExpandableAlbumCardTests.swift"
git commit -m "feat(home): add ExpandedAlbumOverlay with track list and glass tint"
```

---

## Task 3: Add Color Extraction Support for Albums

**Files:**
- Modify: `Fonic HiFi/Core/Services/DominantColorService.swift`
- Test: `Fonic HiFiTests/ExpandableAlbumCardTests.swift` (add test)

**Step 1: Write the failing test**

```swift
// Add to Fonic HiFiTests/ExpandableAlbumCardTests.swift
@Test("DominantColorService can extract color for album")
func dominantColorServiceExtractsAlbumColor() async throws {
    let service = DominantColorService.shared
    let album = Album(title: "Test", albumArtist: "Artist")

    // Should be able to call extractColor for album
    await service.extractColor(for: album)

    // Palette should exist (neutral if no artwork)
    #expect(service.palette != nil)
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "cannot convert value of type 'Album' to expected argument type 'Track?'"

**Step 3: Add album color extraction method**

```swift
// Add to Fonic HiFi/Core/Services/DominantColorService.swift
// After the existing extractColor(for track: Track?) method

/// Extract dominant color for the given album.
/// Uses cache if available, otherwise extracts asynchronously.
func extractColor(for album: Album?) async {
    guard let album else {
        rawDominantColor = .accentColor
        currentTrackID = nil
        withAnimation(.easeInOut(duration: transitionDuration)) {
            rebuildPalette()
        }
        return
    }

    // Check cache first (reusing same cache as tracks)
    if let cached = colorCache[album.id] {
        rawDominantColor = cached
        currentTrackID = album.id
        withAnimation(.easeInOut(duration: transitionDuration)) {
            rebuildPalette()
        }
        return
    }

    // Guard concurrent extractions
    guard !isExtractingColor else { return }
    isExtractingColor = true
    defer { isExtractingColor = false }

    // No artwork - use default
    guard let artworkData = album.artwork else {
        rawDominantColor = .accentColor
        currentTrackID = album.id
        withAnimation(.easeInOut(duration: transitionDuration)) {
            rebuildPalette()
        }
        return
    }

    // Extract on background thread
    let extractedColor = await Task.detached(priority: .utility) {
        UIImage(data: artworkData)?.fastAverageColor ?? Color.accentColor
    }.value

    // Cache result
    colorCache[album.id] = extractedColor
    maintainCacheSize()

    // Apply with animation
    rawDominantColor = extractedColor
    currentTrackID = album.id
    withAnimation(.easeInOut(duration: transitionDuration)) {
        rebuildPalette()
    }
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Core/Services/DominantColorService.swift" "Fonic HiFiTests/ExpandableAlbumCardTests.swift"
git commit -m "feat(color): add album color extraction to DominantColorService"
```

---

## Task 4: Integrate GlassEffectContainer in AlbumsSection

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/Home/Sections/AlbumsSection.swift`

**Step 1: Update AlbumsSection to use GlassEffectContainer and ExpandableAlbumCard**

```swift
// Fonic HiFi/Presentation/Views/Home/Sections/AlbumsSection.swift
//
//  AlbumsSection.swift
//  Fonic HiFi
//
//  Horizontal scrolling albums carousel with glass morph support
//

import SwiftUI

@MainActor
struct AlbumsSection: View {
    let title: String
    let albums: [Album]
    let expandedAlbumID: UUID?
    let namespace: Namespace.ID
    let onAlbumTap: (Album) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.bold())
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer {
                    HStack(spacing: 16) {
                        ForEach(albums) { album in
                            ExpandableAlbumCard(
                                album: album,
                                namespace: namespace,
                                isExpanded: expandedAlbumID == album.id,
                                onTap: { onAlbumTap(album) }
                            )
                            .opacity(shouldHideCard(for: album) ? 0 : 1)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func shouldHideCard(for album: Album) -> Bool {
        expandedAlbumID == album.id
    }
}

#Preview {
    @Previewable @Namespace var namespace
    AlbumsSection(
        title: "Albums",
        albums: [],
        expandedAlbumID: nil,
        namespace: namespace,
        onAlbumTap: { _ in }
    )
}
```

**Step 2: Run lint and build**

Run: `make lint && make build`
Expected: PASS

**Step 3: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Home/Sections/AlbumsSection.swift"
git commit -m "feat(home): integrate GlassEffectContainer in AlbumsSection"
```

---

## Task 5: Update HomeView with Expansion State and Overlay

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/Home/HomeView.swift`

**Step 1: Add expansion state and namespace**

Add these properties to HomeView after existing state:

```swift
// Add to HomeView state section (around line 28)
@Namespace private var albumMorphNamespace
@State private var expandedAlbum: Album?
@State private var expandedAlbumColor: Color = .accentColor
```

**Step 2: Update AlbumsSection calls to pass namespace and expansion state**

Replace the AlbumsSection usage in contentView (around line 97):

```swift
// Albums
if !albums.isEmpty {
    AlbumsSection(
        title: "Albums",
        albums: albums,
        expandedAlbumID: expandedAlbum?.id,
        namespace: albumMorphNamespace,
        onAlbumTap: { album in
            expandAlbum(album)
        }
    )
}
```

And for Favorite Albums (around line 118):

```swift
// Favorite Albums
if !favoriteAlbums.isEmpty {
    AlbumsSection(
        title: "Favorite Albums",
        albums: favoriteAlbums,
        expandedAlbumID: expandedAlbum?.id,
        namespace: albumMorphNamespace,
        onAlbumTap: { album in
            expandAlbum(album)
        }
    )
}
```

**Step 3: Add overlay and helper methods**

Add overlay after contentView ScrollView, before navigation modifiers:

```swift
// Add after ScrollView closing brace in contentView
.overlay {
    if let album = expandedAlbum {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .onTapGesture {
                collapseAlbum()
            }

        GlassEffectContainer {
            ExpandedAlbumOverlay(
                album: album,
                namespace: albumMorphNamespace,
                accentColor: expandedAlbumColor,
                onTrackTap: { track in
                    playTrackFromAlbum(track)
                },
                onDismiss: {
                    collapseAlbum()
                }
            )
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}
.animation(.spring(response: 0.5, dampingFraction: 0.85), value: expandedAlbum?.id)
```

Add helper methods after playTrack:

```swift
private func expandAlbum(_ album: Album) {
    Task {
        await DominantColorService.shared.extractColor(for: album)
        expandedAlbumColor = DominantColorService.shared.palette.glassTint
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            expandedAlbum = album
        }
    }
}

private func collapseAlbum() {
    withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
        expandedAlbum = nil
    }
}

private func playTrackFromAlbum(_ track: Track) {
    guard let audioEngine else { return }

    // First collapse, then play
    collapseAlbum()

    Task {
        // Small delay to let animation complete
        try? await Task.sleep(for: .milliseconds(150))

        do {
            try await audioEngine.play(track: track)
            // Don't show NowPlaying - play in mini player only
        } catch {
            // Handle error silently
        }
    }
}
```

**Step 4: Run lint and build**

Run: `make lint && make build`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Home/HomeView.swift"
git commit -m "feat(home): add album expansion overlay with glass morph transition"
```

---

## Task 6: Run Full Test Suite and Verify

**Step 1: Run all tests**

Run: `make test`
Expected: All tests pass (311+ tests)

**Step 2: Run the app in simulator**

Run: `make run`
Expected: App launches, Home tab shows, albums can be tapped to expand

**Step 3: Manual verification checklist**

- [ ] Album cards show in Home screen
- [ ] Tapping album card shows expanded overlay with glass effect
- [ ] Overlay has accent color tint from album artwork
- [ ] Track list shows album tracks sorted by disc/track number
- [ ] Tapping a track dismisses overlay and plays in mini player
- [ ] Tapping X button dismisses overlay
- [ ] Tapping backdrop dismisses overlay
- [ ] Morph animation is smooth (spring ~0.5s response)

**Step 4: Commit if any fixes needed**

```bash
git add -A
git commit -m "fix(home): polish album morph interaction"
```

---

## Summary

| Task | Description | Files Changed |
|------|-------------|---------------|
| 1 | Create ExpandableAlbumCard | +ExpandableAlbumCard.swift, +Tests |
| 2 | Create ExpandedAlbumOverlay | +ExpandedAlbumOverlay.swift |
| 3 | Album color extraction | ~DominantColorService.swift |
| 4 | GlassEffectContainer integration | ~AlbumsSection.swift |
| 5 | HomeView expansion state | ~HomeView.swift |
| 6 | Test and verify | Manual testing |

**Key Implementation Details:**
- Uses native iOS 26 `GlassEffectContainer` + `.glassEffectID()` + `.glassEffectTransition(.matchedGeometry)`
- Album accent color extracted via `DominantColorService.shared.extractColor(for: album)`
- Track tap: dismiss overlay → play track (mini player only, no NowPlaying navigation)
- Spring animation: response 0.5, dampingFraction 0.85
