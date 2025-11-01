# Repository Guidelines for AI Coding Agents

## Project Context

Fonic HiFi is a high-fidelity iOS 26.0+ audiophile music player with bit-perfect playback.

**Key Technologies:**
- **Platform**: iOS 26.0 minimum (NO backwards compatibility), Swift 6.2, Xcode 26
- **Audio**: AVAudioEngine + AudioKit dual-engine facade pattern
- **Concurrency**: Swift 6 strict concurrency with actor isolation
- **Data**: SwiftData with actor-based persistence (TrackDataActor)
- **UI**: SwiftUI with custom Liquid Glass effects

## Project Structure

`Fonic HiFi/` contains the main SwiftUI target with these modules:
- **Core/Audio/** - Engine facade, AVAudioEngine/AudioKit adapters, playback state
- **Data/** - SwiftData persistence actors, format models, service boundaries
- **Domain/** - Repository pattern, use cases, business entities
- **Presentation/** - ViewModels, views, environment values
- **Utils/** - Shared helpers and extensions
- **Assets.xcassets** - Design system and visual assets

Test targets: `Fonic HiFiTests/` (active Swift Testing & XCTest suites) and `Fonic HiFiUITests/` (UI automation scaffolding). Large reference documents live in `Files/`.

## Architecture Overview

**Audio Engine Facade Pattern:**
- `AudioEngineFacade` coordinates AVAudioEngine and AudioKit adapters
- Format detection determines optimal engine per track
- Bit-perfect playback maintained when possible

**Concurrency Model (Swift 6.2):**
- `@MainActor`: All UI components, ViewModels, AudioEngineFacade
- `TrackDataActor`: SwiftData operations, file I/O isolation (Data/Actors/TrackDataActor.swift:13)
- Cross-actor types MUST conform to `Sendable`
- Audio callbacks dispatch to MainActor via `Task { @MainActor in ... }`

**State Management:**
- `PlaybackStateManager`: Single source of truth for playback state
- Immutable state snapshots published to observers

## Essential Build Commands

```bash
make build         # Build for iPhone 16 Pro simulator (iOS 26.0)
make run           # Build and run in simulator
make clean         # Reset derived data
make lint          # SwiftLint code quality checks (ALWAYS run after changes)
make format        # SwiftFormat auto-formatting
make open          # Launch project in Xcode
```

**Complete command reference**: Run `make help` or see [docs/COMMANDS.md](docs/COMMANDS.md)

## Testing Status

✅ **Swift Testing & XCTest suites are active.**

- Run `make lint` and `make test` after code changes (see `docs/COMMANDS.md` for variants).
- Tests live in `Fonic HiFiTests/` (145+ cases covering audio engines, diagnostics, data, and UI models).
- Follow Swift Testing (`@Test`) for async/unit coverage and XCTest for integration; name files `<Module><Feature>Tests.swift`.
- Review `docs/testing/` for coverage expectations and recent reports.

## Coding Standards

**Swift 6.2 with strict concurrency:**
- Two-space indentation, `// MARK:` section boundaries
- Prefer `final` classes, explicit access control
- `@MainActor` annotations for all UI-facing types
- Pure models MUST conform to `Sendable`
- File names match primary type (`PlaybackStateManager.swift`)
- Descriptive verb-form method names (`prepareEngine`, `handleRouteChange`)
- Multiline doc comments for public APIs
- `.swiftlint.yml` defines lint/style expectations—consult it before proposing new conventions or overrides.

### Observability & Logging

- Use `Log.logger(_:)` with the predefined taxonomy in `Utils/Logging/Log.swift`; avoid ad-hoc category strings.[Verified-Code]
- Apply `LogPrivacy.filename(_:)` and `LogPrivacy.truncated(_:limit:)` when logging user-sourced paths or long strings.[Verified-Code]
- Optional counters live in `Utils/Logging/Metrics.swift`; call `Metrics.enable(true)` only in debug/testing contexts before using `Metrics.increment`.[Verified-Code]
- Reference `docs/refactor/observability-walkthrough.md` for the end-to-end instrumentation guide.

## Commit & Pull Request Guidelines

**Commit Style:**
- Imperative, capitalized subject lines under 72 characters
- Example: "Fix NowPlaying crash", "Add gapless playback support"
- Each commit encapsulates a complete feature or fix

**Pull Requests:**
1. Concise summary of user impact
2. Notes on audio format or concurrency risks
3. Proof of testing (build output, manual verification screenshots)
4. Linked issues or task IDs
5. Request reviewers familiar with touched area (audio vs. presentation)
6. Document simulator/hardware prerequisites

Use `make pr-create` for GitHub CLI pull request creation.

## Security & Configuration

- Review `Fonic_HiFi.entitlements` when adding capabilities
- App ships without network permissions (privacy-first design)
- Keep sample libraries local, avoid embedding licensed audio in git
- Verify new background modes or file-access rights with manual regression on iPhone 16 Pro simulator

## Project Status & AI Tools

- `STATUS.md` tracks the current project status, active phases, verification history, and next steps—review it before making scope assumptions.
- Custom droids live under `.factory/droids/`; invoke them via the Task tool, e.g.:
  ```json
  { "subagent_type": "generated-droid", "description": "Analyze diagnostics architecture", "prompt": "Summarize open Phase 2A follow-ups" }
  ```
  Adjust `subagent_type`, `description`, and `prompt` per task requirements.

## Comprehensive Documentation

For detailed guidance, see:
- ** @CLAUDE.md** - Claude Code-specific instructions (364 lines)
- **docs/COMMANDS.md** - Build command reference and workflow patterns
- **docs/DEBUGGING.md** - Audio debugging patterns and AVAudioSession best practices
- ** @STATUS.md** - Current session state, branch recovery status, staged changes
