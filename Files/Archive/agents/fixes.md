# Fonic HiFi – Supplemental Product Requirements (Files Synthesis)
*Version: Draft – June 2025*

## 1. Document Meta
- **Purpose**: Translate insights from `/Files` artifacts into actionable product and engineering requirements.
- **Sources**: `Files/text.txt`, `Files/Code_Analysis_Report.md`, `Files/compass_artifact_wf-6370d5fc-cf08-4b73-8c4f-7675edb1e462_text_markdown.md` (threading brief), legacy references excluded per archive notice.
- **Audience**: Product, engineering, and QA leads refining Phase 0/Phase 1 execution.

## 2. Executive Summary
Recent stakeholder notes reinforce that Fonic HiFi must centre its MVP around lossless playback excellence (FLAC/ALAC), dependable gapless performance, and high-speed library browsing for collections exceeding 100k tracks. Smart playlists with a basic rules engine, dual offline/online UX, and visible DAC detection are mandatory in the first commercial release—not deferred differentiators. Concurrently, the code analysis report exposes blocking architectural defects (SwiftData relationships, threading, transactional integrity) that must be resolved before layering new functionality. This supplement reprioritises immediate work, codifies MVP acceptance criteria, and adds non-functional mandates around concurrency, performance profiles, and hardware transparency.

## 3. Current Technical Status (from Code Analysis)
- **SwiftData relationships broken**: Album/Artist lack `@Relationship` definitions, preventing fundamental queries.
- **Library view scaling risk**: Current client-side filtering will stutter at the targeted 100k+ track libraries.
- **Import integrity gap**: Files may orphan on failed imports due to missing transaction rollback.
- **AudioKit threading hazards**: Callbacks update UI/state off-main-thread; metrics reporting missing.
- **Access control inconsistencies**: Audio engine facade exposes internals beyond necessity.
These issues are prerequisites for the MVP roadmap and must be resolved during Phase 0 stabilization.

## 4. MVP Priorities (Stakeholder Alignment)
1. **Lossless playback focus**: FLAC & ALAC optimization, ensuring up to 24-bit/192kHz output and bit-perfect validation where hardware permits.
2. **Gapless + waveform polish**: Production-ready seamless transitions plus smooth, real-time waveform rendering in Now Playing.
3. **High-performance library browsing**: Instant search/filter behaviour for massive libraries with lazy loading and memory efficiency.
4. **Smart playlists (baseline rules)**: Rule builder capable of simple criteria (e.g., sample rate, genre, play count) available at launch.
5. **Dual-mode UX**: Clear separation of Offline Library vs. Online Mode with download manager, source indicators, and context-aware controls.
6. **Hardware transparency**: Automatic USB DAC detection with UI confirmation, reflecting active bit depth/sample rate.
7. **Performance profiles**: Balanced, Maximum Quality, and Battery Saver modes influencing DSP, waveform detail, and rendering intensity.

## 5. Functional Requirements
### 5.1 Library & Data
- Restore `Album`/`Artist` ↔ `Track` relationships; ensure predicate-based queries for per-tab data retrieval.
- Indexing pipeline must scale to 2TB/100k tracks with lazy metadata hydration and duplicate detection hooks for future editing features.
- Smart playlist engine delivers minimum viable rules: format type, bitrate, play count, last played, manual tags.

### 5.2 Playback & DSP
- Gapless playback implemented via `prepareNext()` buffering and double-buffer management; regression suite built per Code Analysis action items.
- Bit-perfect validator results surfaced inline, including hardware capabilities and fallback messaging when performance modes alter signal path.
- Performance profiles configurable in Settings with documented effect on waveform density, visualization frequency, and DSP node usage.

### 5.3 Hardware Integration
- USB DAC auto-detection triggers UI toast/badge; Now Playing displays active output, bit depth, and sample rate.
- Route-change handling guarantees resilient playback and updates state via `@MainActor` contexts.

### 5.4 Dual-Mode UX
- Offline mode hides network-dependent actions; online mode (future cloud sync) signals connectivity state and storage impact.
- Download manager tracks transfers, quota, and failure recovery paths.

## 6. Non-Functional & Concurrency Requirements
- Apply `@MainActor` to all UI-facing view models; audio callbacks must hand off to main actor (`Task { @MainActor in … }`) per concurrency brief.
- Combine publishers delivering into UI state must use `.receive(on: RunLoop.main)` or `MainActor.run` wrappers to avoid dispatch assertions.
- Implement dispatch preconditions and logging for queue verification in AudioKit adapters.
- Transactional file import: metadata commit precedes file copy; failure rollback deletes partial artifacts.
- Ensure telemetry-free operation; logs and metrics remain local unless user exports manually.

## 7. Phasing Adjustments
- **Phase 0 (Stability Sprint)**: Fix SwiftData relationships, import transactions, AudioKit threading/metrics, and library query strategy before feature work. Establish gapless regression tests and performance profile scaffolding.
- **Phase 1 (MVP Feature Set)**: Deliver FLAC/ALAC optimisation, smart playlists (baseline), dual-mode UX shell, DAC detection, and performance profiles. Gapless + waveform polish completes here.
- **Phase 2 (Enhancements)**: Extend to advanced DSP, metadata editors, and online enrichment once MVP metrics confirmed.

## 8. Metrics & Validation
- **Technical**: Gapless transition variance ≤ 2 ms; import failure leaves zero orphaned files (audited weekly); dispatch assertion rate = 0 across soak tests.
- **Performance**: Library search results under 150 ms for 100k-track dataset; Balanced mode battery cost ≤ 5%/hr, Max Quality ≤ 8%/hr.
- **User Feedback**: DAC detection accuracy validated across top iOS-compatible devices (iFi, Chord Mojo, AudioQuest DragonFly).

## 9. Risks & Mitigations
| Risk | Description | Mitigation |
| --- | --- | --- |
| Concurrency regressions | Swift 6 main-actor enforcement causing crashes | Enforce actor annotations, add threading regression tests, monitor `_dispatch_assert_queue_fail` breakpoints. |
| Library scaling failure | Predicate refactor incomplete, causing UI stalls | Block Phase 1 release until predicate queries verified with large fixture dataset. |
| Smart playlist slip | Rules engine underestimated | Scope MVP to deterministic rules (no ML), reuse existing metadata indexes to avoid new persistence work. |
| DAC compatibility variance | Hardware handshake differences across vendors | Maintain device matrix, expose manual override, gather beta feedback before public launch. |

## 10. Open Decisions
- Finalize smart playlist rule set for MVP vs. follow-up (stakeholder review pending).
- Confirm performance profile defaults (Balanced vs. Maximum Quality) and UI messaging.
- Determine telemetry/log export mechanism that respects privacy posture while enabling debugging.

---
*Prepared from `/Files` materials to complement the main PRD; update after Phase 0 remediation outcomes and stakeholder review of smart playlist scope.*

## Appendix: UI/API Verification Notes
*Updated: June 2025*

### A1. Purpose
Summarize verified UI/API issues in response to the recent "modernization" critique. Focus is on identifying genuinely broken surfaces, actual gaps, and incorrect API usage versus false positives.

### A2. Snapshot
- Target platform already set to iOS 26; no backward-compatibility shims are shipping.
- Liquid Glass surfaces intentionally mix native modifiers with bespoke utilities for controllable styling.
- Observation macro adoption is in progress: state-heavy singletons stay on `ObservableObject` for lifecycle guarantees, while hot-path UI state has moved to `@Observable`.

### A3. Claim Review
| Area | External Claim | Repository Reality | Status |
| --- | --- | --- | --- |
| Liquid Glass | "Only custom `.liquidGlass()`; native `.glassEffect()` unused" | `.glassEffect()` applied in production views such as `LiquidGlassRail` and Now Playing components alongside a clearly documented custom wrapper (`LiquidGlassDesignSystem.swift:29`). | **False** |
| Glass Container | "Missing `GlassEffectContainer`; custom `PerformanceOptimizedContainer` incorrect" | Replacement is deliberate for frame-rate control and matched-geometry coordination (`PerformanceOptimizedContainer.swift`). No broken behavior observed. | **Intentional design** |
| State Management | "App is stuck on `@StateObject`/`ObservableObject`; must migrate to `@Observable` everywhere" | Core UI-facing models already use `@Observable` (`PlaybackStateManager.swift`, `AudioQueueManager.swift`). App-wide singletons stay `ObservableObject` to preserve Combine publishers and `@StateObject` ownership (`FonicHiFiApp.swift`). | **False/Not an issue** |
| Spatial Audio | "Missing `intendedSpatialAudioExperience`" | API documented for visionOS 26; unsupported on the iOS 26 simulator target. Absence is expected. | **Not applicable** |
| MusicKit / ShazamKit / PHASE / SensoryFeedback | "Must be present for modern audio app" | Optional frameworks. App focuses on local lossless playback; no requirement or regression triggered by their absence. | **Out of scope** |
| `@available(iOS 26, *)` clean-up | "Checks still present" | No annotations remain in source tree. | **Resolved** |

### A4. Verified Issues and Gaps
No blocking API misuse identified. The following are the only actionable observations from this pass:
- **Documentation debt**: ensure the rationale for the custom Liquid Glass stack is surfaced in README/architecture notes to avoid future confusion.
- **Coverage opportunity**: add UI tests covering native `.glassEffect()` morphing to guard against regressions when refactoring the wrapper.

### A5. Recommendations
1. Communicate the validated status to stakeholders to prevent unnecessary rewrites of the Liquid Glass system.
2. Schedule lightweight tests/documentation tasks noted above if the team agrees they add value.

---
*Prepared after reviewing SwiftUI Liquid Glass and Observation docs via Apple RAG / Sosumi and cross-checking the current codebase.*
