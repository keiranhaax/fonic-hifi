# Context Review
- [Verified-Code] `AGENTS.md` still claims no tests exist, yet `Fonic HiFiTests/` now contains extensive Swift Testing/XCTest coverage (e.g., `AudioEngineManagerTests.swift`, `LibraryImportServiceTests.swift`).
- [Verified-Code] Build command guidance references `docs/MAKEFILE.md`, which was superseded by the self-documenting `Makefile` and `docs/COMMANDS.md` (per STATUS.md and repo layout).
- [Verified-Code] `.swiftlint.yml` is present at the repo root; it should be cited as the authoritative lint/style config for agents.
- [Verified-Code] `STATUS.md` documents current project state and is the canonical status reference; AGENTS.md should explicitly direct agents to consult it.
- [Inference] User requested explicit instructions on invoking custom droids located under `.factory/droids` (e.g., `generated-droid` described in the developer prompt). External AGENTS.md best practices (Eric Ma, 2025) reinforce including tooling/test workflows so agents behave consistently.

# Proposed Changes
1. **Testing Guidance Refresh**
   - Replace the outdated “No tests configured” warning with instructions to run `make lint` and `make test`, noting existing Swift Testing suites and pointing to `docs/testing/` for expectations.
2. **Command Reference Update**
   - Amend the Essential Build Commands section to reference `make help` / `docs/COMMANDS.md` instead of the removed `docs/MAKEFILE.md`.
3. **Style Configuration Callout**
   - Add a directive (likely in Coding Standards) stating that `.swiftlint.yml` governs formatting/lint rules and should be followed before suggesting new conventions.
4. **STATUS.md Linkage**
   - Insert an explicit note highlighting `STATUS.md` as the current project status tracker, instructing agents to review it when assessing active work.
5. **Custom Droid Invocation Instructions**
   - Provide a short subsection describing how to run custom droids via the Task tool (`subagent_type`, `description`, `prompt`), referencing the available `generated-droid` and the `.factory/droids` directory.

# Implementation Plan
1. Edit `AGENTS.md` applying the five change areas above while preserving existing structure and tone.
2. Save changes, then run required checks (`make lint`, `make test`) to ensure compliance.
3. Summarize updates for the user and ask if they want the changes committed.

# Confirmation Needed
- Verify whether additional droid-related details (e.g., more droid names) should be included beyond `generated-droid`.
- Confirm no other documentation references require updates alongside AGENTS.md.