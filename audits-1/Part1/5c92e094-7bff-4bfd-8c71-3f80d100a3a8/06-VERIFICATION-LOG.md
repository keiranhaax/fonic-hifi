# Verification Log

Per the ground-truth rule, every Critical/High claim (and several Mediums) was independently re-checked by the lead auditor against the clone before packaging. This log records the direct checks and the one corrected claim.

## Corrected claim

- **"App has no icon assets (Critical → App Store rejection)"** — **CORRECTED, downgraded to Medium.** The config auditor saw an empty `AppIcon.appiconset` (Contents.json with no PNG filenames) and `ASSETCATALOG_COMPILER_APPICON_NAME = Fonic`, and concluded there was no icon. Re-check found `Fonic HiFi/Fonic.icon/` — a valid **Xcode 26 Icon Composer** asset with `icon.json` defining light/dark/tinted fill specializations and an SVG layer. `ASSETCATALOG_COMPILER_APPICON_NAME = Fonic` correctly points at it. So an icon exists and should build. Residual real issue: the empty legacy `AppIcon.appiconset` is ambiguous clutter and the asset name is undescriptive; needs one Xcode build to confirm the archive shows the icon. Reflected as Medium 1.3 in the fix plan.

## Direct re-verifications (all confirmed)

| Claim | Check run | Result |
|---|---|---|
| Route change doesn't pause | Read `StateCoordinator.swift:191-205` | Confirmed — `.oldDeviceUnavailable` only calls `logger.info`, no `pause()`. |
| No crossfade/gapless on AVAudioEngine path | `grep -n "func crossfade" AVAudioEngineAdapter.swift` | Confirmed absent (0 matches). |
| Session deactivated between tracks | `grep -rn notifyOthersOnDeactivation` | Confirmed at `AudioSessionManager.swift:119`. |
| Default engine = AudioKit, not bit-perfect | Read `AudioEngineFactory.swift:107-146` | Confirmed — `.balanced`/`.quality` prefer `.audioKitEngine`. |
| FLAC not natively supported | Read `AVAudioEngineConfig.swift:156-165` | Confirmed — `.flac` returns `false`. |
| Smart-search playback is a stub | Read `SearchView.swift:180-184` | Confirmed — placeholder comment + `logger.info` only. |
| `removeFromQueue` is a no-op | Read `QueueCoordinator.swift:101-104` | Confirmed — comment "would need to be implemented" + log, no mutation. |
| EQ slider has no a11y | `grep -c accessibility EqualizerView.swift` on `VerticalSlider` | Confirmed — 0 accessibility calls in the custom slider. |
| 0.5 s progress tick | Read `PlaybackController.swift:276-293` | Confirmed — `progressTimer.start(pollInterval: 0.5)`. |
| Leaked secrets | Parsed `.kilocode/mcp.json`, `.claude/settings.local.json` | Confirmed — 3 credentials in mcp.json (Brave/Exa/Bearer), 1 X-API-Key + private IP `100.84.79.***` in settings.local.json. (Values masked in all reports.) |
| No privacy manifest | `find . -name "*.xcprivacy"` | Confirmed — 0 files. |
| No export-compliance key | grep `ITSAppUsesNonExemptEncryption` across plists | Confirmed absent. |
| Background audio present (positive) | Read `Info.plist` UIBackgroundModes | Confirmed — `audio` present. |
| CI can't build | Read `.github/workflows/ci.yml:17` | Confirmed — `xcode-select -s /Applications/Xcode_16.1.app` on `macos-15`. |
| `.gitignore` broken | Read `.gitignore` tail + section | Confirmed — corrupted final line `.apdiskbuild_verify.log`; `*.xcodeproj` ignored while project is tracked. |
| Dead code ships (synchronized groups) | Reference-counted 9 symbols with `grep -rlw` across app+widget+tests | Confirmed — `LiquidGlassTabBar`/`LiquidGlassRail`/`AlbumGridView` = 0 refs anywhere; `ImportSession`/`AudioSettingsService`/`SearchCache`/`TrackCache`/`PlaybackStateStore`/`LibraryFilter` = 0 production refs, test-only. |
| Tracked local artifacts | `git ls-files` filter | Confirmed — `CLAUDE copy.md`, `project.pbxproj.backup`, multiple `xcuserdata` plists tracked. |
| AudioKit version (positive) | Read `Package.resolved` | Confirmed — AudioKit pinned, remote source, MIT. |

## Claims explicitly softened / labeled UNVERIFIED in the reports

- FLAC native decode *actually working* after the reclassification fix — needs a device build with a real FLAC file (static code can't prove the decoder path).
- AVAudioEngine `currentTime`-after-seek being wrong — reasoned from `scheduleSegment` semantics; labeled needs-runtime-confirmation.
- Any severity tied to visual rendering (glass legibility, layout) — static-only; flagged needs-Xcode-visual-check.

## Method note

`rg` is a shell function unavailable in non-interactive subshells here; the dead-code auditor invoked the ripgrep binary directly, and the lead auditor's re-verification used `grep -rlw` for reference counts. Counts above are from those direct invocations, not from an alias.
