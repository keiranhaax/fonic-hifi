# Finding Disposition Map

Every normalized WP1–WP5 finding from the audit corpus is mapped to its task or disposition. Model A's 46 findings were not independently normalized; corroborating Model A IDs are cross-referenced where used. Generated against the current working tree on 2026-07-15; regenerate the routing if task files are renumbered.

Legend: `AUDIT-###` = task in files `02`–`10`; `DONE — 01-resolved-findings.md` = verified fixed or explicitly owner-dispositioned in the current tree (see that register for evidence); split routings list every task that carries part of the finding.

## WP2 canonical findings (118) → disposition

| Canonical ID | Severity | Title | Member source IDs | Disposition |
|---|---|---|---|---|
| CAN-001 | Critical | Four credential values of unverified current validity and a sensitive local endpoint are committed | PCFG-001, PSR-001 | AUDIT-001 (worktree removal), AUDIT-061 (provider/history disposition) |
| CAN-002 | Critical | App and widget lack required-reason privacy manifests | PCFG-002, PSR-002 | AUDIT-005, DONE — 01-resolved-findings.md |
| AUD-ENG-002 | High | Play requests are not serialized or cancelled | AUD-ENG-002 | AUDIT-030 |
| AUD-SESSION-001 | High | Audio-session ownership is split and native load deactivates after activation | AUD-SESSION-001 | AUDIT-031 |
| AUD-SESSION-002 | High | Interruption intent and route-loss safety are not preserved | AUD-SESSION-002 | AUDIT-032 |
| CAN-003 | High | CI selects an impossible and internally conflicting iOS 26 toolchain | PCFG-003, PSR-003, TRV-001 | AUDIT-057 (workflow retired), AUDIT-005 (reintroduction blocked), DONE — 01-resolved-findings.md |
| CAN-009 | High | Listening-session tracking exists but is never wired into production | DLP-004, DCA-PART-001 | AUDIT-011 |
| CAN-010 | High | Concurrent import deduplication has a check-to-insert race | DLP-006, CP-004 | AUDIT-014 |
| CAN-013 | High | Import cancellation does not propagate to AsyncStream producers | DLP-021, CP-002 | AUDIT-015 |
| CAN-018 | High | Primary library and mini-player actions use raw gestures instead of semantic controls | UIUX-015, A11Y-001 | DONE — 01-resolved-findings.md |
| CAN-019 | High | The 10-band EQ is a drag-only, undersized, non-adjustable control | UIUX-020, A11Y-002 | DONE — 01-resolved-findings.md |
| CAN-022 | High | Failures are collapsed into silence, false emptiness, or generic fallback states | UIUX-009, FMA-004 | AUDIT-038 |
| CAN-024 | High | Visible audio settings persist values but do not configure the active audio engine | AUD-CONFIG-001, UIUX-008 | AUDIT-021 |
| CP-003 | High | Queue mutations synchronously persist the full queue on the MainActor | CP-003 | AUDIT-041 |
| DLP-001 | High | Persistent-store failure is masked by a normal-mode in-memory store | DLP-001 | DONE — 01-resolved-findings.md |
| DLP-002 | High | `ListeningSession` is absent from the schema that its actor uses | DLP-002 | AUDIT-010 |
| DLP-003 | High | The declared migration plan is only a fallback after an unplanned open | DLP-003 | AUDIT-010 |
| DLP-005 | High | Import failure after copy leaks managed audio files | DLP-005 | AUDIT-013 |
| DLP-007 | High | Startup cleanup converts temporary unavailability into permanent library deletion | DLP-007 | AUDIT-016 |
| PSR-004 | High | Release logging marks user library content and diagnostic details public | PSR-004 | AUDIT-006 (confirmed `.public` content fixed), AUDIT-065 (explicit-privacy residual) |
| UIUX-001 | High | The app-wide audio model is injected as an unobserved environment value | UIUX-001 | AUDIT-036 |
| UIUX-002 | High | Now Playing duplicates authoritative shuffle, repeat, and speed state | UIUX-002 | AUDIT-037 |
| UIUX-010 | High | Import progress is unobserved; picker errors are invisible; presentation depends on a race | UIUX-010 | AUDIT-038 |
| A11Y-003 | Medium | The lyrics overlay lacks an accessible close name and modal focus management | A11Y-003 | DONE — 01-resolved-findings.md |
| A11Y-004 | Medium | Volume, crossfade, and fade-out sliders do not expose purpose-specific labels/values | A11Y-004 | DONE — 01-resolved-findings.md |
| A11Y-005 | Medium | Favorite and A-B loop controls have visible hit regions below 44×44 points | A11Y-005 | DONE — 01-resolved-findings.md |
| A11Y-007 | Medium | Active palette and lyrics transitions do not honor Reduce Motion | A11Y-007 | DONE — 01-resolved-findings.md |
| A11Y-008 | Medium | Shuffle-on and repeat-all states rely on opacity/color when their symbols do not change | A11Y-008 | AUDIT-040 |
| AUD-BIT-001 | Medium | Bit-perfect cache is not keyed by track or route | AUD-BIT-001 | AUDIT-028 |
| AUD-BIT-002 | Medium | “Bit-perfect” is asserted without observing the active engine signal path | AUD-BIT-002 | AUDIT-028 |
| AUD-ENG-001 | Medium | AVAudioEngine preference is ignored | AUD-ENG-001 | AUDIT-020 (DONE) |
| AUD-FORMAT-001 | Medium | M4A container is always reported as ALAC/lossless | AUD-FORMAT-001 | AUDIT-022 |
| AUD-FORMAT-002 | Medium | Import UI exposes formats the playback detector cannot represent | AUD-FORMAT-002 | AUDIT-022 |
| AUD-QUEUE-002 | Medium | Repeat-one also repeats manual Next/Previous | AUD-QUEUE-002 | AUDIT-025 |
| AUD-RECOVERY-001 | Medium | Queue resume position is dropped and shuffled order is restored incorrectly | AUD-RECOVERY-001 | DONE — 01-resolved-findings.md |
| AUD-REMOTE-001 | Medium | Skip commands are enabled but discarded | AUD-REMOTE-001 | DONE — 01-resolved-findings.md |
| AUD-RESET-001 | Medium | Media-services reset does not rebuild invalid audio objects | AUD-RESET-001 | AUDIT-026 |
| AUD-SEEK-001 | Medium | Native seek loses absolute offset; A-B loop is coarse and failure-blind | AUD-SEEK-001 | AUDIT-035 |
| AUD-TRANSITION-001 | Medium | Gapless/native crossfade controls do not produce seamless transitions | AUD-TRANSITION-001 | AUDIT-034 |
| AUD-TRANSITION-002 | Medium | Cancelling an AudioKit crossfade leaves split playback state | AUD-TRANSITION-002 | AUDIT-033 |
| CAN-004 | Medium | No committed shared scheme or test plan defines the CI test action | PCFG-004, TRV-002 | DONE — 01-resolved-findings.md |
| CAN-005 | Medium | Release, analyzer, archive, and distribution-signing behavior is not gated | PCFG-007, TRV-014 | DONE — 01-resolved-findings.md |
| CAN-006 | Medium | Tracked local, generated, user-state, log, and backup artifacts defeat repository hygiene | PCFG-008, PSR-007, DCA-ART-001 | AUDIT-002 (DONE); full Claude tree residual → AUDIT-056 (DONE) |
| CAN-011 | Medium | Every pagination request hydrates the full result set to compute an unused count | DLP-012, CP-014 | AUDIT-017 |
| CAN-012 | Medium | Listening-session replacement is unsequenced and can clear the new session | DLP-019, CP-005 | AUDIT-011 |
| CAN-014 | Medium | Queue edit callbacks translate visible offsets to the wrong absolute indices | AUD-QUEUE-001, UIUX-013 | DONE — 01-resolved-findings.md |
| CAN-015 | Medium | Sleep-timer ownership is transient and fade volume starts from 1.0 | AUD-SLEEP-001, UIUX-007 | AUDIT-024 |
| CAN-016 | Medium | Audio diagnostics report synthetic zero metrics while polling an empty collector | AUD-DIAG-001, DCA-PART-005 | AUDIT-027 |
| CAN-017 | Medium | Widget synchronization is stale and poll-driven | AUD-WIDGET-001, DLP-016, CP-006 | AUDIT-049 |
| CAN-021 | Medium | Surprise Me lacks a single-flight gate for its shared model session and playback side effects | UIUX-019, FMA-001 | DONE — 01-resolved-findings.md |
| CAN-023 | Medium | Persisted EQ is not restored or reapplied across engine creation and switching | AUD-DSP-001, DCA-PART-002 | AUDIT-023 |
| CAN-025 | Medium | Now Playing lacks an adaptive scroll/layout contract for short heights and Dynamic Type | UIUX-006, A11Y-006 | AUDIT-040 |
| CAN-026 | Medium | Missing prerequisites and behavior are converted into passing test skips | TRV-004, TRV-015 | AUDIT-050 |
| CP-001 | Medium | Semaphore waiters are not cancellation-aware | CP-001 | AUDIT-015 |
| CP-007 | Medium | AudioKit creates a MainActor task every 100 ms in addition to centralized polling | CP-007 | AUDIT-029 |
| CP-008 | Medium | Home and Search execute synchronous SwiftData work on the MainActor | CP-008 | AUDIT-054 |
| CP-009 | Medium | Widget artwork processing and file maintenance run on the MainActor | CP-009 | AUDIT-049, AUDIT-054 |
| CP-010 | Medium | Artwork cache limits entries, not memory cost | CP-010 | AUDIT-054 |
| CP-011 | Medium | SwiftUI bodies materialize arrays during every library/queue evaluation | CP-011 | AUDIT-054 |
| CP-015 | Medium | File Manager uses synchronous UI-context I/O and an uncancellable detached copy | CP-015 | AUDIT-042 |
| CP-016 | Medium | Render paths rebuild formatters and full sort/filter results | CP-016 | AUDIT-054 |
| DLP-008 | Medium | ReplayGain metadata is extracted and then discarded | DLP-008 | AUDIT-008 (DONE) |
| DLP-009 | Medium | Track/disc tuple parsing uses wrong offsets and drops parsed totals | DLP-009 | AUDIT-009 (DONE) |
| DLP-010 | Medium | The exposed playlist feature has no complete mutation path | DLP-010 | AUDIT-019 |
| DLP-011 | Medium | Repository-backed library state is not refreshed after writes | DLP-011 | AUDIT-017 |
| DLP-013 | Medium | Page mapping dereferences to-many relationships per album/artist | DLP-013 | AUDIT-017 |
| DLP-014 | Medium | Search bypasses the repository and silently truncates results | DLP-014 | AUDIT-017 |
| DLP-015 | Medium | Repeated recent searches create duplicate persistence rows and duplicate SwiftUI IDs | DLP-015 | DONE — 01-resolved-findings.md |
| DLP-017 | Medium | Listening-session persistence has no retention bound | DLP-017 | AUDIT-011 |
| DLP-020 | Medium | Playback position is mistaken for time actually listened | DLP-020 | AUDIT-011 |
| FMA-002 | Medium | Generated track UUIDs are structurally typed but not checked against the offered set | FMA-002 | AUDIT-044 |
| FMA-003 | Medium | Canceled Smart Search work can be converted into a fallback result and overwrite newer state | FMA-003 | AUDIT-045 |
| FMA-005 | Medium | Smart Search’s documented standard-search fallback returns an empty AI result without handing off | FMA-005 | AUDIT-045 |
| FMA-007 | Medium | Tests do not deterministically exercise the live model path or its failure matrix | FMA-007 | AUDIT-047 |
| FMA-008 | Medium | Initial Home rendering waits for a full model response | FMA-008 | AUDIT-046 |
| LOC-001 | Medium | There is no localization resource pipeline despite extensive English UI and accessibility copy | LOC-001 | AUDIT-043 |
| LOC-002 | Medium | Count-bearing strings bypass plural rules | LOC-002 | AUDIT-043 |
| LOC-003 | Medium | User-visible technical values bypass locale-aware number and measurement formatting | LOC-003 | AUDIT-043 |
| LOC-004 | Medium | Precomposed metadata strings are not translator-reorderable for bidirectional layouts | LOC-004 | AUDIT-043 |
| PCFG-005 | Medium | Dependency/tool resolution is only partly pinned and not enforced in CI | PCFG-005 | AUDIT-005 |
| PCFG-006 | Medium | A mode-160000 gitlink has no `.gitmodules` mapping or available object | PCFG-006 | DONE — 01-resolved-findings.md |
| PSR-005 | Medium | Imported-audio destination protection and backup policy are implicit and unverified | PSR-005 | AUDIT-007 |
| PSR-006 | Medium | In-app privacy disclosure omits material local data and retention/deletion behavior | PSR-006 | AUDIT-007 |
| TRV-003 | Medium | Unit and UI commands are indistinguishable aliases | TRV-003 | DONE — 01-resolved-findings.md |
| TRV-005 | Medium | Audio tests contain test theater and over-broad error assertions | TRV-005 | AUDIT-050 |
| TRV-006 | Medium | “Integration” playback uses fake bytes, fake metadata, and a test-only controller | TRV-006 | AUDIT-051 |
| TRV-008 | Medium | Real sleeps make async and timer tests scheduler-dependent | TRV-008 | AUDIT-050 |
| TRV-009 | Medium | Shared process/sandbox state breaks test isolation | TRV-009 | AUDIT-050 |
| TRV-010 | Medium | Persistent-store and migration behavior is not exercised | TRV-010 | AUDIT-012 |
| TRV-011 | Medium | Library scale/performance tests do not model production storage or establish stable metrics | TRV-011 | AUDIT-051 |
| TRV-016 | Medium | No physical-device media acceptance lane covers the product's highest-risk behavior | TRV-016 | AUDIT-055 |
| UIUX-003 | Medium | The mini player is always shown, including with no track | UIUX-003 | AUDIT-037 |
| UIUX-004 | Medium | The iOS 26 tab accessory never adapts to inline placement | UIUX-004 | AUDIT-037 |
| UIUX-005 | Medium | Full-screen Now Playing has no visible dismissal control | UIUX-005 | AUDIT-037 |
| UIUX-011 | Medium | Smart Search is effectively unreachable from the active Search states | UIUX-011 | AUDIT-045, DONE — 01-resolved-findings.md |
| UIUX-012 | Medium | Multiple browse affordances have no destination or action | UIUX-012 | AUDIT-039 (DONE) |
| UIUX-017 | Medium | File Manager's multi-select actions have no touch-only edit-mode entry | UIUX-017 | DONE — 01-resolved-findings.md |
| UIUX-018 | Medium | Every library pagination fetch presents a full-screen blocking loader | UIUX-018 | DONE — 01-resolved-findings.md |
| CAN-007 | Low | Info.plist claims Live Activity support without an Activity configuration | PCFG-010, PSR-009 | AUDIT-004 |
| CAN-008 | Low | The app carries an unused APNs capability | PCFG-012, PSR-008 | AUDIT-004 |
| CP-012 | Low | Optional diagnostics start a no-op poller; sample histories are now bounded | CP-012 | AUDIT-027 |
| CP-013 | Low | Deferred startup work is unowned and cancellation-blind | CP-013 | AUDIT-054 |
| DCA-DEAD-001 | Low | Eighteen target-included files were reported without production consumers; four are removed and the remainder needs a fresh sweep | DCA-DEAD-001 | AUDIT-052, partial evidence in 01-resolved-findings.md |
| DCA-DEAD-002 | Low | Live files contain 61 manually retained unreferenced symbol roots | DCA-DEAD-002 | AUDIT-052 |
| DCA-PART-003 | Low | QueueCoordinator exposes three inert methods beside working manager APIs | DCA-PART-003 | DONE — 01-resolved-findings.md |
| DCA-PART-004 | Low | Smart-search result taps only log and never invoke playback | DCA-PART-004 | DONE — 01-resolved-findings.md |
| DCA-SAMPLE-001 | Low | Three undocumented sample app fragments have no build container | DCA-SAMPLE-001 | DONE — 01-resolved-findings.md |
| FMA-006 | Low | User queries and imported metadata are inserted into prompts without explicit untrusted-data boundaries | FMA-006 | AUDIT-044 |
| PCFG-009 | Low | SwiftLint excludes all widget and UI-test source | PCFG-009 | DONE — 01-resolved-findings.md |
| PCFG-011 | Low | Widget asset build settings name color sets that do not exist in the widget target | PCFG-011 | AUDIT-003 (DONE) |
| UIUX-014 | Low | Audio Settings nests a second navigation stack inside the Settings stack | UIUX-014 | DONE — 01-resolved-findings.md |
| UIUX-016 | Low | “Reset All Settings” executes immediately without confirmation | UIUX-016 | DONE — 01-resolved-findings.md |
| CAN-020 | Informational | Accessibility, Dynamic Type, locale, RTL, and widget behavior lack a real verification lane | A11YTEST-001, TRV-012 | AUDIT-055 |
| DCA-DUP-001 | Informational | Three app/widget shared-data contracts are manually duplicated | DCA-DUP-001 | AUDIT-048 |
| DLP-018 | Informational | Imported-audio backup policy is implicit and unverified | DLP-018 | AUDIT-007 |
| PSR-010 | Informational | Export classification is not encoded and needs final-archive determination | PSR-010 | AUDIT-007 |
| TRV-007 | Informational | Natural completion/gapless/crossfade output remains unverified | TRV-007 | AUDIT-034 |
| TRV-013 | Informational | Coverage gate is coarse and current evidence is not retained in the repository | TRV-013 | AUDIT-005 |

## WP1 Foundation Models findings (FMA-001…008)

These eight rows are routing cross-references, not additional normalized findings. Every FMA ID below is already included among the 147 WP2 source findings and therefore represented inside the 118 WP2 canonical rows above.

| WP1 ID | Disposition |
|---|---|
| FMA-001 | DONE — merged into CAN-021 (Surprise Me single-flight), fixed; see 01-resolved-findings.md |
| FMA-002 | AUDIT-044 |
| FMA-003 | AUDIT-045 |
| FMA-004 | AUDIT-038 (merged into CAN-022 failure-silence cluster) |
| FMA-005 | AUDIT-045 |
| FMA-006 | AUDIT-044 |
| FMA-007 | AUDIT-047 |
| FMA-008 | AUDIT-046 |

## WP3 reverified clusters (WP3-001…023)

WP3 re-verified Critical/High clusters and recalibrated severities; each cluster routes through its member finding(s).

| WP3 ID | Member(s) | Disposition |
|---|---|---|
| WP3-001 | PCFG-001, PSR-001 (CAN-001) | AUDIT-001 + provider/history residual in AUDIT-061 |
| WP3-002 | PCFG-002, PSR-002 (CAN-002) | DONE (manifests exist) + residual CI check in AUDIT-005 |
| WP3-003 | PCFG-003, PSR-003, TRV-001 (CAN-003) | Workflow intentionally retired in AUDIT-057; reintroduction/evidence blocked in AUDIT-005 |
| WP3-004 | AUD-ENG-002 | AUDIT-030 |
| WP3-005 | AUD-SESSION-001 | AUDIT-031 |
| WP3-006 | AUD-SESSION-002 | AUDIT-032 |
| WP3-007 | DLP-001 | DONE — fallback storage marked and surfaced |
| WP3-008 | DLP-002 | AUDIT-010 |
| WP3-009 | DLP-003 | AUDIT-010 |
| WP3-010 | DLP-004 (CAN-009) | AUDIT-011 |
| WP3-011 | DLP-005 | AUDIT-013 |
| WP3-012 | DLP-007 | AUDIT-016 |
| WP3-013 | CP-002 (CAN-013) | AUDIT-015 |
| WP3-014 | CP-003 | AUDIT-041 |
| WP3-015 | CP-004 (CAN-010) | AUDIT-014 |
| WP3-016 | UIUX-001 | AUDIT-036 |
| WP3-017 | UIUX-002 | AUDIT-037 |
| WP3-018 | UIUX-008 (CAN-024) | AUDIT-021 |
| WP3-019 | UIUX-009 (CAN-022) | AUDIT-038 |
| WP3-020 | UIUX-010 | AUDIT-038 |
| WP3-021 | A11Y-001 (CAN-018) | DONE — semantic Buttons present; runtime VoiceOver pass deferred to AUDIT-055 |
| WP3-022 | A11Y-002 (CAN-019) | DONE — adjustable EQ semantics present; device pass deferred to AUDIT-055 |
| WP3-023 | PSR-004 | AUDIT-006 (DONE) |

## WP4 retained refactoring candidates (R01…R08)

| WP4 ID | Disposition |
|---|---|
| WP4-R01 | AUDIT-036 (observation boundary / presentation model) |
| WP4-R02 | AUDIT-041 (queue persistence seam) |
| WP4-R03 | AUDIT-018 (library section request ownership) |
| WP4-R04 | AUDIT-042 (FileManager service + view model) |
| WP4-R05 | AUDIT-014 (TrackDataActor insertion kernel) |
| WP4-R06 | AUDIT-015 (AsyncStream producer lifetime/cancellation) |
| WP4-R07 | AUDIT-027 (injectable process-metrics provider) |
| WP4-R08 | AUDIT-048 (canonical app/widget shared contract) |

## WP5 cleanup register (CLN-001…015)

| WP5 ID | Disposition |
|---|---|
| CLN-001 | AUDIT-001 (credential-bearing configs) + AUDIT-002 (remaining artifacts, DONE); full Claude tree residual → AUDIT-056 (DONE) |
| CLN-002 | DONE — orphan gitlink no longer present (`git ls-files -s` shows no mode-160000 entries) |
| CLN-003 | AUDIT-052 |
| CLN-004 | AUDIT-052 |
| CLN-005 | DONE — sample roots now have `.xcodeproj` containers; tracked `xcuserdata` residue handled in AUDIT-002 |
| CLN-006 | AUDIT-048 |
| CLN-007 | AUDIT-002 (DONE) |
| CLN-008 | AUDIT-053 |
| CLN-009 | AUDIT-002 (DONE — empty AppIcon set removed; `Fonic.icon` remains) |
| CLN-010 | NOT APPLICABLE — keep AudioKit (negative finding) |
| CLN-011 | NOT APPLICABLE — negative finding; scheme/test-plan gap covered by CAN-004 (now DONE) |
| CLN-012 | NOT APPLICABLE — corrected false positive; keep assets |
| CLN-013 | NOT APPLICABLE — structural/tool-specific duplication; keep |
| CLN-014 | NOT APPLICABLE — `Files/` is an intentional historical archive; keep |
| CLN-015 | AUDIT-053 (documentation strategy/index) |

## Part 1 / Model A

Model A's production audit (46 findings) was not independently re-normalized: its findings corroborate Model B's and were previously routed by `docs/plans/2026-07-10-audit-crosscheck-remediation.md`. Where a Model A ID adds evidence to a task it is cited in that task's "Audit sources" line (e.g. A-C03 → AUDIT-001, A-F01 → AUDIT-036, A-B06 → AUDIT-041, A-B10 → AUDIT-029, A-C07/C09 → AUDIT-002).
