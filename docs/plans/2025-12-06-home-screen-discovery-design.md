# Home Screen Discovery System Design

**Date:** 2025-12-06
**Status:** Approved

## Overview

Transform the Home screen from an empty placeholder into an intelligent discovery experience that helps users explore and rediscover their music library. Uses Apple's Foundation Models framework for on-device AI recommendations.

## Goals

1. **Immediate value**: Show useful content as soon as tracks are imported
2. **Discovery-focused**: Help users rediscover their library, not just browse it
3. **Intelligent recommendations**: Learn from listening patterns using on-device AI
4. **Smart search**: Find tracks even with imperfect/descriptive queries
5. **Distinctive interactions**: Liquid Glass morphing for Home-exclusive album experience

## Non-Goals

- Copying Apple Music UI directly (inspired by, not cloned)
- Cloud-based recommendations (privacy-first, on-device only)
- Backwards compatibility (iOS 26 only)

---

## Library States

### 1. Empty Library
- Existing implementation: "Welcome to Fonic HiFi" + "Import music to see your library here"
- No changes needed

### 2. Fresh Library (imported, no listening history)
- Recently Added as hero section
- Browse sections: Artists, Genres, Albums
- Quick shuffle actions
- No AI features yet

### 3. Active Library (has listening history)
- Full discovery experience
- AI-powered sections: "For You Now", "Your Mixes"
- Time-based recommendations
- Continue Listening, Rediscover sections

---

## Fresh Library Layout

```
┌─────────────────────────────────────┐
│  Home                               │
├─────────────────────────────────────┤
│  ▶️ Shuffle All    🎲 Surprise Me   │  ← Quick action buttons (.buttonSizing(.flexible))
├─────────────────────────────────────┤
│  Recently Added                     │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐       │  ← Large artwork carousel (hero)
│  │ 🎵 │ │ 🎵 │ │ 🎵 │ │ 🎵 │ →     │
│  └────┘ └────┘ └────┘ └────┘       │
├─────────────────────────────────────┤
│  Your Artists                       │
│  (○) (○) (○) (○) (○) →             │  ← Circular avatars
├─────────────────────────────────────┤
│  Browse by Genre                    │
│  [Rock] [Jazz] [Electronic] →       │  ← Glass pills
├─────────────────────────────────────┤
│  Albums                             │
│  ┌────┐ ┌────┐ ┌────┐ →            │
│  └────┘ └────┘ └────┘              │
└─────────────────────────────────────┘
```

---

## Active Library Layout

```
┌─────────────────────────────────────┐
│  Home                               │
├─────────────────────────────────────┤
│  Continue Listening                 │
│  ┌──────────────────────────┐       │  ← Last played track/album
│  │ 🎵 Track Name • 2:34 left│       │
│  └──────────────────────────┘       │
├─────────────────────────────────────┤
│  Good Evening                       │  ← Time-based greeting
│  ┌────┐ ┌────┐ ┌────┐              │     (AI-curated)
│  │ 🎵 │ │ 🎵 │ │ 🎵 │ →            │
│  └────┘ └────┘ └────┘              │
├─────────────────────────────────────┤
│  Quick Play                         │
│  [▶️ Shuffle] [🎲 Surprise] [🔀 Mix]│
├─────────────────────────────────────┤
│  Your Mixes                         │
│  ┌────────┐ ┌────────┐ ┌────────┐  │  ← AI-generated mixes
│  │ Chill  │ │ Energy │ │ Focus  │→ │
│  └────────┘ └────────┘ └────────┘  │
├─────────────────────────────────────┤
│  Recently Added                     │
├─────────────────────────────────────┤
│  Rediscover                         │
│  "You haven't played these..."      │  ← Neglected gems
└─────────────────────────────────────┘
```

**Time-based greetings:**
- 5am-12pm: "Good Morning"
- 12pm-5pm: "Good Afternoon"
- 5pm-9pm: "Good Evening"
- 9pm-5am: "Late Night"

---

## Home Album Interaction (Liquid Glass Morph)

**Home-exclusive behavior** — Library uses standard navigation.

### Flow

1. User taps Album card in Home
2. Album card morphs (via native Liquid Glass) to screen center
3. Glass effect expands with album accent color tint (`.glassEffect(.regular.tint(albumAccentColor))`)
4. Track list appears inside the morphed glass container
5. User taps a track
6. Glass morphs back to album card position
7. Track starts playing in mini player (NowPlaying stays hidden)

### Technical Approach (iOS 26 Liquid Glass APIs)

**Use native glass morphing (NOT matchedGeometryEffect):**

```swift
// Both states must be in the SAME GlassEffectContainer
GlassEffectContainer(spacing: 10.0) {
    if isExpanded {
        ExpandedAlbumView(album: album)
            .glassEffect(.regular.tint(albumAccentColor))
            .glassEffectID(album.id, in: namespace)
            .glassEffectTransition(.matchedGeometry)
    } else {
        AlbumCard(album: album)
            .glassEffect()
            .glassEffectID(album.id, in: namespace)
    }
}
```

**Key components:**
- `GlassEffectContainer` wraps all morphing elements
- `.glassEffectID(album.id, in: namespace)` for morph identity (NOT matchedGeometryEffect)
- `.glassEffectTransition(.matchedGeometry)` for the animation
- `DominantColorService.shared` extracts album accent color (already cached)
- Track tap triggers: dismiss → play (not navigate to NowPlaying)

### Behavior Comparison

| Screen | Album Tap Behavior |
|--------|-------------------|
| **Home** | Glass morph → inline track list → tap plays in mini player |
| **Library** | Standard navigation push → full album detail view |

---

## Foundation Models Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────────┐
│                    SwiftData Layer                       │
│  Track.playCount, Track.lastPlayed, Track.skipCount     │
│  ListeningSession (new model for time-based patterns)   │
└─────────────────────┬───────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────┐
│              ListeningPatternAnalyzer                    │
│  - Aggregates listening history                         │
│  - Builds context: time, day, sequences                 │
│  - Prepares prompts for Foundation Models               │
└─────────────────────┬───────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────┐
│              LanguageModelSession                        │
│  Instructions: "You are a music recommendation engine.  │
│   Given listening patterns and metadata, suggest tracks │
│   that match the user's current context."               │
└─────────────────────┬───────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────┐
│              @Generable Output Types                     │
│  - ForYouRecommendation (track IDs + reasoning)         │
│  - MixDefinition (name, track IDs, mood description)    │
│  - SearchSuggestion (fuzzy matches, confidence scores)  │
└─────────────────────────────────────────────────────────┘
```

### New SwiftData Model

```swift
@Model
final class ListeningSession {
    var track: Track
    var startedAt: Date
    var endedAt: Date?
    var completionPercentage: Double  // 0.0-1.0
    var wasSkipped: Bool
    var hourOfDay: Int               // 0-23 for time patterns
    var dayOfWeek: Int               // 1-7 for weekly patterns
}
```

### AI Input Context

The model receives:
- **Listening patterns**: Time of day, day of week, play/skip ratios
- **Audio metadata**: Genre, BPM, key, energy level (when available)
- **Contextual signals**: Current time, recent listening momentum

### Availability Fallback

If Foundation Models unavailable:
- **"Your Mixes"**: Show rule-based mixes (genre-based, decade-based)
- **Time-based sections**: Filter by `hourOfDay` patterns from history
- **"Surprise Me"**: Falls back to random genre mix
- No degradation message shown to user (seamless fallback)

### Quick Action Behaviors

| Button | Behavior |
|--------|----------|
| **Shuffle All** | Shuffle entire library, start playing |
| **Surprise Me** | Generate AI mix using Foundation Models (fallback: random genre mix) |

---

## Smart Search

### Capabilities

| Query Type | Example | How It Works |
|------------|---------|--------------|
| **Exact match** | "Bohemian Rhapsody" | Standard text search |
| **Partial/fuzzy** | "that bohemian song" | Foundation Models interprets intent |
| **Descriptive** | "the fast guitar song from yesterday" | AI matches against metadata + history |
| **Lyric fragment** | "is this the real life" | Matches against lyrics field (if available) |

### @Generable Search Output

```swift
@Generable
struct SearchResult {
    @Guide(description: "Track IDs matching the query, ranked by relevance")
    let trackIDs: [String]
    
    @Guide(description: "Why each track matched", .maximumCount(5))
    let matchReasons: [String]
    
    @Guide(description: "Suggested refined queries if results are poor")
    let suggestions: [String]
}
```

### Search Flow

1. Try standard text search first (fast, no AI overhead)
2. If no/few results → Foundation Models interprets query with listening history context
3. Return ranked results with match reasons

---

## Implementation Phases

### Phase 1: Fresh Library Home (No AI)

- [ ] Add "Recently Added" section using `getRecentlyAddedTracks()`
- [ ] Add "Your Artists" section (circular avatars)
- [ ] Add "Browse by Genre" section (glass pills)
- [ ] Add "Albums" carousel
- [ ] Add "Shuffle All" and "Surprise Me" buttons
- [ ] Remove redundant "Search Tracks" from Library
- [ ] Wire up tap behaviors (tracks play, artists/genres navigate)

**Ship when:** Home shows useful content for a fresh library

### Phase 2: Album Glass Morph

- [ ] Implement `GlassEffectContainer` for album expansion
- [ ] Add `glassEffectID` + `glassEffectTransition(.matchedGeometry)` for morphing
- [ ] Reuse `DominantColorService.shared` for accent tinting (already cached)
- [ ] Build inline track list within morphed view
- [ ] Wire "tap track → dismiss → play in mini player" flow

**Ship when:** Album morph interaction is polished

### Phase 3: Listening History Tracking

- [ ] Create `ListeningSession` SwiftData model
- [ ] Record sessions on play/pause/skip/complete
- [ ] Store `hourOfDay`, `dayOfWeek`, `completionPercentage`
- [ ] Add "Continue Listening" section (no AI needed)
- [ ] Add "Rediscover" section (tracks with 0 recent plays)

**Ship when:** History is being tracked reliably

### Phase 4: Foundation Models Integration

- [ ] Implement `ListeningPatternAnalyzer`
- [ ] Create `@Generable` types for recommendations
- [ ] Build time-based "Good Morning/Evening" section
- [ ] Implement "Your Mixes" with AI-generated groupings
- [ ] Add availability check + rule-based fallback

**Ship when:** AI recommendations working on-device

### Phase 5: Smart Search

- [ ] Enhance Search tab with Foundation Models
- [ ] Implement fuzzy/descriptive query handling
- [ ] Add match reasons to results
- [ ] Build `GetListeningHistoryTool` for context

**Ship when:** Users can find tracks by description

---

## Visual Styles by Section

| Section | Visual Style |
|---------|-------------|
| Continue Listening | Compact list (1-3 items) |
| For You Now / Time-based | Large artwork cards |
| Recently Added | Horizontal carousel |
| Quick Shuffle | Compact glass buttons |
| Your Mixes | Medium cards with gradient |
| Your Artists | Circular artist avatars |
| Browse by Genre | Compact glass pills |
| Rediscover | Standard track list |

---

## Cleanup Items

- [ ] Remove "Search Tracks" bar from Library screen (redundant with Search tab)

---

## Technical Notes

- All UI on `@MainActor`
- SwiftData operations through `TrackDataActor`
- Foundation Models availability checked before use
- Graceful fallback to rule-based recommendations
- No `@available` checks needed (iOS 26 only)
- **Color extraction**: `DominantColorService.shared` already handles caching (50-entry limit)
- **Button sizing**: Use `.buttonSizing(.flexible)` for quick action buttons
- **Glass morphing**: Use `glassEffectID` + `glassEffectTransition`, NOT `matchedGeometryEffect`
