# Observability SOP

## Logging Taxonomy

All logging MUST route through `Log.logger(_:)` using the taxonomy in `Fonic HiFi/Utils/Logging/Log.swift`.

- Add new `LogCategory` entries only when existing domains don't cover a scenario
- Redact filesystem details with `LogPrivacy.filename(_:)`
- Clamp long metadata via `LogPrivacy.truncated(_:limit:)` before logging

## Metrics

- Wrap optional counters with `Metrics.increment` only after calling `Metrics.enable(true)`
- Enable in debug builds or test harnesses only
- Leave metrics disabled in production builds unless explicitly requested

## Observability Checklist

1. Select an existing `LogCategory` (see `Utils/Logging/Log.swift`) or add a new entry within the matching domain namespace when necessary.
2. Redact filesystem details with `LogPrivacy.filename(_:)` and clamp long metadata via `LogPrivacy.truncated(_:limit:)` before logging.
3. Wrap optional counters with `Metrics.increment` only after calling `Metrics.enable(true)` (e.g., in debug builds or test harnesses).
4. Record instrumentation decisions in ADRs or `docs/refactor/observability-walkthrough.md` so future contributors share the same taxonomy assumptions.
