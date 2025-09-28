
# Implementation Plan: Fonic HiFi Critical Improvements

**Branch**: `002-to-implement-this` | **Date**: 2025-09-26 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-to-implement-this/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from file system structure or context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Fill the Constitution Check section based on the content of the constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, `GEMINI.md` for Gemini CLI, `QWEN.md` for Qwen Code or `AGENTS.md` for opencode).
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
Implementing critical stability, performance, and architecture improvements for the Fonic HiFi iOS audio player to eliminate crashes, enable remote commands, optimize performance for 100k+ track libraries, and improve user experience. The implementation focuses on Swift 6 concurrency compliance, thread-safe UI updates, efficient data operations, and proper memory management across 28 functional requirements prioritized over 4 weeks.

## Technical Context
**Language/Version**: Swift 6.2
**Primary Dependencies**: SwiftUI, AVAudioEngine, AudioKit, SwiftData, Combine, AVFoundation
**Storage**: SwiftData with ModelActor pattern for persistence
**Testing**: No test infrastructure per requirements
**Target Platform**: iOS 26.0+ (iPhone 16 Pro Simulator)
**Project Type**: mobile - iOS application
**Performance Goals**: 60fps UI, <50ms audio latency, <150ms library search for 100k tracks
**Constraints**: <200MB memory usage, bit-perfect playback, no network required, background audio
**Scale/Scope**: 100k+ tracks, ~100 Swift files (~25k LOC), 28 requirements over 4 weeks

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Note**: Constitution template is not yet filled in for this project. Proceeding with standard iOS app best practices:
- ✅ Modular architecture (Core, Data, Presentation layers)
- ✅ Actor-based concurrency for thread safety
- ✅ Clear separation of concerns
- ✅ No test infrastructure as specified

## Project Structure

### Documentation (this feature)
```
specs/[###-feature]/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
Fonic HiFi/
├── Core/
│   └── Audio/
│       ├── Engine/
│       │   ├── AudioEngineFacade.swift
│       │   └── ProgressTimerManager.swift
│       ├── Engines/
│       │   ├── AVAudioEngineAdapter.swift
│       │   └── AudioKitEngineAdapter.swift
│       ├── Factory/
│       │   ├── AudioEngineFactory.swift
│       │   └── AudioEngineType.swift
│       ├── Coordinators/
│       │   ├── PlaybackCoordinator.swift
│       │   ├── QueueCoordinator.swift
│       │   └── StateCoordinator.swift
│       ├── Diagnostics/
│       │   ├── AudioMonitor.swift
│       │   ├── BitPerfectValidator.swift
│       │   └── DACCompatibilityInfo.swift
│       ├── Playback/
│       │   ├── PlaybackStateManager.swift
│       │   ├── PlaybackState.swift
│       │   └── PlaybackStateStore.swift
│       ├── Queue/
│       │   ├── AudioQueueManager.swift
│       │   ├── AudioQueue.swift
│       │   └── QueueState.swift
│       └── Services/
│           ├── AudioSessionManager.swift
│           ├── AudioFormatDetectionManager.swift
│           └── FormatDetectionService.swift
├── Data/
│   ├── Models/
│   │   ├── Track.swift
│   │   ├── Album.swift
│   │   ├── Artist.swift
│   │   └── Playlist.swift
│   ├── Actors/
│   │   ├── TrackDataActor.swift
│   │   └── RecentSearchesActor.swift
│   └── Services/
│       ├── LibraryImportService.swift
│       └── DataManager.swift
├── Presentation/
│   ├── Views/
│   │   ├── LibraryView.swift
│   │   ├── NowPlayingView.swift
│   │   ├── SearchView.swift
│   │   └── SettingsView.swift
│   └── Environments/
│       ├── AudioEnvironment.swift
│       └── NowPlayingEnvironment.swift
└── Utils/
    └── MainActorHelpers.swift
```

**Structure Decision**: iOS mobile application with established Core/Data/Presentation architecture. The improvements will modify existing files rather than creating new structure, focusing on fixing concurrency violations, adding missing relationships, and optimizing performance within the current architecture.

## Phase 0: Outline & Research
1. **Extract unknowns from Technical Context** above:
   - Swift 6 concurrency patterns for audio → researched
   - Memory management for engine switching → researched
   - Performance bottlenecks in SwiftData → researched
   - Error handling strategies → researched

2. **Research completed**:
   - Analyzed 10 AI agent reports from codebase guide
   - Examined current implementation patterns
   - Identified all concurrency violations
   - Documented performance bottlenecks

3. **Consolidate findings** in `research.md`:
   - ✅ Threading architecture defined (3-actor system)
   - ✅ Error handling strategy layered
   - ✅ Performance targets established
   - ✅ Monitoring approach lightweight

**Output**: research.md complete with all decisions documented

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - ✅ Track, Album, Artist, Playlist models defined
   - ✅ PlaybackState, QueueState, ImportSession defined
   - ✅ Cache models for performance
   - ✅ Validation rules specified

2. **Generate API contracts** from functional requirements:
   - ✅ AudioSessionManaging protocol
   - ✅ ImportSessionProtocol with transactions
   - ✅ PlaybackCoordinating interface
   - ✅ PerformanceMonitoring contract

3. **Contract structure** in `/contracts/`:
   - ✅ audio-session-contract.swift
   - ✅ import-session-contract.swift
   - ✅ playback-coordinator-contract.swift
   - ✅ monitoring-contract.swift

4. **Extract validation scenarios** from user stories:
   - ✅ 10 quickstart scenarios defined
   - ✅ Performance benchmarks specified
   - ✅ Sign-off checklist created

5. **Update agent file incrementally**:
   - ✅ Ran `.specify/scripts/bash/update-agent-context.sh kilocode`
   - ✅ Added Swift 6.2, SwiftUI, AVAudioEngine, AudioKit
   - ✅ Added SwiftData with ModelActor pattern
   - ✅ Updated .kilocode/rules/specify-rules.md

**Output**: ✅ data-model.md, ✅ /contracts/*, ✅ quickstart.md, ✅ kilocode config updated

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
- Load `.specify/templates/tasks-template.md` as base
- Generate tasks from Phase 1 design docs (contracts, data model, quickstart)
- Group by weekly priority from specification:
  - Week 1: Stability fixes (FR-001 to FR-006)
  - Week 2-3: Performance improvements (FR-007 to FR-014)
  - Week 4: Architecture & UX (FR-015 to FR-028)

**Task Categories**:
1. **Concurrency Fixes** (8-10 tasks)
   - Fix AudioSessionManager actor violations
   - Replace DispatchQueue with Task patterns
   - Add weak self to callbacks
   - Privatize Combine publishers

2. **Remote Commands** (4-5 tasks)
   - Enable commands in AudioEngineFacade
   - Implement command handlers
   - Add Now Playing updates
   - Test Control Center integration

3. **Data Relationships** (5-6 tasks)
   - Add @Relationship to Album
   - Add @Relationship to Artist
   - Implement computed properties
   - Fix relationship queries
   - Add migration logic

4. **Performance** (10-12 tasks)
   - Move I/O off MainActor
   - Implement pagination
   - Add caching layers
   - Batch timer updates
   - Optimize queue operations

5. **Error Handling** (6-8 tasks)
   - Replace fatal errors
   - Add error recovery
   - Implement user messages
   - Add fallback strategies

6. **Monitoring** (4-5 tasks)
   - Implement AudioMonitor
   - Add memory tracking
   - Create metrics collection
   - Add performance logging

**Ordering Strategy**:
- Priority order: Critical → High → Medium → Low
- Dependency order: Data models → Services → UI
- Mark [P] for parallel execution (independent files)
- No test tasks (per requirements)

**Estimated Output**: 40-50 numbered, ordered tasks in tasks.md

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)  
**Phase 4**: Implementation (execute tasks.md following constitutional principles)  
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |


## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [x] Phase 3: Tasks generated (/tasks command)
- [x] Phase 4: Implementation complete
- [x] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented (none required)

## Validation Evidence
*Completed: 2025-09-28*

**Implementation Status**:
- ✅ All 48 tasks from tasks.md completed
- ✅ Build verification: `make build` passes with iOS 26.0 target
- ✅ No `fatalError()` calls remaining in codebase
- ✅ Swift 6 strict concurrency compliance achieved
- ✅ All required new files created (10+ components)

**Key Deliverables Verified**:
- **Week 1 (T004-T015)**: Concurrency fixes with `Task { @MainActor in }` pattern, remote commands enabled, error handling improved
- **Week 2-3 (T016-T031)**: @Relationship macros added to all models, caching layers (TrackCache, SearchCache), async I/O operations
- **Week 4 (T032-T048)**: Architecture improvements, monitoring systems (PerformanceMonitor, AudioMonitor), UX enhancements

**Files Created Per Plan**:
- `Core/Audio/Cache/TrackCache.swift`
- `Data/Services/SearchCache.swift`
- `Data/Services/ImportSession.swift`
- `Core/Audio/Interfaces/AudioMetrics.swift`
- `Data/Services/ImportMetrics.swift`
- `Core/Audio/Diagnostics/PerformanceMonitor.swift`
- `Presentation/Views/Components/ErrorView.swift`

---
*Based on Constitution v2.1.1 - See `/memory/constitution.md`*
