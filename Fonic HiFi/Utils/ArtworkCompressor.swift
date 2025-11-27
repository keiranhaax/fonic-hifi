//
//  ArtworkCompressor.swift
//  Fonic HiFi
//
//  Created by Claude on 2025-11-26.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Artwork compression using CoreGraphics/ImageIO (thread-safe, no UIKit dependency)
enum ArtworkCompressor {
    /// Maximum dimension for stored artwork
    static let maxDimension: CGFloat = 500

    /// JPEG compression quality (0.0-1.0)
    static let compressionQuality: CGFloat = 0.8

    /// Maximum size in bytes (200KB)
    static let maxSizeBytes = 200 * 1024

    /// Compress artwork data to reasonable size using ImageIO
    /// - Parameter data: Original artwork data
    /// - Returns: Compressed JPEG data or nil if invalid
    static func compress(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        // Read dimensions WITHOUT decoding the full image (efficient)
        // CFDictionary values are CFNumber - cast via NSNumber to CGFloat
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let widthNum = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let heightNum = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
            return nil
        }
        let width = CGFloat(truncating: widthNum)
        let height = CGFloat(truncating: heightNum)

        let maxSide = max(width, height)

        // Calculate target size
        let targetSize = maxSide > maxDimension ? Int(maxDimension) : Int(maxSide)

        // Use ImageIO thumbnail generation for efficient downsampling
        // kCGImageSourceShouldCache: false - don't cache decoded image data
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: targetSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCache: false
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return nil
        }

        // Encode as JPEG with compression
        return encodeAsJPEG(thumbnail, quality: compressionQuality, maxBytes: maxSizeBytes)
    }

    private static func encodeAsJPEG(_ image: CGImage, quality: CGFloat, maxBytes: Int) -> Data? {
        var currentQuality = quality

        while currentQuality >= 0.3 {
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                data as CFMutableData,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            ) else {
                return nil
            }

            let options: [CFString: Any] = [
                kCGImageDestinationLossyCompressionQuality: currentQuality
            ]

            CGImageDestinationAddImage(destination, image, options as CFDictionary)

            guard CGImageDestinationFinalize(destination) else {
                return nil
            }

            if data.count <= maxBytes {
                return data as Data
            }

            currentQuality -= 0.1
        }

        // Return last attempt even if over size limit
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.3
        ]

        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        CGImageDestinationFinalize(destination)

        return data as Data
    }
}
