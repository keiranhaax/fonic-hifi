# Fonic HiFi Roadmap (Mid 2025)

## Vision Pillars
- **Audiophile Transparency**: verifiable bit-perfect playback, signal-path clarity, trustworthy diagnostics.
- **Privacy-First Local Experience**: zero cloud requirement, on-device intelligence, transparent data handling.
- **Modern SwiftUI Craft**: Liquid Glass design language, accessibility baked in, responsive interactions.

## Current Position Snapshot (December 2025 - Actual Implementation)
| Area | Status (Jun 2025) | Notes |
| --- | --- | --- |
| Core playback | ✅ Stable AVAudioEngine + AudioKit playback for PCM (MP3/AAC/ALAC/WAV/AIFF). | Gapless & crossfade hooks exist but are not implemented; progress timer + monitoring in place. |
| High-res formats | ⚠️ Architecture prepared but no live decoders for FLAC/APE/DSD. | `AudioFormatDetectionManager` lacks adapters; AudioKit adapter loads via `AVAudioFile` only. |
| DSP / EQ | ❌ No EQ, replay gain, bass boost, crossfeed, or room correction yet. | Requires new processing graph and UI. |
| Library & metadata | ✅ SwiftData models, import flow, search tabs. | Missing folder browsing UX, duplicate detection, batch tagging, lyrics UI. |
| Lyrics | ⚠️ Metadata stores lyrics strings, but no viewer/editor surfaced. | LRC parsing/downloading unbuilt. |
| Sleep timer / bookmarks | ❌ Not implemented. | Straightforward facade-level features. |
| AI / smart playlists | ⚠️ Smart playlist models exist but rules engine unfinished. | No ML/AI organisation yet. |
| Network / cloud | ❌ No Wi-Fi transfer, cloud drives, NAS. | Requires new entitlements/services. |
| CarPlay / Watch / SharePlay | ❌ No companion targets or entitlements. | Large effort, Phase 3+. |

## Phase Plan

### Phase 0 – Core Stability & Instrumentation *(now → July 2025)*
**Goals**: Ship a reliable local player, prove bit-perfect path, remove show-stopper gaps.
- Implement real gapless playback (finish `prepareNext`, buffer pre-roll) and regression tests.
- Stabilise progress timer, playback queue, and AudioSession handling.
- Hook BitPerfect validator results into UI diagnostics (status badge).
- Build `roadmap.md` quick-win items: resume playback, shake-to-shuffle toggle, default EQ presets placeholders, speed control design spike.
- Validate crash-free sessions (<0.2% crash rate) across PCM formats.

**Dependencies**: Monitoring pipeline already present; requires QA harness of local libraries. 
**Exit Criteria**: Continuous playback between tracks, accurate playback state, mini-player regression suite, crash-free soak test.

### Phase 1 – Format & Playback Parity *(August → October 2025)*
**Goals**: Meet audiophile baseline expectations from plan2/features.md.
- Integrate FLAC decoder via AudioKit or `SFBAudioEngine`; add adapter registration and format detection updates.
- Add DSD/APE support with staged rollout (start with FLAC, then DSD64/128 via DoP prototype, mark DSD as beta).
- Ship 10-band parametric EQ (`AVAudioUnitEQ` or AudioKit `Equalizer`), preset storage & UI integration.
- Implement crossfade engine (configurable 0–12 s) and optional replay gain (album/track modes).
- Add sleep timer, variable playback speed, and A/B looping controls in Now Playing.
- Deliver lyrics display (static + LRC) using existing metadata, with manual import.

**Dependencies**: Requires legal validation for bundled decoders, AudioKit updates, heavy testing on device. 
**Exit Criteria**: Public beta covering hi-res PCM + initial DSD, EQ UI in settings, crossfade smoke tests, QA sign-off on lyric sync.

### Phase 2 – Differentiators & Pro Tooling *(November 2025 → January 2026)*
**Goals**: Exceed competitors on transparency and professional tooling.
- Bit-perfect verification badge with live signal-path visualization and DAC telemetry (leveraging `BitPerfectValidator`, `DACCompatibilityInfo`).
- Pro meters suite: LUFS/RMS/Peak meter view, spectrum analyser, VU meters (AudioKit FFT, Metal visualization).
- A/B comparison & reference track management tied to queue.
- Local “Privacy Plus” intelligence: on-device smart playlists (rules engine + offline embeddings), listening statistics, year-in-review processing (no cloud).
- Batch metadata editor and duplicate detection workflow in Library.

**Dependencies**: Stable Phase 1 DSP graph; potential Metal shader work for visualization; design assets for pro views.
**Exit Criteria**: Studio Mode toggle with meters, analytics dashboards, positive internal beta feedback from audiophile testers.

### Phase 3 – Ecosystem & Connectivity *(February 2026 → April 2026)*
**Goals**: Round out integration story and targeted cloudless connectivity.
- CarPlay template app, Siri Shortcuts intents, SharePlay group sessions (audio sync + queue sharing).
- Apple Watch mini-player & complications; optional HomePod handoff.
- Wi-Fi transfer utility and optional local-network streaming (SMB/DLNA research track).
- Casting support (AirPlay 2 baseline; investigate Chromecast viability or defer).

**Dependencies**: Requires new entitlements, additional QA devices, background audio policies, network security review.
**Exit Criteria**: App Store submission-ready CarPlay/Watch builds, connectivity flows passing regression, privacy review maintained.

## Parallel Workstreams

### Quick-Win Backlog (tackle as capacity allows)
- Library badges (file counts/format counts).
- Swipe gestures & haptic polish for queue controls.
- Resume playback toggle, default DSP preset cards.
- Dynamic Island & Live Activity support (post Phase 1 once playback events stable).

### Technical Debt & Infrastructure
- Continuous integration: automate `make build`, `make test-unit`, SwiftLint/Format gates.
- Automated audio regression harness (sine sweep comparison, gapless detection metrics).
- Structured logging for playback/decoder events.

### Research Tracks
- Evaluate FFmpegKit vs. SFBAudioEngine for DSD (licensing, package size, performance).
- AI metadata organisation: Core ML embeddings vs. rules-based heuristics.
- Local network streaming protocols (UPnP/DLNA vs. SMB) and UX implications under privacy constraints.

## Risks & Mitigations
| Risk | Impact | Mitigation |
| --- | --- | --- |
| Hi-res decoder licensing or App Store policy issues | Blocks Phase 1 format goals | Engage legal early, modularise decoders for optional download, document compliance. |
| DSP performance on older devices | Audio glitches undermine audiophile cred | Provide performance modes, benchmark with profiling tools, expose fallback (disable heavy meters/EQ). |
| Visualization performance with Liquid Glass UI | Jank/thermal issues | Use Metal-based rendering with frame budget monitoring, expose settings to lower intensity. |
| Ecosystem feature creep (CarPlay/Watch) | Schedule overrun | Define MVP scope (basic playback controls first), gate advanced features behind stretch goal. |

## Metrics Dashboard Targets
- Crash-free sessions ≥ 99.8% by end of Phase 0.
- Hi-res playback bug rate < 3% of support tickets by Phase 1 exit.
- Daily active usage ≥ 35% of install base after Phase 2 pro tooling launch.
- App Store rating ≥ 4.6 after Phase 3 ecosystem release.

## Assumptions
- Team capacity ≈ 2–3 engineers + 1 designer + shared QA.
- Privacy posture remains “local-first”; any cloud capability must be opt-in and transparent.
- Timelines assume two-week sprints and no external blocker from Apple betas.

---
*Last updated: 2025-06-XX. Align this roadmap with quarterly planning; adjust dates following decoder feasibility and Apple platform release schedule.*
