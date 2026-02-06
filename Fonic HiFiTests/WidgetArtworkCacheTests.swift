import Foundation
import UIKit
import XCTest

@testable import Fonic_HiFi

@MainActor
final class WidgetArtworkCacheTests: XCTestCase {
    private let cache = WidgetArtworkCache.shared
    private var cacheDirectory: URL?

    override func setUpWithError() throws {
        try super.setUpWithError()
        cacheDirectory = FileManager.default.widgetArtworkCacheURL

        guard cacheDirectory != nil else {
            throw XCTSkip("App Group cache directory unavailable")
        }

        cache.clearCache()
    }

    override func tearDownWithError() throws {
        cache.clearCache()
        cacheDirectory = nil
        try super.tearDownWithError()
    }

    func testStoreAndLoadArtworkRoundTrip() {
        let trackId = UUID()
        let image = makeImage(color: .systemBlue, size: CGSize(width: 1000, height: 1000))

        let key = cache.storeArtwork(image, forTrackId: trackId)

        XCTAssertEqual(key, trackId.uuidString)
        XCTAssertTrue(cache.hasArtwork(forKey: trackId.uuidString))
        XCTAssertNotNil(cache.loadArtwork(forKey: trackId.uuidString))
        XCTAssertNotNil(cache.loadArtworkData(forKey: trackId.uuidString))
        XCTAssertGreaterThan(cache.cacheSize(), 0)
    }

    func testStoreArtworkDataRejectsInvalidImageData() {
        let key = cache.storeArtworkData(Data([0xDE, 0xAD, 0xBE, 0xEF]), forTrackId: UUID())
        XCTAssertNil(key)
    }

    func testLoadArtworkDataForLiveActivityUsesSmallerPayload() {
        let trackId = UUID()
        let image = makeImage(color: .systemRed, size: CGSize(width: 1200, height: 1200))
        _ = cache.storeArtwork(image, forTrackId: trackId)

        let normal = cache.loadArtworkData(forKey: trackId.uuidString)
        let live = cache.loadArtworkData(forKey: trackId.uuidString, forLiveActivity: true)

        XCTAssertNotNil(normal)
        XCTAssertNotNil(live)
        XCTAssertLessThanOrEqual(live?.count ?? .max, normal?.count ?? .max)
    }

    func testRemoveArtworkDeletesEntry() {
        let trackId = UUID()
        let image = makeImage(color: .systemGreen, size: CGSize(width: 700, height: 700))
        _ = cache.storeArtwork(image, forTrackId: trackId)

        XCTAssertTrue(cache.hasArtwork(forKey: trackId.uuidString))

        cache.removeArtwork(forKey: trackId.uuidString)

        XCTAssertFalse(cache.hasArtwork(forKey: trackId.uuidString))
        XCTAssertNil(cache.loadArtwork(forKey: trackId.uuidString))
    }

    func testRemoveOrphanedArtworkKeepsOnlyValidTrackIds() {
        let keepId = UUID()
        let removeId = UUID()
        let image = makeImage(color: .systemOrange, size: CGSize(width: 600, height: 600))

        _ = cache.storeArtwork(image, forTrackId: keepId)
        _ = cache.storeArtwork(image, forTrackId: removeId)

        cache.removeOrphanedArtwork(validTrackIds: [keepId])

        XCTAssertTrue(cache.hasArtwork(forKey: keepId.uuidString))
        XCTAssertFalse(cache.hasArtwork(forKey: removeId.uuidString))
    }

    func testClearCacheRemovesAllFiles() {
        let first = UUID()
        let second = UUID()
        let image = makeImage(color: .purple, size: CGSize(width: 800, height: 800))

        _ = cache.storeArtwork(image, forTrackId: first)
        _ = cache.storeArtwork(image, forTrackId: second)
        XCTAssertGreaterThan(cache.cacheSize(), 0)

        cache.clearCache()

        XCTAssertFalse(cache.hasArtwork(forKey: first.uuidString))
        XCTAssertFalse(cache.hasArtwork(forKey: second.uuidString))
        XCTAssertEqual(cache.cacheSize(), 0)
    }

    private func makeImage(color: UIColor, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
