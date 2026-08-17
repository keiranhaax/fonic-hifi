import Combine
@testable import Fonic_HiFi
import Foundation
import XCTest

@MainActor
final class WidgetDataCoordinatorTests: XCTestCase {
    func testDrivenQueueStreamUpdatesCurrentTrackAndEveryUpNextSnapshot() async {
        let source = WidgetCoordinatorSource()
        let manager = RecordingWidgetSharedStateManager()
        let cache = RecordingWidgetArtworkCache()
        let coordinator = makeCoordinator(
            source: source,
            manager: manager,
            cache: cache
        )
        await coordinator.waitForPendingQueueUpdate()

        let first = makeTrack(title: "First")
        let second = makeTrack(title: "Second")
        let replacement = makeTrack(title: "Replacement")

        source.sendQueue(
            QueueState(
                tracks: [first, second],
                currentIndex: 0,
                repeatMode: .all,
                hasNext: true
            )
        )
        await coordinator.waitForPendingQueueUpdate()

        XCTAssertEqual(manager.trackInfo?.id, first.id)
        XCTAssertEqual(manager.upNextTracks.map(\.id), [second.id])
        XCTAssertEqual(manager.playbackState.repeatMode, "all")
        XCTAssertTrue(manager.playbackState.hasNext)

        // Current identity is unchanged; the queue-derived payload must still update.
        source.sendQueue(
            QueueState(
                tracks: [first, replacement],
                currentIndex: 0,
                repeatMode: .one,
                hasNext: true
            )
        )
        await coordinator.waitForPendingQueueUpdate()

        XCTAssertEqual(manager.trackInfo?.id, first.id)
        XCTAssertEqual(manager.upNextTracks.map(\.id), [replacement.id])
        XCTAssertEqual(manager.playbackState.repeatMode, "one")
    }

    func testIdleCoordinatorCreatesNoPeriodicSleeps() async {
        let source = WidgetCoordinatorSource()
        let manager = RecordingWidgetSharedStateManager()
        let cache = RecordingWidgetArtworkCache()
        let reloadGate = ReloadGate()
        let coordinator = makeCoordinator(
            source: source,
            manager: manager,
            cache: cache,
            reloadDelay: { try await reloadGate.wait() }
        )

        await coordinator.waitForPendingQueueUpdate()
        for _ in 0 ..< 10 {
            await Task.yield()
        }

        let waitCount = await reloadGate.totalWaitCount
        XCTAssertEqual(waitCount, 0)
        XCTAssertEqual(manager.reloadCount, 0)
    }

    func testSupersededArtworkCannotOverwriteNewerTrack() async throws {
        let source = WidgetCoordinatorSource()
        let manager = RecordingWidgetSharedStateManager()
        let cache = RecordingWidgetArtworkCache()
        let artworkGate = ArtworkDataGate()
        let coordinator = makeCoordinator(
            source: source,
            manager: manager,
            cache: cache,
            artworkDataProvider: { trackId in
                await artworkGate.data(for: trackId)
            }
        )
        await coordinator.waitForPendingQueueUpdate()

        let first = makeTrack(title: "First")
        let second = makeTrack(title: "Second")

        source.sendQueue(QueueState(tracks: [first], currentIndex: 0))
        try await artworkGate.waitForRequestCount(1)

        source.sendQueue(QueueState(tracks: [second], currentIndex: 0))
        try await artworkGate.waitForRequestCount(2)

        await artworkGate.resolve(first.id, with: Data([0x01]))
        await artworkGate.resolve(second.id, with: Data([0x02]))
        await coordinator.waitForPendingQueueUpdate()
        for _ in 0 ..< 10 {
            await Task.yield()
        }

        let storedTrackIds = await cache.storedTrackIds
        let gateFailures = await artworkGate.failureMessages
        XCTAssertEqual(manager.trackInfo?.id, second.id)
        XCTAssertEqual(manager.trackInfo?.artworkKey, second.id.uuidString)
        XCTAssertEqual(storedTrackIds, [second.id])
        XCTAssertTrue(gateFailures.isEmpty, gateFailures.joined(separator: "; "))
    }

    func testReloadsAreDebouncedAndGenerationGated() async throws {
        let source = WidgetCoordinatorSource()
        let manager = RecordingWidgetSharedStateManager()
        let cache = RecordingWidgetArtworkCache()
        let reloadGate = ReloadGate()
        let coordinator = makeCoordinator(
            source: source,
            manager: manager,
            cache: cache,
            reloadDelay: { try await reloadGate.wait() }
        )
        await coordinator.waitForPendingQueueUpdate()

        let first = makeTrack(title: "First")
        let second = makeTrack(title: "Second")

        source.sendQueue(QueueState(tracks: [first], currentIndex: 0))
        try await reloadGate.waitForTotalWaitCount(1)

        source.sendQueue(QueueState(tracks: [second], currentIndex: 0))
        try await reloadGate.waitForTotalWaitCount(2)

        await reloadGate.releaseAll()
        await coordinator.waitForPendingReload()
        for _ in 0 ..< 10 {
            await Task.yield()
        }

        let gateFailures = await reloadGate.failureMessages
        XCTAssertEqual(manager.reloadCount, 1)
        XCTAssertTrue(gateFailures.isEmpty, gateFailures.joined(separator: "; "))
    }

    func testAwaitedSyncUsesLatestProvidersForIntentCallers() async {
        let source = WidgetCoordinatorSource()
        let manager = RecordingWidgetSharedStateManager()
        let cache = RecordingWidgetArtworkCache()
        let coordinator = makeCoordinator(
            source: source,
            manager: manager,
            cache: cache
        )
        await coordinator.waitForPendingQueueUpdate()

        let track = makeTrack(title: "Intent Track")
        source.queueState = QueueState(
            tracks: [track],
            currentIndex: 0,
            repeatMode: .all
        )
        source.playbackState = .playing(currentTime: 12, duration: 120)

        await coordinator.syncCurrentState()

        XCTAssertEqual(manager.trackInfo?.id, track.id)
        XCTAssertTrue(manager.playbackState.isPlaying)
        XCTAssertEqual(manager.playbackState.currentTime, 12)
        XCTAssertEqual(manager.playbackState.repeatMode, "all")
        XCTAssertFalse(coordinator.isSyncing)
        XCTAssertNotNil(coordinator.lastSyncDate)
    }

    private func makeCoordinator(
        source: WidgetCoordinatorSource,
        manager: RecordingWidgetSharedStateManager,
        cache: RecordingWidgetArtworkCache,
        artworkDataProvider: (@MainActor @Sendable (UUID) async -> Data?)? = nil,
        reloadDelay: @escaping @Sendable () async throws -> Void = {}
    ) -> WidgetDataCoordinator {
        WidgetDataCoordinator(
            playbackStateProvider: { source.playbackState },
            playbackStatePublisher: source.playbackPublisher,
            queueStateProvider: { source.queueState },
            queueStatePublisher: source.queuePublisher,
            artworkDataProvider: artworkDataProvider,
            appGroupManager: manager,
            artworkCache: cache,
            reloadDelay: reloadDelay
        )
    }

    private func makeTrack(title: String) -> AudioTrack {
        AudioTrack(
            title: title,
            artist: "Artist",
            album: "Album",
            url: FileManager.default.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString).flac"),
            duration: 180,
            audioFormat: "FLAC"
        )
    }
}

@MainActor
private final class WidgetCoordinatorSource {
    var playbackState: PlaybackState = .idle
    var queueState = QueueState()

    private let playbackSubject = PassthroughSubject<PlaybackStateChange, Never>()
    private let queueSubject = PassthroughSubject<QueueState, Never>()

    var playbackPublisher: AnyPublisher<PlaybackStateChange, Never> {
        playbackSubject.eraseToAnyPublisher()
    }

    var queuePublisher: AnyPublisher<QueueState, Never> {
        queueSubject.eraseToAnyPublisher()
    }

    func sendQueue(_ state: QueueState) {
        queueState = state
        queueSubject.send(state)
    }
}

@MainActor
private final class RecordingWidgetSharedStateManager: WidgetSharedStateManaging {
    private(set) var playbackState = WidgetPlaybackState.idle
    private(set) var trackInfo: WidgetTrackInfo?
    private(set) var upNextTracks: [WidgetTrackInfo] = []
    private(set) var reloadCount = 0

    @discardableResult
    func updatePlaybackState(_ state: WidgetPlaybackState) -> Bool {
        guard !isMeaningfullyEqual(playbackState, state) else { return false }
        playbackState = state
        return true
    }

    @discardableResult
    func updateTrackInfo(_ track: WidgetTrackInfo?) -> Bool {
        guard track != trackInfo else { return false }
        trackInfo = track
        return true
    }

    @discardableResult
    func updateUpNextTracks(_ tracks: [WidgetTrackInfo]) -> Bool {
        guard tracks != upNextTracks else { return false }
        upNextTracks = tracks
        return true
    }

    func loadTrackInfo() -> WidgetTrackInfo? {
        trackInfo
    }

    func loadUpNextTracks() -> [WidgetTrackInfo] {
        upNextTracks
    }

    func reloadWidgetTimelines() {
        reloadCount += 1
    }

    private func isMeaningfullyEqual(
        _ lhs: WidgetPlaybackState,
        _ rhs: WidgetPlaybackState
    ) -> Bool {
        lhs.isPlaying == rhs.isPlaying
            && lhs.hasNext == rhs.hasNext
            && lhs.hasPrevious == rhs.hasPrevious
            && lhs.shuffleEnabled == rhs.shuffleEnabled
            && lhs.repeatMode == rhs.repeatMode
            && abs(lhs.duration - rhs.duration) < 0.1
    }
}

private actor RecordingWidgetArtworkCache: WidgetArtworkCaching {
    private var keys = Set<String>()
    private(set) var storedTrackIds: [UUID] = []

    func existingArtworkKeys(for trackIds: [UUID]) async -> Set<String> {
        keys.intersection(trackIds.map(\.uuidString))
    }

    func storeArtworkData(_: Data, forTrackId trackId: UUID) async throws -> String? {
        try Task.checkCancellation()
        storedTrackIds.append(trackId)
        keys.insert(trackId.uuidString)
        return trackId.uuidString
    }
}

private actor ArtworkDataGate {
    private struct DataWaiter {
        let trackId: UUID
        let continuation: CheckedContinuation<Data?, Error>
    }

    private struct CountWaiter {
        let expectedCount: Int
        let continuation: CheckedContinuation<Void, Error>
    }

    private var dataWaiters: [UUID: DataWaiter] = [:]
    private var requestCount = 0
    private var countWaiters: [UUID: CountWaiter] = [:]
    private(set) var failureMessages: [String] = []

    func data(for trackId: UUID) async -> Data? {
        requestCount += 1
        resumeSatisfiedCountWaiters()

        let waiterId = UUID()
        do {
            return try await withAsyncGateTimeout("artwork data request") {
                try await self.suspendForData(trackId: trackId, waiterId: waiterId)
            }
        } catch is CancellationError {
            return nil
        } catch {
            failureMessages.append(String(describing: error))
            return nil
        }
    }

    func waitForRequestCount(_ expectedCount: Int) async throws {
        guard requestCount < expectedCount else { return }

        let waiterId = UUID()
        try await withAsyncGateTimeout("artwork request count \(expectedCount)") {
            try await self.suspendForRequestCount(
                expectedCount,
                waiterId: waiterId
            )
        }
    }

    func resolve(_ trackId: UUID, with data: Data?) {
        let waiterIds = dataWaiters.compactMap { waiterId, waiter in
            waiter.trackId == trackId ? waiterId : nil
        }
        for waiterId in waiterIds {
            dataWaiters.removeValue(forKey: waiterId)?.continuation.resume(returning: data)
        }
    }

    private func suspendForData(trackId: UUID, waiterId: UUID) async throws -> Data? {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    dataWaiters[waiterId] = DataWaiter(
                        trackId: trackId,
                        continuation: continuation
                    )
                }
            }
        } onCancel: {
            Task { await self.cancelDataWaiter(waiterId) }
        }
    }

    private func suspendForRequestCount(
        _ expectedCount: Int,
        waiterId: UUID
    ) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else if requestCount >= expectedCount {
                    continuation.resume(returning: ())
                } else {
                    countWaiters[waiterId] = CountWaiter(
                        expectedCount: expectedCount,
                        continuation: continuation
                    )
                }
            }
        } onCancel: {
            Task { await self.cancelCountWaiter(waiterId) }
        }
    }

    private func cancelDataWaiter(_ waiterId: UUID) {
        dataWaiters.removeValue(forKey: waiterId)?.continuation.resume(
            throwing: CancellationError()
        )
    }

    private func cancelCountWaiter(_ waiterId: UUID) {
        countWaiters.removeValue(forKey: waiterId)?.continuation.resume(
            throwing: CancellationError()
        )
    }

    private func resumeSatisfiedCountWaiters() {
        let waiterIds = countWaiters.compactMap { waiterId, waiter in
            waiter.expectedCount <= requestCount ? waiterId : nil
        }
        for waiterId in waiterIds {
            countWaiters.removeValue(forKey: waiterId)?.continuation.resume(returning: ())
        }
    }
}

private actor ReloadGate {
    private struct CountWaiter {
        let expectedCount: Int
        let continuation: CheckedContinuation<Void, Error>
    }

    private var waitContinuations: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var countWaiters: [UUID: CountWaiter] = [:]
    private(set) var totalWaitCount = 0
    private(set) var failureMessages: [String] = []

    func wait() async throws {
        totalWaitCount += 1
        resumeSatisfiedCountWaiters()

        let waiterId = UUID()
        do {
            try await withAsyncGateTimeout("widget reload delay") {
                try await self.suspendForRelease(waiterId: waiterId)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            failureMessages.append(String(describing: error))
            throw error
        }
    }

    func waitForTotalWaitCount(_ expectedCount: Int) async throws {
        guard totalWaitCount < expectedCount else { return }

        let waiterId = UUID()
        try await withAsyncGateTimeout("reload wait count \(expectedCount)") {
            try await self.suspendForWaitCount(
                expectedCount,
                waiterId: waiterId
            )
        }
    }

    func releaseAll() {
        let continuations = Array(waitContinuations.values)
        waitContinuations.removeAll()
        continuations.forEach { $0.resume(returning: ()) }
    }

    private func suspendForRelease(waiterId: UUID) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    waitContinuations[waiterId] = continuation
                }
            }
        } onCancel: {
            Task { await self.cancelReleaseWaiter(waiterId) }
        }
    }

    private func suspendForWaitCount(
        _ expectedCount: Int,
        waiterId: UUID
    ) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else if totalWaitCount >= expectedCount {
                    continuation.resume(returning: ())
                } else {
                    countWaiters[waiterId] = CountWaiter(
                        expectedCount: expectedCount,
                        continuation: continuation
                    )
                }
            }
        } onCancel: {
            Task { await self.cancelCountWaiter(waiterId) }
        }
    }

    private func cancelReleaseWaiter(_ waiterId: UUID) {
        waitContinuations.removeValue(forKey: waiterId)?.resume(
            throwing: CancellationError()
        )
    }

    private func cancelCountWaiter(_ waiterId: UUID) {
        countWaiters.removeValue(forKey: waiterId)?.continuation.resume(
            throwing: CancellationError()
        )
    }

    private func resumeSatisfiedCountWaiters() {
        let waiterIds = countWaiters.compactMap { waiterId, waiter in
            waiter.expectedCount <= totalWaitCount ? waiterId : nil
        }
        for waiterId in waiterIds {
            countWaiters.removeValue(forKey: waiterId)?.continuation.resume(returning: ())
        }
    }
}

private enum AsyncGateError: Error, CustomStringConvertible {
    case timedOut(String)

    var description: String {
        switch self {
        case let .timedOut(operation):
            "Timed out waiting for \(operation)"
        }
    }
}

private func withAsyncGateTimeout<Value: Sendable>(
    _ operationDescription: String,
    timeout: Duration = .seconds(2),
    operation: @escaping @Sendable () async throws -> Value
) async throws -> Value {
    try await withThrowingTaskGroup(of: Value.self) { group in
        defer { group.cancelAll() }

        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(for: timeout)
            throw AsyncGateError.timedOut(operationDescription)
        }

        guard let value = try await group.next() else {
            throw AsyncGateError.timedOut(operationDescription)
        }
        return value
    }
}
