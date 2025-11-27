# Codex Analysis – Fonic HiFi Widget Plan

## Snapshot
- Overall structure (App Group → App Intents → widgets → Live Activity) is reasonable, but several steps assume capabilities and targets that do not exist in the repo today.
- Plan omits project-required patterns (strict `@MainActor`, `Sendable` for cross-actor types, existing logging/metrics taxonomy) and provisioning steps (App Group, Live Activities capability).
- Control Center controls appear speculative for third-party apps on iOS 26 [Inference]; treat that phase as out of scope unless Apple exposes an API.

## Alignment vs Current Repo
- No widget extension target exists; `Fonic HiFi/Fonic_HiFi.entitlements` only has APS, so App Group and Live Activities capabilities are not configured.
- `Info.plist` lacks `NSSupportsLiveActivities`; Signing & Capabilities would also need Live Activities enabled, not just a plist flag.
- `Core/Services` currently only has artwork/dominant color services; proposed coordinators/command processors are new patterns not referenced elsewhere.

## Technical Accuracy
- App Intents: Widget/AppIntent executions run in the app process; accessing `AudioEngineFacade` via a “service locator” from the widget extension is unnecessary and unsafe. Intents should be `@MainActor` and call the facade directly when the app wakes.
- Command processor queue: Polling App Group for commands is redundant if intents already execute in the app process. If background execution is required, use a lightweight intent that wakes the app, not a polled queue.
- Timeline updates: Calling `WidgetCenter.reloadAllTimelines()` on every playback change will hit system throttling; prefer `AppIntentTimelineProvider` and only reload on meaningful state transitions.
- Artwork storage: UserDefaults is unsuitable for artwork blobs; use file-based caches under the shared container with bounded sizes and purge rules.
- Live Activity: Second-by-second updates are outside ActivityKit guidance [Inference]; use `ActivityContent` with expected progress and fewer state updates.
- Data model: Shared `Codable` structs are fine, but must stay under 4 KB when bundled with Live Activity state; keep artwork thumbnails tiny and optional.
- StandBy: Rendering mode adjustments are fine, but rely on runtime environment values instead of static sizing assumptions.

## Missing Considerations
- Concurrency: All UI/intent-facing types should be `@MainActor`; cross-actor payloads must conform to `Sendable`.
- Observability: New services must use `Log.logger(_:)` taxonomy and `LogPrivacy` helpers; counters only when `Metrics.enable(true)` is set (debug/test).
- Testing: No plan for widget/intent tests or snapshot coverage; adding a new target without tests will drop coverage.
- Provisioning: App Group ID choice, shared container path conventions, and team/bundle settings are unspecified—blocking risks.

## Viability & Adjustments
- Feasible if scoped to: App Group + shared state structs, App Intent-driven interactive widgets (small/medium/lock), and Live Activity with throttled updates. Treat Control Center controls as non-viable until an Apple API is confirmed.
- Replace command processor with direct intent execution; ensure intents can wake the app to call `AudioEngineFacade`.
- Use file-backed artwork cache with size limits; persist only compact state in UserDefaults.
- Add capabilities first (App Group, Live Activities) and wire initialization in `FonicHiFiApp` after confirming actor boundaries.

## Effort
- Estimate is optimistic; adding a new target, entitlements, Live Activity, artwork pipeline, and tests likely exceeds 27 hours once provisioning and QA are included [Inference].

## Recommended Next Steps
- Define App Group identifier and enable App Group + Live Activities capabilities.
- Design shared state schema (playback + track + minimal artwork key) and a file-backed thumbnail cache.
- Implement App Intents (`@MainActor`) that invoke `AudioEngineFacade`; drop the command processor.
- Build a single widget extension using `AppIntentTimelineProvider`, with throttled reloads and proper families (home/lock/StandBy).
- Implement Live Activity with sparse updates and thumbnail compression; add plist flag and capability.
- Add tests: intent execution paths, state serialization, and basic widget snapshot/assertions where possible.***
