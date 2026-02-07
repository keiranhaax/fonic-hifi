# CLAUDE.md

## Project Overview

**Fonic HiFi** - High-fidelity iOS 26 audiophile music player built with Swift 6.2, SwiftUI, AVAudioEngine, and AudioKit. Focus: bit-perfect playback, format versatility, privacy-first design.

**Key Technologies:**
- **Platform**: iOS 26.0 (minimum), Swift 6.2, Xcode 26
- **Audio**: AVAudioEngine, AudioKit, multi-engine facade pattern
- **Concurrency**: Swift 6 strict concurrency, @MainActor boundaries
- **Data**: SwiftData with actor-based persistence (TrackDataActor)
- **UI**: SwiftUI with custom Liquid Glass effects

## Information Recording Principles (Claude must read)

This document uses **progressive disclosure** architecture to optimize LLM working efficiency.

### Level 1 (this file) records only

| Type | Example |
|------|---------|
| Core commands | `make build`, `make test` |
| Iron rules / prohibitions | Never run xcodebuild directly |
| Error diagnostics | Symptom -> cause -> fix (complete flow) |
| Code patterns | Copy-paste-ready code blocks |
| Directory navigation | Function -> file mapping |
| Trigger index tables | Entry points to Level 2 |

### Level 2 (`docs/references/`) records

| Type | Example |
|------|---------|
| Detailed SOP procedures | Branch recovery, cherry-pick strategy |
| Edge case handling | Rare error diagnosis |
| Full architecture diagrams | Widget tree, state flow, engine facade |
| Design philosophy / history | ADRs, design rationale |

### When asked to record information

1. **Is it high-frequency?** Yes -> Level 1. No -> Level 2.
2. **Level 1 references to Level 2 must include:** trigger condition + content summary.
3. **Never:** put low-frequency detailed procedures in Level 1, or reference Level 2 without trigger conditions.

---

## Reference Index (check here when you hit a problem)

| Trigger | Document | Key Content |
|---------|----------|-------------|
| Need full architecture diagrams, state flow, widget tree | `docs/references/architecture-reference.md` | Engine facade, state management, widget, SwiftData, ADRs, design philosophy |
| Build failing on multi-file refactor, need cherry-pick recovery | `docs/references/git-recovery-sop.md` | Emergency backup, sequential cherry-pick, rollback procedures |
| Adding logging, metrics, privacy redaction | `docs/references/observability-sop.md` | LogCategory taxonomy, LogPrivacy helpers, Metrics checklist |
| App slow, memory issues, need profiling targets | `docs/references/performance-targets.md` | Unverified optimization targets, known issues, profiling commands |

---

## Critical Project Rules

- **MANDATORY**: Use MCP tools for build, test, and run operations; use `make` for lint, format, coverage, and profiling
- **MANDATORY**: Verify iOS/Swift claims via `DocumentationSearch` or `web_search` BEFORE stating as facts
- **NEVER**: Run xcodebuild, instruments, xctrace, or profiling tools directly via Bash
- **NEVER**: Use placeholder, mock, or fake data in code
- **NEVER**: Leave commented out code or TODO/FIXME comments in files
- **ALWAYS**: Use verification tags: [Verified-Apple], [Verified-Code], [Inference], [Unverified]
- **ALWAYS**: Route logging through `Log.logger(_:)` (taxonomy in `Fonic HiFi/Utils/Logging/Log.swift`)
- **NEVER**: Emit raw file paths or large user strings — use `LogPrivacy` helpers
- **ALWAYS**: Use TodoWrite for complex tasks (3+ steps) to track progress

See global `~/.claude/CLAUDE.md` for universal Swift/iOS development rules.

## iOS 26 Rules (iOS 26-only project, NO backwards compatibility)

- Target: iOS 26.0 minimum — NO fallbacks to older iOS
- Use ONLY modern iOS 26 APIs — no compatibility wrappers
- NO `@available(iOS 26, *)` — remove when found
- NO `if #available(iOS 26, *)` — remove when found
- Liquid Glass: Use native `.glassEffect()` directly

```swift
// REMOVE when found:
if #available(iOS 26, *) { /* iOS 26 code */ } else { /* fallback */ }
@available(iOS 26, *) struct MyView: View { ... }

// REPLACE WITH direct code:
struct MyView: View { ... }
```

## iOS 26 Verification Protocol

Use iOS 26 Research Assistant skill (@.claude/skills/ios26-research/SKILL.md) to verify all iOS 26 claims.

**Required before stating iOS 26 facts:**
1. Search Apple documentation via `DocumentationSearch` (Xcode MCP) or `web_search` (omnisearch-remote)
2. Tag all iOS 26 information with verification status
3. Cite source URLs from Apple documentation

**Verification Tags:** [Verified-Apple-iOS26], [Verified-WWDC25], [Searched-Not-Found], [Inference-Only]

## Essential Commands [Verified-Code]

**Build, Test, Run** (prefer MCP tools):
- Build: `BuildProject` (Xcode MCP) or `build_sim` (XcodeBuildMCP)
- Test: `RunAllTests` / `RunSomeTests` (Xcode MCP) or `test_sim` (XcodeBuildMCP)
- Run: `build_run_sim` (XcodeBuildMCP)
- Build errors: `GetBuildLog` (Xcode MCP, filter by severity)

**Lint, Format, Coverage** (make commands — no MCP equivalent):
```
make lint            # SwiftLint strict mode
make format          # SwiftFormat auto-fix
make coverage        # Generate coverage report
make coverage-check  # Verify coverage target
```

**Profiling & Diagnostics** (make commands):
`make profile-cpu`, `make profile-memory`, `make crash-logs`, `make logs-stream`, `make logs-filter SUBSYSTEM=...`

**Tools:** `make install-deps` (install) | `make check-deps` (verify)
Required: xcbeautify, swiftlint, swiftformat, ripgrep, fd, fzf

**Build note:** Compiler builds from the working tree (including staged changes). Commit or document staged work before relying on results.

## MCP Server Tools

Three MCP servers are available. Use these instead of running xcodebuild/instruments directly via Bash.

### Xcode MCP (`mcp__xcode__*`) — IDE Integration

All Xcode MCP tools require `tabIdentifier: "windowtab1"`.

| Task | Tool | Notes |
|------|------|-------|
| Search Apple docs | `DocumentationSearch` | Prefer over web search for API questions |
| Build project | `BuildProject` | Build and check for errors |
| Get build errors | `GetBuildLog` | Filter by severity: error, warning, remark |
| Run all tests | `RunAllTests` | Uses active scheme's test plan |
| Run specific tests | `RunSomeTests` | Pass targetName + testIdentifier |
| Preview SwiftUI | `RenderPreview` | Snapshot preview to verify UI changes |
| Run code snippet | `ExecuteSnippet` | Execute code in context of a source file |
| Compiler diagnostics | `XcodeRefreshCodeIssuesInFile` | Real-time errors/warnings for a file |
| Read/Write/Edit files | `XcodeRead`, `XcodeWrite`, `XcodeUpdate` | Works on project structure paths |
| Search project | `XcodeGrep`, `XcodeGlob`, `XcodeLS` | Search/browse Xcode project organization |

### XcodeBuildMCP (`mcp__xcodebuildmcp__*`) — Simulator & Runtime

| Task | Tool | Notes |
|------|------|-------|
| Build for simulator | `build_sim` | Builds app for iOS simulator |
| Build + run | `build_run_sim` | Build and launch in one step |
| Run tests | `test_sim` | Run tests on simulator |
| Screenshot | `screenshot` | Capture simulator for visual verification |
| UI hierarchy | `describe_ui` | Get element frames — use before tap/swipe |
| Tap/swipe/type | `tap`, `swipe`, `gesture`, `type_text` | Simulator interaction (use describe_ui first) |
| Log capture | `start_sim_log_cap` / `stop_sim_log_cap` | Capture app logs by bundleId |
| List simulators | `list_sims` | Show available simulators with UUIDs |
| Boot simulator | `boot_sim` | Start a simulator |
| Set defaults | `session-set-defaults` | Set scheme, simulator, project path |

### Omnisearch (`mcp__omnisearch-remote__*`) — Web Search & Extraction

| Task | Tool | Notes |
|------|------|-------|
| Web search | `web_search` | Providers: tavily, brave, kagi, exa |
| AI search | `ai_search` | Providers: perplexity, kagi_fastgpt, exa_answer |
| GitHub search | `github_search` | Code, repos, or users (supports advanced syntax) |
| Extract web content | `firecrawl_process` | Modes: scrape, crawl, map, extract |
| Extract page text | `tavily_extract_process` | Clean text from URLs |

## Concurrency Model (Swift 6.2) [Verified-Apple]

**Actor Isolation Boundaries:**
- `@MainActor`: All UI components, ViewModels, AudioEngineFacade
- `TrackDataActor`: SwiftData operations, file I/O (TrackDataActor.swift:13)
- `AudioSessionManager`: Session management (no actor needed)

**Critical Threading Rules:**
1. Audio callbacks MUST dispatch to MainActor for UI updates
2. SwiftData operations MUST go through TrackDataActor
3. Use `Task { @MainActor in ... }` for audio -> UI communication
4. All cross-actor types MUST conform to Sendable

**Pattern** (AVAudioEngineAdapter.swift:184):
```swift
// Audio callback on background thread
Task { @MainActor [weak self] in
    self?.handlePlaybackCompletionSync()
}
```

**Concurrency Anti-Patterns** (see ADR 004):
```swift
// ❌ NEVER: @unchecked Sendable on @MainActor classes
@MainActor final class Service {}
extension Service: @unchecked Sendable {} // Bypasses safety!

// ❌ NEVER: Unnecessary actor hops
Task { await MainActor.run { self?.update() } }

// ✅ ALWAYS: Inherit MainActor isolation
Task { @MainActor [weak self] in self?.update() }
```

## Directory Map (Function -> File)

| Function | Location |
|----------|----------|
| Audio engine coordination | `Core/Audio/Engine/AudioEngineFacade.swift:20` |
| AVAudioEngine playback | `Core/Audio/Engines/AVAudioEngineAdapter.swift` |
| AudioKit playback | `Core/Audio/Engines/AudioKitEngineAdapter.swift` |
| Engine selection | `Core/Audio/Factory/AudioEngineFactory.swift` |
| Format detection | `AudioFormatDetectionManager.detectFormat()` |
| SwiftData operations | `Data/Actors/TrackDataActor.swift:13` |
| File import | `Data/Actors/FileImportProcessor.swift:189` |
| Data management | `Data/DataManager.swift` |
| Library import | `Data/Services/LibraryImportService.swift` |
| Playback state | `PlaybackStateManager` (single source of truth) |
| State coordination | `StateCoordinator`, `QueueCoordinator`, `PlaybackController` |
| Logging taxonomy | `Fonic HiFi/Utils/Logging/Log.swift` |
| Diagnostics | `Core/Audio/Diagnostics/AudioMetricsScheduler.swift` |
| Artwork morphing | `MorphableArtwork.swift` (`.matchedGeometryEffect()`) |
| Mini player | `LiquidGlassMiniPlayer.swift` (glass effect) |
| Theme palette | `Core/Services/ThemePalette.swift` |
| Widget extension | `Fonic HiFi Widget/` (Small, Medium, Large, Lock Screen) |
| AI recommendations | `Core/AI/Recommendations/` |
| Smart search | `Core/AI/Search/SmartSearchService.swift` |

## Error Diagnostics

### Audio Playback Issues

1. **Threading Crashes**
   - Check for missing `@MainActor` annotations
   - Verify `Task { @MainActor in ... }` wrapping
   - Look for synchronous UI updates from background threads

2. **State Desynchronization**
   - Ensure single PlaybackStateManager instance
   - Check for duplicate state updates
   - Verify proper state transition validation

3. **Engine Switching Failures**
   - Review format detection logic in `AudioFormatDetectionManager`
   - Check engine capability matrix in `AudioEngineFactory`
   - Verify engine cleanup in facade coordinators

### Adding a New Audio Format

1. Update Detection in `AudioFormatDetectionManager.detectFormat()`
2. Map to Engine in `AudioEngineFactory.createEngine()`
3. Add format support to appropriate engine adapter
4. Test with real audio files

## Non-Existent References (Do NOT reference)

- `Core/LiveActivity/`, `LiveActivityManager.swift`, `NowPlayingAttributes.swift` — NOT PLANNED (system Now Playing controls used)
- `Core/Audio/Decoders/` — DOES NOT EXIST
- `FormatBadge.swift` — DOES NOT EXIST
- `AudioSessionActor` — DOES NOT EXIST (use `AudioSessionManager`)
- `PerformanceOptimizedContainer.swift` — DELETED

## Test Organization [Verified-Code]

**60+ test files** (Fonic HiFiTests/): Audio Engine, Diagnostics (14 files), Data Layer, Queue/Playback, UI
**Coverage**: 45.36% overall, 33.61% app (target: 40% — currently failing)
**Run**: `make test` | `make coverage` | `make coverage-check`

## Git Operations

- **ALWAYS** ask after file edits: "Would you like me to commit these changes?"
- Use `gh pr create` for pull requests, not web interface
- Include Co-Authored-By: `Co-Authored-By: Claude <noreply@anthropic.com>`
- Never push unless explicitly requested

## Feature Development Flow

1. TodoWrite for tasks with 3+ steps
2. `make check-deps` -> feature branch from main
3. Implement with @MainActor boundaries
4. `make lint` -> `make format` -> `BuildProject` -> `build_run_sim`
5. Update STATUS.md if session spans multiple days
6. Ask to commit changes after edits

## Before Modifying Code (check the right reference)

| You're changing | Read first | Key traps |
|----------------|-----------|-----------|
| Audio engine / format support | This file: Error Diagnostics + Directory Map | Engine selection is format-dependent; test with real files |
| Concurrency / @MainActor | This file: Concurrency Model | Never `@unchecked Sendable` on `@MainActor` classes (ADR 004) |
| SwiftData models / actors | This file: Directory Map | ALL db ops through TrackDataActor; batch imports for performance |
| Widget extension | `docs/references/architecture-reference.md` | Lock Screen Now Playing is system-handled (not Live Activities) |
| Logging / metrics | `docs/references/observability-sop.md` | Use LogPrivacy helpers; metrics disabled in production |
| Multi-file refactor / recovery | `docs/references/git-recovery-sop.md` | Emergency backup naming; sequential cherry-pick strategy |
| Performance optimization | `docs/references/performance-targets.md` | Profile FIRST with `make profile-cpu`; targets are unverified |
| State management | `docs/references/architecture-reference.md` | Single PlaybackStateManager; StateCoordinator validates transitions |

## Project Status

**Current**: @STATUS.md
**Build**: `make lint` (0 violations) | `make test` (347 tests, 0 failures) | `make coverage-check` (33.61% < 40% target)

---

## Reference Trigger Index (check here during long conversations)

| Trigger | Document | Key Content |
|---------|----------|-------------|
| Full architecture diagrams, state flow, widget tree, ADRs, design philosophy | `docs/references/architecture-reference.md` | Engine facade, state management, widget, SwiftData, ADRs |
| Build failing on multi-file refactor, cherry-pick recovery, rollback | `docs/references/git-recovery-sop.md` | Emergency backup, sequential cherry-pick, rollback procedures |
| Adding logging, metrics, privacy redaction, LogCategory | `docs/references/observability-sop.md` | LogCategory taxonomy, LogPrivacy helpers, Metrics checklist |
| App slow, memory issues, profiling targets | `docs/references/performance-targets.md` | Optimization targets, known issues, profiling commands |
