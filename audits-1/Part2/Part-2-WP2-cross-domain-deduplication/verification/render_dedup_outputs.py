#!/usr/bin/env python3
"""Render human-readable WP2 decision evidence and source mapping CSV."""

from __future__ import annotations

import csv
import json
import re
import sys
from pathlib import Path


def base_path(value: str) -> str:
    return re.sub(r":\d[\d,\-]*$", "", value)


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: render_dedup_outputs.py CANONICAL_JSON DECISION_LOG_MD MAPPING_CSV", file=sys.stderr)
        return 2

    canonical = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    rows = canonical["canonicalFindings"]
    merged = [row for row in rows if row["canonicalType"] == "merged"]
    lines = [
        "# WP2 cross-domain deduplication decision log",
        "",
        "This log records every accepted merge and the principal near-duplicate groups deliberately kept separate. Complete original finding sections are preserved in CANONICAL_FINDINGS.json and evidence/NORMALIZED_FINDINGS.json.",
        "",
        "## Accepted canonical clusters",
        "",
    ]

    for row in sorted(merged, key=lambda value: value["canonicalID"]):
        lines.extend(
            [
                f"### {row['canonicalID']}: {row['title']}",
                "",
                f"- Highest source severity: {row['highestSourceSeverity']}",
                f"- Members: {', '.join(row['memberIDs'])}",
                f"- Domains: {', '.join(row['domains'])}",
                f"- Rationale: {row['rationale']}",
                f"- Evidence to preserve: {row['preservationRequirements']}",
                "",
                "Member records:",
                "",
            ]
        )
        location_sets = [{base_path(value) for value in member["locations"]} for member in row["members"]]
        shared = set.intersection(*location_sets) if location_sets else set()
        lines.append("- Shared path anchors: " + (", ".join(sorted(shared)) if shared else "No single path shared by every member; cluster is connected through pairwise path/explicit-related anchors."))
        for member in row["members"]:
            lines.extend(
                [
                    f"- {member['id']} [{member['severity']}; {member['domain']}] {member['title']}",
                    f"  - Source: {member['sourceFile']} lines {member['sourceSectionLines']}",
                    "  - Locations: " + ("; ".join(member["locations"]) if member["locations"] else "[none extracted]"),
                    "  - Domain impact: " + member["domainImpact"].replace("\n", " "),
                    "  - Remediation: " + member["remediation"].replace("\n", " "),
                ]
            )
        lines.append("")

    lines.extend(["## Near-duplicate groups retained separately", ""])
    for item in canonical["nearDuplicateNonMerges"]:
        lines.extend(
            [
                f"### {', '.join(item['ids'])}",
                "",
                item["reason"],
                "",
            ]
        )

    Path(sys.argv[2]).write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")

    by_source: list[dict[str, str]] = []
    for row in rows:
        for member in row["members"]:
            by_source.append(
                {
                    "source_id": member["id"],
                    "canonical_id": row["canonicalID"],
                    "canonical_type": row["canonicalType"],
                    "source_severity": member["severity"],
                    "canonical_highest_severity": row["highestSourceSeverity"],
                    "domain": member["domain"],
                    "source_report": member["sourceFile"],
                    "source_section_lines": member["sourceSectionLines"],
                    "source_title": member["title"],
                    "canonical_title": row["title"],
                }
            )
    by_source.sort(key=lambda value: value["source_id"])
    with Path(sys.argv[3]).open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(by_source[0]))
        writer.writeheader()
        writer.writerows(by_source)
    print(json.dumps({"decisionLogClusters": len(merged), "mappingRows": len(by_source)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
