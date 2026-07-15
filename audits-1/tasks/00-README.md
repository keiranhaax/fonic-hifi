# iOS Audit Implementation Backlog

**Created:** 2026-07-15
**Repository:** Fonic HiFi (`main`, worktree dirty with in-flight playback-error and settings work — see "Protected in-flight work" below)
**Audited revision:** audits were taken at `459db9b`; every finding was re-validated against the current working tree on 2026-07-15.
**Planning only:** no application source was modified while building this backlog.

## Files in this tracker

| File | Contents |
|---|---|
| `00-README.md` | This summary, execution order, dependency map, groups |
| `01-resolved-findings.md` | Findings already fixed in the current tree — `[DONE]` register with evidence |
| `02-security-config.md` | AUDIT-001 … AUDIT-007 |
| `03-data-import.md` | AUDIT-008 … AUDIT-016 |
| `04-library-data.md` | AUDIT-017 … AUDIT-019 |
| `05-audio-playback.md` | AUDIT-020 … AUDIT-035 |
| `06-ui-ux.md` | AUDIT-036 … AUDIT-043 |
| `07-foundation-models.md` | AUDIT-044 … AUDIT-047 |
| `08-widget-testing-cleanup.md` | AUDIT-048 … AUDIT-055 |
| `09-finding-disposition-map.md` | Every source finding ID → task or disposition |

## Audit Sources

- **Part 1 / Model A** — `audits-1/Part1/5c92e094-…` (production audit, 46 findings). Not independently re-normalized here; its findings corroborate Model B findings and were already routed by `docs/plans/2026-07-10-audit-crosscheck-remediation.md`.
- **Part 1 / Model B** — `audits-1/Part1/fonic-hifi-production-audit/` (139 findings across 9 domain reports, commit `459db9b`).
- **Part 2 / WP1** — Foundation Models review (`FINDINGS.json`, 8 findings FMA-001…008).
- **Part 2 / WP2** — Cross-domain deduplication (`CANONICAL_FINDINGS.json`): 147 source findings (Model B + WP1) → **118 canonical findings**. This backlog uses the canonical IDs.
- **Part 2 / WP3** — Critical/High reverification (`UPDATED_FINDINGS.json`, 23 reverified clusters WP3-001…023, 0 rejected, severities recalibrated: 0 Critical, 13 High, 10 Medium).
- **Part 2 / WP4** — Refactoring review (8 retained candidates WP4-R01…R08, 0 rejected/deferred remaining in final JSON).
- **Part 2 / WP5** — Project cleanup (15 register entries CLN-001…015, several "keep"/negative findings).

## Status Summary

- Canonical findings reviewed: **118** (from 147 source findings) + 8 WP4 candidates + 15 WP5 entries
- Unique implementation tasks created: **55** (AUDIT-001 … AUDIT-055)
- `[TODO]`: **51**
- `[DONE]` (already fixed in current tree, recorded in `01-resolved-findings.md`): **28 findings**
- `[BLOCKED]`: **4** (AUDIT-001 provider action; AUDIT-004 product decision; AUDIT-007 owner/policy; AUDIT-055 physical device + release owner)
- `[UNCONFIRMED]`: **0** — every retained finding was either re-validated statically or is explicitly tracked as profile-first/reproduce-first inside its task
- `[NOT APPLICABLE]` / no-action: **7** (WP5 CLN-010…014 "keep" findings, WP2 informational positive checks; see disposition map)
- Duplicate findings consolidated: WP2 already merged 55 source findings into 26 clusters; this backlog additionally consolidates 118 canonical findings + WP4/WP5 into 55 tasks (consolidations listed per task under "Audit finding IDs")
- Partially-fixed findings folded into open tasks: 10 (CAN-011, CAN-022, CAN-024, AUD-RESET-001, DLP-010, DLP-014, UIUX-010, UIUX-012, A11Y-008, TRV-005)

## Difficulty Summary

- Trivial: 2 (AUDIT-002, 003)
- Easy: 12 (AUDIT-001, 004, 005, 006, 008, 009, 020, 025, 039, 044, 048, 053)
- Moderate: 25 (AUDIT-007, 010, 012, 013, 016, 018, 019, 021, 022, 023, 024, 026, 027, 028, 029, 037, 038, 040, 042, 045, 046, 047, 050, 051, 052)
- Hard: 12 (AUDIT-011, 014, 015, 017, 030, 031, 032, 033, 035, 041, 049, 054)
- Complex: 4 (AUDIT-034, 036, 043, 055)

## Protected in-flight work

The worktree contains uncommitted user changes that must not be rolled back:
playback-error surfacing (`AudioEngineFacade.lastPlaybackErrorMessage`, `PlaybackErrorBanner.swift`, `ContentView.swift`), facade initialization serialization, `AudioPlaybackSettingsStore`/`FormatDetectionCoordinator` edits, and matching tests. AUDIT-021, AUDIT-030, and AUDIT-038 explicitly build on (and must preserve) this work.

## Recommended Execution Order

Dependency order overrides difficulty order; reasons noted where a harder task precedes an easier one.

1. **AUDIT-001** — credential rotation is urgent and external; unblocks nothing technically but caps exposure (starts immediately, completes when provider confirms).
2. **GROUP-01 hygiene: AUDIT-002, AUDIT-003, AUDIT-005** — trivial/easy, zero-dependency repo and config cleanup.
3. **AUDIT-006** — easy, batched logging-privacy fix; independent.
4. **GROUP-02: AUDIT-008, AUDIT-009** — easy metadata-correctness pair in one service; do together before more import work churns the same files.
5. **AUDIT-020** — easy engine-preference fix; do before AUDIT-021 (same settings surface).
6. **AUDIT-025, AUDIT-039, AUDIT-044, AUDIT-048, AUDIT-053** — remaining easy, independent tasks.
7. **AUDIT-010** *(harder before easier — foundational)* — schema V-next + migration ordering blocks all listening-session work and real migration tests.
8. **GROUP-03: AUDIT-012, AUDIT-011** — migration tests immediately after AUDIT-010, then session lifecycle.
9. **AUDIT-013** then **GROUP-04: AUDIT-015, AUDIT-014** — import-pipeline integrity; AUDIT-015 (cancellation + semaphore) before AUDIT-014 (atomic dedup) because dedup redesign builds on the same actor kernel (WP4-R05/R06).
10. **AUDIT-016** — quarantine policy; independent but high user-data risk, schedule after import pipeline is stable.
11. **AUDIT-036** *(hardest-first — foundational)* — the observation-boundary fix unlocks AUDIT-021, 037, 038 and de-risks all UI state work.
12. **GROUP-07: AUDIT-037, AUDIT-038, AUDIT-021** — UI state/visibility work immediately on top of AUDIT-036.
13. **AUDIT-022, AUDIT-023, AUDIT-024, AUDIT-026, AUDIT-027, AUDIT-028, AUDIT-029** — bounded moderate audio tasks, largely independent.
14. **GROUP-09: AUDIT-017, AUDIT-018** then **AUDIT-019** — library data layer, then playlists.
15. **GROUP-08: AUDIT-045, AUDIT-046, AUDIT-047** — remaining AI hardening and its test matrix.
16. **AUDIT-040, AUDIT-042** — Now Playing layout; FileManager extraction.
17. **AUDIT-041** — queue mutation/persistence separation (profile first).
18. **GROUP-05 audio core (hardest): AUDIT-030 → AUDIT-031 → AUDIT-032 → AUDIT-033 → AUDIT-034**, plus **AUDIT-035** (reproduce-first) — strict dependency chain; gapless (034) last.
19. **AUDIT-049** — widget push sync (after drift guard 048).
20. **AUDIT-050, AUDIT-051, AUDIT-052** — test hygiene and dead-code triage (test hygiene earlier is also acceptable; it has no dependencies).
21. **AUDIT-043** — localization program (large, product-visible; after UI state stabilizes to avoid re-migrating strings).
22. **AUDIT-054** — performance profile-first program (needs stable code to profile).
23. **AUDIT-055** — device acceptance / release evidence lane (final gate; blocked on device + owner).
24. **AUDIT-004, AUDIT-007** — product/owner decisions; execute whenever decided.

## Dependency Map

- AUDIT-001 → blocks AUDIT-002 (final removal of the two credential-bearing configs must follow rotation)
- AUDIT-010 → blocks AUDIT-011 and AUDIT-012
- AUDIT-015 → related-precedes AUDIT-014 (shared FileImportProcessor/TrackDataActor kernel, WP4-R05/R06)
- AUDIT-020 → related-precedes AUDIT-021 (same settings/engine-selection surface)
- AUDIT-036 → blocks AUDIT-037, AUDIT-038; unblocks the UI half of AUDIT-021
- AUDIT-030 → blocks AUDIT-034; AUDIT-031 → blocks AUDIT-032 and AUDIT-034; AUDIT-033 → blocks AUDIT-034
- AUDIT-048 → blocks AUDIT-049 (drift guard before changing widget payload production)
- AUDIT-010/011 → related to AUDIT-051 (perf/integration tests exercise migration and sessions)
- AUDIT-034, AUDIT-028, AUDIT-032 → feed AUDIT-055 (device evidence lane verifies them)
- AUDIT-004 → blocked by product decision; AUDIT-007 → blocked by owner/policy decisions; AUDIT-055 → blocked by physical device + release owner
- No circular dependencies: the audio chain is linear (030/031/033 → 032/034), UI chain is a tree rooted at 036, data chain is linear (010 → 011/012).

## Implementation Groups

- **GROUP-01 — Repository hygiene & security** (AUDIT-001, 002, 003, 005): same `.gitignore`/tracked-file/CI surface; separating them causes repeated index churn and repeated secret-scan passes.
- **GROUP-02 — Import metadata correctness** (AUDIT-008, 009): both change `MetadataExtractionService` + `TrackDataActor.applyTrackMetadata` and share one fixture set; separate PRs would edit identical lines twice.
- **GROUP-03 — Listening sessions** (AUDIT-010, 011, 012): one schema/migration/lifecycle vertical; landing lifecycle without the schema stage crashes inserts, and migration tests are only meaningful against the new stage.
- **GROUP-04 — Import pipeline integrity** (AUDIT-013, 014, 15): failure cleanup, cancellation, and atomic dedup all reshape the same `FileImportProcessor` flow; interleaving other work would produce conflicting rewrites.
- **GROUP-05 — Audio session & transitions** (AUDIT-030, 031, 032, 033, 034): one playback state machine; partial landing leaves transitions incoherent (e.g., serialized play with split session ownership regresses interruption paths).
- **GROUP-06 — Format contract** (inside AUDIT-022): codec inspection and advertised-format pruning must ship together or the UI advertises formats the detector still misroutes.
- **GROUP-07 — Observation & UI state ownership** (AUDIT-036, 037, 038, UI half of 021): all consume the corrected observation boundary; doing them before AUDIT-036 doubles the migration.
- **GROUP-08 — Foundation Models hardening** (AUDIT-044, 045, 046, 047): same two services + view model; the test matrix (047) must land with/after the behavior changes it locks in.
- **GROUP-09 — Library data layer** (AUDIT-017, 018): repository pagination/count semantics and view-model request ownership interlock; changing one alone re-breaks loading states.
- **GROUP-10 — Test hygiene** (AUDIT-050, 051): shared conventions (deterministic clocks, isolated defaults, skip policy) should be established once and applied consistently.
- **GROUP-11 — Measurement honesty** (AUDIT-027, 028): diagnostics zeros and bit-perfect claims are the same "synthetic status presented as measurement" defect across two surfaces.
- **GROUP-12 — Widget contracts & sync** (AUDIT-048, 049): drift guard first, then payload/scheduling changes under its protection.

## Task decomposition notes

- The original ledger's release matrix (X-08) stays one task (AUDIT-055) because it is an evidence lane, not code.
- CP-series performance findings were deliberately consolidated rather than split into 9 speculative micro-tasks: CP-008, CP-010, CP-011, CP-013, CP-016 and the app half of CP-009 form the AUDIT-054 profile-first umbrella (statically identified smells with **unmeasured** runtime impact; the audit itself requires traces before code changes). The rest ride their subsystem tasks: CP-012 → AUDIT-027, CP-014 → AUDIT-017, CP-015 → AUDIT-042, CP-007 → AUDIT-029, widget half of CP-009 → AUDIT-049.
- CAN-022 (failure silence) was split: playback errors are already fixed in-flight; the remainder (Home/Search/File Manager/import surfaces) is AUDIT-038.
- No task requires further splitting except AUDIT-043 and AUDIT-054, which are explicitly phased programs with per-phase exit criteria inside the task.
