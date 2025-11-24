#!/usr/bin/env python3

import argparse
import csv
import datetime as dt
import json
from pathlib import Path
from typing import Any, Dict, Iterable, List, Tuple


def compute_pct(covered: int, executable: int) -> float:
    return (covered / executable * 100) if executable else 0.0


def extract_target(targets: Iterable[Dict[str, Any]], suffix: str) -> Dict[str, Any] | None:
    for target in targets:
        name = target.get("name", "")
        if name.endswith(suffix):
            return target
    return None


def format_line(name: str, covered: int, executable: int) -> str:
    return f"{name}: {compute_pct(covered, executable):.2f}% ({covered}/{executable})"


def load_data(path: Path) -> Dict[str, Any]:
    if not path.exists():
        raise SystemExit(f"Coverage report not found at {path}")
    return json.loads(path.read_text())


def write_history(path: Path, row: Tuple[str, str, int, int, str, int, int, str, int, int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    write_header = not path.exists()
    with path.open("a", newline="") as csvfile:
        writer = csv.writer(csvfile)
        if write_header:
            writer.writerow(
                [
                    "timestamp",
                    "overall_percent",
                    "overall_covered",
                    "overall_executable",
                    "app_percent",
                    "app_covered",
                    "app_executable",
                    "test_percent",
                    "test_covered",
                    "test_executable",
                ]
            )
        writer.writerow(row)


def format_failures(failures: List[str]) -> str:
    return "\n".join(f"❌ {failure}" for failure in failures)


def main() -> None:
    parser = argparse.ArgumentParser(description="Summarise xccov coverage JSON output")
    parser.add_argument("coverage_json", type=Path)
    parser.add_argument("--build-dir", type=Path, required=True)
    parser.add_argument("--overall-threshold", type=float, default=0.0)
    parser.add_argument("--app-threshold", type=float, default=0.0)
    parser.add_argument("--skip-history", action="store_true")
    args = parser.parse_args()

    data = load_data(args.coverage_json)
    targets = data.get("targets", [])

    total_covered = int(data.get("coveredLines", 0))
    total_executable = int(data.get("executableLines", 0))
    overall_pct = compute_pct(total_covered, total_executable)

    app_target = extract_target(targets, ".app")
    test_target = extract_target(targets, ".xctest")

    app_cov = int(app_target.get("coveredLines", 0)) if app_target else 0
    app_exec = int(app_target.get("executableLines", 0)) if app_target else 0
    app_pct = compute_pct(app_cov, app_exec) if app_target else 0.0

    test_cov = int(test_target.get("coveredLines", 0)) if test_target else 0
    test_exec = int(test_target.get("executableLines", 0)) if test_target else 0
    test_pct = compute_pct(test_cov, test_exec) if test_target else 0.0

    overall_threshold = args.overall_threshold if args.overall_threshold > 0 else None
    app_threshold = args.app_threshold if args.app_threshold > 0 else None

    timestamp = dt.datetime.now().isoformat(timespec="seconds")
    lines = [
        f"Coverage Summary @ {timestamp}",
        f"Overall: {overall_pct:.2f}% ({total_covered}/{total_executable})",
    ]

    for target in targets:
        covered = int(target.get("coveredLines", 0))
        executable = int(target.get("executableLines", 0))
        lines.append(format_line(target.get("name", "Unknown"), covered, executable))

    summary_text = "\n".join(lines) + "\n"

    summary_path = args.build_dir / "coverage-summary.txt"
    summary_path.write_text(summary_text)

    print(summary_text, end="")
    print(f"Summary saved to {summary_path}")

    if not args.skip_history:
        history_path = args.build_dir / "coverage-history.csv"
        write_history(
            history_path,
            (
                timestamp,
                f"{overall_pct:.2f}",
                total_covered,
                total_executable,
                f"{app_pct:.2f}" if app_target else "",
                app_cov if app_target else "",
                app_exec if app_target else "",
                f"{test_pct:.2f}" if test_target else "",
                test_cov if test_target else "",
                test_exec if test_target else "",
            ),
        )
        print(f"History updated at {history_path}")

    failures: List[str] = []
    if overall_threshold is not None and overall_pct + 1e-9 < overall_threshold:
        failures.append(
            f"Overall coverage {overall_pct:.2f}% is below required {overall_threshold:.2f}%"
        )

    if app_threshold is not None:
        if app_target is None:
            failures.append("App target coverage data not found for threshold evaluation")
        elif app_pct + 1e-9 < app_threshold:
            failures.append(
                f"App target coverage {app_pct:.2f}% is below required {app_threshold:.2f}%"
            )

    if failures:
        print(format_failures(failures))
        raise SystemExit(1)

    if overall_threshold is not None or app_threshold is not None:
        print("✅ Coverage thresholds satisfied")


if __name__ == "__main__":
    main()
