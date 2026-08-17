//
//  WidgetArtworkCache.swift
//  Fonic HiFi
//
//  Created by Claude on 11/26/25.
//

import Foundation
import ImageIO
import OSLog
import UniformTypeIdentifiers

struct WidgetArtworkProcessingResult: Sendable {
    let data: Data
    let processedOnMainThread: Bool
}

enum WidgetArtworkProcessor {
    /// Image decoding, downsampling, and JPEG encoding are CPU-heavy and must not
    /// inherit a MainActor caller. Only Sendable `Data` crosses the boundary.
    @concurrent
    static func makeJPEGThumbnail(
        from sourceData: Data,
        maxPixelSize: CGFloat,
        compressionQuality: CGFloat
    ) async throws -> WidgetArtworkProcessingResult? {
        try Task.checkCancellation()
        let processedOnMainThread = currentExecutionUsesMainThread()

        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(sourceData as CFData, sourceOptions) else {
            return nil
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize.rounded(.up))),
        ] as CFDictionary

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }

        try Task.checkCancellation()

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let destinationOptions = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality,
        ] as CFDictionary
        CGImageDestinationAddImage(destination, image, destinationOptions)

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        try Task.checkCancellation()
        return WidgetArtworkProcessingResult(
            data: output as Data,
            processedOnMainThread: processedOnMainThread
        )
    }

    private nonisolated static func currentExecutionUsesMainThread() -> Bool {
        Thread.isMainThread
    }
}

typealias WidgetArtworkProcessing = @Sendable (
    _ sourceData: Data,
    _ maxPixelSize: CGFloat,
    _ compressionQuality: CGFloat
) async throws -> WidgetArtworkProcessingResult?

protocol WidgetArtworkCaching: Sendable {
    func existingArtworkKeys(for trackIds: [UUID]) async -> Set<String>
    func storeArtworkData(_ data: Data, forTrackId trackId: UUID) async throws -> String?
}

/// File-based artwork cache for widget consumption.
///
/// The actor is the single owner of cache metadata and file operations. ImageIO
/// processing runs on the concurrent executor and returns encoded data, so UIKit
/// reference types never cross an isolation boundary.
public actor WidgetArtworkCache: WidgetArtworkCaching {
    // MARK: - Singleton

    public static let shared = WidgetArtworkCache()

    // MARK: - Private Properties

    private let logger = Log.logger(.widgetData)
    private let configuredCacheURL: URL?
    private let maxCacheSize: Int64
    private let processor: WidgetArtworkProcessing
    private var cacheURL: URL?
    private var didResolveCacheURL = false
    private var accessDates: [String: Date] = [:]

    // MARK: - Initialization

    private init() {
        configuredCacheURL = nil
        maxCacheSize = WidgetConstants.ArtworkCache.maxCacheSize
        processor = { data, maxPixelSize, compressionQuality in
            try await WidgetArtworkProcessor.makeJPEGThumbnail(
                from: data,
                maxPixelSize: maxPixelSize,
                compressionQuality: compressionQuality
            )
        }
    }

    init(
        cacheDirectory: URL,
        maxCacheSize: Int64 = WidgetConstants.ArtworkCache.maxCacheSize,
        processor: @escaping WidgetArtworkProcessing = { data, maxPixelSize, compressionQuality in
            try await WidgetArtworkProcessor.makeJPEGThumbnail(
                from: data,
                maxPixelSize: maxPixelSize,
                compressionQuality: compressionQuality
            )
        }
    ) {
        configuredCacheURL = cacheDirectory
        self.maxCacheSize = maxCacheSize
        self.processor = processor
    }

    // MARK: - Public API

    /// Downsample and store artwork for a track.
    /// Returns the cache key if successful.
    @discardableResult
    public func storeArtworkData(_ data: Data, forTrackId trackId: UUID) async throws -> String? {
        try Task.checkCancellation()

        guard let processed = try await processor(
            data,
            WidgetConstants.ArtworkCache.thumbnailSize,
            WidgetConstants.ArtworkCache.compressionQuality
        ) else {
            logger.error("Failed to decode widget artwork data")
            return nil
        }

        try Task.checkCancellation()
        guard let cacheURL = resolveCacheURL() else { return nil }

        let key = trackId.uuidString
        let fileURL = cacheURL.appendingPathComponent("\(key).jpg")

        do {
            try processed.data.write(to: fileURL, options: .atomic)
            accessDates[key] = Date()
            saveAccessDates()
            // Once the atomic file replacement succeeds, finish the actor-owned
            // metadata/eviction commit even if the caller is cancelled. The caller
            // can ignore the result, but the cache must not be left over its limit.
            enforceCacheLimit()
            logger.debug("Stored widget artwork")
            return key
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            logger.error("Failed to write artwork: \(error.localizedDescription, privacy: .private)")
            return nil
        }
    }

    /// Load artwork data for the widget or a smaller Live Activity payload.
    public func loadArtworkData(
        forKey key: String,
        forLiveActivity: Bool = false
    ) async throws -> Data? {
        try Task.checkCancellation()
        guard let cacheURL = resolveCacheURL() else { return nil }

        let fileURL = cacheURL.appendingPathComponent("\(key).jpg")
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL)
        else {
            return nil
        }

        if forLiveActivity {
            let result = try await processor(
                data,
                WidgetConstants.ArtworkCache.liveActivityThumbnailSize,
                WidgetConstants.ArtworkCache.liveActivityCompressionQuality
            )
            try Task.checkCancellation()
            return result?.data
        }

        accessDates[key] = Date()
        saveAccessDates()
        return data
    }

    /// Return the subset of requested track IDs whose cache files exist.
    public func existingArtworkKeys(for trackIds: [UUID]) async -> Set<String> {
        guard !Task.isCancelled, let cacheURL = resolveCacheURL() else { return [] }

        return Set(trackIds.compactMap { trackId in
            let key = trackId.uuidString
            let fileURL = cacheURL.appendingPathComponent("\(key).jpg")
            return FileManager.default.fileExists(atPath: fileURL.path) ? key : nil
        })
    }

    /// Check if artwork exists for a key.
    public func hasArtwork(forKey key: String) -> Bool {
        guard let cacheURL = resolveCacheURL() else { return false }
        let fileURL = cacheURL.appendingPathComponent("\(key).jpg")
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// Remove artwork for a track.
    public func removeArtwork(forKey key: String) {
        guard let cacheURL = resolveCacheURL() else { return }

        do {
            try removeArtworkFile(forKey: key, cacheURL: cacheURL)
            saveAccessDates()
            logger.debug("Removed artwork for key: \(key, privacy: .private(mask: .hash))")
        } catch {
            logger.error("Failed to remove artwork: \(error.localizedDescription, privacy: .private)")
        }
    }

    /// Remove artwork for tracks that no longer exist.
    public func removeOrphanedArtwork(validTrackIds: Set<UUID>) {
        guard let cacheURL = resolveCacheURL() else { return }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: cacheURL,
                includingPropertiesForKeys: nil
            )

            for fileURL in contents where fileURL.pathExtension == "jpg" {
                let key = fileURL.deletingPathExtension().lastPathComponent

                if let uuid = UUID(uuidString: key), !validTrackIds.contains(uuid) {
                    try? removeArtworkFile(forKey: key, cacheURL: cacheURL)
                    logger.debug("Removed orphaned artwork: \(key, privacy: .private(mask: .hash))")
                }
            }

            saveAccessDates()
        } catch {
            logger.error("Failed to clean orphaned artwork: \(error.localizedDescription, privacy: .private)")
        }
    }

    /// Clear all cached artwork.
    public func clearCache() {
        guard let cacheURL = resolveCacheURL() else { return }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: cacheURL,
                includingPropertiesForKeys: nil
            )

            for fileURL in contents {
                try? FileManager.default.removeItem(at: fileURL)
            }

            accessDates.removeAll()
            logger.info("Artwork cache cleared")
        } catch {
            logger.error("Failed to clear cache: \(error.localizedDescription, privacy: .private)")
        }
    }

    /// Get current cache size in bytes.
    public func cacheSize() -> Int64 {
        guard let cacheURL = resolveCacheURL() else { return 0 }
        return cacheSize(at: cacheURL)
    }

    // MARK: - Cache Management

    private func resolveCacheURL() -> URL? {
        if didResolveCacheURL {
            return cacheURL
        }
        didResolveCacheURL = true

        guard let url = configuredCacheURL ?? FileManager.default.widgetArtworkCacheURL else {
            logger.error("Failed to get widget artwork cache URL")
            return nil
        }

        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            cacheURL = url
            loadAccessDates()
            logger.info("Widget artwork cache initialized")
            return url
        } catch {
            logger.error("Failed to create artwork cache directory: \(error.localizedDescription, privacy: .private)")
            return nil
        }
    }

    private func cacheSize(at cacheURL: URL) -> Int64 {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: cacheURL,
                includingPropertiesForKeys: [.fileSizeKey]
            )

            return try contents.reduce(into: Int64(0)) { totalSize, fileURL in
                let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(values.fileSize ?? 0)
            }
        } catch {
            return 0
        }
    }

    private func enforceCacheLimit() {
        guard let cacheURL else { return }

        let currentSize = cacheSize(at: cacheURL)
        guard currentSize > maxCacheSize else { return }

        logger.info(
            "Cache size (\(currentSize, privacy: .public)) exceeds limit (\(self.maxCacheSize, privacy: .public)), evicting..."
        )

        let sortedKeys = accessDates.sorted { $0.value < $1.value }.map(\.key)
        var freedSize: Int64 = 0
        let targetSize = maxCacheSize * 3 / 4

        for key in sortedKeys {
            guard currentSize - freedSize > targetSize else { break }

            let fileURL = cacheURL.appendingPathComponent("\(key).jpg")
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                freedSize += Int64(size)
            }
            try? removeArtworkFile(forKey: key, cacheURL: cacheURL)
        }

        saveAccessDates()
        logger.info("Evicted \(freedSize, privacy: .public) bytes from cache")
    }

    private func removeArtworkFile(forKey key: String, cacheURL: URL) throws {
        let fileURL = cacheURL.appendingPathComponent("\(key).jpg")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        accessDates.removeValue(forKey: key)
    }

    // MARK: - Access Date Persistence

    private var accessDatesURL: URL? {
        cacheURL?.appendingPathComponent(".access_dates.plist")
    }

    private func loadAccessDates() {
        guard let url = accessDatesURL,
              let data = try? Data(contentsOf: url),
              let dates = try? PropertyListDecoder().decode([String: Date].self, from: data)
        else {
            return
        }

        accessDates = dates
    }

    private func saveAccessDates() {
        guard let url = accessDatesURL,
              let data = try? PropertyListEncoder().encode(accessDates)
        else {
            return
        }

        try? data.write(to: url, options: .atomic)
    }
}
