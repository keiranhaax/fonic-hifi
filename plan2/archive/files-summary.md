# Files Directory Synthesis (June 2025)

Purpose: capture all current, non-legacy guidance contained in `/Files` so the original folder can be archived without losing relevant knowledge. Legacy materials under `/Files/Archive/**` are intentionally excluded.

## 1. Stakeholder Priorities (`Files/text.txt`)
- **Lossless focus**: MVP must optimise FLAC and ALAC playback; MP3/M4A/OGG already stable.
- **Format roadmap**: DSD (up to DSD256), APE, WAV/AIFF planned for Phase 2; target 24-bit/192kHz with bit-perfect integrity when hardware allows.
- **Hardware integration**: Detect USB DACs (iFi, Chord Mojo, AudioQuest DragonFly) with UI confirmation and accurate bit depth/sample rate switching.
- **Performance modes**: Provide Balanced (default), Maximum Quality, and Battery Saver profiles; waveform detail scales by context (simplified in Library, real-time in Now Playing).
- **Metadata handling**: Prioritise embedded tags; later phases may use MusicBrainz/Discogs. Manual editing is important but can trail MVP as v1.1.
- **Library scale**: Optimise for 100k+ tracks / 2TB libraries via lazy loading and efficient indexing.
- **MVP feature triad**: (1) Robust playback engine with gapless + waveform polish, (2) fast library browsing, (3) smart playlists with basic rules.
- **Dual-mode UX**: Distinguish offline library vs. online sources, include download manager, source indicators, and adaptive UI states.

## 2. Codebase Risks & Required Fixes (`Files/Code_Analysis_Report.md`)
- **SwiftData relationships missing** (`Album`/`Artist` ↔ `Track`) → core queries fail; must add `@Relationship` macros and computed property logic.
- **Library view performance**: Avoid fetch-all + client filtering; move to predicate-based queries in a view model to keep UI responsive as library grows.
- **Import transactional integrity**: Process metadata and persist before copying files; add rollback to prevent orphaned media on failure.
- **AudioKit threading**: Dispatch callbacks to the main actor (`Task { @MainActor … }`) to avoid race conditions; implement metrics capture.
- **CloudKit entitlement**: Remove unused iCloud entitlement to align with privacy stance.
- **Metrics gap & access control**: Fill `AudioKitEngineAdapter.getMetrics()` and tighten `AudioEngineFacade` access modifiers.

## 3. Concurrency Guidance (`Files/compass_artifact_wf-6370d5fc-cf08-4b73-8c4f-7675edb1e462_text_markdown.md`)
- Swift 6 enforces `@MainActor` for SwiftUI views; synchronous calls from background queues will crash (`_dispatch_assert_queue_fail`).
- Combine publishers updating `@Published` properties must deliver on the main queue (`.receive(on:)` or `MainActor.run`).
- Audio callbacks (e.g., `AVAudioPlayerNode`) never arrive on main — wrap UI mutations in `Task { @MainActor in … }`.
- Use dispatch preconditions and Main Thread Checker to catch violations; add threading regression tests.

## 4. Unread / Legacy Materials
- `Fonic HiFi SaaS Implementation Plan.pdf` – binary asset not parsed here; presumed legacy business plan.
- `/Files/Archive/**` – explicitly marked as historical and not representative of the current build; keep archived separately if needed.

## 5. Recommended Actions Before Removing `/Files`
1. Confirm no outstanding need for the PDF; relocate to a long-term archive if retention required.
2. Ensure `plan2/prd2.md` and this summary are version-controlled so future agents reference the distilled requirements.
3. Update onboarding/playbook docs (e.g., `README.md`) with key points: MVP priorities, critical code fixes, concurrency safeguards.

With the above captured, the `/Files` folder can be archived or removed from the working tree without losing pertinent guidance for the active project.
