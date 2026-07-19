#!/usr/bin/env python3
"""Generate conservative duplicate candidates from the normalized audit corpus."""

from __future__ import annotations

import json
import re
import sys
from itertools import combinations
from pathlib import Path

STOP = {
    "the", "a", "an", "and", "or", "to", "of", "in", "on", "for", "is", "are", "be", "as",
    "with", "from", "that", "this", "it", "its", "does", "do", "not", "no", "after", "before",
    "can", "cannot", "without", "all", "every", "has", "have", "into", "by", "while", "when",
    "remediation", "verification", "acceptance", "code", "source", "finding", "current", "existing",
}
TOKEN = re.compile(r"[a-z0-9][a-z0-9+_.-]+")


def tokens(value: str) -> set[str]:
    return {token for token in TOKEN.findall(value.lower()) if token not in STOP and len(token) > 2}


def jaccard(left: set[str], right: set[str]) -> float:
    if not left or not right:
        return 0.0
    return len(left & right) / len(left | right)


def location_paths(values: list[str]) -> set[str]:
    output: set[str] = set()
    for value in values:
        path = re.sub(r":\d[\d,\-]*$", "", value)
        output.add(path)
    return output


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: generate_dedup_candidates.py NORMALIZED_JSON OUTPUT_JSON", file=sys.stderr)
        return 2
    corpus = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    records = corpus["findings"]
    pairs: list[dict[str, object]] = []

    for left, right in combinations(records, 2):
        left_title, right_title = tokens(left["title"]), tokens(right["title"])
        left_rem, right_rem = tokens(left["remediation"]), tokens(right["remediation"])
        left_impact, right_impact = tokens(left["domainImpact"]), tokens(right["domainImpact"])
        left_locations, right_locations = location_paths(left["locations"]), location_paths(right["locations"])

        title_score = jaccard(left_title, right_title)
        remediation_score = jaccard(left_rem, right_rem)
        impact_score = jaccard(left_impact, right_impact)
        location_score = jaccard(left_locations, right_locations)
        related = right["id"] in left["relatedIDs"] or left["id"] in right["relatedIDs"]
        shared_locations = sorted(left_locations & right_locations)

        score = (
            0.34 * title_score
            + 0.28 * remediation_score
            + 0.18 * impact_score
            + 0.20 * location_score
            + (0.12 if related else 0.0)
        )
        include = (
            score >= 0.23
            or title_score >= 0.34
            or remediation_score >= 0.42
            or location_score >= 0.50
            or (related and (title_score >= 0.15 or remediation_score >= 0.20 or location_score > 0))
        )
        if include:
            pairs.append(
                {
                    "leftID": left["id"],
                    "rightID": right["id"],
                    "leftDomain": left["domain"],
                    "rightDomain": right["domain"],
                    "leftTitle": left["title"],
                    "rightTitle": right["title"],
                    "scores": {
                        "combined": round(score, 4),
                        "title": round(title_score, 4),
                        "remediation": round(remediation_score, 4),
                        "impact": round(impact_score, 4),
                        "locations": round(location_score, 4),
                    },
                    "explicitlyRelated": related,
                    "sharedLocationPaths": shared_locations,
                }
            )

    pairs.sort(
        key=lambda item: (
            item["scores"]["combined"],
            item["scores"]["locations"],
            item["scores"]["title"],
        ),
        reverse=True,
    )
    output = {
        "schemaVersion": 1,
        "sourceFindingCount": corpus["sourceFindingCount"],
        "candidatePairCount": len(pairs),
        "method": "cross-domain title, remediation, impact, location, and explicit-related similarity; candidates require manual source-section review",
        "pairs": pairs,
    }
    Path(sys.argv[2]).write_text(
        json.dumps(output, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(
        json.dumps(
            {
                "candidatePairCount": len(pairs),
                "topPairs": [
                    {
                        "ids": [pair["leftID"], pair["rightID"]],
                        "score": pair["scores"]["combined"],
                        "sharedLocations": pair["sharedLocationPaths"],
                    }
                    for pair in pairs[:30]
                ],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
