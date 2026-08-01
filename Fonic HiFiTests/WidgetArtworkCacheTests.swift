@testable import Fonic_HiFi
import Foundation
import UIKit
import XCTest

@MainActor
final class WidgetArtworkCacheTests: XCTestCase {
    func testStoreAndLoadArtworkRoundTrip() async throws {
        let cache = makeCache()
        let trackId = UUID()
        let sourceData = try makeImageData(
            color: .systemBlue,
            size: CGSize(width: 1000, height: 1000)
        )

        let key = try await cache.storeArtworkData(sourceData, forTrackId: trackId)
        let exists = await cache.hasArtwork(forKey: trackId.uuidString)
        let loadedData = try await cache.loadArtworkData(forKey: trackId.uuidString)
        let size = await cache.cacheSize()

        XCTAssertEqual(key, trackId.uuidString)
        XCTAssertTrue(exists)
        XCTAssertNotNil(loadedData.flatMap(UIImage.init(data:)))
        XCTAssertGreaterThan(size, 0)
    }

    func testStoreArtworkDataRejectsInvalidImageData() async throws {
        let cache = makeCache()
        let key = try await cache.storeArtworkData(
            Data([0xDE, 0xAD, 0xBE, 0xEF]),
            forTrackId: UUID()
        )
        XCTAssertNil(key)
    }

    func testLoadArtworkDataForLiveActivityUsesSmallerPayload() async throws {
        let cache = makeCache()
        let trackId = UUID()
        let sourceData = try makeImageData(
            color: .systemRed,
            size: CGSize(width: 1200, height: 1200)
        )
        _ = try await cache.storeArtworkData(sourceData, forTrackId: trackId)

        let normal = try await cache.loadArtworkData(forKey: trackId.uuidString)
        let live = try await cache.loadArtworkData(
            forKey: trackId.uuidString,
            forLiveActivity: true
        )

        XCTAssertNotNil(normal)
        XCTAssertNotNil(live)
        XCTAssertLessThanOrEqual(live?.count ?? .max, normal?.count ?? .max)
    }

    func testRemoveArtworkDeletesEntry() async throws {
        let cache = makeCache()
        let trackId = UUID()
        let sourceData = try makeImageData(
            color: .systemGreen,
            size: CGSize(width: 700, height: 700)
        )
        _ = try await cache.storeArtworkData(sourceData, forTrackId: trackId)

        let existedBeforeRemoval = await cache.hasArtwork(forKey: trackId.uuidString)
        await cache.removeArtwork(forKey: trackId.uuidString)
        let existsAfterRemoval = await cache.hasArtwork(forKey: trackId.uuidString)
        let loadedAfterRemoval = try await cache.loadArtworkData(forKey: trackId.uuidString)

        XCTAssertTrue(existedBeforeRemoval)
        XCTAssertFalse(existsAfterRemoval)
        XCTAssertNil(loadedAfterRemoval)
    }

    func testRemoveOrphanedArtworkKeepsOnlyValidTrackIds() async throws {
        let cache = makeCache()
        let keepId = UUID()
        let removeId = UUID()
        let sourceData = try makeImageData(
            color: .systemOrange,
            size: CGSize(width: 600, height: 600)
        )

        _ = try await cache.storeArtworkData(sourceData, forTrackId: keepId)
        _ = try await cache.storeArtworkData(sourceData, forTrackId: removeId)
        await cache.removeOrphanedArtwork(validTrackIds: [keepId])

        let kept = await cache.hasArtwork(forKey: keepId.uuidString)
        let removed = await cache.hasArtwork(forKey: removeId.uuidString)
        XCTAssertTrue(kept)
        XCTAssertFalse(removed)
    }

    func testClearCacheRemovesAllFiles() async throws {
        let cache = makeCache()
        let first = UUID()
        let second = UUID()
        let sourceData = try makeImageData(
            color: .purple,
            size: CGSize(width: 800, height: 800)
        )

        _ = try await cache.storeArtworkData(sourceData, forTrackId: first)
        _ = try await cache.storeArtworkData(sourceData, forTrackId: second)
        let sizeBeforeClear = await cache.cacheSize()

        await cache.clearCache()

        let firstExists = await cache.hasArtwork(forKey: first.uuidString)
        let secondExists = await cache.hasArtwork(forKey: second.uuidString)
        let sizeAfterClear = await cache.cacheSize()
        XCTAssertGreaterThan(sizeBeforeClear, 0)
        XCTAssertFalse(firstExists)
        XCTAssertFalse(secondExists)
        XCTAssertEqual(sizeAfterClear, 0)
    }

    func testCacheFilesSurviveActorRelaunch() async throws {
        let directory = makeCacheDirectory()
        let trackId = UUID()
        let sourceData = try makeImageData(
            color: .cyan,
            size: CGSize(width: 500, height: 500)
        )

        let firstInstance = WidgetArtworkCache(cacheDirectory: directory)
        _ = try await firstInstance.storeArtworkData(sourceData, forTrackId: trackId)

        let relaunchedInstance = WidgetArtworkCache(cacheDirectory: directory)
        let exists = await relaunchedInstance.hasArtwork(forKey: trackId.uuidString)
        let loaded = try await relaunchedInstance.loadArtworkData(forKey: trackId.uuidString)

        XCTAssertTrue(exists)
        XCTAssertNotNil(loaded)
    }

    func testProcessingRunsOffMainThread() async throws {
        let sourceData = try makeImageData(
            color: .magenta,
            size: CGSize(width: 900, height: 900)
        )

        let result = try await WidgetArtworkProcessor.makeJPEGThumbnail(
            from: sourceData,
            maxPixelSize: 200,
            compressionQuality: 0.7
        )

        XCTAssertNotNil(result)
        XCTAssertFalse(result?.processedOnMainThread ?? true)
    }

    func testCancellationPropagatesThroughProcessing() async throws {
        let directory = makeCacheDirectory()
        let gate = ArtworkProcessingGate()
        let cache = WidgetArtworkCache(
            cacheDirectory: directory,
            processor: { data, _, _ in
                try await gate.process(data)
            }
        )

        let task = Task {
            try await cache.storeArtworkData(Data([0x01]), forTrackId: UUID())
        }

        try await gate.waitUntilStarted()
        task.cancel()
        await gate.release()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation to propagate")
        } catch is CancellationError {
            // Expected.
        }
    }

    private func makeCache() -> WidgetArtworkCache {
        WidgetArtworkCache(cacheDirectory: makeCacheDirectory())
    }

    private func makeCacheDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WidgetArtworkCacheTests-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }

    private func makeImageData(color: UIColor, size: CGSize) throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return try XCTUnwrap(image.pngData())
    }
}

private actor ArtworkProcessingGate {
    private struct StartWaiter {
        let continuation: CheckedContinuation<Void, Error>
    }

    private var started = false
    private var startWaiters: [UUID: StartWaiter] = [:]
    private var releaseWaiters: [UUID: CheckedContinuation<Void, Error>] = [:]

    func process(_ data: Data) async throws -> WidgetArtworkProcessingResult? {
        started = true
        let waiters = Array(startWaiters.values)
        startWaiters.removeAll()
        waiters.forEach { $0.continuation.resume(returning: ()) }

        let waiterId = UUID()
        try await withArtworkGateTimeout("artwork processor release") {
            try await self.suspendForRelease(waiterId: waiterId)
        }
        try Task.checkCancellation()
        return WidgetArtworkProcessingResult(data: data, processedOnMainThread: false)
    }

    func waitUntilStarted() async throws {
        if started {
            return
        }

        let waiterId = UUID()
        try await withArtworkGateTimeout("artwork processor start") {
            try await self.suspendUntilStarted(waiterId: waiterId)
        }
    }

    func release() {
        let continuations = Array(releaseWaiters.values)
        releaseWaiters.removeAll()
        continuations.forEach { $0.resume(returning: ()) }
    }

    private func suspendUntilStarted(waiterId: UUID) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else if started {
                    continuation.resume(returning: ())
                } else {
                    startWaiters[waiterId] = StartWaiter(continuation: continuation)
                }
            }
        } onCancel: {
            Task { await self.cancelStartWaiter(waiterId) }
        }
    }

    private func suspendForRelease(waiterId: UUID) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    releaseWaiters[waiterId] = continuation
                }
            }
        } onCancel: {
            Task { await self.cancelReleaseWaiter(waiterId) }
        }
    }

    private func cancelStartWaiter(_ waiterId: UUID) {
        startWaiters.removeValue(forKey: waiterId)?.continuation.resume(
            throwing: CancellationError()
        )
    }

    private func cancelReleaseWaiter(_ waiterId: UUID) {
        releaseWaiters.removeValue(forKey: waiterId)?.resume(
            throwing: CancellationError()
        )
    }
}

private enum ArtworkGateError: Error, CustomStringConvertible {
    case timedOut(String)

    var description: String {
        switch self {
        case let .timedOut(operation):
            "Timed out waiting for \(operation)"
        }
    }
}

private func withArtworkGateTimeout<Value: Sendable>(
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
            throw ArtworkGateError.timedOut(operationDescription)
        }

        guard let value = try await group.next() else {
            throw ArtworkGateError.timedOut(operationDescription)
        }
        return value
    }
}
