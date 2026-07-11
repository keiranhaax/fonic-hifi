//
//  GlassModifiers.swift
//  Fonic HiFi
//
//  Created by Factory Droid on 10/7/25.
//

import SwiftUI

// MARK: - Surface Styles

enum LiquidGlassStyle: CaseIterable {
    case standard
    case thick
    case ultraThin
    case dynamic

    var cornerRadius: CGFloat {
        switch self {
        case .standard:
            16
        case .thick:
            20
        case .ultraThin:
            12
        case .dynamic:
            18
        }
    }

    var borderOpacity: Double {
        switch self {
        case .standard:
            0.24
        case .thick:
            0.28
        case .ultraThin:
            0.18
        case .dynamic:
            0.22
        }
    }

    func resolvedGlass(tint overrideTint: Color? = nil, interactive: Bool = false, colorScheme: ColorScheme) -> Glass {
        var glass: Glass = switch self {
        case .standard:
            .regular
        case .thick:
            .regular
        case .ultraThin:
            .clear
        case .dynamic:
            colorScheme == .dark ? .regular : .clear
        }

        let baseTint: Color? = switch self {
        case .standard:
            Color.white.opacity(colorScheme == .dark ? 0.35 : 0.25)
        case .thick:
            Color.white.opacity(colorScheme == .dark ? 0.55 : 0.45)
        case .ultraThin:
            Color.white.opacity(colorScheme == .dark ? 0.18 : 0.12)
        case .dynamic:
            colorScheme == .dark ? Color.white.opacity(0.4) : Color.white.opacity(0.2)
        }

        if let tint = overrideTint ?? baseTint {
            glass = glass.tint(tint)
        }

        if interactive {
            glass = glass.interactive()
        }

        return glass
    }
}

// MARK: - View Modifiers

private struct GlassSurfaceModifier: ViewModifier {
    let style: LiquidGlassStyle
    let tint: Color?
    let cornerRadius: CGFloat?
    let interactive: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var radius: CGFloat { cornerRadius ?? style.cornerRadius }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let strokeOpacity = style.borderOpacity
        let glass = style.resolvedGlass(tint: tint, interactive: interactive, colorScheme: colorScheme)

        content
            .clipShape(shape)
            .overlay(
                shape
                    .strokeBorder(.white.opacity(strokeOpacity), lineWidth: 1),
            )
            .glassEffect(glass, in: shape)
    }
}

struct GlassTransitionModifier: ViewModifier {
    let isActive: Bool
    let duration: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? 1.02 : 1.0)
            .opacity(isActive ? 0.9 : 1.0)
            .blur(radius: isActive ? 1 : 0)
            .animation(.easeInOut(duration: duration), value: isActive)
    }
}

// MARK: - Public Modifiers

extension View {
    func glassSurface(
        style: LiquidGlassStyle = .standard,
        tint: Color? = nil,
        cornerRadius: CGFloat? = nil,
        interactive: Bool = false,
    ) -> some View {
        modifier(GlassSurfaceModifier(style: style, tint: tint, cornerRadius: cornerRadius, interactive: interactive))
    }

    func glassTransition(isActive: Bool, duration: Double = 0.6) -> some View {
        modifier(GlassTransitionModifier(isActive: isActive, duration: duration))
    }
}

extension Animation {
    /// Liquid Glass smooth animation curve
    static let liquidSmooth = Animation.timingCurve(0.2, 0.0, 0.38, 0.9, duration: 0.6)

    /// Bouncy spring for interactive elements
    static let liquidBouncy = Animation.spring(duration: 0.6, bounce: 0.4)

    /// Fluid transition for morphing effects
    static let liquidMorph = Animation.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.8)
}
