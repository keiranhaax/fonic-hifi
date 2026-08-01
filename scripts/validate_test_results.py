#!/usr/bin/env python3
"""Fail validation for bad xcresult summaries or incompatible widget contracts."""

import argparse
import json
from pathlib import Path
import subprocess
import sys


def verify_widget_contracts() -> int:
    verifier = Path(__file__).with_name("verify_widget_contracts.py")
    result = subprocess.run([sys.executable, str(verifier)], check=False)
    if result.returncode != 0:
        print("Widget contract validation failed", file=sys.stderr)
    return result.returncode


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--label", default="Tests")
    parser.add_argument("--allow-skips", type=int, default=0)
    args = parser.parse_args()
    summary = json.load(sys.stdin)

    total = int(summary.get("totalTestCount", 0))
    passed = int(summary.get("passedTests", 0))
    failed = int(summary.get("failedTests", 0))
    skipped = int(summary.get("skippedTests", 0))
    print(f"{args.label}: {total} total, {passed} passed, {failed} failed, {skipped} skipped")

    errors = []
    if total <= 0:
        errors.append("no tests executed")
    if failed > 0:
        errors.append(f"{failed} tests failed")
    if skipped > args.allow_skips:
        errors.append(f"{skipped} tests skipped; allowed {args.allow_skips}")
    if errors:
        print(f"{args.label} validation failed: {'; '.join(errors)}", file=sys.stderr)
        return 1
    return verify_widget_contracts()


if __name__ == "__main__":
    raise SystemExit(main())
