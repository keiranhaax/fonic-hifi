# DataManager Responsibility Map

| Domain | Responsibilities | Primary Dependencies |
| --- | --- | --- |
| Initialization & Fallback | Build SwiftData container, wire contexts and services, surface recovery metadata, provide preview/fallback factories | `SchemaV1`, `ModelContainer`, `TrackDataActor`, `MetadataExtractionService`, `LibraryImportService`, `AudioFormatDetectionManager` |
| Library Metrics & Pagination | Compute library statistics, paginate track/album fetches, batch retrieval for exports | `ModelContext`, `BatchProcessor<Track>`, `LibraryStatistics` |
| Search APIs | Query tracks, albums, artists, playlists (paginated and legacy limits) | `ModelContext`, `Predicate`, pagination helpers |
| Recent Search History | Persist, fetch, clear, and update recent search records | `RecentSearchesActor`, `RecentSearchData` |
| Recent Items | Supply recently added and recently played track lists | `ModelContext`, `Track` metadata |
| Cleanup Operations | Remove entries with missing files, log cleanup stats | `TrackDataActor`, `Logger` |
| Data Export | Produce JSON export snapshot for backup | `fetchAllTracksInBatches`, `LibraryExportData`, `JSONEncoder` |
