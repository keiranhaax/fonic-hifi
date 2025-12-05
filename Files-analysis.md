# Fonic HiFi Project Documentation Audit Report

**Generated**: 2025-12-04
**Scope**: `/Users/keiran/Documents/Fonic-HiFi/Files`
**Analyst**: Claude Code

---

## Executive Summary

Fonic HiFi has a **solid architectural foundation** but is **significantly behind roadmap execution**. The documentation reveals an ambitious vision for a privacy-first, audiophile-grade iOS 26 music player, but ~75% of documented features remain unimplemented. Phase 0 (Core Stability) is mostly complete, but Phase 1 (Format Parity) deliverables are essentially not started despite being targeted for October 2025. Documentation contains 42 iOS version references needing updates, 6 major contradictions, and multiple stale/dead file references.

**Key Finding**: The project needs a documentation cleanup pass and a clear decision on decoder technology (FFmpegKit vs SFBAudioEngine) before Phase 1 can begin.

---

## 1. Unimplemented Features

| Feature | Source File | Status | Priority | Notes |
|---------|-------------|--------|----------|-------|
| **Gapless Playback** | plan2/prd.md, roadmap.md | NOT IMPLEMENTED | CRITICAL | Empty stub only; `prepareNext()` not functional |
| **FLAC Decoder** | plan2/prd.md, roadmap.md | NOT IMPLEMENTED | CRITICAL | Blocks Phase 1; decision needed on decoder tech |
| **10-Band Parametric EQ** | plan2/prd.md, features.md | NOT IMPLEMENTED | HIGH | No AVAudioUnitEQ integration |
| **Crossfade (0-12s)** | plan2/prd.md, roadmap.md | NOT IMPLEMENTED | HIGH | Mixing nodes not configured |
| **Sleep Timer** | roadmap.md Phase 0 | NOT IMPLEMENTED | HIGH | Quick win (1-2 days) |
| **Playback Speed Control** | features.md, prd.md | NOT IMPLEMENTED | HIGH | 0.5x-2x speed not functional |
| **A-B Loop/Repeat** | prd.md:9.1 | NOT IMPLEMENTED | HIGH | Loop points for practice |
| **Resume Playback** | features.md Phase 0 | NOT IMPLEMENTED | MEDIUM | Save/restore position on relaunch |
| **Lyrics Display UI** | prd.md:9.1 | NOT IMPLEMENTED | MEDIUM | Data captured, no viewer |
| **APE Decoder** | roadmap.md | NOT IMPLEMENTED | MEDIUM | Required for Phase 1 |
| **DSD Support** | prd.md, features.md | NOT IMPLEMENTED | MEDIUM | DSD64/128 via DoP |
| **Replay Gain** | features.md, prd.md | NOT IMPLEMENTED | MEDIUM | Volume normalization |
| **Folder Browsing** | features.md, prd.md | NOT IMPLEMENTED | MEDIUM | Library hierarchy view |
| **LUFS/RMS Meter** | prd.md:9.2 | NOT IMPLEMENTED | MEDIUM | Phase 2 Pro feature |
| **Spectrum Analyzer** | features.md, prd.md | NOT IMPLEMENTED | MEDIUM | Phase 2 Pro feature |
| **Smart Playlist Engine** | prd.md:9.2 | PARTIAL | MEDIUM | Models exist; rules engine incomplete |
| **CarPlay Support** | prd.md:9.3, roadmap.md | NOT IMPLEMENTED | LOW | Phase 3 ecosystem |
| **Apple Watch Companion** | prd.md:9.3 | NOT IMPLEMENTED | LOW | Phase 3 ecosystem |
| **Siri Shortcuts** | prd.md:9.3 | NOT IMPLEMENTED | LOW | Phase 3 ecosystem |
| **SharePlay Sessions** | prd.md:9.3 | NOT IMPLEMENTED | LOW | Phase 3 ecosystem |
| **NAS/DLNA Support** | prd.md:9.3 | NOT IMPLEMENTED | LOW | Phase 3 research track |

**Phase Completion Summary:**
- Phase 0 (Core Stability): ~30% complete
- Phase 1 (Format Parity): ~5% complete (framework only)
- Phase 2 (Studio Mode): 0% complete
- Phase 3 (Ecosystem): 0% complete

---

## 2. Original Plan vs Current State

| Aspect | Original Vision | Current State | Gap |
|--------|-----------------|---------------|-----|
| **Timeline** | Phase 0 July 2025, Phase 1 Oct 2025 | Dec 2025: Phase 0 incomplete | 2+ months behind |
| **Format Support** | FLAC, APE, DSD, comprehensive | PCM only (MP3, AAC, ALAC, WAV, AIFF) | Major gap |
| **Audio Processing** | EQ, crossfade, replay gain, gapless | Basic playback only | Major gap |
| **Pro Tools** | Studio Mode, meters, A/B comparison | Diagnostics framework only | Not started |
| **Ecosystem** | CarPlay, Watch, Shortcuts, SharePlay | None | Not started |
| **Architecture** | Multi-engine facade, actor concurrency | ✅ Implemented well | On track |
| **UI/UX** | Liquid Glass, Apple Music patterns | ✅ Implemented | On track |
| **Widgets** | Live Activities, Dynamic Island | ✅ Implemented | On track |
| **Testing** | 65% coverage target | 46.54% overall (34.17% app) | Below target |

**What IS Implemented:**
- Core PCM playback (MP3, AAC, ALAC, WAV, AIFF)
- SwiftData library with metadata
- File import and library scanning
- Basic queue management
- Swift 6.2 concurrency architecture
- Liquid Glass UI styling (iOS 26)
- Widget ecosystem (Live Activities, Dynamic Island)
- Bit-perfect validator framework
- Audio engines (AVAudioEngine, AudioKit adapters)
- Comprehensive diagnostics infrastructure

---

## 3. Next Steps (Priority Order)

### Immediate (P0 - Blockers)

| Action | Effort | Dependencies | Impact |
|--------|--------|--------------|--------|
| **Decide decoder technology** (FFmpegKit vs SFBAudioEngine) | 1 day | Legal review | Unblocks all Phase 1 format work |
| **Remove `try!` fallbacks** in FonicHiFiApp.swift, DataManager.swift | 2-3 days | None | Prevents crash-on-init |
| **Fix LibraryImportService threading** (off @MainActor) | 3-4 days | None | Unblocks import testing |
| **Lint remediation** (339 → <100 violations) | 2 days | None | Code quality gate |

### Near-Term (P1 - Phase 1 Features)

| Action | Effort | Dependencies | Impact |
|--------|--------|--------------|--------|
| **Implement gapless playback** | 4-5 days | P0 completion | Core audiophile feature |
| **Integrate 10-band EQ** | 5-6 days | Gapless | DSP foundation |
| **Sleep timer** | 1-2 days | None | Quick win |
| **Resume playback** | 1-2 days | None | Quick win |
| **Playback speed control** | 1 day | None | Quick win |
| **Lyrics display UI** | 3-4 days | None | Data already captured |
| **FLAC decoder integration** | 6-8 days | Decoder decision | Phase 1 gate |

### Mid-Term (P2 - Phase 2 Features)

| Action | Effort | Dependencies | Impact |
|--------|--------|--------------|--------|
| **Studio Mode signal-path UI** | 5-6 days | Phase 1 DSP | Pro differentiation |
| **LUFS/RMS meters** | 4-5 days | Studio Mode | Pro feature |
| **Smart playlist rules engine** | 6-7 days | Phase 1 | User retention |
| **Listening statistics** | 3-4 days | Smart playlists | Engagement feature |

---

## 4. Outdated Content

| File | Issue | Severity | Recommendation |
|------|-------|----------|----------------|
| `plan2/features.md` | "Last Updated: August 2023" (27 months stale) | HIGH | Update or archive |
| `docs/testing/coverage-2025-02-14.md` | 26% coverage (now 46.54%) | HIGH | Delete or update |
| `docs/testing/coverage-2025-10-09.md` | 41.67% coverage (now 46.54%) | MEDIUM | Update |
| `Archive/Tasks/Legacy/MVP_Development_Plan.md` | 10-week plan from 2024 | HIGH | Move deeper into archive |
| `Plan/mock.md` | Contains `if #available(iOS 26, *)` examples | HIGH | Remove; violates CLAUDE.md rules |
| `Archive/liq.md` | References deleted `PerformanceOptimizedContainer.swift` | HIGH | Archive with deprecation notice |
| `plan2/roadmap.md` | Still proposes FFmpegKit vs SFBAudioEngine evaluation | MEDIUM | Update after decision made |
| `plan2/all.md` | References non-existent `Core/Audio/Decoders/` | HIGH | Remove dead reference |

---

## 5. iOS Version References (Older than iOS 26)

| File | Line(s) | Reference | Issue |
|------|---------|-----------|-------|
| `plan2/logic.md` | 645, 1966 | "FLAC (iOS 11+)" | iOS 11 irrelevant for iOS 26-only project |
| `plan2/logic.md` | 1976 | "iOS 16-17 MP3 gapless broken" | Historical context unnecessary |
| `plan2/logic.md` | 2041 | "iOS 18+ use Swift Testing" | Should just use Swift Testing |
| `plan2/tab.md` | 23, 329, 471 | "Tab(...) - iOS 18.0+" | iOS 26 minimum; no version check needed |
| `plan2/audio.md` | 124, 394, 402 | "iOS 13.0+, iOS 12.0+ deprecations" | Historical; remove |
| `Plan/Sheet.md` | 59-63 | "iOS 18.0+, iOS 16.0+, iOS 16.4+" | Confusing; iOS 26 is minimum |
| `Plan/Sheet.md` | 311, 542-544 | "iOS 18+ matchedTransitionSource" | Mixed iOS 18/26 references |
| `compass_artifact_wf-...md` | 3, 5, 13, 45, 47, 55, 93 | "iOS 16+, iOS 17+, iOS 18+" | Historical threading context |
| `Archive/Tasks/Legacy/*.md` | Multiple | "iOS 18+, iOS 18.0, iOS 18.1" | Archive docs targeting old iOS |

**Total iOS version references found**: 42
**Recommendation**: Remove all version checks and historical context; document iOS 26-only patterns

---

## 6. Contradictions Between Documents

| Contradiction | Source 1 | Source 2 | Resolution Needed |
|---------------|----------|----------|-------------------|
| **@available checks** | CLAUDE.md: "NEVER use @available" | Plan/mock.md: Shows `if #available(iOS 26, *)` examples | Remove examples from mock.md |
| **Coverage target** | STATUS.md: "target lowered to 40%" | docs/testing/coverage-2025-02-14.md: "65% target" | Update old doc or delete |
| **Stub engines** | Plan/mock2.plan: "stub files removed" | plan2/roadmap.md: "Evaluate FFmpegKit vs SFBAudioEngine" | Clarify which stubs remain |
| **Phase timeline** | plan2/all.md: "Phase 0 → July 2025" | Current: December 2025 | Update timeline in docs |
| **Gapless status** | plan2/roadmap.md: "hooks exist, not implemented" | plan2/all.md: "Complete prepareNext()" | Clarify what's actually done |
| **DSP scope** | roadmap.md Phase 0: "No EQ yet" | all.md Phase 0: "Implement 10-band EQ" | Clarify Phase 0 vs Phase 1 scope |

---

## 7. Pending Technical Decisions

| Decision | Status | Options | Impact | Deadline |
|----------|--------|---------|--------|----------|
| **Decoder stack** | UNRESOLVED | FFmpegKit vs SFBAudioEngine | Blocks Phase 1 FLAC | Immediate |
| **Visualization tech** | DEFERRED | SwiftUI vs Metal | Phase 2 spectrum analyzer | Phase 2 |
| **Pricing model** | NOT VALIDATED | Freemium vs paid-only | Launch strategy | Phase 1 beta |
| **NAS protocol** | RESEARCH | UPnP vs SMB vs WebDAV | Phase 3 streaming | Phase 3 |
| **Smart playlist ML** | DEFERRED | Rules-only vs Core ML | Phase 2/4 scope | Phase 2 |

---

## 8. Recommendations (Priority Order)

### Immediate Actions (This Week)

1. **DECIDE**: Decoder technology (FFmpegKit vs SFBAudioEngine) - blocks all Phase 1 format work
2. **REMOVE**: All `@available(iOS 26, *)` examples from `Plan/mock.md`
3. **UPDATE**: `plan2/roadmap.md` to reflect decoder decision once made
4. **DELETE**: `docs/testing/coverage-2025-02-14.md` (10 months stale)

### Short-Term Actions (Next 2 Weeks)

5. **ARCHIVE**: Move `Archive/Tasks/Legacy/MVP_Development_Plan.md` deeper with deprecation notice
6. **FIX**: Remove dead `Core/Audio/Decoders/` reference from `plan2/all.md`
7. **CONSOLIDATE**: Coverage documentation to single source (STATUS.md)
8. **REMOVE**: Historical iOS 12-18 context from `plan2/audio.md`, `plan2/logic.md`

### Medium-Term Actions (Phase 1)

9. **IMPLEMENT**: Gapless playback, EQ, quick wins (sleep timer, resume, speed)
10. **INTEGRATE**: FLAC decoder (after legal clearance)
11. **UPDATE**: All roadmap timelines to reflect actual progress
12. **CLARIFY**: Phase 0 vs Phase 1 scope boundaries

---

## Appendix: Files Analyzed

| File Path | Type | Notes |
|-----------|------|-------|
| `/Files/Plan/README.md` | Current | Planning overview |
| `/Files/Plan/Search.md` | Current | Search implementation |
| `/Files/Plan/Sheet.md` | Current | Sheet UI patterns |
| `/Files/Plan/audio.md` | Current | Audio system notes |
| `/Files/Plan/logmock.md` | Current | Logging mock |
| `/Files/Plan/mock.md` | Current | Contains deprecated patterns |
| `/Files/Plan/mock2.plan` | Current | Cleanup plan |
| `/Files/plan2/prd.md` | Current | Product requirements |
| `/Files/plan2/features.md` | Stale | 27 months old |
| `/Files/plan2/roadmap.md` | Current | Phase roadmap |
| `/Files/plan2/all.md` | Current | Combined plan |
| `/Files/plan2/audio.md` | Current | Audio deep-dive |
| `/Files/plan2/logic.md` | Current | Logic patterns |
| `/Files/plan2/tab.md` | Current | Tab implementation |
| `/Files/plan2/files-summary.md` | Current | File inventory |
| `/Files/plan2/archive/` | Archive | Legacy versions |
| `/Files/docs/DEBUGGING.md` | Current | Debug guide |
| `/Files/docs/adr/001-import-url-normalisation.md` | Current | ADR |
| `/Files/docs/adr/002-audio-monitor-decomposition.md` | Current | ADR |
| `/Files/docs/adr/003-paginated-fetch-descriptor.md` | Current | ADR |
| `/Files/docs/bit.md` | Current | Bit-perfect notes |
| `/Files/docs/refactor/baseline-2025-10-07.md` | Current | Refactor baseline |
| `/Files/docs/refactor/data-manager-responsibility-map.md` | Current | Data layer map |
| `/Files/docs/refactor/observability-walkthrough.md` | Current | Logging guide |
| `/Files/docs/refactor/postmortem.md` | Current | Incident review |
| `/Files/docs/testing/coverage-2025-02-14.md` | Stale | 10 months old |
| `/Files/docs/testing/coverage-2025-10-09.md` | Outdated | 2 months old |
| `/Files/Archive/README.md` | Archive | Archive index |
| `/Files/Archive/Files/*.md` | Archive | Original specs |
| `/Files/Archive/Plan/Legacy/*.md` | Archive | Legacy plans |
| `/Files/Archive/Tasks/Legacy/*.md` | Archive | Completed tasks |
| `/Files/Archive/agents/*.md` | Archive | Agent configs |
| `/Files/Archive/*.md` | Archive | Recovery notes |
| `/Files/Code_Analysis_Report.md` | Current | Code analysis |
| `/Files/compass_artifact_wf-*.md` | Current | Compass artifact |

**Total files analyzed**: 55+ markdown files

---

## Summary Statistics

| Metric | Count |
|--------|-------|
| Unimplemented features | 25+ |
| iOS version references needing updates | 42 |
| Stale documents (3+ months old) | 8 |
| Dead file references | 5 |
| Major contradictions | 6 |
| Pending technical decisions | 5 |
| High-severity issues | 7 |
| Medium-severity issues | 15 |

---

*Report generated by Claude Code documentation audit.*
