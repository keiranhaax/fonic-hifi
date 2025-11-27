//
//  StandByAdaptive.swift
//  Fonic HiFi Widget
//
//  StandBy mode detection and adaptive styling helpers
//

import SwiftUI
@preconcurrency import WidgetKit

// MARK: - StandBy Environment Key

/// Environment key for detecting StandBy mode
/// When `showsWidgetContainerBackground` is false, we're in StandBy mode [Verified-Apple]
struct StandByEnvironment: Sendable {
    let showsBackground: Bool
    let renderingMode: WidgetRenderingMode

    /// True when widget is displayed in StandBy mode (bedside clock mode)
    var isStandByMode: Bool {
        !showsBackground
    }

    /// True when using vibrant (tinted monochrome) rendering
    var isVibrantMode: Bool {
        renderingMode == .vibrant
    }

    /// True when full color artwork should be displayed
    var supportsFullColor: Bool {
        renderingMode == .fullColor
    }
}

// MARK: - StandBy Adaptive View Modifier

/// View modifier that adapts content for StandBy mode
/// Enlarges text and increases contrast for distance viewing
struct StandByAdaptive: ViewModifier {
    @Environment(\.showsWidgetContainerBackground) var showsBackground
    @Environment(\.widgetRenderingMode) var renderingMode

    let scaleFactor: CGFloat

    init(scaleFactor: CGFloat = 1.2) {
        self.scaleFactor = scaleFactor
    }

    var isStandByMode: Bool {
        !showsBackground
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isStandByMode ? scaleFactor : 1.0)
            .environment(\.dynamicTypeSize, isStandByMode ? .xxxLarge : .large)
    }
}

extension View {
    /// Apply StandBy mode adaptive scaling
    /// - Parameter scaleFactor: How much to scale up in StandBy mode (default 1.2)
    func standByAdaptive(scaleFactor: CGFloat = 1.2) -> some View {
        modifier(StandByAdaptive(scaleFactor: scaleFactor))
    }
}

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

// MARK: - Environment-Aware Container

/// A container view that provides StandBy-aware environment values to children
struct StandByAwareContainer<Content: View>: View {
    @Environment(\.showsWidgetContainerBackground) var showsBackground
    @Environment(\.widgetRenderingMode) var renderingMode

    let content: (StandByEnvironment) -> Content

    init(@ViewBuilder content: @escaping (StandByEnvironment) -> Content) {
        self.content = content
    }

    var body: some View {
        let environment = StandByEnvironment(
            showsBackground: showsBackground,
            renderingMode: renderingMode
        )
        content(environment)
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension StandByEnvironment {
    /// Normal widget context (Home Screen)
    static let normal = StandByEnvironment(showsBackground: true, renderingMode: .fullColor)

    /// StandBy mode context (bedside clock)
    static let standBy = StandByEnvironment(showsBackground: false, renderingMode: .vibrant)

    /// Lock Screen vibrant context
    static let lockScreenVibrant = StandByEnvironment(showsBackground: true, renderingMode: .vibrant)
}
#endif
