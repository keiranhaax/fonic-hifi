# Archived Planning Documents

**Archive Date**: 2025-10-02
**Reason**: Consolidated into `../all.md` (Version 2.0)

## Purpose

These files were consolidated to reduce clutter and create a single source of truth for the Fonic HiFi implementation plan. All information from these files has been preserved and integrated into the master plan.

## Archived Files & Their New Locations

### 1. `prd.md` (192 lines) → Product Requirements Document
**Consolidated Into**:
- **Executive Summary** in all.md (lines 29-69)
- **Appendix B: Product Requirements Detail** (lines 2532-2683)

**Key Content**:
- Vision pillars (Transparency, Privacy, Craft)
- Success metrics and targets
- User segments (Audiophiles 30%, Privacy-conscious 25%, Power users 20%, Collectors 25%)
- Functional requirements by phase
- Non-functional requirements (performance, quality, security)
- Release milestones with acceptance criteria
- Monetization strategy (Basic free, Pro $19.99, Audiophile $39.99)

---

### 2. `features.md` (555 lines) → Market Analysis & Competitive Research
**Consolidated Into**:
- **Appendix A: Market Analysis & Competitive Intelligence** (lines 2238-2529)

**Key Content**:
- Market overview ($6.8B by 2032, CAGR 8.5%)
- 11 competitor deep-dive analyses (VOX, Neutron, Onkyo HF, Flacbox, FiiO, etc.)
- Feature taxonomy: 🔹 Baseline (market standard), ⭐ Premium (differentiators), 🔥 Emerging (future-proof)
- 80+ features categorized by priority
- User pain points from Reddit/forums
- Success metrics benchmarks (technical, user, business KPIs)
- Pricing strategy analysis
- Fonic HiFi positioning and competitive advantages

---

### 3. `roadmap.md` (106 lines) → Phase Planning & Milestones
**Consolidated Into**:
- **Integrated throughout all.md** in Phase 0-3 sections
- Timeline and dependencies preserved

**Key Content**:
- Phase 0: Core Stability (gapless, bit-perfect UI)
- Phase 1: Format Parity (FLAC, EQ, crossfade, lyrics)
- Phase 2: Pro Tooling (Studio Mode, meters, smart playlists)
- Phase 3: Ecosystem (CarPlay, Watch, SharePlay)
- Risk matrix and mitigation strategies
- Metrics dashboard targets

---

### 4. `ai.md` (818 lines) → Apple Intelligence Integration Strategy
**Consolidated Into**:
- **Phase 4: Apple Intelligence Integration** (lines 1441-1791)

**Key Content**:
- Foundation Models framework overview (iOS 26, on-device LLM)
- 8 AI features detailed:
  1. Intelligent playlist generation
  2. Smart music search (conversational)
  3. Automated music organization
  4. Contextual recommendations
  5. Lyrics intelligence
  6. Music discovery engine
  7. Voice-powered control
  8. Audio production assistant
- Technical implementation (AIServiceManager, structured generation)
- Privacy guarantees (100% on-device, zero telemetry)
- Performance targets (<500ms response, <500MB memory)
- 6-phase rollout (50-70 hours total)
- Code examples (Swift with Foundation Models APIs)

---

### 5. `files-summary.md` (39 lines) → Legacy Knowledge Capture
**Consolidated Into**:
- **Appendix C: Legacy Knowledge & Critical Context** (lines 2686-2796)

**Key Content**:
- Stakeholder priorities (lossless focus, DAC integration, 100k+ track libraries)
- Critical code risks (SwiftData relationships, threading, CloudKit removal)
- Swift 6 concurrency safeguards (patterns and validation)
- Historical context (emergency recovery, Liquid Glass migration, P0 fixes)

---

## Active File

**`../all.md` - MASTER PLAN** (Version 2.0, ~2,800 lines)
- **Single source of truth** for all planning and implementation
- Comprehensive roadmap with Phases 0-4
- Progress tracker showing 24% completion (Foundation done, 33 features remaining)
- Complete market analysis and competitive intelligence
- Detailed requirements and acceptance criteria
- Legacy knowledge and critical context preserved

## Why Consolidate?

**Before**: 6 files, 3,610 lines total, duplicated information, navigation complexity
**After**: 1 active file + archive, single source of truth, complete information preserved

**Benefits**:
1. **Reduced clutter**: Active plan2/ directory has 1 master file instead of 6
2. **No information loss**: All content preserved in organized appendices
3. **Better navigation**: Single table of contents, consistent structure
4. **Easier updates**: One file to maintain instead of syncing across 6
5. **Clear status**: Progress tracker shows what's done vs. pending

## How to Use

**For implementation**: Refer to `../all.md` (master plan)
**For historical reference**: Use these archived files to understand original context
**For verification**: Compare archived files to consolidated sections if needed

## Verification

You can verify no information was lost by comparing these archived files to the corresponding sections in `../all.md`:

```bash
# Compare PRD content
diff -u prd.md <(sed -n '29,69p; 2532,2683p' ../all.md)

# Compare features analysis
diff -u features.md <(sed -n '2238,2529p' ../all.md)

# Compare AI strategy
diff -u ai.md <(sed -n '1441,1791p' ../all.md)

# Compare legacy knowledge
diff -u files-summary.md <(sed -n '2686,2796p' ../all.md)
```

---

**Last Updated**: 2025-10-02
**Consolidated By**: Claude Code (Sonnet 4.5)
**Archive Status**: Complete - All files preserved, all content integrated
