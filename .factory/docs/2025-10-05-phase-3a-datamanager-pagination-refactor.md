### Goals
- Replace DataManager’s manual, in-memory pagination with true offset/limit queries backed by SwiftData.
- Ensure all public paginated APIs (tracks, albums, artists, playlists, search variants) preserve their existing signatures while sourcing data from efficient repository helpers.
- Add regression tests exercising large result sets to verify paging correctness and memory usage boundaries.

### Key Workstreams
1. **Repository Enhancements**
   - Inspect `SwiftDataLibraryRepository` (and related repository helpers) to confirm current fetch implementations.
   - Introduce a reusable `PaginatedFetchDescriptor` helper that accepts page number + size and applies `fetchOffset`/`fetchLimit` before executing.
   - Provide typed wrappers (`fetchTracksPage`, `fetchAlbumsPage`, etc.) returning a standard `PaginatedResult` with `entities` + `hasMore` + `totalCount` where feasible.

2. **DataManager Integration**
   - Update `DataManager+LibraryMetrics.swift` and `DataManager+Search.swift` methods (`fetchTracks`, `searchTracks`, `fetchAlbums`, etc.) to call the new repository helpers instead of slicing arrays in memory.
   - Ensure legacy non-paginated variants reuse the paginated path with `pageSize` equal to the request count, removing duplicate logic.
   - Audit `fetchAllTracksInBatches` and similar utilities to make sure they iterate via paginated repository calls rather than preloading entire collections.

3. **Supporting Type Adjustments**
   - Extend or replace the existing result models (e.g., `PaginatedTracksResult`) so they can be initialised directly from repository responses without extra copying.
   - Confirm `TrackDataActor` interactions remain Sendable-safe; adjust any async boundaries if repository now performs async fetches.

4. **Testing Strategy**
   - Create `DataManagerPaginationTests` using an in-memory SwiftData container seeded with >200 sample entities; verify:
     - Page boundaries respect `pageSize`/`page` inputs.
     - `hasMore` toggles correctly.
     - Legacy non-paging APIs still return full collections but now leverage paginated internals.
   - Add stress-style async test ensuring iterative `fetchAllTracksInBatches` never loads more than one page at a time (can monitor by counting fetch invocations/memory via instrumentation hooks if available).

5. **Verification & Tooling**
   - Run `make lint` and targeted Swift tests (`make test TESTS=DataManagerPaginationTests`) after implementation.
   - Capture before/after performance metrics (execution time for a 10k-track fetch loop) using existing benchmarking harness or temporary measurement code, logging results for later inclusion in `perf-results.md`.

6. **Documentation & Cleanup**
   - Update any inline comments/TODOs referencing old pagination behaviour.
   - Record new helper responsibilities in the ongoing DataManager responsibility map if needed (no STATUS/README updates unless later requested).
