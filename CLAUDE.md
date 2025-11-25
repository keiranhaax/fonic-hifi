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
- **ALWAYS**: Route all logging through `Log.logger(_:)` using the taxonomy in `Fonic HiFi/Utils/Logging/Log.swift`; add new categories only when the existing domains do not cover a scenario.[Verified-Code]
- **NEVER**: Emit raw file paths or large user strings—use `LogPrivacy` helpers for filenames and truncation before logging or counting events.[Verified-Code]
- **OPTIONAL**: Enable telemetry counters via `Metrics.enable(true)` when observing imports, engine switches, or queue mutations; leave metrics disabled in production builds unless explicitly requested.[Verified-Code]
- **ALWAYS**: Use TodoWrite for complex tasks (3+ steps) to track progress

See global `~/.claude/CLAUDE.md` for universal Swift/iOS development rules.

## Project Status

**Current**: @STATUS.md
**Commands**: Run `make help` for all build/test patterns; compiler behavior and security notes below.

## iOS 26 Modern API Requirements

**This is an iOS 26-only project - NO backwards compatibility:**
- Target: iOS 26.0 minimum - NO fallbacks to older iOS versions
- APIs: Use ONLY modern iOS 26 APIs - no compatibility wrappers
- NO @available checks: Remove all `@available(iOS 26, *)` attributes
- NO if #available: Remove all `if #available(iOS 26, *)` branches
- Liquid Glass: Use native iOS 26 `.glassEffect()` APIs directly
- ALWAYS: Assume iOS 26 features are available


## iOS 26 Verification Protocol

**Use the iOS 26 Research Assistant skill** (@.claude/skills/ios26-research/SKILL.md) to verify all iOS 26 claims.

**Required before stating iOS 26 facts:**
1. Search Apple documentation using MCP tools (apple-rag-mcp, sosumi)
2. Tag all iOS 26 information with verification status
3. Cite source URLs from Apple documentation
4. Use [Searched-Not-Found] when documentation unavailable

**Verification Tags for iOS 26:**
- **[Verified-Apple-iOS26]** - Found in official Apple iOS 26 documentation
- **[Verified-WWDC25]** - Found in WWDC 2025 session content
- **[Searched-Not-Found]** - Searched but not found in Apple docs
- **[Inference-Only]** - Based on pre-January 2025 knowledge (low confidence)

**Priority topics requiring verification:**
- Liquid Glass APIs (`.glassEffect()`, `GlassEffectContainer`, tinting, interactivity)
- SwiftUI iOS 26 improvements (navigation, sheets, transitions, morphing)
- SwiftData iOS 26 enhancements (actor patterns, query performance)
- AVAudioEngine iOS 26 changes
- Swift 6.2 + iOS 26 concurrency patterns

See skill documentation for complete multi-tier search strategy and examples.

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

## Required Development Tools

**Essential (via Homebrew):**
- `xcbeautify` - Xcode build output formatting
- `swiftlint` - Swift code linting
- `swiftformat` - Swift code formatting
- `ripgrep (rg)` - Ultra-fast code search
- `fd` - Fast file finder
- `fzf` - Interactive fuzzy finder

**Install**: `make install-deps` | **Check**: `make check-deps`

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

### Observability Checklist [Verified-Code]

1. Select an existing `LogCategory` (see `Utils/Logging/Log.swift`) or add a new entry within the matching domain namespace when necessary.
2. Redact filesystem details with `LogPrivacy.filename(_:)` and clamp long metadata via `LogPrivacy.truncated(_:limit:)` before logging.
3. Wrap optional counters with `Metrics.increment` only after calling `Metrics.enable(true)` (e.g., in debug builds or test harnesses).
4. Record instrumentation decisions in ADRs or `docs/refactor/observability-walkthrough.md` so future contributors share the same taxonomy assumptions.

## Command & Build Notes [Verified-Code]

- Use `make help` as the single source of truth for build/test/debug commands; avoid direct `xcodebuild`/`xctrace`/profilers.
- Compiler builds from the working tree (including staged changes). A successful build can include staged-but-uncommitted code—commit or document staged work before relying on results.
- Fast checks: `make build-check` for exit-code-only, `make build-verify` + `make error-report` for full failure context.
- Makefile security hardening (Oct 2025): PID regex validation and bounded durations, mktemp + trap cleanup, bundle ID matching for processes, fail-fast error handling, crash log sorting + atos validation, and `CODEX_ALLOW_UPLOAD=1` gate for AI uploads.

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

- @STATUS.md - Current project state and progress
- Makefile (`make help`) - Command catalog; see Command & Build Notes above
