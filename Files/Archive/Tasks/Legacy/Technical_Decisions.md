# Technical Decision Log

## Architecture Decisions

### 1. MVVM over MVC
**Decision**: Use MVVM pattern with Combine/SwiftUI
**Rationale**: 
- Better separation of concerns
- SwiftUI native data binding
- Easier testing of business logic
- Clear data flow

### 2. SwiftData over Core Data
**Decision**: SwiftData as primary, Core Data fallback
**Rationale**:
- Modern Swift-first API
- Better SwiftUI integration
- Type safety improvements
- Easier migrations
**Risk**: New framework, may have bugs

### 3. Multiple Audio Engines
**Decision**: AVAudioEngine + SFBAudioEngine + FFmpeg
**Rationale**:
- AVAudioEngine: iOS native, hardware acceleration
- SFBAudioEngine: High-res format support (FLAC, DSD)
- FFmpeg: Universal fallback
**Trade-off**: Complexity vs. format support

### 4. File-based Library
**Decision**: Reference files, don't copy
**Rationale**:
- Saves storage space
- User maintains file organization
- Faster import process
**Risk**: Files may move/delete

---

## Technology Stack

### Core Technologies
| Component | Technology | Rationale |
|-----------|------------|-----------|
| UI | SwiftUI 5 | Modern, declarative, less code |
| Language | Swift 6 | Strict concurrency, performance |
| Database | SwiftData | Swift-native, type-safe |
| Audio | AVFoundation + | iOS integration + high-res |
| Metadata | TagLib | Industry standard, reliable |
| Testing | XCTest | Native, good integration |

### Third-Party Dependencies
| Library | Purpose | Alternative Considered |
|---------|---------|------------------------|
| SFBAudioEngine | High-res audio | Building custom |
| TagLib | Metadata | AVFoundation limited |
| FFmpegKit | Format support | Limited formats |

---

## Data Model Decisions

### 1. Separate Entities
**Decision**: Track, Album, Artist as separate entities
**Rationale**:
- Normalized database
- Efficient queries
- Flexible relationships
- Better for large libraries

### 2. Lazy Loading Strategy
**Decision**: Lazy load artwork and waveforms
**Rationale**:
- Reduced memory usage
- Faster initial load
- On-demand generation
**Implementation**: Computed properties with caching

### 3. Metadata Storage
**Decision**: Store all metadata in DB, not just file reference
**Rationale**:
- Faster browsing
- Offline access
- Search capability
- Reduces file I/O

---

## Performance Decisions

### 1. Batch Size: 500 items
**Decision**: Process imports/operations in 500-item batches
**Rationale**:
- Balance between memory and speed
- Tested with various library sizes
- Allows progress updates

### 2. Image Cache Limits
**Decision**: 100 images, 100MB max
**Rationale**:
- ~1MB average per artwork
- Covers typical browsing session
- Prevents memory pressure

### 3. Background Processing
**Decision**: Use BackgroundTasks for long operations
**Rationale**:
- Better battery life
- iOS manages scheduling
- Can continue when app backgrounds

---

## UI/UX Decisions

### 1. Dark Mode First
**Decision**: Optimize for dark mode, light mode secondary
**Rationale**:
- Target audience preference
- Better for extended listening
- OLED battery savings
- Modern aesthetic

### 2. Gesture Navigation
**Decision**: Swipe gestures for playback control
**Rationale**:
- One-handed operation
- Matches iOS conventions
- Faster than buttons
- More intuitive

### 3. Waveform Visualization
**Decision**: Show waveform in Now Playing
**Rationale**:
- Visual feedback
- Seek precision
- Audiophile expectation
- Differentiator

---

## Security & Privacy

### 1. No Analytics
**Decision**: Zero analytics or crash reporting by default
**Rationale**:
- Privacy-first promise
- User trust
- Simplifies compliance
- No third-party SDKs

### 2. Local Storage Only
**Decision**: All data stored locally
**Rationale**:
- No server costs
- Complete user control
- Offline functionality
- Privacy guarantee

### 3. Optional iCloud
**Decision**: iCloud sync optional, not default
**Rationale**:
- User choice
- Some prefer local-only
- Reduces complexity for MVP
- Can enable post-launch

---

## Trade-offs & Compromises

### 1. Format Support vs Complexity
**Chose**: Multiple engines for format support
**Trade-off**: More complexity, better compatibility
**Alternative**: Single engine, limited formats

### 2. Features vs Performance  
**Chose**: Fewer features, better performance
**Trade-off**: No visualizer, faster UI
**Alternative**: More features, accept slower performance

### 3. Storage vs Speed
**Chose**: Cache metadata, reference files
**Trade-off**: More storage for DB, faster browsing
**Alternative**: Read from files each time

---

## Future Considerations

### Phase 2 Decisions Needed
1. **Cloud Sync Method**: iCloud vs custom solution
2. **Social Features**: Privacy implications
3. **AI Features**: On-device vs cloud processing
4. **Desktop Sync**: Protocol selection

### Technical Debt to Address
1. Migrate from any UIKit wrapped views
2. Optimize SwiftData queries
3. Improve audio engine switching
4. Better error recovery

### Upgrade Paths
1. **iOS 19**: Adopt new SwiftUI features
2. **Swift 7**: Migrate when stable
3. **New Formats**: Modular decoder system
4. **Performance**: Metal for visualizations

---

## Lessons Learned

### What Worked Well
- SwiftUI for rapid UI development
- MVVM for clear separation
- Early performance testing
- Batch processing approach

### What Didn't Work
- (To be filled during development)

### Would Do Differently
- (To be filled post-MVP)

---

## Decision Template

### Decision: [Title]
**Date**: [YYYY-MM-DD]
**Status**: Proposed | Accepted | Deprecated
**Context**: What is the issue we're addressing?
**Decision**: What did we decide?
**Rationale**: Why did we make this choice?
**Alternatives**: What else did we consider?
**Consequences**: What are the trade-offs?
**Review Date**: When should we revisit this?