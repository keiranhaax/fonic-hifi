# Next Implementation Steps

## 1. Phase 3B – Library Statistics Optimisation
- Audit `DataManager` statistics helpers to design aggregate SwiftData queries that avoid materialising full datasets. [Verified-Code]
- Implement batch/aggregate fetchers plus optional TTL caching; validate via performance benchmarks mirroring Phase 3A methodology. [Inference]
- Add regression tests covering large-library scenarios to ensure correctness and memory stability. [Inference]

## 2. Phase 3C – Import Batching Improvements
- Introduce bounded-concurrency processing in `LibraryImportService`/`FileImportProcessor` (e.g., AsyncStream work queue) while preserving actor isolation. [Verified-Code]
- Emit structured logging/metrics for batch progress through `Log.logger` categories; verify via manual import test cases. [Inference]
- Document import benchmarking results for STATUS.md once validated. [Inference]

## 3. Phase 4A & CI Automation
- Wire `make test` to run the Swift test suite and update Makefile targets to fail on lint/test errors. [Inference]
- Create `.github/workflows/ci.yml` executing `make lint`, `make build`, `make test`, with optional coverage artifact upload. [Inference]
- Ensure CI updates include necessary badges/status updates in STATUS.md after verification. [Inference]

## 4. Phase 4C/D – Integration Tests & Coverage
- Implement Swift Testing integration flow (import → playback) plus minimal UI smoke coverage if feasible. [Inference]
- Capture coverage report (`docs/testing/coverage-YYYY-MM-DD.md`), set ≥65% gate, and update quick metrics. [Inference]

## 5. Phase 5 – Observability & Documentation
- Finalise logging categories, metrics counters, and redaction policies before polishing docs. [Inference]
- Author pending ADRs, refresh CLAUDE/AGENTS/README guidance, and prepare knowledge-transfer materials. [Inference]

## 6. Ongoing Coordination
- Update STATUS.md and success metrics after each milestone; continue weekly cadence communication. [Verified-Code]

Ready to proceed once priorities are confirmed.