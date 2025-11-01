## Upcoming Work From `tasks.md`
1. **Phase 3C – Import Batching Improvements**
   - Implement bounded-concurrency import batching (e.g., `AsyncStream` queue).
   - Add logging/metrics instrumentation to track batch progress.
   - Validate the new pipeline with representative manual import scenarios.

2. **Phase 4A/4C/4D – Testing & CI Foundation**
   - Wire `make test` directly to the Swift test suite and make the Makefile fail when lint/test fail.
   - Add integration/UI coverage (Swift Testing flow, optional XCUITest smoke tests).
   - Capture and publish coverage data, set enforcement thresholds, and build a CI workflow running lint/build/test (with coverage artifacts if possible).

3. **Phase 5 – Observability & Documentation**
   - Finalize logging categories/redaction rules and add key metrics counters.
   - Refresh docs (`CLAUDE.md`, `AGENTS.md`, README) and author the pending ADRs.
   - Prepare knowledge-transfer artifacts (Loom/doc walkthrough, postmortem report), keeping STATUS metrics in sync throughout.