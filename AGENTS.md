# Fonic HiFi Agent Guide

Fonic HiFi is a privacy-first, offline iOS music player. Do not introduce cloud playback, streaming catalogs, remote metadata enrichment, telemetry, cloud inference, or uploads of library data, listening history, lyrics, prompts, or user files without explicit scope and privacy review.

Correct playback, user-data safety, and existing work take priority over speed or broad cleanup.

## Hard Stop Conditions

Stop and report the exact condition instead of working around it when:

- `Fonic HiFi.xcodeproj/project.pbxproj` or SwiftPM `Package.resolved` is missing or locally deleted. Do not restore, recreate, or substitute a sample project.
- A change would require modifying signing, entitlements, App Groups, bundle identifiers, privacy declarations, deployment targets, dependencies, StoreKit, or CloudKit behavior. These need explicit scope and review first.
- A persistence, migration, import, or playback problem could only be "fixed" by deleting the user store, library, bookmarks, or imported media. Never do this.
- A required tool (SwiftLint, SwiftFormat, an iOS 27 runtime) is missing. Report the affected check as `UNVERIFIED`; do not install or substitute tools.

## Canonical Task Loop

Every code task follows this shape. Deviate only when the request explicitly requires it.

1. Read this file and the nearest `AGENTS.md` for each target path (see Specialized Instructions).
2. Inspect `git status --short`, the current branch, the target files, nearby tests, call sites, and the nearest comparable implementation. Preserve all pre-existing changes.
3. Define the smallest behaviorally complete change and its proportionate verification (see Validation Policy).
4. Implement, extending established patterns; do not create parallel sources of truth.
5. Validate: `make lint`, then the narrowest test lane (`make test-focus ONLY=...`), then `make build` if the change compiles new code paths.
6. Clean up everything you created under `build/` (see Artifact Hygiene).
7. Review the full diff, run `git diff --check`, and report per Before Finishing.

## Scope and Sources of Truth

- Follow explicit user instructions over this file. The nearest applicable `AGENTS.md` or `AGENTS.override.md` governs files in its subtree.
- Tool availability is a capability, not permission to install software, alter Git state, upload data, or perform destructive work.
- Current source and `Fonic HiFi.xcodeproj/project.pbxproj` are authoritative for implementation and project settings. `Package.resolved` is authoritative for dependency pins.
- The `Makefile` defines local command behavior, destinations, artifacts, and side effects. Hosted CI is intentionally disabled while the project targets Xcode 27 beta; there is no active `.github/workflows/ci.yml`. Reintroducing CI requires explicit scope and runner/toolchain review.
- Treat plans, audits, generated reports, tracked logs, and agent-specific configuration as context only until confirmed against the current tree. Archived material under `Files/` is reference, not production code.
- Do not create ad-hoc root-level reports, audit summaries, backups, or scratch documents unless explicitly requested. Transient analysis stays in chat; approved durable plans go under `docs/plans/` and must be revalidated before reuse.

## Verified Project Facts and Map

- Baseline: iOS 27.0 deployment, Xcode 27-era APIs, Swift 6 language mode, complete strict-concurrency checking. Verify the selected host toolchain before making compiler-specific claims.
- Primary project: `Fonic HiFi.xcodeproj`; development scheme: `Fonic HiFi`.
- AudioKit is the only third-party dependency, pinned in `Package.resolved`. Exhaust AudioKit and Apple frameworks before writing custom implementations, and verify a capability against current documentation and types before assuming a framework lacks it. Do not update the pin incidentally; adding any package requires explicit approval.
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
- `Fonic HiFiTests/`: unit and integration tests (XCTest and Swift Testing). `Fonic HiFiUITests/`: UI smoke tests.

The project uses Xcode file-system-synchronized groups: files placed under synchronized target roots are discovered automatically. Do not edit `project.pbxproj` merely to add a source file; edit project configuration only for genuine target-membership, capability, build-setting, or package-linkage work. The nested `AGENTS.md` files are intentional documentation; do not add project membership for them. Do not create scratch or backup source files inside target directories.

General engineering conduct (simplicity, root causes, layered growth, elegance, evidence standards, subagent use) is defined by the global agent instructions on this machine; this file adds only what is specific to Fonic.

## Cross-Cutting Architecture

- Preserve strict concurrency. Do not bypass isolation with detached tasks, `nonisolated(unsafe)`, or `@unchecked Sendable`. A narrowly scoped exception requires a documented invariant and race-oriented tests.
- Keep UI state and playback orchestration on their established main-actor boundary. Hop explicitly from callbacks, notifications, timers, and remote commands before touching isolated state.
- Keep SwiftData operations behind the established model actor and repository boundaries; prefer identifiers or other `Sendable` values across actors.
- Views must not become independent authorities for playback, persistence, networking, or model-generated actions.
- Extend established composition, dependency injection, observation, and ownership patterns rather than creating parallel sources of truth.
- Preserve cancellation and explicit error states in streams, imports, task groups, search, and model generation. Do not continue mutating state after cancellation.
- Every repeating timer, observer, notification token, and audio tap has an explicit owner and teardown path; cancel view- or feature-owned work when its owner disappears.
- Recovery must be bounded: no retry loop without an attempt limit and a terminal, surfaced failure state.
- Keep app and widget copies of shared App Group keys and payload contracts wire-compatible until intentionally migrated.

## Privacy and Safety

- Follow `.swiftlint.yml` and the SwiftFormat behavior configured by the Makefile. Do not disable lint, compiler, test, or concurrency checks to make a change pass.
- `print()` is prohibited by lint. Route logs through `Log.logger(_:)`; never log raw paths, bookmarks, lyrics, prompts, transcripts, library metadata, user exports, secrets, credentials, or bearer-like identifiers. Use `LogPrivacy` and appropriate OSLog privacy.
- Treat `.claude/settings.local.json`, `.kilocode/mcp.json`, auth files, environment files, and local tool configuration as sensitive. Do not inspect values unnecessarily or copy them into source or documentation.
- Do not edit generated build products, result bundles, traces, caches, `xcuserdata`, tracked logs, or backup files as source.
- Do not leave placeholders, fake production implementations, commented-out code, or TODO-based fixes. Controlled doubles, generated media, and in-memory stores are valid in tests when they exercise the real contract.

## Build and Tool Policy

Tool precedence: for any lint, build, test, coverage, or run action, use the checked-in Makefile recipes; they are the repository's verification contract. Use MCP tools only for work the Makefile does not cover: XcodeBuildMCP for interactive simulator/device control, UI automation, debugging, and the native Xcode IDE bridge; XcodeMCP for active-Xcode project state and XCResult inspection. Confirm the configured project, scheme, and destination before acting, and inspect the live tool surface rather than assuming a function exists.

Apple's native Xcode MCP requires Xcode running with the Fonic project open and **Allow external agents to use Xcode tools** enabled under Xcode Settings > Intelligence. XcodeBuildMCP exposes it through the `xcode-ide` workflow; direct clients may use `xcrun mcpbridge`.

On Xcode 27, Device Hub replaces `Simulator.app` as the simulator UI host, but `xcrun simctl` remains the canonical CLI and is not deprecated; all Makefile simulator recipes and XcodeBuildMCP's simulator workflow work unchanged. If process recovery is needed, use `killall -9 DeviceHub` (not `killall -9 Simulator`). The absence of `Simulator.app` alone is not evidence of a broken installation.

| Goal | Command or policy | Important behavior |
| --- | --- | --- |
| Host toolchain | `xcode-select -p`, `xcodebuild -version`, `swift --version` | Read-only; run before host-version claims. |
| Dependencies | `make check-deps` | Requires Xcode 27, an iOS 27 runtime and iPhone 17 Pro simulator, Python, SwiftLint, and SwiftFormat. |
| Lint | `make lint` | Requires SwiftLint; do not install it automatically. |
| Focused tests | `make test-focus ONLY="Fonic HiFiTests/SomeTests[/testCase]"` | Runs only the named test class or case; the preferred first lane for scoped changes. |
| Unit tests | `make test-unit` | Runs the full app unit/integration target and writes artifacts. |
| UI tests | `make test-ui` | Runs the UI target and mutates simulator/build state. |
| Full tests | `make test` | Recreates `build/Results/TestResults.xcresult`. |
| Debug build | `make build` | Compile-only unsigned simulator build; lint and tests remain explicit. |
| Release/analyze | `make build-release`, `make analyze` | CI-level checks for substantial or release-sensitive work. |
| Coverage | `make coverage-check` | Always runs the full test plan before enforcing thresholds. |
| Run | `make run` | Builds, boots, installs, and launches; mutates simulator state. |

For domain-specific iOS guidance, prefer the Axiom skill plugin: versioned to iOS/Xcode 27, covering audio (`axiom-media`), SwiftData (`axiom-data`), concurrency (`axiom-concurrency`), Foundation Models (`axiom-ai`), App Intents (`axiom-integration`), accessibility, testing, performance, and build debugging with Device Hub awareness. The `build-ios-apps` plugin supplements it for ETTrace profiling, memgraph leak detection, and simulator browser mirroring, but targets the iOS 26 era.

Read a Make recipe before using it. `make install-deps` downloads Homebrew tools, `make clean` deletes the ignored `build/` directory, and `make format` rewrites the repository; use these only with explicit approval or clearly established need, after checking the worktree. xcbeautify is optional (the Makefile falls back to `cat`).

Never run builds or tests concurrently against the same DerivedData, `build/`, or result-bundle path. Use isolated paths when parallel execution is required.

## Build Artifact Hygiene (Mandatory Cleanup)

Stray agent artifacts have grown `build/` past 25 GB. Everything under `build/` is ignored and regenerable:

- Reuse the Makefile's canonical paths (`build/DerivedData`, `build/Results`). Create a separate task-named path under `build/` only when parallel runs require isolation, and delete it in the same session.
- Extract findings from an `.xcresult` bundle into your report, then delete it. Keep at most the most recent bundle per test lane.
- Never persist evidence, audit, or screenshot archives under `build/`; summarize in chat or `docs/` instead.
- Before finishing any session that built or tested, delete the DerivedData, result bundles, and attachments you created. This cleanup is pre-authorized inside `build/` only; it never extends to `git clean`, simulators, or anything outside `build/`.
- Exception: parallel testing clones simulators into `~/Library/Developer/XCTestDevices`, and interrupted runs orphan them (~9 GB each). After UI or parallel test runs, run `xcrun simctl --set testing delete all`. This is pre-authorized; it deletes only disposable test clones, never regular simulators.

## Validation Policy

Run the narrowest meaningful check first and broaden only in proportion to risk. Escalate in order: focused tests (`make test-focus ONLY=...`) → affected target (`make test-unit` or `make test-ui`) → full plan (`make test`). Reserve `make test`, `make test-ui`, and `make coverage-check` for cross-cutting changes, shared-contract migrations, or release-sensitive work; they are not per-edit validation.

| Change | Minimum validation |
| --- | --- |
| Copy, localization strings, design tokens, or comment-only edits | Build the owning target; no test run unless behavior changed. |
| Documentation or instructions | Validate every referenced path, command, and configuration claim; run `git diff --check`. |
| Pure logic or state | Run the closest focused tests; broaden to the full unit target only when shared state, protocols, or multiple call sites are touched. |
| SwiftUI | Build the owning target and perform relevant visual/accessibility QA when tools permit. |
| Audio or playback | Run relevant focused tests, build the app, and exercise the required runtime or device scenario. |
| SwiftData or import | Run data tests and the applicable migration, import, cancellation, or recovery scenario. |
| Foundation Models | Test fallback, malformed output, bounds, deduplication, and cancellation; validate eligible-device behavior when claimed. |
| Widget or App Intent | Build the app and extension as applicable; check shared-state compatibility and degraded states. |
| Project, dependency, entitlement, capability, or release | Use a fresh isolated build, relevant tests, and capability/privacy review. |

Simulator-only results do not prove hardware routing, interruptions, background audio, Bluetooth, AirPlay, USB DAC, high-resolution output, bit-perfect playback, or Apple Intelligence eligibility. Do not claim "fixed," "green," "gapless," "bit-perfect," or "release-ready" from static inspection alone.

## Learning Capture (Codex agents only; others skip this section)

- Never create `tasks/` files or other root-level scratch, progress, or lessons files in this repository.
- Route tracking by lifetime: transient checklists stay in the session todo list, approved durable plans go under `docs/plans/`, and durable lessons go to Codex memories under `~/.codex/memories`, never into this repo.
- Capture a lesson only when a real durable learning emerges from an issue, or when asked:
  - Reusable procedure or guardrail: add `~/.codex/memories/skills/fonic-<topic>/SKILL.md` with the existing frontmatter (`name`, `description`, `disable-model-invocation`, `user-invocable`, `allowed-tools`) and `When to use` / `Procedure` / `Pitfalls` / verification sections, mirroring `skills/fonic-scoped-audit-remediation/SKILL.md`.
  - Dated correction, gotcha, or decision: append to `~/.codex/memories/memory_summary.md` under `### /Users/widismini/Documents/Fonic-HiFi` → `#### <date>`, matching the existing `- Title: \`tags\``, `desc`, `learnings` entry format.
- Never dump per-task todos or transient analysis into memories; durable memory stays lean.

## Subagent Orchestration (Codex agents only; others skip this section)

When splitting work across subagents, the parent session only plans, delegates, reviews, and integrates; it delegates implementation to `luna_worker` and independent review to `luna_reviewer`.

- Each delegation is one bounded task stating goal, acceptance criteria, exclusive authorized paths disjoint from every concurrent worker, exclusions, build-lane grant, and required verification.
- Parallelize read-only work freely and reuse freed slots as a queue; write work needs disjoint ownership or runs serially. One agent at a time holds the canonical `build/` lane; parallel validation uses isolated paths per Artifact Hygiene.
- Review each substantive change via `luna_reviewer` on the handoff and criteria alone, never the worker's conversation; BLOCKER findings return to a worker as new corrective assignments.
- Dispatch no more concurrent work than the orchestrator can verify; worker PASS claims are inputs, not conclusions. The orchestrator owns integration, Validation Policy escalation, and the Before Finishing report.

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
