# Widget Instructions

These instructions extend the repository root guide for `Fonic HiFi Widget/`.

## Shared Contracts

- The app and widget compile separately. Keep widget-side copies under `Shared/` wire-compatible with their app-side counterparts until they are intentionally unified.
- Preserve App Group identifiers, keys, Codable field names, defaults, and backward decoding behavior. Treat changes as migrations and test old stored payloads.
- Keep widget intent stubs synchronized with app-side App Intent names, parameters, titles, conformances, and routing assumptions.
- Do not make the widget a second authority for playback, queue, or library state.

## Timeline and Degraded States

- Timeline generation must remain bounded and safe when shared data, artwork, the app process, or playback dependencies are unavailable.
- Preserve placeholder, snapshot, timeline, empty, stale-data, missing-artwork, and decode-failure behavior.
- Avoid expensive or unbounded work in timeline and view construction.

## Verification

- Build both the containing app and widget extension.
- Test old and current shared payloads plus placeholder, snapshot, timeline, empty, stale, missing-artwork, and corrupted-data cases.
- Verify intent configuration and routing when affected. Simulator rendering is useful visual evidence but does not prove background refresh timing on a physical device.
