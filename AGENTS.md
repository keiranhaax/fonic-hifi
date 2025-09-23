# Repository Guidelines

## Project Structure & Module Organization
Fonic HiFi’s SwiftUI target lives in `Fonic HiFi/`. `Core/Audio/` holds the engine facade, adapters, and playback state. Persistence actors, format models, and service boundaries are under `Data/`. UI environment values, view models, and views are organized in `Presentation/`. Shared helpers live in `Utils/`, while design assets remain in `Assets.xcassets`. Unit and integration tests mirror the runtime layout in `Fonic HiFiTests/`, with end-to-end UI flows in `Fonic HiFiUITests/`. Keep large reference documents or fixtures inside `Files/`.

## Build, Test, and Development Commands
- `xcodebuild -scheme "Fonic HiFi" -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' build` builds the simulator app with the latest toolchain.
- `xcodebuild test -scheme "Fonic HiFi" -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' -only-testing:"Fonic HiFiTests"` runs unit and integration suites.
- `xcodebuild test -scheme "Fonic HiFi" -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' -only-testing:"Fonic HiFiUITests"` exercises UI flows.
- `xcodebuild clean -scheme "Fonic HiFi"` resets derived data before reproducing release issues.
- `open "Fonic HiFi.xcodeproj"` launches the project in Xcode.

## Coding Style & Naming Conventions
Code is Swift 6 with two-space indentation and `// MARK:` boundaries. Prefer `final` classes, explicit access control, and `@MainActor` annotations for UI-facing types. Keep pure models `Sendable`, and name files after their primary type (`PlaybackStateManager.swift`). Opt for descriptive method names in verb form (`prepareEngine`, `handleRouteChange`). Use multiline doc comments for public facades and summarize intent in one sentence.

## Testing Guidelines
Tests use both Swift Testing (`@Test`) for async-heavy units and XCTest for integration. Name files with the module + feature + `Tests` suffix (`AudioEngineFacadeTests`). Ensure new audio flow code gains coverage in `Fonic HiFiTests/Integration/`; UI changes should add launch or screen regressions in `Fonic HiFiUITests`. Run the relevant `xcodebuild test` command before opening a PR and attach logs for flaky reproductions.

## Commit & Pull Request Guidelines
Follow the existing log: imperative, capitalized subject lines under 72 characters (e.g., “Fix NowPlaying crash”). Each commit should encapsulate a feature or fix plus tests. Pull requests must include: 1) a concise summary of user impact, 2) notes on audio format or concurrency risks, 3) proof of tests (`xcodebuild` output or screenshots), and 4) linked issues or task IDs. Request reviewers familiar with the touched area (audio engine vs. presentation) and document any simulator or hardware prerequisites.

## Security & Configuration Tips
Review `Fonic_HiFi.entitlements` when adding capabilities; the app currently ships without network permissions. Keep sample libraries local, avoid embedding licensed audio in git, and verify new background modes or file-access rights with manual regression passes on the iPhone 16 Pro simulator.
