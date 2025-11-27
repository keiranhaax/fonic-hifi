//
//  WidgetArtworkLoader.swift
//  Fonic HiFi Widget
//
//  Created by Claude on 11/26/25.
//

import Foundation
import SwiftUI
import UIKit

/// Lightweight artwork loader for widget extension
/// Reads directly from the App Group artwork cache
enum WidgetArtworkLoader {
    /// Load artwork image for a given cache key
    static func loadArtwork(forKey key: String?) -> UIImage? {
        guard let key,
              let cacheURL = FileManager.default.widgetArtworkCacheURL
        else { return nil }

        let fileURL = cacheURL.appendingPathComponent("\(key).jpg")

        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data)
        else {
            return nil
        }

        return image
    }

    /// Load artwork as SwiftUI Image
    static func loadImage(forKey key: String?) -> Image? {
        guard let uiImage = loadArtwork(forKey: key) else { return nil }
        return Image(uiImage: uiImage)
    }
}

// MARK: - SwiftUI View for Artwork

/// Artwork view for widgets that handles loading and placeholder
struct WidgetArtworkView: View {
    let artworkKey: String?
    let size: CGFloat

    @State private var artwork: Image?

    init(artworkKey: String?, size: CGFloat = 60) {
        self.artworkKey = artworkKey
        self.size = size
    }

    var body: some View {
        Group {
            if let artwork {
                artwork
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.12))
        .onAppear {
            artwork = WidgetArtworkLoader.loadImage(forKey: artworkKey)
        }
    }

    private var placeholderView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12)
                .fill(.quaternary)

            Image(systemName: "music.note")
                .font(.system(size: size * 0.4))
                .foregroundStyle(.secondary)
        }
    }
}
