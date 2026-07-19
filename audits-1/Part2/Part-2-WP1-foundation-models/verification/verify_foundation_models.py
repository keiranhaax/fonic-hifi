#!/usr/bin/env python3
"""Read-only structural verification for Fonic HiFi WP1.

This script does not compile Swift or validate Apple runtime behavior. It verifies
repository identity and source-level facts used by the Foundation Models report.
"""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path

EXPECTED_COMMIT = "459db9bfd18d17960e8fd2ff8defc4701085532e"
EXPECTED_IMPORTS = {
    "Fonic HiFi/Core/AI/Recommendations/RecommendationSchemas.swift",
    "Fonic HiFi/Core/AI/Recommendations/RecommendationService.swift",
    "Fonic HiFi/Core/AI/Search/SmartSearchService.swift",
}


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


def count(text: str, token: str) -> int:
    return text.count(token)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: verify_foundation_models.py REPOSITORY_ROOT", file=sys.stderr)
        return 2

    root = Path(sys.argv[1]).resolve()
    failures: list[str] = []
    facts: dict[str, object] = {}

    head = git(root, "rev-parse", "HEAD")
    status = git(root, "status", "--porcelain=v1")
    tracked = git(root, "ls-files").splitlines()
    product_swift = [p for p in tracked if p.startswith("Fonic HiFi/") and p.endswith(".swift")]

    if head != EXPECTED_COMMIT:
        failures.append(f"unexpected commit: {head}")
    if status:
        failures.append("repository worktree is not clean")

    imports = {
        p
        for p in product_swift
        if "import FoundationModels" in (root / p).read_text(encoding="utf-8")
    }
    if imports != EXPECTED_IMPORTS:
        failures.append(f"direct import set differs: {sorted(imports)}")

    direct_text = "\n".join((root / p).read_text(encoding="utf-8") for p in sorted(EXPECTED_IMPORTS))
    all_product_text = "\n".join((root / p).read_text(encoding="utf-8") for p in product_swift)

    expected_counts = {
        "LanguageModelSession constructions": (count(direct_text, "LanguageModelSession("), 2),
        "respond calls": (count(direct_text, ".respond("), 3),
        "cached session properties": (count(direct_text, "private var session: LanguageModelSession?"), 2),
        "availability checks": (count(direct_text, "SystemLanguageModel.default.availability"), 2),
        "Generable schemas": (count(direct_text, "@Generable"), 4),
        "exact-count array guides": (count(direct_text, ".count("), 3),
        "isResponding guards in product": (count(all_product_text, "isResponding"), 0),
        "locale-support preflight in product": (count(all_product_text, "supportsLocale"), 0),
        "supportedLanguages preflight in product": (count(all_product_text, "supportedLanguages"), 0),
        "Foundation Models tools in direct code": (count(direct_text, "tools:"), 0),
        "URLSession in direct code": (count(direct_text, "URLSession"), 0),
        "HTTP literals in direct code": (count(direct_text.lower(), "http://") + count(direct_text.lower(), "https://"), 0),
    }

    for name, (actual, expected) in expected_counts.items():
        facts[name] = actual
        if actual != expected:
            failures.append(f"{name}: expected {expected}, got {actual}")

    source_hashes = {
        p: hashlib.sha256((root / p).read_bytes()).hexdigest()
        for p in sorted(EXPECTED_IMPORTS)
    }

    result = {
        "result": "PASS" if not failures else "FAIL",
        "scope": "source-structure only; not a compile or runtime check",
        "repositoryCommit": head,
        "repositoryClean": not bool(status),
        "trackedFiles": len(tracked),
        "trackedProductSwiftFiles": len(product_swift),
        "directFoundationModelsImports": sorted(imports),
        "facts": facts,
        "sourceHashes": source_hashes,
        "failures": failures,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
