## Enhanced CLAUDE.md Structure

### 1. **Swift Mastery Section**

```markdown
## Swift 6+ Mastery Patterns

### Concurrency Checkpoints
- Actor boundaries: AudioEngine → @AudioActor, UI → @MainActor
- Sendable conformance: All models crossing actor boundaries
- Task priority: .userInitiated for playback, .background for library scan

### Advanced Swift Patterns
```swift
// Typed throws with error propagation
enum AudioError: Error {
    case decoderFailure(codec: String)
    case bufferUnderrun(timestamp: TimeInterval)
}

func decode() throws(AudioError) { ... }

// Macro usage for boilerplate reduction
@AudioRoute
struct NowPlayingRoute: Routable { ... }

// Result builders for declarative APIs
@resultBuilder
struct AudioPipelineBuilder { ... }
```

### Performance Patterns
- Copy-on-write for large collections: `struct Library { private var _tracks: [Track] }`
- Lazy sequences for library filtering: `tracks.lazy.filter { }.map { }`
- Actor reentrancy awareness: Use `Task.detached` for long operations
```

### 2. **Large Codebase Context Management**

```markdown
## Codebase Navigation & Loading

### Priority Load Order
1. **Critical Path** (load first):
   - Core/Audio/AudioEngine.swift
   - Domain/Models/Track.swift
   - Presentation/NowPlaying/NowPlayingViewModel.swift

2. **Context Graphs** (load related files together):
   ```
   AudioPlayback: AudioEngine → AudioQueue → PlaybackState
   Library: LibraryScanner → MetadataParser → SwiftData models
   UI Flow: AppCoordinator → TabRouter → Feature Views
   ```

3. **Smart Context Commands**:
   - `/load-feature audio`: Loads entire audio subsystem
   - `/load-flow now-playing`: Loads view → VM → services chain
   - `/minimize`: Unload non-essential files, keep only current feature

### File Fingerprints (for change detection)
```yaml
Core/Audio/AudioEngine.swift: 
  last_modified: 2024-01-15
  checksum: abc123
  dependencies: [AudioKit, AVFoundation]
  exports: [AudioEngine, PlaybackState]
```
```

### 3. **Enhanced Memory System**

```markdown
## Project Memory Architecture

### Decision Log (DECISIONS.md)
```markdown
# Architectural Decisions

## 2024-01-15: Audio Engine Threading
- **Decision**: Dedicated AudioActor for all playback
- **Rationale**: Prevents UI blocking, ensures real-time performance
- **Trade-offs**: Complexity vs. reliability → chose reliability
- **Review date**: 2024-04-15
```

### Pattern Library (PATTERNS.md)
```markdown
# Established Patterns

## ViewModelFactory
Used in: Library, NowPlaying, Settings
```swift
protocol ViewModelFactory {
    associatedtype ViewModel
    static func make(dependencies: DependencyContainer) -> ViewModel
}
```
Rationale: Testability + SwiftUI previews
```

### Session Memory (.claude/session/)
```markdown
# Current Session: Feature/Equalizer

## Progress
- [x] Created EqualizerService protocol
- [x] Implemented 10-band EQ with AudioKit
- [ ] Wire up to settings UI
- [ ] Add preset management

## Blockers
- AudioKit node connection timing issue (see fix-001.md)

## Next Steps
1. Implement preset CoreData model
2. Create SwiftUI frequency slider component
```
```

### 4. **Intelligent Context Switching**

```markdown
## Context Management Commands

### Feature Contexts
/context library      # Switches to library browsing feature
/context playback     # Switches to audio engine work
/context ui-polish    # Loads design system + components

### Memory Checkpoints
/checkpoint "pre-refactor"   # Saves current context state
/rollback "pre-refactor"     # Restores previous state

### Dependency Mapping
/deps AudioEngine     # Shows all files that depend on AudioEngine
/impact Track.swift   # Shows what breaks if Track model changes
```

### 5. **Code Intelligence Enhancers**

```markdown
## Code Understanding Aids

### Symbol Index (.claude/symbols.json)
{
  "AudioEngine": {
    "type": "actor",
    "file": "Core/Audio/AudioEngine.swift",
    "methods": ["play", "pause", "seek"],
    "publishes": ["playbackState", "currentTime"]
  }
}

### Common Workflows
```yaml
add_format:
  steps:
    - Add decoder to Core/Audio/Decoders/
    - Register in AudioFormatRegistry
    - Add UI indicator in FormatBadge component
    - Test with sample file in Tests/Resources/
    
fix_memory_leak:
  tools: [Instruments, "Memory Graph Debugger"]
  common_causes: ["Combine subscriptions", "Timer retention", "Closure captures"]
```

### Performance Baselines
```yaml
metrics:
  app_launch: 1.2s (iPhone 13 Pro)
  cold_library_scan: 1000 tracks/sec
  memory_10k_tracks: 142MB
  audio_switch_latency: 8ms
```
```

### 6. **Swift Evolution Tracking**

```markdown
## Swift Version Matrix

### Available Features by Target
- iOS 18.0+: Swift 6 full (typed throws, strict concurrency), SwiftUI 5.1 (improved scrolling, mesh gradients)
- iOS 17.0+: Swift 5.9 (@Observable, macros), SwiftUI 5 (@Observable macro, SwiftData integration)
- iOS 16.0+: Swift 5.7 (Regex, if-let shorthand), SwiftUI 4 (NavigationStack, Grid layout)

### Migration Flags
SWIFT_STRICT_CONCURRENCY = complete
SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY = YES
SWIFT_UPCOMING_FEATURE_TYPED_THROWS = YES
```

### 7. **Codebase Health Metrics**

```markdown
## Quality Gates

### Automated Checks
- Coverage: > 80% for business logic, > 60% for UI
- Cyclomatic complexity: < 10 per method
- SwiftLint violations: 0 errors, < 10 warnings
- Build time: < 2 min clean, < 20s incremental

### Architecture Conformance
/validate mvvm       # Ensures no View → Model direct calls
/validate threading  # Confirms actor isolation rules
```

## Implementation Strategy

1. **Start with Decision Log** - Document "why" alongside "what"
2. **Build Symbol Index** - Run a script to generate automatically
3. **Create Feature Contexts** - Define 3-5 core workflows
4. **Set up Checkpointing** - Save state before major changes
5. **Add Performance Baselines** - Measure, don't guess

### Swift & SwiftUI Excellence Rules

### Core Principles
1. **Performance First**: Every implementation must target 60fps UI and < 100ms response time.
2. **Type Safety**: Leverage Swift's type system fully - no `Any`, minimal force unwrapping.
3. **Testability**: All business logic must be testable in isolation.
4. **Accessibility**: WCAG 2.2 AA compliance is non-negotiable, adhering to Apple HIG guidelines for VoiceOver, Dynamic Type, and sufficient color contrast.
5. **Consistency**: Adhere strictly to Apple Human Interface Guidelines (HIG) for UI/UX patterns, navigation, and component usage to ensure a native and familiar user experience.

### Swift 6 Implementation Standards

#### Concurrency Rules
- **✅ ALWAYS**: Explicit actor isolation using `@MainActor` for UI updates and dedicated actors for background tasks (e.g., `@AudioActor`).
- **✅ ALWAYS**: Ensure all types crossing actor boundaries conform to `Sendable`.
- **✅ ALWAYS**: Use `Task` with appropriate priorities (`.userInitiated`, `.background`) for asynchronous operations.
- **❌ NEVER**: Use `DispatchQueue.main.async` for UI updates if `@MainActor` can be used. Avoid implicit actor hopping.

#### Error Handling Patterns
- **✅ ALWAYS**: Use typed throws with specific, custom error enums for clear error propagation (e.g., `throws(LibraryError)`).
- **✅ ALWAYS**: Return `Result<Success, Failure>` for asynchronous operations that can fail, especially when error handling is complex or involves multiple potential failure points.
- **❌ NEVER**: Use generic `throws` without specifying the error type (`func badMethod() throws`).

#### Memory Management
- **✅ ALWAYS**: Use `[weak self]` or `[unowned self]` in closures, especially those crossing actor boundaries or in long-lived operations, to prevent strong reference cycles.
- **✅ ALWAYS**: Manage `Task` lifecycles and Combine `AnyCancellable` instances by storing them in appropriate collections (e.g., `Set<AnyCancellable>`) to ensure proper deallocation.
- **❌ NEVER**: Launch unmanaged `Task` instances without considering their lifecycle and potential for leaks.

### SwiftUI Implementation Patterns

#### View Composition Rules
- **✅ ALWAYS**: Break down complex views into smaller, reusable subviews. A view's `body` should ideally be less than 50 lines and no more than 3 levels deep in nesting.
- **✅ ALWAYS**: Create custom `ViewModifier`s for reusable styling and common view behaviors.
- **✅ ALWAYS**: Use `Group` or `AnyView` sparingly, only when absolutely necessary for type erasure or conditional view hierarchies that cannot be expressed otherwise.
- **❌ NEVER**: Embed complex computed properties or business logic directly within a view's `body`. Delegate such logic to a `ViewModel` or dedicated service.

#### State Management Hierarchy
- **✅ ALWAYS**: Establish a clear state ownership hierarchy. Use `@State` for local value types, `@StateObject` for owning observable reference types (iOS 16+), and `@Observable` for owning observable reference types (iOS 17+).
- **✅ ALWAYS**: Use `@Binding` for two-way communication between parent and child views, allowing child views to modify parent-owned state.
- **✅ ALWAYS**: For SwiftUI 5 (iOS 17+) and later, prefer the `@Observable` macro for observable models and `@Bindable` for two-way bindings to these models in views.
- **❌ NEVER**: Have multiple sources of truth for the same piece of data. Avoid duplicating state across different `ViewModel` instances or views.

#### Performance Optimizations
- **✅ ALWAYS**: Implement lazy loading for lists and grids using `LazyVStack`, `LazyHStack`, or `List` with `ForEach` and `id` parameters to ensure efficient rendering of large datasets.
- **✅ ALWAYS**: Make complex views conform to `Equatable` to prevent unnecessary re-renders when their content has not changed.
- **✅ ALWAYS**: Offload heavy computations, data processing, or network requests to background tasks using `Task(priority: .background)` and update the UI on the `MainActor`.
- **❌ NEVER**: Perform synchronous file I/O or other blocking operations on the main thread.

### Architecture-Specific Rules

#### MVVM Boundaries
- **✅ ALWAYS**: Enforce unidirectional data flow: Views send commands to `ViewModel`s, and `ViewModel`s expose published state for Views to observe.
- **✅ ALWAYS**: Keep business logic and data manipulation within `ViewModel`s or dedicated service layers, not directly in Views.
- **❌ NEVER**: Allow Views to directly access or modify models without going through a `ViewModel`.

#### Dependency Injection
- **✅ ALWAYS**: Use protocol-based dependency injection to abstract concrete implementations and improve testability.
- **✅ ALWAYS**: Utilize SwiftUI's `environment` or `environmentObject` for injecting system-wide or shared dependencies.

### Testing Requirements

#### Unit Test Patterns
- **✅ ALWAYS**: Follow the Given-When-Then structure for unit tests to ensure clarity and maintainability.
- **✅ ALWAYS**: Write unit tests for all business logic, aiming for high code coverage (>80%).
- **✅ ALWAYS**: Properly handle asynchronous code in tests using `await` and `XCTestExpectation` or `XCTWaiter` where necessary.

### Code Quality Gates

Before ANY implementation, the following questions must be answered affirmatively:
1. ✅ Will this code run at 60fps on target devices?
2. ✅ Can this be unit tested in isolation?
3. ✅ Is the memory ownership clear, and are potential strong reference cycles prevented?
4. ✅ Does it handle all foreseeable error cases gracefully, using typed errors?
5. ✅ Is it accessible to VoiceOver users and does it adhere to all relevant HIG accessibility guidelines?
6. ✅ Does it conform to Apple Human Interface Guidelines for UI/UX consistency and best practices?

### Anti-Patterns to Catch

```swift
// 🚫 FORBIDDEN: Force unwrapping (e.g., `optional!`) - ALWAYS use safe unwrapping (`if let`, `guard let`, `??`).

// 🚫 FORBIDDEN: Stringly-typed APIs (e.g., `NotificationCenter.default.post(name: "SomeString")`) - ALWAYS use typed notifications or enums.

// 🚫 FORBIDDEN: Massive initializers (`init(a: A, b: B, c: C, d: D, e: E)`) - Limit to 3-4 parameters; use builders or factories for complex object creation.

// 🚫 FORBIDDEN: View logic in models (e.g., `struct Track { var displayName: String { return "♪ \(title)" } }`) - Models should be pure data; presentation logic belongs in Views or ViewModels.

// 🚫 FORBIDDEN: Synchronous file I/O on the main thread (e.g., `let data = try Data(contentsOf: url)`) - ALWAYS use asynchronous variants.
```

### SwiftUI-Specific Anti-Patterns

```swift
// 🚫 FORBIDDEN: GeometryReader abuse - Use only for size-dependent layouts where no other modifier suffices; ALWAYS constrain its frame.

// 🚫 FORBIDDEN: Using `onAppear` for data loading - ALWAYS use the `.task` modifier for asynchronous data fetching tied to view lifecycle.

// 🚫 FORBIDDEN: Complex views without previews - EVERY complex view MUST have a `#Preview` to facilitate rapid UI development and testing.

// 🚫 FORBIDDEN: Direct state mutation in `body` (e.g., `count += 1` in a gesture handler) - State mutations MUST occur within actions or closures that trigger view updates, not directly in the `body` property.

// 🚫 FORBIDDEN: Nesting `ScrollView` directly inside `List` - This causes conflicting scroll behaviors. Use `LazyVStack` within `ScrollView` for custom scrollable content.

// 🚫 FORBIDDEN: Applying `.animation()` directly to a view for state changes - ALWAYS wrap state changes in `withAnimation { ... }` for smoother and predictable animations.
```

### Performance Benchmarks

Every implementation must meet:
- View body computation: < 16ms (ensuring 60fps)
- Image loading: < 100ms perceived latency
- List scrolling: Zero frame drops with 10k items
- Memory: < 1MB per 100 tracks (optimized for large libraries)
- App launch: < 1.5s cold start

### Automated Enforcement

```bash
# Pre-commit hooks must pass:
swiftlint --strict
swift test
xcodebuild -scheme FonicHiFi analyze

# Performance tests must maintain baselines:
xctest -performance-baseline 'baseline.json'
```
```

These rules ensure that Claude Code will consistently produce Swift and SwiftUI code that meets the highest standards of performance, maintainability, and user experience. Each rule is backed by your 2025 knowledge base and real-world iOS development best practices.


