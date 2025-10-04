# Build Commands Reference

**Quick Start**: Run `make help` to see all available commands.

## iOS 26 Build Patterns

### Standard Debug Build
```bash
xcodebuild build \
  -project "Fonic HiFi.xcodeproj" \
  -scheme "Fonic HiFi" \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

### Release Build
```bash
xcodebuild build \
  -project "Fonic HiFi.xcodeproj" \
  -scheme "Fonic HiFi" \
  -configuration Release \
  -sdk iphonesimulator26.0 \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0'
```

## Build Verification Best Practices

### DO:
- Use `make build-check` for quick verification (exit code only)
- Use `make build-verify` for comprehensive analysis with full output
- Use `make error-report` for detailed error extraction
- Always check exit codes: `make build; echo $?` (0 = success)
- Review full output when debugging build issues

### DON'T:
- Use `tail` or `head` on build output (loses critical information)
- Rely only on final output messages from formatters
- Ignore exit codes when verifying builds
- Trust "Build Succeeded" without checking actual exit status

## ⚠️ CRITICAL: Compiler Working Tree Behavior

**Key Insight from Branch Recovery [Verified-Code]:**

- **Compiler compiles from working tree, NOT from HEAD commit**
- Staged but uncommitted changes ARE visible to the compiler
- Build can succeed with staged changes even though they're not committed
- This is NORMAL xcodebuild/swiftc behavior, not a bug

**Example Scenario:**
```bash
# File has changes staged but not committed
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

## Verification Workflow

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

## Troubleshooting Build Failures

1. Run `make build-verify` for full output
2. Check `build_verify.log` for complete details
3. Use `make error-report` to extract all errors/warnings
4. Review `build_errors.log` for filtered issues

## Security Hardening Summary

**October 2025 - Makefile Security Improvements:**

| Category | Improvements |
|----------|-------------|
| **Input Validation** | PID regex validation, DURATION range checks |
| **Temp File Security** | mktemp for codex-review, trap cleanup |
| **Process Matching** | Bundle ID instead of generic process names |
| **Error Handling** | Fail-fast with &&, explicit error messages |
| **Crash Log Safety** | Modification time sorting, atos validation |
| **Upload Protection** | CODEX_ALLOW_UPLOAD=1 required for AI commands |

See Makefile comments for implementation details.

## Most-Used Commands

**Build & Verify:**
- `make build` - Build Debug configuration
- `make build-verify` - Comprehensive build verification
- `make build-check` - Quick pass/fail check
- `make run-verify` - Build + launch + verify running

**Code Quality:**
- `make lint` - SwiftLint checks (ALWAYS run after code changes)
- `make format` - Auto-format with SwiftFormat
- `make analyze` - Static analysis

**Search & Debug:**
- `make search PATTERN='text'` - Fast ripgrep search
- `make find-todos` - Find all TODO/FIXME
- `make logs-stream` - Live debug logs
- `make crash-latest` - Most recent crash log

**Profiling:**
- `make profile-cpu` - CPU profiling
- `make profile-memory` - Memory profiling
- `make memory-leaks` - Leak detection

## Project Configuration

- **Target**: iOS 26.0 (minimum)
- **Simulator**: iPhone 16 Pro, iOS 26.0
- **Swift**: 6.2 (strict concurrency)
- **Xcode**: 26
- **Bundle ID**: ai.keiranlabs.Fonic-HiFi
