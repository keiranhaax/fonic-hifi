## Next Steps per `tasks.md`
1. **Phase 3B – Library Statistics Optimisation**  
   • Implement aggregated/batched statistics computation that avoids full dataset loads.  
   • Add TTL-based caching (or comparable strategy) and document any SwiftData limitations encountered.  

2. **Phase 3C – Import Batching Improvements**  
   • Introduce bounded-concurrency batching (e.g., via `AsyncStream`).  
   • Add logging/metrics instrumentation for batch progress and validate with manual import scenarios.  

3. **Phase 4A/4B/4D – Testing & CI Foundation**  
   • Wire `make test` to the Swift test suite and ensure failures propagate.  
   • Update the Makefile so lint/test failures fail the build.  
   • Track coverage toward the ≥65% target, capture coverage reports, and set up CI workflow (`.github/workflows/ci.yml`) running lint/build/test with coverage artifacts.  

4. **Phase 5 – Observability & Documentation (upcoming)**  
   • Finalize logging/metrics polish, refresh documentation (`CLAUDE.md`, `AGENTS.md`, README), author ADRs, and prepare knowledge-transfer materials.