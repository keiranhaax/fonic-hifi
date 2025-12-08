# Audit Remediation: Remove @unchecked Sendable from @MainActor Classes

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove ADR 004 violations where `@unchecked Sendable` is incorrectly applied to `@MainActor` classes.

**Architecture:** `@MainActor` classes are implicitly Sendable because the actor serializes all access. Adding `@unchecked Sendable` bypasses Swift 6's data-race prevention and is explicitly forbidden by ADR 004.

**Tech Stack:** Swift 6.2, iOS 26, strict concurrency

---

## Background

**Source:** AUDIT.md validation (2025-12-07)

**ADR 004 Rule:** Never use `@unchecked Sendable` on `@MainActor` classes.

**Why it's dangerous:** `@unchecked Sendable` tells the compiler "trust me, this is safe" but bypasses compile-time safety checks. `@MainActor` already provides implicit Sendable conformance via actor isolation.

---

### Task 1: Remove @unchecked Sendable from GlassPerformanceProfiler

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/Components/GlassModifiers.swift:382`

**Step 1: Verify current state**

Run: `grep -n "@unchecked Sendable" "Fonic HiFi/Presentation/Views/Components/GlassModifiers.swift"`

Expected output includes:
```
382:final class GlassPerformanceProfiler: ObservableObject, @unchecked Sendable {
438:final class GlassEffectMemoryManager: ObservableObject, @unchecked Sendable {
```

**Step 2: Remove @unchecked Sendable from GlassPerformanceProfiler**

Change line 382 from:
```swift
final class GlassPerformanceProfiler: ObservableObject, @unchecked Sendable {
```

To:
```swift
final class GlassPerformanceProfiler: ObservableObject {
```

**Step 3: Verify compilation**

Run: `make build`

Expected: BUILD SUCCEEDED (no errors about Sendable - class is implicitly Sendable via @MainActor)

---

### Task 2: Remove @unchecked Sendable from GlassEffectMemoryManager

**Files:**
- Modify: `Fonic HiFi/Presentation/Views/Components/GlassModifiers.swift:438`

**Step 1: Remove @unchecked Sendable from GlassEffectMemoryManager**

Change line 438 from:
```swift
final class GlassEffectMemoryManager: ObservableObject, @unchecked Sendable {
```

To:
```swift
final class GlassEffectMemoryManager: ObservableObject {
```

**Step 2: Verify compilation**

Run: `make build`

Expected: BUILD SUCCEEDED

**Step 3: Run tests**

Run: `make test`

Expected: All 361 tests pass, 0 failures

**Step 4: Commit**

```bash
git add "Fonic HiFi/Presentation/Views/Components/GlassModifiers.swift"
git commit -m "fix(concurrency): remove @unchecked Sendable from @MainActor classes

Per ADR 004, @MainActor classes are implicitly Sendable via actor isolation.
The @unchecked Sendable annotation was redundant and bypassed compiler safety.

Removed from:
- GlassPerformanceProfiler (line 382)
- GlassEffectMemoryManager (line 438)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 3: Verify no remaining violations in production code

**Step 1: Search for remaining @unchecked Sendable in production code**

Run: `grep -rn "@unchecked Sendable" "Fonic HiFi/" --include="*.swift" | grep -v Tests`

Expected: Only `AudioPlaybackSettingsStore.swift:6` (acceptable - UserDefaults wrapper in actor)

**Step 2: Document remaining usage**

The `DefaultsBox` wrapper in `AudioPlaybackSettingsStore.swift` is acceptable because:
- It wraps `UserDefaults` which is non-Sendable but thread-safe
- It's inside an `actor` which provides additional isolation
- Removing it would require `nonisolated init` and may cause compiler issues

No action required.

---

## Summary

| Task | File | Action | Status |
|------|------|--------|--------|
| 1 | GlassModifiers.swift:382 | Remove `, @unchecked Sendable` | ☐ |
| 2 | GlassModifiers.swift:438 | Remove `, @unchecked Sendable` | ☐ |
| 3 | Verify no remaining violations | grep search | ☐ |

**Total changes:** 2 line modifications
**Estimated time:** 5 minutes
