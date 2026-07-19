# Unit and Integration Test Instructions

These instructions extend the repository root guide for `Fonic HiFiTests/`.

## Test Design

- Follow the existing XCTest or Swift Testing convention in the affected area; do not migrate frameworks during unrelated work.
- Test externally observable behavior and regression contracts rather than private implementation details.
- Add focused regression coverage for bug fixes when the behavior is testable without distorting production design.
- Prefer the real lightweight boundary under test: in-memory SwiftData for persistence behavior, generated valid media for audio logic, and controlled doubles for external or nondeterministic collaborators.
- Never use a text file renamed with an audio extension; deferred media cleanup can remove it and destabilize tests.
- Preserve cancellation, actor isolation, ordering, cleanup, and failure behavior in concurrency tests. Do not weaken production isolation to simplify a test.

## Execution

- Run the smallest affected test or suite first, then `make test-unit` when the change or shared state warrants the full target.
- Do not run test processes concurrently against the same DerivedData, `build/`, or result-bundle path.
- Investigate failures against the current worktree and execution order before changing assertions or production behavior.
- Do not claim coverage from a stale result bundle; generate current-tree results before `make coverage-check` claims.
- Report skipped, quarantined, device-only, and order-dependent coverage explicitly.
