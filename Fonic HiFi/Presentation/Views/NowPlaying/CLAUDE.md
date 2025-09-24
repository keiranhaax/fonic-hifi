# NowPlaying CLAUDE.md

Complex state management and animations for Now Playing views. Verify with apple-rag/sosumi.

## STRICT IMPLEMENTATION RULES

- **NEVER** create mock data, fake APIs, or placeholder values
- **NEVER** use TODO, FIXME, or stub comments in code
- **NEVER** comment out code - remove or implement properly
- **ALWAYS** verify implementation matches user requirements exactly
- **ALWAYS** implement complete, working solutions
- **ALWAYS** double-check before editing/commenting - implement correctly
- Comments are OK if concise and helpful for understanding

## STATE SYNCHRONIZATION [Verified-Code]

**Single Source of Truth:**
```swift
AudioEngineFacade (MainActor)
    ├── @Published currentTrack
    ├── @Published isPlaying
    ├── @Published currentTime
    └── @Published duration
```

**ACTUAL CODE** (`NowPlayingView.swift:15`):
```swift
struct NowPlayingView: View {
    @Environment(\.audioEngine) private var audioService: AudioEngineFacade?
    // Uses environment injection, not @EnvironmentObject
}
```

**ACTUAL STATE USAGE** (`NowPlayingView.swift:72-73`):
```swift
private func nowPlayingContent(audioService: AudioEngineFacade) -> some View {
    PerformanceOptimizedContainer(spacing: 0) {
        // Content here
    }
}
```

## MINI PLAYER ↔ FULL PLAYER

**Sheet Presentation (iOS 26):**
```swift
.sheet(isPresented: $showFullPlayer) {
    NowPlayingView()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .glassEffect()  // iOS 26 Liquid Glass
}
```

**Transition Coordination:**
```swift
// Shared namespace for morphing
@Namespace private var nowPlayingNamespace

MiniPlayerView()
    .matchedGeometryEffect(id: "albumArt", in: nowPlayingNamespace)

// In full player
AlbumArtView()
    .matchedGeometryEffect(id: "albumArt", in: nowPlayingNamespace)
```

## GESTURE HANDLING [Verified-Code]

**ACTUAL Dismissal Pattern** (`NowPlayingView.swift:479-493`):
```swift
.gesture(
    DragGesture()
        .onChanged { _ in
            // Gesture callbacks may run on background thread
            Task { @MainActor in
                isDragging = true
            }
        }
        .onEnded { value in
            Task { @MainActor in
                isDragging = false
                let shouldDismiss = value.translation.height > dismissThreshold ||
                    (value.translation.height > minimumDismissDistance &&
                     value.predictedEndTranslation.height > dismissThreshold)
                // Handle dismissal
            }
        }
)
```

**Interactive Scrubbing:**
```swift
Slider(value: $scrubTime, in: 0...duration) { editing in
    if !editing {
        // User finished scrubbing
        Task {
            await audioFacade.seek(to: scrubTime)
        }
    }
}
```

## PERFORMANCE OPTIMIZATIONS [Verified-Apple]

**Efficient Re-renders:**
```swift
// GOOD: Equatable view to prevent re-renders
struct AlbumArtView: View, Equatable {
    let imageURL: URL?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.imageURL == rhs.imageURL
    }
}

// BAD: Re-renders on every state change
struct AlbumArtView: View {
    @EnvironmentObject var audioFacade: AudioEngineFacade
    // Uses entire object, re-renders frequently
}
```

**Async Work [Verified-Apple]:**
```swift
.task {  // Cancellable, async
    await loadLyrics()
}
.task(id: track.id) {  // Re-runs when track changes
    await loadAlbumArt()
}
```

**Animation Performance:**
```swift
// Explicit animation values
.animation(.smooth, value: isPlaying)
.animation(.smooth, value: currentTime)

// NOT implicit .animation(.smooth)
```

## LIQUID GLASS INTEGRATION [NOT YET IMPLEMENTED]

**Native iOS 26 (NOT IN CODE):**
```swift
// How it SHOULD work with native APIs
.glassEffect(Glass.regular.interactive(true))
```

**ACTUAL IMPLEMENTATION** (`NowPlayingView.swift:279-281`):
```swift
// Using custom implementations
.liquidGlass(style: .thick)
.glassEffectID("trackInfo", in: animationNamespace)
// NOT using native .glassEffect()
```

**ACTUAL CONTROLS** (`NowPlayingView.swift:384-385`):
```swift
.glassEffectID("playPause", in: animationNamespace)
.glassTransition(isActive: audioService?.isPlaying ?? false)
// Custom extensions, not native iOS 26 APIs
```

**Progress Bar with Glass:**
```swift
GeometryReader { geometry in
    ZStack(alignment: .leading) {
        Capsule()
            .fill(.quaternary)

        Capsule()
            .fill(.tint)
            .frame(width: progressWidth(in: geometry))
    }
}
.frame(height: 6)
.glassEffect(in: Capsule())
```

## STATE UPDATES FROM AUDIO

**Progress Timer Updates:**
```swift
// In AudioEngineFacade
private func startProgressTimer() {
    progressTimer = Timer.publish(every: 0.1, on: .main, in: .common)
        .autoconnect()
        .sink { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.updatePlaybackProgress()
            }
        }
}
```

**Track Change Handling:**
```swift
.onChange(of: audioFacade.currentTrack) { _, newTrack in
    guard let track = newTrack else { return }
    // Update UI elements
    Task {
        await loadTrackDetails(track)
    }
}
```

## COMMON PATTERNS

**ACTUAL Play/Pause Toggle** (`NowPlayingView.swift:533-540`):
```swift
private func togglePlayPause() {
    Task { @MainActor in
        guard let audioService = audioService else { return }
        do {
            if audioService.isPlaying {
                await audioService.pause()
            } else {
                try await audioService.play()
            }
        } catch { }
    }
}
```

**ACTUAL Queue Navigation** (`NowPlayingView.swift:550-557`):
```swift
private func playNext() {
    Task { @MainActor in
        guard let audioService = audioService else { return }
        do {
            try await audioService.playNext()
        } catch { }
    }
}
```

## DEBUG

```bash
make view FILE=Presentation/Views/NowPlaying/NowPlayingView.swift
make profile-cpu  # Animation performance
make logs-stream  # Real-time state updates
```

## KEY FILES

- `NowPlayingView.swift:14`: Full player (@MainActor)
- `MiniPlayerView.swift:104-112`: Compact player with gestures
- `LiquidGlassMiniPlayer.swift`: Glass-styled mini player (custom impl)
- Task patterns throughout: `Task { @MainActor in }` for thread safety