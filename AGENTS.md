# Fonic HiFi Agent Guide

Fonic HiFi is a privacy-first, offline iOS music player. Do not introduce cloud playback, streaming catalogs, remote metadata enrichment, telemetry, cloud inference, or uploads of library data, listening history, lyrics, prompts, or user files without explicit scope and privacy review.

Correct playback, user-data safety, and existing work take priority over speed or broad cleanup.

## Scope and Sources of Truth

- Follow explicit user instructions over this file. The nearest applicable `AGENTS.md` or `AGENTS.override.md` governs files in its subtree.
- Tool availability is a capability, not permission to install software, alter Git state, upload data, or perform destructive work.
- Current source and `Fonic HiFi.xcodeproj/project.pbxproj` are authoritative for implementation and project settings. SwiftPM `Package.resolved` is authoritative for dependency pins.
- The `Makefile` defines local command behavior, destinations, artifacts, and side effects. Hosted CI is intentionally disabled while the project targets Xcode 27 beta; there is no active `.github/workflows/ci.yml`. Reintroducing CI requires explicit scope and runner/toolchain review.
- Treat plans, audits, archived files, generated reports, tracked logs, and agent-specific configuration as context only until confirmed against the current tree.
- If `Fonic HiFi.xcodeproj/project.pbxproj` or its SwiftPM `Package.resolved` is missing or locally deleted, stop and report the exact path. Do not restore it, recreate it, or build a sample project instead.
- `sample/` and archived material under `Files/` are references, not production code.

## Verified Project Facts and Map

- Project baseline: iOS 27.0 deployment, Xcode 27-era APIs, Swift 6 language mode, and complete strict-concurrency checking. Verify the selected host toolchain before making compiler-specific claims.
- Primary project: `Fonic HiFi.xcodeproj`; development scheme: `Fonic HiFi`.
- AudioKit is the third-party audio dependency and is pinned in `Package.resolved`; do not update it incidentally.
- `Fonic HiFi/`: main app.
  - `Core/Audio/`: playback facade, engines, queue, session, DSP, and diagnostics.
  - `Core/AI/`: on-device recommendations and smart search.
  - `Core/Intents/` and `Core/Services/`: App Intents and app services.
  - `Data/`: SwiftData models, schemas, actors, repositories, import, and search.
  - `Domain/`: entities, repository protocols, and use cases.
  - `Presentation/`: SwiftUI environment, state, screens, tokens, and reusable views.
  - `Shared/`: app-side widget contracts and App Group constants.
  - `Utils/`: logging, privacy, metrics, caches, and helpers.
- `Fonic HiFi Widget/`: WidgetKit extension and widget-side shared contracts.
- `Fonic HiFiTests/`: unit and integration tests using XCTest and Swift Testing.
- `Fonic HiFiUITests/`: UI smoke tests.

The project uses Xcode file-system-synchronized groups. Files placed under synchronized target roots are normally discovered automatically. The nested `AGENTS.md` files are intentional documentation; do not add explicit project membership for them. Do not create scratch or backup source files inside target directories, and do not edit `project.pbxproj` merely to add a source file. Edit project configuration only for genuine target membership, capability, build-setting, or package-linkage work.

## Before Editing

1. Read this file and every closer instruction file for the target paths.
2. Inspect `git status --short`, the current branch, target files, nearby tests, call sites, protocols, models, and duplicated contracts.
3. Identify the owning target and the nearest comparable implementation before introducing a pattern.
4. Check project settings, package pins, relevant Make recipes, tool availability, and the live destination before stating command or toolchain behavior as fact.
5. Identify pre-existing changes and preserve them. Never discard, overwrite, reformat, stage, or clean up unrelated work.
6. Define the smallest behaviorally complete change and its proportionate verification.

Proactively perform safe, non-destructive inspection and in-scope validation without repeatedly asking for confirmation. Ask before destructive actions, external writes, credential or system changes, dependency installation, or material scope expansion.

Do not create ad-hoc root-level reports, audit summaries, backup files, or scratch documents unless explicitly requested. Keep transient analysis in chat; put approved durable plans under `docs/plans/` and revalidate them before reuse.

## Cross-Cutting Architecture

- Preserve strict concurrency. Do not bypass isolation with detached tasks, `nonisolated(unsafe)`, or `@unchecked Sendable`. A narrowly scoped exception requires a documented invariant and race-oriented tests.
- Keep UI state and playback orchestration on their established main-actor boundary. Hop explicitly from callbacks, notifications, timers, and remote commands before touching isolated state.
- Keep SwiftData operations behind the established model actor and repository boundaries; prefer identifiers or other `Sendable` values across actors.
- Views must not become independent authorities for playback, persistence, networking, or model-generated actions.
- Extend established composition, dependency injection, observation, and ownership patterns rather than creating parallel sources of truth.
- Preserve cancellation and explicit error states in streams, imports, task groups, search, and model generation. Do not continue mutating state after cancellation.
- Keep app and widget copies of shared App Group keys and payload contracts wire-compatible until intentionally migrated.

## Scope, Privacy, and Safety

- Never recover from a persistence, migration, import, or playback problem by deleting the user store, library, bookmarks, or imported media.
- Do not change signing, team settings, certificates, provisioning, bundle identifiers, entitlements, App Groups, background modes, privacy declarations, deployment targets, dependencies, CI images, product IDs, StoreKit configuration, or CloudKit behavior without explicit scope and review.
- Do not add a production dependency or install development tools without explicit approval.
- Follow `.swiftlint.yml` and the SwiftFormat behavior configured by the Makefile. Do not disable lint, compiler, test, or concurrency checks to make a change pass.
- `print()` is prohibited by lint. Route logs through `Log.logger(_:)`; never log raw paths, bookmarks, lyrics, prompts, transcripts, library metadata, user exports, secrets, credentials, or bearer-like identifiers. Use `LogPrivacy` and appropriate OSLog privacy.
- Treat `.claude/settings.local.json`, `.kilocode/mcp.json`, auth files, environment files, and local tool configuration as sensitive. Do not inspect values unnecessarily or copy them into source or documentation.
- Do not edit generated build products, result bundles, traces, caches, `xcuserdata`, tracked logs, or backup files as source.
- Do not leave placeholders, fake production implementations, commented-out code, or TODO-based fixes. Controlled doubles, generated media, and in-memory stores are valid in tests when they exercise the real contract.

## Build and Tool Policy

Use the checked-in Makefile for the repository's exact lint, build, test, coverage, artifact, and cleanup contract. For interactive agent work, `.factory/mcp.json` configures complementary project-scoped tools: XcodeBuildMCP owns headless build, test, simulator/device, UI automation, debugging, coverage, and the native Xcode IDE bridge; XcodeMCP owns active-Xcode project state and XCResult inspection. Confirm the configured main project, scheme, and intended destination before acting, and inspect the live tool surface rather than assuming a function exists.

Apple's native Xcode MCP requires Xcode to be running with the Fonic project open and **Allow external agents to use Xcode tools** enabled under Xcode Settings > Intelligence. XcodeBuildMCP exposes it through the `xcode-ide` workflow; direct clients may use `xcrun mcpbridge`.

Verify the selected Xcode's current simulator tooling. On newer releases, Device Hub may replace legacy Simulator components; their absence alone is not evidence of a broken installation.

| Goal | Command or policy | Important behavior |
| --- | --- | --- |
| Host toolchain | `xcode-select -p`, `xcodebuild -version`, `swift --version` | Read-only; run before host-version claims. |
| Dependencies | `make check-deps` | Requires Xcode 27, an iOS 27 runtime and iPhone 17 Pro simulator, Python, SwiftLint, and SwiftFormat. |
| Lint | `make lint` | Requires SwiftLint; do not install it automatically. |
| Unit tests | `make test-unit` | Runs the full app unit/integration target and writes artifacts. |
| UI tests | `make test-ui` | Runs the UI target and mutates simulator/build state. |
| Full tests | `make test` | Recreates `build/Results/TestResults.xcresult`. |
| Debug build | `make build` | Compile-only unsigned simulator build; lint and tests remain explicit. |
| Release/analyze | `make build-release`, `make analyze` | CI-level checks for substantial or release-sensitive work. |
| Coverage | `make coverage-check` | Always runs the full test plan before enforcing thresholds. |
| Run | `make run` | Builds, boots, installs, and launches; mutates simulator state. |

Read a Make recipe before using it. `make install-deps` downloads the repository's Homebrew development tools, `make clean` deletes only the ignored repository-local `build/`, and `make format` rewrites the repository; use them only with explicit approval or clearly established need and after checking the worktree.

xcbeautify is optional because the Makefile falls back to `cat`. SwiftLint and SwiftFormat are required by `make check-deps`; missing required tools make affected checks `UNVERIFIED`, not permission to install or substitute them.

Never run builds or tests concurrently against the same DerivedData, `build/` directory, or result-bundle path. Use isolated paths when parallel execution is required.

## Validation Policy

Run the narrowest meaningful check first and broaden only in proportion to risk.

| Change | Minimum validation |
| --- | --- |
| Documentation or instructions | Validate every referenced path, command, and configuration claim; run `git diff --check`. |
| Pure logic or state | Run the closest focused tests, then the affected test target when warranted. |
| SwiftUI | Build the owning target and perform relevant visual/accessibility QA when tools permit. |
| Audio or playback | Run relevant focused tests, build the app, and exercise the required runtime or device scenario. |
| SwiftData or import | Run data tests and the applicable migration, import, cancellation, or recovery scenario. |
| Foundation Models | Test fallback, malformed output, bounds, deduplication, and cancellation; validate eligible-device behavior when claimed. |
| Widget or App Intent | Build the app and extension as applicable; check shared-state compatibility and degraded states. |
| Project, dependency, entitlement, capability, or release | Use a fresh isolated build, relevant tests, and capability/privacy review. |

Simulator-only results do not prove hardware routing, interruptions, background audio, Bluetooth, AirPlay, USB DAC, high-resolution output, bit-perfect playback, or Apple Intelligence eligibility. Do not claim “fixed,” “green,” “gapless,” “bit-perfect,” or “release-ready” from static inspection alone.

## Specialized Instructions

- `Fonic HiFi/Core/Audio/AGENTS.md`: playback ownership, audio sessions, routes, DSP, and hardware evidence.
- `Fonic HiFi/Core/AI/AGENTS.md`: Foundation Models trust boundaries, fallback, and validation.
- `Fonic HiFi/Core/Intents/AGENTS.md`: App Intent contracts, routing, and unavailable-service behavior.
- `Fonic HiFi/Data/AGENTS.md`: SwiftData, migrations, imports, user data, and CloudKit boundaries.
- `Fonic HiFi/Presentation/AGENTS.md`: SwiftUI ownership, design system, accessibility, and visual QA.
- `Fonic HiFi Widget/AGENTS.md`: WidgetKit, App Group payloads, timelines, and degraded states.
- `Fonic HiFiTests/AGENTS.md`: unit/integration test conventions and fixtures.
- `Fonic HiFiUITests/AGENTS.md`: UI harness, launch state, identifiers, and simulator QA.

## Before Finishing

1. Re-read the request and review the complete diff for scope, regressions, accidental formatting, secrets, absolute home paths, library metadata, and personal data.
2. Run `git diff --check` and the validation required above and by any nested guide.
3. Report changed files, behavior, commands and outcomes, `UNVERIFIED` checks with exact reasons, remaining risks, and manual device scenarios.

Never stage, commit, create or switch branches, restore, reset, clean, push, open a PR, rewrite history, or publish a release unless explicitly requested. If a commit is requested, use the repository's Conventional Commit style with one logical change and an imperative summary.
