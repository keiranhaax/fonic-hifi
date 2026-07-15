//
//  WidgetArtworkCache.swift
//  Fonic HiFi
//
//  Created by Claude on 11/26/25.
//

import Foundation
import OSLog
import UIKit

/// File-based artwork cache for widget consumption
/// Stores compressed JPEG thumbnails in the App Group container
@MainActor
public final class WidgetArtworkCache {
    // MARK: - Singleton

    public static let shared = WidgetArtworkCache()

    // MARK: - Private Properties

    private let logger = Log.logger(.widgetData)
    private let fileManager = FileManager.default
    private var cacheURL: URL?
    private var accessDates: [String: Date] = [:]

    // MARK: - Initialization

    private init() {
        setupCacheDirectory()
    }

    private func setupCacheDirectory() {
        guard let url = fileManager.widgetArtworkCacheURL else {
            logger.error("Failed to get widget artwork cache URL")
            return
        }

        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            cacheURL = url
            logger.info("Widget artwork cache initialized")

            // Load access dates from disk
            loadAccessDates()
        } catch {
            logger.error("Failed to create artwork cache directory: \(error.localizedDescription)")
        }
    }

    // MARK: - Public API

    /// Store artwork for a track
    /// Returns the cache key if successful
    @discardableResult
    public func storeArtwork(_ image: UIImage, forTrackId trackId: UUID) -> String? {
        guard let cacheURL else { return nil }

        let key = trackId.uuidString
        let fileURL = cacheURL.appendingPathComponent("\(key).jpg")

        // Resize to thumbnail size
        let thumbnailSize = WidgetConstants.ArtworkCache.thumbnailSize
        guard let thumbnail = image.resized(to: CGSize(width: thumbnailSize, height: thumbnailSize)),
              let data = thumbnail.jpegData(compressionQuality: WidgetConstants.ArtworkCache.compressionQuality)
        else {
            logger.error("Failed to create widget artwork thumbnail")
            return nil
        }

        do {
            try data.write(to: fileURL, options: .atomic)
            accessDates[key] = Date()
            saveAccessDates()

            // Check cache size and evict if needed
            Task {
                await enforceCacheLimit()
            }

            logger.debug("Stored widget artwork")
            return key
        } catch {
            logger.error("Failed to write artwork: \(error.localizedDescription)")
            return nil
        }
    }

    /// Store artwork data directly (for cases where UIImage isn't available)
    @discardableResult
    public func storeArtworkData(_ data: Data, forTrackId trackId: UUID) -> String? {
        guard let image = UIImage(data: data) else {
            logger.error("Failed to decode widget artwork data")
            return nil
        }
        return storeArtwork(image, forTrackId: trackId)
    }

    /// Load artwork for a track
    public func loadArtwork(forKey key: String) -> UIImage? {
        guard let cacheURL else { return nil }

        let fileURL = cacheURL.appendingPathComponent("\(key).jpg")

        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data)
        else {
            return nil
        }

        // Update access date
        accessDates[key] = Date()

        return image
    }

    /// Load artwork data for Live Activity (returns Data for ActivityKit)
    public func loadArtworkData(forKey key: String, forLiveActivity: Bool = false) -> Data? {
        guard let cacheURL else { return nil }

        let fileURL = cacheURL.appendingPathComponent("\(key).jpg")

        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL)
        else {
            return nil
        }

        if forLiveActivity {
            // Re-compress to smaller size for Live Activity 4KB limit
            guard let image = UIImage(data: data) else { return nil }
            let size = WidgetConstants.ArtworkCache.liveActivityThumbnailSize
            guard let thumbnail = image.resized(to: CGSize(width: size, height: size)) else { return nil }
            return thumbnail.jpegData(compressionQuality: WidgetConstants.ArtworkCache.liveActivityCompressionQuality)
        }

        // Update access date
        accessDates[key] = Date()

        return data
    }

    /// Check if artwork exists for a key
    public func hasArtwork(forKey key: String) -> Bool {
        guard let cacheURL else { return false }
        let fileURL = cacheURL.appendingPathComponent("\(key).jpg")
        return fileManager.fileExists(atPath: fileURL.path)
    }

    /// Remove artwork for a track
    public func removeArtwork(forKey key: String) {
        guard let cacheURL else { return }

        let fileURL = cacheURL.appendingPathComponent("\(key).jpg")

        do {
            try fileManager.removeItem(at: fileURL)
            accessDates.removeValue(forKey: key)
            logger.debug("Removed artwork for key: \(key)")
        } catch {
            logger.error("Failed to remove artwork: \(error.localizedDescription)")
        }
    }

    /// Remove artwork for tracks that no longer exist
    public func removeOrphanedArtwork(validTrackIds: Set<UUID>) {
        guard let cacheURL else { return }

        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)

            for fileURL in contents where fileURL.pathExtension == "jpg" {
                let key = fileURL.deletingPathExtension().lastPathComponent

                if let uuid = UUID(uuidString: key), !validTrackIds.contains(uuid) {
                    try? fileManager.removeItem(at: fileURL)
                    accessDates.removeValue(forKey: key)
                    logger.debug("Removed orphaned artwork: \(key)")
                }
            }

            saveAccessDates()
        } catch {
            logger.error("Failed to clean orphaned artwork: \(error.localizedDescription)")
        }
    }

    /// Clear all cached artwork
    public func clearCache() {
        guard let cacheURL else { return }

        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)

            for fileURL in contents {
                try? fileManager.removeItem(at: fileURL)
            }

            accessDates.removeAll()
            logger.info("Artwork cache cleared")
        } catch {
            logger.error("Failed to clear cache: \(error.localizedDescription)")
        }
    }

    /// Get current cache size in bytes
    public func cacheSize() -> Int64 {
        guard let cacheURL else { return 0 }

        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: [.fileSizeKey])

            var totalSize: Int64 = 0
            for fileURL in contents {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }

            return totalSize
        } catch {
            return 0
        }
    }

    // MARK: - Cache Management

    private func enforceCacheLimit() async {
        let currentSize = cacheSize()
        let maxSize = WidgetConstants.ArtworkCache.maxCacheSize

        guard currentSize > maxSize else { return }

        logger.info("Cache size (\(currentSize)) exceeds limit (\(maxSize)), evicting...")

        // Sort by access date (oldest first)
        let sortedKeys = accessDates.sorted { $0.value < $1.value }.map(\.key)

        var freedSize: Int64 = 0
        let targetSize = maxSize * 3 / 4  // Evict to 75% of max

        for key in sortedKeys {
            guard currentSize - freedSize > targetSize else { break }

            if let cacheURL {
                let fileURL = cacheURL.appendingPathComponent("\(key).jpg")
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    freedSize += Int64(size)
                }
            }

            removeArtwork(forKey: key)
        }

        logger.info("Evicted \(freedSize) bytes from cache")
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

// MARK: - UIImage Resizing Extension

private extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage? {
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)

        let newSize = CGSize(
            width: size.width * ratio,
            height: size.height * ratio
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
