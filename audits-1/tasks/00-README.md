# iOS Audit Implementation Backlog

**Created:** 2026-07-15
**Repository:** Fonic HiFi (`main`, worktree dirty with in-flight playback-error and settings work — see "Protected in-flight work" below)
**Audited revision:** source audits were taken at `459db9b`; normalized findings were statically re-checked on 2026-07-15, and current-repository follow-ups were added from the 2026-07-18 audit at `4fab020`. Runtime, future CI, and physical-device claims remain verification work where the tasks say so.
**Planning only:** no application source was modified while building this backlog.
**Implementation use:** treat this as a planning backlog, not proof of current runtime behavior. Revalidate the selected task against `HEAD`, the live dirty worktree, and its stated verification lane immediately before editing.

## Files in this tracker

| File | Contents |
|---|---|
| `00-README.md` | This summary, execution order, dependency map, groups |
| `01-resolved-findings.md` | Findings already fixed in the current tree — `[DONE]` register plus one explicitly partial evidence row |
| `02-security-config.md` | AUDIT-001 … AUDIT-007 |
| `03-data-import.md` | AUDIT-008 … AUDIT-016 |
| `04-library-data.md` | AUDIT-017 … AUDIT-019 |
| `05-audio-playback.md` | AUDIT-020 … AUDIT-035 |
| `06-ui-ux.md` | AUDIT-036 … AUDIT-043 |
| `07-foundation-models.md` | AUDIT-044 … AUDIT-047 |
| `08-widget-testing-cleanup.md` | AUDIT-048 … AUDIT-056 |
| `09-finding-disposition-map.md` | Every normalized WP1–WP5 finding ID → task or disposition; Model A is cross-referenced but not independently normalized |
| `10-current-audit-followups.md` | AUDIT-057 … AUDIT-066 from the 2026-07-18 current-repository audit and owner decisions |

## Audit Sources

- **Part 1 / Model A** — `audits-1/Part1/5c92e094-…` (production audit, 46 findings). Not independently re-normalized here; its findings corroborate Model B findings and were already routed by `docs/plans/2026-07-10-audit-crosscheck-remediation.md`.
- **Part 1 / Model B** — `audits-1/Part1/fonic-hifi-production-audit/` (139 findings across 9 domain reports, commit `459db9b`).
- **Part 2 / WP1** — Foundation Models review (`FINDINGS.json`, 8 findings FMA-001…008).
- **Part 2 / WP2** — Cross-domain deduplication (`CANONICAL_FINDINGS.json`): 147 source findings (Model B + WP1) → **118 canonical findings**. This backlog uses the canonical IDs.
- **Part 2 / WP3** — Critical/High reverification (`UPDATED_FINDINGS.json`, 23 reverified clusters WP3-001…023, 0 rejected, severities recalibrated: 0 Critical, 13 High, 10 Medium).
- **Part 2 / WP4** — Refactoring review (8 retained candidates WP4-R01…R08, 0 rejected/deferred remaining in final JSON).
- **Part 2 / WP5** — Project cleanup (15 register entries CLN-001…015, several "keep"/negative findings).
- **Project references** — `docs/references/` is retained, non-production guidance. It must be validated against the current tree before reuse.

Counting note: `09-finding-disposition-map.md` contains 118 WP2 canonical rows and repeats the 8 WP1 FMA rows as routing cross-references (126 table rows across those two sections). The repeated WP1 rows are already source members of the WP2 canonical set and are not 8 additional unique findings.

## Status Summary

- Normalized findings reviewed: **118** WP2 canonical findings (from 147 Model B + WP1 source findings) + 8 WP4 candidates + 15 WP5 entries; Model A's 46 findings are corroborating evidence, not an additional normalized set
- Unique implementation tasks created: **66** (AUDIT-001 … AUDIT-066)
- `[TODO]`: **49**
- `[IN PROGRESS]`: **0**
- `[DONE]` implementation tasks: **12** (AUDIT-001, AUDIT-002, AUDIT-003, AUDIT-006, AUDIT-008, AUDIT-009, AUDIT-020, AUDIT-056, AUDIT-057, AUDIT-058, AUDIT-059, AUDIT-060), plus **27 resolved/owner-dispositioned findings** recorded in `01-resolved-findings.md` and 1 partial dead-code evidence row whose remaining work is AUDIT-052
- `[BLOCKED]`: **5** (AUDIT-004 product decision; AUDIT-005 CI reintroduction; AUDIT-007 owner/policy; AUDIT-055 physical device + release owner; AUDIT-061 provider/history disposition)
- Standalone `[UNCONFIRMED]` dispositions: **0** — retained static defects are routed to tasks, while unmeasured runtime/device impact remains explicit profile-first, reproduce-first, or evidence-lane work
- `[NOT APPLICABLE]` / no-action: **5** (WP5 CLN-010…014 "keep" findings; see disposition map)
- Duplicate findings consolidated: WP2 already merged 55 source findings into 26 clusters; the normalized corpus is consolidated into AUDIT-001…056, while AUDIT-057…066 records non-duplicative current-tree findings and owner decisions from 2026-07-18
- Residual or partially-fixed findings folded into open tasks: 10 (CAN-011, CAN-022, CAN-024, AUD-RESET-001, DLP-010, DLP-014, UIUX-010, UIUX-012, A11Y-008, TRV-005). TRV-005 is a confirmed residual finding rather than a partially-fixed one.

## Difficulty Summary

- Trivial: 4 (AUDIT-002, 003, 057, 060)
- Easy: 16 (AUDIT-001, 004, 005, 006, 008, 009, 020, 025, 039, 044, 048, 053, 056, 058, 059, 061)
- Moderate: 29 (AUDIT-007, 010, 012, 013, 016, 018, 019, 021, 022, 023, 024, 026, 027, 028, 029, 037, 038, 040, 042, 045, 046, 047, 050, 051, 052, 062, 064, 065, 066)
- Hard: 13 (AUDIT-011, 014, 015, 017, 030, 031, 032, 033, 035, 041, 049, 054, 063)
- Complex: 4 (AUDIT-034, 036, 043, 055)

## Protected in-flight work

The worktree contains uncommitted user changes that must not be rolled back:
playback-error surfacing (`AudioEngineFacade.lastPlaybackErrorMessage`, `PlaybackErrorBanner.swift`, `ContentView.swift`), facade initialization serialization, `AudioPlaybackSettingsStore`/`FormatDetectionCoordinator` edits, and matching tests. AUDIT-021, AUDIT-030, AUDIT-038, AUDIT-062, and AUDIT-064 explicitly build on (and must preserve) this work.

## Recommended Execution Order

Dependency order overrides difficulty order; reasons noted where a harder task precedes an easier one.

1. **AUDIT-001 — DONE** — retired `.kilocode/` configuration removed completely.
2. **AUDIT-002, AUDIT-003, AUDIT-056, AUDIT-057 … AUDIT-060 — DONE** — repository artifacts and retired agent trees removed; widget AccentColor mismatch cleared; hosted CI retired; local agent guidance preserved; references classified; local test media ignored. **AUDIT-005 is blocked until CI reintroduction.**
3. **AUDIT-006 — DONE** — confirmed content-bearing public log interpolations redacted; broader explicit-privacy policy work remains AUDIT-065.
4. **GROUP-02: AUDIT-008, AUDIT-009 — DONE** — ReplayGain and MP4 numbering metadata now parse and persist with AAC/ALAC fixture coverage.
5. **AUDIT-020 — DONE** — typed engine preferences now select every capable stored choice, migrate the legacy AudioKit value, and log deterministic fallbacks.
6. **AUDIT-025 — NEXT**, then **AUDIT-039, AUDIT-044, AUDIT-048, AUDIT-053, AUDIT-065** — remaining bounded independent tasks. **AUDIT-056 … AUDIT-060 are DONE**.
7. **AUDIT-010** *(harder before easier — foundational)* — schema V-next + migration ordering blocks all listening-session work and real migration tests.
8. **GROUP-03: AUDIT-012, AUDIT-011** — migration tests immediately after AUDIT-010, then session lifecycle.
9. **AUDIT-013** then **GROUP-04: AUDIT-015, AUDIT-014** — import-pipeline integrity; AUDIT-015 (cancellation + semaphore) before AUDIT-014 (atomic dedup) because dedup redesign builds on the same actor kernel (WP4-R05/R06).
10. **AUDIT-016** — quarantine policy; independent but high user-data risk, schedule after import pipeline is stable.
11. **AUDIT-036** *(hardest-first — foundational)* — the observation-boundary fix unlocks AUDIT-021, 037, 038 and de-risks all UI state work.
12. **GROUP-07: AUDIT-037, AUDIT-038, AUDIT-021** — UI state/visibility work immediately on top of AUDIT-036.
13. **AUDIT-022, AUDIT-023, AUDIT-024, AUDIT-026, AUDIT-027, AUDIT-028, AUDIT-029** — bounded moderate audio tasks, largely independent.
14. **GROUP-09: AUDIT-017, AUDIT-018** then **AUDIT-019** — library data layer, then playlists.
15. **GROUP-08: AUDIT-045, AUDIT-046, AUDIT-047** — remaining AI hardening and its test matrix.
16. **AUDIT-040, AUDIT-042, AUDIT-064** — Now Playing layout; FileManager extraction; accessible playback-error lifecycle after AUDIT-036.
17. **AUDIT-041** — queue mutation/persistence separation (profile first).
18. **GROUP-05 audio core (hardest): AUDIT-062, then AUDIT-030 → AUDIT-031/AUDIT-063 → AUDIT-032 → AUDIT-033 → AUDIT-034**, plus **AUDIT-035** (reproduce-first) — strict dependency chain; callback isolation coordinates with the single session owner; gapless (034) last.
19. **AUDIT-049** — widget push sync (after drift guard 048).
20. **AUDIT-050, AUDIT-051, AUDIT-052, AUDIT-066** — test hygiene, warning-family burn-down, and dead-code triage (test hygiene earlier is also acceptable; it has no dependencies).
21. **AUDIT-043** — localization program (large, product-visible; after UI state stabilizes to avoid re-migrating strings).
22. **AUDIT-054** — performance profile-first program (needs stable code to profile).
23. **AUDIT-055** — device acceptance / release evidence lane (final gate; blocked on device + owner).
24. **AUDIT-004, AUDIT-005, AUDIT-007, AUDIT-061** — product, future-CI, policy, and provider/history decisions; execute only when explicitly unblocked.

## Dependency Map

- AUDIT-001 and AUDIT-002 are complete; remaining Claude agent-tree purge is AUDIT-056.
- AUDIT-002 → related-precedes AUDIT-056 (settings.local already untracked in 002)
- AUDIT-010 → blocks AUDIT-011 and AUDIT-012
- AUDIT-015 → related-precedes AUDIT-014 (shared FileImportProcessor/TrackDataActor kernel, WP4-R05/R06)
- AUDIT-020 is complete and related-precedes AUDIT-021 (same settings/engine-selection surface)
- AUDIT-036 → blocks AUDIT-037, AUDIT-038; unblocks the UI half of AUDIT-021
- AUDIT-030 → blocks AUDIT-034; AUDIT-031 → blocks AUDIT-032 and AUDIT-034; AUDIT-033 → blocks AUDIT-034
- AUDIT-048 → blocks AUDIT-049 (drift guard before changing widget payload production)
- AUDIT-010/011 → related to AUDIT-051 (perf/integration tests exercise migration and sessions)
- AUDIT-034, AUDIT-028, AUDIT-032 → feed AUDIT-055 (device evidence lane verifies them)
- AUDIT-057 → blocks speculative CI work; AUDIT-005 remains blocked until an owner-approved runner/toolchain exists
- AUDIT-062 → related-precedes AUDIT-030/031; AUDIT-063 coordinates with AUDIT-031/032; AUDIT-036 → related-precedes AUDIT-064
- AUDIT-061 → blocked by provider/account ownership and any separate history-rewrite decision
- AUDIT-004 → blocked by product decision; AUDIT-007 → blocked by owner/policy decisions; AUDIT-055 → blocked by physical device + release owner
- No circular dependencies: the audio chain is linear (030/031/033 → 032/034), UI chain is a tree rooted at 036, data chain is linear (010 → 011/012).

## Implementation Groups

- **GROUP-01 — Repository hygiene & security** (AUDIT-001, 002, 003, 005; AUDIT-056 is related post-002 cleanup): same `.gitignore`/tracked-file/CI surface; separating them causes repeated index churn and repeated secret-scan passes.
- **GROUP-02 — Import metadata correctness — DONE** (AUDIT-008, 009): ReplayGain, MP4 track/disc tuples, and totals are covered by shared extraction and persistence fixtures.
- **GROUP-03 — Listening sessions** (AUDIT-010, 011, 012): one schema/migration/lifecycle vertical; landing lifecycle without the schema stage crashes inserts, and migration tests are only meaningful against the new stage.
- **GROUP-04 — Import pipeline integrity** (AUDIT-013, 014, 015): failure cleanup, cancellation, and atomic dedup all reshape the same `FileImportProcessor` flow; interleaving other work would produce conflicting rewrites.
- **GROUP-05 — Audio session & transitions** (AUDIT-030, 031, 032, 033, 034): one playback state machine; partial landing leaves transitions incoherent (e.g., serialized play with split session ownership regresses interruption paths).
- **GROUP-06 — Format contract** (inside AUDIT-022): codec inspection and advertised-format pruning must ship together or the UI advertises formats the detector still misroutes.
- **GROUP-07 — Observation & UI state ownership** (AUDIT-036, 037, 038, UI half of 021): all consume the corrected observation boundary; doing them before AUDIT-036 doubles the migration.
- **GROUP-08 — Foundation Models hardening** (AUDIT-044, 045, 046, 047): same two services + view model; the test matrix (047) must land with/after the behavior changes it locks in.
- **GROUP-09 — Library data layer** (AUDIT-017, 018): repository pagination/count semantics and view-model request ownership interlock; changing one alone re-breaks loading states.
- **GROUP-10 — Test hygiene** (AUDIT-050, 051): shared conventions (deterministic clocks, isolated defaults, skip policy) should be established once and applied consistently.
- **GROUP-11 — Measurement honesty** (AUDIT-027, 028): diagnostics zeros and bit-perfect claims are the same "synthetic status presented as measurement" defect across two surfaces.
- **GROUP-12 — Widget contracts & sync** (AUDIT-048, 049): drift guard first, then payload/scheduling changes under its protection.
- **GROUP-13 — Current repository cleanup** (AUDIT-057, 058, 059, 060): owner-approved CI retirement, local-guide preservation, reference classification, and test-media exclusion; no application behavior or Git-index mutation.

## Task decomposition notes

- The original ledger's release matrix (X-08) stays one task (AUDIT-055) because it is an evidence lane, not code.
- CP-series performance findings were deliberately consolidated rather than split into 9 speculative micro-tasks: CP-008, CP-010, CP-011, CP-013, CP-016 and the app half of CP-009 form the AUDIT-054 profile-first umbrella (statically identified smells with **unmeasured** runtime impact; the audit itself requires traces before code changes). The rest ride their subsystem tasks: CP-012 → AUDIT-027, CP-014 → AUDIT-017, CP-015 → AUDIT-042, CP-007 → AUDIT-029, widget half of CP-009 → AUDIT-049.
- CAN-022 (failure silence) was split: playback errors are already fixed in-flight; the remainder (Home/Search/File Manager/import surfaces) is AUDIT-038.
- AUDIT-057…066 are current-tree follow-ups, not a second normalization pass. Existing task IDs carry overlapping canonical findings; the new file records only newly confirmed behavior, owner decisions, or residual scope.
- No task requires further splitting except AUDIT-043 and AUDIT-054, which are explicitly phased programs with per-phase exit criteria inside the task.
