# Data, Library, Persistence, and Storage Audit

## Conclusion

**The active data path is not production-safe yet.** Static source establishes several release-relevant defects: a persistent-store open failure is silently converted into an in-memory store presented as the normal library; the live SwiftData schema omits `ListeningSession`; the one declared migration plan is attempted only after an unplanned open; listening-history wiring is never installed; import failures can leave copied audio behind; parallel imports can admit duplicate copies; startup recovery permanently deletes missing-file records; extracted ReplayGain and disc/track totals are discarded; and the exposed playlist UI has no production mutation path beyond creating an empty object.

The repository has useful foundations: `@ModelActor` is used for the primary SwiftData writers, metadata is transferred through `Sendable` values, security-scoped access is usually balanced, imported playback files are copied into the sandbox, the library screen has a repository/value-entity boundary, page fetches use limits, and widget artwork is stored under an App Group `Library/Caches` directory with a 50 MB cap. Those controls do not offset the findings below.

**Static-analysis boundary:** the audited Linux environment has no Xcode or Apple SDKs. I did not compile, migrate a real store, launch the app/widget, exercise a file provider, inspect an iOS backup, or profile a large library. Every stated runtime outcome or timing expectation is **UNVERIFIED — needs build/device check**. Static findings describe active control flow, schema membership, persistence calls, and reachable UI/data contracts. Prior logs, plans, READMEs, and audit artifacts were not used as proof.

### Skills loaded

- Axiom: Data & Persistence (including its storage, SwiftData, migration, and disk-management guidance)
- Axiom: Swift Concurrency
- Axiom: Testing
- Axiom: iOS Audit Agents (`swiftdata-auditor`, `storage-auditor`, and database-schema audit guidance)
- Relevant supporting guidance: Axiom Security & Privacy, Performance & Energy, and System Integration/Widgets

### Findings count

| Severity | Count |
|---|---:|
| Critical | 0 |
| High | 6 |
| Medium | 14 |
| Low | 0 |
| Informational | 1 |
| **Total** | **21** |

## Audit coverage

| Requested area | Static disposition |
|---|---|
| SwiftData schema and migrations | DLP-001, DLP-002, DLP-003 |
| Actors/concurrency | DLP-006, DLP-012, DLP-013, DLP-021 |
| Imports and security-scoped URLs | DLP-005, DLP-006, DLP-021; balanced-access candidate rejected below |
| Metadata extraction | DLP-008, DLP-009 |
| Deduplication | DLP-003, DLP-006 |
| Copy/move/delete semantics | DLP-005, DLP-007, DLP-021 |
| Playlists/history | DLP-004, DLP-010, DLP-015, DLP-017, DLP-019, DLP-020 |
| Search/pagination | DLP-012, DLP-014, DLP-015 |
| Cache/disk growth | DLP-005, DLP-016, DLP-017, DLP-018 |
| Backup exclusion | DLP-018; widget cache placement is appropriate |
| Missing-file recovery | DLP-007 |
| Large-library behavior | DLP-007, DLP-012, DLP-013, DLP-014 |
| Repository boundaries | DLP-010, DLP-011, DLP-014 |
| Widget shared data | DLP-016 |

## Findings table

| ID | Severity | Confidence | Summary |
|---|---|---|---|
| DLP-001 | High | Confirmed by static evidence | A persistent-store failure becomes a read-only in-memory store presented as normal, so mutations fail or appear ephemeral |
| DLP-002 | High | Confirmed by static evidence | `ListeningSession` is queried and inserted but is absent from every live/fallback schema |
| DLP-003 | High | Probable | Production opens without the migration plan first, bypassing the declared V1→V2 migration path |
| DLP-004 | High | Confirmed by static evidence | Listening-session tracking is implemented but never configured in any app service graph |
| DLP-005 | High | Confirmed by static evidence | A failure after copying an import leaves the copied audio file orphaned on disk |
| DLP-006 | Medium | Confirmed by static evidence | Batch deduplication is check-then-act and races across concurrent imports |
| DLP-007 | High | Confirmed by static evidence | Startup “recovery” permanently deletes records for temporarily unavailable files and leaves empty album/artist rows |
| DLP-008 | Medium | Confirmed by static evidence | ReplayGain is extracted, then dropped before the `Track` is persisted |
| DLP-009 | Medium | Confirmed by static evidence | iTunes track/disc number offsets are wrong, and parsed totals never enter persisted metadata |
| DLP-010 | Medium | Confirmed by static evidence | The exposed playlist feature can only create empty playlists; smart rules and track membership have no active mutation boundary |
| DLP-011 | Medium | Confirmed by static evidence | Repository-backed library pages do not observe imports or playlist writes and can remain stale on screen |
| DLP-012 | Medium | Confirmed by static evidence | Every repository page can rescan and materialize the whole matching table just to compute `totalCount` |
| DLP-013 | Medium | Probable | Album/artist page mapping dereferences to-many relationships per row, creating relationship fan-out at page load |
| DLP-014 | Medium | Confirmed by static evidence | The Search tab bypasses the repository, runs four serial main-context queries, caps results, and provides no working continuation |
| DLP-015 | Medium | Confirmed by static evidence | Repeating a recent search inserts duplicate rows that the UI identifies with the same key |
| DLP-016 | Medium | Confirmed by static evidence | Widget playback snapshots discard progress-only updates and ignore their own stale-state signal |
| DLP-017 | Medium | Confirmed by static evidence | Listening sessions have no retention or pruning policy and will grow without bound once history is enabled |
| DLP-018 | Informational | UNVERIFIED — needs build/device check | Imported music backup policy is implicit; release acceptance has no explicit backup-size decision or device verification |
| DLP-019 | Medium | Confirmed by static evidence | Track transitions either omit the next session or race and clear the replacement session |
| DLP-020 | Medium | Confirmed by static evidence | Listening duration is set to playback position, so seeks and restored positions corrupt history/play counts |
| DLP-021 | Medium | Confirmed by static evidence | Cancelling the public import task does not cancel the unstructured processing producer |

---

## Full findings

### DLP-001 — Persistent-store failure is masked by a normal-mode in-memory store

- **Severity:** High
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Data/DataManager+Initialization.swift:128-179`
    > `let container = try ModelContainer(`
    > `for: schema,`
    > `configurations: [configuration]`
    > `)`
    > `...`
    > `let minimalConfig = ModelConfiguration(`
    > `isStoredInMemoryOnly: true,`
    > `allowsSave: false,`
    > `...`
    > `return container`
  - `Fonic HiFi/Data/DataManager+Initialization.swift:51-75`
    > `let container = try Self.buildContainer(...)`
    > `self.init(container: container, isFallback: false)`
  - `Fonic HiFi/Data/Services/LibraryImportService.swift:72-100`
    > `guard !isImporting else { ... }`
    > `...`
    > `isImporting = true`
    > `...`
    > `await executeImportPipeline(urls: urls)`
- **Why this is defective/risky:** `buildContainer` does not signal that its returned container is the fourth-attempt, in-memory, `allowsSave: false` store. The convenience initializer therefore labels it `isFallback: false`; the app exposes its normal import controls; and `TrackDataActor.createTrack` later attempts saves. Depending on SwiftData behavior, users either receive per-file save failures after audio copies have already been made (DLP-005), or interact with an ephemeral store whose contents cannot survive process termination. The exact device error is **UNVERIFIED — needs build/device check**, but the recovery-state loss is statically certain.
- **Preserving remediation:** Keep the existing recovery UI, but never return a fallback container as if it were the primary persistent store. Split primary open from fallback construction. If persistent open fails, return an explicitly typed recovery result and disable all mutating controls. Do not auto-delete the store.
- **Paste-ready sample (requires Xcode validation):**

```swift
private enum ContainerResolution {
    case persistent(ModelContainer)
    case readOnlyRecovery(ModelContainer)
}

private static func buildPersistentContainer(
    schema: Schema,
    configuration: ModelConfiguration
) throws -> ModelContainer {
    try ModelContainer(
        for: schema,
        migrationPlan: LibraryMigrationPlan.self,
        configurations: [configuration]
    )
}

convenience init() throws {
    Self.ensureAppGroupDirectoriesExist()
    let schema = Schema(SchemaV3.models)
    let configuration = ModelConfiguration(
        isStoredInMemoryOnly: false,
        allowsSave: true,
        groupContainer: .identifier(WidgetConstants.appGroupIdentifier),
        cloudKitDatabase: .none
    )
    let container = try Self.buildPersistentContainer(
        schema: schema,
        configuration: configuration
    )
    self.init(container: container, isFallback: false)
}
```

Construct the existing in-memory manager only in `makeFallbackDataManager()`, mark it `isFallback: true`, and make `LibraryImportService` unavailable while `ImportRecoveryMode` is `.readOnly` or `.ephemeralStorage`.
- **Verification / acceptance criteria:**
  1. A deliberately incompatible/corrupt test store does not open the normal library UI as writable.
  2. Import, playlist creation, favorites, and history writes are disabled in recovery mode with clear guidance.
  3. Restarting after the storage issue is fixed reopens the untouched persistent store.
  4. No fallback path deletes, replaces, or renames the production store automatically.
  5. Validate on a device under low disk and protected-data-unavailable conditions; outcome is **UNVERIFIED — needs build/device check**.
- **Related:** DLP-002, DLP-003, DLP-005, DLP-007.

### DLP-002 — `ListeningSession` is absent from the schema that its actor uses

- **Severity:** High
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Data/Migration/RecentSearchMigrationPlan.swift:146-158`
    > `static var models: [any PersistentModel.Type] {`
    > `[ Track.self, Artist.self, Album.self, Playlist.self, RecentSearch.self ]`
  - `Fonic HiFi/Data/DataManager+Initialization.swift:43-49`
    > `let schema = Schema(SchemaV2.models)`
  - `Fonic HiFi/Data/Actors/TrackDataActor.swift:787-819`
    > `let session = ListeningSession(...)`
    > `modelContext.insert(session)`
    > `...`
    > `let sessions = try modelContext.fetch(descriptor)`
  - `Fonic HiFi/Data/DataManager+Initialization.swift:189-203,309-323,347-360`
    > `Track.self, Artist.self, Album.self, Playlist.self, RecentSearch.self`
- **Why this is defective/risky:** The production, preview, writable fallback, and read-only fallback schemas all omit a model that live code inserts and fetches. Home calls `getContinueListeningTracks`, which calls this fetch. Once session tracking is wired (DLP-004), persistence also uses the missing entity. The exact SwiftData exception/diagnostic is **UNVERIFIED — needs build/device check**, but schema membership is definitively inconsistent.
- **Preserving remediation:** Introduce a new versioned schema rather than silently editing V2, register `ListeningSession`, and migrate V2→V3. Use the same schema list for primary, preview, and fallback containers.
- **Paste-ready sample (migration behavior requires Xcode validation):**

```swift
enum SchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Track.self,
            Artist.self,
            Album.self,
            Playlist.self,
            RecentSearch.self,
            ListeningSession.self
        ]
    }
}

enum LibraryMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self)
        ]
    }
}
```

- **Verification / acceptance criteria:**
  1. `SchemaV3.models` is the single source used by all app/test/fallback containers.
  2. An on-disk V2 fixture opens as V3 and preserves all tracks/playlists.
  3. Inserting, saving, fetching, and relaunching a `ListeningSession` succeeds.
  4. Home history APIs return an empty array—not an error—before the first session.
  5. Validate migration and store files on simulator/device; result is **UNVERIFIED — needs build/device check**.
- **Related:** DLP-003, DLP-004, DLP-017.

### DLP-003 — The declared migration plan is only a fallback after an unplanned open

- **Severity:** High
- **Confidence:** Probable
- **Evidence:**
  - `Fonic HiFi/Data/DataManager+Initialization.swift:128-150`
    > `logger.info("Creating container without migration plan")`
    > `let container = try ModelContainer(for: schema, configurations: [configuration])`
    > `...`
    > `logger.info("Attempting fallback container with migration plan")`
  - `Fonic HiFi/Data/Migration/RecentSearchMigrationPlan.swift:167-200`
    > `.custom(fromVersion: SchemaV1.self, toVersion: SchemaV2.self,`
    > `willMigrate: { context in`
    > `try migrateTrackBookmarkHashes(in: context)`
    > `})`
    > `...`
    > `let fetchDescriptor = FetchDescriptor<Track>()`
  - `Fonic HiFiTests/MigrationPlanTests.swift:16-41`
    > `let container = try ModelContainer(for: schema, configurations: [configuration])`
    > `...`
    > `try RecentSearchMigrationPlan.migrateTrackBookmarkHashes(in: context)`
- **Why this is defective/risky:** The normal production open never supplies the plan. If SwiftData can infer a lightweight migration, it may open successfully and the custom hash backfill will never run; if it cannot, only then is the plan tried. The custom `willMigrate` closure also fetches the destination `Track` type while the source schema is active, a migration-phase compatibility risk. The test never migrates a V1 store—it invokes a helper directly against V2—so it cannot validate either condition. Exact migration behavior is **UNVERIFIED — needs build/device check**.
- **Preserving remediation:** Always open a versioned store with one authoritative migration plan. Keep structural migration in migration stages; perform optional derived-field backfills after a successful open through `TrackDataActor`, in bounded batches, with an idempotent durable marker.
- **Paste-ready sample (requires a real V1 fixture):**

```swift
let container = try ModelContainer(
    for: Schema(SchemaV3.models),
    migrationPlan: LibraryMigrationPlan.self,
    configurations: [configuration]
)

// After the versioned store has opened successfully:
Task(priority: .utility) {
    try await dataManager.trackDataActor.backfillSourceHashes(batchSize: 250)
}
```

Do not retry an unplanned open first, and do not use an in-memory store to represent migration success.
- **Verification / acceptance criteria:**
  1. Create a V1 store with tracks, bookmarks, playlists, relationships, favorites, and play counts using the V1 schema.
  2. Open it only through the production V3 configuration and migration plan.
  3. Assert record counts, IDs, relationships, and user data are unchanged.
  4. Assert source hashes are eventually populated and rerunning the backfill is a no-op.
  5. Interrupt the backfill mid-batch and verify safe resume.
  6. This full migration is **UNVERIFIED — needs build/device check**.
- **Related:** DLP-001, DLP-002, TRV-010 in the testing audit.

### DLP-004 — Listening history is never wired into the production audio service

- **Severity:** High
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:202-208`
    > `public func configureSessionTracking(dataActor: TrackDataActor) {`
    > `self.sessionService = ListeningSessionService(dataActor: dataActor)`
  - `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:331-341`
    > `try await playbackController.play(track: track)`
    > `...`
    > `sessionService?.startSession(trackId: track.id, duration: duration)`
  - `Fonic HiFi/FonicHiFiApp.swift:318-347`
    > `let audioService = AudioEngineFacade(...)`
    > `let importService = LibraryImportService(...)`
    > `...`
    > `return AppServices(...)`
  - Repository-wide active-source search found no call to `configureSessionTracking` outside its declaration.
- **Why this is defective/risky:** `sessionService` remains `nil`; optional start/end calls are no-ops; `recordListeningSession` and `incrementPlayCount` are never reached. Continue Listening, Recently Played, Most Listened, Rediscover, time-based recommendations, and persisted play counts therefore have no production data source. Runtime UI behavior is **UNVERIFIED — needs build/device check**, but the missing dependency wiring is static and unconditional.
- **Preserving remediation:** Configure the existing service in every service graph immediately after constructing `AudioEngineFacade`. Apply DLP-002 first so the model is registered.
- **Paste-ready sample:**

```swift
let audioService = AudioEngineFacade(
    stateManager: playbackStateManager,
    queueManager: queueManager,
    monitor: audioMonitor
)
audioService.configureSessionTracking(dataActor: dataManager.trackDataActor)
```

Apply the same wiring to preview/fallback graphs only when their schema supports `ListeningSession` and the store allows saves.
- **Verification / acceptance criteria:**
  1. Play more than 50% of one track, stop, and assert one session plus a play-count increment.
  2. Skip before 10 seconds and assert no session; skip after 10 seconds and assert one skipped session.
  3. Relaunch and verify Recently Played/Continue Listening are derived from persisted data.
  4. Verify auto-advance and manual next start a new session for the next track.
  5. Run on a device; the full playback lifecycle is **UNVERIFIED — needs build/device check**.
- **Related:** DLP-002, DLP-017.

### DLP-005 — Import failure after copy leaks managed audio files

- **Severity:** High
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Data/Actors/FileImportProcessor.swift:603-635`
    > `let copiedFileURL = try copyFile(...)`
    > `let trackMetadata = try await metadataExtractor.extractTrackMetadata(from: copiedFileURL)`
    > `...`
    > `return try await trackDataActor.createTrack(from: enrichedMetadata)`
  - `Fonic HiFi/Data/Actors/FileImportProcessor.swift:393-408`
    > `catch {`
    > `...`
    > `return ProcessedFileResult(... identifier: nil, error: ...)`
  - `Fonic HiFi/Data/Actors/FileImportProcessor.swift:669-695`
    > `try fileManager.copyItem(at: sourceURL, to: destinationURL)`
    > `return destinationURL`
- **Why this is defective/risky:** Metadata extraction, cancellation, relationship creation, or SwiftData save can throw after a potentially multi-gigabyte file has been copied into `Documents/Music`. The catch converts the operation to a failed result but never removes the copy. Repeated malformed imports or low-disk failures grow disk usage with files absent from the library database. This execution path is static; exact filesystem behavior is **UNVERIFIED — needs build/device check**.
- **Preserving remediation:** Treat copy + metadata + database insert as a compensating transaction. Delete only the just-created destination when downstream work fails; never delete the source. Keep deletion failure visible in structured logs/metrics.
- **Paste-ready sample:**

```swift
let copiedFileURL = try copyFile(
    from: resolvedURL,
    to: baseDirectory,
    logger: logger
)

do {
    try Task.checkCancellation()
    let metadata = try await metadataExtractor.extractTrackMetadata(from: copiedFileURL)
    let enriched = metadata.withSourceInfo(
        sourceURL: file.originalURL,
        sourceBookmark: file.securityScopedBookmark
    )
    return try await trackDataActor.createTrack(from: enriched)
} catch {
    do {
        try FileManager.default.removeItem(at: copiedFileURL)
    } catch let cleanupError {
        logger.error("Import rollback failed: \(cleanupError.localizedDescription, privacy: .public)")
    }
    throw error
}
```

- **Verification / acceptance criteria:**
  1. Force metadata failure after copy; `Documents/Music` returns to its pre-import contents.
  2. Force SwiftData save failure after metadata; no copy remains and no track row exists.
  3. Cancel each import phase and assert source preservation plus no destination orphan.
  4. Inject cleanup failure and assert it is reported distinctly.
  5. Measure on device with a large file; result is **UNVERIFIED — needs build/device check**.
- **Related:** DLP-001, DLP-006, DLP-018.

### DLP-006 — Concurrent deduplication is not an atomic claim

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Data/Actors/FileImportProcessor.swift:276-303`
    > `for _ in 0..<concurrency {`
    > `let currentCache = hashCache`
    > `group.addTask { ... hashCache: currentCache ... }`
    > `}`
    > `...`
    > `if result.succeeded { hashCache.addEntry(...) }`
  - `Fonic HiFi/Data/Actors/FileImportProcessor.swift:363-385`
    > `if hashCache.contains(...) { ... }`
    > `...`
    > `let identifier = try await Self.importFile(...)`
  - `Fonic HiFi/Data/Actors/FileImportProcessor.swift:617-634`
    > `if try await trackDataActor.trackExists(...) != nil { ... }`
    > `let copiedFileURL = try copyFile(...)`
    > `...`
    > `return try await trackDataActor.createTrack(...)`
- **Why this is defective/risky:** Initial child tasks receive the same cache snapshot. Two identical URLs in the same selection can both miss the cache, serialize through `trackExists` before either inserts, copy twice, and create two rows. No `@Attribute(.unique)` or atomic source claim closes the check-to-insert window. Exact reproduction is **UNVERIFIED — needs build/device check**, but the race window exists in active source.
- **Preserving remediation:** Add a batch-local actor that atomically claims a canonical source identity before copy; retain the claim on success and release on failure. Keep the database check as defense in depth. A durable unique source identity should be considered in the next schema version if imports can originate from more than one service/process.
- **Paste-ready sample:**

```swift
private actor ImportSourceClaims {
    private var claimed = Set<String>()

    func claim(_ key: String) -> Bool {
        claimed.insert(key).inserted
    }

    func release(_ key: String) {
        claimed.remove(key)
    }
}

private static func sourceKey(for file: DiscoveredAudioFile) -> String {
    if let bookmark = file.securityScopedBookmark {
        return "bookmark:" + bookmark.sha256Hex()
    }
    return "url:" + file.originalURL.librarySourceHash()
}
```

Pass one `ImportSourceClaims` instance to every child. Before `importFile`, `guard await claims.claim(key) else { return duplicateResult }`; on failure call `await claims.release(key)`, and on success retain it until the batch ends.
- **Verification / acceptance criteria:**
  1. Import 100 references to one URL at concurrency 4; exactly one row and one managed copy result.
  2. Repeat with equivalent normalized URLs and equal bookmarks.
  3. Force the claimed import to fail; a later retry can claim and succeed.
  4. Start two public import requests; the service still prevents overlapping sessions.
  5. Run with Thread Sanitizer and on device; concurrency outcome is **UNVERIFIED — needs build/device check**.
- **Related:** DLP-003, DLP-005.

### DLP-007 — Startup cleanup converts temporary unavailability into permanent library deletion

- **Severity:** High
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/FonicHiFiApp.swift:198-208`
    > `try? await Task.sleep(for: .seconds(3))`
    > `let removedCount = try await dataManager.cleanupMissingFiles()`
  - `Fonic HiFi/Data/Actors/TrackDataActor.swift:687-705`
    > `let fetchDescriptor = FetchDescriptor<Track>()`
    > `let tracks = try modelContext.fetch(fetchDescriptor)`
    > `for track in tracks {`
    > `if !FileManager.default.fileExists(atPath: track.url.path) {`
    > `modelContext.delete(track)`
    > `}`
    > `}`
    > `try modelContext.save()`
  - `Fonic HiFi/Data/Models/Album.swift:118-124` and `Fonic HiFi/Data/Models/Artist.swift:58-64`
    > `@Relationship(deleteRule: .nullify, inverse: \Track.albumRelation)`
    > `@Relationship(deleteRule: .nullify, inverse: \Track.artistRelation)`
- **Why this is defective/risky:** Three seconds after launch, one transient `fileExists == false` permanently deletes track metadata, favorites, play counts, playlist links, and history discoverability. There is no retry, protected-data check, file-provider coordination, missing-state quarantine, or source-bookmark repair. Deleting the track nullifies relationships but does not delete now-empty Album/Artist objects, so ghost rows and inflated statistics can remain. The imported managed files should normally exist, but low-disk/file-provider/protection behavior is **UNVERIFIED — needs build/device check**; the destructive one-sample policy is confirmed.
- **Preserving remediation:** Replace destructive launch cleanup with reconciliation. Mark/surface missing records, retry after protected data is available, offer relink/restore from the source bookmark, and delete only after explicit user confirmation. When an explicit delete occurs, prune empty albums/artists in the same actor transaction.
- **Paste-ready safe first step:**

```swift
public func missingTrackIDs() throws -> [UUID] {
    var descriptor = FetchDescriptor<Track>(
        sortBy: [SortDescriptor(\Track.id)]
    )
    descriptor.fetchLimit = 500

    return try modelContext.fetch(descriptor).compactMap { track in
        FileManager.default.fileExists(atPath: track.url.path) ? nil : track.id
    }
}
```

Call this as diagnostics only; do not delete. A production implementation should add versioned fields such as `missingSince`/`availabilityState`, scan in batches, and provide explicit recovery actions.
- **Verification / acceptance criteria:**
  1. Simulate protected data unavailable at launch; no track/playlist/history row is deleted.
  2. Temporarily hide a managed file, then restore it; the same track ID and user data recover.
  3. Explicitly delete one track and verify its managed file, row, playlist references, and empty album/artist cleanup are consistent.
  4. Scan 10k/50k tracks without a launch hang or full-table memory spike.
  5. Validate File Provider and device-lock behavior; **UNVERIFIED — needs build/device check**.
- **Related:** DLP-001, DLP-005, DLP-010, DLP-013.

### DLP-008 — ReplayGain metadata is extracted and then discarded

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Data/Services/MetadataExtractionService.swift:82-109`
    > `let replayGain = extractReplayGain(from: metadata)`
    > `...`
    > `replayGainTrack: replayGain.track,`
    > `replayGainAlbum: replayGain.album`
  - `Fonic HiFi/Data/Actors/TrackDataActor.swift:79-101`
    > `private func applyTrackMetadata(_ metadata: TrackMetadata, to track: Track) {`
    > `...`
    > `track.bitrate = metadata.bitrate`
    > `track.sourceURLBookmark = metadata.sourceBookmark`
    > `...`
    > `}`
  - `Fonic HiFi/Core/Audio/Engine/PlaybackController.swift:252-262`
    > `await engine.applyReplayGain(gain)`
    > `...`
    > `track.replayGainTrack ?? 0`
    > `track.replayGainAlbum ?? track.replayGainTrack ?? 0`
- **Why this is defective/risky:** `TrackMetadata` carries both gain values, but `applyTrackMetadata` never copies them into `Track`. Imported tracks therefore persist `nil`; track/album ReplayGain modes apply 0 dB even when tags were extracted. Audible output is **UNVERIFIED — needs build/device check**, but the lost assignment is static.
- **Preserving remediation:** Copy the existing fields during the existing mapping; no architecture change is needed.
- **Paste-ready sample:**

```swift
private func applyTrackMetadata(_ metadata: TrackMetadata, to track: Track) {
    // Existing assignments...
    track.bitrate = metadata.bitrate
    track.replayGainTrack = metadata.replayGainTrack
    track.replayGainAlbum = metadata.replayGainAlbum
    // Existing source assignments...
}
```

- **Verification / acceptance criteria:**
  1. Import fixtures with track-only, album-only, both, positive, and negative gain tags.
  2. Fetch after save/relaunch and assert exact persisted values.
  3. Track mode prefers track gain; album mode prefers album then track gain.
  4. Untagged tracks remain 0 dB.
  5. Verify engine gain on device/an offline render; audible behavior is **UNVERIFIED — needs build/device check**.
- **Related:** DLP-009.

### DLP-009 — Track/disc tuple parsing uses wrong offsets and drops parsed totals

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Data/Services/MetadataExtractionService.swift:275-287`
    > `values.trackNumber = extractTrackNumber(from: data)`
    > `values.trackCount = extractTrackCount(from: data)`
    > `...`
    > `values.discNumber = extractDiscNumber(from: data)`
    > `values.discCount = extractDiscCount(from: data)`
  - `Fonic HiFi/Data/Services/MetadataExtractionService.swift:327-348`
    > `load(fromByteOffset: 6, as: UInt16.self)`
    > `load(fromByteOffset: 4, as: UInt16.self)`
    > `load(fromByteOffset: 2, as: UInt16.self)`
    > `load(fromByteOffset: 0, as: UInt16.self)`
  - `Fonic HiFi/Data/Actors/TrackDataActor.swift:1053-1081`
    > `public let trackNumber: Int?`
    > `public let discNumber: Int?`
    > *(no total-track or total-disc field)*
  - `Fonic HiFi/Data/Models/Track.swift:71-81`
    > `public var trackNumber: Int?`
    > `public var totalTracks: Int?`
    > `public var discNumber: Int?`
    > `public var totalDiscs: Int?`
- **Why this is defective/risky:** Standard iTunes `trkn`/`disk` tuples place the item number after a two-byte reserved field and the total after it. The code reads the track number at byte 6 (reserved tail) and disc total at byte 0 (reserved head). It then parses totals into `MetadataValues` but `TrackMetadata` cannot carry them, so the persisted model never receives them. Album ordering/completeness can be wrong. Actual tag layouts across formats are **UNVERIFIED — needs build/device check**.
- **Preserving remediation:** Centralize bounds-checked, unaligned big-endian reads; use offsets 2 and 4 for number/total; extend `TrackMetadata` with `totalTracks` and `totalDiscs`; and assign both in `applyTrackMetadata`.
- **Paste-ready parser:**

```swift
private func bigEndianUInt16(in data: Data, at offset: Int) -> Int? {
    guard offset >= 0, data.count >= offset + MemoryLayout<UInt16>.size else {
        return nil
    }
    let value = data.withUnsafeBytes { bytes in
        bytes.loadUnaligned(fromByteOffset: offset, as: UInt16.self).bigEndian
    }
    return value == 0 ? nil : Int(value)
}

private func extractTrackNumber(from data: Data) -> Int? {
    bigEndianUInt16(in: data, at: 2)
}

private func extractTrackCount(from data: Data) -> Int? {
    bigEndianUInt16(in: data, at: 4)
}

private func extractDiscNumber(from data: Data) -> Int? {
    bigEndianUInt16(in: data, at: 2)
}

private func extractDiscCount(from data: Data) -> Int? {
    bigEndianUInt16(in: data, at: 4)
}
```

- **Verification / acceptance criteria:**
  1. Unit-test byte tuples for `3/12` and disc `2/3`, zero/missing values, short data, and unaligned buffers.
  2. Import tagged M4A/ALAC fixtures and assert all four fields after relaunch.
  3. Verify FLAC/Vorbis and ID3 text-number paths separately rather than assuming iTunes binary tuples.
  4. Album ordering and completeness reflect persisted totals.
  5. Real-file extraction is **UNVERIFIED — needs build/device check**.
- **Related:** DLP-008.

### DLP-010 — The exposed playlist feature has no complete mutation path

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Presentation/Views/Library/LibraryView.swift:93-99,125-138`
    > `Button(action: primaryToolbarAction)`
    > `...`
    > `.sheet(isPresented: $showingCreatePlaylist) { CreatePlaylistView() }`
    > `...`
    > `PlaylistEntityDetailView(playlist: playlist)`
  - `Fonic HiFi/Presentation/Views/Library/PlaylistListView.swift:456-511`
    > `Toggle("Smart Playlist", isOn: $isSmartPlaylist)`
    > `...`
    > `let playlist = Playlist(...)`
    > `modelContext.insert(playlist)`
    > `dismiss()`
  - `Fonic HiFi/Domain/Repositories/LibraryRepository.swift:28-35`
    > `func playlists(page: Int, pageSize: Int, searchQuery: String?) ...`
    > *(read methods only)*
  - Active-source search found no production call to `Playlist.addTrack`, `Playlist.addTracks`, or `Playlist.addSmartFilter`; the latter calls are only built-in constructors inside `Playlist.swift`.
- **Why this is defective/risky:** Users can create a static or “Smart Playlist,” but the active repository has no create/update/delete/membership methods, the create view does not save/report errors, there is no rule editor, no add-track path, and the active detail view only renders name/count. The feature therefore creates empty records that cannot fulfill the promise shown in the UI. This is a missing-feature finding because the current product UI explicitly exposes and describes it.
- **Preserving remediation:** Keep the current screens and model, but put playlist mutations behind `LibraryRepository` using UUID/value inputs. Save explicitly, return errors, refresh repository pages, and temporarily hide/disable the Smart toggle until a rule editor and evaluator are connected. Choose one canonical membership representation (`trackIds` for order or the relationship) and update it transactionally rather than maintaining divergent arrays.
- **Paste-ready boundary sketch:**

```swift
public protocol LibraryRepository: Sendable {
    // Existing reads...
    func createPlaylist(name: String, description: String?) async throws -> UUID
    func addTracks(_ trackIDs: [UUID], to playlistID: UUID) async throws
    func removeTrack(_ trackID: UUID, from playlistID: UUID) async throws
    func deletePlaylist(id: UUID) async throws
}
```

In `SwiftDataLibraryRepository`, fetch by UUID in its private context, mutate `trackIds`, set `dateModified`, and `try context.save()`; do not pass `Playlist`/`Track` models across the actor boundary.
- **Verification / acceptance criteria:**
  1. Create, error, duplicate-name policy, rename, delete, and relaunch are tested on an on-disk store.
  2. Add/reorder/remove tracks and verify order plus count after relaunch.
  3. Deleting a track removes/drops stale playlist IDs according to a documented rule.
  4. Smart rules are editable and produce bounded/paged results, or the Smart UI is absent until ready.
  5. UI behavior is **UNVERIFIED — needs build/device check**.
- **Related:** DLP-007, DLP-011, DLP-013.

### DLP-011 — Repository-backed library state is not refreshed after writes

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Presentation/ViewModels/Library/LibraryViewModel.swift:25-44,66-90`
    > `@Published private(set) var tracks...`
    > `private var trackState = PaginationState...`
    > `func refresh(section: Section, query: String?) async`
    > `guard statistics == nil else { return }`
  - `Fonic HiFi/Presentation/Views/Library/LibraryView.swift:156-178`
    > `.onChange(of: importService?.isImporting) { _, isImporting in`
    > `if isImporting == true { ... }`
    > `}`
    > `.task { await ensureInitialLoad() }`
  - `Fonic HiFi/Presentation/Views/Library/PlaylistListView.swift:503-511`
    > `modelContext.insert(playlist)`
    > `dismiss()`
- **Why this is defective/risky:** `LibraryViewModel` stores value snapshots from fresh repository contexts. It has no SwiftData observation, mutation event, pull-to-refresh, or import-completion refresh. The view only reacts when import starts, not when it ends, and playlist creation dismisses without notifying it. Newly imported tracks/albums/artists and new playlists can remain absent until a tab/query refresh or view reconstruction; `statistics` is load-once. Exact SwiftUI lifecycle behavior is **UNVERIFIED — needs build/device check**, but no explicit refresh path exists.
- **Preserving remediation:** Keep the repository/value boundary and add a small mutation notification/revision stream. Emit once after a committed import batch and every playlist mutation; reset the relevant pagination state and statistics cache when received.
- **Paste-ready minimal bridge:**

```swift
extension Notification.Name {
    static let libraryDidChange = Notification.Name("library.didChange")
}

// After a committed mutation:
NotificationCenter.default.post(name: .libraryDidChange, object: nil)

// In LibraryView:
.onReceive(NotificationCenter.default.publisher(for: .libraryDidChange)) { _ in
    Task { @MainActor in
        await viewModel.refresh(section: selectedTab.section, query: normalized(searchText))
        await viewModel.reloadStatistics()
    }
}
```

Prefer an injected `AsyncStream<LibraryRevision>` over global notification in a later cleanup; the sample is a small architecture-preserving fix.
- **Verification / acceptance criteria:**
  1. Finish an import while Library is visible; committed rows appear without switching tabs.
  2. Create/delete a playlist; the page updates exactly once.
  3. Statistics update after import/delete/favorite changes.
  4. Failed/cancelled imports do not emit a committed revision.
  5. Verify SwiftUI behavior on device; **UNVERIFIED — needs build/device check**.
- **Related:** DLP-005, DLP-010, DLP-012.

### DLP-012 — Pagination computes counts by hydrating every matching model on every page

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Data/Repositories/SwiftDataLibraryRepository.swift:43-49,65-71,97-103,127-133`
    > `includeTotalCount: true`
    > `let result = try fetch.execute(in: context)`
  - `Fonic HiFi/Data/Repositories/PaginatedFetch.swift:27-29`
    > `let totalCount: Int? = if includeTotalCount {`
    > `try context.batchedFetchCount(descriptor.removingPagination())`
  - `Fonic HiFi/Data/Extensions/SwiftDataPagination.swift:61-81`
    > `while true {`
    > `let batch = try fetch(countingDescriptor)`
    > `total += batch.count`
    > `...`
    > `offset += batch.count`
    > `}`
- **Why this is defective/risky:** Each page request performs its limited page fetch and then repeatedly fetches full model objects for the entire result set merely to count them. Loading 100 pages can rescan the same table 100 times; offset cost can also rise with depth. This defeats the repository’s stated large-library purpose and can increase memory/CPU/latency. Exact thresholds are **UNVERIFIED — needs build/device check**.
- **Preserving remediation:** Use SwiftData’s store-side count API and request total count only when the UI needs it (the current `LibraryViewModel` does not consume it). Keep the existing `Page` contract.
- **Paste-ready sample (API availability requires Xcode validation):**

```swift
public extension ModelContext {
    func efficientFetchCount<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>
    ) throws -> Int {
        var countDescriptor = descriptor
        countDescriptor.fetchLimit = nil
        countDescriptor.fetchOffset = nil
        return try fetchCount(countDescriptor)
    }
}
```

Then replace `batchedFetchCount` and set `includeTotalCount: page == 0` or `false` where unused.
- **Verification / acceptance criteria:**
  1. 50k-row page 0 and deep-page tests return correct items/`hasMore`/count.
  2. SQL/Core Data instrumentation shows a count query, not hydrated batches.
  3. Page 2+ does not recompute an unused total.
  4. Record wall time, allocations, and main-thread stalls on device; performance is **UNVERIFIED — needs build/device check**.
- **Related:** DLP-011, DLP-013, DLP-014.

### DLP-013 — Page mapping dereferences to-many relationships per album/artist

- **Severity:** Medium
- **Confidence:** Probable
- **Evidence:**
  - `Fonic HiFi/Data/Repositories/SwiftDataLibraryRepository.swift:72-83`
    > `let mapped = result.items.map { album in`
    > `...`
    > `trackCount: album.trackCount`
  - `Fonic HiFi/Data/Models/Album.swift:158-161`
    > `public var trackCount: Int { tracks.count }`
  - `Fonic HiFi/Data/Repositories/SwiftDataLibraryRepository.swift:104-113`
    > `albumCount: artist.albumCount,`
    > `trackCount: artist.trackCount`
  - `Fonic HiFi/Data/Models/Artist.swift:68-80`
    > `tracks.count`
    > `albums.count`
    > `tracks.reduce(0) { ... }`
- **Why this is defective/risky:** Mapping each parent page touches to-many relationships to compute counts. Depending on SwiftData fault behavior, this can issue per-row fetches or hydrate many child models, producing N+1/fan-out behavior and undermining page-size memory bounds. The query/fault count is **UNVERIFIED — needs build/device check**, so confidence is Probable rather than confirmed runtime impact.
- **Preserving remediation:** Do not resolve full relationships while mapping list summaries. Add versioned, transactionally maintained aggregate counts on Album/Artist, or perform bounded aggregate/count queries and join by parent ID. Keep full relationships for detail screens only.
- **Safe code direction:**

```swift
// Versioned fields maintained when linking/unlinking tracks.
public var cachedTrackCount: Int
public var cachedAlbumCount: Int

// Page mapping reads scalar columns only.
trackCount: album.cachedTrackCount
```

Backfill counts idempotently after migration and update them in the same `TrackDataActor` save as relationship changes. This schema sample requires Xcode migration validation.
- **Verification / acceptance criteria:**
  1. Import/delete/relink updates cached counts atomically.
  2. A migration backfills exact values and is restart-safe.
  3. Fetching 100 albums/artists does not fault all child tracks.
  4. Instruments/SQL debug confirms bounded queries and memory; **UNVERIFIED — needs build/device check**.
- **Related:** DLP-007, DLP-010, DLP-012.

### DLP-014 — Search bypasses the repository and silently truncates results

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Presentation/Views/Search/SearchView.swift:155-167`
    > `let tracks = try await dataManager.searchTracks(query)`
    > `let albums = try await dataManager.searchAlbums(query)`
    > `let artists = try await dataManager.searchArtists(query)`
    > `let playlists = try await dataManager.searchPlaylists(query)`
  - `Fonic HiFi/Data/DataManager+Search.swift:37-51,82-93,133-144,184-195`
    > `limit: Int = 100`
    > `descriptor.fetchLimit = limit`
    > `...`
    > `limit: Int = 50`
  - `Fonic HiFi/Presentation/Views/Search/SearchView.swift:197-205`
    > `ForEach(results.tracks.prefix(10))`
    > `Text("See all \(results.tracks.count) tracks")`
- **Why this is defective/risky:** The Search tab serially runs four `@MainActor`/main-context fetches instead of the repository’s `Sendable` entities and paging. It can show at most 100 tracks and 50 of each other type, and “See all” is text with no navigation/load-more action. Users with larger matching libraries cannot reach the rest, while slow first queries delay later categories. Exact latency is **UNVERIFIED — needs build/device check**.
- **Preserving remediation:** Add a repository-level multi-category search returning first pages concurrently, then page each category through the existing repository methods. Preserve the current Search UI; make “See all” an actual action.
- **Paste-ready orchestration sketch:**

```swift
async let tracks = repository.tracks(page: 0, pageSize: 25, searchQuery: query)
async let albums = repository.albums(page: 0, pageSize: 10, searchQuery: query)
async let artists = repository.artists(page: 0, pageSize: 10, searchQuery: query)
async let playlists = repository.playlists(page: 0, pageSize: 10, searchQuery: query)

return try await SearchPage(
    tracks: tracks,
    albums: albums,
    artists: artists,
    playlists: playlists
)
```

Define `SearchPage` as `Sendable` and cancel stale searches when the query changes.
- **Verification / acceptance criteria:**
  1. Seed 151 matching tracks; page through all 151 from Search.
  2. “See all” is actionable and keeps deterministic order.
  3. Rapid typing cancels old results and never replaces a newer query.
  4. One category failure does not erase successful categories unless product policy says all-or-nothing.
  5. Profile a 50k library on device; **UNVERIFIED — needs build/device check**.
- **Related:** DLP-011, DLP-012, DLP-015.

### DLP-015 — Repeated recent searches create duplicate persistence rows and duplicate SwiftUI IDs

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Data/Actors/RecentSearchesActor.swift:17-32`
    > `let search = RecentSearch(query: query, timestamp: Date())`
    > `modelContext.insert(search)`
    > `try modelContext.save()`
    > `... keep last 20`
  - `Fonic HiFi/Presentation/Views/Search/SearchView.swift:317-325`
    > `ForEach(recentSearches, id: \.query) { search in`
- **Why this is defective/risky:** Searching the same text repeatedly inserts multiple rows, but the UI treats `query` as a unique identity. Duplicate rows therefore have the same SwiftUI ID, which can yield unstable row reuse/removal and redundant history entries. The exact rendering symptom is **UNVERIFIED — needs build/device check**, but duplicate storage and IDs are certain.
- **Preserving remediation:** Upsert a normalized query and keep one row per normalized value. For a future schema version, add a stable UUID and a normalized unique key; until then, the actor can deduplicate its bounded 20-row set.
- **Paste-ready sample:**

```swift
public func addSearch(_ rawQuery: String) throws {
    let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return }
    let normalized = query.folding(
        options: [.caseInsensitive, .diacriticInsensitive],
        locale: .current
    )

    let searches = try modelContext.fetch(
        FetchDescriptor<RecentSearch>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
    )
    let matches = searches.filter {
        $0.query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == normalized
    }

    if let existing = matches.first {
        existing.query = query
        existing.timestamp = Date()
        for duplicate in matches.dropFirst() { modelContext.delete(duplicate) }
    } else {
        modelContext.insert(RecentSearch(query: query))
    }
    try modelContext.save()
}
```

- **Verification / acceptance criteria:**
  1. Search `Björk`, `bjork`, and whitespace variants; one row remains at the newest timestamp.
  2. Result count updates the same row.
  3. The UI uses a stable persistent ID after the next schema migration.
  4. History never exceeds 20 unique normalized queries.
  5. SwiftUI behavior is **UNVERIFIED — needs build/device check**.
- **Related:** DLP-014.

### DLP-016 — Widget state freezes progress and can remain “playing” after becoming stale

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Shared/AppGroupManager.swift:53-63`
    > `if let last = lastPlaybackState,`
    > `last.isPlaying == state.isPlaying,`
    > `... abs(last.duration - state.duration) < 0.1 {`
    > `// Only time changed - skip write`
    > `return`
  - `Fonic HiFi Widget/Shared/WidgetPlaybackState.swift:66-94`
    > `return min(max(currentTime / duration, 0), 1)`
    > `...`
    > `public var isStale: Bool { age > 300 }`
  - `Fonic HiFi Widget/NowPlayingEntry.swift:43-49`
    > `playbackState: WidgetPlaybackState.loadOrIdle()`
    > `trackInfo: WidgetTrackInfo.loadOrEmpty()`
  - `Fonic HiFi Widget/NowPlayingTimelineProvider.swift:36-49`
    > `if entry.isPlaying { refreshDate = Date().addingTimeInterval(60) }`
    > `...`
    > `policy: .after(refreshDate)`
- **Why this is defective/risky:** The app intentionally does not persist current-time-only updates. The widget’s `progress` ignores `timestamp` and `playbackRate`, so each scheduled timeline reload reads the same `currentTime`; the bar remains frozen. `isStale` exists but `fromAppGroup` never uses it, so a crash/force quit can leave the widget reporting playing indefinitely and requesting minute refreshes. Device scheduling/render behavior is **UNVERIFIED — needs build/device check**.
- **Preserving remediation:** Persist bounded checkpoints and derive projected time from the snapshot timestamp/rate. Resolve stale snapshots to paused/idle according to product policy; do not write every audio tick.
- **Paste-ready sample (mirror in both shared copies):**

```swift
public var projectedCurrentTime: TimeInterval {
    guard isPlaying, playbackRate > 0 else { return currentTime }
    let elapsed = max(0, Date().timeIntervalSince(timestamp))
    return min(duration, currentTime + elapsed * Double(playbackRate))
}

public var progress: Double {
    guard duration > 0 else { return 0 }
    return min(max(projectedCurrentTime / duration, 0), 1)
}
```

Also include `currentTime`/`timestamp` in `AppGroupManager`’s equality policy with a bounded checkpoint (for example, at least every 30 seconds), and make `NowPlayingEntry.fromAppGroup()` convert stale `isPlaying` snapshots to a non-playing state.
- **Verification / acceptance criteria:**
  1. During a five-minute track, widget progress advances on successive timeline entries.
  2. App Group writes remain bounded; no per-tick defaults writes.
  3. Pause/seek/track changes persist immediately.
  4. Force-quit/crash and wait past stale threshold; widget no longer claims active playback.
  5. Test all widget families on device; scheduling is **UNVERIFIED — needs build/device check**.
- **Related:** DLP-018.

### DLP-017 — Listening-session persistence has no retention bound

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Data/Actors/TrackDataActor.swift:775-806`
    > `let session = ListeningSession(...)`
    > `modelContext.insert(session)`
    > `try modelContext.save()`
  - `Fonic HiFi/Data/Actors/TrackDataActor.swift:809-835,909-929`
    > `descriptor.fetchLimit = limit`
    > *(read limits only)*
  - Active-source search found no `modelContext.delete`/batch-delete path for `ListeningSession`.
- **Why this is defective/risky:** Once DLP-002/DLP-004 enable history, every qualifying playback creates a permanent row. Reads are limited, but storage is not. Long-term listeners accumulate an ever-growing SwiftData/SQLite store and indexes; backup size and maintenance cost increase even though product features currently use only the newest 50 sessions. Growth rate and thresholds are **UNVERIFIED — needs build/device check**.
- **Preserving remediation:** Define a product retention contract (for example, raw sessions for one year and/or a maximum row count), aggregate older statistics if needed, and prune in bounded background batches after successful writes—not at launch. Keep favorites/play counts on `Track` independent of raw-session deletion.
- **Paste-ready actor method (policy values are examples):**

```swift
public func pruneListeningSessions(before cutoff: Date, batchSize: Int = 500) throws -> Int {
    var totalDeleted = 0

    while true {
        var descriptor = FetchDescriptor<ListeningSession>(
            predicate: #Predicate { $0.startedAt < cutoff },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        descriptor.fetchLimit = max(1, batchSize)
        let batch = try modelContext.fetch(descriptor)
        guard !batch.isEmpty else { break }

        for session in batch { modelContext.delete(session) }
        try modelContext.save()
        totalDeleted += batch.count
        if batch.count < batchSize { break }
    }

    return totalDeleted
}
```

- **Verification / acceptance criteria:**
  1. Document retention by age/count and whether older aggregates are retained.
  2. Seed more than the limit, prune, relaunch, and verify exact retained boundary.
  3. Continue Listening/recommendations/play counts remain correct.
  4. Cancellation between batches resumes safely.
  5. Measure store/WAL size and prune time on device; **UNVERIFIED — needs build/device check**.
- **Related:** DLP-002, DLP-004, DLP-018.

### DLP-018 — Imported-audio backup policy is implicit and unverified

- **Severity:** Informational
- **Confidence:** UNVERIFIED — needs build/device check
- **Evidence:**
  - `Fonic HiFi/Data/Actors/FileImportProcessor.swift:62-76`
    > `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)`
    > `.appendingPathComponent("Music", isDirectory: true)`
  - `Fonic HiFi/Data/Actors/FileImportProcessor.swift:669-680`
    > `try fileManager.copyItem(at: sourceURL, to: destinationURL)`
  - `Fonic HiFi/Shared/WidgetConstants.swift:75-80`
    > `.appendingPathComponent("Library", isDirectory: true)`
    > `.appendingPathComponent("Caches", isDirectory: true)`
    > `.appendingPathComponent(...ArtworkCache...)`
  - Active-source search found no `.isExcludedFromBackupKey`, `NSURLIsExcludedFromBackupKey`, or equivalent policy application.
- **Why this is risky:** Widget thumbnails are correctly placed under `Library/Caches` and should remain purgeable. Imported audio is copied under Documents, where backup inclusion may be appropriate if it is irreplaceable user data—or inappropriate if it is a reproducible copy of a security-scoped source. The code does not record that product decision, apply per-file policy, expose restore expectations, or test backup size. Excluding everything could cause data loss after restore; backing up a 500 GB library could create operational/review risk. This is therefore an acceptance/policy gap, not a proven defect.
- **Preserving remediation:** Decide and document the policy before changing code. If imported copies are authoritative user data, retain backup inclusion and validate restore. If they are reproducible caches, store them in an appropriate non-backed-up location or explicitly exclude only those files while preserving library metadata and a relink workflow. Never blanket-exclude the SwiftData store or user-created playlists/history.
- **Safe acceptance-test sample:**

```swift
let values = try managedFileURL.resourceValues(
    forKeys: [.isExcludedFromBackupKey, .fileSizeKey]
)
XCTAssertEqual(values.isExcludedFromBackup, expectedBackupExclusion)
```

The expected value must come from the approved product data-retention contract.
- **Verification / acceptance criteria:**
  1. Product/security signs off whether managed audio is authoritative or reproducible.
  2. Inspect a device backup manifest for SwiftData, managed music, and widget cache.
  3. Restore onto a clean device and verify tracks, playlists, history, and missing-file UX.
  4. Measure backup size for a representative large lossless library.
  5. Confirm cache directories are purgeable and recoverable. All outcomes are **UNVERIFIED — needs build/device check**.
- **Related:** DLP-005, DLP-007, DLP-016, DLP-017.

### DLP-019 — Track transitions omit or race the replacement listening session

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:331-341`
    > `try await playbackController.play(track: track)`
    > `...`
    > `sessionService?.startSession(trackId: track.id, duration: duration)`
  - `Fonic HiFi/Core/Audio/Analytics/ListeningSessionService.swift:55-71`
    > `if activeSession != nil {`
    > `Task { await endSession(currentTime: 0, wasSkipped: true, wasCompleted: false) }`
    > `}`
    > `activeSession = ActiveSession(...)`
  - `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:405-430`
    > `await sessionService?.endSession(...)`
    > `try await queueCoordinator.playNext()`
    > `...`
    > `try await queueCoordinator.playPrevious()`
  - `Fonic HiFi/Core/Audio/Coordinators/QueueCoordinator.swift:39-74`
    > `queueManager.setCurrentTrack(nextTrack)`
    > `...`
    > `try await playbackController.play(track: track, queueEntry: nextTrack)`
    > `...`
    > `try await playbackController.play(track: track, queueEntry: previousTrack)`
  - `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:171-183`
    > `await self.sessionService?.endSession(...)`
    > `try await self.queueCoordinator.playNext()`
- **Why this is defective/risky:** Only the public `play(track:)` method starts a session. Manual next, previous, and natural auto-advance end the old session and call `QueueCoordinator` directly; no new session is started for the newly playing queue item. Directly selecting another track has the opposite failure: `startSession` schedules asynchronous cleanup of the old session, immediately installs the new session, and the later MainActor task can observe and clear that replacement. Even after DLP-004 wiring, queue history is incomplete and direct replacement is racy. Runtime playback/history behavior is **UNVERIFIED — needs build/device check**, but both transition paths are static.
- **Preserving remediation:** Keep queue playback in `QueueCoordinator`, but centralize transition ownership in `AudioEngineFacade`: synchronously/awaitably finish the old session before playback replacement, call one post-success start hook after every successful transition, and remove the unstructured cleanup `Task` from `startSession`. Do not start a session before playback succeeds.
- **Paste-ready helper (requires Xcode validation):**

```swift
@MainActor
private func startSessionForCurrentQueueTrack() async {
    guard let track = queueCoordinator.currentTrack,
          let engine = engineManager.currentEngine else { return }
    let duration = await engine.duration
    sessionService?.startSession(trackId: track.id, duration: duration)
}

public func playNext() async throws {
    if let engine = engineManager.currentEngine {
        await sessionService?.endSession(
            currentTime: await engine.currentTime,
            wasSkipped: true,
            wasCompleted: false
        )
    }
    try await queueCoordinator.playNext()
    await startSessionForCurrentQueueTrack()
}
```

Apply the same helper after previous and the natural-completion auto-advance callback. Make `startSession` install only a new session (no child `Task`); the facade must await old-session completion before replacement. A cleaner follow-up is an injected `didStartTrack` callback from `QueueCoordinator`, but the local helper preserves the current architecture.
- **Verification / acceptance criteria:**
  1. Explicit play followed by three manual-next actions records four distinct track sessions.
  2. Natural completion/auto-advance records the completed track and starts the next session.
  3. Directly select a new track while one is active; the old session ends and the new session remains active.
  4. Previous, repeat-one, repeat-all, shuffle, crossfade, and end-of-queue semantics are covered.
  5. A failed next-track load does not start a phantom session.
  6. Exercise real playback on device; behavior is **UNVERIFIED — needs build/device check**.
- **Related:** DLP-002, DLP-004, DLP-017, DLP-020.

### DLP-020 — Playback position is mistaken for time actually listened

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Core/Audio/Analytics/ListeningSessionService.swift:41-45`
    > `let startedAt: Date`
    > `let trackDuration: TimeInterval`
  - `Fonic HiFi/Core/Audio/Analytics/ListeningSessionService.swift:91-118`
    > `let durationListened = currentTime`
    > `let completionPercentage = ... durationListened / session.trackDuration`
    > `...`
    > `if completionPercentage >= playCountThreshold || wasCompleted {`
    > `try await dataActor.incrementPlayCount(...)`
  - `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:337-347`
    > `sessionService?.startSession(trackId: track.id, duration: duration)`
    > `...`
    > `if let seekPosition = pendingSeekPosition {`
    > `try await playbackController.seek(to: seekPosition)`
- **Why this is defective/risky:** Media position is not listening duration. Seeking near the end—or restoring a saved position immediately after the session starts—makes `durationListened` and `completionPercentage` jump even if the user listened for only seconds. That can increment play count, distort Continue Listening, and poison recommendation inputs. The arithmetic and restored-position order are static; exact feature output is **UNVERIFIED — needs build/device check**.
- **Preserving remediation:** Track actual playing intervals with a monotonic clock, separately persist media completion position, and base the 50% play-count threshold on actual listened time (or natural completion), not current position. Pause/resume and interruptions must open/close listening intervals; seeks must not add time.
- **Safe code direction (requires integration with playback callbacks):**

```swift
private let clock = ContinuousClock()
private var segmentStartedAt: ContinuousClock.Instant?
private var accumulatedListened: Duration = .zero

func playbackDidResume() {
    segmentStartedAt = segmentStartedAt ?? clock.now
}

func playbackDidPause() {
    guard let start = segmentStartedAt else { return }
    accumulatedListened += start.duration(to: clock.now)
    segmentStartedAt = nil
}

private func listenedSeconds() -> TimeInterval {
    var duration = accumulatedListened
    if let start = segmentStartedAt {
        duration += start.duration(to: clock.now)
    }
    let parts = duration.components
    return TimeInterval(parts.seconds)
        + TimeInterval(parts.attoseconds) / 1_000_000_000_000_000_000
}
```

At end, set `durationListened = listenedSeconds()`. Compute media completion from `currentTime / trackDuration`, but compute play-count eligibility from `durationListened / trackDuration` unless `wasCompleted` is true. Inject a test clock rather than sleeping in tests.
- **Verification / acceptance criteria:**
  1. Seek from 0% to 90%, listen five seconds, stop: no 50% play-count increment.
  2. Restore at 80% and stop quickly: persisted listened duration reflects only new playback.
  3. Pause for five minutes: paused wall time is excluded.
  4. Seek backward/replay sections: actual listening time accumulates without negative deltas.
  5. Natural completion still increments according to policy. Device behavior is **UNVERIFIED — needs build/device check**.
- **Related:** DLP-004, DLP-017, DLP-019.

### DLP-021 — Import cancellation is not propagated to the stream producer

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Evidence:**
  - `Fonic HiFi/Data/Services/LibraryImportService.swift:108-115`
    > `self.importTask?.cancel()`
    > `self.importTask = nil`
    > `self.isImporting = false`
  - `Fonic HiFi/Data/Actors/FileImportProcessor.swift:143-155`
    > `return AsyncStream<ProcessedFileResult> { continuation in`
    > `Task {`
    > `await Self.emitProcessedFiles(...)`
    > `}`
    > `}`
  - `Fonic HiFi/Data/Actors/FileImportProcessor.swift:276-334`
    > `await withTaskGroup(...) { group in`
    > `...`
    > `if Task.isCancelled { break }`
    > `...`
    > `group.cancelAll()`
  - `Fonic HiFi/Data/Services/LibraryImportService.swift:233-241`
    > `for await result in stream {`
    > `if Task.isCancelled {`
    > `...`
    > `return`
- **Why this is defective/risky:** `cancelImport` cancels the consumer task. `processFilesStream` created a separate unstructured `Task`; ending the consumer/`AsyncStream` iteration does not automatically cancel that producer because no `onTermination` handler links them. The producer’s `Task.isCancelled` checks and `group.cancelAll()` therefore may never activate, and queued/in-flight imports can continue copying and saving after the UI reports “Import cancelled.” The number of extra commits depends on scheduling/buffering and is **UNVERIFIED — needs build/device check**, but the missing cancellation link is static.
- **Preserving remediation:** Retain the producer task inside the `AsyncStream` builder and cancel it from `continuation.onTermination`. Apply the same pattern to discovery, call `Task.checkCancellation()` between copy/metadata/save phases, and combine it with DLP-005’s compensating delete.
- **Paste-ready stream pattern (requires Swift concurrency build validation):**

```swift
return AsyncStream<ProcessedFileResult> { continuation in
    let producer = Task {
        await Self.emitProcessedFiles(
            from: files,
            maxConcurrentTasks: maxConcurrentTasks,
            baseDirectory: baseDirectory,
            metadataExtractor: metadataExtractor,
            trackDataActor: trackDataActor,
            securityAccessor: securityAccessor,
            logger: logger,
            to: continuation
        )
    }

    continuation.onTermination = { @Sendable _ in
        producer.cancel()
    }
}
```

Inside `importFile`, check cancellation before copy, immediately after copy, before the SwiftData insert, and on error remove only the new destination.
- **Verification / acceptance criteria:**
  1. Start 1,000 slow imports, cancel, and assert processed/row/file counts stop increasing after currently executing operations settle.
  2. Cancel while discovery is blocked on a full buffer; producer and security-scoped access terminate.
  3. Cancel after copy but before metadata/save; the destination is rolled back.
  4. Repeated cancel/restart does not leak tasks or reject a fresh import.
  5. Validate with Swift Concurrency Instruments/device filesystem; behavior is **UNVERIFIED — needs build/device check**.
- **Related:** DLP-005, DLP-006.

---

## Rejected candidate findings

1. **Security-scoped access leak during the active import path — rejected.** `emitDiscoveredFiles`/`enumerateAudioFiles` stop directory access, single-file discovery stops after bookmark creation, and `resolveSecurityScopedURL` returns a deferred stop closure (`FileImportProcessor.swift:456-534,611-666`). Real provider behavior still belongs in device checks.
2. **Widget artwork cache is unbounded — rejected.** It lives in the App Group `Library/Caches` path and enforces a 50 MB target with eviction (`WidgetConstants.swift:28-46`; `WidgetArtworkCache.swift:228-255`). Its access-date persistence could be improved, but no material defect was retained.
3. **App Group identifier mismatch — rejected.** App, widget, both entitlement files, and both `WidgetConstants` copies use `group.ai.keiranlabs.Fonic-HiFi`.
4. **`TrackCache`/`SearchCache` cause production memory growth — rejected.** Both are bounded, actor-isolated, and active-source search found construction only in tests; they are not the live library/search path.
5. **The duplicate app/widget shared structs are currently incompatible — rejected.** The active copies are structurally identical in this snapshot. Duplication is drift risk, but no current wire mismatch was proven.
6. **`ImportSession` rollback defects affect the shipped import flow — rejected.** Active-source construction occurs only in `ImportSessionTests`; production uses `LibraryImportService`/`FileImportProcessor`. Its issues should be removed or fixed before activation, but were not counted as production findings.
7. **Direct `TrackDataActor.deleteTrack` necessarily leaks/deletes the wrong file — rejected.** The method deletes only metadata, but no active user-facing call reaches it; current semantics are not enough to infer intended file ownership. Explicit File Manager deletion is covered through DLP-007’s reconciliation impact.
8. **Documents/Music must always be backup-excluded — rejected as an absolute claim.** Imported music can be irreplaceable user data. DLP-018 requires a policy and device proof instead of prescribing unsafe blanket exclusion.

## Open build/device checks

1. **Schema/migration:** Build with the shipping Xcode; open real V1 and V2 on-disk fixtures through the production App Group configuration; verify no fallback and byte/count preservation.
2. **History:** After registering/wiring `ListeningSession`, exercise play, pause, seek, manual skip, auto-advance, completion, interruption, termination, and relaunch; verify session/play-count semantics.
3. **Import transaction:** Inject failures/cancellation before copy, after copy, during metadata, during relationship save, and under low disk. Verify no source loss, no orphan copy, and idempotent retry.
4. **Security-scoped URLs:** Test local Files, iCloud Drive downloaded/evicted items, third-party providers, selected folders, stale bookmarks, revoked permission, and coordinated reads.
5. **Deduplication:** Select repeated/equivalent URLs and bookmarks at concurrency 1/4/8; verify one row/copy and retry after failure.
6. **Missing-file recovery:** Lock/unlock the device, temporarily remove/restore files, and simulate provider unavailability. No automatic metadata deletion is acceptable.
7. **Large library:** Profile 10k and 50k tracks (lossless-size artwork included) for launch, page 0/deep page, search, statistics, Home load, import, relationship backfill, and memory warning behavior.
8. **Playlist persistence:** Validate create/add/reorder/remove/delete/relaunch, stale IDs after track deletion, smart-rule semantics, and repository refresh.
9. **Widget:** Compare App Group payloads across app/widget processes; test progress, seek, pause, app crash/force quit, stale threshold, timeline budget, and artwork eviction in all families.
10. **Backup/restore:** Inspect actual backup manifests and restore to a clean device using the approved authoritative-vs-reproducible media policy.
11. **Concurrency:** Rebuild in Swift 6 complete concurrency mode with warnings as errors, Thread Sanitizer where supported, and inspect any model-crossing or actor diagnostics.
12. **Large-store disk behavior:** Measure SQLite, WAL, artwork blobs, raw listening sessions, widget cache, failed-import cleanup, and post-prune compaction; static source cannot establish reclaimed bytes.
