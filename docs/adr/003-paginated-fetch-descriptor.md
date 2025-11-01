# ADR 003: Paginated Fetch Descriptor

- **Status**: Accepted (2025-10-10)
- **Decision Makers**: Data Platform Working Group
- **Context**: SwiftData fetches were previously materialising entire result sets for library queries, leading to multi-second latency and memory spikes for collections above ~5,000 tracks.[Verified-Code]

## Drivers

- Library views require responsive pagination and must not block the main actor during large fetches.[Inference]
- Aggregate statistics (duration, size, counts) needed to run without reading full model instances into memory.[Inference]
- CI benchmarks mandated sub-500 ms fetch times for 10k-track libraries after Phase 3A.[Verified-Code]

## Decision

1. Introduce `PaginatedFetchDescriptor<T>` to wrap a base `FetchDescriptor` with page size metadata, exposing `page(_:)` and `count(in:)` helpers for reuse across repositories.[Verified-Code]
2. Add `ModelContext.batchedFetchCount` to iterate in fixed-size batches (default 512) so counts no longer materialise every record.[Verified-Code]
3. Implement `BatchProcessor` to process large datasets in chunks, enabling statistics aggregation and maintenance tasks to execute with constant memory usage.[Verified-Code]
4. Update `SwiftDataLibraryRepository` and `DataManager` fetch paths to rely on the paginated helpers, aligning UI pagination, statistics aggregation, and import maintenance on the same code path.[Verified-Code]

## Consequences

- ✅ Library pagination calls (`LibraryViewModel`, `LibraryImportService`) now fetch predictable slices, keeping aggregation runs under the 1.8 s ceiling enforced by `LibraryStatisticsPerformanceTests`.[Verified-Code]
- ✅ Aggregations within `LibraryStatisticsAggregator` reuse `BatchProcessor`, ensuring counts and totals respect the same pagination strategy.[Verified-Code]
- ✅ Test coverage in `LibraryStatisticsPerformanceTests` and pagination suites confirms fetches remain bounded under load.[Verified-Code]
- ⚠️ Developers must supply deterministic sorting to paginated descriptors; unsorted descriptors can yield duplicate rows across pages.[Inference]

## Implementation Notes

- Pagination helpers live under `Fonic HiFi/Data/Extensions/SwiftDataPagination.swift` and are imported where repositories need streaming access to data.[Verified-Code]
- `PaginatedFetchDescriptor.count(in:)` delegates to `batchedFetchCount`, which loops until a final partial batch signals completion.[Verified-Code]
- Benchmarks were updated to seed 10k synthetic tracks and assert totals using the new helpers.[Verified-Code]

## Alternatives Considered

- **Direct `ModelContext.fetchCount`**: Rejected because SwiftData lacks an optimised count API in iOS 26, forcing an eager fetch.[Inference]
- **Raw SQLite queries**: Rejected to avoid breaking SwiftData abstractions and future schema evolutions.[Inference]

## Follow-up Work

- Evaluate exposing the pagination helpers to SwiftUI view models directly once app-coverage work resumes.[Inference]
- Monitor SwiftData releases for native count APIs and retire `batchedFetchCount` when a more efficient alternative becomes available.[Inference]
