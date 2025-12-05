# ADR 001: Import URL Normalisation

- **Status**: Accepted (2025-10-10)
- **Decision Makers**: Audio/Data Platform Working Group
- **Context**: Duplicate imports were observed whenever users added the same audio file from different security-scoped bookmarks or alias paths, because existence checks compared only the sandbox-resolved URL stored in `Track.url`.[Verified-Code]

## Drivers

- SwiftData models need a deterministic identifier that survives bookmark changes and alias resolution at import time.[Inference]
- Security-scoped resources can present different URL instances for the same underlying file; without a stable hash we cannot safely deduplicate.[Inference]

## Decision

1. Persist both the absolute source URL string and a SHA-256 hash of the normalized path (`librarySourceHash()`) on the `Track` model via the new `sourceURLString`, `sourceURLHash`, and `sourceBookmarkHash` fields.[Verified-Code]
2. Extend `TrackDataActor.trackExists(for:bookmark:)` to compare against the normalized URL hash, stored bookmark hash, original absolute string, and the sandbox URL to avoid regressions when metadata was previously saved with older fields.[Verified-Code]
3. Require `FileImportProcessor` to forward the original external URL and optional bookmark data into `TrackMetadata`, ensuring the hashes are generated before enqueueing work on the actor.[Verified-Code]
4. Introduce migration helpers that backfill `sourceURLHash`/`sourceBookmarkHash` for existing records, enabling idempotent checks during subsequent imports.[Verified-Code]

## Consequences

- ✅ Duplicate import attempts now short-circuit once any of the stored hashes or original URL strings match, preventing redundant track creation while logging the existing identifier.[Verified-Code]
- ✅ Import telemetry is richer because we can correlate duplicates across distinct bookmark sessions without exposing full paths (hash-only storage satisfies privacy goals).[Verified-Code]
- ⚠️ Migration increases the Track model footprint slightly; SwiftData snapshots remain within acceptable size because hashes are capped at 64 hex characters.[Inference]
- ⚠️ Import pipelines must continue supplying source metadata; test utilities were updated to generate deterministic hashes for fixtures.[Verified-Code]

## Implementation Notes

- `TrackDataActor.createTrack(from:)` computes hashes when ingesting metadata and persists bookmark data when present.[Verified-Code]
- `FileImportProcessor.DiscoveredAudioFile` captures both the original URL and bookmark so the actor can evaluate all dedupe keys.[Verified-Code]
- Regression coverage lives in `ImportPipelineTests` and `ImportSessionTests`, both of which assert that re-importing security-scoped files returns the existing identifier.[Verified-Code]

## Alternatives Considered

- **Bookmark-only dedupe**: Rejected because Finder aliases and Files.app copies can produce new bookmarks for the same path.[Inference]
- **Filesystem inode queries**: Rejected to preserve sandbox compatibility and avoid additional security-scoped calls.[Inference]

## Follow-up Work

- Continue monitoring dedupe hit rates via `Metrics.increment(.importsFailed, metadata:)` logging when duplicate detections occur.[Verified-Code]
- Expand migration diagnostics to flag legacy records that still lack hashes (expected to be zero after the remedial backfill completes).[Inference]
