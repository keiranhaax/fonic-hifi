# Data, Persistence, and Import Instructions

These instructions extend the repository root guide for `Data/`.

## SwiftData Ownership

- Keep persistent mutations in `TrackDataActor` or the established repository layer. Views and feature services must not become independent persistence authorities.
- Pass identifiers or other `Sendable` values across actor boundaries rather than live persistent models.
- Preserve relationships and any scalar compatibility fields together where the current schema requires both.
- Never delete the user store, library, bookmarks, or imported media to recover from a persistence or migration failure.
- Durable track identity is `Track.id`, independent of absolute container paths, display metadata, and array position. Path repair (for example `ManagedMediaURLResolver`) updates the location in place and must preserve the existing ID, playlists, ratings, and history.

## Schemas and Shared Contracts

- A shipped schema change requires a new immutable `VersionedSchema` snapshot, an ordered migration stage, and a real prior-store-to-current-store migration test.
- Treat App Group identifiers, keys, and shared payload formats as persistent contracts. Coordinate migrations with the app, widget, and intents.
- CloudKit is currently disabled in the SwiftData configuration. Verify the live configuration before relying on that fact, and do not enable CloudKit or alter sync behavior without explicit scope, offline behavior design, migration tests, conflict handling, entitlement review, and production-schema safety.

## Import Pipeline

- Keep file discovery, copying, hashing, and metadata extraction off the main actor through the established import pipeline.
- Balance every successful `startAccessingSecurityScopedResource()` with `stopAccessingSecurityScopedResource()` on every exit path.
- Copy imported audio into the app container before persisting the copied URL.
- Preserve source bookmarks and hashes used for duplicate detection.
- Preserve bounded concurrency, cancellation, duplicate handling, partial-failure reporting, cleanup, and already-imported-file behavior.
- File existence is not validity: treat zero-byte, partial, or undecodable files as failures, and use the library-integrity fields on `Track` to mark unreachable files over consecutive checks instead of deleting user data.
- Import and scan triggers are idempotent; launch, foreground, and background triggers must not start overlapping workflows. Preserve the established in-progress guard pattern.

## Verification

- Test model actors, repositories, relationships, queries, duplicate detection, cancellation, partial failure, and cleanup with representative data.
- Schema work requires migration from a real prior-version store; a fresh in-memory container is not migration proof.
- Import work requires valid audio fixtures and the applicable security-scoped or file-provider scenario. Never use text files renamed with an audio extension.
