//
//  ThemePalette.swift
//  Fonic HiFi
//
//  Theme palette derived from a single dominant color.
//  Provides surface, accent, subtle, and glassTint variants.
//

import SwiftUI

/// A color palette derived from a single dominant color, adapted for light/dark mode.
struct ThemePalette: Equatable, Sendable {

    // MARK: - Properties

    /// The raw extracted dominant color
    let dominant: Color

    /// The color scheme this palette is adapted for
    let colorScheme: ColorScheme

    /// Surface color for backgrounds and cards (low opacity tint)
    var surface: Color {
        let opacity = colorScheme == .dark ? 0.20 : 0.12
        return dominant.opacity(opacity)
    }

    /// Accent color for interactive elements (saturated variant)
    var accent: Color {
        // Return the dominant color with full saturation for interactivity
        dominant
    }

    /// Subtle color for separators and secondary highlights
    var subtle: Color {
        let opacity = colorScheme == .dark ? 0.08 : 0.05
        return dominant.opacity(opacity)
    }

    /// Glass tint optimized for .glassEffect()
    var glassTint: Color {
        let opacity = colorScheme == .dark ? 0.25 : 0.15
        return dominant.opacity(opacity)
    }

    /// Whether this palette has a vibrant (saturated) dominant color
    var isVibrant: Bool {
        // Extract HSB components to check saturation
        guard let components = dominant.hsbaComponents else { return false }
        return components.saturation >= 0.15
    }

    // MARK: - Initialization

    init(dominant: Color, colorScheme: ColorScheme) {
        self.dominant = dominant
        self.colorScheme = colorScheme
    }

    // MARK: - Static Palettes

    /// Neutral fallback palette for when no artwork color is available
    static let neutral = ThemePalette(
        dominant: Color(white: 0.5),
        colorScheme: .dark
    )

    /// Creates a neutral palette adapted for the given color scheme
    static func neutral(for colorScheme: ColorScheme) -> ThemePalette {
        ThemePalette(
            dominant: Color(white: colorScheme == .dark ? 0.45 : 0.55),
            colorScheme: colorScheme
        )
    }
}

// MARK: - Color HSB Extension

private extension Color {
    /// Extract HSB components from a Color
    var hsbaComponents: (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat)? {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        guard UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return nil
        }

        return (hue, saturation, brightness, alpha)
    }
}
