# Threadlock — Swift concurrency, performance, memory, and energy audit

**Repository:** `/agent/workspace/fonic-hifi-audit`
**Audited snapshot:** `main` @ `459db9bfd18d17960e8fd2ff8defc4701085532e`
**Audit date:** 2026-07-09
**Scope:** 197 Swift files / 43,546 lines in the main app source tree and 16 Swift files / 1,828 lines in the widget source tree. Tests were inspected where they corroborate ownership or validation gaps. Sample projects, prose, old logs, and prior audits were not used as proof of a production defect.
**Loaded guidance:** Axiom Swift Concurrency, Performance & Energy (including memory/energy routing), SwiftUI performance guidance, and iOS Audit Agents guidance.
**Execution boundary:** static inspection only. This Linux environment has no Xcode or Apple SDKs. I did not compile, run, profile, sign, launch Instruments, exercise a simulator, or measure a device. Rates such as “10 callbacks/second” below are arithmetic from literal source intervals, not runtime measurements.

## Conclusion

The project has a strong baseline for Swift 6 checking: the app, tests, UI tests, and widget declare Swift 6 language mode with `SWIFT_STRICT_CONCURRENCY = complete`. Most mutable audio/UI owners are explicitly `@MainActor`; SwiftData background work generally uses actors or `@ModelActor`; production contains only one `@unchecked Sendable`, and that wrapper is actor-confined.

The main risks are therefore not a broad absence of isolation annotations. They are lifecycle and scaling defects inside otherwise well-isolated code. Cancellation can strand semaphore waiters and does not reach import-stream producers; the concurrent importer has a check-then-insert race for duplicates; listening-session replacement is an unstructured MainActor race; and two continuously running polling designs create avoidable wakeups or tasks. On the performance side, queue persistence performs an O(queue-size) file validation plus full JSON/UserDefaults write on the MainActor for each mutation, active Home/Search paths run synchronous SwiftData work on the MainActor, widget artwork processing performs image and file work on the MainActor, and pagination repeatedly implements “count” by fetching every matching model. Optional diagnostics also retain unbounded samples and schedule a second poller whose current engine implementations do no work.

**Retained findings: 16 — 3 High, 11 Medium, 2 Low.**
**Confidence: 15 confirmed by static evidence, 1 probable.**
**Unapplied fixes only:** no repository source was modified.

## Findings table

| ID | Severity | Confidence | Finding |
|---|---|---|---|
| CP-001 | Medium | Confirmed by static evidence | Semaphore waiters are not cancellation-aware and can remain suspended after cancellation |
| CP-002 | High | Confirmed by static evidence | Import cancellation does not cancel the AsyncStream producer tasks or bounded processing group |
| CP-003 | High | Confirmed by static evidence | Every queue mutation can synchronously validate and serialize the full queue on the MainActor |
| CP-004 | High | Confirmed by static evidence | Concurrent imports can pass duplicate checks before either import commits |
| CP-005 | Medium | Confirmed by static evidence | Starting a new listening session can make an old fire-and-forget task clear the new session |
| CP-006 | Medium | Confirmed by static evidence | The always-created widget coordinator polls the full queue every 500 ms even when idle |
| CP-007 | Medium | Confirmed by static evidence | AudioKit creates a MainActor task every 100 ms in addition to the centralized progress poller |
| CP-008 | Medium | Confirmed by static evidence | Active Home and Search paths perform synchronous SwiftData fetches and an unbounded genre scan on the MainActor |
| CP-009 | Medium | Confirmed by static evidence | Widget artwork decode, resize, JPEG encoding, plist writes, and cache scans run on the MainActor |
| CP-010 | Medium | Probable | The artwork cache is bounded by entry count, not bytes, and stores full encoded artwork blobs |
| CP-011 | Medium | Confirmed by static evidence | SwiftUI library and queue bodies materialize new arrays on every evaluation |
| CP-012 | Low | Confirmed by static evidence | Optional runtime diagnostics retain unbounded histories and start a redundant no-op engine poller |
| CP-013 | Low | Confirmed by static evidence | Deferred startup maintenance is unowned and treats cancellation as “run immediately” |
| CP-014 | Medium | Confirmed by static evidence | Pagination obtains total counts by fetching every matching model on every page |
| CP-015 | Medium | Confirmed by static evidence | File Manager mixes synchronous UI-context file I/O with an uncancellable detached-copy continuation |
| CP-016 | Medium | Confirmed by static evidence | Library rows and File Manager rebuild formatters and full sort/filter results in render paths |

---

## Full findings

### CP-001 — Semaphore waiters are not cancellation-aware

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Core/Audio/Services/AsyncSemaphore.swift:3-37`
  - `Fonic HiFi/Core/Audio/Services/FormatDetectionCoordinator.swift:29-55`
- **Source excerpt:**

  ```swift
  func acquire() async {
      if currentValue > 0 {
          currentValue -= 1
          return
      }

      await withCheckedContinuation { continuation in
          waiters.append(continuation)
      }
  }
  ```

  ```swift
  try Task.checkCancellation()
  ...
  await semaphore.acquire()
  ...
  defer {
      Task {
          await semaphore.release()
      }
  }
  ```

- **Why this is defective/risky:** cancellation is checked only before waiting. Once `acquire()` appends a continuation, canceling that task does not remove or resume the waiter. The caller remains suspended until some other operation releases a permit; if the active operations hang, the canceled task and everything it captures can remain retained indefinitely. When a permit eventually arrives, a canceled waiter consumes it before the format operation's later cancellation check rejects the request. The current cancellation test cancels an already-running detection; it does not cover a request queued behind a saturated semaphore.
- **Preserving remediation:** make `acquire()` throwing and cancellation-aware. Give every waiter an ID, remove-and-resume it from a cancellation handler, install permit release immediately after acquisition, and check cancellation once more after acquiring.
- **Unapplied sample (compile validation required):**

  ```swift
  actor AsyncSemaphore {
      private struct Waiter {
          let id: UUID
          let continuation: CheckedContinuation<Void, Error>
      }

      private let maximumValue: Int
      private var currentValue: Int
      private var waiters: [Waiter] = []

      init(value: Int) {
          precondition(value > 0)
          maximumValue = value
          currentValue = value
      }

      func acquire() async throws {
          try Task.checkCancellation()
          if currentValue > 0 {
              currentValue -= 1
              return
          }

          let id = UUID()
          try await withTaskCancellationHandler {
              try await withCheckedThrowingContinuation { continuation in
                  waiters.append(Waiter(id: id, continuation: continuation))
              }
          } onCancel: {
              Task { await self.cancelWaiter(id: id) }
          }
      }

      private func cancelWaiter(id: UUID) {
          guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
          waiters.remove(at: index).continuation.resume(throwing: CancellationError())
      }

      func release() {
          if !waiters.isEmpty {
              waiters.removeFirst().continuation.resume()
          } else if currentValue < maximumValue {
              currentValue += 1
          }
      }
  }
  ```

  In `performDetection`, use `try await semaphore.acquire()`, install the existing release immediately, then call `try Task.checkCancellation()`.
- **Verification / acceptance:** add a deterministic test with concurrency limit 1: block request A, queue request B, cancel B, and require B to throw `CancellationError` before A is released. Then release A and verify request C acquires the only permit. Acceptance: no canceled continuation remains in the semaphore and permit count is preserved.
- **Related:** CP-002, CP-015.

### CP-002 — Import cancellation does not reach AsyncStream producers

- **Severity:** High
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Data/Actors/FileImportProcessor.swift:101-105,126-156,260-338,456-495`
  - `Fonic HiFi/Data/Services/LibraryImportService.swift:193-241`
- **Source excerpt:**

  ```swift
  func discoverAudioFilesStream(from urls: [URL]) -> AsyncStream<DiscoveredAudioFile> {
      AsyncStream { continuation in
          Task { await self.emitDiscoveredFiles(from: urls, to: continuation) }
      }
  }
  ```

  ```swift
  return AsyncStream<ProcessedFileResult> { continuation in
      Task {
          await Self.emitProcessedFiles(..., to: continuation)
      }
  }
  ```

  ```swift
  if Task.isCancelled {
      discoveryTask.cancel()
      queueContinuation.finish()
      _ = await discoveryTask.result
      self.statusMessage = "Import cancelled"
      self.isImporting = false
      return
  }
  ```

- **Why this is defective/risky:** both stream builders start unstructured producer tasks and discard their handles. Neither sets `continuation.onTermination`. `cancelImport()` cancels the MainActor consumer and its explicitly owned `discoveryTask`, but cancellation does not propagate into `FileImportProcessor`'s discovery task or the task that owns `withTaskGroup`. The discovery producer also ignores the result of `continuation.yield`; after its consumer terminates it can continue walking a large directory and creating bookmarks. The processing producer can continue bounded copies, metadata extraction, and SwiftData inserts after the UI already says “Import cancelled.” The existing test only checks UI state and `filesProcessed < totalFiles`; it does not assert that disk copies and database inserts stop after cancellation.
- **Preserving remediation:** retain each producer handle in its stream and cancel it from `onTermination`; make the producer check cancellation before every new file and before persistence; explicitly await producer shutdown before publishing the canceled state. Accept that `FileManager.copyItem` is not mid-copy cancellable unless replaced with chunked copying, but do not start any new copy after cancellation.
- **Unapplied sample (apply to every producer stream; compile validation required):**

  ```swift
  func discoverAudioFilesStream(from urls: [URL]) -> AsyncStream<DiscoveredAudioFile> {
      AsyncStream(bufferingPolicy: .bufferingOldest(32)) { continuation in
          let producer = Task {
              await self.emitDiscoveredFiles(from: urls, to: continuation)
          }
          continuation.onTermination = { @Sendable _ in
              producer.cancel()
          }
      }
  }
  ```

  Use the same ownership pattern for `processFilesStream` and `makeContainerPreparationFailureStream`. In `emitDiscoveredFiles`, stop when `yield` returns `.terminated`; in `emitProcessedFiles`, check `Task.isCancelled` before each `group.addTask`, call `group.cancelAll()`, and do not update the hash cache or create a track after cancellation.
- **Verification / acceptance:** inject a controllable copy/metadata collaborator, start more files than the concurrency limit, cancel while all slots are occupied, and record copy starts, metadata starts, destination files, and persisted identifiers. Acceptance: cancellation returns promptly; no new work starts after cancellation; at most the already in-flight bounded work reaches a defined cleanup point; no post-cancel track is committed; security-scoped access is balanced.
- **Related:** CP-001, CP-004, CP-015.

### CP-003 — Queue mutations synchronously persist the full queue on the MainActor

- **Severity:** High
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Core/Audio/Queue/AudioQueueManager.swift:12-15,570-665`
  - `Fonic HiFi/Core/Audio/Queue/QueueState.swift:321-326,359-404`
  - `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:357-384`
- **Source excerpt:**

  ```swift
  @MainActor
  @Observable
  public final class AudioQueueManager: AudioQueue {
  ```

  ```swift
  private func notifyTracksChanged() {
      delegate?.audioQueue(self, didUpdateTracks: tracks)
      // Auto-save when tracks change
      saveState()
  }

  private func notifyCurrentTrackChanged() {
      delegate?.audioQueue(self, didChangeCurrentTrack: currentTrack, at: currentIndex)
      // Auto-save when current track changes
      saveState()
  }
  ```

  ```swift
  let validTracks = tracks.filter { track in
      FileManager.default.fileExists(atPath: track.url.path)
  }
  ...
  let data = try encoder.encode(self)
  UserDefaults.standard.set(data, forKey: Self.persistenceKey)
  ```

- **Why this is defective/risky:** `saveState()` inherits MainActor isolation. It builds a full snapshot, performs `fileExists` for every queued and history track, encodes both arrays to JSON, and stores the complete blob in `UserDefaults`. Common operations such as `replaceQueue` call both track and current-track notifications, so one action can perform this full pass twice. Pause and stop also synchronously save. Cost therefore scales with queue length on a latency-sensitive actor shared by playback controls and SwiftUI. It also uses preferences storage as a frequently rewritten large-state database.
- **Preserving remediation:** keep `AudioQueueManager` as the authoritative MainActor owner, but pass an immutable `QueueState` snapshot to a dedicated persistence actor. Debounce/coalesce mutations, persist one atomic file under Application Support/App Group, and perform expensive file validation at restore or maintenance time rather than on every mutation. Flush explicitly on backgrounding/termination where the platform grants time.
- **Unapplied sample (compile/device validation required):**

  ```swift
  actor QueueStatePersistence {
      private let fileURL: URL
      private var pending: Task<Void, Never>?

      init(fileURL: URL) { self.fileURL = fileURL }

      func schedule(_ state: QueueState) {
          pending?.cancel()
          pending = Task { [fileURL] in
              do {
                  try await Task.sleep(for: .milliseconds(400))
                  try Task.checkCancellation()
                  let encoder = JSONEncoder()
                  encoder.dateEncodingStrategy = .iso8601
                  let data = try encoder.encode(state)
                  try data.write(to: fileURL, options: .atomic)
              } catch is CancellationError {
                  return
              } catch {
                  Log.logger(.audioQueueState).error("Queue save failed: \(error.localizedDescription)")
              }
          }
      }

      func flush() async { _ = await pending?.result }
  }
  ```

  Queue mutation methods should enqueue one snapshot after all fields are updated, not from both notification helpers. Do not call `validateForPersistence()` on the hot mutation path.
- **Verification / acceptance:** unit-test that a replace/move/remove emits one persistence request. On device, profile queues of 100, 1,000, and 10,000 lightweight entries with Time Profiler, Hangs, and File Activity. Acceptance: queue controls do no synchronous file checks/encoding on the main thread; writes are coalesced; force-quit/relaunch restores the final state; missing files are pruned during restore without blocking interaction.
- **Related:** CP-006, CP-011, CP-016.

### CP-004 — Concurrent imports can pass duplicate checks before either commits

- **Severity:** High
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Data/Actors/FileImportProcessor.swift:273-327,352-385,603-634`
  - `Fonic HiFi/Data/Actors/TrackDataActor.swift:480-505`
- **Source excerpt:**

  ```swift
  var hashCache = await loadSourceHashCache(...)
  ...
  let currentCache = hashCache
  group.addTask {
      await Self.processDiscoveredFile(
          discoveredFile,
          hashCache: currentCache,
          ...
      )
  }
  ```

  ```swift
  if result.succeeded {
      ...
      hashCache.addEntry(...)
  }
  ```

  ```swift
  if try await trackDataActor.trackExists(...) != nil {
      throw ProcessedFileError(message: "Duplicate file already exists")
  }

  let copiedFileURL = try copyFile(...)
  let trackMetadata = try await metadataExtractor.extractTrackMetadata(from: copiedFileURL)
  return try await trackDataActor.createTrack(from: enrichedMetadata)
  ```

- **Why this is defective/risky:** each child receives a value snapshot of the cache. The coordinator adds a source identity to the cache only after that child completes. Two identical URLs admitted in the same concurrency window can therefore both miss the cache. Their actor-isolated `trackExists` calls can also both return nil before either task finishes copy/metadata work and calls `createTrack`; actor isolation serializes each check, but it does not make the check-plus-insert transaction atomic across suspension points. The result can be two copied files and two library records for one source.
- **Preserving remediation:** claim each source identity synchronously in the single coordinator before launching a child. Keep a set of preexisting plus in-flight hashes, and yield a duplicate result without launching when insertion fails. Add a persistence-level unique import identity (or an atomic `createIfAbsent`) as the final invariant.
- **Unapplied sample (coordinator portion):**

  ```swift
  var claimedURLHashes = hashCache.urlHashes

  func launch(_ file: DiscoveredAudioFile, in group: inout TaskGroup<ProcessedFileResult>) {
      let hash = file.originalURL.librarySourceHash()
      guard claimedURLHashes.insert(hash).inserted else {
          continuation.yield(.init(
              file: file,
              identifier: nil,
              error: .init(message: "Duplicate file already queued"),
              duration: 0
          ))
          return
      }

      let currentCache = hashCache
      group.addTask {
          await Self.processDiscoveredFile(file, hashCache: currentCache, /* existing arguments */)
      }
  }
  ```

  Expose a read-only snapshot or a helper on `SourceHashCache` rather than widening mutable access. A database uniqueness constraint or actor method that performs fetch-and-insert without suspension must remain the authoritative backstop.
- **Verification / acceptance:** import the same source URL 10 times in one request with concurrency 4, then import symlink/standardized-path aliases. Acceptance: exactly one destination file and one Track survive, nine deterministic duplicate results are reported, and cancellation releases every in-flight claim.
- **Related:** CP-002.

### CP-005 — Old session teardown can clear a newly started listening session

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Core/Audio/Analytics/ListeningSessionService.swift:55-74,81-102`
- **Source excerpt:**

  ```swift
  if activeSession != nil {
      Task {
          await endSession(currentTime: 0, wasSkipped: true, wasCompleted: false)
      }
  }

  activeSession = ActiveSession(
      trackId: trackId,
      startedAt: Date(),
      trackDuration: duration
  )
  ```

  ```swift
  guard let session = activeSession else { return }
  activeSession = nil
  ```

- **Why this is defective/risky:** `startSession` is synchronous on the MainActor. The unstructured task cannot complete the actor-isolated `endSession` before the current call stores the replacement. When that task later executes, `endSession` reads and clears the new session, not the old one. Rapid track changes or an overlapping start can therefore discard the session for the track that is actually playing and corrupt play-count/listening analytics.
- **Preserving remediation:** make replacement ordered. Either make `startSession` async and await termination before assignment, or capture the old `ActiveSession` value and persist that value without consulting mutable `activeSession` later. The caller should supply the old engine position rather than hard-code zero if the old session is meant to be recorded.
- **Unapplied sample:**

  ```swift
  public func startSession(
      trackId: UUID,
      duration: TimeInterval,
      previousCurrentTime: TimeInterval = 0
  ) async {
      if activeSession != nil {
          await endSession(
              currentTime: previousCurrentTime,
              wasSkipped: true,
              wasCompleted: false
          )
      }

      activeSession = ActiveSession(
          trackId: trackId,
          startedAt: Date(),
          trackDuration: duration
      )
  }
  ```

  Update `AudioEngineFacade.play` to `await` this call. Compilation and analytics semantics must be validated.
- **Verification / acceptance:** start A, immediately start B before any teardown task can run, then end B after a qualifying duration. Acceptance: B remains active until explicitly ended; the persisted track ID/percent belongs to B; A is handled exactly once according to product policy; no unstructured teardown task remains.
- **Related:** CP-007.

### CP-006 — Widget synchronization polls the queue every 500 ms even when idle

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/FonicHiFiApp.swift:318-339`
  - `Fonic HiFi/Core/Services/WidgetDataCoordinator.swift:28-32,56-94`
- **Source excerpt:**

  ```swift
  let widgetCoordinator = WidgetDataCoordinator(
      stateManager: playbackStateManager,
      queueManager: queueManager,
      artworkService: artworkService,
  )
  ```

  ```swift
  observationTask = Task { @MainActor [weak self] in
      ...
      while !Task.isCancelled {
          guard let self else { return }
          let state = queueManager.queueState
          ...
          try? await Task.sleep(for: .milliseconds(500))
      }
  }
  ```

- **Why this is defective/risky:** primary, preview, and fallback service construction all create this coordinator. Its task wakes at the configured 500 ms interval for the coordinator's lifetime, even when the queue is idle and unchanged. During background audio playback that is a configured two wakeups per second on the MainActor, each creating a queue snapshot containing queue/history arrays just to compare current ID and count. The weak capture prevents a permanent owner cycle, but it does not remove the process-lifetime wake source because the app intentionally retains the coordinator.
- **Preserving remediation:** replace polling with a queue-change publisher/observation callback emitted only when tracks/current index/shuffle/repeat change. Subscribe with a weak capture and debounce only the widget reload, not state detection. If polling must remain as a fallback, start it only while playback is active, move the weak-self check after sleep, use a much longer tolerance-aware clock, and expose an explicit `stop()` invoked by the lifecycle owner.
- **Unapplied sample (publisher direction):**

  ```swift
  // AudioQueueManager
  private let queueDidChangeSubject = PassthroughSubject<Void, Never>()
  var queueDidChange: AnyPublisher<Void, Never> {
      queueDidChangeSubject.eraseToAnyPublisher()
  }

  private func publishQueueChange() {
      queueDidChangeSubject.send(())
  }
  ```

  Call `publishQueueChange()` once at the end of each completed mutation. In `WidgetDataCoordinator`, sink that publisher, read one `queueState`, and call `handleQueueStateChange`; remove `observationTask` entirely.
- **Verification / acceptance:** add a fake queue-change publisher and assert zero callbacks while idle, one callback per mutation, and no callback after coordinator teardown. On a physical device, compare Energy Log/System Trace during 30 minutes of background playback before/after. Acceptance: no periodic 500 ms wake source remains; widget state/reloads still update on current-track, queue, shuffle, and repeat changes.
- **Related:** CP-003, CP-009.

### CP-007 — AudioKit creates a MainActor task every 100 ms in addition to centralized polling

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift:39-46,52-55,123-148,309-334`
  - `Fonic HiFi/Core/Audio/Engine/PlaybackController.swift:276-293`
- **Source excerpt:**

  ```swift
  updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      guard let self else { return }
      Task { @MainActor in
          await self.updateProgress()
      }
  }
  ```

  ```swift
  progressTimer.start(pollInterval: 0.5) { [weak self] in
      ...
      async let currentTime = engine.currentTime
      async let duration = engine.duration
      ...
  }
  ```

- **Why this is defective/risky:** selecting AudioKit starts a run-loop Timer at a literal 0.1-second interval and allocates a new unstructured MainActor task on every callback. PlaybackController simultaneously runs the architecture's central 0.5-second progress task. The AudioKit protocol getters only return `_currentTime`/`_duration`, so the second poller consumes values maintained by the first. This is avoidable timer, task, publication, and MainActor work for the full playback duration.
- **Preserving remediation:** establish one progress owner. Preferred: make AudioKit's getters read the player directly and let `ProgressTimerManager` drive UI progress; wire AudioKit's native completion callback for natural completion. As a safe intermediate reduction, make `updateProgress` synchronous, execute it directly in the main-run-loop callback, and align the interval with the centralized 0.5-second cadence; then remove the local timer after completion tests pass.
- **Unapplied intermediate sample:**

  ```swift
  private func startProgressPolling() {
      stopProgressPolling()
      let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
          MainActor.assumeIsolated {
              self?.updateProgressSynchronously()
          }
      }
      RunLoop.main.add(timer, forMode: .common)
      updateTimer = timer
  }

  private func updateProgressSynchronously() {
      guard _isPlaying else { return }
      _currentTime = activePlayer.currentTime
      _duration = activePlayer.duration
      if _duration > 0, _currentTime >= _duration {
          _isPlaying = false
          stopProgressPolling()
          completionHandler?()
      }
  }
  ```

  This removes per-tick Task creation; final consolidation should remove this timer rather than retain two pollers. Xcode must validate `MainActor.assumeIsolated` against the imported AudioKit/Timer closure annotations.
- **Verification / acceptance:** test pause/resume/seek/crossfade/natural completion with a controllable clock. On device, profile AudioKit playback with Swift Concurrency and Time Profiler. Acceptance: one progress scheduler exists; no recurring Task allocation originates at `AudioKitEngineAdapter.startProgressPolling`; visible time remains smooth; exactly one completion event fires.
- **Related:** CP-005, CP-012.

### CP-008 — Home and Search execute synchronous SwiftData work on the MainActor

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Presentation/Views/Search/SearchView.swift:79-113,123-168`
  - `Fonic HiFi/Data/DataManager+Search.swift:11-12,37-59,82-100,133-151,184-202`
  - `Fonic HiFi/Presentation/Views/Home/HomeView.swift:186-232`
  - `Fonic HiFi/Data/DataManager+Recent.swift:11-12,108-119`
- **Source excerpt:**

  ```swift
  @MainActor
  public extension DataManager {
      ...
      return try mainContext.fetch(descriptor)
  }
  ```

  ```swift
  private func searchAllContent(...) async throws -> SearchResults {
      let tracks = try await dataManager.searchTracks(query)
      let albums = try await dataManager.searchAlbums(query)
      let artists = try await dataManager.searchArtists(query)
      let playlists = try await dataManager.searchPlaylists(query)
      ...
  }
  ```

  ```swift
  let descriptor = FetchDescriptor<Track>()
  let tracks = try mainContext.fetch(descriptor)
  let genres = Set(tracks.compactMap(\.genre))
  return genres.sorted()
  ```

- **Why this is defective/risky:** the methods are declared `async`, but their actual `ModelContext.fetch` calls are synchronous and explicitly MainActor-isolated. Each debounced standard search performs four fetches serially on the UI actor. Home reload performs many serial main-context fetches, including `getUniqueGenres`, which has no fetch limit and materializes every Track model before extracting one field. Cancellation of the outer search task cannot preempt a synchronous fetch already running. Large libraries therefore scale directly into UI-actor work.
- **Preserving remediation:** use the existing actor-backed repository boundary and return Sendable domain entities/search DTOs, not SwiftData model objects, to views. Add actor methods for search and distinct genre aggregation. Search categories may run concurrently only if they use independent actor/context instances; otherwise off-main serialization is still preferable to MainActor blocking.
- **Unapplied direction:**

  ```swift
  public actor SwiftDataSearchRepository {
      private let container: ModelContainer

      public init(container: ModelContainer) { self.container = container }

      public func tracks(query: String, limit: Int) throws -> [TrackEntity] {
          let context = ModelContext(container)
          var descriptor = FetchDescriptor<Track>(/* existing predicate/sort */)
          descriptor.fetchLimit = limit
          return try context.fetch(descriptor).map(TrackEntity.init(track:))
      }
  }
  ```

  Build one aggregate `SearchEntityResults: Sendable`, check cancellation between category fetches, and make Home consume entity pages/aggregates. Do not send `Track`/`Album` SwiftData objects across the actor boundary.
- **Verification / acceptance:** create an on-disk 10k/50k-track fixture with representative metadata. Use Time Profiler and Hangs while typing, clearing, and rapidly replacing queries and while revisiting Home. Acceptance: no `ModelContext.fetch` or full-track genre scan appears on the main thread; canceled queries do not publish stale results; first useful results meet a product-defined device budget.
- **Related:** CP-014, CP-016.

### CP-009 — Widget artwork processing and file maintenance run on the MainActor

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Shared/WidgetArtworkCache.swift:12-15,53-84,89-97,207-256,264-283,286-303`
  - `Fonic HiFi/Core/Services/WidgetDataCoordinator.swift:206-252`
- **Source excerpt:**

  ```swift
  @MainActor
  public final class WidgetArtworkCache {
  ```

  ```swift
  guard let thumbnail = image.resized(...),
        let data = thumbnail.jpegData(compressionQuality: ...)
  ...
  try data.write(to: fileURL, options: .atomic)
  accessDates[key] = Date()
  saveAccessDates()

  Task {
      await enforceCacheLimit()
  }
  ```

  ```swift
  let contents = try fileManager.contentsOfDirectory(...)
  ...
  let data = try? PropertyListEncoder().encode(accessDates)
  try? data.write(to: url, options: .atomic)
  ```

- **Why this is defective/risky:** on a current-track change, the coordinator awaits artwork data and calls this MainActor singleton. It decodes `UIImage`, renders a thumbnail, compresses JPEG, writes it atomically, re-encodes/writes the complete access-date dictionary, then starts a `Task` that inherits MainActor isolation and may enumerate/stat every cache file. This work sits on the same actor as playback controls and SwiftUI. The `async` label on `enforceCacheLimit` does not move its synchronous work off the MainActor.
- **Preserving remediation:** make the cache an actor that accepts/returns Sendable values (`Data`, UUID, String), lazily prepares its directory inside the actor, and performs sizing/eviction in the same owned operation. Keep only final UI state publication on MainActor. Coalesce access-date persistence and avoid a full directory scan after every write by maintaining a byte counter updated on insert/remove.
- **Unapplied direction:**

  ```swift
  actor WidgetArtworkCache {
      static let shared = WidgetArtworkCache()
      private var cachedByteCount: Int64 = 0
      private var accessDates: [String: Date] = [:]

      func storeArtworkData(_ source: Data, forTrackId id: UUID) throws -> String {
          try Task.checkCancellation()
          // Decode, resize, encode and write entirely inside this actor.
          // Update cachedByteCount from the replacement/new file size.
          // Evict only when the tracked total crosses the limit.
          return id.uuidString
      }
  }
  ```

  `WidgetDataCoordinator.cacheArtwork` is already async and can use `try await artworkCache.storeArtworkData(...)` without moving image work back to MainActor.
- **Verification / acceptance:** use Time Profiler, Hangs, Allocations, and File Activity while rapidly skipping among tracks with large embedded art. Acceptance: no image rendering/JPEG/plist/directory walk appears on the main thread; one bounded write sequence occurs per uncached track; cache byte accounting remains correct across replacement, eviction, relaunch, and memory warning.
- **Related:** CP-006, CP-010.

### CP-010 — Artwork cache limits entries, not memory cost

- **Severity:** Medium
- **Confidence:** Probable
- **Code:**
  - `Fonic HiFi/Core/Services/ArtworkService.swift:64-71,85-118,121-137,150-157`
  - `Fonic HiFi/Presentation/Views/Shared/LazyArtworkView.swift:28-32,93-122,141-153`
- **Source excerpt:**

  ```swift
  private var cache: [String: Data] = [:]
  private let maxCacheSize = 100
  ```

  ```swift
  if let artwork {
      maintainCacheSize()
      cache[key] = artwork
  }
  ```

  ```swift
  if let data = artworkData, let uiImage = UIImage(data: data) {
      Image(uiImage: uiImage)
  }
  ```

- **Why this is defective/risky:** the cache admits up to 100 full encoded blobs regardless of byte size. Embedded artwork size is uncontrolled by this code, so the memory ceiling is not actually bounded. Each visible `LazyArtworkView` also retains the returned Data in `@State` and constructs a new `UIImage(data:)` during body evaluation. The source proves the absence of cost accounting; the actual memory footprint and decode residency require Allocations/device validation, so impact is labeled probable rather than measured.
- **Preserving remediation:** use cost-based eviction (`NSCache.totalCostLimit` or a custom byte-budget actor), cache display-sized decoded thumbnails for UI surfaces, and handle memory warnings by evicting. Keep original artwork in persistence, not simultaneously in a 100-entry process cache unless its bytes count against a defined budget.
- **Unapplied sample:**

  ```swift
  private let cache: NSCache<NSString, NSData> = {
      let cache = NSCache<NSString, NSData>()
      cache.totalCostLimit = 32 * 1024 * 1024 // Tune from device evidence.
      return cache
  }()

  private func store(_ data: Data, key: String) {
      cache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
  }
  ```

  For best results, decode/downsample off-main once in `loadArtwork()` and store a `UIImage`/`Image` state rather than reconstructing it in `body`. The budget value must be validated on supported devices; it is not a claimed universal optimum.
- **Verification / acceptance:** use 100 small and 100 multi-megabyte art samples, scroll repeatedly, switch tracks, and trigger a memory warning. Acceptance: cache cost stays under the chosen budget, off-screen images release, warning handling drops residency, and decoded-image growth plateaus without visible re-decoding stalls.
- **Related:** CP-009, CP-011.

### CP-011 — SwiftUI bodies materialize arrays during every library/queue evaluation

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Presentation/Views/Library/LibraryView.swift:195-208,217-240,250-281`
  - `Fonic HiFi/Presentation/Views/Queue/QueueView.swift:31-49`
  - `Fonic HiFi/Core/Audio/Queue/QueueState.swift:70-79`
- **Source excerpt:**

  ```swift
  ForEach(Array(viewModel.tracks.enumerated()), id: \.element.id) { index, track in
  ```

  ```swift
  let remaining = audioService?.queueManager.queueState.remainingTracks ?? []
  ...
  ForEach(Array(remaining.enumerated()), id: \.element.id) { _, track in
  ```

  ```swift
  return Array(tracks[(currentIndex + 1)...])
  ```

- **Why this is defective/risky:** all four paginated library sections allocate a new `(offset, element)` array whenever their view builder runs. Queue does two materializations: `remainingTracks` copies the suffix into a new array, then `Array(enumerated())` creates another. These allocations scale with every page accumulated in the view model or every queued track, even though SwiftUI needs only lazy collection traversal and stable element IDs.
- **Preserving remediation:** iterate the underlying identifiable collection directly. For pagination, expose a stable prefetch trigger ID or an index-aware wrapper created only when page state changes, not in `body`. For Queue, iterate an `ArraySlice` or the original array indices without first copying the suffix.
- **Unapplied sample:**

  ```swift
  ForEach(viewModel.tracks) { track in
      TrackEntityRow(track: track) { selectedTrack = track }
          .onAppear {
              if track.id == viewModel.trackPrefetchTriggerID {
                  loadNextPage(for: .tracks)
              }
          }
  }
  ```

  ```swift
  let state = audioService?.queueManager.queueState
  let start = min((state?.currentIndex ?? -1) + 1, state?.tracks.count ?? 0)
  if let tracks = state?.tracks {
      ForEach(tracks[start...]) { track in
          QueueRowView(track: track, isPlaying: false)
      }
  }
  ```

  Confirm `ArraySlice`/`ForEach` type inference in Xcode and keep IDs based on track identity.
- **Verification / acceptance:** use the SwiftUI instrument plus Allocations while scrolling 10k library rows page-by-page and opening a 10k-track queue. Acceptance: no render-path allocations are attributed to `Array(enumerated())` or `remainingTracks`; row identity remains stable across appends, moves, and deletes; pagination still triggers once per threshold.
- **Related:** CP-003, CP-010, CP-016.

### CP-012 — Optional diagnostics retain unbounded samples and start a no-op poller

- **Severity:** Low
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Core/Audio/Diagnostics/PerformanceMonitor.swift:100-126,140-171,210-231,295-315`
  - `Fonic HiFi/Core/Audio/Diagnostics/AudioMonitor.swift:194-197`
  - `Fonic HiFi/Core/Audio/Diagnostics/AudioMonitorEngineHooks.swift:50-83`
  - `Fonic HiFi/Core/Audio/Interfaces/AudioEngineService.swift:139-142`
  - `Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift:240-253`
  - `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift:119-127,280-286`
- **Source excerpt:**

  ```swift
  private var audioLatencies: [TimeInterval] = []
  private var memoryUsages: [Int64] = []
  private var searchLatencies: [(duration: TimeInterval, resultCount: Int)] = []
  private var importMetrics: [ImportMetrics] = []
  private var errors: [(error: Error, context: String, timestamp: Date)] = []
  ```

  ```swift
  await runtime.startMonitoring(...)
  engineHooks.startMonitoring(interval: updateInterval)
  ```

  ```swift
  await currentEngine.collectMetrics()
  ```

  ```swift
  func collectMetrics() async {
      // Optional implementation
  }
  ```

- **Why this is defective/risky:** when runtime monitoring is enabled, every periodic sample is appended with no cap until `reset()` is called. Error arrays can retain arbitrary error object graphs. In parallel, `AudioMonitor` starts `AudioMonitorEngineHooks`; it wakes and calls `collectMetrics`, but the protocol default is no-op and AudioKit explicitly implements an empty method. AVAudioEngineAdapter uses the default. Thus the second poller performs no engine collection in the current shipping implementations. Release defaults monitoring off, which limits severity, but Debug defaults on and the UserDefaults gate can enable it.
- **Preserving remediation:** use bounded ring buffers or online aggregates for latency/memory/search/import/error metrics; retain only the recent diagnostic window needed by reports. Remove `engineHooks` polling until an implementation provides meaningful collection, or add an explicit capability flag so no task starts for no-op engines.
- **Unapplied direction:** cap raw history (for example, a configurable recent 2,048-sample ring) and maintain count/sum/min/max plus a bounded quantile sketch. Never use a product-independent constant without profiling. Change `collectMetrics` to a required meaningful API or expose `supportsPeriodicMetricCollection`; only start hooks when true.
- **Verification / acceptance:** enable runtime monitoring and run long playback plus repeated errors/searches/imports under Allocations and Energy Log. Acceptance: retained sample/error counts plateau at configured bounds; reports remain correct; no `AudioMonitorEngineHooks.pollMetrics` wake appears for current no-op engines; disabled Release monitoring schedules no diagnostics timer.
- **Related:** CP-007.

### CP-013 — Deferred startup work is unowned and cancellation-blind

- **Severity:** Low
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/FonicHiFiApp.swift:103-113,194-229`
- **Source excerpt:**

  ```swift
  .task {
      await initializeApp()
  }
  ```

  ```swift
  Task {
      try? await Task.sleep(for: .seconds(3))
      let removedCount = try await dataManager.cleanupMissingFiles()
      ...
  }
  ```

  Three similar tasks are started at 3, 5, and 8 seconds.
- **Why this is defective/risky:** `performStartupTasks` discards all three handles. They are not children of the SwiftUI `.task` for cancellation purposes. More importantly, `try?` swallows `CancellationError`; if a task is canceled during its delay, it proceeds immediately into cleanup/statistics/backfill instead of stopping. A later root-view task invocation can schedule another set because the audio-service initialization guard does not guard maintenance scheduling.
- **Preserving remediation:** put deferred maintenance in a long-lived coordinator that owns handles, prevents duplicate scheduling, catches cancellation separately, and cancels on teardown/background policy. Keep it fire-and-forget so launch timing remains honest, but make ownership explicit.
- **Unapplied sample:**

  ```swift
  @MainActor
  final class StartupMaintenanceCoordinator {
      private var tasks: [Task<Void, Never>] = []
      private var scheduled = false

      func schedule(using dataManager: DataManager) {
          guard !scheduled else { return }
          scheduled = true
          tasks = [3, 5, 8].map { delay in
              Task { [weak dataManager] in
                  do {
                      try await Task.sleep(for: .seconds(delay))
                      try Task.checkCancellation()
                      guard let dataManager else { return }
                      // Dispatch the existing operation selected for this delay.
                  } catch is CancellationError {
                      return
                  } catch {
                      Log.logger(.appLifecycle).error("Startup maintenance failed: \(error.localizedDescription)")
                  }
              }
          }
      }

      func cancel() {
          tasks.forEach { $0.cancel() }
          tasks.removeAll()
      }
  }
  ```

  In production, use one typed operation per task rather than the illustrative delay array.
- **Verification / acceptance:** invoke initialization twice and assert one cleanup/statistics/backfill schedule. Cancel during each delay and assert zero underlying operations. Acceptance: cancellation never accelerates maintenance, and no duplicate full-library work is queued.
- **Related:** CP-008, CP-014.

### CP-014 — Pagination implements total count by fetching all models on every page

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Data/Repositories/SwiftDataLibraryRepository.swift:29-51,54-83,86-113,116-135`
  - `Fonic HiFi/Data/Repositories/PaginatedFetch.swift:10-34`
  - `Fonic HiFi/Data/Extensions/SwiftDataPagination.swift:55-82`
- **Source excerpt:**

  ```swift
  let fetch = PaginatedModelFetch(
      descriptor: descriptor,
      page: page,
      pageSize: pageSize,
      includeTotalCount: true,
  )
  ```

  ```swift
  let totalCount: Int? = if includeTotalCount {
      try context.batchedFetchCount(descriptor.removingPagination())
  } else {
      nil
  }
  ```

  ```swift
  while true {
      ...
      let batch = try fetch(countingDescriptor)
      total += batch.count
      ...
  }
  ```

- **Why this is defective/risky:** every page request for tracks, albums, artists, and playlists sets `includeTotalCount: true`. The custom “count” loops through the entire matching dataset in batches of 512 and fetches model objects. The active view model never reads `Page.totalCount`; it only uses `items`, `nextPage`, and `hasMore`. Consequently each incremental page can rescan the whole table for a value the UI discards, producing near-quadratic cumulative work as a user pages through a large library.
- **Preserving remediation:** set `includeTotalCount: false` for active pages because the result is unused. If a future UI needs a count, call SwiftData's count API once for page zero/cache invalidation and cache it independently; do not fetch models to count rows.
- **Unapplied minimal fix:** remove `includeTotalCount: true` (or set it to `page == 0` only if a caller is added) in all four repository methods. Replace `batchedFetchCount` with the toolchain-verified `ModelContext.fetchCount(_:)` API for genuine count requests.
- **Verification / acceptance:** add a repository spy that records fetch calls and prove page N performs one `pageSize + 1` item fetch and no count scan. Under an on-disk 50k library, profile loading 20 pages. Acceptance: work per page is bounded by page size, `hasMore` remains correct, and count is computed only when explicitly requested.
- **Related:** CP-008, CP-016.

### CP-015 — File Manager uses synchronous UI-context I/O and an uncancellable detached copy

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Presentation/Views/Settings/FileManagerView.swift:39-55,162-175,195-234,265-275,290-342`
- **Source excerpt:**

  ```swift
  let contents = try FileManager.default.contentsOfDirectory(...)
  for url in contents {
      let resourceValues = try url.resourceValues(...)
      ...
  }
  ```

  ```swift
  await withCheckedContinuation { continuation in
      Task.detached(priority: .utility) {
          defer { continuation.resume() }
          ...
          try fm.copyItem(at: sourceURL, to: targetURL)
      }
  }
  ```

- **Why this is defective/risky:** directory enumeration/resource-value reads and deletion are synchronous inside view-owned async methods, with no isolated file-I/O service. The copy path moves one operation to `Task.detached`, but discards the task handle and bridges it through a nonthrowing continuation. Parent/view cancellation cannot cancel the detached task or the continuation wait, and copy errors are logged then converted into apparent success. Navigating away or canceling the initiating SwiftUI task can therefore leave large copies running and the caller cannot distinguish completion from failure.
- **Preserving remediation:** move listing, delete, unique-name selection, and copy into one dedicated file-operations actor/service with throwing APIs. Check cancellation before each file and after copy; if cancellation arrives after a completed copy but before commit, remove the destination according to product policy. For truly interruptible large-file copy, use bounded chunked `FileHandle` I/O rather than `FileManager.copyItem`.
- **Unapplied direction:**

  ```swift
  actor FileOperations {
      func copy(_ source: URL, to destination: URL) throws {
          try Task.checkCancellation()
          let accessed = source.startAccessingSecurityScopedResource()
          defer { if accessed { source.stopAccessingSecurityScopedResource() } }
          try FileManager.default.copyItem(at: source, to: destination)
          try Task.checkCancellation()
      }

      func list(_ directory: URL) throws -> [FileItem] {
          // Existing contents/resourceValues loop, isolated off MainActor.
      }
  }
  ```

  The view should call `try await operations.copy(...)`, surface the error, and let its structured task cancellation stop before the next file. Compile validation is required because `FileItem` visibility/Sendable conformance must be adjusted.
- **Verification / acceptance:** inject a slow/chunked copier, cancel while copying many files, dismiss the view, and inspect destination/security-scope balances. Acceptance: no new copy starts after cancellation, errors reach UI state, no continuation hangs, listing/deletion/copy stacks are absent from the main thread, and partial-file policy is deterministic.
- **Related:** CP-001, CP-002.

### CP-016 — Render paths rebuild formatters and full sort/filter results

- **Severity:** Medium
- **Confidence:** Confirmed by static evidence
- **Code:**
  - `Fonic HiFi/Presentation/Views/Library/LibraryView.swift:195-208,378-417`
  - `Fonic HiFi/Domain/Entities/LibraryEntities.swift:80-91`
  - `Fonic HiFi/Presentation/Views/Settings/FileManagerView.swift:39-55,103-106,434-436`
- **Source excerpt:**

  ```swift
  ForEach(Array(viewModel.tracks.enumerated()), id: \.element.id) { index, track in
      TrackEntityRow(track: track) { ... }
  }
  ```

  ```swift
  public var formattedFileSize: String {
      let formatter = ByteCountFormatter()
      formatter.allowedUnits = [.useKB, .useMB, .useGB]
      formatter.countStyle = .file
      return formatter.string(fromByteCount: fileSize)
  }
  ```

  ```swift
  private var filteredContents: [FileItem] {
      let filtered = ... directoryContents.filter { ... }
      return filtered.sorted { ... }
  }
  ```

- **Why this is defective/risky:** CP-011 covers the explicit array materialization. The row path then creates a new `ByteCountFormatter` whenever `formattedFileSize` is read, and File Manager filters plus sorts the complete directory every time its view recomputes. These are deterministic render-path allocations/work that scale with accumulated pages or directory size and are triggered by unrelated local state changes such as selection/loading. No runtime duration is claimed; the source proves repeated construction and full-collection transforms in view evaluation.
- **Preserving remediation:** precompute display strings in immutable entities when mapping a fetched page, use `ByteCountFormatStyle` or a shared immutable formatting helper, and cache File Manager's sorted/filtered result when directory/search/sort inputs change rather than recomputing from every body evaluation. Apply CP-011's direct collection iteration.
- **Unapplied sample:**

  ```swift
  public var formattedFileSize: String {
      fileSize.formatted(.byteCount(style: .file))
  }
  ```

  For File Manager, move filtering/sorting into a small `@Observable @MainActor` model method invoked from `onChange` of `directoryContents`, `searchText`, and `sortOption`, or compute it in the file actor and publish one result array.
- **Verification / acceptance:** use SwiftUI and Allocations instruments while selecting rows, typing search text, changing sort, and paging. Acceptance: formatter creation and full sort/filter stacks do not recur for unrelated invalidations; results and locale-aware display remain correct; row identity remains stable.
- **Related:** CP-008, CP-011, CP-014.

---

## Rejected candidate findings

These were investigated and intentionally not retained as production defects.

| Candidate | Exact evidence | Why rejected / residual note |
|---|---|---|
| Production `@unchecked Sendable` is automatically unsafe | `Fonic HiFi/Core/Audio/Engine/AudioPlaybackSettingsStore.swift:5-20` — `private struct DefaultsBox: @unchecked Sendable { let value: UserDefaults }` inside `public actor AudioPlaybackSettingsStore` | This is the only production `@unchecked Sendable`. The box is immutable and every use is actor-isolated. No second mutable owner or cross-actor mutation was found. Retain a comment documenting that invariant and re-evaluate if raw `UserDefaults` escapes; static evidence does not prove a race today. |
| Dominant-color detached tasks race shared state | `Fonic HiFi/Core/Services/DominantColorService.swift:108-137,162-190,237-253` — immutable `artworkData` is captured and `await Task.detached { ... }.value` completes before MainActor cache/state mutation | The detached work is awaited and does not capture the mutable cache. Cancellation propagation could be improved, but no shared mutable race is source-proven. Validate decode cost under CP-010 instead. |
| Audio-session NotificationCenter observers leak | `Fonic HiFi/Core/Audio/Services/AudioSessionManager.swift:342-365,511-513` | Selector observers are registered once behind `hasRegisteredForNotifications` and explicitly removed in `deinit`. Remote-command target lifecycle is a separate functional review, not a proven observer retain cycle here. |
| Glass memory-warning observer retains the singleton | `Fonic HiFi/Presentation/Views/Components/GlassModifiers.swift:437-484` — singleton lifetime and `[weak self]` capture | The observer token is not removed, but the owner is intentionally process-lifetime and the closure is weak. No cycle or per-instance accumulation is proven. |
| SearchCache's cleanup task is a shipping leak | `Fonic HiFi/Data/Services/SearchCache.swift:101-115,259-269` — stored looping task strongly uses `self`; repository-wide production search found no `SearchCache(` instantiation outside tests | If wired into production, this is a self-owned infinite-task cycle and must gain explicit ownership/termination. It is not on an active app path in this snapshot, so it was rejected rather than presented as user impact. |
| Legacy `@Query` library grids eagerly load active tables | `Fonic HiFi/Presentation/Views/Library/AlbumGridView.swift:133`, `Fonic HiFi/Presentation/Views/Library/ArtistListView.swift:126-127`, `Fonic HiFi/Presentation/Views/Library/PlaylistListView.swift:138`; each type is referenced only by its own preview (`Fonic HiFi/Presentation/Views/Library/AlbumGridView.swift:293`, `Fonic HiFi/Presentation/Views/Library/ArtistListView.swift:280`, `Fonic HiFi/Presentation/Views/Library/PlaylistListView.swift:516`) | Active `ContentView` uses `LibraryView` with `LibraryViewModel`/repository pagination. The eager `@Query` views are orphaned/preview-only in this snapshot; they should be removed or kept out of target membership, but they do not prove active runtime cost. |
| Audio render tap always allocates Tasks | `Fonic HiFi/Core/Audio/Engines/AVAudioEngineAdapter.swift:574-582` — a Task is created only when `buffer.frameLength == 0` | Allocation from an audio callback is a valid real-time concern, but callback frequency/thread behavior and whether zero-length callbacks occur require device/System Trace evidence. Kept as an open device check, not a measured defect. |
| Profiling timeout definitely stops a later profile in production | `Fonic HiFi/Core/Audio/Diagnostics/AudioMonitorRuntime.swift:104-120` stores no timeout task handle | The ownership bug is plausible, but no active production UI caller of `startProfiling` exists in this snapshot; only the monitor forwarding API/tests call it. If diagnostics UI exposes profiling, store/cancel a timeout handle and generation token before release. |
| `@preconcurrency` imports alone prove Sendable violations | `Fonic HiFi/Data/Services/MetadataExtractionService.swift:8`, `Fonic HiFi/Core/Audio/Engines/AudioKitEngineAdapter.swift:8`, `Fonic HiFi/Core/Audio/Services/AudioFormatDetectionManager.swift:8` | `@preconcurrency` suppresses imported-module checking but is not itself evidence of a race. The audited captures are immutable or actor/MainActor-confined. Xcode strict-concurrency rebuild remains required. |

## Open build/device checks

These checks are deliberately separate from static findings. None was performed here.

1. **Strict-concurrency build gate:** with the release Xcode 26.x toolchain, build every target in Debug and Release with Swift 6, `SWIFT_STRICT_CONCURRENCY=complete`, warnings as errors, and concurrency runtime checks. Acceptance: no actor-isolation, sending, non-Sendable capture, or `@preconcurrency` diagnostic is waived without a documented invariant.
2. **Swift Concurrency instrument:** exercise cancellation during saturated format detection, import cancellation, rapid track switching, startup teardown, and AudioKit playback. Look for suspended canceled tasks, task fan-out, executor hops, and actors with long jobs.
3. **Thread Sanitizer (simulator where supported):** stress simultaneous duplicate imports, rapid engine changes, remote commands, queue mutations, and widget synchronization. TSan silence does not replace the logical duplicate-race tests in CP-004.
4. **Time Profiler + Hangs:** run Home, standard Search, File Manager, queue edits, widget artwork updates, and queue restore with 10k/50k-track on-disk libraries. Confirm the main-thread stacks called out in CP-003/008/009/015 are gone after fixes.
5. **Allocations + Leaks + Memory Graph:** scroll artwork-heavy libraries, repeatedly present/dismiss Queue/File Manager/Now Playing, enable diagnostics for long playback, and reconstruct app services in a test harness. Confirm widget coordinator, caches, task closures, errors, and histories plateau/deallocate.
6. **SwiftUI instrument:** record body updates for `ContentView`, Library rows, Queue, artwork views, and File Manager. Verify CP-011/016 fixes remove array/formatter/sort churn and that only relevant subtrees invalidate on playback progress.
7. **File Activity instrument:** capture queue mutation/pause/skip, widget artwork insertion/eviction, directory browsing, and import cancellation. Acceptance: queue writes are coalesced/off-main, cache maintenance is bounded, and canceled work stops producing files.
8. **Energy Log/System Trace on physical device:** compare idle, foreground playback, and background audio for AVAudioEngine and AudioKit before/after CP-006/007/012. Do not set a pass/fail number until a product/device energy budget is defined; acceptance is removal of the identified periodic/no-op wake sources without playback regressions.
9. **Audio-device matrix:** verify wired/USB DAC, Bluetooth, AirPlay, speaker, interruption, route change, lock screen, background, remote commands, gapless boundaries, crossfade, and natural completion while the concurrency/performance fixes are present.
10. **Memory-warning/thermal/Low Power Mode:** trigger warnings and thermal states with artwork-heavy playback and diagnostics enabled. Verify cache eviction, polling reduction, and uninterrupted audio; collect MetricKit/field diagnostics only after choosing the supported API/toolchain.

## Static acceptance summary

A remediation pass is ready for device validation when all of the following are true:

- cancellation removes semaphore waiters and terminates every stream producer;
- import duplicate identity is claimed atomically before concurrent work starts;
- no self-owned periodic widget task or duplicate AudioKit progress task remains;
- queue mutation, widget artwork processing, search/home fetches, and file browsing perform no synchronous heavy work on MainActor;
- pagination does not fetch model objects to count unused totals;
- diagnostics and artwork caches have byte/sample budgets and deterministic eviction;
- SwiftUI bodies do not materialize collection-sized arrays or rebuild formatters/sorts for unrelated invalidations;
- all fixes compile under the actual Swift 6.2/Xcode 26 release toolchain and pass the separate Instruments/device matrix above.
