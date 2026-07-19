# Architecture Reference

## Audio Engine Facade Pattern

```
AudioEngineFacade (Main coordinator) - AudioEngineFacade.swift:20
├── AVAudioEngineAdapter (Core/Audio/Engines/AVAudioEngineAdapter.swift)
└── AudioKitEngineAdapter (Core/Audio/Engines/AudioKitEngineAdapter.swift)
```

**Engine Selection** (AudioEngineFactory.swift):
- Detects format via AudioFormatDetectionManager
- Selects optimal engine based on format capabilities
- Falls back gracefully if primary engine fails
- Maintains bit-perfect playback when possible

**Why Multiple Audio Engines?**
- AVAudioEngine: Best iOS integration, limited format support
- AudioKit: Superior DSP and FLAC playback, slightly higher CPU usage
- Trade-off: Complexity for flexibility (see ADR 002)

## State Management Architecture

```
PlaybackStateManager (Single source of truth)
├── PlaybackState (Immutable state snapshot)
├── PlaybackStateStore (Persistence layer)
└── Published to:
    ├── AudioEngineFacade
    └── Individual ViewModels

Coordinators (orchestrate complex operations):
├── StateCoordinator - State transitions between managers
├── QueueCoordinator - Queue/state/playback coordination
└── PlaybackController - Playback operation control

UI State:
└── AudioUIState - UI state derived from engine state
```

**State Flow:**
1. User action → ViewModel method
2. ViewModel → AudioEngineFacade command
3. AudioEngine → PlaybackStateManager update
4. StateCoordinator validates transition
5. State change → Published to all observers
6. UI updates via @Published properties + AudioUIState

## Widget Architecture [Verified-Code]

```
Widget Ecosystem (Fonic HiFi Widget/)
├── Home Screen Widgets (WidgetKit)
│   ├── Views/SmallWidgetView, MediumWidgetView, LargeWidgetView
│   └── StandBy mode detection via showsWidgetContainerBackground
├── Lock Screen Accessories
│   └── accessoryCircular, accessoryRectangular, accessoryInline
└── Core Files
    ├── NowPlayingWidget.swift (Widget configuration)
    ├── NowPlayingTimelineProvider.swift (Timeline updates)
    └── WidgetArtworkLoader.swift (Async artwork)

Note: Lock Screen Now Playing controls are handled automatically by iOS
via MPNowPlayingInfoCenter and MPRemoteCommandCenter (not Live Activities).
```

**Widget Update Strategy:**
- Timeline provider refreshes on play/pause/seek/track change
- Artwork: Async loading via WidgetArtworkLoader
- StandBy mode: Detected via `showsWidgetContainerBackground` environment

## Apple Music UI Patterns [Verified-Code]

The NowPlaying UI follows Apple Music's zoom transition pattern:
- `MorphableArtwork.swift` - Artwork morphing with `.matchedGeometryEffect()`
- `LiquidGlassMiniPlayer.swift` - Mini player with glass effect
- Native iOS 26 `.glassEffect()` without custom drag gestures
- Unified color service for artwork-based theming

## SwiftData Integration [Verified-Apple]

**Model Persistence** (Data/Models/ and Data/Actors/TrackDataActor.swift):
- All database operations through TrackDataActor
- Batch imports for performance
- Relationships: Artist <-> Album <-> Track <-> Playlist
- Migration support via versioned schemas

**Why SwiftData over Core Data?**
- Modern Swift-first API (iOS 26 enhanced)
- Better SwiftUI integration
- Pagination support (see ADR 003)

## Architecture Decision Records

See `docs/plans/` for detailed decisions:

| ADR | Title | Key Decision |
|-----|-------|--------------|
| 001 | Import URL Normalisation | Multi-key hash deduplication (sourceURLHash + sourceBookmarkHash) |
| 002 | Audio Monitor Decomposition | Modular diagnostics: AudioMetricsScheduler, AudioSessionAnalytics |
| 003 | Paginated Fetch Descriptor | BatchProcessor for 5,000+ track libraries |
| 004 | MainActor Service Concurrency | No `@unchecked Sendable` on `@MainActor` classes |

**Why Actor-Based Concurrency?**
- Swift 6 strict concurrency eliminates races
- Clear isolation boundaries (see ADR 004)
- Compile-time safety

## Project Design Philosophy

**Audio Quality:**
- Bit-perfect playback is the primary goal
- Format support breadth over depth
- User control over processing chain
- Transparency in signal path

**Privacy & Security:**
- No cloud services or analytics
- All data stored locally
- No network permissions required
- File access limited to user-selected directories

**Target Audience:**
- Audiophiles requiring bit-perfect playback
- Users with diverse format collections
- Privacy-conscious individuals
- iOS power users
