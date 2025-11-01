//
//  GlassControls.swift
//  Fonic HiFi
//
//  Created by Factory Droid on 10/7/25.
//

import SwiftUI

// MARK: - Button Style

struct GlassInteractiveButtonStyle: ButtonStyle {
    let style: LiquidGlassStyle

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassSurface(style: style, interactive: true)
            .glassTransition(isActive: configuration.isPressed, duration: 0.2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GlassButton<Label: View>: View {
    let style: LiquidGlassStyle
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    init(
        style: LiquidGlassStyle = .standard,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label,
    ) {
        self.style = style
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action, label: label)
            .buttonStyle(GlassInteractiveButtonStyle(style: style))
    }
}

// MARK: - Cards

struct GlassCard<Content: View>: View {
    let style: LiquidGlassStyle
    @ViewBuilder let content: () -> Content

    init(
        style: LiquidGlassStyle = .standard,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.style = style
        self.content = content
    }

    var body: some View {
        content()
            .padding()
            .glassSurface(style: style)
            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Progress

struct FluidProgressView: View {
    let progress: Double
    let height: CGFloat

    @State private var animatedProgress: Double = 0

    init(progress: Double, height: CGFloat = 6) {
        self.progress = progress
        self.height = height
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .frame(height: height)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.85), .white.opacity(0.55)],
                            startPoint: .leading,
                            endPoint: .trailing,
                        ),
                    )
                    .frame(width: geometry.size.width * animatedProgress, height: height)
                    .overlay(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.35), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing,
                                ),
                            )
                            .frame(width: 30)
                            .offset(x: -15 + (geometry.size.width * animatedProgress)),
                    )
                    .clipShape(Capsule())
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Backwards Compatibility

typealias LiquidGlassButton<Label: View> = GlassButton<Label>
typealias LiquidGlassCard<Content: View> = GlassCard<Content>
