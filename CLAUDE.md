# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Fonic HiFi** - High-fidelity iOS 26 audiophile music player built with Swift 6.2, SwiftUI, AVAudioEngine, and AudioKit. Focus: bit-perfect playback, format versatility, privacy-first design.

**Key Technologies:**
- **Platform**: iOS 26.0 (minimum), Swift 6.2, Xcode 26
- **Audio**: AVAudioEngine, AudioKit, multi-engine facade pattern
- **Concurrency**: Swift 6 strict concurrency, @MainActor boundaries
- **Data**: SwiftData with actor-based persistence (TrackDataActor)
- **UI**: SwiftUI with custom Liquid Glass effects

## Critical Project Rules

- **MANDATORY**: Use `make` commands for ALL build, test, profile, and debug operations
- **MANDATORY**: Verify iOS/Swift claims via apple-rag/sosumi BEFORE stating as facts
- **NEVER**: Run xcodebuild, instruments, xctrace, or profiling tools directly
- **NEVER**: Use placeholder, mock, or fake data in code
- **NEVER**: Leave commented out code or TODO/FIXME comments in files
- **ALWAYS**: Use verification tags: [Verified-Apple], [Verified-Code], [Inference], [Unverified]
- **ALWAYS**: Use TodoWrite for complex tasks (3+ steps) to track progress

See global `~/.claude/CLAUDE.md` for universal Swift/iOS development rules.

## Project Status

**Current Status**: See [STATUS.md](STATUS.md) for volatile session state
**Build**: ✅ PASSING (fix-concurrency-issues @ 80ab4e2)
**Recovery**: Following plan2/fix2.md (4-phase cherry-pick strategy)
**Critical Issues**: See plan2/next-steps.md for P0/P1 prioritized tasks

## Implementation Status [Verified-Code]

**Audio Engines:**
- ✅ AVAudioEngineAdapter - COMPLETE (Core/Audio/Engines/AVAudioEngineAdapter.swift)
- ✅ AudioKitEngineAdapter - COMPLETE (Core/Audio/Engines/AudioKitEngineAdapter.swift)
- ✅ AudioEngineFacade - Main coordinator (Core/Audio/Engine/AudioEngineFacade.swift:20)
- ✅ AudioEngineFactory - Engine selection (Core/Audio/Factory/AudioEngineFactory.swift)

**Data Layer:**
- ✅ TrackDataActor - SwiftData operations (Data/Actors/TrackDataActor.swift:13)
- ✅ DataManager - Main data coordinator (Data/DataManager.swift)
- ✅ LibraryImportService - File import (Data/Services/LibraryImportService.swift)
- ⚠️ LibraryImportService: Main-thread I/O blocks UI (P0 - needs background actor)

**UI Layer:**
- ⚠️ Native `.glassEffect()` - iOS 26 API documented but NOT USED IN CODE
- ✅ `.liquidGlass()` - CUSTOM implementation using Material (LiquidGlassDesignSystem.swift:30)
- ✅ PerformanceOptimizedContainer - CUSTOM container (PerformanceOptimizedContainer.swift:16)

**Non-Existent References (Do NOT reference these):**
- ❌ Core/Audio/Decoders/ - DOES NOT EXIST
- ❌ FormatBadge.swift - DOES NOT EXIST
- ❌ AudioSessionActor - DOES NOT EXIST (uses AudioSessionManager instead)
- ❌ Files/TestAudio/ - DOES NOT EXIST

## iOS 26 Modern API Requirements

**This is an iOS 26-only project - NO backwards compatibility:**
- Target: iOS 26.0 minimum - NO fallbacks to older iOS versions
- APIs: Use ONLY modern iOS 26 APIs - no compatibility wrappers
- NO @available checks: Remove all `@available(iOS 26, *)` attributes
- NO if #available: Remove all `if #available(iOS 26, *)` branches
- Liquid Glass: Use native iOS 26 `.glassEffect()` APIs directly
- ALWAYS: Assume iOS 26 features are available

See global CLAUDE.md for iOS 26 Liquid Glass APIs and Swift 6.2 features.

## Architecture Overview [Verified-Code]

### Audio Engine Facade Pattern

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

### Concurrency Model (Swift 6.2) [Verified-Apple]

**Actor Isolation Boundaries:**
- `@MainActor`: All UI components, ViewModels, AudioEngineFacade
- `TrackDataActor`: SwiftData operations, file I/O (TrackDataActor.swift:13)
- `AudioSessionManager`: Session management (no actor needed)

**Critical Threading Rules:**
1. Audio callbacks MUST dispatch to MainActor for UI updates
2. SwiftData operations MUST go through TrackDataActor
3. Use `Task { @MainActor in ... }` for audio → UI communication
4. All cross-actor types MUST conform to Sendable

**Pattern** (AVAudioEngineAdapter.swift:184):
```swift
// Audio callback on background thread
Task { @MainActor [weak self] in
    self?.handlePlaybackCompletionSync()
}
```

### State Management Architecture

```
PlaybackStateManager (Single source of truth)
├── PlaybackState (Immutable state snapshot)
├── PlaybackStateStore (Persistence layer)
└── Published to:
    ├── AudioEngineFacade
    └── Individual ViewModels
```

**State Flow:**
1. User action → ViewModel method
2. ViewModel → AudioEngineFacade command
3. AudioEngine → PlaybackStateManager update
4. State change → Published to all observers
5. UI updates via @Published properties

## Essential Commands

**Quick Reference:**
```bash
make build              # Build app (Debug)
make lint               # Check code quality (ALWAYS after code changes)
make format             # Auto-format code
make search PATTERN='x' # Fast code search
make find-audio         # Find all audio-related code
```

**Full Command Reference**: See [docs/MAKEFILE.md](docs/MAKEFILE.md)

## Required Development Tools

**Essential (via Homebrew):**
- `xcbeautify` - Xcode build output formatting
- `swiftlint` - Swift code linting
- `swiftformat` - Swift code formatting
- `ripgrep (rg)` - Ultra-fast code search
- `fd` - Fast file finder
- `fzf` - Interactive fuzzy finder

**Install**: `make install-deps` | **Check**: `make check-deps`

## Outstanding P0/P1 Issues [From plan2/next-steps.md]

**Source:** Multiple AI assessments (2025-09-28) identified systemic issues requiring focused follow-up.

### Phase 1 – Crash & Build Safeguards (P0)

1. **Replace residual `try!`/fatal fallbacks**
   - Fonic HiFi/FonicHiFiApp.swift:81 - App init escalates to `try! DataManager()` when all fallbacks fail
   - Fonic HiFi/Data/DataManager.swift:614 - Preview builder falls back to `try! ModelContainer`
   - **Action:** Propagate errors to user-visible failure state (alert/placeholder)

2. **Guard Mach API usage**
   - Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:369 - Direct Mach API calls without availability checks
   - **Action:** Wrap with `#if canImport(Mach)`, provide zero/placeholder metrics when unavailable

### Phase 2 – Performance & Threading (P0)

3. **Move import pipeline off `@MainActor`**
   - Fonic HiFi/Data/Services/LibraryImportService.swift:15,146 - Synchronous FileManager work on main actor
   - **Action:** Convert to non-main actor, perform file I/O on background actor/task
   - **Risk Level:** HIGH - Commit b7e6743 in backup branch contains these changes (342 lines modified)
   - **Testing Required:** Manual import of 10+ files, verify NO UI freezing

4. **Paginate library statistics & heavy fetches**
   - Fonic HiFi/Data/DataManager.swift:89 - `getLibraryStatistics()` fetches entire tables on main context
   - **Action:** Use `fetchCount`, batched fetches, or existing pagination helpers

### Phase 3 – Architecture Cleanup (P1)

5. **Remove unused CloudKit entitlement** - Fonic HiFi/Fonic_HiFi.entitlements:8
6. **Unify logging on `os.Logger`** - Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:1041
7. **Optimize progress timer updates** - Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:930

**Full Details**: See plan2/next-steps.md

## Development Workflow Patterns

### Git Operations (Repository-Specific Safety Directives)

- **ALWAYS** ask after file edits: "Would you like me to commit these changes?"
- Use `gh pr create` for pull requests, not web interface
- Include Co-Authored-By in commits: `Co-Authored-By: Claude <noreply@anthropic.com>`
- Never push unless explicitly requested

### Branch Recovery Protocol [Verified-Code]

**When to Create Emergency Backups:**
- Build failing with complex multi-file changes
- Major refactoring spans multiple sessions
- Before risky git operations (rebase, filter-branch, reset --hard)
- After manual file restoration from previous commits

**Naming Convention:**
```bash
git branch emergency-backup-YYYYMMDD-HHMMSS
```

**Recovery Strategy: Sequential Cherry-Pick (RECOMMENDED)**

1. **Preserve backup branch:** Never force-push or modify backup branches
2. **Work from clean branch:** Ensure working tree is clean before starting recovery
3. **Commit staged changes first:** Always commit any staged work before cherry-picking
4. **Cherry-pick sequentially:** Process commits one at a time with build verification
5. **Handle conflicts:** Use `--ours` for files already manually restored
6. **Document progress:** Update STATUS.md after each phase

**High-Risk Commits (Require Extra Caution):**
- Threading changes: Any commit modifying `@MainActor` annotations (verify with manual testing)
- Data layer changes: DataManager, SwiftData models, actors (test import/export)
- Large formatting commits: 50+ files (consider splitting before applying)

**Rollback Procedures:**
```bash
git reset --soft HEAD^  # Undo last commit (keep changes)
git reset --hard HEAD^  # Undo last commit (discard changes)
git revert COMMIT_SHA   # Revert specific commit
```

### Feature Development Flow

1. Use TodoWrite for tasks with 3+ steps
2. Run `make check-deps` to ensure tools are installed
3. Create feature branch from main
4. Implement with @MainActor boundaries (iOS 26 concurrency)
5. Run `make lint` to check code quality
6. Run `make format` to ensure consistent style
7. Run `make build` to verify compilation
8. Run `make run` to test in iPhone 16 Pro simulator (iOS 26.0)
9. Update STATUS.md if session spans multiple days
10. Ask to commit changes after edits
11. **NEVER** add backwards compatibility code
12. **ALWAYS** use modern iOS 26 APIs directly

## Debugging Reference

**Quick Debug Commands:**
```bash
make find-audio                      # Find audio-related code
make search PATTERN='AudioEngine'    # Search for patterns
make logs-stream                     # Stream live logs
make memory-leaks                    # Check for leaks
```

**Full Debugging Guide**: See [docs/DEBUGGING.md](docs/DEBUGGING.md)

## Critical Implementation Patterns

### Adding a New Audio Format

1. Update Detection in `AudioFormatDetectionManager.detectFormat()`
2. Map to Engine in `AudioEngineFactory.createEngine()`
3. Add format support to appropriate engine adapter
4. Test with real audio files

### Fixing Audio Playback Issues

**Common Issues & Solutions:**

1. **Threading Crashes**
   - Check for missing `@MainActor` annotations
   - Verify `Task { @MainActor in ... }` wrapping
   - Look for synchronous UI updates from background threads

2. **State Desynchronization**
   - Ensure single PlaybackStateManager instance
   - Check for duplicate state updates
   - Verify proper state transition validation

3. **Engine Switching Failures**
   - Review format detection logic
   - Check engine capability matrix
   - Verify engine cleanup in facade coordinators

## Performance Optimization Points [UNVERIFIED]

**Optimization Targets:**
1. LibraryImportService: Batch SwiftData operations
2. AudioQueueManager: Preload next track metadata
3. AudioEngineFacade: Cache engine instances
4. TrackDataActor: Implement pagination for large libraries

**Note:** These are optimization targets, not verified measurements. Profile first with `make profile-cpu` and `make profile-memory`.

## SwiftData Integration [Verified-Apple]

**Model Persistence** (Data/Models/ and Data/Actors/TrackDataActor.swift):
- All database operations through TrackDataActor
- Batch imports for performance
- Relationships: Artist ↔ Album ↔ Track ↔ Playlist
- Migration support via versioned schemas

## Project-Specific Context

**Audio Quality Philosophy:**
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

## Architecture Decision Records

**Why Multiple Audio Engines?**
- AVAudioEngine: Best iOS integration, limited format support
- AudioKit: Superior DSP and FLAC playback, slightly higher CPU usage
- Extensible adapter layer: Leaves room for future specialized engines
- Trade-off: Complexity for flexibility

**Why Actor-Based Concurrency?**
- Swift 6 strict concurrency eliminates races
- Clear isolation boundaries
- Compile-time safety
- Future-proof architecture

**Why SwiftData over Core Data?**
- Modern Swift-first API (iOS 26 enhanced)
- Better SwiftUI integration (iOS 26 features)
- Automatic iCloud sync (iOS 26 implementation)
- Simpler relationship management

## Code Cleanup Requirements

**iOS 26 is the ONLY target - write code as if iOS 26 is guaranteed (because it is).**

Remove these patterns when found:
```swift
// REMOVE THIS:
if #available(iOS 26, *) { /* iOS 26 code */ } else { /* fallback */ }
@available(iOS 26, *) struct MyView: View { ... }

// REPLACE WITH:
// iOS 26 code directly
struct MyView: View { ... }
```

## References

- **Session Status**: [STATUS.md](STATUS.md) - Volatile session state (updated per session)
- **Build Commands**: [docs/MAKEFILE.md](docs/MAKEFILE.md) - Complete command reference
- **Debugging**: [docs/DEBUGGING.md](docs/DEBUGGING.md) - Audio debugging patterns
- **Recovery**: plan2/fix2.md - 4-phase recovery execution guide
- **Issues**: plan2/next-steps.md - P0/P1 prioritized tasks
- **Global Rules**: ~/.claude/CLAUDE.md - Universal Swift/iOS development rules
 Always read @STATUS.md for the current status of the project.
