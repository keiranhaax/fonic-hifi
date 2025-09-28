# Fonic HiFi – Product Requirements Document (PRD)
*Version: Draft – June 2025*

## 1. Document Meta
- **Product Owner**: Keiran (Founder / Lead Engineer)
- **Prepared By**: Codex agent (based on README.md, plan2/features.md, plan2/roadmap.md)
- **Revision History**:
  - 2025-06-XX: Initial draft
- **Related Docs**: plan2/features.md (market & feature research), plan2/roadmap.md (execution plan), README.md (current architecture overview)

## 2. Executive Summary
Fonic HiFi is an iOS 26+ premium music player focused on privacy, audiophile-grade playback, and a modern SwiftUI experience. The current build provides reliable PCM playback, a SwiftData-backed library, and Liquid Glass UI styling, but lacks several features that the 2025 market considers baseline (gapless playback, crossfade, format breadth). This PRD defines the product vision, user needs, MVP scope, phased roadmap, KPIs, and risks needed to evolve Fonic HiFi from a promising prototype into a competitive, privacy-first audiophile player.

## 3. Problem Statement
Audiophiles and privacy-conscious listeners on iOS lack a modern player that:
1. Guarantees bit-perfect playback for both standard and high-resolution formats without cloud dependencies.
2. Provides professional-grade analysis tools (meters, signal-path insights) while staying approachable.
3. Respects user privacy (no analytics, no forced accounts) yet still offers smart organisation and ecosystem integrations.
Currently, existing apps either compromise on privacy (cloud sync), usability (dated interfaces), or format transparency. Fonic HiFi aims to close this gap.

## 4. Product Vision & Goals
- **Audiophile Transparency**: Real-time verification of signal integrity, clear disclosure of processing stages, and support for hi-res/DSD formats.
- **Privacy-First Local Experience**: All features operate on-device by default; any network capability remains optional, transparent, and user-controlled.
- **Modern SwiftUI Craft**: Deliver an elegant Liquid Glass interface with accessibility and performance across iPhone 16 Pro and newer devices.
- **Extensible Platform**: Architecture must scale to pro features (Studio Mode), AI-assisted organisation, and ecosystem integrations without major rewrites.

### Success Metrics (Targets)
- Crash-free sessions ≥ 99.8% after Phase 0 deployment.
- Bit-perfect verification accuracy ≥ 95% (measured against hardware probes) by Phase 1 completion.
- 30-day retention ≥ 60% for early adopters by end of Phase 2.
- App Store rating ≥ 4.6 with ≥ 1k reviews by end of Phase 4.

## 5. Target Users & Segments
Sourced from plan2/features.md and roadmap insights.

| Segment | Share | Needs | Monetisation | Notes |
| --- | --- | --- | --- | --- |
| **Audiophiles** | ~30% | Bit-perfect playback, DSD/hi-res support, format transparency | Will pay $30–$50 | Require hardware integration clarity, professional tooling.
| **Privacy-Conscious listeners** | ~25% | Offline/local processing, no telemetry, encrypted backups | Will pay premium for privacy | Expect transparent data policies, optional network features.
| **Power Users** | ~20% | Advanced queueing, automation (Shortcuts), customisation | Invest in productivity | Need smart playlists, statistics, remote integrations.
| **Music Collectors** | ~25% | Metadata management, folder browsing, duplicate handling | Pay for organisation tools | Expect robust tagging, batch editing, file operations.

## 6. Market Landscape & Benchmarking
(From plan2/features.md research)
- **Competitors**: VOX, Flacbox, Neutron, Onkyo HF, HiByMusic, FiiO Music, Offline Music Player, etc.
- **Baseline Expectations (🔹)**: FLAC/ALAC/WAV/AIFF support, gapless playback, crossfade, EQ presets, lyrics display, folder browsing, sleep timer, replay gain, lock screen controls, social sharing.
- **Premium Differentiators (⭐)**: DSD/MQA support, room correction, crossfeed, smart playlists, spectrum/vu meters, collaborative lists.
- **Emerging Capabilities (🔥)**: AI-based organisation and recommendations, AutoMix transitions, AI-generated visualisations, Year-in-review insights.
- **Pricing Trend**: One-time purchases between $7.99–$39.99 or subscriptions ($4.99–$19.99/mo). Fonic HiFi aims for a one-time model (Basic free, Pro $19.99, Audiophile $39.99) per roadmap.

## 7. Product Narrative
Fonic HiFi delivers a transparent, privacy-first audio experience. At launch, it focuses on impeccable playback of personal libraries, providing assurance via bit-perfect validation and a modern Liquid Glass UI. Subsequent releases expand into professional tools (Studio Mode) and ecosystem integrations, culminating in a comprehensive but approachable audiophile suite that avoids subscription fatigue.

## 8. Scope & Phasing Overview
Aligned with plan2/roadmap.md.

| Phase | Timeline | Theme | Key Deliverables |
| --- | --- | --- | --- |
| **Phase 0 – Core Stability & Instrumentation** | now → July 2025 | Stabilise existing PCM playback | True gapless playback, progress/queue reliability, bit-perfect badge surfacing, quick-win UX tweaks. |
| **Phase 1 – Format & Playback Parity** | Aug → Oct 2025 | Meet baseline audiophile expectations | FLAC/APE/DSD decoders, parametric EQ, crossfade, replay gain, sleep timer, playback speed, lyrics UI. |
| **Phase 2 – Differentiators & Pro Tooling** | Nov 2025 → Jan 2026 | Professional transparency | Signal-path visualisation, LUFS/RMS meters, spectrum/vu, A/B comparison, smart playlists/statistics, batch metadata tools. |
| **Phase 3 – Ecosystem & Connectivity** | Feb → Apr 2026 | Platform integrations | CarPlay, Siri Shortcuts, SharePlay, Apple Watch, Wi-Fi transfer, NAS/DLNA (research-driven). |
| **Phase 4 – Stretch (Post-Apr 2026)** | TBD | Advanced AI & community | AI visualisations, collaborative playlists, optional cloud sync (privacy preserving). |

## 9. Functional Requirements
### 9.1 MVP (Phase 0 & Phase 1 combined)
1. **Audio Playback**
   - Support MP3/AAC/ALAC/WAV/AIFF with seamless gapless transitions.
   - Introduce FLAC playback via integrated decoder (AudioKit or SFBAudioEngine).
   - Provide configurable crossfade (0–12s) and optional replay gain (track & album modes).
2. **DSP & Controls**
   - Implement 10-band parametric EQ with presets and user-defined settings.
   - Add sleep timer with fade-out and variable playback speed (0.5x–2x) with pitch control toggle.
   - Support A-B loop points for practice/analysis use cases.
3. **Lyrics & Metadata**
   - Display embedded/static lyrics and LRC sync; allow manual import/edit.
   - Enhance Library with folder browsing, duplicate detection, and search filters (genre/year/bitrate).
4. **Bit-Perfect Transparency**
   - Surface validator results with clear messaging (e.g., “Bit-perfect” vs. “Processing active” with reasons).
5. **UI Enhancements**
   - Ensure Now Playing, mini player, and effect UIs align with Liquid Glass guidelines.
   - Provide quick gestures for queue management (swipe to add/remove). 

### 9.2 Phase 2 Requirements
- Studio Mode toggles to expose pro meters, signal-path lineage, reference track management, waveform/spectrum visualisation.
- Listening statistics dashboard (play counts, hi-res ratio, time-of-day usage).
- Smart playlist engine supporting rule-builder (e.g., Sample rate ≥ 96kHz, Genre contains “Jazz”).
- Batch metadata editor (tags, artwork, lyrics) with undo support.

### 9.3 Phase 3 Requirements
- CarPlay target with essential playback/queue controls.
- Siri Shortcuts for play album/playlist, toggle EQ preset, start sleep timer.
- SharePlay session for synchronous listening with queue synchronisation.
- Apple Watch companion for remote control + complications.
- Wi-Fi transfer utility for device-to-device imports; optional NAS/DLNA stream (feature gated as beta).

### 9.4 Non-Goals (2025)
- Streaming licensed content (e.g., Spotify/Tidal integration).
- Cloud-based analytics or telemetry.
- Desktop (macOS) client (defer consideration until iOS client stabilises).

## 10. User Experience & Design Requirements
- Maintain Liquid Glass design language with accessible motion options (respect `reduceMotion`, `Dynamic Type`).
- Provide dark-mode-first visuals optimised for OLED (per README).
- Ensure pro tooling surfaces without overwhelming casual users (Studio Mode toggled off by default).
- Provide contextual education for audiophile features (tooltips, “Why bit-perfect?”)
- Support one-handed operations on iPhone 16 Pro (key controls reachable within thumb arc).
- Add offline-first messaging when network features are disabled.

## 11. Technical Requirements
- Conform to Swift 6.2 concurrency (MainActor for UI, actors for data/persistence) as documented in README.
- Continue using AudioEngineFacade with engine factory; add decoder adapters via `AudioFormatDetectionManager.registerAdapter`.
- Implement DSP chain with `AVAudioUnitEQ`/AudioKit nodes while maintaining bit-perfect modes (ability to disable DSP per track).
- Ensure new network features respect sandboxing and App Store entitlements (CarPlay, Background audio, Local network).
- Expand automated tests via `make test-unit`; create audio regression harness (sine sweeps, gapless detection) as part of CI.
- Maintain privacy posture: no additional analytics frameworks; store only necessary data in SwiftData (encrypted when feasible).

## 12. Release Milestones & Deliverables
Refer to roadmap but clarify acceptance criteria for each milestone.

### Milestone A – Core Stability Release (Phase 0)
- Gapless playback validated with test suite (live album test cases).
- Bit-perfect status indicator in Now Playing.
- Sleep timer & resume playback toggles implemented.
- QA sign-off on crash-free soak test (≥ 8-hour playlist).

### Milestone B – Audiophile Baseline Release (Phase 1)
- FLAC playback (16/24-bit) verified on device & external DAC.
- EQ UI available with at least 8 presets + custom saving.
- Lyrics view (scrolling + timed) functional.
- Crossfade & replay gain settings accessible in Settings.

### Milestone C – Studio Mode Release (Phase 2)
- Signal path visualisation with processing stage list.
- LUFS/RMS meter accuracy validated against reference plugin (±1 dB).
- Smart playlists available with rule builder and auto-update toggle.
- Batch metadata editor handles 100+ tracks without crash.

### Milestone D – Ecosystem Release (Phase 3)
- CarPlay template passes Apple review guidelines.
- Siri Shortcut set published (play album, toggle EQ preset, start sleep timer).
- SharePlay session tested with 3 participants; queue stays in sync within ±500 ms.
- Apple Watch companion app available with complications.

## 13. Metrics & Analytics (Privacy-Respecting)
While avoiding analytics SDKs, collect anonymised, on-device metrics with opt-in export:
- Playback hours per format (PCM vs hi-res vs DSD) – stored locally.
- Feature adoption toggles (EQ usage, sleep timer) – used to prioritise UI improvements.
- Error logs (decoder failures) – surfaced to user for optional feedback submission.

## 14. Risks & Mitigations
| Risk | Impact | Likelihood | Mitigation |
| --- | --- | --- | --- |
| Decoder licensing / App Store policy conflicts | Blocks hi-res roadmap | Medium | Engage legal early, keep decoders modular (optional download), maintain documentation of open-source usage. |
| DSP performance drains battery or glitches | Damages audiophile trust | Medium | Provide performance modes (efficiency/quality), profile with Instruments, allow disabling heavy visualisations. |
| Visualization with Liquid Glass causes jank | Poor UX | Medium | Prototype with Metal, throttle frame rate, include low-performance mode. |
| Ecosystem scope creep (CarPlay, SharePlay, Watch) | Schedule slips | High | Limit MVP functionality (play/pause/next), iterate post-initial release, apply strict acceptance criteria per milestone. |
| Optional network features compromise privacy stance | Brand trust loss | Low | Keep network features opt-in, no third-party analytics, document behavior transparently. |

## 15. Dependencies & Open Decisions
- **Decoder Stack**: Choose between FFmpegKit (broader format support, larger binary) vs. SFBAudioEngine (lighter, Apple-friendly). Decision deadline: before Phase 1 kickoff.
- **Visualization Tech**: Determine SwiftUI vs. Metal for waveform/spectrum to balance performance and maintainability.
- **Smart Playlist Intelligence**: Select approach (rules engine first, Core ML embeddings later) to deliver Phase 2 features.
- **NAS/DLNA Protocol**: Research UPnP vs. SMB vs. WebDAV for network streaming; align with privacy policy.
- **Pricing/Monetization**: Validate Basic/Pro/Audiophile pricing tiers through user research before public launch.

## 16. Non-Functional Requirements
- App size target < 200 MB even after decoder integrations (optional downloads acceptable).
- Battery impact < 5%/hr with EQ + visualisers off; < 8%/hr with pro tooling active.
- Accessibility compliance: VoiceOver labels for controls, Dynamic Type support, haptic feedback for key actions.
- Localization ready: UI strings stored in localisation files; initial release English-only with plan for top 3 languages.

## 17. Testing & QA Strategy
- **Unit Tests**: Expand coverage on AudioEngineFacade, metadata services, EQ presets.
- **Integration Tests**: Use `make test-unit` to cover import → playback flow with sample library.
- **Audio Regression Harness**: Automated tests for gapless transitions, crossfade volume ramps, replay gain accuracy.
- **Manual QA**: Test hi-res playback with popular DACs, CarPlay sessions, SharePlay scenarios in simulator and on-device.
- **Beta Program**: Private TestFlight for audiophile community feedback prior to Phase 2.

## 18. Launch & Rollout Plan
- **Phase 0**: Soft launch to small beta (invite-only) for stability validation.
- **Phase 1**: Public App Store launch targeted to early adopters, accompanied by transparent blog post explaining privacy stance.
- **Phase 2**: Marketing push to audiophile/producer communities, highlight Studio Mode differentiators.
- **Phase 3**: Partnerships with accessory makers (DAC vendors) for co-marketing; highlight ecosystem integrations.

## 19. Appendices
- **A. Market Feature Legend**: See legend in plan2/features.md clarifying emoji usage (🔹 baseline, ⭐ premium, 🔥 emerging, ✅ implemented).
- **B. Architecture Summary**: README.md outlines Swift 6.2 concurrency, AudioEngineFacade orchestrating AVAudioEngine/AudioKit adapters.
- **C. Roadmap Reference**: plan2/roadmap.md provides original timelines, quick-win backlog, research tracks, and risk table used here.

---
*This PRD aggregates current knowledge from README.md, plan2/features.md, and plan2/roadmap.md. It should be reviewed and updated after decoder feasibility spikes and pricing validation.*
