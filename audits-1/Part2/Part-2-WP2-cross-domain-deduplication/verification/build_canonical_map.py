#!/usr/bin/env python3
"""Build the evidence-preserving canonical finding map for WP2."""

from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path

SEVERITY_ORDER = {
    "Unknown": 0,
    "Informational": 1,
    "Low": 2,
    "Medium": 3,
    "High": 4,
    "Critical": 5,
}


def highest(values: list[str]) -> str:
    return max(values, key=lambda value: SEVERITY_ORDER.get(value, -1))


def unique(values: list[str]) -> list[str]:
    return list(dict.fromkeys(value for value in values if value))


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: build_canonical_map.py NORMALIZED_JSON DECISIONS_JSON OUTPUT_JSON", file=sys.stderr)
        return 2

    corpus = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    decisions = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
    by_id = {record["id"]: record for record in corpus["findings"]}
    errors: list[str] = []
    assigned: dict[str, str] = {}
    canonical: list[dict[str, object]] = []

    for decision in decisions["clusters"]:
        member_ids = decision["memberIDs"]
        missing = [finding_id for finding_id in member_ids if finding_id not in by_id]
        reused = [finding_id for finding_id in member_ids if finding_id in assigned]
        if missing:
            errors.append(f"{decision['canonicalID']} missing IDs: {missing}")
        if reused:
            errors.append(f"{decision['canonicalID']} reuses IDs: {reused}")
        members = [by_id[finding_id] for finding_id in member_ids if finding_id in by_id]
        for finding_id in member_ids:
            assigned[finding_id] = decision["canonicalID"]
        severities = [member["severity"] for member in members]
        canonical.append(
            {
                "canonicalID": decision["canonicalID"],
                "canonicalType": "merged",
                "title": decision["title"],
                "highestSourceSeverity": highest(severities),
                "sourceSeverities": {member["id"]: member["severity"] for member in members},
                "memberCount": len(members),
                "memberIDs": member_ids,
                "domains": unique([member["domain"] for member in members]),
                "locations": unique([location for member in members for location in member["locations"]]),
                "rationale": decision["rationale"],
                "preservationRequirements": decision["preserve"],
                "members": members,
            }
        )

    for record in corpus["findings"]:
        if record["id"] in assigned:
            continue
        assigned[record["id"]] = record["id"]
        canonical.append(
            {
                "canonicalID": record["id"],
                "canonicalType": "standalone",
                "title": record["title"],
                "highestSourceSeverity": record["severity"],
                "sourceSeverities": {record["id"]: record["severity"]},
                "memberCount": 1,
                "memberIDs": [record["id"]],
                "domains": [record["domain"]],
                "locations": record["locations"],
                "rationale": "No other source finding met the WP2 merge threshold; retained as a separately actionable record.",
                "preservationRequirements": "Preserve the complete source record without modification.",
                "members": [record],
            }
        )

    source_ids = {record["id"] for record in corpus["findings"]}
    if set(assigned) != source_ids:
        errors.append(f"coverage mismatch missing={sorted(source_ids-set(assigned))} extra={sorted(set(assigned)-source_ids)}")

    canonical.sort(
        key=lambda row: (
            -SEVERITY_ORDER.get(row["highestSourceSeverity"], -1),
            row["canonicalType"] != "merged",
            row["canonicalID"],
        )
    )
    source_severity_counts = Counter(record["severity"] for record in corpus["findings"])
    canonical_severity_counts = Counter(record["highestSourceSeverity"] for record in canonical)
    merged_members = sum(row["memberCount"] for row in canonical if row["canonicalType"] == "merged")
    merged_clusters = sum(1 for row in canonical if row["canonicalType"] == "merged")
    standalone_count = sum(1 for row in canonical if row["canonicalType"] == "standalone")
    reduction = corpus["sourceFindingCount"] - len(canonical)

    output = {
        "schemaVersion": 1,
        "repositoryCommit": corpus["repositoryCommit"],
        "status": "PASS" if not errors else "FAIL",
        "summary": {
            "sourceFindingCount": corpus["sourceFindingCount"],
            "sourceUniqueIDCount": corpus["uniqueIDCount"],
            "mergedClusterCount": merged_clusters,
            "mergedSourceFindingCount": merged_members,
            "standaloneCanonicalCount": standalone_count,
            "canonicalFindingCount": len(canonical),
            "deduplicatedRecordReduction": reduction,
            "deduplicatedRecordReductionPercent": round(reduction / corpus["sourceFindingCount"] * 100, 2),
            "sourceSeverityCounts": dict(sorted(source_severity_counts.items())),
            "canonicalHighestSeverityCounts": dict(sorted(canonical_severity_counts.items())),
        },
        "sourceToCanonical": dict(sorted(assigned.items())),
        "nearDuplicateNonMerges": decisions["nearDuplicateNonMerges"],
        "canonicalFindings": canonical,
        "errors": errors,
    }
    Path(sys.argv[3]).write_text(json.dumps(output, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"status": output["status"], **output["summary"], "errors": errors}, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
