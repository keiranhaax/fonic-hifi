# Documentation Index

This index classifies the repository's Markdown documentation as of 2026-07-21. It is a navigation and provenance guide, not a substitute for revalidating claims against the current tree.

## Status labels and precedence

- **Authoritative** — instructions or contracts that govern current work. The nearest applicable `AGENTS.md` takes precedence.
- **Active** — a maintained entry point, backlog, or reference. Confirm behavior claims against current source and project configuration before acting.
- **Historical** — a retained decision, plan, or status snapshot. It does not describe current behavior by itself.
- **Generated research** — model- or tool-produced analysis. Treat its findings as hypotheses until independently revalidated.
- **Raw input** — source evidence or archival material preserved for traceability. Presence does not make it an approved requirement.

For implementation truth, use current source, `Fonic HiFi.xcodeproj/project.pbxproj`, its SwiftPM `Package.resolved`, and the checked-in `Makefile`. For working instructions, start with the [project agent guide](../AGENTS.md) and then read the closest nested guide. For current remediation status, use the [audit backlog](../audits-1/tasks/00-README.md), but revalidate each selected task against `HEAD` and the live worktree.

## Documentation roots

The counts below describe the intended tree after this index is tracked: 241 Markdown files (240 tracked before this file was added, plus this index).

| Path | Count | Status | Use and forward disposition |
| --- | ---: | --- | --- |
| Repository root | 6 | Mixed; itemized below | Entry points plus explicitly classified legacy reports. |
| `.agents/skills/` | 4 | Active | Project-local agent skills and their references; tooling guidance, not product behavior evidence. |
| `.factory/docs/` | 27 | Historical / Generated research | 2025 generated refactor proposals and progress assessments. Revalidate before reuse. |
| `Files/` (direct children) | 2 | Generated research / Raw input | Older project analysis and imported artifact material. |
| `Files/Archive/` | 56 | Historical / Raw input | Intentional archive. Its own archive notice applies; do not treat it as the current plan. |
| `Files/Plan/` | 6 | Historical / Raw input | Legacy planning inputs retained without current approval. |
| `Files/docs/` | 19 | Historical | Legacy ADRs, plans, refactor notes, and test snapshots. |
| `Files/plan2/` | 15 | Historical / Raw input | Later planning corpus retained as evidence, including its nested archive. |
| `Fonic HiFi/**/AGENTS.md` | 5 | Authoritative | Local instructions for Audio, AI, Intents, Data, and Presentation. |
| `Fonic HiFi Widget/AGENTS.md` | 1 | Authoritative | Widget-specific instructions and shared-contract constraints. |
| `Fonic HiFiTests/AGENTS.md` | 1 | Authoritative | Unit and integration test conventions. |
| `Fonic HiFiUITests/AGENTS.md` | 1 | Authoritative | UI-test harness and simulator conventions. |
| `audits-1/Part1/` | 20 | Raw input / Generated research | Original production-audit packages and evidence. |
| `audits-1/Part2/` | 51 | Raw input / Generated research | Deduplication, reverification, refactoring, and cleanup work-package evidence. |
| `audits-1/tasks/` | 11 | Active | Current normalized implementation backlog, resolved register, and disposition map. |
| `docs/README.md` | 1 | Active | This provenance and navigation index. |
| `docs/plans/` | 10 | Historical | Dated implementation plans and completed remediation records; none overrides the live backlog. |
| `docs/privacy/` | 1 | Active | Required-reason API inventory; revalidate when production API usage or target membership changes. |
| `docs/references/` | 4 | Active / Generated research | Maintained operational references plus one explicitly unverified target list, itemized below. |

## Root documents

| File | Status | Current use |
| --- | --- | --- |
| `AGENTS.md` | Authoritative | Repository-wide working instructions and source-of-truth policy. |
| `README.md` | Active | Human-facing overview only; verify feature, build, and test claims against the current tree. |
| `STATUS.md` | Historical | 2025-12-07 build and feature snapshot; not current status evidence. |
| `EQ.md` | Generated research | DSP background only. Current EQ and measurement work is routed through AUDIT-023, AUDIT-028, and the resolved-finding register. |
| `Files-analysis.md` | Generated research | 2025-12-04 analysis of the historical `Files/` corpus; not a current roadmap. |
| `summary.md` | Generated research | 2025-12-04 codebase snapshot with stale source, test, and capability claims. |

The three generated root reports remain in place so existing paths do not break. Their explicit classification here is their disposition; moving or deleting them requires a separately scoped archive change.

## Active references

| File | Status | Revalidation rule |
| --- | --- | --- |
| `docs/privacy/required-reason-api-inventory.md` | Active | Re-run the production-source inventory after privacy-sensitive API or target changes. |
| `docs/references/architecture-reference.md` | Active | Use as orientation; confirm types, ownership, and engine behavior in current source. |
| `docs/references/git-recovery-sop.md` | Active | Recovery reference only. `AGENTS.md` approval and safety rules govern any state-changing command. |
| `docs/references/observability-sop.md` | Active | Confirm logging and metrics APIs in current source before applying. |
| `docs/references/performance-targets.md` | Generated research | Explicitly unverified targets; profile first and verify commands against the current `Makefile`. |

`CLAUDE.md` is not present in the current tree. The four `docs/references/` files are tracked, so the earlier audit claim that a tracked `CLAUDE.md` linked to untracked reference files no longer applies.

## Archived-requirement mapping

Archived prose is not silently promoted into current scope. Its forward disposition is explicit:

| Archived source | Forward destination or disposition |
| --- | --- |
| `audits-1/Part1/` and `audits-1/Part2/` findings | Normalized through the [finding disposition map](../audits-1/tasks/09-finding-disposition-map.md) into task files, the [resolved register](../audits-1/tasks/01-resolved-findings.md), or a documented no-action disposition. |
| EQ, playback-measurement, and audio-transition proposals | Current defects and evidence requirements live in the [audio backlog](../audits-1/tasks/05-audio-playback.md); device-only proof remains in AUDIT-055. |
| Home, listening-history, Foundation Models, and smart-search plans | Current work is represented by the data, UI, and [Foundation Models backlog](../audits-1/tasks/07-foundation-models.md), not by the dated plans. |
| `.factory/docs/`, `Files/**`, root generated reports, and dated `docs/plans/` | Historical-only unless a requirement is revalidated against current source and deliberately promoted into `audits-1/tasks/` or a newly approved plan. Historical-only is a disposition, not an implementation commitment. |
| Privacy and operational guidance | Maintain in `docs/privacy/` or `docs/references/` after live revalidation; governing instructions remain in the nearest `AGENTS.md`. |

When promoting an archived requirement, record its source path, current-code evidence, destination task or plan, and verification lane. Do not edit archival evidence merely to make it look current.
