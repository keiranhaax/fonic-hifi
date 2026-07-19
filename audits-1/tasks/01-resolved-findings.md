# Resolved Findings Register — `[DONE]` + Partial Evidence

This register contains 27 findings demonstrably fixed in the current working tree and one explicitly partial dead-code evidence row (validated 2026-07-15). No implementation task is created for fully resolved rows; residual verification or remaining work is routed to the named task. Evidence cites current file:line.

| # | Finding ID(s) | Title | Evidence of fix | Residual |
|---|---|---|---|---|
| 1 | CAN-002 (PCFG-002, PSR-002 / WP3-002) | Missing privacy manifests | `Fonic HiFi/PrivacyInfo.xcprivacy` and `Fonic HiFi Widget/PrivacyInfo.xcprivacy` exist and are tracked | Archive-time validation → AUDIT-005 |
| 2 | CAN-003 (PCFG-003, PSR-003, TRV-001 / WP3-003) | CI selected an impossible toolchain | The failing hosted workflow is intentionally absent by owner decision under AUDIT-057 | Any future CI contract and green-run evidence → AUDIT-005 |
| 3 | CAN-004 (PCFG-004, TRV-002) | No shared scheme/test plan | Tracked `Fonic HiFi.xcodeproj/xcshareddata/xcschemes/Fonic HiFi.xcscheme` and `Fonic HiFi.xctestplan` | — |
| 4 | CAN-005 (PCFG-007, TRV-014) | No Release/analyze gates | Temporarily accepted while hosted CI is intentionally disabled; local `make build-release` and `make analyze` recipes remain available | Restore gates when CI is reintroduced → AUDIT-005; signed archive lane → AUDIT-055 |
| 5 | PCFG-006 / CLN-002 | Orphan mode-160000 gitlink | `git ls-files -s \| awk '$1==160000'` returns nothing | — |
| 6 | DCA-PART-003 | QueueCoordinator inert methods | `rg removeFromQueue\|moveInQueue\|insertInQueue` in Core/Audio returns nothing (ledger E-06 verified) | — |
| 7 | AUD-REMOTE-001 | Skip commands enabled but discarded | `AudioSessionManager.swift:266-286` keeps `skipForward/Backward` disabled and targets removed (ledger E-08) | — |
| 8 | AUD-RECOVERY-001 | Queue resume position dropped, shuffle restored wrong | `AudioQueueManager.swift:656-662` restores persisted traversal; `AudioEngineFacade.swift:328-332,426-430` seeks restored position on first play | — |
| 9 | CAN-014 (AUD-QUEUE-001, UIUX-013) | Queue edit offsets translated wrong | `QueueView.swift:46-64` passes visible offsets to manager-owned translation; `AudioQueueManager.swift:203-221,261-285` computes `baseIndex` atomically, incl. shuffled edits (ledger E-07 + later work) | — |
| 10 | DLP-001 (WP3-007) | In-memory fallback masked as normal store | `DataManager+Initialization.swift:385-388` marks `isFallback: true` + recovery state; `FonicHiFiApp.swift:78-83` surfaces recovery-mode UI | Non-destructive recovery *contract* remains open in AUDIT-016 notes |
| 11 | DLP-015 | Duplicate recent-search rows/IDs | `RecentSearchesActor.swift:26-36` normalizes and consolidates duplicates before save | — |
| 12 | UIUX-011 | Smart Search unreachable | `SearchView.swift:105-118` toolbar menu always exposes Smart Search | — |
| 13 | UIUX-014 | Nested NavigationStack in Audio Settings | `SettingsView.swift:27` owns the stack; `AudioSettingsView.swift:10-11` is content-only | — |
| 14 | UIUX-016 | Reset All Settings without confirmation | `SettingsView.swift:190-210` destructive confirmation alert | — |
| 15 | UIUX-017 | File Manager multi-select had no touch entry | `FileManagerView.swift:146-149` toolbar `EditButton` | — |
| 16 | UIUX-018 | Full-screen blocking pagination loader | `LibraryView.swift:219-259` inline loading rows; overlay only for empty first page (`:70-76`) | — |
| 17 | CAN-018 (UIUX-015, A11Y-001 / WP3-021) | Raw gestures instead of semantic controls | `TrackRowView.swift:25` and `LiquidGlassMiniPlayer.swift:22,73` use `Button` | Runtime VoiceOver pass → AUDIT-055 |
| 18 | CAN-019 (UIUX-020, A11Y-002 / WP3-022) | EQ drag-only, no adjustable semantics | `EqualizerView.swift:96-101` 44-pt interaction frames; `:222-228` `accessibilityAdjustableAction` | Device VoiceOver pass → AUDIT-055 |
| 19 | A11Y-003 | Lyrics overlay close name/modal focus | `LyricsView.swift:41-42,72-79` named close + modal trait + focus | — |
| 20 | A11Y-004 | Slider purpose labels/values | `NowPlayingContent.swift:564-565`, `AudioSettingsView.swift:104-107`, `SleepTimerSheet.swift:116-117` | — |
| 21 | A11Y-005 | Favorite/A-B loop hit regions < 44pt | `NowPlayingContent.swift:380-384,443-447` explicit 44×44 frames | — |
| 22 | A11Y-007 | Reduce Motion not honored | `NowPlayingContent.swift:19,54-55` gates animation on `reduceMotion` | — |
| 23 | CAN-021 (UIUX-019, FMA-001) | Surprise Me lacked single-flight gate | `HomeView.swift:51,108-111,273-278` `SurpriseMeRequestGate.begin()` + `defer` release | — |
| 24 | DCA-PART-004 | Smart-search taps only logged | `SmartSearchResultsView.swift:65-70` → `SearchView.swift:49-61` routes taps to `playTrack(track)` | — |
| 25 | DCA-DEAD-001 (partial evidence) | Four files from the 18-file dead-code inventory removed | Spot-check: `TrackCache.swift`, `PlaybackStateStore.swift`, `AudioSettingsService.swift`, `PlaybackDiagnosticFormatters.swift` no longer exist under the production root | Remaining-file sweep folded into AUDIT-052; the full finding is not DONE |
| 26 | DCA-SAMPLE-001 / CLN-005 | Sample fragments without build containers | `sample/AppleMusicBottomBar`, `sample/CustomMenu`, `sample/CustomToolBottomBar` each have `.xcodeproj` containers | — |
| 27 | PCFG-009 | SwiftLint excluded widget/UI-test roots | `.swiftlint.yml:1-7` explicitly includes all four target roots | — |
| 28 | TRV-003 | test-unit/test-ui were aliases | `Makefile:267-309` uses distinct `-only-testing:` filters and result bundles | — |

**Caution for the implementation agent:** several of these fixes exist only in *uncommitted* working-tree changes or recent commits (`98f4263…723c81a`). Do not revert or overwrite them; re-verify any row above before building on it.
