# Remaining Features Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement four remaining features: Favorites heart button, Queue display UI, Lyrics display, and A-B loop.

**Architecture:** Each feature follows iOS 26 patterns with Liquid Glass styling, Swift 6.2 strict concurrency (@MainActor for UI, TrackDataActor for SwiftData), and existing AudioEngineFacade/AudioQueueManager infrastructure.

**Tech Stack:** SwiftUI (iOS 26), SwiftData, AVAudioEngine, Swift 6.2 concurrency, Liquid Glass `.glassEffect()`

---

## Feature 1: Favorites Heart Button

**Total Time:** ~2.5 hours

### Task 1.1: Add toggleFavorite method to TrackDataActor

**Files:**
- Modify: `Fonic HiFi/Data/Actors/TrackDataActor.swift`
- Test: `Fonic HiFiTests/TrackDataActorTests.swift`

**Step 1: Write the failing test**

```swift
// In TrackDataActorTests.swift
func testToggleFavorite() async throws {
    // Given
    let track = Track(title: "Test Track", artist: "Test Artist", url: testURL)
    track.isFavorite = false
    modelContext.insert(track)
    try modelContext.save()

    // When
    try await sut.toggleFavorite(trackId: track.id)

    // Then
    let fetched = try modelContext.fetch(FetchDescriptor<Track>(predicate: #Predicate { $0.id == track.id })).first
    XCTAssertTrue(fetched?.isFavorite == true)
}
```

**Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL with "toggleFavorite not found"

**Step 3: Write minimal implementation**

```swift
// In TrackDataActor.swift, add method:
func toggleFavorite(trackId: UUID) async throws {
    let descriptor = FetchDescriptor<Track>(predicate: #Predicate { $0.id == trackId })
    guard let track = try modelContext.fetch(descriptor).first else {
        throw TrackDataError.trackNotFound
    }
    track.isFavorite.toggle()
    try modelContext.save()
    Log.logger(.data).info("Toggled favorite for track")
}
```

**Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 5: Commit**

```bash
git add "Fonic HiFi/Data/Actors/TrackDataActor.swift" "Fonic HiFiTests/TrackDataActorTests.swift"
git commit -m "feat(data): add toggleFavorite to TrackDataActor"
```

---

### Task 1.2: Add heart button to NowPlayingContent

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift`

**Step 1: Locate existing isFavorite state**

Find: `@State private var isFavorite: Bool` (around line 25)

**Step 2: Add heart button in header bar**

Find the header HStack and add button after existing controls:

```swift
// In header bar HStack, add:
Button {
    toggleFavorite()
} label: {
    Image(systemName: isFavorite ? "heart.fill" : "heart")
        .font(.title2)
}
.tint(isFavorite ? .red : nil)
.accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
```

**Step 3: Add toggleFavorite function**

```swift
// Add function in NowPlayingContent:
private func toggleFavorite() {
    guard let track = audioService?.currentTrack else { return }

    // Haptic feedback
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()

    Task {
        do {
            try await trackDataActor.toggleFavorite(trackId: track.id)
            isFavorite.toggle()
            Log.logger(.nowPlaying).info("Favorite toggled")
        } catch {
            Log.logger(.nowPlaying).error("Failed to toggle favorite: \(error)")
        }
    }
}
```

**Step 4: Add trackDataActor dependency**

```swift
// Add at top of struct:
@Environment(\.modelContext) private var modelContext
private var trackDataActor: TrackDataActor { TrackDataActor(modelContainer: modelContext.container) }
```

**Step 5: Sync isFavorite on track change**

```swift
// Add or modify .onChange:
.onChange(of: audioService?.currentTrack) { _, newTrack in
    isFavorite = newTrack?.isFavorite ?? false
}
```

**Step 6: Build and verify**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 7: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift"
git commit -m "feat(ui): add favorites heart button to NowPlaying"
```

---

## Feature 2: Queue Display UI

**Total Time:** ~2-3 days

### Task 2.1: Create QueueView file structure

**Files:**
- Create: `Fonic HiFi/Presentation/Views/Queue/QueueView.swift`

**Step 1: Create the QueueView file**

```swift
import SwiftUI

struct QueueView: View {
    @Environment(AudioEngineFacade.self) private var audioService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                nowPlayingSection
                upNextSection
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .scrollEdgeEffectStyle(.hard, for: .top)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var nowPlayingSection: some View {
        if let current = audioService?.currentTrack {
            Section("Now Playing") {
                QueueRowView(track: current, isPlaying: true)
            }
        }
    }

    @ViewBuilder
    private var upNextSection: some View {
        let remaining = audioService?.queueManager.queueState.remainingTracks ?? []
        if !remaining.isEmpty {
            Section("Up Next • \(remaining.count) tracks") {
                ForEach(Array(remaining.enumerated()), id: \.element.id) { index, track in
                    QueueRowView(track: track, isPlaying: false)
                }
                .onMove(perform: moveTrack)
                .onDelete(perform: deleteTrack)
            }
        }
    }

    private func moveTrack(from source: IndexSet, to destination: Int) {
        guard let fromIndex = source.first else { return }
        // Offset by 1 since we skip current track
        let actualFrom = fromIndex + 1
        let actualTo = destination + 1
        audioService?.queueManager.move(from: actualFrom, to: actualTo)
        Log.logger(.queue).info("Moved track in queue")
    }

    private func deleteTrack(at offsets: IndexSet) {
        for index in offsets {
            let actualIndex = index + 1 // Offset by 1
            audioService?.queueManager.remove(at: actualIndex)
        }
        Log.logger(.queue).info("Removed track from queue")
    }
}

#Preview {
    QueueView()
}
```

**Step 2: Build to verify compilation**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Queue/QueueView.swift"
git commit -m "feat(ui): add QueueView with list structure"
```

---

### Task 2.2: Create QueueRowView component

**Files:**
- Create: `Fonic HiFi/Presentation/Views/Queue/QueueRowView.swift`

**Step 1: Create the row view**

```swift
import SwiftUI

struct QueueRowView: View {
    let track: Track
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            if let artworkData = track.artworkData,
               let uiImage = UIImage(data: artworkData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
            }

            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body)
                    .fontWeight(isPlaying ? .semibold : .regular)
                    .lineLimit(1)

                Text(track.artist ?? "Unknown Artist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Playing indicator
            if isPlaying {
                Image(systemName: "waveform")
                    .symbolEffect(.variableColor.iterative)
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    List {
        QueueRowView(track: .preview, isPlaying: true)
        QueueRowView(track: .preview, isPlaying: false)
    }
}
```

**Step 2: Build to verify**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Queue/QueueRowView.swift"
git commit -m "feat(ui): add QueueRowView component"
```

---

### Task 2.3: Wire queue button in NowPlayingContent

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift`

**Step 1: Find showingQueue state**

Locate: `@State private var showingQueue` (should exist around line 23)

**Step 2: Find queue button and wire sheet**

Find queue button in toolbar or header and add sheet modifier:

```swift
// Add sheet modifier to the view:
.sheet(isPresented: $showingQueue) {
    QueueView()
}
```

**Step 3: Ensure button sets showingQueue**

```swift
// Queue button should be:
Button {
    showingQueue = true
} label: {
    Image(systemName: "list.bullet")
}
```

**Step 4: Build and verify**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift"
git commit -m "feat(ui): wire queue sheet to NowPlaying"
```

---

### Task 2.4: Verify QueueCoordinator.removeFromQueue

**Files:**
- Read: `Fonic HiFi/Core/Audio/Queue/QueueCoordinator.swift`

**Step 1: Check if removeFromQueue is a stub**

Search for `removeFromQueue` method and verify implementation.

**Step 2: If stub, implement it**

```swift
// If stub found, implement:
func removeFromQueue(at index: Int) {
    guard index > 0, index < queueState.tracks.count else { return }
    queueManager.remove(at: index)
    Log.logger(.queue).info("Removed track at index \(index)")
}
```

**Step 3: Build and test**

Run: `make build && make test`
Expected: Both pass

**Step 4: Commit if changes made**

```bash
git add "Fonic HiFi/Core/Audio/Queue/QueueCoordinator.swift"
git commit -m "fix(queue): implement removeFromQueue in QueueCoordinator"
```

---

## Feature 3: Lyrics Display

**Total Time:** ~2-3 days

### Task 3.1: Create LyricsView component

**Files:**
- Create: `Fonic HiFi/Presentation/Views/NowPlaying/LyricsView.swift`

**Step 1: Create basic lyrics view**

```swift
import SwiftUI

struct LyricsView: View {
    let lyrics: String?
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            // Dimming layer for Clear variant
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack {
                // Header
                HStack {
                    Text("Lyrics")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                .padding()

                // Lyrics content
                ScrollView {
                    if let lyrics = lyrics, !lyrics.isEmpty {
                        Text(lyrics)
                            .font(.title3)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .padding()
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "text.quote")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No lyrics available")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .glassEffect(.clear)
        }
    }
}

#Preview {
    LyricsView(lyrics: "Sample lyrics here\nLine two\nLine three", isPresented: .constant(true))
}
```

**Step 2: Build to verify**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/NowPlaying/LyricsView.swift"
git commit -m "feat(ui): add LyricsView component"
```

---

### Task 3.2: Wire lyrics toggle in NowPlayingContent

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift`

**Step 1: Add showingLyrics state**

```swift
// Add state:
@State private var showingLyrics = false
```

**Step 2: Add lyrics button**

```swift
// Add button in header:
Button {
    showingLyrics.toggle()
    Log.logger(.nowPlaying).info("Lyrics toggled: \(showingLyrics)")
} label: {
    Image(systemName: "text.quote")
}
.opacity(audioService?.currentTrack?.lyrics != nil ? 1.0 : 0.5)
.disabled(audioService?.currentTrack?.lyrics == nil)
```

**Step 3: Add overlay for lyrics**

```swift
// Add overlay to artwork or main content:
.overlay {
    if showingLyrics {
        LyricsView(
            lyrics: audioService?.currentTrack?.lyrics,
            isPresented: $showingLyrics
        )
        .transition(.opacity)
    }
}
.animation(.easeInOut, value: showingLyrics)
```

**Step 4: Build and verify**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift"
git commit -m "feat(ui): wire lyrics toggle in NowPlaying"
```

---

## Feature 4: A-B Loop

**Total Time:** ~3-4 days

### Task 4.1: Create ABLoopState model

**Files:**
- Create: `Fonic HiFi/Core/Audio/Playback/ABLoopState.swift`

**Step 1: Create state model**

```swift
import Foundation

struct ABLoopState: Sendable, Equatable {
    var isEnabled: Bool = false
    var pointA: TimeInterval? = nil
    var pointB: TimeInterval? = nil

    var isComplete: Bool {
        pointA != nil && pointB != nil
    }

    var isValid: Bool {
        guard let a = pointA, let b = pointB else { return false }
        return b > a
    }

    mutating func clear() {
        isEnabled = false
        pointA = nil
        pointB = nil
    }
}
```

**Step 2: Build to verify**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "Fonic HiFi/Core/Audio/Playback/ABLoopState.swift"
git commit -m "feat(audio): add ABLoopState model"
```

---

### Task 4.2: Add loop state to AudioEngineFacade

**Files:**
- Modify: `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift`

**Step 1: Add published property**

```swift
// Add property:
@Published var abLoopState = ABLoopState()
```

**Step 2: Add control methods**

```swift
// Add methods:
func setLoopPointA() {
    abLoopState.pointA = currentTime
    Log.logger(.playback).info("Set loop point A at \(currentTime)")
}

func setLoopPointB() {
    abLoopState.pointB = currentTime
    abLoopState.isEnabled = abLoopState.isValid
    Log.logger(.playback).info("Set loop point B at \(currentTime)")
}

func clearLoop() {
    abLoopState.clear()
    Log.logger(.playback).info("Cleared A-B loop")
}
```

**Step 3: Add loop enforcement in playback timer**

Find the playback update timer/callback and add:

```swift
// In playback update callback:
if abLoopState.isEnabled,
   let pointB = abLoopState.pointB,
   let pointA = abLoopState.pointA,
   currentTime >= pointB {
    seek(to: pointA)
}
```

**Step 4: Clear loop on track change**

```swift
// In track change handler:
abLoopState.clear()
```

**Step 5: Build to verify**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add "Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift"
git commit -m "feat(audio): add A-B loop state to AudioEngineFacade"
```

---

### Task 4.3: Add loop controls to NowPlayingContent

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift`

**Step 1: Add loop button**

```swift
// Add button near progress slider:
Button {
    handleLoopTap()
} label: {
    Image(systemName: loopButtonIcon)
}
.tint(audioService?.abLoopState.isEnabled == true ? .orange : nil)
```

**Step 2: Add helper computed properties**

```swift
private var loopButtonIcon: String {
    guard let state = audioService?.abLoopState else { return "a.square" }
    if state.isEnabled { return "repeat.circle.fill" }
    if state.pointA != nil { return "b.square" }
    return "a.square"
}

private func handleLoopTap() {
    guard let service = audioService else { return }

    if service.abLoopState.isEnabled {
        service.clearLoop()
    } else if service.abLoopState.pointA != nil {
        service.setLoopPointB()
    } else {
        service.setLoopPointA()
    }
}
```

**Step 3: Build to verify**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/NowPlaying/NowPlayingContent.swift"
git commit -m "feat(ui): add A-B loop controls to NowPlaying"
```

---

### Task 4.4: Add loop markers to progress slider (optional enhancement)

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/NowPlaying/ProgressSlider.swift` (or equivalent)

**Step 1: Add marker overlays**

```swift
// Add overlay for A-B markers on slider:
.overlay {
    GeometryReader { geo in
        if let pointA = abLoopState.pointA,
           let pointB = abLoopState.pointB,
           duration > 0 {
            let aPosition = (pointA / duration) * geo.size.width
            let bPosition = (pointB / duration) * geo.size.width

            // Highlighted region
            Rectangle()
                .fill(.orange.opacity(0.3))
                .frame(width: bPosition - aPosition)
                .offset(x: aPosition)

            // A marker
            Rectangle()
                .fill(.orange)
                .frame(width: 2)
                .offset(x: aPosition)

            // B marker
            Rectangle()
                .fill(.orange)
                .frame(width: 2)
                .offset(x: bPosition)
        }
    }
}
```

**Step 2: Build to verify**

Run: `make build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/NowPlaying/ProgressSlider.swift"
git commit -m "feat(ui): add A-B loop markers to progress slider"
```

---

## Final Steps

### Run full test suite

Run: `make test`
Expected: All tests pass

### Run linter

Run: `make lint`
Expected: No violations

### Update STATUS.md

Add completed features to the status file.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| QueueCoordinator.removeFromQueue may be stub | Verify in Task 2.4, implement if needed |
| A-B loop timing precision | Use AVAudioTime if glitches occur |
| Lyrics sync (future) | Start with plain text, add sync later |
| TrackDataActor threading | Use Task { await } pattern consistently |

---

## iOS 26 Patterns Used

- `.glassEffect()` - Regular variant for most UI
- `.glassEffect(.clear)` - Clear variant for lyrics overlay (with dimming)
- `.scrollEdgeEffectStyle(.hard, for: .top)` - Queue list legibility
- `.tint()` - Primary actions (heart, loop)
- `@MainActor` - All UI code
- `Task { await }` - Actor crossing pattern
