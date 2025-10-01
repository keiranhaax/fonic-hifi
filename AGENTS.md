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

Test targets: `Fonic HiFiTests/` and `Fonic HiFiUITests/` (currently no tests configured). Large reference documents live in `Files/`.

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

**Complete command reference**: See [docs/MAKEFILE.md](docs/MAKEFILE.md)

## Testing Status

⚠️ **IMPORTANT**: No tests are currently configured.

- `make test`, `make test-unit`, `make test-ui` display "No tests configured"
- When adding tests: Use Swift Testing (`@Test`) for async code, XCTest for integration
- Name files with module + feature + `Tests` suffix (e.g., `AudioEngineFacadeTests`)

## Coding Standards

**Swift 6.2 with strict concurrency:**
- Two-space indentation, `// MARK:` section boundaries
- Prefer `final` classes, explicit access control
- `@MainActor` annotations for all UI-facing types
- Pure models MUST conform to `Sendable`
- File names match primary type (`PlaybackStateManager.swift`)
- Descriptive verb-form method names (`prepareEngine`, `handleRouteChange`)
- Multiline doc comments for public APIs

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

## Comprehensive Documentation

For detailed guidance, see:
- ** @CLAUDE.md** - Claude Code-specific instructions (364 lines)
- **docs/MAKEFILE.md** - Complete build command reference
- **docs/DEBUGGING.md** - Audio debugging patterns and AVAudioSession best practices
- ** @STATUS.md** - Current session state, branch recovery status, staged changes
