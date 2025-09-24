# Repository Guidelines

## Project Structure & Module Organization
Fonic HiFi’s SwiftUI target lives in `Fonic HiFi/`. `Core/Audio/` holds the engine facade, adapters, and playback state. Persistence actors, format models, and service boundaries are under `Data/`. UI environment values, view models, and views are organized in `Presentation/`. Shared helpers live in `Utils/`, while design assets remain in `Assets.xcassets`. Unit and integration tests mirror the runtime layout in `Fonic HiFiTests/`, with end-to-end UI flows in `Fonic HiFiUITests/`. Keep large reference documents or fixtures inside `Files/`.

## Build, Test, and Development Commands
- `make build` builds the simulator app with the latest toolchain (Debug configuration for iPhone 16 Pro, iOS 26.0).
- `make test-unit` runs unit and integration suites.
- `make test-ui` exercises UI flows.
- `make clean` resets derived data before reproducing release issues.
- `make open` launches the project in Xcode.
- `make run` builds and runs the app in the simulator.
- `make lint` runs SwiftLint for code quality checks.
- `make format` auto-formats code with SwiftFormat.

## Coding Style & Naming Conventions
Code is Swift 6 with two-space indentation and `// MARK:` boundaries. Prefer `final` classes, explicit access control, and `@MainActor` annotations for UI-facing types. Keep pure models `Sendable`, and name files after their primary type (`PlaybackStateManager.swift`). Opt for descriptive method names in verb form (`prepareEngine`, `handleRouteChange`). Use multiline doc comments for public facades and summarize intent in one sentence.

## Testing Guidelines
Tests use both Swift Testing (`@Test`) for async-heavy units and XCTest for integration. Name files with the module + feature + `Tests` suffix (`AudioEngineFacadeTests`). Ensure new audio flow code gains coverage in `Fonic HiFiTests/Integration/`; UI changes should add launch or screen regressions in `Fonic HiFiUITests`. Run `make test` (or `make test-unit` for faster feedback) before opening a PR and attach logs for flaky reproductions. Use `make coverage` to generate test coverage reports.

## Commit & Pull Request Guidelines
Follow the existing log: imperative, capitalized subject lines under 72 characters (e.g., "Fix NowPlaying crash"). Each commit should encapsulate a feature or fix plus tests. Pull requests must include: 1) a concise summary of user impact, 2) notes on audio format or concurrency risks, 3) proof of tests (output from `make test` or `make test-unit`, or screenshots), and 4) linked issues or task IDs. Request reviewers familiar with the touched area (audio engine vs. presentation) and document any simulator or hardware prerequisites. Use `make pr-create` to create pull requests via GitHub CLI.

## Security & Configuration Tips
Review `Fonic_HiFi.entitlements` when adding capabilities; the app currently ships without network permissions. Keep sample libraries local, avoid embedding licensed audio in git, and verify new background modes or file-access rights with manual regression passes on the iPhone 16 Pro simulator.
