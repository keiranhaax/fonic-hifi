//
//  StandByAdaptive.swift
//  Fonic HiFi Widget
//
//  StandBy mode detection and adaptive styling helpers
//

import SwiftUI
@preconcurrency import WidgetKit

// MARK: - StandBy Aware Font

/// Provides fonts that scale appropriately for StandBy mode
struct StandByFont {
    let showsBackground: Bool

    /// Title font (larger in StandBy)
    var title: Font {
        showsBackground ? .headline : .title3
    }

    /// Subtitle font (larger in StandBy)
    var subtitle: Font {
        showsBackground ? .subheadline : .headline
    }

    /// Caption font (larger in StandBy)
    var caption: Font {
        showsBackground ? .caption : .subheadline
    }

    /// Caption2 font (larger in StandBy)
    var caption2: Font {
        showsBackground ? .caption2 : .caption
    }

    /// Monospaced digits font for time display
    func monospacedTime(size: CGFloat) -> Font {
        let adjustedSize = showsBackground ? size : size * 1.3
        return .system(size: adjustedSize, design: .monospaced)
    }
}

// MARK: - StandBy Aware Colors

/// Provides colors optimized for high contrast in StandBy mode
struct StandByColors {
    let renderingMode: WidgetRenderingMode

    /// Primary foreground color
    var primary: Color {
        .primary
    }

    /// Secondary foreground color (higher contrast in vibrant mode)
    var secondary: Color {
        renderingMode == .vibrant ? .primary.opacity(0.7) : .secondary
    }

    /// Tertiary foreground color
    /// Note: Color.tertiary returns ShapeStyle, so we use gray with opacity for consistency
    var tertiary: Color {
        renderingMode == .vibrant ? .primary.opacity(0.5) : Color.gray.opacity(0.5)
    }

    /// Accent color for active states
    var accent: Color {
        renderingMode == .vibrant ? .primary : .orange
    }
}

// MARK: - StandBy Aware Sizes

/// Provides sizes that scale for StandBy mode
struct StandBySizes {
    let showsBackground: Bool

    /// Small artwork size
    var smallArtwork: CGFloat {
        showsBackground ? 36 : 48
    }

    /// Medium artwork size
    var mediumArtwork: CGFloat {
        showsBackground ? 100 : 120
    }

    /// Control button icon size
    var controlIcon: CGFloat {
        showsBackground ? 16 : 22
    }

    /// Play/pause main icon size
    var playPauseIcon: CGFloat {
        showsBackground ? 24 : 32
    }

    /// Progress bar height
    var progressHeight: CGFloat {
        showsBackground ? 4 : 6
    }

    /// Standard spacing
    var spacing: CGFloat {
        showsBackground ? 8 : 12
    }
}
