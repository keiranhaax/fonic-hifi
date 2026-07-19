# UI Test Instructions

These instructions extend the repository root guide for `Fonic HiFiUITests/`.

## Harness and Assertions

- Keep launch state deterministic and isolate tests from personal library data, credentials, network services, and prior simulator state.
- Exercise user-visible behavior through stable accessibility labels and identifiers. Do not couple tests to incidental view hierarchy or coordinates when semantic access is available.
- Prefer condition-based expectations over fixed sleeps; preserve useful failure screenshots and diagnostics.
- Cover critical empty, loading, error, permission, navigation, playback-control, and restoration paths without making the UI test target a substitute for focused logic tests.
- Add or change accessibility identifiers only when they improve a durable user or testing contract, not as a cosmetic workaround.

## Execution and Evidence

- Build the owning app before UI execution and run the narrowest affected UI test first, then `make test-ui` when broader coverage is warranted.
- Do not run UI tests concurrently against the same simulator, DerivedData, `build/`, or result-bundle path.
- Simulator UI tests do not prove physical-device audio routing, background execution, Bluetooth, AirPlay, USB DAC, or Apple Intelligence behavior.
- For visual changes, pair automated assertions with relevant screenshots or manual accessibility configuration checks and report unverified states.
