# Makefile Command Reference

**MANDATORY**: Always use Makefile commands for consistency and efficiency.

## Quick Command Reference

**Most Used Commands:**
- `make build` - Build the app (Debug)
- `make build-verify` - Comprehensive build verification with full output
- `make build-check` - Quick build check (exit code only)
- `make error-report` - Generate detailed error report
- `make run` - Build and run in simulator
- `make test` - Shows message about no tests configured
- `make lint` - Check code quality
- `make format` - Auto-format code
- `make clean` - Clean build artifacts
- `make search PATTERN='text'` - Fast code search
- `make profile-cpu` - CPU profiling
- `make profile-memory` - Memory profiling
- `make memory-leaks` - Check for leaks
- `make logs-stream` - Stream live logs

## Build Verification Best Practices

### DO:
- Use `make build-check` for quick verification (shows only pass/fail)
- Use `make build-verify` for comprehensive analysis with full output
- Use `make error-report` for detailed error extraction when debugging
- Always check exit codes: `make build; echo $?` (0 = success)
- Review full output when debugging build issues

### DON'T:
- Use `tail` or `head` on build output (loses critical information)
- Rely only on final output messages from formatters
- Ignore exit codes when verifying builds
- Trust "Build Succeeded" without checking actual exit status

### ⚠️ CRITICAL: Compiler Working Tree Behavior

**Key Insight from Branch Recovery [Verified-Code]:**
- **Compiler compiles from working tree, NOT from HEAD commit**
- Staged but uncommitted changes ARE visible to the compiler
- Build can succeed with staged changes even though they're not committed
- This is NORMAL xcodebuild/swiftc behavior, not a bug

**Implications:**
```bash
# Scenario: File has ReplayGainMode enum staged but not committed
git status
# M  "Fonic HiFi/Core/Audio/Interfaces/AudioEngineConfiguration.swift"

make build
# ✅ Build Succeeded (compiler sees staged changes)

git diff --cached AudioEngineConfiguration.swift | grep "ReplayGainMode"
# +public enum ReplayGainMode: String, CaseIterable, Sendable {
# (Staged but not in HEAD)

git show HEAD:AudioEngineConfiguration.swift | grep "ReplayGainMode"
# (No matches - not in committed history)
```

**Best Practice:**
1. ✅ Build success with staged changes is EXPECTED
2. ⚠️ Always commit staged changes after verification to avoid confusion
3. 📝 Document staged changes in STATUS.md if recovery spans multiple sessions
4. 🔄 Never rely on uncommitted changes for long-term branch stability

### Verification Commands:
```bash
# Quick check - exit code only
make build-check

# Full verification - complete output capture
make build-verify

# Detailed error extraction
make error-report

# Manual verification
make build; echo "Exit code: $?"
```

### Troubleshooting Build Failures:
1. Run `make build-verify` for full output
2. Check `build_verify.log` for complete details
3. Use `make error-report` to extract all errors/warnings
4. Review `build_errors.log` for filtered issues

## Primary Build Commands

```bash
# Build for Debug (iPhone 16 Pro Simulator, iOS 26)
make build

# Build for Release
make build-release

# Build and run in simulator
make run

# Clean build artifacts and derived data
make clean

# Open project in Xcode
make open
```

## Testing Commands

```bash
# Test commands (no tests configured)
make test         # Shows no tests message
make test-unit    # Shows no unit tests message
make test-ui      # Shows no UI tests message
make coverage     # Shows no coverage message
```

## Code Quality Commands

```bash
# Run SwiftLint (ALWAYS run after code changes)
make lint

# Auto-format code with SwiftFormat
make format

# Run static analysis
make analyze
```

## Search & Navigation (ripgrep, fd, fzf)

```bash
# Fast code search
make search PATTERN='your search term'

# Find files by pattern
make find-files PATTERN='*.swift'

# Find all TODO/FIXME comments
make find-todos

# Find all ViewModels
make find-viewmodels

# Find AudioKit/audio references
make find-audio

# Find Core module references
make find-core

# Interactive file finder with preview
make find-interactive

# Interactive code search
make search-interactive
```

## Code Analysis (tokei, eza, bat)

```bash
# Show code statistics
make stats

# Statistics per feature module
make stats-features

# Visual project structure
make tree

# View file with syntax highlighting
make view FILE=path/to/file.swift
```

## Performance Benchmarking (hyperfine)

```bash
# Benchmark build performance
make benchmark-build

# Benchmark test execution
make benchmark-test

# Full performance analysis
make benchmark-all
```

## Simulator Management

```bash
# Boot iPhone 16 Pro simulator
make simulator-boot

# Shutdown all simulators
make simulator-shutdown

# List available simulators
make simulator-list
```

## Dependency Management

```bash
# Check if required tools are installed
make check-deps

# Install missing dependencies via Homebrew
make install-deps
```

## AI Assistance (Optional - requires mods/llm)

```bash
# Explain code with AI
make ai-explain FILE=path/to/file.swift

# Generate tests with AI
make ai-test-generate FILE=path/to/file.swift

# AI code review of staged changes
make ai-review

# Generate commit message with AI
make ai-commit
```

## Git & GitHub Integration

```bash
# Create pull request
make pr-create

# List GitHub issues
make issues

# Colored git diff
make diff
```

## Makefile Automation Features

### File Watching & Auto-Tasks
```bash
# Auto-lint on file changes
make watch-lint

# Auto-build on changes
make watch-build

# Auto-test on changes
make watch-test
```

### Advanced Workflows
```bash
# Full build cycle (without tests)
make all  # Runs: clean → lint → build

# Parse last build for errors
make parse-errors
```

### Project Navigation Tips
- Use `make find-interactive` for exploring the codebase with live preview
- Use `make search-interactive` for real-time search as you type
- Use `make tree` to understand project structure
- Use `make stats-features` to see code distribution across modules