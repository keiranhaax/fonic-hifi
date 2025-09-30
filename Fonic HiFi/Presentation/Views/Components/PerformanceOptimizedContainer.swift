//
//  PerformanceOptimizedContainer.swift
//  Fonic HiFi
//
//  CUSTOM IMPLEMENTATION - Not to be confused with Apple's official GlassEffectContainer
//  Performance-optimized container for rendering multiple views with frame rate control
//  iOS 26+ Custom Implementation
//

import SwiftUI

/// CUSTOM Performance-optimized container (NOT Apple's GlassEffectContainer)
/// Flattens rendering hierarchy and controls adaptive frame rate
/// This is a custom implementation for performance optimization

struct PerformanceOptimizedContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    @Environment(\.colorScheme) private var colorScheme
    @State private var isBackgrounded = false

    init(spacing: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        content
            .drawingGroup() // Flatten render hierarchy for performance
            .preferredFrameRate(isBackgrounded ? 30 : 120) // Adaptive frame rate
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                isBackgrounded = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                isBackgrounded = false
            }
    }
}

/// Wrapper for glass effect with morphing animation

struct GlassMorphingContainer<Content: View>: View {
    let id: String
    let namespace: Namespace.ID
    let content: Content

    init(
        id: String,
        in namespace: Namespace.ID,
        @ViewBuilder content: () -> Content,
    ) {
        self.id = id
        self.namespace = namespace
        self.content = content()
    }

    var body: some View {
        content
            .matchedGeometryEffect(id: id, in: namespace)
            .glassEffectID(id, in: namespace)
    }
}

/// Extension for glass effect ID on iOS 26

extension View {
    func glassEffectID(_ id: String, in namespace: Namespace.ID) -> some View {
        matchedGeometryEffect(id: "\(id).glass", in: namespace, properties: .frame)
            .matchedGeometryEffect(id: "\(id).blur", in: namespace, properties: .position)
    }
}

// MARK: - Preview

#Preview("Performance Optimized Container") {
    PerformanceOptimizedContainer {
        VStack(spacing: 20) {
            Text("Optimized Glass Effect")
                .padding()
                .liquidGlass(style: .standard)

            Text("Another Glass Element")
                .padding()
                .liquidGlass(style: .thick)
        }
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
