# Fonic HiFi iOS App - Makefile
# Comprehensive build automation for iOS audio application development

# Project Configuration
PROJECT_NAME = Fonic HiFi
SCHEME = Fonic HiFi
BUNDLE_ID = ai.keiranlabs.Fonic-HiFi

# Build Configuration
CONFIGURATION_DEBUG = Debug
CONFIGURATION_RELEASE = Release
SDK = iphonesimulator26.0
DEPLOYMENT_TARGET = 26.0

# Simulator Configuration
SIMULATOR_NAME = iPhone 16 Pro
SIMULATOR_OS = 26.0
DESTINATION = platform=iOS Simulator,name=$(SIMULATOR_NAME),OS=$(SIMULATOR_OS)

# Derived Data Path
DERIVED_DATA = $(HOME)/Library/Developer/Xcode/DerivedData
BUILD_DIR = build
RESULT_BUNDLE = $(BUILD_DIR)/TestResults.xcresult
OVERALL_COVERAGE_THRESHOLD ?= 0
APP_COVERAGE_THRESHOLD ?= 0
COVERAGE_MIN_PERCENT ?= 65
APP_COVERAGE_MIN_PERCENT ?= 65

# Detect Homebrew prefix dynamically (works on Intel and ARM Macs)
BREW_PREFIX := $(shell brew --prefix 2>/dev/null || echo /usr/local)

# Tools
XCODEBUILD = xcodebuild
XCBEAUTIFY = $(shell command -v xcbeautify >/dev/null 2>&1 && echo xcbeautify || echo cat)
SWIFTLINT = $(shell command -v swiftlint 2>/dev/null || echo $(BREW_PREFIX)/bin/swiftlint)
SWIFTFORMAT = $(shell command -v swiftformat 2>/dev/null || echo $(BREW_PREFIX)/bin/swiftformat)
INSTRUMENTS = instruments
XCRUN = xcrun

# Brew Tools
RG = rg
FD = fd
FZF = fzf
BAT = bat
EZA = eza
TOKEI = tokei
JQ = jq
WATCHMAN = watchman
HYPERFINE = hyperfine
GH = gh
MODS = mods
LLM = llm


# Default target
.DEFAULT_GOAL := help

# Phony targets
.PHONY: all help clean build build-release test test-unit test-ui coverage coverage-check lint format analyze open check-deps install-deps simulator-boot simulator-shutdown simulator-list run
.PHONY: search find-files find-todos find-viewmodels find-audio find-core stats stats-features tree view
.PHONY: watch-lint watch-build watch-test benchmark-build benchmark-test benchmark-all
.PHONY: profile-cpu profile-memory profile-audio memory-graph memory-leaks
.PHONY: logs-show logs-stream logs-filter logs-errors logs-audio symbolicate
.PHONY: ai-explain ai-test-generate ai-review ai-commit pr-create issues diff find-interactive search-interactive parse-errors test-json
.PHONY: build-verify build-check error-report
.PHONY: crash-logs crash-latest crash-symbolicate crash-simctl run-verify app-status monitor-app
.PHONY: venv-setup venv-activate venv-check sim-python
.PHONY: codex-explain codex-fix codex-test codex-review

## Self-documenting help - reads inline ## comments from targets below
help: ## Show all available commands
	@echo "Fonic HiFi iOS App - Self-Documenting Makefile"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[32m%-25s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "📖 See docs/COMMANDS.md for build best practices and iOS 26 patterns"
	@echo "  make codex-explain FILE=path - Explain code with Codex CLI"
	@echo "  make codex-fix ISSUE='description' - Fix issue with Codex"
	@echo "  make codex-test FILE=path - Generate tests with Codex"
	@echo "  make codex-review         - Code review with Codex CLI"
	@echo ""
	@echo "Git & GitHub (gh, bat):"
	@echo "  make pr-create      - Create pull request"
	@echo "  make issues         - List GitHub issues"
	@echo "  make diff           - Colored git diff"
	@echo ""
	@echo "Simulator Commands:"
	@echo "  make simulator-boot     - Boot iPhone 16 Pro simulator"
	@echo "  make simulator-shutdown - Shutdown all simulators"
	@echo "  make simulator-list     - List available simulators"
	@echo ""
	@echo "Utility Commands:"
	@echo "  make check-deps     - Check if required tools are installed"
	@echo "  make install-deps   - Install missing dependencies"

# Check if required dependencies are installed
check-deps: ## Check if required development tools are installed
	@echo "Checking dependencies..."
	@echo "\nCritical (Required):"
	@command -v $(XCODEBUILD) >/dev/null 2>&1 && echo "  [OK] xcodebuild" || { echo "  [FAIL] xcodebuild - Please install Xcode"; exit 1; }
	@echo "\nBuild & Formatting:"
	@command -v xcbeautify >/dev/null 2>&1 && echo "  [OK] xcbeautify" || echo "  xcbeautify - Install with: brew install xcbeautify"
	@command -v $(SWIFTLINT) >/dev/null 2>&1 && echo "  [OK] swiftlint" || echo "  swiftlint - Install with: brew install swiftlint"
	@command -v $(SWIFTFORMAT) >/dev/null 2>&1 && echo "  [OK] swiftformat" || echo "  swiftformat - Install with: brew install swiftformat"
	@echo "\nSearch & Navigation (Optional):"
	@command -v $(RG) >/dev/null 2>&1 && echo "  [OK] ripgrep (rg)" || echo "  ripgrep - Install with: brew install ripgrep"
	@command -v $(FD) >/dev/null 2>&1 && echo "  [OK] fd" || echo "  fd - Install with: brew install fd"
	@command -v $(FZF) >/dev/null 2>&1 && echo "  [OK] fzf" || echo "  fzf - Install with: brew install fzf"
	@command -v $(BAT) >/dev/null 2>&1 && echo "  [OK] bat" || echo "  bat - Install with: brew install bat"
	@command -v $(EZA) >/dev/null 2>&1 && echo "  [OK] eza" || echo "  eza - Install with: brew install eza"
	@echo "\nAnalysis & Monitoring (Optional):"
	@command -v $(TOKEI) >/dev/null 2>&1 && echo "  [OK] tokei" || echo "  tokei - Install with: brew install tokei"
	@command -v $(WATCHMAN) >/dev/null 2>&1 && echo "  [OK] watchman" || echo "  watchman - Install with: brew install watchman"
	@command -v $(HYPERFINE) >/dev/null 2>&1 && echo "  [OK] hyperfine" || echo "  hyperfine - Install with: brew install hyperfine"
	@command -v $(JQ) >/dev/null 2>&1 && echo "  [OK] jq" || echo "  jq - Install with: brew install jq"
	@echo "\nGit & AI Tools (Optional):"
	@command -v $(GH) >/dev/null 2>&1 && echo "  [OK] gh" || echo "  gh - Install with: brew install gh"
	@command -v $(MODS) >/dev/null 2>&1 && echo "  [OK] mods" || echo "  mods - Install with: brew install mods"
	@command -v $(LLM) >/dev/null 2>&1 && echo "  [OK] llm" || echo "  llm - Install with: brew install llm"
	@echo "\nDependency check complete"

# Install missing dependencies
install-deps: ## Install missing dependencies via Homebrew
	@echo "Installing dependencies..."
	@command -v brew >/dev/null 2>&1 || { echo "Installing Homebrew..."; /bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; }
	@echo "\nInstalling essential tools..."
	@command -v xcbeautify >/dev/null 2>&1 || { echo "  Installing xcbeautify..."; brew install xcbeautify; }
	@command -v $(SWIFTLINT) >/dev/null 2>&1 || { echo "  Installing SwiftLint..."; brew install swiftlint; }
	@command -v $(SWIFTFORMAT) >/dev/null 2>&1 || { echo "  Installing SwiftFormat..."; brew install swiftformat; }
	@echo "\nInstalling search & navigation tools..."
	@command -v $(RG) >/dev/null 2>&1 || { echo "  Installing ripgrep..."; brew install ripgrep; }
	@command -v $(FD) >/dev/null 2>&1 || { echo "  Installing fd..."; brew install fd; }
	@command -v $(FZF) >/dev/null 2>&1 || { echo "  Installing fzf..."; brew install fzf; }
	@command -v $(BAT) >/dev/null 2>&1 || { echo "  Installing bat..."; brew install bat; }
	@command -v $(EZA) >/dev/null 2>&1 || { echo "  Installing eza..."; brew install eza; }
	@echo "\nInstalling analysis tools..."
	@command -v $(TOKEI) >/dev/null 2>&1 || { echo "  Installing tokei..."; brew install tokei; }
	@command -v $(JQ) >/dev/null 2>&1 || { echo "  Installing jq..."; brew install jq; }
	@echo "\nDependencies installed"

# Clean build artifacts and derived data
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@$(XCODEBUILD) clean \
		-project "$(PROJECT_NAME).xcodeproj" \
		-scheme "$(SCHEME)" \
		-quiet || true
	@echo "Cleaning derived data..."
	@rm -rf "$(DERIVED_DATA)/Fonic_HiFi-"*
	@rm -rf "$(DERIVED_DATA)/Fonic HiFi-"*
	@echo "Clean complete"

# Build the app in Debug configuration
build: check-deps
	@echo "Verifying lint before build..."
	@$(MAKE) lint
	@echo "Verifying tests before build..."
	@$(MAKE) test
	@echo "Building $(PROJECT_NAME) (Debug)..."
	@set -o pipefail && $(XCODEBUILD) build \
		-project "$(PROJECT_NAME).xcodeproj" \
		-scheme "$(SCHEME)" \
		-configuration $(CONFIGURATION_DEBUG) \
		-destination "$(DESTINATION)" \
		-derivedDataPath $(BUILD_DIR) \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		2>&1 | tee .build_output.tmp | $(XCBEAUTIFY); \
	EXIT_CODE=$${PIPESTATUS[0]}; \
	if [ $$EXIT_CODE -ne 0 ]; then \
		echo "❌ Build failed with exit code $$EXIT_CODE"; \
		echo "First 5 errors:"; \
		grep -E "error:" .build_output.tmp | head -5 2>/dev/null || echo "Check .build_output.tmp for details"; \
		rm -f .build_output.tmp; \
		exit $$EXIT_CODE; \
	fi; \
	rm -f .build_output.tmp; \
	echo "Build complete"

# Build the app in Release configuration
build-release: check-deps ## Build app in Release configuration
	@echo "Building $(PROJECT_NAME) (Release)..."
	@set -o pipefail && $(XCODEBUILD) build \
		-project "$(PROJECT_NAME).xcodeproj" \
		-scheme "$(SCHEME)" \
		-configuration $(CONFIGURATION_RELEASE) \
		-destination "$(DESTINATION)" \
		-derivedDataPath $(BUILD_DIR) \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		| $(XCBEAUTIFY) || exit 1
	@echo "Release build complete"

# Comprehensive build verification with full output capture
build-verify: clean ## Comprehensive build verification with full output
	@echo "🔍 Running comprehensive build verification..."
	@$(MAKE) build > build_verify.log 2>&1; \
	EXIT_CODE=$$?; \
	if [ $$EXIT_CODE -ne 0 ]; then \
		echo "❌ Build failed with exit code $$EXIT_CODE"; \
		echo "First 10 errors:"; \
		grep -E "error:" build_verify.log | head -10 || echo "No explicit error messages found"; \
		echo ""; \
		echo "See build_verify.log for full output"; \
		exit 1; \
	else \
		echo "✅ Build succeeded"; \
		if grep -q "error:" build_verify.log; then \
			echo "⚠️  Warning: Found 'error:' in successful build output:"; \
			grep "error:" build_verify.log | head -5; \
		fi; \
		echo "Full log saved to build_verify.log"; \
	fi

# Quick build check - exit code only
build-check: ## Quick build check (exit code only, no output)
	@$(MAKE) build >/dev/null 2>&1 && echo "✅ Build OK" || echo "❌ Build FAILED (exit code: $$?)"

# Detailed error report with filtering
error-report: ## Generate detailed error report from build
	@echo "📋 Generating detailed error report..."
	@$(MAKE) build 2>&1 | tee build_errors.log | grep -E "error:|warning:" || true
	@ERROR_COUNT=$$(grep -c "error:" build_errors.log 2>/dev/null || echo 0); \
	WARNING_COUNT=$$(grep -c "warning:" build_errors.log 2>/dev/null || echo 0); \
	echo ""; \
	echo "Summary: $$ERROR_COUNT errors, $$WARNING_COUNT warnings"; \
	echo "Full log saved to build_errors.log"

# Build and run the app in the simulator
run: build simulator-boot ## Build and run app in simulator
	@echo "Installing $(PROJECT_NAME) on simulator..."
	@$(XCRUN) simctl install booted "$(BUILD_DIR)/Build/Products/Debug-iphonesimulator/Fonic HiFi.app" || { echo "Failed to install app"; exit 1; }
	@echo "Launching $(PROJECT_NAME)..."
	@$(XCRUN) simctl launch booted $(BUNDLE_ID) || { echo "Failed to launch app"; exit 1; }
	@echo "App is running on simulator"

# Run all tests (unit and UI)
test: check-deps ## Run all Swift test targets
	@echo "Running Swift test suite..."
	@rm -rf "$(RESULT_BUNDLE)"
	@set -o pipefail && $(XCODEBUILD) test \
		-project "$(PROJECT_NAME).xcodeproj" \
		-scheme "$(SCHEME)" \
		-configuration $(CONFIGURATION_DEBUG) \
		-destination "$(DESTINATION)" \
		-derivedDataPath $(BUILD_DIR) \
		-enableCodeCoverage YES \
		-resultBundlePath "$(RESULT_BUNDLE)" \
		2>&1 | tee .test_output.tmp | $(XCBEAUTIFY); \
	EXIT_CODE=$${PIPESTATUS[0]}; \
	rm -f .test_output.tmp; \
	if [ $$EXIT_CODE -ne 0 ]; then \
		echo "❌ Tests failed with exit code $$EXIT_CODE"; \
		exit $$EXIT_CODE; \
	fi; \
	echo "✅ Test suite complete"

# Run unit tests only
test-unit: ## Run unit tests (alias of make test)
	@$(MAKE) test

# Run UI tests only
test-ui: ## Run UI tests (alias of make test)
	@$(MAKE) test

# Generate test coverage report
coverage: ## Generate test coverage report for the latest test run
	@if [ ! -d "$(RESULT_BUNDLE)" ]; then \
		echo "Test result bundle not found. Running tests..."; \
		$(MAKE) test; \
	fi
	@echo "Calculating coverage metrics..."
	@xcrun xccov view --report --json "$(RESULT_BUNDLE)" > $(BUILD_DIR)/coverage.json
	@xcrun xccov view --report "$(RESULT_BUNDLE)"
	@python3 scripts/coverage_summary.py $(BUILD_DIR)/coverage.json --build-dir $(BUILD_DIR) --overall-threshold $(OVERALL_COVERAGE_THRESHOLD) --app-threshold $(APP_COVERAGE_THRESHOLD)

coverage-check: ## Generate coverage report and enforce coverage thresholds (defaults 65%)
	@$(MAKE) coverage OVERALL_COVERAGE_THRESHOLD=$(COVERAGE_MIN_PERCENT) APP_COVERAGE_THRESHOLD=$(APP_COVERAGE_MIN_PERCENT)

# Run SwiftLint
lint: ## Run SwiftLint code quality checks
	@echo "Running SwiftLint..."
	@if command -v $(SWIFTLINT) >/dev/null 2>&1; then \
		$(SWIFTLINT) lint --strict --reporter emoji || exit 1; \
	else \
		echo "SwiftLint not installed. Run 'make install-deps' to install it."; \
		exit 1; \
	fi
	@echo "Linting complete"

# Auto-format code using SwiftFormat
format: ## Auto-format code with SwiftFormat
	@echo "Formatting code with SwiftFormat..."
	@if command -v $(SWIFTFORMAT) >/dev/null 2>&1; then \
		$(SWIFTFORMAT) . --swiftversion 6.2 --verbose; \
	else \
		echo "SwiftFormat not installed. Run 'make install-deps' to install it."; \
		exit 1; \
	fi
	@echo "Formatting complete"

# Run static analysis
analyze: check-deps ## Run static analysis on codebase
	@echo "Running static analysis..."
	@set -o pipefail && $(XCODEBUILD) analyze \
		-project "$(PROJECT_NAME).xcodeproj" \
		-scheme "$(SCHEME)" \
		-configuration $(CONFIGURATION_DEBUG) \
		-destination "$(DESTINATION)" \
		-quiet \
		| $(XCBEAUTIFY) || exit 1
	@echo "Static analysis complete"

# Open project in Xcode
open: ## Open project in Xcode
	@echo "Opening project in Xcode..."
	@open "$(PROJECT_NAME).xcodeproj"

# Boot the simulator
simulator-boot: ## Boot iPhone 16 Pro simulator (iOS 26)
	@echo "Booting $(SIMULATOR_NAME) simulator..."
	@$(XCRUN) simctl boot "$(SIMULATOR_NAME)" 2>/dev/null || echo "Simulator already booted or not available"

# Shutdown all simulators
simulator-shutdown:
	@echo "Shutting down all simulators..."
	@$(XCRUN) simctl shutdown all
	@echo "All simulators shut down"

# List available simulators
simulator-list:
	@echo "Available simulators:"
	@$(XCRUN) simctl list devices available | grep -E "iPhone|iPad"

# ===== SEARCH & NAVIGATION COMMANDS =====

# Fast code search using ripgrep
search: ## Fast code search (usage: PATTERN='text')
	@if [ -z "$(PATTERN)" ]; then \
		echo "Usage: make search PATTERN='your search term'"; \
		exit 1; \
	fi
	@command -v $(RG) >/dev/null 2>&1 || { echo "ripgrep not installed. Install with: brew install ripgrep"; exit 1; }
	@echo "Searching for '$(PATTERN)'..."
	@$(RG) "$(PATTERN)" "Fonic HiFi" --type swift --line-number --column --pretty || echo "No matches found"

# Find files using fd
find-files: ## Find files by pattern (usage: PATTERN='*.swift')
	@if [ -z "$(PATTERN)" ]; then \
		echo "Usage: make find-files PATTERN='*.swift'"; \
		exit 1; \
	fi
	@command -v $(FD) >/dev/null 2>&1 || { echo "fd not installed. Install with: brew install fd"; exit 1; }
	@echo "Finding files matching '$(PATTERN)'..."
	@$(FD) "$(PATTERN)" "Fonic HiFi" --type f || echo "No files found"

# Find all TODO/FIXME comments
find-todos: ## Find all TODO/FIXME comments
	@echo "Finding all TODO/FIXME/HACK comments..."
	@command -v $(RG) >/dev/null 2>&1 || { echo "ripgrep not installed. Install with: brew install ripgrep"; exit 1; }
	@command -v $(BAT) >/dev/null 2>&1 || { echo "bat not installed. Install with: brew install bat"; exit 1; }
	@$(RG) "TODO|FIXME|HACK|XXX" "Fonic HiFi" --type swift --line-number --pretty | $(BAT) --language=swift --style=numbers || echo "No TODOs found"

# Find all ViewModels
find-viewmodels:
	@echo "Finding all ViewModels..."
	@command -v $(FD) >/dev/null 2>&1 || { echo "fd not installed. Install with: brew install fd"; exit 1; }
	@command -v $(BAT) >/dev/null 2>&1 || { echo "bat not installed. Install with: brew install bat"; exit 1; }
	@$(FD) "ViewModel\.swift$$" "Fonic HiFi" --type f | $(BAT) --style=numbers --language=txt || echo "No ViewModels found"

# Find all AudioKit/audio references
find-audio:
	@echo "Finding all AudioKit and audio references..."
	@command -v $(RG) >/dev/null 2>&1 || { echo "ripgrep not installed. Install with: brew install ripgrep"; exit 1; }
	@$(RG) "AudioKit|AVAudioEngine|AudioUnit|AudioPlayer|AudioRecorder" "Fonic HiFi" --type swift --line-number --pretty || echo "No audio references found"

# Find all Core module references
find-core:
	@echo "Finding all Core module references..."
	@command -v $(RG) >/dev/null 2>&1 || { echo "ripgrep not installed. Install with: brew install ripgrep"; exit 1; }
	@$(RG) "import Core|Core\." "Fonic HiFi" --type swift --line-number --pretty || echo "No Core references found"

# Interactive file finder with preview
find-interactive:
	@echo "Opening interactive file finder (ESC to exit)..."
	@command -v $(FD) >/dev/null 2>&1 || { echo "fd not installed. Install with: brew install fd"; exit 1; }
	@command -v $(FZF) >/dev/null 2>&1 || { echo "fzf not installed. Install with: brew install fzf"; exit 1; }
	@command -v $(BAT) >/dev/null 2>&1 || { echo "bat not installed. Install with: brew install bat"; exit 1; }
	@$(FD) "\.swift$$" "Fonic HiFi" | $(FZF) --preview '$(BAT) --color=always --style=numbers --line-range=:500 {}' --preview-window=right:60%

# Interactive code search
search-interactive:
	@echo "Interactive search (type to search, ESC to exit)..."
	@command -v $(FZF) >/dev/null 2>&1 || { echo "fzf not installed. Install with: brew install fzf"; exit 1; }
	@command -v $(RG) >/dev/null 2>&1 || { echo "ripgrep not installed. Install with: brew install ripgrep"; exit 1; }
	@echo "" | $(FZF) --print-query --preview '$(RG) --color=always --line-number {q} "Fonic HiFi" || echo "Type to search..."' --preview-window=down:50% --bind 'change:reload:$(RG) --color=always --line-number {q} "Fonic HiFi" || true'

# ===== CODE ANALYSIS COMMANDS =====

# Show code statistics with tokei
stats: ## Show code statistics with tokei
	@echo "Code Statistics:"
	@command -v $(TOKEI) >/dev/null 2>&1 || { echo "tokei not installed. Install with: brew install tokei"; exit 1; }
	@$(TOKEI) --type=Swift --sort lines "Fonic HiFi"

# Statistics per feature module
stats-features:
	@command -v $(TOKEI) >/dev/null 2>&1 || { echo "tokei not installed. Install with: brew install tokei"; exit 1; }
	@echo "Module Statistics:"
	@echo "\nCore:"
	@$(TOKEI) "Fonic HiFi/Core" --type=Swift --sort lines || echo "No Core module found"
	@echo "\nPresentation:"
	@$(TOKEI) "Fonic HiFi/Presentation" --type=Swift --sort lines || echo "No Presentation module found"
	@echo "\nData:"
	@$(TOKEI) "Fonic HiFi/Data" --type=Swift --sort lines || echo "No Data module found"
	@echo "\nUtils:"
	@$(TOKEI) "Fonic HiFi/Utils" --type=Swift --sort lines || echo "No Utils module found"

# Visual project structure with eza
tree: ## Visual project structure with eza
	@command -v $(EZA) >/dev/null 2>&1 || { echo "eza not installed. Install with: brew install eza"; exit 1; }
	@echo "Project Structure:"
	@$(EZA) --tree --level=3 --icons --ignore-glob=".git|build|DerivedData|*.xcodeproj" "Fonic HiFi/"

# View file with syntax highlighting
view:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make view FILE=path/to/file.swift"; \
		exit 1; \
	fi
	@command -v $(BAT) >/dev/null 2>&1 || { echo "bat not installed. Install with: brew install bat"; exit 1; }
	@$(BAT) --style=full --language=swift "$(FILE)" || echo "File not found: $(FILE)"

# ===== MONITORING & AUTOMATION COMMANDS =====

# Auto-lint on file changes
watch-lint:
	@echo "Watching for changes to run SwiftLint..."
	@command -v $(WATCHMAN) >/dev/null 2>&1 || { echo "watchman not installed. Install with: brew install watchman"; exit 1; }
	@command -v $(JQ) >/dev/null 2>&1 || { echo "jq not installed. Install with: brew install jq"; exit 1; }
	@$(WATCHMAN) watch-del-all >/dev/null 2>&1 || true
	@$(WATCHMAN) watch-project . >/dev/null 2>&1
	@$(WATCHMAN) -- trigger . swiftlint '*.swift' -- make lint
	@echo "Watching for Swift file changes. Press Ctrl+C to stop."
	@$(WATCHMAN) -- trigger-list . | $(JQ) '.'

# Auto-build on changes
watch-build:
	@echo "Watching for changes to rebuild..."
	@command -v $(WATCHMAN) >/dev/null 2>&1 || { echo "watchman not installed. Install with: brew install watchman"; exit 1; }
	@command -v $(JQ) >/dev/null 2>&1 || { echo "jq not installed. Install with: brew install jq"; exit 1; }
	@$(WATCHMAN) watch-del-all >/dev/null 2>&1 || true
	@$(WATCHMAN) watch-project . >/dev/null 2>&1
	@$(WATCHMAN) -- trigger . rebuild '*.swift' '*.storyboard' '*.xib' -- make build
	@echo "Watching for changes. Press Ctrl+C to stop."
	@$(WATCHMAN) -- trigger-list . | $(JQ) '.'

# Auto-test on changes
watch-test:
	@echo "Watching for changes to run tests..."
	@command -v $(WATCHMAN) >/dev/null 2>&1 || { echo "watchman not installed. Install with: brew install watchman"; exit 1; }
	@command -v $(JQ) >/dev/null 2>&1 || { echo "jq not installed. Install with: brew install jq"; exit 1; }
	@$(WATCHMAN) watch-del-all >/dev/null 2>&1 || true
	@$(WATCHMAN) watch-project . >/dev/null 2>&1
	@$(WATCHMAN) -- trigger . test '*.swift' -- make test-unit
	@echo "Watching for test changes. Press Ctrl+C to stop."
	@$(WATCHMAN) -- trigger-list . | $(JQ) '.'

# ===== PERFORMANCE BENCHMARKING =====

# Benchmark build performance
benchmark-build:
	@echo "Benchmarking build performance..."
	@command -v $(HYPERFINE) >/dev/null 2>&1 || { echo "hyperfine not installed. Install with: brew install hyperfine"; exit 1; }
	@$(HYPERFINE) --warmup 1 --runs 3 \
		'make clean build' \
		--export-markdown benchmark-build.md
	@echo "Results saved to benchmark-build.md"

# Benchmark test execution
benchmark-test:
	@echo "Benchmarking test performance..."
	@command -v $(HYPERFINE) >/dev/null 2>&1 || { echo "hyperfine not installed. Install with: brew install hyperfine"; exit 1; }
	@$(HYPERFINE) --warmup 1 --runs 3 \
		'make test-unit' \
		--export-markdown benchmark-test.md
	@echo "Results saved to benchmark-test.md"

# Full performance analysis
benchmark-all:
	@echo "Running full performance analysis..."
	@command -v $(HYPERFINE) >/dev/null 2>&1 || { echo "hyperfine not installed. Install with: brew install hyperfine"; exit 1; }
	@$(HYPERFINE) --warmup 1 --runs 3 \
		'make clean build' \
		'make test-unit' \
		'make lint' \
		--export-markdown benchmark-all.md
	@echo "Results saved to benchmark-all.md"

# ===== PERFORMANCE PROFILING (xctrace) =====

# CPU profiling with xctrace
profile-cpu: ## CPU profiling (app must be running)
	@echo "Starting CPU profiling..."
	@$(XCRUN) xctrace record --template "CPU Profiler" \
		--output cpu_profile.trace \
		--attach "Fonic HiFi" || { echo "Note: App must be running. Use 'make run' first."; exit 1; }
	@echo "CPU profile saved to cpu_profile.trace"
	@echo "Open with: open cpu_profile.trace"

# Memory allocation profiling
profile-memory: ## Memory allocation profiling
	@echo "Starting memory allocation profiling..."
	@$(XCRUN) xctrace record --template "Allocations" \
		--output memory_allocations.trace \
		--attach "Fonic HiFi" || { echo "Note: App must be running. Use 'make run' first."; exit 1; }
	@echo "Memory profile saved to memory_allocations.trace"
	@echo "Open with: open memory_allocations.trace"

# Audio system trace profiling
profile-audio:
	@echo "Starting audio system profiling..."
	@$(XCRUN) xctrace record --template "Audio System Trace" \
		--output audio_system.trace \
		--attach "Fonic HiFi" || { echo "Note: App must be running. Use 'make run' first."; exit 1; }
	@echo "Audio profile saved to audio_system.trace"
	@echo "Open with: open audio_system.trace"

# Memory graph debugging
memory-graph:
	@echo "Capturing memory graph..."
	@$(XCRUN) xctrace record --template "Allocations" \
		--output memory_graph.trace \
		--time-limit 30s \
		--attach "Fonic HiFi" || { echo "Note: App must be running. Use 'make run' first."; exit 1; }
	@echo "Memory graph saved to memory_graph.trace"

# Check for memory leaks
memory-leaks: ## Check for memory leaks
	@echo "Checking for memory leaks..."
	@if [ -d "$(BUILD_DIR)/Build/Products/Debug-iphonesimulator/Fonic HiFi.app" ]; then \
		leaks --atExit -- "$(BUILD_DIR)/Build/Products/Debug-iphonesimulator/Fonic HiFi.app/Fonic HiFi" || echo "Leak check complete"; \
	else \
		echo "App not found. Run 'make build' first."; \
		exit 1; \
	fi

# ===== DEBUGGING & LOGGING =====

# Show recent logs for the app
logs-show:
	@echo "Showing recent logs for Fonic HiFi..."
	@log show --predicate 'process == "Fonic HiFi"' --last 1h --style syslog

# Stream live logs
logs-stream: ## Stream live debug logs
	@echo "Streaming live logs for Fonic HiFi..."
	@echo "Press Ctrl+C to stop."
	@log stream --predicate 'process == "Fonic HiFi"' --level debug

# Filter logs by subsystem
logs-filter:
	@if [ -z "$(SUBSYSTEM)" ]; then \
		echo "Usage: make logs-filter SUBSYSTEM='com.fonichifi.audio'"; \
		exit 1; \
	fi
	@echo "Filtering logs for subsystem: $(SUBSYSTEM)"
	@log show --predicate 'subsystem == "$(SUBSYSTEM)"' --last 1h

# Symbolicate crash logs
symbolicate:
	@if [ -z "$(CRASH_LOG)" ]; then \
		echo "Usage: make symbolicate CRASH_LOG=path/to/crashlog.crash"; \
		exit 1; \
	fi
	@echo "Symbolicating crash log..."
	@if [ -f "$(BUILD_DIR)/Build/Products/Debug-iphonesimulator/Fonic HiFi.app.dSYM/Contents/Resources/DWARF/Fonic HiFi" ]; then \
		atos -arch arm64 -o "$(BUILD_DIR)/Build/Products/Debug-iphonesimulator/Fonic HiFi.app.dSYM/Contents/Resources/DWARF/Fonic HiFi" -l 0x100000000 < "$(CRASH_LOG)"; \
	else \
		echo "dSYM file not found. Build the app first."; \
		exit 1; \
	fi

# ===== AI ASSISTANCE COMMANDS =====

# Explain code with AI
ai-explain:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make ai-explain FILE=path/to/file.swift"; \
		exit 1; \
	fi
	@command -v $(MODS) >/dev/null 2>&1 || { echo "mods not installed. Install with: brew install mods"; exit 1; }
	@echo "Explaining $(FILE)..."
	@cat "$(FILE)" | $(MODS) "Explain this Swift code, focusing on audio processing and SwiftUI patterns used"

# Generate tests with AI
ai-test-generate:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make ai-test-generate FILE=path/to/file.swift"; \
		exit 1; \
	fi
	@command -v $(MODS) >/dev/null 2>&1 || { echo "mods not installed. Install with: brew install mods"; exit 1; }
	@echo "Generating tests for $(FILE)..."
	@cat "$(FILE)" | $(MODS) "Write comprehensive XCTest unit tests for this Swift code, including edge cases"

# AI code review of changes
ai-review:
	@command -v $(MODS) >/dev/null 2>&1 || { echo "mods not installed. Install with: brew install mods"; exit 1; }
	@echo "Running AI code review on staged changes..."
	@git diff --cached | $(MODS) "Review this code diff for iOS best practices, Swift 6 concurrency, and potential bugs"

# Generate commit message with AI
ai-commit:
	@command -v $(MODS) >/dev/null 2>&1 || { echo "mods not installed. Install with: brew install mods"; exit 1; }
	@echo "Generating commit message..."
	@git diff --cached | $(MODS) "Generate a concise, conventional commit message for these changes. Format: type(scope): description"

# ===== GIT & GITHUB INTEGRATION =====

# Create pull request
pr-create:
	@command -v $(GH) >/dev/null 2>&1 || { echo "gh not installed. Install with: brew install gh"; exit 1; }
	@echo "Creating pull request..."
	@$(GH) pr create --fill --web

# List GitHub issues
issues:
	@command -v $(GH) >/dev/null 2>&1 || { echo "gh not installed. Install with: brew install gh"; exit 1; }
	@echo "GitHub Issues:"
	@$(GH) issue list --label "ios" --limit 20

# Colored git diff
diff:
	@command -v $(BAT) >/dev/null 2>&1 || { echo "bat not installed. Install with: brew install bat"; exit 1; }
	@echo "Git diff with syntax highlighting:"
	@git diff | $(BAT) --language=diff --style=changes

# ===== XCODE BUILD OUTPUT PARSING =====

# Parse Xcode build output for errors
parse-errors:
	@echo "Parsing last build for errors..."
	@command -v $(RG) >/dev/null 2>&1 || { echo "ripgrep not installed. Install with: brew install ripgrep"; exit 1; }
	@$(XCODEBUILD) build -project "$(PROJECT_NAME).xcodeproj" -scheme "$(SCHEME)" -destination "$(DESTINATION)" 2>&1 | \
		$(RG) "error:|warning:" --color=always || echo "No errors or warnings found"

# Extract test results as JSON
test-json:
	@echo "Extracting test results as JSON..."
	@command -v $(JQ) >/dev/null 2>&1 || { echo "jq not installed. Install with: brew install jq"; exit 1; }
	@$(XCODEBUILD) test -project "$(PROJECT_NAME).xcodeproj" -scheme "$(SCHEME)" -destination "$(DESTINATION)" -resultBundlePath result.xcresult >/dev/null 2>&1
	@xcrun xcresulttool get --format json --path result.xcresult | $(JQ) '.metrics'

# ===== CRASH DETECTION & MONITORING =====

# List recent crash logs
crash-logs:
	@echo "Recent crash logs for Fonic HiFi..."
	@find ~/Library/Logs/DiagnosticReports -maxdepth 1 -type f \( -name "Fonic HiFi*.crash" -o -name "Fonic HiFi*.ips" \) 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -10 || echo "No crash logs found"

# Show most recent crash log
crash-latest: ## Show most recent crash log
	@echo "Most recent crash log..."
	@LATEST=$$(find ~/Library/Logs/DiagnosticReports -maxdepth 1 -type f \( -name "Fonic HiFi*.crash" -o -name "Fonic HiFi*.ips" \) -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -1); \
	if [ -n "$$LATEST" ]; then \
		echo "File: $$LATEST"; \
		cat "$$LATEST"; \
	else \
		echo "No crash logs found"; \
	fi

# iOS 26 simulator crash diagnostics (modern alternative)
crash-simctl:
	@echo "Fetching crash reports from iOS 26 simulator..."
	@$(XCRUN) simctl diagnose booted --crashes 2>/dev/null || \
		$(XCRUN) simctl crashreporter show booted 2>/dev/null || \
		echo "No crashes found or simctl diagnostics unavailable"

# Enhanced crash log symbolication
crash-symbolicate:
	@if [ -z "$(CRASH_LOG)" ]; then \
		echo "Usage: make crash-symbolicate CRASH_LOG=path/to/crashlog.crash"; \
		exit 1; \
	fi
	@command -v atos >/dev/null 2>&1 || { echo "❌ atos not found. Install Xcode Command Line Tools."; exit 1; }
	@if [ ! -f "$(CRASH_LOG)" ]; then \
		echo "❌ Crash log not found: $(CRASH_LOG)"; \
		exit 1; \
	fi
	@echo "Symbolicating crash log: $(CRASH_LOG)..."
	@DSYM_PATH="$(BUILD_DIR)/Build/Products/Debug-iphonesimulator/Fonic HiFi.app.dSYM/Contents/Resources/DWARF/Fonic HiFi"; \
	if [ -f "$$DSYM_PATH" ]; then \
		grep -E '^\s*[0-9]+\s+Fonic HiFi\s+0x[0-9a-f]+' "$(CRASH_LOG)" | \
		atos -arch arm64 -o "$$DSYM_PATH" -l 0x100000000 || \
		{ echo "❌ Symbolication failed"; exit 1; }; \
	else \
		echo "❌ dSYM file not found. Build the app first with: make build"; \
		exit 1; \
	fi

# ===== APP LAUNCH VERIFICATION =====

# Build, install, launch, and verify app is running
run-verify: build simulator-boot ## Build, install, launch, verify app running
	@echo "Installing $(PROJECT_NAME) on simulator..."
	@$(XCRUN) simctl install booted "$(BUILD_DIR)/Build/Products/Debug-iphonesimulator/Fonic HiFi.app" || { echo "Failed to install app"; exit 1; }
	@echo "Launching $(PROJECT_NAME) and verifying..."
	@LAUNCH_OUTPUT=$$($(XCRUN) simctl launch booted $(BUNDLE_ID) 2>&1); \
	APP_PID=$$(echo "$$LAUNCH_OUTPUT" | awk '{print $$NF}'); \
	if [ -z "$$APP_PID" ]; then \
		echo "❌ Failed to launch app"; \
		exit 1; \
	fi; \
	if ! [[ "$$APP_PID" =~ ^[0-9]+$$ ]]; then \
		echo "❌ Invalid PID extracted: $$APP_PID"; \
		exit 1; \
	fi; \
	echo "App launched with PID: $$APP_PID"; \
	sleep 3; \
	if kill -0 $$APP_PID 2>/dev/null; then \
		echo "✅ App is running and verified (PID: $$APP_PID)"; \
	else \
		echo "❌ App crashed after launch (PID $$APP_PID no longer exists)"; \
		make crash-latest; \
		exit 1; \
	fi

# Check if app is currently running
app-status:
	@echo "Checking $(PROJECT_NAME) status..."
	@$(XCRUN) simctl spawn booted launchctl list | grep "$(BUNDLE_ID)" || echo "App is not running"

# Monitor app for crashes over duration
monitor-app: ## Monitor app for crashes (usage: DURATION=30)
	@if [ -z "$(DURATION)" ]; then \
		DURATION=30; \
	elif ! [[ "$(DURATION)" =~ ^[0-9]+$$ ]]; then \
		echo "❌ DURATION must be a positive integer"; \
		exit 1; \
	elif [ $(DURATION) -gt 3600 ]; then \
		echo "⚠️  Duration capped at 3600 seconds (1 hour)"; \
		DURATION=3600; \
	else \
		DURATION=$(DURATION); \
	fi; \
	echo "Monitoring $(PROJECT_NAME) for $$DURATION seconds..."; \
	APP_PID=$$($(XCRUN) simctl spawn booted launchctl list | grep -i "fonic" | awk '{print $$1}'); \
	if [ -z "$$APP_PID" ]; then \
		echo "❌ App is not running. Launch it first with: make run"; \
		exit 1; \
	fi; \
	echo "Monitoring PID: $$APP_PID"; \
	for i in $$(seq 1 $$DURATION); do \
		if ! kill -0 $$APP_PID 2>/dev/null; then \
			echo "❌ App crashed at $$i seconds"; \
			make crash-latest; \
			exit 1; \
		fi; \
		sleep 1; \
		echo -n "."; \
	done; \
	echo ""; \
	echo "✅ App stable for $$DURATION seconds"

# ===== ADVANCED LOG FILTERING =====

# Show only error-level logs
logs-errors: ## Show only error-level logs from last hour
	@echo "Showing error-level logs for Fonic HiFi..."
	@log show --predicate 'process == "Fonic HiFi" && level == "error"' --last 1h --style syslog

# Filter logs for audio subsystem
logs-audio:
	@echo "Filtering logs for audio subsystem..."
	@log show --predicate 'process == "Fonic HiFi" && subsystem CONTAINS "audio"' --last 1h --style syslog

# ===== PYTHON AUTOMATION =====

# Setup Python virtual environment
venv-setup:
	@echo "Setting up Python virtual environment..."
	@if [ -d "venv" ]; then \
		echo "Virtual environment already exists at venv/"; \
	else \
		python3 -m venv venv && \
		echo "Virtual environment created" && \
		echo "Activating and installing packages..." && \
		. venv/bin/activate && \
		python3 -m pip install --require-virtualenv isim pymobiledevice3 tidevice Appium-Python-Client pytest && \
		echo "✅ Virtual environment ready" || \
		{ echo "❌ Failed to setup virtual environment"; exit 1; }; \
	fi
	@echo "\nTo activate: source venv/bin/activate"

# Show activation instructions
venv-activate:
	@echo "To activate the Python virtual environment, run:"
	@echo "  source venv/bin/activate"
	@echo ""
	@echo "To deactivate when done:"
	@echo "  deactivate"

# Check if venv is activated
venv-check:
	@if [ -n "$$VIRTUAL_ENV" ]; then \
		echo "✅ Virtual environment is active: $$VIRTUAL_ENV"; \
		echo "Installed packages:"; \
		pip list | grep -E "isim|pymobiledevice3|tidevice|Appium|pytest" || echo "No tracked packages installed yet"; \
	else \
		echo "❌ Virtual environment is not active"; \
		echo "Activate with: source venv/bin/activate"; \
	fi

# Launch simulator using Python isim
sim-python:
	@echo "Launching simulator via isim (Python)..."
	@if [ -n "$$VIRTUAL_ENV" ]; then \
		python3 -c "from isim import Runtime, DeviceType, Device; runtime = Runtime.from_name('iOS $(SIMULATOR_OS)'); device_type = DeviceType.from_name('$(SIMULATOR_NAME)'); devices = Device.from_name('$(SIMULATOR_NAME)'); device = devices[0] if devices else Device.create('Test iPhone', device_type, runtime); device.boot(); print('Simulator booted:', device.name)"; \
	else \
		echo "❌ Virtual environment not active. Run: source venv/bin/activate"; \
		exit 1; \
	fi

# ===== CODEX CLI COMMANDS =====

# Explain code with Codex CLI
codex-explain:
	@if [ -z "$(CODEX_ALLOW_UPLOAD)" ]; then \
		echo "⚠️  WARNING: This will upload code to OpenAI Codex service"; \
		echo "Set CODEX_ALLOW_UPLOAD=1 to proceed: make codex-explain FILE=... CODEX_ALLOW_UPLOAD=1"; \
		exit 1; \
	fi
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make codex-explain FILE=path/to/file.swift CODEX_ALLOW_UPLOAD=1"; \
		exit 1; \
	fi
	@command -v codex >/dev/null 2>&1 || { echo "codex not installed. Install with: npm install -g @openai/codex"; exit 1; }
	@echo "Explaining $(FILE) with Codex..."
	@codex exec --full-auto "Explain this Swift code file focusing on iOS 26 features, SwiftUI patterns, and audio processing: $(FILE)"

# Fix issue with Codex CLI
codex-fix:
	@if [ -z "$(CODEX_ALLOW_UPLOAD)" ]; then \
		echo "⚠️  WARNING: This will upload code to OpenAI Codex service"; \
		echo "Set CODEX_ALLOW_UPLOAD=1 to proceed: make codex-fix ISSUE='...' CODEX_ALLOW_UPLOAD=1"; \
		exit 1; \
	fi
	@if [ -z "$(ISSUE)" ]; then \
		echo "Usage: make codex-fix ISSUE='description of the issue' CODEX_ALLOW_UPLOAD=1"; \
		exit 1; \
	fi
	@command -v codex >/dev/null 2>&1 || { echo "codex not installed. Install with: npm install -g @openai/codex"; exit 1; }
	@echo "Fixing issue with Codex: $(ISSUE)"
	@codex exec "$(ISSUE)"

# Generate tests with Codex CLI
codex-test:
	@if [ -z "$(CODEX_ALLOW_UPLOAD)" ]; then \
		echo "⚠️  WARNING: This will upload code to OpenAI Codex service"; \
		echo "Set CODEX_ALLOW_UPLOAD=1 to proceed: make codex-test FILE=... CODEX_ALLOW_UPLOAD=1"; \
		exit 1; \
	fi
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make codex-test FILE=path/to/file.swift CODEX_ALLOW_UPLOAD=1"; \
		exit 1; \
	fi
	@command -v codex >/dev/null 2>&1 || { echo "codex not installed. Install with: npm install -g @openai/codex"; exit 1; }
	@echo "Generating tests for $(FILE) with Codex..."
	@codex exec --full-auto "Generate comprehensive Swift Testing (@Test) unit tests for this file with edge cases: $(FILE)"

# Code review with Codex CLI
codex-review:
	@if [ -z "$(CODEX_ALLOW_UPLOAD)" ]; then \
		echo "⚠️  WARNING: This will upload git diff to OpenAI Codex service"; \
		echo "Set CODEX_ALLOW_UPLOAD=1 to proceed: make codex-review CODEX_ALLOW_UPLOAD=1"; \
		exit 1; \
	fi
	@command -v codex >/dev/null 2>&1 || { echo "codex not installed. Install with: npm install -g @openai/codex"; exit 1; }
	@echo "Running Codex code review on staged changes..."
	@TEMP_DIFF=$$(mktemp); \
	trap 'rm -f "$$TEMP_DIFF"' EXIT; \
	git diff --cached > "$$TEMP_DIFF"; \
	if [ ! -s "$$TEMP_DIFF" ]; then \
		echo "No staged changes to review"; \
		exit 1; \
	fi; \
	codex exec --full-auto "Review this git diff for iOS 26 best practices, Swift 6.2 concurrency, security issues, and potential bugs. Provide actionable feedback." < "$$TEMP_DIFF"

# Combined commands for common workflows
all: clean lint build ## Run full build cycle (clean, lint, build)
	@echo "Full build and test cycle complete"