### Key Takeaways from `refactor/refactor.md`
- The refactor program is organized into phases, with **Phase 0 (Verification & Baseline)** explicitly intended as the immediate next milestone before any large rewrites.
- Phase 0 tasks emphasize capturing the repository’s current state: clean git diff, baseline metrics (lint/build outputs, `print` usage counts, `tokei` LOC snapshot), a `make test` sanity run, and reproducing known duplicate-import/security-scope bugs.
- Deliverable for Phase 0 is a documented baseline stored at `docs/refactor/baseline-2025-10-07.md` summarizing all gathered evidence.

### Phase 1 Preview (Post-Baseline Work)
- After Phase 0, **Phase 1** targets safety and hygiene: fixing duplicate detection & security scope release (1A), replacing `print`/`fatalError`/force unwraps with structured logging and safer error handling (1B), and reworking format detection concurrency (1C).
- Each Phase 1 subsection pairs code changes with regression tests, reinforcing the plan’s “tests accompany every fix” principle.

### Dependencies & Coordination Notes
- Later phases (2–5) build on Phase 1’s logging and safety groundwork; large decompositions in Phase 2 assume the logging cleanup is already merged to avoid conflicts.
- Workstreams are assigned with dependency ordering, reinforcing that Phase 0 baselines and Phase 1 safeguards must complete before structural refactors proceed.

### Immediate Next Step Recommendation
- Execute Phase 0 verification tasks to produce the baseline report; this unlocks Phase 1’s implementation work while ensuring we have an authoritative snapshot for regression comparisons.