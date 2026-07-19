#!/usr/bin/env python3
"""Independent source-predicate re-verification for WP1 findings."""

from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path


def load(root: Path, relative: str) -> str:
    return (root / relative).read_text(encoding="utf-8")


def check(checks: list[dict[str, object]], finding: str, name: str, condition: bool, detail: str) -> None:
    checks.append(
        {
            "finding": finding,
            "check": name,
            "result": "PASS" if condition else "FAIL",
            "detail": detail,
        }
    )


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: reverify_findings.py REPOSITORY_ROOT DELIVERABLE_ROOT", file=sys.stderr)
        return 2

    repo = Path(sys.argv[1]).resolve()
    delivery = Path(sys.argv[2]).resolve()
    findings = json.loads((delivery / "FINDINGS.json").read_text(encoding="utf-8"))
    checks: list[dict[str, object]] = []

    recommendation = load(repo, "Fonic HiFi/Core/AI/Recommendations/RecommendationService.swift")
    schemas = load(repo, "Fonic HiFi/Core/AI/Recommendations/RecommendationSchemas.swift")
    smart_service = load(repo, "Fonic HiFi/Core/AI/Search/SmartSearchService.swift")
    search_view = load(repo, "Fonic HiFi/Presentation/Views/Search/SearchView.swift")
    search_vm = load(repo, "Fonic HiFi/Presentation/ViewModels/SmartSearchViewModel.swift")
    smart_results = load(repo, "Fonic HiFi/Presentation/Views/Search/SmartSearchResultsView.swift")
    home = load(repo, "Fonic HiFi/Presentation/Views/Home/HomeView.swift")
    quick = load(repo, "Fonic HiFi/Presentation/Views/Home/Sections/QuickActionsSection.swift")
    recent = load(repo, "Fonic HiFi/Data/DataManager+Recent.swift")
    rec_tests = load(repo, "Fonic HiFiTests/Core/AI/RecommendationServiceTests.swift")
    vm_tests = load(repo, "Fonic HiFiTests/Presentation/SmartSearchViewModelTests.swift")
    rec_integration = load(repo, "Fonic HiFiTests/Integration/AIRecommendationsIntegrationTests.swift")
    search_integration = load(repo, "Fonic HiFiTests/Integration/SmartSearchIntegrationTests.swift")
    product_swift = "\n".join(
        p.read_text(encoding="utf-8")
        for p in (repo / "Fonic HiFi").rglob("*.swift")
    )

    check(checks, "FMA-001", "cached shared recommendation session", "private var session: LanguageModelSession?" in recommendation, "RecommendationService caches one session")
    check(checks, "FMA-001", "repeat action remains enabled", "isGeneratingRecommendations" not in quick and ".disabled(" not in quick, "QuickActionsSection does not receive busy state or disable Surprise Me")
    check(checks, "FMA-001", "no session admission guard", "isResponding" not in recommendation, "RecommendationService never checks LanguageModelSession.isResponding")

    check(checks, "FMA-002", "generated identifiers are strings parsed with compactMap", schemas.count("trackIDStrings.compactMap { UUID(uuidString: $0) }") == 4, "All four schemas silently drop malformed UUID strings")
    check(checks, "FMA-002", "exact count guides exist", schemas.count(".count(") == 3, "Greeting and mix schemas request exact array counts")
    check(checks, "FMA-002", "no allowed-set membership validation", "Set(availableTrackIDs)" not in recommendation + smart_service and "allowedTrack" not in recommendation + smart_service, "Service output is returned without checking UUID membership")
    check(checks, "FMA-002", "downstream drops unresolved IDs", "return ids.compactMap { trackMap[$0] }" in recent, "Database boundary silently omits unresolved IDs")

    check(checks, "FMA-003", "previous search task canceled", "searchTask?.cancel()" in search_view, "SearchView cancels the previous task")
    check(checks, "FMA-003", "service converts generic error to fallback", 'catch {\n            logger.error("Smart search failed:' in smart_service and "return await fallbackSearch" in smart_service, "Generic catch returns a normal fallback value")
    check(checks, "FMA-003", "no post-model cancellation check", "Task.checkCancellation" not in smart_service + search_vm and "Task.isCancelled" not in smart_service + search_vm, "No cancellation check protects the final state write")
    check(checks, "FMA-003", "view model commits result unconditionally", "smartSearchResult = result" in search_vm and "resultTrackIDs = result.trackIDs" in search_vm, "Result is committed without a request identity guard")

    check(checks, "FMA-004", "availability collapses to Bool", recommendation.count("case .unavailable:") == 1 and smart_service.count("case .unavailable:") == 1, "Both services discard the unavailable reason")
    check(checks, "FMA-004", "no locale preflight", "supportsLocale" not in product_swift and "supportedLanguages" not in product_swift, "Product source has no locale support check")
    check(checks, "FMA-004", "error state defined", "case error(String)" in search_vm, "SmartSearchViewModel defines an error state")
    check(checks, "FMA-004", "error state not rendered", "case .error" not in search_view, "SearchView has no branch for the error state")

    check(checks, "FMA-005", "fallback promises standard search", "let standard search handle it" in smart_service and "Smart search unavailable - use standard search fallback" in smart_service, "Service comments and result name standard-search fallback")
    check(checks, "FMA-005", "fallback contains no track IDs", "trackIDs: []" in smart_service, "Fallback constructs an empty track list")
    check(checks, "FMA-005", "empty AI result becomes noResults", "if result.trackIDs.isEmpty" in search_vm and "searchState = .noResults" in search_vm, "View model maps fallback to no-results")

    check(checks, "FMA-006", "query interpolated into prompt", 'User search query: "\\(query)"' in smart_service, "User text is placed directly in the prompt")
    check(checks, "FMA-006", "metadata interpolated into prompt", '\\(track.title)' in smart_service and '\\(track.artist)' in smart_service, "Imported metadata is placed directly in the prompt")
    check(checks, "FMA-006", "bounded local impact", "tools:" not in recommendation + smart_service and "URLSession" not in recommendation + smart_service and "http://" not in (recommendation + smart_service).lower() and "https://" not in (recommendation + smart_service).lower(), "Direct AI code defines no tool or network path")
    check(checks, "FMA-006", "generated text reaches views", "Text(result.searchStrategy)" in smart_results and "Text(reason)" in smart_results, "Generated strategy and reasons are rendered")

    tautology = "== true ||" in rec_tests and "== true ||" in vm_tests
    check(checks, "FMA-007", "availability assertions are tautological", tautology, "Both availability tests accept either Boolean value")
    check(checks, "FMA-007", "integration tests call production services", "RecommendationService()" in rec_integration and "SmartSearchService()" in search_integration, "Integration tests do not inject a model adapter")
    check(checks, "FMA-007", "no injectable service initializer", "public init() {}" in recommendation and "public init() {}" in smart_service, "Production services construct Apple model/session dependencies internally")

    generation_index = home.find("let greeting = await recommendationService.generateTimeBasedGreeting")
    clear_loading_index = home.find("isLoading = false", generation_index)
    check(checks, "FMA-008", "Home clears loading after generation", generation_index >= 0 and clear_loading_index > generation_index, "Initial blocking loading state remains active through optional model generation")
    check(checks, "FMA-008", "Home blocks on isLoading", 'if isLoading {\n                    ProgressView("Loading your music...")' in home, "Home body shows a blocking progress view while isLoading is true")

    expected_ids = {f"FMA-{i:03d}" for i in range(1, 9)}
    actual_ids = {item["id"] for item in findings["findings"]}
    check(checks, "PACKAGE", "finding IDs complete", actual_ids == expected_ids, f"Found IDs: {sorted(actual_ids)}")

    severity_counts = Counter(item["severity"].lower() for item in findings["findings"])
    declared = findings["counts"]
    counts_match = (
        declared["new"] == len(findings["findings"])
        and declared["critical"] == severity_counts["critical"]
        and declared["high"] == severity_counts["high"]
        and declared["medium"] == severity_counts["medium"]
        and declared["low"] == severity_counts["low"]
    )
    check(checks, "PACKAGE", "severity totals consistent", counts_match, f"Computed: {dict(severity_counts)}")

    location_failures: list[str] = []
    location_pattern = re.compile(r"^(.*\.swift):(\d+)(?:-(\d+))?(?:,.*)?$")
    for item in findings["findings"]:
        for location in item["locations"]:
            match = location_pattern.match(location)
            if not match:
                location_failures.append(f"unparsed:{location}")
                continue
            path, start, end = match.group(1), int(match.group(2)), int(match.group(3) or match.group(2))
            source = repo / path
            if not source.exists():
                location_failures.append(f"missing:{location}")
                continue
            line_count = len(source.read_text(encoding="utf-8").splitlines())
            if start < 1 or end > line_count or start > end:
                location_failures.append(f"range:{location}:file_lines={line_count}")
    check(checks, "PACKAGE", "cited files and primary ranges exist", not location_failures, json.dumps(location_failures))

    failures = [item for item in checks if item["result"] != "PASS"]
    output = {
        "result": "PASS" if not failures else "FAIL",
        "scope": "independent source-predicate and package-consistency re-verification",
        "checks": checks,
        "failureCount": len(failures),
    }
    print(json.dumps(output, indent=2, sort_keys=True))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
