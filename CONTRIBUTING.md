# Contributing to Fonic HiFi

Thanks for your interest in contributing! Fonic HiFi is a privacy-first, offline iOS music player. Contributions of all kinds are welcome: bug reports, fixes, tests, documentation, and features that fit the project's scope.

## Ground Rules

- **Privacy first.** Do not add cloud playback, streaming catalogs, remote metadata enrichment, telemetry, analytics, or anything that uploads library data, listening history, or user files. Changes in this area need explicit discussion in an issue before any code is written.
- **User data safety.** Never "fix" a persistence, migration, or import problem by deleting the user's store, bookmarks, or imported media.
- **Strict concurrency stays strict.** The project uses Swift 6 language mode with complete strict-concurrency checking. Do not bypass isolation with `nonisolated(unsafe)`, `@unchecked Sendable`, or detached tasks.
- **No `print()`.** Logging goes through `Log.logger(_:)` with appropriate OSLog privacy; never log raw paths, library metadata, or other user data.

## Requirements

- Xcode 27+ with an iOS 27 runtime and an iPhone 17 Pro simulator
- SwiftLint and SwiftFormat (installable via `make install-deps`)
- Python 3 (used by repository scripts)

Verify your environment before starting:

```bash
make check-deps
```

## Development Workflow

All lint, build, and test actions go through the Makefile; it is the repository's verification contract.

```bash
make help          # List all available targets
make open          # Open the project in Xcode
make build         # Unsigned Debug build for the iOS 27 simulator
make run           # Build, boot the simulator, install, and launch
```

### Linting and Formatting

```bash
make lint          # SwiftLint (must pass with 0 violations)
make format        # SwiftFormat auto-formatting
```

### Testing

Run the narrowest lane that covers your change first, then broaden as needed:

```bash
make test-focus ONLY="Fonic HiFiTests/SomeTests"           # A single test class
make test-focus ONLY="Fonic HiFiTests/SomeTests/testCase"  # A single test case
make test-unit     # Full unit + integration target
make test-ui       # UI smoke tests (mutates simulator state)
make test          # Full test plan
```

```bash
make coverage        # Fresh test run with coverage report
make coverage-check  # Enforce coverage thresholds
```

Build artifacts live under the ignored `build/` directory (`build/DerivedData`, `build/Results`). `make clean` deletes only repository-local artifacts.

### What to Validate Before Opening a PR

1. `make lint` passes with 0 violations.
2. The focused tests closest to your change pass (`make test-focus ONLY=...`); run `make test-unit` when you touch shared state, protocols, or multiple call sites.
3. `make build` succeeds if your change compiles new code paths.
4. For audio/playback changes, note which scenarios you verified on a simulator vs. real hardware. Simulator results do not prove hardware routing, interruptions, Bluetooth, USB DAC, or bit-perfect behavior; be explicit about what remains unverified.

## Project Structure

- `Fonic HiFi/Core/Audio/` — playback facade, engines, queue, session, DSP, diagnostics
- `Fonic HiFi/Core/AI/` — on-device recommendations and smart search
- `Fonic HiFi/Data/` — SwiftData models, schemas, actors, repositories, import
- `Fonic HiFi/Domain/` — entities, repository protocols, use cases
- `Fonic HiFi/Presentation/` — SwiftUI screens, view models, design tokens
- `Fonic HiFi Widget/` — WidgetKit extension
- `Fonic HiFiTests/`, `Fonic HiFiUITests/` — unit/integration and UI tests

The project uses Xcode file-system-synchronized groups: new files placed under a target's directory are picked up automatically. Do not edit `project.pbxproj` just to add a source file.

## Architecture Expectations

- Keep UI state and playback orchestration on the main actor; hop explicitly from callbacks, notifications, and timers.
- Keep SwiftData operations behind the existing model actor and repository boundaries; pass identifiers or `Sendable` values across actors.
- Views must not become independent authorities for playback, persistence, or networking.
- Every timer, observer, notification token, and audio tap needs an explicit owner and teardown path.
- Preserve cancellation and explicit error states in streams, imports, and task groups.

## Dependencies

AudioKit is the only third-party dependency, pinned in `Package.resolved`. Exhaust AudioKit and Apple frameworks before writing custom implementations. Adding or updating any package requires prior discussion in an issue.

## Commits and Pull Requests

1. Fork the repository and create a feature branch (`git checkout -b feature/amazing-feature`).
2. Keep each commit to one logical change, using [Conventional Commits](https://www.conventionalcommits.org/) with an imperative summary (e.g., `fix(audio): rebuild EQ chain after route change`).
3. Describe in the PR what you changed, how you validated it (commands and outcomes), and anything left unverified.
4. Do not include generated artifacts, result bundles, logs, or scratch files in the diff.

## Reporting Bugs

Use [GitHub Issues](https://github.com/keiranhaax/fonic-hifi/issues). Include your Xcode and iOS versions, device or simulator model, steps to reproduce, and relevant (redacted) log output. For security issues, see [SECURITY.md](SECURITY.md) instead of opening a public issue.
