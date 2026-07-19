#!/usr/bin/env python3
"""Normalize existing Fonic HiFi audit findings for WP2 deduplication.

The parser reads prior reports and the completed WP1 report. It does not read or
modify repository source. Output preserves source pointers, severities, evidence
blocks, impact text, remediation, verification text, locations, and cross-links.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

PRIOR_HEADING = re.compile(r"^###\s+([A-Z][A-Z0-9]*(?:-[A-Z0-9]+)*-\d{3})\s+[—-]\s+(.+?)\s*$")
WP1_HEADING = re.compile(r"^##\s+(FMA-\d{3}):\s+(.+?)\s*$")
ID_PATTERN = re.compile(r"\b[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)*-\d{3}\b")
SEVERITY_PATTERN = re.compile(r"^- (?:\*\*)?Severity:(?:\*\*)?\s*(.+?)\s*$", re.M)
CONFIDENCE_PATTERN = re.compile(r"^- (?:\*\*)?Confidence:(?:\*\*)?\s*(.+?)\s*$", re.M)
INLINE_CODE = re.compile(r"`([^`\n]+)`")
PATH_PATTERN = re.compile(
    r"(?:^|/|\\)(?:[^\n]+?)\.(?:swift|yml|yaml|json|plist|pbxproj|xcconfig|md|sh|py|xcprivacy|entitlements)(?::[\d,\-]+)?$",
    re.I,
)

DOMAIN_MAP = {
    "01_Audio_Reliability.md": "Audio Reliability",
    "02_Data_Library_Persistence.md": "Data, Library, and Persistence",
    "03_Concurrency_Performance.md": "Concurrency and Performance",
    "04_UI_UX.md": "UI and UX",
    "05_Accessibility_Localization.md": "Accessibility and Localization",
    "06_Project_Configuration.md": "Project Configuration",
    "07_Privacy_Security_Release.md": "Privacy, Security, and Release",
    "08_Dead_Partial_Artifacts.md": "Dead, Partial, and Artifacts",
    "09_Testing_Release_Verification.md": "Testing and Release Verification",
    "WP1_FOUNDATION_MODELS_REVIEW.md": "Foundation Models",
}


def field(text: str, labels: list[str]) -> str:
    for label in labels:
        pattern = re.compile(
            rf"^- (?:\*\*)?{re.escape(label)}:(?:\*\*)?\s*(.*?)(?=^- (?:\*\*)?[^\n]+:(?:\*\*)?|\Z)",
            re.M | re.S,
        )
        match = pattern.search(text)
        if match:
            return match.group(1).strip()
    return ""


def heading_field(text: str, labels: list[str]) -> str:
    for label in labels:
        pattern = re.compile(
            rf"^###\s+{re.escape(label)}\s*$\n(.*?)(?=^###\s+|^##\s+|^#\s+|\Z)",
            re.M | re.S | re.I,
        )
        match = pattern.search(text)
        if match:
            return match.group(1).strip()
    return ""


def code_locations(section: str) -> list[str]:
    values: list[str] = []
    seen: set[str] = set()
    for token in INLINE_CODE.findall(section):
        candidate = token.strip().replace("\\ ", " ")
        path_like = (
            bool(PATH_PATTERN.search(candidate))
            or bool(re.match(r"^(?:Makefile|\.gitmodules)(?::[\d,\-]+)?$", candidate))
            or (candidate.startswith(".") and "/" in candidate and " " not in candidate)
        )
        if path_like and candidate not in seen:
            seen.add(candidate)
            values.append(candidate)
    return values


def sections(lines: list[str], heading_re: re.Pattern[str], stop_level: str) -> list[tuple[str, str, int, int, str]]:
    starts: list[tuple[int, re.Match[str]]] = []
    for index, line in enumerate(lines):
        match = heading_re.match(line)
        if match:
            starts.append((index, match))
    output: list[tuple[str, str, int, int, str]] = []
    for position, (start, match) in enumerate(starts):
        end = starts[position + 1][0] if position + 1 < len(starts) else len(lines)
        if stop_level == "wp1":
            for probe in range(start + 1, end):
                if lines[probe].startswith("# "):
                    end = probe
                    break
        text = "\n".join(lines[start:end]).strip()
        output.append((match.group(1), match.group(2).strip(), start + 1, end, text))
    return output


def normalize(source_file: Path, domain: str, item: tuple[str, str, int, int, str], package: str) -> dict[str, object]:
    finding_id, title, start, end, section = item
    severity_match = SEVERITY_PATTERN.search(section)
    confidence_match = CONFIDENCE_PATTERN.search(section)

    if package == "part-2-wp1":
        evidence = heading_field(section, ["Evidence"])
        impact = heading_field(
            section,
            [
                "Reachable path and impact",
                "Why this is defective",
                "Impact",
                "Risk and mitigation context",
                "Missing deterministic coverage",
            ],
        )
        remediation = heading_field(section, ["Preserving remediation"])
        verification = heading_field(section, ["Verification"])
    else:
        evidence_parts = [
            field(section, ["Evidence", "Exact evidence", "Code"]),
            field(section, ["Source excerpt"]),
        ]
        evidence = "\n\n".join(part for part in evidence_parts if part)
        impact = field(
            section,
            [
                "Why this is defective/risky",
                "Why this is defective",
                "Why this is risky",
                "Why this is a gap",
                "Why this is risky / remains unverified",
                "Defect and execution path",
                "Impact / execution path",
                "Impact and execution path",
                "Impact",
                "Execution path",
            ],
        )
        remediation = field(section, ["Preserving remediation", "Remediation", "Remediation / safe unapplied patch", "Safe remediation", "Recommended remediation"])
        verification = field(section, ["Verification / acceptance criteria", "Verification / acceptance", "Verification and acceptance"])
    related = sorted(set(ID_PATTERN.findall(section)) - {finding_id})

    return {
        "id": finding_id,
        "title": title,
        "severity": severity_match.group(1).strip() if severity_match else "Unknown",
        "confidence": confidence_match.group(1).strip() if confidence_match else "Not stated",
        "domain": domain,
        "sourcePackage": package,
        "sourceFile": source_file.name,
        "sourceSectionLines": f"{start}-{end}",
        "locations": code_locations(evidence),
        "evidence": evidence,
        "domainImpact": impact,
        "remediation": remediation,
        "verification": verification,
        "relatedIDs": related,
        "sourceSectionText": section,
    }


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: parse_audit_corpus.py PRIOR_REPORT_DIR WP1_REPORT OUTPUT_JSON", file=sys.stderr)
        return 2

    prior_dir = Path(sys.argv[1]).resolve()
    wp1_report = Path(sys.argv[2]).resolve()
    output_path = Path(sys.argv[3]).resolve()
    records: list[dict[str, object]] = []

    for source in sorted(prior_dir.glob("0[1-9]_*.md")):
        lines = source.read_text(encoding="utf-8").splitlines()
        for item in sections(lines, PRIOR_HEADING, "prior"):
            records.append(normalize(source, DOMAIN_MAP[source.name], item, "original-checkpoint"))

    wp1_lines = wp1_report.read_text(encoding="utf-8").splitlines()
    for item in sections(wp1_lines, WP1_HEADING, "wp1"):
        records.append(normalize(wp1_report, DOMAIN_MAP[wp1_report.name], item, "part-2-wp1"))

    ids = [record["id"] for record in records]
    duplicates = sorted({finding_id for finding_id in ids if ids.count(finding_id) > 1})
    by_domain: dict[str, int] = {}
    by_severity: dict[str, int] = {}
    for record in records:
        by_domain[record["domain"]] = by_domain.get(record["domain"], 0) + 1
        by_severity[record["severity"]] = by_severity.get(record["severity"], 0) + 1

    missing_fields: list[dict[str, object]] = []
    for record in records:
        missing = [
            key
            for key in ("severity", "locations", "evidence", "domainImpact", "remediation")
            if record[key] in ("", [], "Unknown")
        ]
        if missing:
            missing_fields.append({"id": record["id"], "fields": missing})

    output = {
        "schemaVersion": 1,
        "repositoryCommit": "459db9bfd18d17960e8fd2ff8defc4701085532e",
        "sourceFindingCount": len(records),
        "uniqueIDCount": len(set(ids)),
        "duplicateSourceIDs": duplicates,
        "countsByDomain": dict(sorted(by_domain.items())),
        "countsBySeverity": dict(sorted(by_severity.items())),
        "recordsWithParserFieldGaps": missing_fields,
        "findings": records,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(output, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({key: output[key] for key in ("sourceFindingCount", "uniqueIDCount", "duplicateSourceIDs", "countsByDomain", "countsBySeverity", "recordsWithParserFieldGaps")}, indent=2, ensure_ascii=False))
    return 0 if not duplicates else 1


if __name__ == "__main__":
    raise SystemExit(main())
