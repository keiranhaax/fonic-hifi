# Fonic HiFi Part 2, Work Package 1: Foundation Models review

## TLDR

The Foundation Models integration needs hardening before release. This scoped review found no Critical or High-severity defect and no off-device model-data path, but it confirmed seven Medium findings and one Low finding across session reuse, generated-ID validation, cancellation, availability and locale handling, Smart Search fallback behavior, model-path testing, launch latency, and prompt-boundary safety. The repository was not modified.

## Verdict

**NEEDS HARDENING**

- New findings: 8
- Critical: 0
- High: 0
- Medium: 7
- Low: 1
- Repository fixes applied: 0
- Repository commit audited: `459db9bfd18d17960e8fd2ff8defc4701085532e`
- Repository state: clean before and after review

This is a read-only static review. Apple-framework runtime claims that require Xcode, Simulator, Instruments, or an eligible physical device are labeled as unverified.

## Scope and baseline

This continuation reviewed only:

- Foundation Models imports and schemas
- `SystemLanguageModel` availability
- `LanguageModelSession` construction and reuse
- prompts and generated content
- app-defined tools and network boundaries
- Swift concurrency and cancellation at the model boundary
- privacy of model inputs and outputs
- error and locale handling
- iOS platform availability
- first-order callers, consumers, and tests

The attached checkpoint ZIP was inspected first. Its manifest validated all 11 expected Markdown files and explicitly stated that the standalone Foundation Models review was incomplete and absent. The fresh repository clone resolved to the exact prior commit and a clean worktree.

Direct product imports of `FoundationModels` exist only in:

1. `Fonic HiFi/Core/AI/Recommendations/RecommendationSchemas.swift`
2. `Fonic HiFi/Core/AI/Recommendations/RecommendationService.swift`
3. `Fonic HiFi/Core/AI/Search/SmartSearchService.swift`

The review traced those files through `ListeningPatternAnalyzer`, `HomeView`, `QuickActionsSection`, `SmartSearchViewModel`, `SearchView`, `SmartSearchResultsView`, the relevant `TrackDataActor`/`DataManager` methods, project settings, and six Foundation Models-related test files.

## Findings summary

| ID | Severity | Finding | Status |
|---|---|---|---|
| FMA-001 | Medium | A shared session can receive overlapping recommendation requests | Confirmed statically; exact runtime outcome needs device validation |
| FMA-002 | Medium | Generated track UUIDs are structurally typed but not checked against the offered set | Confirmed statically |
| FMA-003 | Medium | Canceled Smart Search work can be converted into a fallback result and overwrite newer state | Confirmed statically; Foundation Models cancellation timing needs runtime validation |
| FMA-004 | Medium | Availability, runtime asset loss, locale failure, and model errors collapse into booleans or generic fallback | Confirmed statically |
| FMA-005 | Medium | Smart Search’s documented standard-search fallback returns an empty AI result without handing off | Confirmed statically; currently bounded by UIUX-011 |
| FMA-006 | Low | User queries and imported metadata are inserted into prompts without explicit untrusted-data boundaries | Confirmed statically; impact is local and no tools/network are present |
| FMA-007 | Medium | Tests do not deterministically exercise the live model path or its failure matrix | Confirmed statically; tests were not runnable here |
| FMA-008 | Medium | Initial Home rendering waits for a full model response | Confirmed statically; latency needs Instruments/device measurement |

# Detailed findings

## FMA-001: A shared session can receive overlapping recommendation requests

- Severity: Medium
- Confidence: High for the reachable overlap; exact Apple runtime result is unverified
- Related prior finding: UIUX-019

### Evidence

`Fonic HiFi/Core/AI/Recommendations/RecommendationService.swift:7-13,91-134,172-189`

```swift
@MainActor
public final class RecommendationService {
    private var session: LanguageModelSession?
```

```swift
if let existingSession = session {
    return existingSession
}
```

`Fonic HiFi/Presentation/Views/Home/HomeView.swift:32-36,260-299`

```swift
private let recommendationService = RecommendationService()
@State private var isGeneratingRecommendations = false
```

```swift
Task {
    isGeneratingRecommendations = true
    defer { isGeneratingRecommendations = false }
    // ...
    let result = await recommendationService.generateSurpriseMix(...)
```

`Fonic HiFi/Presentation/Views/Home/Sections/QuickActionsSection.swift:26-33`

```swift
Button {
    onSurpriseMe()
} label: {
    Label("Surprise Me", systemImage: "dice")
}
```

The busy state is not passed to `QuickActionsSection`, and the button remains enabled. Each tap creates a new unstructured task. Those tasks share one `RecommendationService` and therefore one cached `LanguageModelSession`.

Apple’s current documentation says a session handles only one request at a time and that another `respond` call before completion causes a runtime error. Apple separately says not to call `respond` while `isResponding` is true and to disable the submitting interaction. See A1 and A3 in `evidence/APPLE_SOURCES.md`.

### Reachable path and impact

Rapidly tapping Surprise Me can overlap two calls to `generateSurpriseMix`. Both can obtain the same cached session and call `respond`. At minimum, one request can fail and fall back while both tasks still race to replace the queue and start playback. Apple documents the overlapping-session call as a runtime error, but whether this exact iOS 26 build throws a catchable generation error or traps must be verified on an eligible device.

The existing UIUX-019 already identifies the repeated-action and queue race. This finding adds the Foundation Models session-contract impact. Formal deduplication belongs to Work Package 2.

### Preserving remediation

- Make the existing busy state the single admission gate before creating a task.
- Disable the action while generation is active.
- Check `session.isResponding` before every shared-session call.
- Prefer a fresh session for these independent single-turn recommendation requests, as Apple recommends for single-turn interactions.
- Do not introduce a new recommendation architecture solely for this fix.

### Verification

On an Apple-Intelligence-capable device, inject a delayed response and tap Surprise Me repeatedly. Acceptance requires exactly one active generation, no second `respond` call on the same session, one queue replacement, one playback start, and stable recovery after success, failure, cancellation, backgrounding, and model unavailability.

## FMA-002: Generated track UUIDs are structurally typed but not checked against the offered set

- Severity: Medium
- Confidence: High

### Evidence

`Fonic HiFi/Core/AI/Recommendations/RecommendationSchemas.swift:11-19,35-43,59-67,80-95`

```swift
@Guide(description: "Track UUID strings that match the time of day mood", .count(5))
public var trackIDStrings: [String]

public var trackIDs: [UUID] {
    trackIDStrings.compactMap { UUID(uuidString: $0) }
}
```

The same string-to-UUID pattern is used for `MixDefinition`, `SurpriseMixResult`, and `SmartSearchResult`.

`Fonic HiFi/Core/AI/Recommendations/RecommendationService.swift:49-64,105-122`

```swift
- Track UUIDs to choose from: \(trackIDs.prefix(20).map { $0.uuidString }...)
```

```swift
Use ONLY track UUIDs from the provided list.
```

`Fonic HiFi/Core/AI/Search/SmartSearchService.swift:145-155`

```swift
let limited = metadata.prefix(100)
context += "- \(track.id.uuidString): ..."
```

`Fonic HiFi/Data/DataManager+Recent.swift:170-187`

```swift
return ids.compactMap { trackMap[$0] }
```

### Why this is defective

`@Generable` and `@Guide` guarantee the generated structure and array-count constraints. They do not prove that a syntactically valid UUID belongs to the runtime set offered in the prompt. The implementation never computes an allowed-ID set and never rejects, deduplicates, or repairs output IDs.

Invalid UUID text disappears silently in `compactMap`. A valid but unoffered UUID survives until the database fetch drops it. Duplicate IDs remain possible. The exact-count guides also demand five or seven values even when a small library has fewer unique tracks, creating an impossible contract unless IDs repeat or the model violates the requested business rule.

Apple’s guided-generation documentation describes constrained structural output and points to runtime schemas when allowed values are known only at runtime. See A6.

### Impact

- Greeting and surprise sections can contain fewer tracks than promised.
- A partly valid surprise mix can play a shortened queue without explaining why.
- A fully unresolved surprise result falls back to shuffle, hiding the model-contract failure.
- Generated match reasons can become misaligned after invalid or duplicate IDs are removed.

### Preserving remediation

After generation, validate against the exact IDs included in that request:

1. Parse UUIDs.
2. Keep only IDs in the allowed set.
3. Deduplicate while preserving generated order.
4. Enforce a request-specific maximum no greater than the available unique count.
5. If the validated count is below the product minimum, return a typed validation failure and use the existing deterministic fallback.

A runtime schema that constrains choices to the supplied IDs is worth evaluating, but post-generation validation remains required at the integration boundary.

### Verification

Use a model seam or fixture to return malformed UUIDs, valid-but-unoffered UUIDs, duplicates, and more requested items than the library contains. Acceptance requires that no unoffered ID reaches a view or queue, ordering remains deterministic, small libraries work, and fallback is explicit and testable.

## FMA-003: Canceled Smart Search work can be converted into a fallback result and overwrite newer state

- Severity: Medium
- Confidence: High for the state path; model cancellation timing is unverified

### Evidence

`Fonic HiFi/Presentation/Views/Search/SearchView.swift:79-113`

```swift
searchTask?.cancel()
searchTask = Task {
    try? await Task.sleep(for: .milliseconds(300))
    guard !Task.isCancelled else { return }
    // ...
    await smartSearchViewModel.performSmartSearch(query: newValue, dataManager: dataManager)
}
```

`Fonic HiFi/Core/AI/Search/SmartSearchService.swift:89-110`

```swift
let response = try await session.respond(...)
// ...
} catch {
    logger.error("Smart search failed: \(error.localizedDescription)")
    return await fallbackSearch(query: query, availableTrackIDs: availableTrackIDs)
}
```

`Fonic HiFi/Presentation/ViewModels/SmartSearchViewModel.swift:72-95`

```swift
let result = await smartSearchService.smartSearch(...)
smartSearchResult = result
resultTrackIDs = result.trackIDs
searchState = result.trackIDs.isEmpty ? .noResults : .results
```

### Why this is defective

Cancellation is checked only before the model request. If the query changes while `respond` is suspended, the old task is flagged as canceled, but the service catches every error and turns it into a normal fallback result. There is no `Task.checkCancellation` after the model call, no cancellation-specific rethrow, and no query generation token before the view model writes state.

Swift task cancellation is cooperative and does not automatically stop arbitrary functions. See A11.

### Impact

An older query can finish after a newer query and replace its state with `.noResults` or stale results. Cancellation can be logged as an AI failure even though it is an expected lifecycle event. Reusing the same session can also interact with FMA-001 if a canceled request is still responding when the next query starts.

Current production reachability is reduced by prior finding UIUX-011, which makes the Smart Search mode control effectively unreachable. The defect becomes active as soon as that existing UI issue is corrected.

### Preserving remediation

- Let cancellation remain cancellation. Do not convert it into a fallback result.
- Check cancellation after each awaited data fetch and after model generation.
- Associate every search with a monotonically increasing request ID or the exact normalized query, and commit state only if it is still current.
- If a session remains shared, wait until it is not responding or replace it with a fresh single-turn session for each query.

### Verification

Use an injected delayed model responder. Submit A, then B, then clear the field. Acceptance requires that A never overwrites B, clearing never reappears as results/no-results, cancellation produces no user error, and only the current query can write final state.

## FMA-004: Availability, runtime asset loss, locale failure, and model errors collapse into booleans or generic fallback

- Severity: Medium
- Confidence: High

### Evidence

`Fonic HiFi/Core/AI/Recommendations/RecommendationService.swift:21-29,39-86,96-135`

```swift
switch SystemLanguageModel.default.availability {
case .available: return true
case .unavailable: return false
}
```

`Fonic HiFi/Core/AI/Search/SmartSearchService.swift:21-29,55-110` uses the same Boolean collapse.

The greeting and Smart Search paths distinguish only guardrail and context-window cases. Surprise Mix catches all errors generically. No product source calls `supportsLocale` or `supportedLanguages`.

`Fonic HiFi/Presentation/ViewModels/SmartSearchViewModel.swift:38-43`

```swift
isSmartSearchEnabled = await smartSearchService.isSmartSearchAvailable()
```

`Fonic HiFi/Presentation/Views/Search/SearchView.swift:44-75` renders results, no-results, standard results, loading, or the empty view. It does not render `SmartSearchViewModel.SearchState.error(String)`.

### Why this is defective

The same false/generic-fallback path represents materially different states:

- ineligible device
- Apple Intelligence disabled
- model assets still downloading or temporarily unavailable
- assets removed while the app is running
- unsupported language or locale
- guardrail refusal
- context overflow
- decoding or other generation failure
- cancellation

Apple documents reason-specific availability UI, runtime `assetsUnavailable`, locale preflight, and user-facing handling for unsupported languages and guardrail failures. See A1, A4, A5, and A7.

### Impact

Users cannot distinguish a permanent device limitation from a temporary model download, a language mismatch, a safety refusal, or a retryable runtime failure. Search can show no results rather than a model error. This also makes telemetry and testing unable to prove which failure path occurred.

### Preserving remediation

Define a small app-owned model-status/error type that preserves the Apple reason without exposing raw framework diagnostics. Map each case to one of: available, unavailable-permanent, unavailable-user-action, unavailable-temporary, unsupported-language, safety-refusal, canceled, or generation-failed. Keep deterministic fallbacks, but return the reason with the fallback so the caller can present the correct state.

Do not expose private prompt or library content in errors or logs.

### Verification

Exercise eligible/ineligible devices, Apple Intelligence off, assets downloading, assets removed after preflight, unsupported app locale, mixed-language query, guardrail input, context overflow, decoding failure, cancellation, and unknown errors. Every state must produce the intended fallback and a distinct, user-safe UI outcome.

## FMA-005: Smart Search’s documented standard-search fallback returns an empty AI result without handing off

- Severity: Medium
- Confidence: High
- Related prior finding: UIUX-011

### Evidence

`Fonic HiFi/Core/AI/Search/SmartSearchService.swift:55-58,113-140`

```swift
guard await isSmartSearchAvailable() else {
    logger.info("Foundation Models unavailable, using fallback search")
    return await fallbackSearch(query: query, availableTrackIDs: availableTrackIDs)
}
```

```swift
// In fallback mode, return empty and let standard search handle it
return SmartSearchResult(
    trackIDs: [],
    matchReasons: [],
    searchStrategy: "Smart search unavailable - use standard search fallback",
    suggestions: [...]
)
```

`Fonic HiFi/Presentation/ViewModels/SmartSearchViewModel.swift:79-86` maps empty track IDs to `.noResults`.

`Fonic HiFi/Presentation/Views/Search/SearchView.swift:57-60` renders the Smart Search no-results view. No code invokes the standard search after this fallback result.

### Impact

If the model becomes unavailable after Smart Search was enabled, the app claims to use standard search but shows no AI results instead. The user can be told there are no matches even when deterministic title or artist matches exist.

UIUX-011 currently makes Smart Search hard to reach through the active UI, which bounds present impact. This finding should be merged with the final Smart Search reachability/remediation record during Work Package 2 rather than fixed as an isolated feature redesign.

### Preserving remediation

Make fallback ownership explicit. Either:

- have the service return a typed `useStandardSearch` outcome that `SearchView` routes to its existing `performSearch`, or
- perform deterministic metadata filtering inside the service with the same semantics and return those track IDs.

Do not represent fallback as a successful empty AI result.

### Verification

Enable Smart Search, then simulate asset removal, Apple Intelligence being disabled, an unsupported locale, and a transient generation failure. Known exact and partial title/artist matches must appear through the standard path, and the UI must explain when semantic search is unavailable.

## FMA-006: User queries and imported metadata are inserted into prompts without explicit untrusted-data boundaries

- Severity: Low
- Confidence: High

### Evidence

`Fonic HiFi/Core/AI/Search/SmartSearchService.swift:67-87`

```swift
User search query: "\(query)"
```

`Fonic HiFi/Core/AI/Search/SmartSearchService.swift:145-155`

```swift
context += "- \(track.id.uuidString): \"\(track.title)\" by \(track.artist) [\(genre)]\n"
```

Both values are placed in the prompt without escaping, a dedicated prompt builder, explicit untrusted-data delimiters, or output-policy validation. The model-generated strategy, reasons, and suggestions are rendered in `SmartSearchResultsView.swift:16-24,31-47,94-100`.

### Risk and mitigation context

A query or imported tag can contain quotes, newlines, instruction-like text, or sensitive language. That can redirect the model or cause off-topic or unsafe local output. Apple recommends boundaries for open or unverified input and app-specific safety layers. See A7.

The impact is deliberately rated Low because this code configures no Foundation Models `Tool`, contains no network client or endpoint, and uses the on-device `SystemLanguageModel`. Prompt injection cannot trigger an app-defined side effect or exfiltrate data through the reviewed model path. Built-in guardrails also provide a base safety layer.

### Preserving remediation

- Build prompts with explicit sections that mark the query and metadata as data, not instructions.
- Normalize or escape line-breaking delimiters in imported metadata.
- Strengthen trusted session instructions to ignore commands embedded in query/metadata fields.
- Validate generated user-visible strings against the feature’s narrow music-search purpose.
- Add adversarial prompt tests and re-run them after OS/model/guardrail updates.

Do not add a server, deny-list service, or complex agent framework for this local feature.

### Verification

Test quotes, multiline text, embedded instructions, mixed languages, sensitive phrases, extremely long tags, and metadata that attempts to override the session role. The output must remain bounded to music-search results and must never trigger app actions.

## FMA-007: Tests do not deterministically exercise the live model path or its failure matrix

- Severity: Medium
- Confidence: High

### Evidence

`Fonic HiFiTests/Core/AI/RecommendationServiceTests.swift:35-43`

```swift
let isAvailable = await service.isFoundationModelsAvailable()
#expect(isAvailable == true || isAvailable == false)
```

`Fonic HiFiTests/Presentation/SmartSearchViewModelTests.swift:19-28` contains the same tautological availability assertion.

`Fonic HiFiTests/Integration/AIRecommendationsIntegrationTests.swift:9-35` calls production generation and comments that it “Should work even without AI (fallback)”. It does not prove whether the model or fallback path ran.

`Fonic HiFiTests/Integration/SmartSearchIntegrationTests.swift:9-43` calls production Smart Search and only requires nonempty strategy text or an empty result for an empty query. On an unavailable host, this is a fallback test; on an eligible host, it is nondeterministic model inference.

The services construct `SystemLanguageModel.default` and `LanguageModelSession` internally. No model/session protocol or injected response seam exists.

### Missing deterministic coverage

- each availability reason
- asset loss after preflight
- unsupported locale
- guardrail and decoding errors
- context overflow and session reset
- overlapping requests
- cancellation and stale-query suppression
- invalid, unoffered, and duplicate generated UUIDs
- prompt-boundary adversarial cases
- proof that fallback invokes standard search
- eligible-device live generation assertions and prompt evaluations

### Impact

The suite can pass while only exercising fallback, or become host-dependent if a model is available. It does not establish that the production Foundation Models path compiles, returns semantically valid library IDs, handles its error matrix, or remains stable after OS model updates.

### Preserving remediation

Introduce a narrow injected generation seam owned by these two services. Keep the production adapter thin around `SystemLanguageModel` and `LanguageModelSession`. Test deterministic fixtures and errors without replacing the existing service API. Keep a separate eligible-device suite for actual Apple model evaluations, locale/guardrail checks, and Instruments measurements.

### Verification

CI must report which suite ran: deterministic unit tests, iOS Simulator integration, or eligible physical-device model evaluations. A fallback-only run must never be labeled as live Foundation Models coverage.

## FMA-008: Initial Home rendering waits for a full model response

- Severity: Medium
- Confidence: High for the state dependency; latency magnitude is unverified

### Evidence

`Fonic HiFi/Presentation/Views/Home/HomeView.swift:45-61,186-237`

```swift
if isLoading {
    ProgressView("Loading your music...")
}
```

```swift
if showLoading {
    isLoading = true
}
// Load core library sections...
if !recentlyPlayed.isEmpty {
    let greeting = await recommendationService.generateTimeBasedGreeting(...)
    timeBasedGreeting = greeting
    greetingTracks = try dataManager.fetchTracks(by: greeting.trackIDs)
}
isLoading = false
```

Apple says a Foundation Models response may take a few seconds. The Home view does not clear its blocking loading state after core library data is ready; it waits for the entire AI greeting request and follow-up fetch.

### Impact

On an eligible device with listening history, the app can hold back all Home content while a nonessential recommendation is generated. A model slowdown, context error, or asset transition extends the launch-facing spinner even though deterministic library content is already available.

This is not evidence that `respond` blocks the MainActor thread. The method is asynchronous, and current API signatures are nonisolated. The confirmed defect is the UI state dependency, not a claimed thread stall.

### Preserving remediation

Publish core Home data and clear `isLoading` before starting the optional greeting request. Generate the greeting in a separately owned, cancelable task with a small local loading/placeholder state for that section. Preserve existing content if generation fails or is canceled.

### Verification

Measure time to core Home content and time to AI greeting separately on eligible and ineligible devices. Core content must appear without waiting for the model. Leaving Home must cancel or safely ignore the optional result. Use the Foundation Models Instruments template for request latency and token measurement.

# Related prior findings

These records were independently checked only at the Foundation Models boundary. They are not duplicated in the new count and were not edited or repackaged.

| Prior ID | WP1 disposition | Relationship |
|---|---|---|
| UIUX-009 | Retained for its Smart Search slice | `.error(String)` exists but SearchView does not render it; overlaps FMA-004 |
| UIUX-011 | Retained | Smart Search mode control is unreachable in normal state flow; bounds FMA-003 and FMA-005 |
| UIUX-019 | Retained | Repeated Surprise Me taps create concurrent tasks; combines with the shared-session contract in FMA-001 |
| DCA-PART-004 | Retained but outside Foundation Models remediation | Smart result tap ends in a log-only playback placeholder |
| PSR-006 | Retained for its on-device intelligence disclosure slice | The privacy text omits query/history/metadata use by on-device Foundation Models; WP1 found no off-device model path |

Formal duplicate merging is reserved for Work Package 2.

# Rejected or bounded candidate findings

1. **“Foundation Models sends the music library to a server.” Rejected.** Direct AI code contains no tool, URLSession, HTTP literal, or network fallback. It uses `SystemLanguageModel.default`; Apple documents this path as on-device and offline-capable.
2. **“Tool calling can exfiltrate data.” Not applicable to the current implementation.** No `Tool` conformance or `tools:` session initializer exists in the product path.
3. **“@MainActor proves model inference blocks the UI thread.” Rejected.** `respond` is asynchronous and current signatures are nonisolated. FMA-008 is limited to the view waiting on the result.
4. **“@Generable output can be malformed JSON.” Rejected as framed.** Guided generation provides structural constrained output. FMA-002 is the separate semantic-membership defect.
5. **“The Foundation Models imports violate platform availability.” Rejected.** The app target is iOS 26.0 and the reviewed API surface is available on iOS 26. No iOS 27-only model/provider API was found in the live product path.
6. **“Streaming is mandatory for these outputs.” Rejected.** The schemas request short structured results. The confirmed issue is where Home waits for inference, not absence of streaming by itself.
7. **“The music-search/recommendation use case violates Apple’s Foundation Models acceptable-use requirements.” Rejected.** No prohibited category was identified in the current Apple policy page.

# Verified-good controls

- Both services check `SystemLanguageModel.default.availability` before generation.
- Recommendations have deterministic local fallbacks.
- User query and imported metadata stay in prompts, not trusted session instructions.
- Guided generation is used instead of manual JSON parsing.
- No app-defined Foundation Models tool exists.
- No direct AI network client, endpoint, or remote-model fallback exists.
- The product target is iOS 26.0 with complete strict-concurrency checking.
- No repository source or configuration file was changed.

# Verification commands and results

| Check | Result |
|---|---|
| Attached ZIP path-safety and size inventory | PASS: 15 entries, no unsafe path |
| Attached checkpoint manifest byte/line/SHA-256 validation | PASS: 11 of 11 |
| Fresh HTTPS clone and revision check | PASS: exact commit `459db9b...` |
| Repository status | PASS: clean |
| Product Foundation Models structural verifier | PASS |
| Verifier Python syntax compilation | PASS |
| `git diff --check` | PASS |
| Deliverable JSON parsing | PASS at this phase |
| Swift parser/compiler | NOT RUN: Swift toolchain unavailable |
| Xcode build and test | NOT RUN: Xcode and Apple SDK unavailable |
| Simulator/device/Foundation Models runtime | NOT RUN: unavailable in Linux sandbox |

The structural verifier is included at `verification/verify_foundation_models.py`; its captured result is `verification/structural-verification.json`.

# Important limitations

- No Xcode, Apple SDK, Simulator, eligible physical device, or Foundation Models runtime was available.
- No app or test target was compiled.
- No prompt evaluation, guardrail matrix, locale matrix, cancellation timing, concurrent-session runtime, Instruments trace, or on-device latency measurement was performed.
- Current Apple documentation was live-crawled on 2026-07-10. iOS 27 beta APIs were excluded except where Apple’s WWDC26 material described already-shipped iOS 26.4 context/token APIs.
- The delegated secondary scan returned no analyzable result and was rejected in full. No sub-agent claim appears in this report.

# Recommended remediation order

1. FMA-001: enforce one request per session/action.
2. FMA-002: validate generated IDs against the request’s allowed set.
3. FMA-003: preserve cancellation and prevent stale state writes.
4. FMA-004 and FMA-005: make model status/error/fallback outcomes explicit.
5. FMA-007: add deterministic model seams and a separate eligible-device evaluation lane.
6. FMA-008: remove model generation from the blocking Home-load path.
7. FMA-006: add lightweight untrusted-data boundaries and adversarial prompt tests.

No remediation should be applied until the audit package and cross-domain deduplication order are reviewed.