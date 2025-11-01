# Observability Walkthrough (Phase 5)

**Last Updated**: 2025-10-10

This guide describes how to exercise the logging taxonomy, privacy helpers, and optional metrics counters introduced during Phase 5 of the refactor program.

## 1. Logging Taxonomy

- All logging routes through `Log.logger(_:)`, which now exposes structured categories following the `<domain>.<area>[.<subarea>]` pattern (e.g., `.audio.engine`, `.metrics.queue`).[Verified-Code]
- Categories are defined in `Fonic HiFi/Utils/Logging/Log.swift`; prefer reusing an existing leaf category before adding a new root domain.[Verified-Code]
- Audio-specific flows can rely on the dedicated `audio.engine.switch`, `audio.metrics`, and `audio.queue.manager` labels for targeted filtering in Console or unified logging exports.[Verified-Code]

## 2. Privacy Helpers

- Use `LogPrivacy.filename(_:)` to redact absolute paths before emitting filenames in logs or metrics metadata.[Verified-Code]
- `LogPrivacy.truncated(_:limit:)` clamps long strings to a configurable limit (default 80 characters) to prevent leaking personal information in verbose metadata.[Verified-Code]
- Helpers live in `Fonic HiFi/Utils/Logging/LogPrivacy.swift`; they are static and side-effect free, making them safe to call from any actor.[Verified-Code]

## 3. Optional Metrics Counters

- Metrics emission is centralized in `Fonic HiFi/Utils/Logging/Metrics.swift`.[Verified-Code]
- Counters currently shipped:
  - `imports.discovered`, `imports.completed`, `imports.failed` – track library import throughput and failures.[Verified-Code]
  - `audio.engine.switch` – records engine transitions driven by `AudioEngineManager`.[Verified-Code]
  - `audio.queue.mutation` – captures queue mutations (enqueue, shuffle, navigation) in `AudioQueueManager`.[Verified-Code]
- Toggle metrics at runtime by calling `Metrics.enable(true)` during app bootstrap or from a debug preference; defaults to `false` to avoid noise in production builds.[Verified-Code]
- The helper formats each counter as a structured log line, tagging metadata pairs as `key=value` sorted alphabetically for consistent ingestion.[Verified-Code]

## 4. Instrumented Workflows

### 4.1 Library Import

1. Enable metrics: `Metrics.enable(true)`.[Verified-Code]
2. Trigger an import via `LibraryImportService.importFiles(from:)` (UI or tests). The service logs discovery progress to `library.import.service` while counters capture discovered/completed/failed files with redacted filenames.[Verified-Code]
3. Review logs in Console, filtering by subsystem `com.fonichifi` and categories `metrics.import` or `library.import.service`.[Verified-Code]

### 4.2 Engine Switching

1. Play tracks that require switching between AVAudioEngine and AudioKit adapters.[Inference]
2. `AudioEngineManager` will emit `metrics.engine` entries with the engine type and truncated format label whenever a new engine is created.[Verified-Code]
3. Queue corresponding `audio.engine.manager` log lines capture reuse vs. recreation decisions for additional context.[Verified-Code]

### 4.3 Queue Mutation Telemetry

1. Interact with playback controls (enqueue, shuffle, next/previous).[Verified-Code]
2. Each mutation invokes `recordQueueMutation`, raising a `metrics.queue` counter that includes action name, queue size, and redacted titles where applicable.[Verified-Code]
3. The associated audit trail remains in the structured log stream, enabling downstream dashboards to aggregate mutation frequency.[Inference]

## 5. Validation Checklist

- ⚙️ **Logging** – Confirm new code paths use one of the defined categories; add to `LogCategory` only when a domain gap exists.[Verified-Code]
- 🔒 **Privacy** – Redact external URLs, file paths, and user-entered text with `LogPrivacy` helpers before logging.[Verified-Code]
- 📊 **Metrics** – Wrap optional counters with feature flags or debug toggles so production builds can disable emission when necessary.[Inference]
- ✅ **Tests** – Extend coverage alongside feature work; `AudioQueueManagerTests` and `LibraryImportServiceTests` assert key behaviors of the new counters.[Verified-Code]

## 6. References

- `Fonic HiFi/Utils/Logging/Log.swift`
- `Fonic HiFi/Utils/Logging/LogPrivacy.swift`
- `Fonic HiFi/Utils/Logging/Metrics.swift`
- `Fonic HiFi/Data/Services/LibraryImportService.swift`
- `Fonic HiFi/Core/Audio/Engine/AudioEngineManager.swift`
- `Fonic HiFi/Core/Audio/Queue/AudioQueueManager.swift`

Use this walkthrough as the baseline for future observability enhancements and knowledge-transfer sessions.[Inference]
