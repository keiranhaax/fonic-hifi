# CI Workflow Update Spec

## Repository Analysis
- [Verified-Code] `tasks.md` lists the CI workflow work as pending; `.github/workflows/ci.yml` already exists and currently runs `brew update`, installs a short list of tools, then calls `make lint`, `make build`, and `make test`.
- [Verified-Code] The `Makefile` is the authoritative automation entry point; `make build` chains `make lint` and `make test`, but calling them explicitly in CI keeps log separation clear.
- [Inference] Aligning the workflow to call `make install-deps` (with `HOMEBREW_NO_AUTO_UPDATE=1`) better matches the documented tooling setup in README.md/CLAUDE.md; this is an alignment choice rather than correcting a violation.

## Implementation Plan
1. **Replace manual Homebrew installs**  
   - Swap the custom `brew install swiftlint swiftformat xcbeautify` step for `HOMEBREW_NO_AUTO_UPDATE=1 make install-deps` so runner dependencies mirror local expectations. [Inference]
2. **Retain explicit quality gates**  
   - Keep sequential `make lint`, `make build`, and `make test` steps for clear logs even though `make build` invokes the others. [Verified-Code]
3. **Maintain Xcode selection**  
   - Preserve the existing `sudo xcode-select -s /Applications/Xcode_16.1.app` unless testing shows the default toolchain already matches local builds. [Inference]

## Verification Strategy
- [Verified-Code] Run `make install-deps`, `make lint`, `make build`, and `make test` locally before committing.
- [Inference] After pushing, monitor the GitHub Action to ensure the updated workflow succeeds; adjust if the hosted runner needs additional permissions or tooling tweaks.
