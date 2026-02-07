# Repository Guidelines

## Project Structure & Module Organization
`Fonic HiFi/` is the main iOS app target. Key modules:
- `Core/`: audio engine facade, playback/queue coordination, diagnostics, AI services.
- `Data/`: SwiftData models, actors, repositories, migrations, import/search services.
- `Presentation/`: SwiftUI views, view models, and environment wiring.
- `Utils/`: logging, privacy helpers, caches, shared utilities.
- `Assets.xcassets/`: app colors, icons, and artwork resources.

`Fonic HiFi Widget/` contains WidgetKit timelines, widget views, and shared widget models.  
`Fonic HiFiTests/` contains unit and integration tests; `Fonic HiFiUITests/` contains UI smoke tests.  
`scripts/coverage_summary.py` generates coverage summaries from `xccov` output.

## Build, Test, and Development Commands

**Build, Test, Run** (prefer MCP tools when available):
- Build: `BuildProject` (Xcode MCP) or `build_sim` (XcodeBuildMCP)
- Test: `RunAllTests` / `RunSomeTests` (Xcode MCP) or `test_sim` (XcodeBuildMCP)
- Run: `build_run_sim` (XcodeBuildMCP)
- Build errors: `GetBuildLog` (Xcode MCP, filter by severity)

**Lint, Format, Coverage** (make commands — no MCP equivalent):
- `make lint`: strict SwiftLint run.
- `make format`: apply SwiftFormat (`--swiftversion 6.2`).
- `make coverage` / `make coverage-check`: generate and enforce coverage thresholds.

**Setup** (make commands):
- `make check-deps`: verify required tools (`xcodebuild`, `swiftlint`, `swiftformat`, `xcbeautify`).
- `make install-deps`: install missing Homebrew dependencies.

## Coding Style & Naming Conventions
- Swift 6.2 and SwiftUI-first patterns are the default.
- Use SwiftFormat output as source of truth (4-space indentation, consistent wrapping).
- Follow SwiftLint rules in `.swiftlint.yml`; `print()` is disallowed (use `Utils/Logging/Log`).
- Keep type/file naming consistent: `FeatureView`, `FeatureViewModel`, `SomethingService`, `SomethingActor`.
- Prefer small, focused extensions (`Type+Capability.swift`) over large utility files.

## Testing Guidelines
- Both XCTest and Swift Testing are used (`XCTestCase` and `@Test`).
- Name test files with `*Tests.swift`; group integration coverage under `Fonic HiFiTests/Integration/`.
- Add or update tests for behavior changes before opening a PR.
- Run at minimum: `make lint && RunAllTests (Xcode MCP) && make coverage-check`.

## Commit & Pull Request Guidelines
- Follow Conventional Commit style seen in history: `feat(scope): ...`, `fix(scope): ...`, `test(scope): ...`, `docs: ...`.
- Keep commits scoped to one logical change and use imperative summaries.
- PRs should include: concise description, linked issue (if available), test evidence, and UI screenshots/video for visual changes.
