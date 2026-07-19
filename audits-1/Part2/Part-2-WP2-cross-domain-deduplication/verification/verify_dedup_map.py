#!/usr/bin/env python3
"""Verify WP2 canonical-map coverage and evidence preservation."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from collections import Counter, defaultdict, deque
from pathlib import Path

SEVERITY_ORDER = {
    "Unknown": 0,
    "Informational": 1,
    "Low": 2,
    "Medium": 3,
    "High": 4,
    "Critical": 5,
}
EXPECTED_COMMIT = "459db9bfd18d17960e8fd2ff8defc4701085532e"


def base_path(value: str) -> str:
    return re.sub(r":\d[\d,\-]*$", "", value)


def connected_by_location_or_relation(members: list[dict[str, object]]) -> bool:
    if len(members) < 2:
        return True
    adjacency: dict[str, set[str]] = defaultdict(set)
    for i, left in enumerate(members):
        left_locations = {base_path(value) for value in left["locations"]}
        for right in members[i + 1 :]:
            right_locations = {base_path(value) for value in right["locations"]}
            related = right["id"] in left["relatedIDs"] or left["id"] in right["relatedIDs"]
            if left_locations & right_locations or related:
                adjacency[left["id"]].add(right["id"])
                adjacency[right["id"]].add(left["id"])
    seen: set[str] = set()
    queue: deque[str] = deque([members[0]["id"]])
    while queue:
        current = queue.popleft()
        if current in seen:
            continue
        seen.add(current)
        queue.extend(adjacency[current] - seen)
    return seen == {member["id"] for member in members}


def main() -> int:
    if len(sys.argv) != 5:
        print("usage: verify_dedup_map.py NORMALIZED DECISIONS CANONICAL REPOSITORY", file=sys.stderr)
        return 2

    normalized = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    decisions = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
    canonical = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8"))
    repository = Path(sys.argv[4]).resolve()
    checks: list[dict[str, object]] = []

    def check(name: str, condition: bool, detail: object) -> None:
        checks.append({"check": name, "result": "PASS" if condition else "FAIL", "detail": detail})

    source_records = normalized["findings"]
    source_by_id = {record["id"]: record for record in source_records}
    source_ids = [record["id"] for record in source_records]
    check("normalized source count", len(source_records) == 147, len(source_records))
    check("normalized source IDs unique", len(source_ids) == len(set(source_ids)) == 147, len(set(source_ids)))
    check("normalized parser field gaps", normalized["recordsWithParserFieldGaps"] == [], normalized["recordsWithParserFieldGaps"])

    decision_ids = [cluster["canonicalID"] for cluster in decisions["clusters"]]
    all_members = [finding_id for cluster in decisions["clusters"] for finding_id in cluster["memberIDs"]]
    check("decision cluster count", len(decision_ids) == len(set(decision_ids)) == 26, len(decision_ids))
    check("merged member IDs unique", len(all_members) == len(set(all_members)) == 55, len(all_members))
    check("merged member IDs exist", set(all_members) <= set(source_ids), sorted(set(all_members) - set(source_ids)))
    check("near-duplicate non-merge decisions documented", len(decisions["nearDuplicateNonMerges"]) >= 16, len(decisions["nearDuplicateNonMerges"]))

    expected_summary = {
        "sourceFindingCount": 147,
        "sourceUniqueIDCount": 147,
        "mergedClusterCount": 26,
        "mergedSourceFindingCount": 55,
        "standaloneCanonicalCount": 92,
        "canonicalFindingCount": 118,
        "deduplicatedRecordReduction": 29,
    }
    check("canonical summary counts", all(canonical["summary"].get(key) == value for key, value in expected_summary.items()), canonical["summary"])
    check("canonical build status", canonical["status"] == "PASS" and canonical["errors"] == [], canonical["errors"])

    canonical_rows = canonical["canonicalFindings"]
    mapping = canonical["sourceToCanonical"]
    check("source-to-canonical coverage", set(mapping) == set(source_ids) and len(mapping) == 147, len(mapping))
    check("canonical row count", len(canonical_rows) == 118, len(canonical_rows))

    reconstructed: dict[str, dict[str, object]] = {}
    row_errors: list[str] = []
    anchor_errors: list[str] = []
    for row in canonical_rows:
        member_ids = row["memberIDs"]
        members = row["members"]
        if [member["id"] for member in members] != member_ids:
            row_errors.append(f"{row['canonicalID']}: member order/id mismatch")
        for member in members:
            finding_id = member["id"]
            if source_by_id.get(finding_id) != member:
                row_errors.append(f"{row['canonicalID']}: source record changed for {finding_id}")
            if finding_id in reconstructed:
                row_errors.append(f"{row['canonicalID']}: duplicate source member {finding_id}")
            reconstructed[finding_id] = member
            if mapping.get(finding_id) != row["canonicalID"]:
                row_errors.append(f"{row['canonicalID']}: mapping mismatch for {finding_id}")
        severities = [member["severity"] for member in members]
        expected_highest = max(severities, key=lambda value: SEVERITY_ORDER[value])
        if row["highestSourceSeverity"] != expected_highest:
            row_errors.append(f"{row['canonicalID']}: highest severity mismatch")
        expected_locations = list(dict.fromkeys(location for member in members for location in member["locations"]))
        if row["locations"] != expected_locations:
            row_errors.append(f"{row['canonicalID']}: location union mismatch")
        if row["canonicalType"] == "merged" and not connected_by_location_or_relation(members):
            anchor_errors.append(row["canonicalID"])
        if row["canonicalType"] == "standalone" and (len(member_ids) != 1 or row["canonicalID"] != member_ids[0]):
            row_errors.append(f"{row['canonicalID']}: invalid standalone identity")

    check("every source record preserved byte-for-byte as JSON data", reconstructed == source_by_id, row_errors)
    check("accepted clusters have a connected source-location or explicit-related anchor graph", not anchor_errors, anchor_errors)

    computed_source_severity = dict(sorted(Counter(record["severity"] for record in source_records).items()))
    computed_canonical_severity = dict(sorted(Counter(row["highestSourceSeverity"] for row in canonical_rows).items()))
    check("source severity counts preserved", canonical["summary"]["sourceSeverityCounts"] == computed_source_severity, computed_source_severity)
    check("canonical severity counts computed from highest member severity", canonical["summary"]["canonicalHighestSeverityCounts"] == computed_canonical_severity, computed_canonical_severity)

    reference_errors: list[str] = []
    valid_reference_ids = set(source_ids) | set(decision_ids)
    for item in decisions["nearDuplicateNonMerges"]:
        for value in item["ids"]:
            if value not in valid_reference_ids:
                reference_errors.append(value)
    check("non-merge references resolve", not reference_errors, sorted(set(reference_errors)))

    head = subprocess.check_output(["git", "-C", str(repository), "rev-parse", "HEAD"], text=True).strip()
    status = subprocess.check_output(["git", "-C", str(repository), "status", "--porcelain=v1"], text=True)
    check("repository revision unchanged", head == EXPECTED_COMMIT, head)
    check("repository worktree clean", status == "", status)

    failures = [item for item in checks if item["result"] != "PASS"]
    output = {
        "status": "PASS" if not failures else "FAIL",
        "checkCount": len(checks),
        "failureCount": len(failures),
        "checks": checks,
    }
    print(json.dumps(output, indent=2, ensure_ascii=False))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
