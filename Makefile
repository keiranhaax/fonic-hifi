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

# Detect Homebrew prefix dynamically (works on Intel and ARM Macs)
BREW_PREFIX := $(shell brew --prefix 2>/dev/null || echo /usr/local)

# Tools
XCODEBUILD = xcodebuild
XCBEAUTIFY = $(shell command -v xcbeautify 2>/dev/null && echo xcbeautify || echo cat)
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
.PHONY: all help clean build build-release test test-unit test-ui coverage lint format analyze open check-deps install-deps simulator-boot simulator-shutdown simulator-list run
.PHONY: search find-files find-todos find-viewmodels find-audio find-core stats stats-features tree view
.PHONY: watch-lint watch-build watch-test benchmark-build benchmark-test benchmark-all
.PHONY: ai-explain ai-test-generate ai-review ai-commit pr-create issues diff find-interactive search-interactive parse-errors test-json

# Help target - displays all available commands
help:
	@echo "Fonic HiFi iOS App - Available Commands:"
	@echo ""
	@echo "Build Commands:"
	@echo "  make build          - Build the app in Debug configuration"
	@echo "  make build-release  - Build the app in Release configuration"
	@echo "  make run            - Build and run the app in the simulator"
	@echo "  make clean          - Clean build artifacts and derived data"
	@echo "  make open           - Open the project in Xcode"
	@echo ""
	@echo "Testing Commands:"
	@echo "  make test           - Run all unit and UI tests"
	@echo "  make test-unit      - Run unit tests only (faster)"
	@echo "  make test-ui        - Run UI tests only (slower)"
	@echo "  make coverage       - Generate test coverage report"
	@echo ""
	@echo "Code Quality Commands:"
	@echo "  make lint           - Run SwiftLint"
	@echo "  make format         - Auto-format code using SwiftFormat"
	@echo "  make analyze        - Run static analysis on the codebase"
	@echo ""
	@echo "Search & Navigation (ripgrep, fd, fzf):"
	@echo "  make search PATTERN='text'     - Fast code search"
	@echo "  make find-files PATTERN='*.swift' - Find files by pattern"
	@echo "  make find-todos                - Find all TODO/FIXME comments"
	@echo "  make find-viewmodels           - Locate all ViewModel files"
	@echo "  make find-audio                - Find AudioKit/audio references"
	@echo "  make find-core                 - Find Core module references"
	@echo "  make find-interactive          - Interactive file finder with preview"
	@echo "  make search-interactive        - Interactive code search"
	@echo ""
	@echo "Code Analysis (tokei, eza, bat):"
	@echo "  make stats          - Show code statistics"
	@echo "  make stats-features - Statistics per feature module"
	@echo "  make tree           - Visual project structure"
	@echo "  make view FILE=path - View file with syntax highlighting"
	@echo ""
	@echo "Monitoring & Automation (watchman):"
	@echo "  make watch-lint     - Auto-lint on file changes"
	@echo "  make watch-build    - Auto-build on changes"
	@echo "  make watch-test     - Auto-test on changes"
	@echo ""
	@echo "Performance (hyperfine):"
	@echo "  make benchmark-build - Measure build performance"
	@echo "  make benchmark-test  - Compare test execution times"
	@echo "  make benchmark-all   - Full performance analysis"
	@echo ""
	@echo "AI Assistance (mods, llm):"
	@echo "  make ai-explain FILE=path - Explain code with AI"
	@echo "  make ai-test-generate FILE=path - Generate tests with AI"
	@echo "  make ai-review            - AI code review of changes"
	@echo "  make ai-commit            - Generate commit message"
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
check-deps:
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
install-deps:
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
	@echo "Building $(PROJECT_NAME) (Debug)..."
	@set -o pipefail && $(XCODEBUILD) build \
		-project "$(PROJECT_NAME).xcodeproj" \
		-scheme "$(SCHEME)" \
		-configuration $(CONFIGURATION_DEBUG) \
		-destination "$(DESTINATION)" \
		-derivedDataPath $(BUILD_DIR) \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		| $(XCBEAUTIFY) || exit 1
	@echo "Build complete"

# Build the app in Release configuration
build-release: check-deps
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

# Build and run the app in the simulator
run: build simulator-boot
	@echo "Installing $(PROJECT_NAME) on simulator..."
	@$(XCRUN) simctl install booted "$(BUILD_DIR)/Build/Products/Debug-iphonesimulator/Fonic HiFi.app" || { echo "Failed to install app"; exit 1; }
	@echo "Launching $(PROJECT_NAME)..."
	@$(XCRUN) simctl launch booted $(BUNDLE_ID) || { echo "Failed to launch app"; exit 1; }
	@echo "App is running on simulator"

# Run all tests (unit and UI)
test: check-deps simulator-boot
	@echo "Running all tests..."
	@set -o pipefail && $(XCODEBUILD) test \
		-project "$(PROJECT_NAME).xcodeproj" \
		-scheme "$(SCHEME)" \
		-destination "$(DESTINATION)" \
		-derivedDataPath $(BUILD_DIR) \
		-enableCodeCoverage YES \
		| $(XCBEAUTIFY) || exit 1
	@echo "All tests passed"

# Run unit tests only
test-unit: check-deps simulator-boot
	@echo "Running unit tests..."
	@set -o pipefail && $(XCODEBUILD) test \
		-project "$(PROJECT_NAME).xcodeproj" \
		-scheme "$(SCHEME)" \
		-destination "$(DESTINATION)" \
		-derivedDataPath $(BUILD_DIR) \
		-enableCodeCoverage YES \
		-only-testing:"Fonic HiFiTests" \
		| $(XCBEAUTIFY) || exit 1
	@echo "Unit tests passed"

# Run UI tests only
test-ui: check-deps simulator-boot
	@echo "Running UI tests..."
	@set -o pipefail && $(XCODEBUILD) test \
		-project "$(PROJECT_NAME).xcodeproj" \
		-scheme "$(SCHEME)" \
		-destination "$(DESTINATION)" \
		-derivedDataPath $(BUILD_DIR) \
		-enableCodeCoverage YES \
		-only-testing:"Fonic HiFiUITests" \
		| $(XCBEAUTIFY) || exit 1
	@echo "UI tests passed"

# Generate test coverage report
coverage: test
	@echo "Generating test coverage report..."
	@if [ -d "$(BUILD_DIR)/Build/Products/Debug-iphonesimulator/Fonic HiFi.app" ]; then \
		PROFDATA=$$(find $(BUILD_DIR)/Build/ProfileData -name "Coverage.profdata" 2>/dev/null | head -1); \
		if [ -n "$$PROFDATA" ]; then \
			$(XCRUN) llvm-cov report \
				"$(BUILD_DIR)/Build/Products/Debug-iphonesimulator/Fonic HiFi.app/Fonic HiFi" \
				-instr-profile="$$PROFDATA" \
				-ignore-filename-regex=".*(Tests|Mocks|Generated).*" || echo "Coverage report generation failed."; \
		else \
			echo "No coverage data found. Make sure tests have been run with code coverage enabled."; \
		fi \
	else \
		echo "App not found. Run 'make test' first to generate coverage data."; \
	fi
	@echo "Coverage report complete"

# Run SwiftLint
lint:
	@echo "Running SwiftLint..."
	@if command -v $(SWIFTLINT) >/dev/null 2>&1; then \
		$(SWIFTLINT) lint --strict --reporter emoji || exit 1; \
	else \
		echo "SwiftLint not installed. Run 'make install-deps' to install it."; \
		exit 1; \
	fi
	@echo "Linting complete"

# Auto-format code using SwiftFormat
format:
	@echo "Formatting code with SwiftFormat..."
	@if command -v $(SWIFTFORMAT) >/dev/null 2>&1; then \
		$(SWIFTFORMAT) . --swiftversion 6.2 --verbose; \
	else \
		echo "SwiftFormat not installed. Run 'make install-deps' to install it."; \
		exit 1; \
	fi
	@echo "Formatting complete"

# Run static analysis
analyze: check-deps
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
open:
	@echo "Opening project in Xcode..."
	@open "$(PROJECT_NAME).xcodeproj"

# Boot the simulator
simulator-boot:
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
search:
	@if [ -z "$(PATTERN)" ]; then \
		echo "Usage: make search PATTERN='your search term'"; \
		exit 1; \
	fi
	@command -v $(RG) >/dev/null 2>&1 || { echo "ripgrep not installed. Install with: brew install ripgrep"; exit 1; }
	@echo "Searching for '$(PATTERN)'..."
	@$(RG) "$(PATTERN)" "Fonic HiFi" --type swift --line-number --column --pretty || echo "No matches found"

# Find files using fd
find-files:
	@if [ -z "$(PATTERN)" ]; then \
		echo "Usage: make find-files PATTERN='*.swift'"; \
		exit 1; \
	fi
	@command -v $(FD) >/dev/null 2>&1 || { echo "fd not installed. Install with: brew install fd"; exit 1; }
	@echo "Finding files matching '$(PATTERN)'..."
	@$(FD) "$(PATTERN)" "Fonic HiFi" --type f || echo "No files found"

# Find all TODO/FIXME comments
find-todos:
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
stats:
	@echo "Code Statistics:"
	@command -v $(TOKEI) >/dev/null 2>&1 || { echo "tokei not installed. Install with: brew install tokei"; exit 1; }
	@$(TOKEI) --type=Swift --sort lines "Fonic HiFi"

# Statistics per feature module
stats-features:
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
tree:
	@echo "Project Structure:"
	@$(EZA) --tree --level=3 --icons --ignore-glob=".git|build|DerivedData|*.xcodeproj" "Fonic HiFi/"

# View file with syntax highlighting
view:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make view FILE=path/to/file.swift"; \
		exit 1; \
	fi
	@$(BAT) --style=full --language=swift "$(FILE)" || echo "File not found: $(FILE)"

# ===== MONITORING & AUTOMATION COMMANDS =====

# Auto-lint on file changes
watch-lint:
	@echo "Watching for changes to run SwiftLint..."
	@$(WATCHMAN) watch-del-all >/dev/null 2>&1 || true
	@$(WATCHMAN) watch-project . >/dev/null 2>&1
	@$(WATCHMAN) -- trigger . swiftlint '*.swift' -- make lint
	@echo "Watching for Swift file changes. Press Ctrl+C to stop."
	@$(WATCHMAN) -- trigger-list . | $(JQ) '.'

# Auto-build on changes
watch-build:
	@echo "Watching for changes to rebuild..."
	@$(WATCHMAN) watch-del-all >/dev/null 2>&1 || true
	@$(WATCHMAN) watch-project . >/dev/null 2>&1
	@$(WATCHMAN) -- trigger . rebuild '*.swift' '*.storyboard' '*.xib' -- make build
	@echo "Watching for changes. Press Ctrl+C to stop."
	@$(WATCHMAN) -- trigger-list . | $(JQ) '.'

# Auto-test on changes
watch-test:
	@echo "Watching for changes to run tests..."
	@$(WATCHMAN) watch-del-all >/dev/null 2>&1 || true
	@$(WATCHMAN) watch-project . >/dev/null 2>&1
	@$(WATCHMAN) -- trigger . test '*.swift' -- make test-unit
	@echo "Watching for test changes. Press Ctrl+C to stop."
	@$(WATCHMAN) -- trigger-list . | $(JQ) '.'

# ===== PERFORMANCE BENCHMARKING =====

# Benchmark build performance
benchmark-build:
	@echo "Benchmarking build performance..."
	@$(HYPERFINE) --warmup 1 --runs 3 \
		'make clean build' \
		--export-markdown benchmark-build.md
	@echo "Results saved to benchmark-build.md"

# Benchmark test execution
benchmark-test:
	@echo "Benchmarking test performance..."
	@$(HYPERFINE) --warmup 1 --runs 3 \
		'make test-unit' \
		--export-markdown benchmark-test.md
	@echo "Results saved to benchmark-test.md"

# Full performance analysis
benchmark-all:
	@echo "Running full performance analysis..."
	@$(HYPERFINE) --warmup 1 --runs 3 \
		'make clean build' \
		'make test-unit' \
		'make lint' \
		--export-markdown benchmark-all.md
	@echo "Results saved to benchmark-all.md"

# ===== AI ASSISTANCE COMMANDS =====

# Explain code with AI
ai-explain:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make ai-explain FILE=path/to/file.swift"; \
		exit 1; \
	fi
	@echo "Explaining $(FILE)..."
	@cat "$(FILE)" | $(MODS) "Explain this Swift code, focusing on audio processing and SwiftUI patterns used"

# Generate tests with AI
ai-test-generate:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make ai-test-generate FILE=path/to/file.swift"; \
		exit 1; \
	fi
	@echo "Generating tests for $(FILE)..."
	@cat "$(FILE)" | $(MODS) "Write comprehensive XCTest unit tests for this Swift code, including edge cases"

# AI code review of changes
ai-review:
	@echo "Running AI code review on staged changes..."
	@git diff --cached | $(MODS) "Review this code diff for iOS best practices, Swift 6 concurrency, and potential bugs"

# Generate commit message with AI
ai-commit:
	@echo "Generating commit message..."
	@git diff --cached | $(MODS) "Generate a concise, conventional commit message for these changes. Format: type(scope): description"

# ===== GIT & GITHUB INTEGRATION =====

# Create pull request
pr-create:
	@echo "Creating pull request..."
	@$(GH) pr create --fill --web

# List GitHub issues
issues:
	@echo "GitHub Issues:"
	@$(GH) issue list --label "ios" --limit 20

# Colored git diff
diff:
	@echo "Git diff with syntax highlighting:"
	@git diff | $(BAT) --language=diff --style=changes

# ===== XCODE BUILD OUTPUT PARSING =====

# Parse Xcode build output for errors
parse-errors:
	@echo "Parsing last build for errors..."
	@$(XCODEBUILD) build -project "$(PROJECT_NAME).xcodeproj" -scheme "$(SCHEME)" -destination "$(DESTINATION)" 2>&1 | \
		$(RG) "error:|warning:" --color=always || echo "No errors or warnings found"

# Extract test results as JSON
test-json:
	@echo "Extracting test results as JSON..."
	@$(XCODEBUILD) test -project "$(PROJECT_NAME).xcodeproj" -scheme "$(SCHEME)" -destination "$(DESTINATION)" -resultBundlePath result.xcresult 2>&1 >/dev/null
	@xcrun xcresulttool get --format json --path result.xcresult | $(JQ) '.metrics'

# Combined commands for common workflows
all: clean lint build test
	@echo "Full build and test cycle complete"