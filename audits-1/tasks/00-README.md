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
- `[TODO]`: **5** (AUDIT-034, AUDIT-041, AUDIT-042, AUDIT-054, AUDIT-066)
- `[IN PROGRESS]`: **0**
- `[DONE]` implementation tasks: **58** (AUDIT-001, AUDIT-002, AUDIT-003, AUDIT-005, AUDIT-006, AUDIT-008, AUDIT-009, AUDIT-010, AUDIT-011, AUDIT-012, AUDIT-013, AUDIT-014, AUDIT-015, AUDIT-016, AUDIT-017, AUDIT-018, AUDIT-019, AUDIT-020, AUDIT-021, AUDIT-022, AUDIT-023, AUDIT-024, AUDIT-025, AUDIT-026, AUDIT-027, AUDIT-028, AUDIT-029, AUDIT-030, AUDIT-031, AUDIT-032, AUDIT-033, AUDIT-035, AUDIT-036, AUDIT-037, AUDIT-038, AUDIT-039, AUDIT-040, AUDIT-043, AUDIT-044, AUDIT-045, AUDIT-046, AUDIT-047, AUDIT-048, AUDIT-049, AUDIT-050, AUDIT-051, AUDIT-052, AUDIT-053, AUDIT-055, AUDIT-056, AUDIT-057, AUDIT-058, AUDIT-059, AUDIT-060, AUDIT-062, AUDIT-063, AUDIT-064, AUDIT-065), plus **27 resolved/owner-dispositioned findings** recorded in `01-resolved-findings.md`
- `[BLOCKED]`: **3** (AUDIT-004 product decision; AUDIT-007 owner/policy; AUDIT-061 provider/history disposition)
- Standalone `[UNCONFIRMED]` dispositions: **0** — retained static defects are routed to tasks, while unmeasured runtime/device impact remains explicit profile-first, reproduce-first, or evidence-lane work
- `[NOT APPLICABLE]` / no-action: **5** (WP5 CLN-010…014 "keep" findings; see disposition map)
- Duplicate findings consolidated: WP2 already merged 55 source findings into 26 clusters; the normalized corpus is consolidated into AUDIT-001…056, while AUDIT-057…066 records non-duplicative current-tree findings and owner decisions from 2026-07-18
- Residual or partially-fixed findings folded into open tasks: 9 (CAN-011, CAN-022, CAN-024, AUD-RESET-001, DLP-010, DLP-014, UIUX-010, A11Y-008, TRV-005). TRV-005 is a confirmed residual finding rather than a partially-fixed one.

### Latest verification snapshot — 2026-07-29

- Fresh app/widget build: succeeded with **0 compiler warnings**
- Complete unit target: **593/593 passed**, 0 failed, 0 skipped
- Complete UI target: **26/26 passed**, 0 failed, 0 skipped; four QoS priority-inversion warnings remain under AUDIT-066
- Shared test plan and coverage rerun: **619/619 passed**, 0 failed, 0 skipped
- Coverage: **65.98% overall**, **73.67% app**, both above the enforced 40% thresholds
- SwiftLint: **0 violations, 0 serious across 317 files**
- Widget contract verifier and `git diff --check`: passed
- SwiftFormat remains outside the green claim because the repository has existing formatting debt and ignored DerivedData traversal

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
2. **AUDIT-002, AUDIT-003, AUDIT-005, AUDIT-056, AUDIT-057 … AUDIT-060 — DONE** — repository artifacts and retired agent trees removed; widget AccentColor mismatch cleared; hosted CI retired and owner-accepted as unnecessary for the private app; local agent guidance preserved; references classified; local test media ignored.
3. **AUDIT-006 — DONE** — confirmed content-bearing public log interpolations redacted; broader explicit-privacy policy work remains AUDIT-065.
4. **GROUP-02: AUDIT-008, AUDIT-009 — DONE** — ReplayGain and MP4 numbering metadata now parse and persist with AAC/ALAC fixture coverage.
5. **AUDIT-020 — DONE** — typed engine preferences now select every capable stored choice, migrate the legacy AudioKit value, and log deterministic fallbacks.
6. **AUDIT-025, AUDIT-039, AUDIT-044, AUDIT-048, AUDIT-053, AUDIT-065 — DONE** — repeat-one navigation, genre destinations, AI trust boundaries, widget contract drift protection, export cleanup, and explicit logging privacy classification are complete. **AUDIT-056 … AUDIT-060 are DONE**.
7. **AUDIT-010 — DONE** — schema V-next and safe migration ordering landed.
8. **GROUP-03: AUDIT-011, AUDIT-012 — DONE** — real migration tests protect the stage and the production listening-session lifecycle records bounded elapsed listening time.
9. **AUDIT-013, AUDIT-014, AUDIT-015 — DONE** — import failure cleanup, cancellation-aware flow control, and atomic duplicate claims landed together.
10. **AUDIT-016 — DONE** — missing files now follow a retry/quarantine policy instead of one-shot deletion.
11. **AUDIT-036 — DONE** — the app-wide observation boundary is authoritative.
12. **GROUP-07: AUDIT-037, AUDIT-038, AUDIT-021 — DONE** — Now Playing state, failure surfaces, import progress, and settings honesty now build on the corrected boundary.
13. **AUDIT-022, AUDIT-023, AUDIT-024, AUDIT-026, AUDIT-027, AUDIT-028, AUDIT-029 — DONE** — playable format truthfulness, EQ lifecycle restoration, durable sleep-timer ownership, media-reset recovery, diagnostics honesty, eligibility claim gating, and exactly-once AudioKit completion are complete.
14. **GROUP-09: AUDIT-017, AUDIT-018, AUDIT-019 — DONE** — repository scale/correctness, request ownership, and persisted playlist mutations landed as one library vertical.
15. **GROUP-08: AUDIT-045, AUDIT-046, AUDIT-047 — DONE** — cancellation/fallback, non-blocking Home rendering, generation seams, serialized session access, and the deterministic failure matrix are complete; eligible-device execution remains routed to AUDIT-055.
16. **AUDIT-040, AUDIT-064 — DONE** — focused adaptive-layout evidence is accepted for the private-app configuration; playback-error announcement, dismissal, deterministic lifecycle, and Reduce Motion behavior are complete. **AUDIT-042 — TODO** has an implemented service slice but still requires trace and manual evidence.
17. **AUDIT-041 — TODO** — actor-owned/coalesced queue persistence and force-quit restoration are verified; queue-scale File Activity evidence remains.
18. **GROUP-05 audio core: AUDIT-030, AUDIT-031, AUDIT-032, AUDIT-033, AUDIT-035, AUDIT-062, AUDIT-063 — DONE**. **AUDIT-034 — TODO** has native offline waveform evidence and retains representative real-track physical-device capture.
19. **AUDIT-049 — DONE** — event-driven widget sync and off-main artwork/file ownership are complete after the AUDIT-048 drift guard.
20. **AUDIT-050, AUDIT-051, AUDIT-052 — DONE** — local test hygiene, real integration/10k scale lanes, and the Xcode-gated dead-code batch are complete; hosted-CI skip reporting is owner-accepted as not applicable. **AUDIT-066 — TODO** retains QoS warning-family closure.
21. **AUDIT-043 — DONE** — catalogs, plurals, formatters, composition, and focused double-length/RTL screenshots are implemented; the owner accepted this evidence for the supported private-app configuration without requiring an exhaustive localization/accessibility matrix.
22. **AUDIT-054 — TODO** — structured cancellable startup and scale coverage are implemented; the required profile-first trace program remains.
23. **AUDIT-055 — DONE BY OWNER SCOPE** — release/device evidence is not required while the app remains private and undistributed; personal hardware QA remains optional.
24. **AUDIT-004, AUDIT-007, AUDIT-061** — product, policy, and provider/history decisions; execute only when explicitly unblocked.

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
- AUDIT-057 → blocks speculative CI work; AUDIT-005 is closed by owner scope and reopens only if hosted CI becomes an explicit requirement
- AUDIT-062 → related-precedes AUDIT-030/031; AUDIT-063 coordinates with AUDIT-031/032; AUDIT-036 → related-precedes AUDIT-064
- AUDIT-061 → blocked by provider/account ownership and any separate history-rewrite decision
- AUDIT-004 → blocked by product decision; AUDIT-007 → blocked by owner/policy decisions; AUDIT-055 is closed by private-app scope
- No circular dependencies: the audio chain is linear (030/031/033 → 032/034), UI chain is a tree rooted at 036, data chain is linear (010 → 011/012).

## Implementation Groups

- **GROUP-01 — Repository hygiene & security** (AUDIT-001, 002, 003, 005 — DONE; AUDIT-056 is related post-002 cleanup): same `.gitignore`/tracked-file/CI surface; hosted-CI reintroduction is explicitly out of private-app scope.
- **GROUP-02 — Import metadata correctness — DONE** (AUDIT-008, 009): ReplayGain, MP4 track/disc tuples, and totals are covered by shared extraction and persistence fixtures.
- **GROUP-03 — Listening sessions — DONE** (AUDIT-010, 011, 012): the schema/migration/lifecycle vertical is complete with real prior-store and deterministic lifecycle coverage.
- **GROUP-04 — Import pipeline integrity** (AUDIT-013, 014, 015): failure cleanup, cancellation, and atomic dedup all reshape the same `FileImportProcessor` flow; interleaving other work would produce conflicting rewrites.
- **GROUP-05 — Audio session & transitions** (AUDIT-030, 031, 032, 033 — DONE; AUDIT-034 — TODO): one playback state machine; the implementation predecessors are complete and gapless retains offline/device evidence.
- **GROUP-06 — Format contract — DONE** (AUDIT-022): codec inspection and advertised-format pruning ship together with real AAC, ALAC, FLAC, and unsupported-Opus fixtures.
- **GROUP-07 — Observation & UI state ownership — DONE** (AUDIT-036, 037, 038, UI half of 021): consumers now share the corrected observation boundary and authoritative presentation state.
- **GROUP-08 — Foundation Models hardening — DONE** (AUDIT-044, 045, 046, 047): behavior hardening and the deterministic failure matrix are complete; AUDIT-055 retains eligible-device evidence.
- **GROUP-09 — Library data layer — DONE** (AUDIT-017, 018, 019): repository pagination/count semantics, request ownership, and persisted playlist mutation now form one validated vertical.
- **GROUP-10 — Test hygiene — DONE** (AUDIT-050, 051): deterministic clocks, isolated defaults, skip policy, and parallel simulator validation are implemented; hosted-CI skip reporting is not applicable.
- **GROUP-11 — Measurement honesty — DONE** (AUDIT-027, 028): diagnostics now model unavailable data explicitly and bit-perfect wording remains eligibility-only until physical measurement evidence exists.
- **GROUP-12 — Widget contracts & sync — DONE** (AUDIT-048, 049): drift guard and event-driven payload/artwork scheduling are complete.
- **GROUP-13 — Current repository cleanup** (AUDIT-057, 058, 059, 060): owner-approved CI retirement, local-guide preservation, reference classification, and test-media exclusion; no application behavior or Git-index mutation.

## Task decomposition notes

- The original ledger's release matrix (X-08) remains recorded as AUDIT-055, but is owner-closed as not applicable while the app is private and undistributed.
- CP-series performance findings were deliberately consolidated rather than split into 9 speculative micro-tasks: CP-008, CP-010, CP-011, CP-013, CP-016 and the app half of CP-009 form the AUDIT-054 profile-first umbrella (statically identified smells with **unmeasured** runtime impact; the audit itself requires traces before code changes). The rest ride their subsystem tasks: CP-012 → AUDIT-027, CP-014 → AUDIT-017, CP-015 → AUDIT-042, CP-007 → AUDIT-029, widget half of CP-009 → AUDIT-049.
- CAN-022 (failure silence) was split: playback errors are already fixed in-flight; the remainder (Home/Search/File Manager/import surfaces) is AUDIT-038.
- AUDIT-057…066 are current-tree follow-ups, not a second normalization pass. Existing task IDs carry overlapping canonical findings; the new file records only newly confirmed behavior, owner decisions, or residual scope.
- No open task requires further splitting except AUDIT-054, which is an explicitly phased program with per-phase exit criteria inside the task.
