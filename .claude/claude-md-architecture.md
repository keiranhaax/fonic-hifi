# Architecture Guidelines

## Core Architecture Principles
- **MVVM Pattern**: Views observe ViewModels, ViewModels use Domain layer
- **Dependency Injection**: Use protocol-oriented design with ServiceProvider
- **Modular Design**: Features are self-contained modules
- **Clean Architecture**: Strict separation between layers
- **Offline-First**: Local functionality takes priority

## Layer Responsibilities

### Presentation Layer
- **Views**: Pure SwiftUI views, no business logic
- **ViewModels**: @Published properties, handle user interactions
- **UI State**: Global app state, navigation, theme management
- Always use @MainActor for UI updates
- Implement proper @StateObject and @ObservedObject usage

### Domain Layer
- **Models**: Immutable value types (structs) representing business entities
- **Use Cases**: Single responsibility business logic operations
- **Interfaces**: Protocol definitions for repositories
- No UI or data layer dependencies
- Use async/await for all asynchronous operations

### Data Layer
- **Repositories**: Implement domain interfaces, coordinate data sources
- **Data Sources**: Local (SwiftData, FileSystem) and Remote (future)
- **DTOs**: Data transfer objects for database/network
- **Mappers**: Convert between DTOs and domain models
- Handle all data persistence and retrieval

### Core Services
- **Audio Engine**: Manages playback, format detection, DSP
- **Metadata Service**: Tag parsing/writing via TagLib
- **File System**: Secure file operations, import/export
- **Background Tasks**: Long-running operations management
- All services should be protocol-based for testability

## Key Architectural Patterns

### Audio Engine Selection
```
1. Analyze format → 2. Select engine → 3. Configure output
- Standard formats (MP3, AAC, ALAC, WAV, AIFF): AVAudioEngine
- FLAC or DSP-heavy workloads: AudioKit
- Future specialized formats: Extend via new adapters when requirements emerge
```

### Database Schema Strategy
- Use SwiftData with @Model for entities
- Implement indexes on: artist, album, title, genre
- Lazy load artwork and waveform data
- Cache frequently accessed metadata
- Version migrations for schema changes

### Background Processing
- Use BackgroundTasks framework for:
  - Library scanning and indexing
  - Waveform generation
  - Metadata updates
  - Cloud sync (future)
- Implement cancellable operations
- Priority queue with checkpointing

### Memory Management
- NSCache for artwork (multiple resolutions)
- Tiered caching: Memory → Disk → Regenerate
- Release resources on memory pressure
- Use appropriate image sizes for context
- Implement automatic cleanup

### Error Handling
- Define typed errors for each module
- Propagate errors up to presentation layer
- User-friendly error messages
- Automatic retry for transient errors
- Detailed logging for debugging

## Performance Optimization

### Large Library Support (100k+ tracks)
- Composite database indexes
- Virtualized lists with cell recycling
- Progressive loading of metadata
- Background indexing with progress
- Batch operations (500 items)

### Audio Playback
- Buffer size based on performance mode
- Preload next track in queue
- Cache decoded audio chunks
- Efficient format conversion
- Hardware acceleration when available

### UI Performance
- Lazy loading in all lists
- Image downsampling for thumbnails
- Debounce search and filter operations
- Progressive waveform rendering
- Smooth 60fps scrolling

## Threading Model
- Main thread: UI updates only
- Background queues: File I/O, processing
- Audio thread: Real-time audio processing
- Use Task.detached for CPU-intensive work
- Proper actor isolation

## Dependency Management
- Swift Package Manager preferred
- CocoaPods for legacy dependencies
- Version lock all dependencies
- Regular security updates
- Minimal external dependencies

## Testing Architecture
- Unit tests for business logic
- Integration tests for workflows
- UI tests for critical paths
- Performance tests with profiling
- Mock all external dependencies