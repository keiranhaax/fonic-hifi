SHELL := /bin/zsh
.DEFAULT_GOAL := help

# Canonical project contract
PROJECT_NAME := Fonic HiFi
PROJECT := $(PROJECT_NAME).xcodeproj
SCHEME := Fonic HiFi
BUNDLE_ID := ai.keiranlabs.Fonic-HiFi
CONFIGURATION_DEBUG := Debug
CONFIGURATION_RELEASE := Release
IOS_MAJOR := 27
SIMULATOR_NAME ?= iPhone 17 Pro

# Prefer the selected full Xcode; fall back to the installed Xcode 27 beta when
# xcode-select still points at CommandLineTools. Callers may override this.
SELECTED_DEVELOPER_DIR := $(shell /usr/bin/xcode-select -p 2>/dev/null)
DEVELOPER_DIR ?= $(if $(findstring /Applications/Xcode,$(SELECTED_DEVELOPER_DIR)),$(SELECTED_DEVELOPER_DIR),/Applications/Xcode-beta.app/Contents/Developer)
export DEVELOPER_DIR
export PATH := /opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

XCODEBUILD := $(DEVELOPER_DIR)/usr/bin/xcodebuild
XCRUN := /usr/bin/xcrun
PYTHON := /usr/bin/python3
BREW := $(firstword $(wildcard /opt/homebrew/bin/brew /usr/local/bin/brew))
SWIFTLINT := $(shell command -v swiftlint 2>/dev/null || printf '/opt/homebrew/bin/swiftlint')
SWIFTFORMAT := $(shell command -v swiftformat 2>/dev/null || printf '/opt/homebrew/bin/swiftformat')
XCBEAUTIFY := $(shell command -v xcbeautify 2>/dev/null || printf 'cat')

# Generated outputs stay below build/.
BUILD_DIR := build
DERIVED_DATA := $(BUILD_DIR)/DerivedData
RESULTS_DIR := $(BUILD_DIR)/Results
COVERAGE_DIR := $(BUILD_DIR)/Coverage
RESULT_BUNDLE := $(RESULTS_DIR)/TestResults.xcresult
UNIT_RESULT_BUNDLE := $(RESULTS_DIR)/UnitTestResults.xcresult
UI_RESULT_BUNDLE := $(RESULTS_DIR)/UITestResults.xcresult
FOCUS_RESULT_BUNDLE := $(RESULTS_DIR)/FocusTestResults.xcresult
# Skip inventory for the shared lanes. Capability-only coverage belongs in an
# explicit dedicated lane instead of silently widening these gates.
ALL_TEST_ALLOWED_SKIPS := 0
UNIT_TEST_ALLOWED_SKIPS := 0
UI_TEST_ALLOWED_SKIPS := 0
FOCUS_TEST_ALLOWED_SKIPS := 0
OVERALL_COVERAGE_THRESHOLD ?= 0
APP_COVERAGE_THRESHOLD ?= 0
COVERAGE_MIN_PERCENT ?= 40
APP_COVERAGE_MIN_PERCENT ?= 40

# Resolve the newest installed iOS 27 runtime and the matching simulator UDID.
SIMULATOR_OS ?= $(shell $(XCRUN) simctl list runtimes available -j 2>/dev/null | $(PYTHON) -c 'import json, sys; major="$(IOS_MAJOR)."; data=json.load(sys.stdin); versions=[r.get("version", "") for r in data.get("runtimes", []) if r.get("isAvailable", False) and r.get("version", "").startswith(major)]; print(sorted(versions, key=lambda value: tuple(int(part) for part in value.split(".")))[-1] if versions else "")' 2>/dev/null)
SIMULATOR_ID ?= $(shell $(XCRUN) simctl list devices available -j 2>/dev/null | $(PYTHON) -c 'import json, sys; runtime_id="com.apple.CoreSimulator.SimRuntime.iOS-$(subst .,-,$(SIMULATOR_OS))"; name="$(SIMULATOR_NAME)"; data=json.load(sys.stdin); print(next((device["udid"] for runtime, devices in data.get("devices", {}).items() if runtime == runtime_id for device in devices if device.get("name") == name and device.get("isAvailable", False)), ""))' 2>/dev/null)
DESTINATION := platform=iOS Simulator,id=$(SIMULATOR_ID)
APP_PATH := $(DERIVED_DATA)/Build/Products/Debug-iphonesimulator/$(PROJECT_NAME).app

XCODE_COMMON_FLAGS = \
	-project "$(PROJECT)" \
	-scheme "$(SCHEME)" \
	-destination "$(DESTINATION)" \
	-derivedDataPath "$(DERIVED_DATA)" \
	-onlyUsePackageVersionsFromResolvedFile

.PHONY: help check-deps install-deps clean lint format build build-release test test-unit test-ui test-focus coverage coverage-check analyze open run
.PHONY: simulator-list simulator-boot simulator-shutdown logs-show logs-stream logs-errors logs-audio

help: ## Show the canonical local commands
	@echo "Fonic HiFi iOS 27 local commands"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-22s %s\n", $$1, $$2}'
	@echo ""
	@echo "Default destination: $(SIMULATOR_NAME), latest installed iOS $(IOS_MAJOR).x"

check-deps: ## Validate Xcode 27, iOS 27 simulator, and required local tools
	@echo "Checking the Fonic HiFi development environment..."
	@test -d "$(PROJECT)" || { echo "[FAIL] Missing $(PROJECT)"; exit 1; }
	@test -f "$(PROJECT)/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" || { echo "[FAIL] Missing authoritative Package.resolved"; exit 1; }
	@test -x "$(XCODEBUILD)" || { echo "[FAIL] xcodebuild not found below $(DEVELOPER_DIR)"; exit 1; }
	@test -x "$(XCRUN)" || { echo "[FAIL] xcrun not found below $(DEVELOPER_DIR)"; exit 1; }
	@XCODE_VERSION=$$($(XCODEBUILD) -version | awk '/^Xcode / { print $$2 }'); \
		case "$$XCODE_VERSION" in 27.*) echo "[OK] Xcode $$XCODE_VERSION ($(DEVELOPER_DIR))" ;; \
		*) echo "[FAIL] Xcode 27.x is required; selected $$XCODE_VERSION at $(DEVELOPER_DIR)"; exit 1 ;; \
		esac
	@test -x "$(PYTHON)" || { echo "[FAIL] /usr/bin/python3 is required"; exit 1; }
	@test -n "$(SIMULATOR_OS)" || { echo "[FAIL] No available iOS $(IOS_MAJOR).x runtime found"; exit 1; }
	@test -n "$(SIMULATOR_ID)" || { echo "[FAIL] No available $(SIMULATOR_NAME) on iOS $(IOS_MAJOR).x found"; exit 1; }
	@echo "[OK] $(SIMULATOR_NAME) iOS $(SIMULATOR_OS) ($(SIMULATOR_ID))"
	@test -x "$(SWIFTLINT)" || { echo "[FAIL] SwiftLint is required; run 'make install-deps'"; exit 1; }
	@echo "[OK] SwiftLint"
	@test -x "$(SWIFTFORMAT)" || { echo "[FAIL] SwiftFormat is required; run 'make install-deps'"; exit 1; }
	@echo "[OK] SwiftFormat"
	@if [ "$(XCBEAUTIFY)" = "cat" ]; then echo "[INFO] xcbeautify unavailable; raw xcodebuild output will be used"; else echo "[OK] xcbeautify"; fi

install-deps: ## Install the repository's Homebrew development tools
	@test -n "$(BREW)" && test -x "$(BREW)" || { echo "Homebrew is required and will not be installed automatically."; exit 1; }
	@command -v swiftlint >/dev/null 2>&1 || $(BREW) install swiftlint
	@command -v swiftformat >/dev/null 2>&1 || $(BREW) install swiftformat
	@command -v xcbeautify >/dev/null 2>&1 || $(BREW) install xcbeautify

clean: ## Delete only repository-local generated build output
	@rm -rf "$(BUILD_DIR)"
	@echo "Removed $(BUILD_DIR)/"

lint: ## Run strict SwiftLint checks
	@test -x "$(SWIFTLINT)" || { echo "SwiftLint is not installed. Run 'make install-deps'."; exit 1; }
	@$(SWIFTLINT) lint --strict --reporter emoji

format: ## Rewrite Swift sources with SwiftFormat in Swift 6 language mode
	@test -x "$(SWIFTFORMAT)" || { echo "SwiftFormat is not installed. Run 'make install-deps'."; exit 1; }
	@$(SWIFTFORMAT) . --swiftversion 6.0 --verbose

build: check-deps ## Compile an unsigned Debug simulator build
	@mkdir -p "$(RESULTS_DIR)"
	@set -o pipefail; $(XCODEBUILD) build \
		$(XCODE_COMMON_FLAGS) \
		-configuration "$(CONFIGURATION_DEBUG)" \
		CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
		2>&1 | tee "$(RESULTS_DIR)/build-debug.log" | $(XCBEAUTIFY)

build-release: check-deps ## Compile an unsigned Release simulator build
	@mkdir -p "$(RESULTS_DIR)"
	@set -o pipefail; $(XCODEBUILD) build \
		$(XCODE_COMMON_FLAGS) \
		-configuration "$(CONFIGURATION_RELEASE)" \
		CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
		2>&1 | tee "$(RESULTS_DIR)/build-release.log" | $(XCBEAUTIFY)

test: check-deps ## Run the shared test plan with coverage and validate the result
	@mkdir -p "$(RESULTS_DIR)"
	@rm -rf "$(RESULT_BUNDLE)"
	@set -o pipefail; $(XCODEBUILD) test \
		$(XCODE_COMMON_FLAGS) \
		-configuration "$(CONFIGURATION_DEBUG)" \
		-enableCodeCoverage YES \
		-resultBundlePath "$(RESULT_BUNDLE)" \
		2>&1 | tee "$(RESULTS_DIR)/test.log" | $(XCBEAUTIFY)
	@$(XCRUN) xcresulttool get test-results summary --path "$(RESULT_BUNDLE)" --format json | \
		$(PYTHON) scripts/validate_test_results.py --label "All tests" --allow-skips "$(ALL_TEST_ALLOWED_SKIPS)"

test-unit: check-deps ## Run only the app unit and integration test target
	@mkdir -p "$(RESULTS_DIR)"
	@rm -rf "$(UNIT_RESULT_BUNDLE)"
	@set -o pipefail; $(XCODEBUILD) test \
		$(XCODE_COMMON_FLAGS) \
		-configuration "$(CONFIGURATION_DEBUG)" \
		-enableCodeCoverage YES \
		-parallel-testing-enabled YES \
		-only-testing:"Fonic HiFiTests" \
		-resultBundlePath "$(UNIT_RESULT_BUNDLE)" \
		2>&1 | tee "$(RESULTS_DIR)/test-unit.log" | $(XCBEAUTIFY)
	@$(XCRUN) xcresulttool get test-results summary --path "$(UNIT_RESULT_BUNDLE)" --format json | \
		$(PYTHON) scripts/validate_test_results.py --label "Unit tests" --allow-skips "$(UNIT_TEST_ALLOWED_SKIPS)"

test-focus: check-deps ## Run focused tests: make test-focus ONLY="Fonic HiFiTests/SomeTests[/testCase]"
	@test -n "$(ONLY)" || { echo "Usage: make test-focus ONLY=\"Fonic HiFiTests/SomeTests[/testCase]\""; exit 1; }
	@mkdir -p "$(RESULTS_DIR)"
	@rm -rf "$(FOCUS_RESULT_BUNDLE)"
	@set -o pipefail; $(XCODEBUILD) test \
		$(XCODE_COMMON_FLAGS) \
		-configuration "$(CONFIGURATION_DEBUG)" \
		-only-testing:"$(ONLY)" \
		-resultBundlePath "$(FOCUS_RESULT_BUNDLE)" \
		2>&1 | tee "$(RESULTS_DIR)/test-focus.log" | $(XCBEAUTIFY)
	@$(XCRUN) xcresulttool get test-results summary --path "$(FOCUS_RESULT_BUNDLE)" --format json | \
		$(PYTHON) scripts/validate_test_results.py --label "Focused tests" --allow-skips "$(FOCUS_TEST_ALLOWED_SKIPS)"

test-ui: check-deps ## Run only the UI test target
	@mkdir -p "$(RESULTS_DIR)"
	@rm -rf "$(UI_RESULT_BUNDLE)"
	@set -o pipefail; $(XCODEBUILD) test \
		$(XCODE_COMMON_FLAGS) \
		-configuration "$(CONFIGURATION_DEBUG)" \
		-only-testing:"Fonic HiFiUITests" \
		-resultBundlePath "$(UI_RESULT_BUNDLE)" \
		2>&1 | tee "$(RESULTS_DIR)/test-ui.log" | $(XCBEAUTIFY)
	@$(XCRUN) xcresulttool get test-results summary --path "$(UI_RESULT_BUNDLE)" --format json | \
		$(PYTHON) scripts/validate_test_results.py --label "UI tests" --allow-skips "$(UI_TEST_ALLOWED_SKIPS)"

coverage: ## Run a fresh full test plan and generate coverage output
	@$(MAKE) test
	@mkdir -p "$(COVERAGE_DIR)"
	@$(XCRUN) xccov view --report --json "$(RESULT_BUNDLE)" > "$(COVERAGE_DIR)/coverage.json"
	@$(XCRUN) xccov view --report "$(RESULT_BUNDLE)"
	@$(PYTHON) scripts/coverage_summary.py "$(COVERAGE_DIR)/coverage.json" \
		--build-dir "$(COVERAGE_DIR)" \
		--overall-threshold "$(OVERALL_COVERAGE_THRESHOLD)" \
		--app-threshold "$(APP_COVERAGE_THRESHOLD)"

coverage-check: ## Run fresh tests and enforce the 40 percent coverage thresholds
	@$(MAKE) coverage \
		OVERALL_COVERAGE_THRESHOLD="$(COVERAGE_MIN_PERCENT)" \
		APP_COVERAGE_THRESHOLD="$(APP_COVERAGE_MIN_PERCENT)"

analyze: check-deps ## Run Release static analysis
	@mkdir -p "$(RESULTS_DIR)"
	@set -o pipefail; $(XCODEBUILD) analyze \
		$(XCODE_COMMON_FLAGS) \
		-configuration "$(CONFIGURATION_RELEASE)" \
		CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
		2>&1 | tee "$(RESULTS_DIR)/analyze-release.log" | $(XCBEAUTIFY)

open: ## Open the primary project in Xcode
	@open "$(PROJECT)"

simulator-list: ## Show available iOS 27 simulators
	@$(XCRUN) simctl list devices available | awk '/-- iOS $(IOS_MAJOR)/ { visible=1; print; next } /^-- / { visible=0 } visible'

simulator-boot: check-deps ## Boot only the selected iOS 27 simulator
	@$(XCRUN) simctl boot "$(SIMULATOR_ID)" 2>/dev/null || true
	@$(XCRUN) simctl bootstatus "$(SIMULATOR_ID)" -b

simulator-shutdown: check-deps ## Shut down only the selected simulator
	@$(XCRUN) simctl shutdown "$(SIMULATOR_ID)" 2>/dev/null || true

run: build simulator-boot ## Build, install, and launch on the selected simulator
	@test -d "$(APP_PATH)" || { echo "Built app not found at $(APP_PATH)"; exit 1; }
	@$(XCRUN) simctl install "$(SIMULATOR_ID)" "$(APP_PATH)"
	@$(XCRUN) simctl launch "$(SIMULATOR_ID)" "$(BUNDLE_ID)"

logs-show: ## Show app logs from the last hour
	@/usr/bin/log show --predicate 'process == "$(PROJECT_NAME)"' --last 1h --style syslog

logs-stream: ## Stream live app debug logs
	@/usr/bin/log stream --predicate 'process == "$(PROJECT_NAME)"' --level debug

logs-errors: ## Show app error logs from the last hour
	@/usr/bin/log show --predicate 'process == "$(PROJECT_NAME)" && level == "error"' --last 1h --style syslog

logs-audio: ## Show app audio-subsystem logs from the last hour
	@/usr/bin/log show --predicate 'process == "$(PROJECT_NAME)" && subsystem CONTAINS "audio"' --last 1h --style syslog
