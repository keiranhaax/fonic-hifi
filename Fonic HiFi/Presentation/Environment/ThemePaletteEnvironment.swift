//
//  ThemePaletteEnvironment.swift
//  Fonic HiFi
//
//  Environment key for distributing ThemePalette to views.
//

import SwiftUI

// MARK: - Environment Key

/// Environment key for ThemePalette dependency injection
struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue: ThemePalette = .neutral
}

extension EnvironmentValues {
    /// Access to the current theme palette through environment
    var themePalette: ThemePalette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Injects the theme palette into the environment
    func themePalette(_ palette: ThemePalette) -> some View {
        environment(\.themePalette, palette)
    }
}
