# Fonic HiFi — Step-by-Step Fix Plan

Phased remediation, hardest-blocking first. Each step names the files, the change, what to preserve, and where the paste-ready code lives (domain reports 02-05). Do the phases in order; within a phase, steps are independent unless noted.

**Global rule:** make each phase its own branch + PR, build in Xcode 26 after each phase, and keep the existing architecture — this codebase is well-structured. Do not refactor beyond what a step asks. Nothing here has been applied to the repo yet.

---

## Phase 0 — Security emergency (do tonight, before anything else)

The repo went public tonight with live credentials in it. Treat the keys as compromised.

**0.1 — Rotate the four leaked credentials NOW (not after the code fix).**
- `.kilocode/mcp.json:45` — Brave Search API key
- `.kilocode/mcp.json:77` — Exa API key
- `.kilocode/mcp.json:92` — `Authorization: Bearer` token (apple-rag)
- `.claude/settings.local.json:83` — omnisearch `X-API-Key` (also leaks a private Tailscale IP `100.84.79.***`)
Revoke/regenerate each in its provider dashboard. Rotation is what actually protects you; scrubbing is secondary.

**0.2 — Remove the files from the working tree and stop tracking them.**
These are local agent-tool configs that should never have been committed:
```
git rm --cached .kilocode/mcp.json .claude/settings.local.json
```
Then add to `.gitignore`:
```
.kilocode/
.claude/settings.local.json
```

**0.3 — Purge them from git history** (they remain in every past commit until you do). Use `git filter-repo`:
```
git filter-repo --path .kilocode/mcp.json --path .claude/settings.local.json --invert-paths
git push --force origin main
```
Force-pushing rewrites history; fine for a solo repo. If any clone/fork exists, coordinate first.

**0.4 — Consider the repo private again** until Phases 0-1 are done, if that's an option.

Evidence & detail: `04-config-hygiene-audit.md` → "Live API credentials committed to version control."

---

## Phase 1 — App Store submission blockers (must fix to ship at all)

**1.1 — Add a privacy manifest.** Create `Fonic HiFi/PrivacyInfo.xcprivacy`. At minimum declare the `UserDefaults` required-reason API (used in 28 files) with reason `CA92.1`, plus `NSPrivacyTracking=false` and an empty collected-data-types array if you collect nothing. Add it to the app target (and a separate one to the widget if the widget touches `UserDefaults`/file timestamps). Paste-ready plist XML: `04-config-hygiene-audit.md` → "Privacy manifest missing."

**1.2 — Declare export compliance.** Add to `Fonic HiFi/Info.plist`:
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```
(Correct if the app uses only standard HTTPS/system crypto.) Detail: same report, "ITSAppUsesNonExemptEncryption not declared."

**1.3 — Verify the app icon builds.** `Fonic HiFi/Fonic.icon` (Icon Composer) exists and is valid, but the legacy `Assets.xcassets/AppIcon.appiconset` is empty and `ASSETCATALOG_COMPILER_APPICON_NAME = Fonic` is easy to misread. Open the project in Xcode 26, confirm the icon resolves in the target's App Icon slot and the archive shows an icon, then delete the empty `AppIcon.appiconset` to remove ambiguity. Detail: `04` → "App icon" (corrected finding) and `06-VERIFICATION-LOG.md`.

**1.4 — Register document types for imported audio.** For an offline player, users import files via Files/AirDrop/"Open in". `Info.plist` is missing `CFBundleDocumentTypes` / `UTImportedTypeDeclarations` for FLAC/ALAC/WAV/AIFF and `LSSupportsOpeningDocumentsInPlace` + `UIFileSharingEnabled`. Paste-ready plist: `04` → "File-import type registration missing."

---

## Phase 2 — Core audio correctness (the audiophile promise)

These four are why the app doesn't yet deliver bit-perfect, uninterrupted playback. All evidence + full Swift fixes in `02-backend-audio-audit.md`.

**2.1 — Pause on headphone/route disconnect.** `StateCoordinator.handleRouteChange` (`.../Coordinators/StateCoordinator.swift:191-205`) only logs `oldDeviceUnavailable`. Make that case call `pause()`. Preserve the existing logging and the other cases. Standard Apple behavior; also an App Review expectation.

**2.2 — Fix gapless on the lossless path.** Track changes go through `load()`→`stop()`, and `stop()` deactivates the session with `notifyOthersOnDeactivation` (`AudioSessionManager.swift:119`), causing an audible gap. Add a gapless/crossfade override to `AVAudioEngineAdapter` that pre-schedules the next buffer on the existing engine instead of tearing the session down, and stop deactivating the session between tracks in a queue. Fix in `02` → "Gapless/crossfade unimplemented on AVAudioEngine path."

**2.3 — Make the default configuration bit-perfect.** `AudioEngineFactory` selects AudioKit for `.balanced` (the default) and `.quality`, and the AudioKit chain always includes a `TimePitch` node + mixer that are never bypassed at unity — so the app's default output is not bit-perfect, contradicting the headline feature. Route native-supported formats to `AVAudioEngine` by default, and/or bypass the TimePitch/mixer nodes when no effect is active. Preserve AudioKit for formats that genuinely need it. Fix in `02` → "Default engine is AudioKit and is not bit-perfect."

**2.4 — Send FLAC down the native path.** `AVAudioEngineConfig.isFormatNativelySupported` returns `false` for `.flac` (`:156-165`). AVAudioEngine/AVAudioFile has decoded FLAC natively since iOS 11. Move `.flac` into the supported case so the flagship format gets the bit-perfect engine. Verify actual decode on a device with a real FLAC file (labeled UNVERIFIED in the report). Fix in `02` → "FLAC classified as not natively supported."

---

## Phase 3 — Flagship feature completeness

**3.1 — Wire up Smart Search playback (Critical).** `SearchView.playTrack` (`SearchView.swift:180-184`) is a logging placeholder — AI results can't be played. Inject the same playback path the Library uses and call it. Full fix: `03-frontend-uiux-audit.md` → "Smart-search results cannot be played."

**3.2 — Add the AI error UI state (Critical, same finding).** The search view model has an `.error(String)` state with no `View` branch, so on-device model failures render blank. Add an error view (message + Retry). Code sample in the same section.

**3.3 — Implement or remove `QueueCoordinator.removeFromQueue`.** It logs and returns without mutating the queue (`QueueCoordinator.swift:101-104`) but is reachable from UI. Either implement the removal in `AudioQueueManager` or hide the affordance. Fix: `05-dead-code-audit.md` → "Reachable-but-no-op stub."

---

## Phase 4 — UI/UX to professional Apple-native bar

All in `03-frontend-uiux-audit.md` with SwiftUI samples.

**4.1 — Stop the 0.5 s progress tick re-rendering the whole Now Playing screen** (`PlaybackController.swift:276-293` drives the 720-line `NowPlayingContent.body`). Isolate progress into a small observed subview / `TimelineView` so only the scrubber updates. High-value for perceived performance.
**4.2 — Fix the state-observation graph** that currently works "by accident" (mixed `ObservableObject`/`@Observable` read only through `@Environment`; `AudioEngineFacade.swift:22-45`). Make progress observable properly. Preserve the facade API.
**4.3 — Make the EQ accessible.** Custom `VerticalSlider` (`EqualizerView.swift:169-222`) has zero VoiceOver support and a 30 pt hit target. Add `accessibilityValue`/`accessibilityAdjustableAction` and grow the target to 44 pt.
**4.4 — Add context menus + swipe actions** (Play Next / Add to Queue / Add to Playlist) — currently zero in the codebase; a baseline expectation for a music app.
**4.5 — Fix Liquid Glass misuse** to match the project's own `.claude/reference/ios26-liquid-glass.md`: replace fake `.ultraThinMaterial` "glass," wrap glass pills in a `GlassEffectContainer`, and remove glass-on-glass in the rails. Also wire in the 458-line accessibility layer that's built but unused (and respect Reduce Transparency in the *used* `glassSurface()`).
**4.6 — Dynamic Type:** replace fixed `.font(.system(size:))` (37 sites) with text styles / `@ScaledMetric`.
**4.7 — Empty-state import CTA:** empty library/home should offer a tappable Import action (critical for an offline player's first run).

---

## Phase 5 — Dead code & repo hygiene (shrinks the binary, de-risks maintenance)

Because the project uses synchronized folder groups (objectVersion 90), every file on disk compiles — deleting dead code is a real win. Delete each, then do a green Xcode build as the safety check. Full list + evidence: `05-dead-code-audit.md`.
- Remove the dead Liquid Glass nav family (`LiquidGlassTabBar.swift`, `LiquidGlassRail.swift`, ~480 L — app uses native `TabView`).
- Remove superseded library list views (`AlbumGridView.swift`; the dead primary views in `ArtistListView.swift`/`TrackListView.swift`, keeping the `*DetailView` types).
- Remove the 490-line abandoned `ImportSession.swift` cluster (keep `ImportError`); real path is `LibraryImportService`.
- Decide on the five test-only services (`AudioSettingsService`, `SearchCache`, `TrackCache`, `PlaybackStateStore`, `LibraryFilter`): delete, or actually adopt them.
- Repo hygiene: delete `log.md`, `build_errors.log`, `build_verify.log`, `summary.md`, `Files-analysis.md`, `CLAUDE copy.md`, `project.pbxproj.backup`, the `docs/plans/...copy.md`; relocate `Files/` (102 planning docs) and `sample/` (5 sample Xcode apps) out of the app repo; untrack `xcuserdata`.
- **Fix `.gitignore`:** repair the corrupted last line (`.apdiskbuild_verify.log`) so `build_verify.log` is actually ignored, and remove the `*.xcodeproj` line (the project must stay tracked). Sample in `04`/`05`.

---

## Phase 6 — CI & tooling

**6.1 — Fix CI (`.github/workflows/ci.yml:17`):** it selects Xcode 16.1 on macos-15, which cannot build this iOS 26 / objectVersion-90 project — every run fails. Move to a `macos-26` runner + Xcode 26 (or the current image that ships it). Sample in `04`.
**6.2 — Unify the triplicated Widget/Shared models** (`WidgetConstants`/`WidgetPlaybackState`/`WidgetTrackInfo` are byte-identical in two places) into one file shared by both targets' membership, to stop drift. Low priority.
**6.3 — Correct the `project-config.md` house reference,** which is boilerplate copied from an unrelated HealthKit app ("Halie Heart") and misleads future contributors/agents.

---

## Suggested branch/PR sequence

1. `security/rotate-and-scrub-secrets` (Phase 0) — merge immediately.
2. `release/app-store-blockers` (Phase 1).
3. `audio/core-correctness` (Phase 2) — highest product value; test on device with real FLAC + headphones.
4. `feature/smart-search-playback` (Phase 3).
5. `ui/native-polish` (Phase 4) — can split per sub-step.
6. `chore/dead-code-and-hygiene` (Phase 5).
7. `ci/xcode-26` (Phase 6).

Phases 0-3 are the true release gate. 4-6 raise it from "shippable" to "the flawless experience your audiophile users expect."
