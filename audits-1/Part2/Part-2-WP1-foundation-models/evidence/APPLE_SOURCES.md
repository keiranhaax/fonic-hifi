# Current Apple and Swift sources used for WP1

Accessed 2026-07-10. Primary sources are authoritative for framework and language behavior; repository conclusions still depend on the exact audited source at commit 459db9bfd18d17960e8fd2ff8defc4701085532e.

## A1. Generate content and perform tasks with Foundation Models

URL: https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models

Material claims:

- Always verify model availability and plan a fallback.
- For single-turn interactions, create a new session for each call.
- A session handles only one request at a time; calling it again before completion causes a runtime error, and isResponding should gate another request.
- Instructions, prompts, outputs, and schema all consume the session context window.
- The iOS 26 system model context is 4,096 tokens; remove transcript entries or split work when the limit is exceeded.
- A response may take a few seconds.

Exact excerpts used:

> “Always verify model availability first, and plan for a fallback experience in case the model is unavailable.”

> “For a single-turn interaction, create a new session each time you call the model.”

> “A session can only handle a single request at a time, and causes a runtime error if you call it again before the previous request finishes.”

## A2. LanguageModelSession

URL: https://developer.apple.com/documentation/foundationmodels/languagemodelsession

Material claims:

- A session is a single stateful context.
- Every prompt and response is retained in its Transcript.
- Exceeding the available context size throws a context-size error.
- Instruments and prewarm are the supported performance-analysis and latency tools.

Exact excerpt used:

> “The framework records each call to the model in a Transcript that includes all prompts and responses.”

## A3. isResponding

URL: https://developer.apple.com/documentation/foundationmodels/languagemodelsession/isresponding

Material claim: while isResponding is true, the app should not call another respond method and should disable interactions that can submit another prompt.

Exact excerpt used:

> “You should not call any of the respond methods while this property is true.”

## A4. Runtime asset loss

URL: https://developer.apple.com/documentation/foundationmodels/languagemodelsession/generationerror/assetsunavailable(_:)

Material claim: availability can change after the preflight because model assets can be deleted or Apple Intelligence can be disabled while the app is running.

Exact excerpt used:

> “This can happen if the user disables Apple Intelligence while your app is running.”

## A5. Languages and locales

URL: https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models

Material claims:

- Check supportsLocale before calling the model when the app supports locales Apple Intelligence may not support.
- Handle unsupportedLanguageOrLocale by explaining the limitation, disabling the feature, or providing an alternative.
- Guardrails only cover supported languages and locales reliably.

Exact excerpts used:

> “Before you call the model, run supportsLocale(_:) to verify the support for a locale.”

> “Handle the error by communicating to the person using your app that a language in their request is unsupported.”

## A6. Guided generation

URL: https://developer.apple.com/documentation/FoundationModels/generating-swift-data-structures-with-guided-generation

Material claims:

- Generable and constrained sampling guarantee the response structure, not business-semantic validity.
- Guides constrain supported property characteristics.
- A runtime generation schema is the Apple-provided pattern when allowed values are known only at runtime.

Exact excerpts used:

> “Constrained sampling prevents the model from producing malformed output and provides you with results as a type you define.”

> “If you don’t know what you want the model to produce at compile time use DynamicGenerationSchema to define what you need.”

## A7. Prompt and output safety

URL: https://developer.apple.com/documentation/foundationmodels/improving-the-safety-of-generative-model-output

Material claims:

- Open user input and unverified external content increase risk.
- Applications need use-case-specific boundaries in addition to built-in guardrails.
- Instructions should contain only trusted content.
- Prompts and outputs should receive adversarial safety testing and re-testing after model or guardrail updates.

Exact excerpts used:

> “Safety risks increase when a prompt includes direct input from a person using your app, or from an unverified external source.”

> “It’s vital to design additional safety layers specific to your app.”

## A8. On-device privacy and stateful sessions

URL: https://developer.apple.com/videos/play/wwdc2025/286/

Material claims:

- SystemLanguageModel inference is on-device and can work offline.
- Stateful sessions retain each interaction as transcript context.
- Tool calling is the boundary that can execute app-defined code.

Exact excerpt used:

> “All of this runs on-device, so all data going into and out of the model stays private. That also means it can run offline!”

## A9. Session recovery and tool boundary

URL: https://developer.apple.com/videos/play/wwdc2025/301/

Material claims:

- Repeated requests grow a session transcript and can hit its context limit.
- Recovery requires a new or condensed session.
- Tools can access local, private, or external data and can be called multiple times.

Exact excerpt used:

> “A LanguageModelSession is stateful. Each respond(to:) call is recorded in the transcript.”

## A10. iOS 26.4 context inspection

URL: https://developer.apple.com/videos/play/wwdc2026/241/?time=539

Material claim: iOS 26.4 added APIs to inspect context size and count tokens in instructions, prompts, and transcripts. These are production-line APIs relevant to an iOS 26 target; the iOS 27 model/provider features from the same session are out of this audit’s release scope.

Exact excerpt used:

> “In iOS 26.4, we released new APIs for inspecting the model’s context size and counting the tokens in instructions, prompts, and transcripts.”

## A11. Swift task cancellation

URLs:

- https://developer.apple.com/documentation/swift/task/cancel()
- https://developer.apple.com/documentation/swift/task/checkcancellation()

Material claims:

- Task cancellation is cooperative, not an automatic stop.
- Code must check or propagate cancellation where stopping is required.
- checkCancellation throws CancellationError for an already-canceled task.

Exact excerpt used:

> “Cancelling a task does not automatically cause arbitrary functions on the task to stop running or throw errors.”

## A12. Acceptable use requirements

URL: https://developer.apple.com/apple-intelligence/acceptable-use-requirements-for-the-foundation-models-framework/

Material claim: the framework’s prohibited-use requirements apply to any app that uses, prompts, or exposes Foundation Models. The audited local music-search and recommendation use case did not match a prohibited category found on this page.
