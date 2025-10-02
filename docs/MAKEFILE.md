# Makefile Command Reference

**MANDATORY**: Always use Makefile commands for consistency and efficiency.

## Quick Command Reference

**Most Used Commands:**
- `make build` - Build the app (Debug)
- `make build-verify` - Comprehensive build verification with full output
- `make build-check` - Quick build check (exit code only)
- `make error-report` - Generate detailed error report
- `make run` - Build and run in simulator
- `make run-verify` - Build, install, launch, verify app is running (NEW)
- `make test` - Shows message about no tests configured
- `make lint` - Check code quality
- `make format` - Auto-format code
- `make clean` - Clean build artifacts
- `make search PATTERN='text'` - Fast code search
- `make crash-latest` - Show most recent crash log (NEW)
- `make monitor-app DURATION=30` - Monitor app for crashes (NEW)
- `make profile-cpu` - CPU profiling
- `make profile-memory` - Memory profiling
- `make memory-leaks` - Check for leaks
- `make logs-stream` - Stream live logs
- `make logs-errors` - Show only error-level logs (NEW)
- `make logs-audio` - Filter logs for audio subsystem (NEW)

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

## Crash Detection & Monitoring

### Crash Log Management
```bash
# List all recent crash logs (sorted by modification time)
make crash-logs

# Show the most recent crash log
make crash-latest

# iOS 26 modern crash diagnostics (uses simctl)
make crash-simctl

# Symbolicate a specific crash log
make crash-symbolicate CRASH_LOG=path/to/crashlog.crash
```

### App Launch Verification
```bash
# Build, install, launch, and verify app is running
make run-verify

# Check if app is currently running
make app-status

# Monitor app for crashes over 60 seconds
make monitor-app DURATION=60
```

**Example Workflow:**
```bash
# Launch app with verification
make run-verify

# Monitor for stability
make monitor-app DURATION=120

# If crash detected, view latest crash log
make crash-latest

# Symbolicate crash log for detailed analysis
make crash-symbolicate CRASH_LOG=~/Library/Logs/DiagnosticReports/Fonic\ HiFi-2025-10-01-*.crash
```

## Advanced Log Filtering

```bash
# Show only error-level logs from last hour
make logs-errors

# Filter logs for audio subsystem
make logs-audio

# Standard log filtering by subsystem (existing)
make logs-filter SUBSYSTEM='com.fonichifi.audio'
```

## Python Automation

### Setup Virtual Environment
```bash
# Create and setup Python virtual environment
make venv-setup

# Activate the environment
source venv/bin/activate

# Check if environment is active
make venv-check

# Deactivate when done
deactivate
```

### Python-Based Simulator Control
```bash
# Launch simulator using Python isim library
source venv/bin/activate
make sim-python
```

### Available Python Packages
After running `make venv-setup`, the following packages are installed:
- **isim** - iOS simulator management wrapper
- **pymobiledevice3** - Real device control (USB/network)
- **tidevice** - Simplified pymobiledevice3 wrapper
- **Appium-Python-Client** - UI testing automation
- **pytest** - Testing framework

### Python Scripts Best Practices
1. Always activate venv before Python operations: `source venv/bin/activate`
2. Check venv status with: `make venv-check`
3. Deactivate when done: `deactivate`
4. For custom Python scripts, place them in `scripts/` directory

## Codex CLI Integration

**Note**: All codex commands use `codex exec --full-auto` for non-interactive execution, suitable for automation and CI/CD environments without TTY.

**Security**: All Codex commands require `CODEX_ALLOW_UPLOAD=1` to prevent accidental code transmission to OpenAI's service.

### Code Assistance with OpenAI Codex
```bash
# Explain a Swift file with Codex
make codex-explain FILE="Fonic HiFi/Core/Audio/AudioEngineFacade.swift" CODEX_ALLOW_UPLOAD=1

# Fix an issue with Codex
make codex-fix ISSUE="NowPlayingView re-plays track on sheet open" CODEX_ALLOW_UPLOAD=1

# Generate tests with Codex
make codex-test FILE="Fonic HiFi/Core/Audio/AudioEngineFactory.swift" CODEX_ALLOW_UPLOAD=1

# Review staged changes with Codex
git add .
make codex-review CODEX_ALLOW_UPLOAD=1
```

### Codex vs Mods Commands

| Task | Codex CLI | Mods CLI |
|------|-----------|----------|
| Explain code | `make codex-explain FILE=path` | `make ai-explain FILE=path` |
| Generate tests | `make codex-test FILE=path` | `make ai-test-generate FILE=path` |
| Code review | `make codex-review` | `make ai-review` |
| Fix issues | `make codex-fix ISSUE='desc'` | Manual workflow |

**When to use Codex:**
- Need direct file editing capabilities (`codex exec`)
- Want GPT-4o-optimized code generation
- Prefer OpenAI ecosystem

**When to use Mods:**
- Need streaming output
- Want model flexibility (Claude, Gemini, etc.)
- Prefer conversational interface

### Security & Reliability Improvements

**October 1, 2025 - Initial Security Hardening:**

1. **PID Validation** (run-verify:736-744):
   - Added regex check that extracted PID is numeric
   - Prevents invalid PID values from passing through

2. **Duration Limiting** (monitor-app:762-769):
   - Capped maximum duration at 3600 seconds (1 hour)
   - Prevents accidental infinite loops or DoS

3. **Bundle ID Matching** (app-status:758):
   - Changed from `grep -i "fonic"` to `grep "$(BUNDLE_ID)"`
   - Prevents false matches with unrelated processes

**October 2, 2025 - Codex Security Review Fixes:**

4. **Temp File Security** (codex-review:887-894):
   - Fixed symlink attack vulnerability
   - Changed from predictable `/tmp/codex_review_diff.txt` to `mktemp`
   - Added trap cleanup to ensure temp file deletion

5. **Enhanced Error Handling** (venv-setup:814-818):
   - Chain all commands with `&&` to fail fast
   - Added `--require-virtualenv` flag to ensure packages install in venv
   - Explicit error messages on failure

6. **Input Validation** (monitor-app:769-771):
   - Added regex validation for DURATION parameter
   - Prevents "integer expression expected" errors
   - Clear error message for invalid input

7. **Crash Log Recency** (crash-logs:706, crash-latest:711):
   - Fixed sorting to use modification time instead of alphabetical
   - Added `-maxdepth 1` for performance
   - Uses `ls -t` to get newest files first

8. **Crash Symbolication Safety** (crash-symbolicate:725-735):
   - Added `atos` availability check
   - Validates crash log file exists
   - Extracts only address frames with grep
   - Checks atos exit status

9. **Python Package Check** (venv-check:837):
   - Appended `|| echo "No tracked packages installed yet"`
   - Prevents false failures when venv is fresh

10. **Codex Upload Protection** (codex-*:875-924):
    - All Codex commands now require `CODEX_ALLOW_UPLOAD=1`
    - Prevents accidental code transmission to OpenAI
    - Clear warning messages when flag is missing

## Integration with bash-commands.md

The Makefile now implements patterns from `~/bash-commands.md`:
- ✅ Build verification with exit codes (Section 1)
- ✅ Crash detection and monitoring (Section 5)
- ✅ App launch verification with PID tracking (Section 6)
- ✅ Process monitoring with kill -0 checks (Section 6)
- ✅ Advanced log filtering with predicates (Section 4)
- ✅ Python automation via isim/pymobiledevice3 (Section 11)
- ✅ Security hardening (PID validation, duration limits, bundle ID matching)

See `~/bash-commands.md` for complete reference on Bash patterns for iOS/Xcode automation.