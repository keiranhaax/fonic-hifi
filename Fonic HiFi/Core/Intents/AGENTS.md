# App Intents Instructions

These instructions extend the repository root guide for `Core/Intents/`.

## Contracts and Routing

- Keep app-side App Intent names, parameters, titles, conformances, and routing assumptions synchronized with widget-side stubs.
- Route intent actions through the established dependency provider and playback/library authorities. Intents must not create parallel audio, queue, or persistence state.
- Preserve parameter and identifier compatibility for donated, suggested, or previously configured intents.
- Treat App Group keys and shared Codable payloads as persistent contracts; coordinate any migration with the widget target.

## Failure Behavior and Verification

- Fail safely when the app process, dependency provider, audio engine, library, shared state, or requested track is unavailable.
- Do not imply that playback or mutation succeeded when the containing app could not complete the action.
- Test parameter resolution, routing, missing dependencies, missing data, cancellation, and degraded responses.
- Build the containing app and any affected extension. Verify the real intent path when the platform harness permits it.
