# ADR 004: MainActor Service Concurrency Patterns

**Status:** Accepted
**Decision Makers:** Development Team
**Date:** 2025-12-05

## Context

`@MainActor` service classes in Fonic HiFi (e.g., `LibraryImportService`) were using `@unchecked Sendable` conformance to bypass Swift 6 concurrency checks. This is dangerous because:

1. `@MainActor` classes are NOT automatically Sendable
2. `@Published` properties require MainActor isolation
3. `@unchecked Sendable` disables compiler safety guarantees

Additionally, Task blocks within these classes were missing `@MainActor` annotations, causing unnecessary actor hops via `await MainActor.run { }`.

## Decision

### Pattern 1: No @unchecked Sendable on @MainActor classes

```swift
// WRONG
@MainActor
final class LibraryImportService: ObservableObject {
    @Published var isImporting = false
}
extension LibraryImportService: @unchecked Sendable {}

// CORRECT
@MainActor
final class LibraryImportService: ObservableObject {
    @Published var isImporting = false
}
// No Sendable conformance - class stays isolated to MainActor
```

### Pattern 2: @MainActor Task blocks inherit isolation

```swift
// WRONG - Unnecessary actor hops
Task(priority: .userInitiated) { [weak self] in
    await MainActor.run { self?.isImporting = true }
}

// CORRECT - Inherits MainActor isolation
Task { @MainActor [weak self] in
    self?.isImporting = true  // Already on MainActor
}
```

### Pattern 3: Nested Tasks for background work with UI updates

When a Task needs to do heavy I/O but periodically update UI:

```swift
// CORRECT - Outer task on MainActor, inner task for I/O
Task { @MainActor [weak self] in
    // UI state setup
    self?.isProcessing = true

    // Spawn background work
    let backgroundTask = Task(priority: .userInitiated) {
        for await item in stream {
            // Heavy processing here (off MainActor)

            // Hop to MainActor for UI updates
            await MainActor.run {
                self?.progress += 1
            }
        }
    }

    await backgroundTask.value
    self?.isProcessing = false
}
```

### Pattern 4: Use nonisolated for truly concurrent work

```swift
@MainActor
final class Service {
    // For work that should run concurrently without actor isolation
    nonisolated func processInBackground(_ data: Data) async -> Result {
        // Runs on cooperative thread pool
    }
}
```

## Consequences

**Positive:**
- Compile-time data race prevention
- No runtime overhead from unnecessary actor hops
- Clear isolation boundaries
- Swift 6 strict concurrency compliance

**Negative:**
- Cannot pass `@MainActor` service references to background tasks directly
- Must use `Task { @MainActor in }` pattern for callbacks
- Slightly more verbose code

## Implementation Notes

Applied to:
- `LibraryImportService.swift` - Removed @unchecked Sendable, fixed Task blocks

## References

- [Swift Evolution SE-0401: Remove Actor Isolation Inference](https://github.com/apple/swift-evolution/blob/main/proposals/0401-remove-property-wrapper-isolation.md)
- [WWDC 2024: Migrate your app to Swift 6](https://developer.apple.com/videos/play/wwdc2024/10169/)
