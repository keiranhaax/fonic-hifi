# Fonic HiFi — Production Release Audit — Executive Summary

**Repo:** github.com/keiranhaax/fonic-hifi @ commit `459db9b` · **Audit date:** 2026-07-09
**Scope:** Full static audit — backend audio/data logic, frontend UI/UX, project configuration, dead/partial/debug code.
**Verdict:** The architecture is genuinely strong and most of the codebase is production-quality, but the app is **not releasable today**. Three Critical issues (one security emergency), and a cluster of High-severity defects that break the app's core promise — bit-perfect, uninterrupted playback — must be fixed first.

---

## TLDR — the most critical issues

1. **SECURITY EMERGENCY: four live API credentials are committed to this now-public repo** (`.kilocode/mcp.json` lines 45/77/92: Brave, Exa, and a Bearer token; `.claude/settings.local.json` line 83: an X-API-Key plus a private Tailscale IP `100.84.79.***`). The repo became public tonight. Rotate all four keys immediately, then scrub the files and history. (Fix Plan, Phase 0.)
2. **App Store submission will fail:** no `PrivacyInfo.xcprivacy` anywhere in the project (required since 2024; `UserDefaults` — a required-reason API — is used in 28 files), and `ITSAppUsesNonExemptEncryption` is missing so every upload stalls on export compliance. (Phase 1.)
3. **The flagship Smart Search feature is a dead end:** tapping any AI search result does nothing — `SearchView.playTrack` is a placeholder that only logs (`SearchView.swift:180-184`), and the view model's error state has no UI branch, so on-device AI failures show a blank screen. (Phase 3.)
4. **The audiophile core promise is currently not delivered:**
   - Unplugging headphones does **not** pause playback — audio continues on the speaker (`StateCoordinator.swift:191-205` only logs the event).
   - Gapless playback is broken on the lossless AVAudioEngine path — every track change deactivates the audio session, producing an audible gap (`AVAudioEngineAdapter` has no crossfade/gapless override; `AudioSessionManager.swift:119`).
   - The **default** engine is AudioKit, whose chain always routes through a TimePitch node and mixer — i.e., the default configuration is **not bit-perfect** (`AudioEngineFactory.swift:107-146`).
   - FLAC — the flagship audiophile format — is misclassified as "not natively supported" and forced off the bit-perfect path (`AVAudioEngineConfig.swift:156-165`); AVAudioEngine has handled FLAC natively since iOS 11.
5. **~1,860 lines of dead Swift ship in the binary** (the project uses Xcode synchronized folder groups, so every file on disk compiles): an unused Liquid Glass tab bar/rail family, superseded library list views, a 490-line abandoned import subsystem, and five services referenced only by their own tests.
6. **CI has never been able to build this project** — the workflow pins Xcode 16.1 on macos-15, which cannot open an objectVersion-90 / iOS 26 project.

## Verified finding counts

| Domain | Critical | High | Medium | Low | Report |
|---|---|---|---|---|---|
| Backend audio & data | 0 | 4 | 5 | 2 | `02-backend-audio-audit.md` |
| Frontend UI/UX | 1 | 6 | 5 | 2 | `03-frontend-uiux-audit.md` |
| Config & hygiene | 2 | 4 | 4 | 2 | `04-config-hygiene-audit.md` |
| Dead / partial code | 0 | 4 | 3 | 2 | `05-dead-code-audit.md` |
| **Total** | **3** | **18** | **17** | **8** | **46 findings** |

Every finding cites file, line numbers, and a verbatim code excerpt read during this audit. All Critical and High findings were independently re-verified by the lead auditor against the clone (see `06-VERIFICATION-LOG.md`). One sub-auditor claim was **corrected** during verification: "app has no icon" was wrong — a valid Xcode 26 Icon Composer asset (`Fonic HiFi/Fonic.icon`) exists with light/dark/tinted layers; the finding is downgraded to a Medium cleanup (empty legacy `AppIcon.appiconset`, sloppy internal asset name, needs one Xcode build verification).

## What is genuinely good (verified — preserve these)

- **EQ subsystem is complete and the strongest module:** a real 10-band `AVAudioUnitEQ` with a true bit-perfect bypass. Not a stub.
- **Smart Search AI is real, on-device Foundation Models** — no external endpoint, no API key in the app itself.
- **Zero `print`/`NSLog`, zero TODO/FIXME, zero `try!`/`fatalError`/force-unwraps in the production audio core.** Logging is proper `os.Logger` throughout.
- **Swift 6 language mode with complete strict concurrency is genuinely enabled** on all targets; only one `@unchecked Sendable` remains and it is justified.
- Security-scoped resource handling on the live import path is correctly `defer`-balanced on all branches.
- App Group configuration is consistent across app, widget, and code. `UIBackgroundModes: audio` is present.
- Clean Debug/Release build separation; versions consistent; AudioKit 5.6.5 stable (MIT).
- The `DominantColorService` → `ThemePalette` artwork-driven theming is a real differentiator worth keeping.
- Test suite is healthy: 94 files, no disabled/orphaned tests; all `XCTSkip`s are legitimate environment guards.

## How to use this package

1. Read this summary.
2. Follow **`01-FIX-PLAN.md`** — a phased, step-by-step remediation plan (Phase 0 = today's security emergency; Phases 1-6 in priority order). Each step names exact files, what to change, what to preserve, and points to the paste-ready code sample in the matching domain report.
3. The four domain reports contain the full evidence and production-ready fix code for every finding.
4. `06-VERIFICATION-LOG.md` documents the independent re-verification and the one corrected claim.

## Audit method & limits (honest disclosure)

- Four specialist auditors reviewed the domains in parallel; the lead auditor then independently re-verified every Critical/High claim (and several Mediums) against the clone with targeted reads and reference-count greps before packaging.
- This audit ran in a Linux sandbox **without Xcode or Apple SDKs**: findings are from static code review, not compilation or runtime testing. Items that need a build or a device to confirm are explicitly labeled `UNVERIFIED — needs Xcode check` in the reports. Expect the fixes themselves to surface minor compile-level adjustments when first built.
- Nothing in the repository was modified. This package is the deliverable; no fixes have been applied, per the agreed stop line.
