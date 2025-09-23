# Swift 6.2 Concurrency and Actor Isolation Reference

**Last Updated: September 2025**
**Swift Version: 6.2**
**Platform Focus: iOS 26.0+ (This document focuses on iOS implementation)**
**Verification Status: [Verified-Apple] - From official Swift documentation**

## Overview

Swift 6.2 introduces strict concurrency checking as an opt-in feature that catches data races at compile time. This represents a paradigm shift from runtime crash detection to compile-time safety guarantees.

## Swift 6 Language Mode

### Enabling Strict Concurrency

[Verified-Apple] **Build Settings Configuration:**

1. **Gradual Adoption (Swift 5 mode):**
   - Swift Compiler - Upcoming Features → Enable individual features
   - Strict Concurrency Checking → Complete

2. **Full Swift 6 Mode:**
   - Swift Compiler - Language → Swift Language Version → Swift 6
   - Enables ALL concurrency features automatically

### Migration Strategy

[Verified-Apple] **Recommended approach:**
```swift
// Start with Swift 5 mode + complete checking
// Fix warnings gradually
// Then switch to Swift 6 mode
```

**Module-by-module migration:**
- Apps first, then dependencies
- Each module can have different language mode
- Binary compatibility maintained

## Core Concurrency Concepts

### Data Race Prevention

[Verified-Apple] **Three conditions create data races:**
1. Overlapping access
2. Shared state
3. Mutable data

**Solution:** Eliminate at least one condition.

### Actor Isolation

[Verified-Apple] **Default isolation changes in Swift 6.2:**

```swift
// Swift 6.2: Async functions inherit caller's isolation
@MainActor
class ViewModel {
    func updateUI() async {
        // Runs on MainActor (inherited)
        await fetchData()
    }

    func fetchData() async {
        // Also on MainActor unless explicitly moved
    }
}
```

**No more thread hopping:**
```swift
// Old behavior (Swift 5)
@MainActor func updateUI() async {
    // On main thread
    await doWork()  // Hops to cooperative thread pool
    // Back to main thread
}

// New behavior (Swift 6.2)
@MainActor func updateUI() async {
    // On main thread
    await doWork()  // STAYS on main thread
    // Still on main thread
}
```

## MainActor Isolation

### Default MainActor for UI

[Verified-Apple] **Automatic MainActor inference:**

```swift
import SwiftUI

// View is implicitly @MainActor
struct ContentView: View {
    // All properties are MainActor-isolated
    @State private var count = 0

    // All methods are MainActor-isolated
    func increment() {
        count += 1  // Safe: on main thread
    }

    var body: some View {
        Button("Count: \(count)") {
            increment()  // No await needed
        }
    }
}
```

### Explicit MainActor Usage

[Verified-Apple] **When to use @MainActor:**

```swift
// Mark entire class
@MainActor
final class AudioPlayerViewModel: ObservableObject {
    @Published var isPlaying = false

    func play() {
        isPlaying = true
    }
}

// Mark specific methods
class DataManager {
    @MainActor
    func updateUI(with data: String) {
        // UI updates here
    }

    nonisolated func fetchData() async -> String {
        // Background work here
        return "data"
    }
}
```

## Sendable Types

### Automatic Sendable Conformance

[Verified-Apple] **Swift 6.2 automatic inference:**

```swift
// Automatically Sendable (all stored properties Sendable)
struct Song {
    let title: String
    let duration: TimeInterval
    let id: UUID
}

// Automatically Sendable (immutable class)
final class ImmutableConfig: Sendable {
    let apiKey: String
    let endpoint: URL

    init(apiKey: String, endpoint: URL) {
        self.apiKey = apiKey
        self.endpoint = endpoint
    }
}
```

### Manual Sendable Conformance

[Verified-Apple] **When automatic doesn't work:**

```swift
// Need explicit conformance + @unchecked
final class AudioBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer: [Float]

    func read() -> [Float] {
        lock.withLock { buffer }
    }

    func write(_ data: [Float]) {
        lock.withLock { buffer = data }
    }
}
```

### Sendable Closures

[Verified-Apple] **Closure requirements in Swift 6.2:**

```swift
// Sendable closure required for concurrent contexts
func processInBackground(
    work: @Sendable () async -> Void
) {
    Task {
        await work()
    }
}

// Using with capture lists
func startTimer(count: Int) {
    Task { [count] in  // Capture by value for Sendable
        for i in 0..<count {
            print(i)
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
```

## Task and Async/Await

### Task Isolation

[Verified-Apple] **Task inherits actor context:**

```swift
@MainActor
func scheduleWork() {
    Task {
        // This task runs on MainActor
        updateUI()
    }

    Task.detached {
        // This runs on cooperative thread pool
        await performBackgroundWork()
    }
}
```

### Async Sequences

[Verified-Apple] **Actor-isolated async sequences:**

```swift
@MainActor
class StreamProcessor {
    func process() async {
        for await value in asyncSequence {
            // Each iteration on MainActor
            updateUI(with: value)
        }
    }
}
```

## Actor Design Patterns

### Custom Actors

[Verified-Apple] **Creating domain-specific actors:**

```swift
actor AudioEngine {
    private var isPlaying = false
    private var queue: [Track] = []

    func play() {
        isPlaying = true
    }

    func addToQueue(_ track: Track) {
        queue.append(track)
    }

    nonisolated func getInfo() -> String {
        "AudioEngine"  // Constant, safe to access
    }
}
```

### Global Actors

[Verified-Apple] **Creating custom global actors:**

```swift
@globalActor
actor DataActor {
    static let shared = DataActor()
}

@DataActor
class DatabaseManager {
    func save(_ record: Record) {
        // Isolated to DataActor
    }
}
```

## Migration Patterns

### Migrating from Completion Handlers

[Verified-Apple] **Before (Swift 5):**
```swift
func loadData(completion: @escaping (Result<Data, Error>) -> Void) {
    URLSession.shared.dataTask(with: url) { data, _, error in
        if let error = error {
            completion(.failure(error))
        } else if let data = data {
            completion(.success(data))
        }
    }.resume()
}
```

**After (Swift 6.2):**
```swift
func loadData() async throws -> Data {
    let (data, _) = try await URLSession.shared.data(from: url)
    return data
}
```

### Migrating Observable Objects

[Verified-Apple] **Before (Combine):**
```swift
class ViewModel: ObservableObject {
    @Published var items: [Item] = []

    func load() {
        service.fetchItems()
            .receive(on: DispatchQueue.main)
            .sink { items in
                self.items = items
            }
            .store(in: &cancellables)
    }
}
```

**After (Swift 6.2 + Observation):**
```swift
@Observable @MainActor
final class ViewModel {
    var items: [Item] = []

    func load() async {
        items = await service.fetchItems()
    }
}
```

## Common Patterns and Solutions

### Pattern 1: Background Processing

[Verified-Apple] **Proper background work:**
```swift
@MainActor
class ImageProcessor {
    func processImage(_ image: UIImage) async -> UIImage? {
        // Move off MainActor for heavy work
        return await Task.detached(priority: .userInitiated) {
            // Heavy processing here
            return self.applyFilters(to: image)
        }.value
    }

    nonisolated func applyFilters(to image: UIImage) -> UIImage {
        // CPU-intensive work
        return image
    }
}
```

### Pattern 2: Thread-Safe Shared State

[Verified-Apple] **Using actors for shared state:**
```swift
actor Counter {
    private var value = 0

    func increment() -> Int {
        value += 1
        return value
    }

    func reset() {
        value = 0
    }
}

// Usage
let counter = Counter()
await counter.increment()
```

### Pattern 3: Bridging Sync and Async

[Verified-Apple] **Safe bridging patterns:**
```swift
@MainActor
class LegacyBridge {
    func handleLegacyCallback() {
        // Called from non-async context
        Task { @MainActor in
            await updateUI()
        }
    }

    func updateUI() async {
        // Async UI updates
    }
}
```

## Compiler Annotations

### Key Annotations

[Verified-Apple] **Swift 6.2 annotations:**

```swift
// Force main actor isolation
NS_SWIFT_UI_ACTOR

// Mark as non-isolated
NS_SWIFT_NONISOLATED

// Sendable conformance
NS_SWIFT_SENDABLE
NS_SWIFT_NONSENDABLE

// Example usage in Objective-C header
NS_SWIFT_UI_ACTOR
@interface MyViewController : UIViewController
@end
```

### CoreData Annotations

[Verified-Apple] **Updated in iOS 26:**
```swift
// NSManagedObject: NOT Sendable
// NSManagedObjectContext: Sendable (for passing references)

// Correct usage
func performBackgroundWork(context: NSManagedObjectContext) {
    context.perform {  // @Sendable closure required
        // Work with managed objects here
    }
}
```

## Warnings and Errors

### Common Concurrency Warnings

[Verified-Apple] **How to fix common issues:**

1. **"Capture of 'self' with non-sendable type"**
```swift
// Problem
class NonSendable {
    var value = 0
    func start() {
        Task {
            value += 1  // Warning!
        }
    }
}

// Solution
@MainActor class NonSendable {
    var value = 0
    func start() {
        Task {
            value += 1  // Safe
        }
    }
}
```

2. **"Mutation of captured var"**
```swift
// Problem
var count = 0
Task {
    count += 1  // Error!
}

// Solution
let count = 0
Task { [count] in
    var localCount = count
    localCount += 1
}
```

3. **"Call to main actor-isolated method"**
```swift
// Problem
func background() async {
    updateUI()  // Error!
}

// Solution
func background() async {
    await MainActor.run {
        updateUI()
    }
}
```

## Performance Considerations

### Minimizing Actor Hops

[Verified-Apple] **Reduce cross-actor calls:**
```swift
// Inefficient
actor DataStore {
    func getValue() -> Int { value }
    func getValue2() -> String { string }
}

// Better: Batch operations
actor DataStore {
    func getAllValues() -> (Int, String) {
        (value, string)
    }
}
```

### Avoiding Deadlocks

[Verified-Apple] **Prevent circular waits:**
```swift
// Dangerous
actor A {
    func callB(b: B) async {
        await b.callA(a: self)  // Potential deadlock
    }
}

// Safe: Use nonisolated or redesign
actor A {
    nonisolated func getSafeData() -> Data {
        // Return immutable data
    }
}
```

## Testing Concurrent Code

### Testing Actors

[Verified-Apple] **XCTest with actors:**
```swift
@MainActor
final class ViewModelTests: XCTestCase {
    func testStateUpdate() async {
        let viewModel = ViewModel()
        await viewModel.updateState()
        XCTAssertTrue(viewModel.isUpdated)
    }
}
```

### Testing Sendable

[Verified-Apple] **Verify Sendable conformance:**
```swift
func requiresSendable<T: Sendable>(_ value: T) { }

// Test at compile time
func testSendable() {
    let myStruct = MyStruct()
    requiresSendable(myStruct)  // Compiles = Sendable
}
```

## Best Practices

### Do's

[Verified-Apple] **Recommended patterns:**
1. ✅ Use @MainActor for all UI code
2. ✅ Make value types Sendable when possible
3. ✅ Use actors for shared mutable state
4. ✅ Prefer immutable data
5. ✅ Use structured concurrency (async/await)

### Don'ts

[Verified-Apple] **Avoid these patterns:**
1. ❌ Don't use DispatchQueue.main.async in Swift 6
2. ❌ Don't share mutable reference types
3. ❌ Don't use @unchecked Sendable without synchronization
4. ❌ Don't mix completion handlers with async/await
5. ❌ Don't ignore concurrency warnings

## Summary

Swift 6.2's strict concurrency model provides:
- **Compile-time safety** against data races
- **Better performance** with reduced thread hopping
- **Clearer code** with explicit isolation
- **Gradual migration** path from Swift 5

Focus on adopting @MainActor for UI code and enabling strict checking incrementally for safest migration.