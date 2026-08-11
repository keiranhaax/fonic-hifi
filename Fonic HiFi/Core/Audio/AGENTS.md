# Audio and Playback Instructions

These instructions extend the repository root guide for `Core/Audio/`.

## Ownership and State

- Keep one playback source of truth. Route UI-facing behavior through `AudioEngineFacade` and the established controller, engine manager/factory, queue, playback-state, coordinator, and audio-session boundaries.
- SwiftUI views and unrelated services must not manipulate engine adapters or duplicate playback, queue, progress, or Now Playing state.
- Engine selection depends on preference, performance mode, format capability, and runtime availability. Do not replace it with a fixed format-to-engine split.
- Preserve coherent transitions across load, play, pause, seek, completion, queue advance, engine switch, interruption, route change, background playback, remote commands, and Now Playing metadata.
- Audio callbacks may arrive off actor. Hop to the established main-actor owner before changing playback state, and preserve task cancellation.
- Asynchronous playback results (completions, crossfade completions, initialization) are generation-scoped; validate against the active generation before mutating state, and do not remove or bypass these guards.
- Audio taps and render-adjacent callbacks must not allocate per buffer, log, or publish observable state; bounded event signaling, as in the underrun tap, is the ceiling.

## Regression Guardrails

- Do not deactivate the audio session between queue tracks. Deactivation belongs to real playback teardown.
- Route loss, especially loss of the previous output device, must leave playback and Now Playing state coherent and must not continue unexpectedly on another route.
- Do not change completion, queue-advance, seek, interruption, or engine-switch behavior without examining the associated facade, controller, coordinator, queue, state, and session tests.
- Gapless playback, crossfade, ReplayGain, EQ, playback rate, time-pitch, mixing, and engine selection are coupled behaviors; preserve their established ordering and eligibility rules.
- Media-services reset recovery flows from `AudioSessionManager` through `AudioEngineManager` to `PlaybackController.recoverAfterMediaServicesReset`; preserve this rebuild path and its reentrancy guard.
- Repeated skip, boundary, or engine-recovery failures must trip a bounded stop with a surfaced reason, never an unbounded loop.

## Evidence and Validation

- Treat internal “bit-perfect” status as eligibility, not proof. Conclusive claims require the source format, actual output format, route, volume, resampling path, and every DSP stage to be measured on the intended physical output.
- Generated tones and temporary audio files are valid for logic tests. Decoder and transition claims require representative real tracks and formats.
- Simulator results do not prove routes, interruptions, background audio, Bluetooth, AirPlay, USB DAC, gapless output, high-resolution output, or bit-perfect playback.
- Run the narrowest affected audio tests first, then build the app. Exercise the applicable interruption, route, background, remote-command, seek, completion, and consecutive-track scenario.
- Performance work requires comparable before-and-after measurements; do not present suspicion or graph inspection as measured improvement.
