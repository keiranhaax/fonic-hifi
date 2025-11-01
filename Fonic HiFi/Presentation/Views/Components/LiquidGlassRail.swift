//
//  LiquidGlassRail.swift
//  Fonic HiFi
//
//  iOS 26+ Liquid Glass Rail component with morphing capabilities
//

import SwiftUI

/// A liquid glass rail container that supports morphing between states

struct LiquidGlassRail<Content: View>: View {
    @Binding var isExpanded: Bool
    @Namespace private var namespace

    let content: () -> Content
    let spacing: CGFloat
    let style: LiquidGlassStyle

    init(
        isExpanded: Binding<Bool>,
        spacing: CGFloat = 20,
        style: LiquidGlassStyle = .standard,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        _isExpanded = isExpanded
        self.spacing = spacing
        self.style = style
        self.content = content
    }

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: spacing) {
                content()
                    .glassEffect()
                    .glassEffectID("rail-content", in: namespace)
            }
            .padding(isExpanded ? 12 : 8)
            .glassSurface(style: style, cornerRadius: isExpanded ? 20 : 16, interactive: true)
            .shadow(
                color: .black.opacity(0.1),
                radius: isExpanded ? 12 : 8,
                y: isExpanded ? 6 : 4,
            )
        }
        .animation(
            .spring(response: 0.32, dampingFraction: 0.85),
            value: isExpanded,
        )
    }
}

/// Liquid Glass Segmented Tabs with Rail and Pill pattern

struct LiquidGlassSegmentedTabs: View {
    struct Tab: Identifiable {
        let id = UUID()
        let title: String
        let icon: String?

        init(title: String, icon: String? = nil) {
            self.title = title
            self.icon = icon
        }
    }

    let tabs: [Tab]
    @Binding var selection: Int

    @Namespace private var pillNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var sheenPhase: CGFloat = -1.0
    @State private var isPressed: Bool = false

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 8) {
                ForEach(tabs.indices, id: \.self) { index in
                    tabButton(for: index)
                }
            }
            .padding(6)
            .background(railBackground)
            .animation(
                reduceMotion ? .linear(duration: 0.2) : .spring(response: 0.32, dampingFraction: 0.85),
                value: selection,
            )
        }
    }

    @ViewBuilder
    private func tabButton(for index: Int) -> some View {
        Button {
            withAnimation(
                reduceMotion ? .linear(duration: 0.2)
                    : .spring(response: 0.32, dampingFraction: 0.85, blendDuration: 0.1),
            ) {
                selection = index
            }

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            // Trigger sheen animation
            if selection != index {
                sheenPhase = -1.0
                withAnimation(.easeOut(duration: 0.45)) {
                    sheenPhase = 1.0
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let icon = tabs[index].icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                }

                Text(tabs[index].title)
                    .font(.system(size: 15, weight: selection == index ? .semibold : .regular))
            }
            .foregroundStyle(selection == index ? .primary : .secondary)
            .opacity(selection == index ? 0.95 : 0.70)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(selectionPill(for: index))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffectID("tab-\(index)", in: pillNamespace)
    }

    @ViewBuilder
    private func selectionPill(for index: Int) -> some View {
        if selection == index {
            ZStack {
                // Clear glass pill
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(reduceTransparency ? Color(UIColor.secondarySystemBackground) : .clear)
                    .background(
                        reduceTransparency ? nil : Color.white.opacity(0.01),
                    )
                    .glassEffect()
                    .overlay(
                        // Subtle rim/border
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.white.opacity(0.28), lineWidth: 1),
                    )
                    .shadow(radius: 6, y: 2)

                // Interactive sheen
                if !reduceMotion, selection == index {
                    InteractiveSheen(phase: sheenPhase)
                }
            }
            .matchedGeometryEffect(id: "pill", in: pillNamespace)
        }
    }

    private var railBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(reduceTransparency ? Color(UIColor.systemBackground) : .clear)
            .glassEffect()
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.2),
                                .white.opacity(0.05),
                            ],
                            startPoint: .top,
                            endPoint: .bottom,
                        ),
                        lineWidth: 0.5,
                    ),
            )
    }
}

/// Interactive sheen effect for glass selections

private struct InteractiveSheen: View {
    let phase: CGFloat

    var body: some View {
        LinearGradient(
            colors: [
                .white.opacity(0.0),
                .white.opacity(0.24),
                .white.opacity(0.0),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
        .scaleEffect(1.4)
        .mask(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .black.opacity(0),
                            .black,
                            .black.opacity(0),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing,
                    ),
                )
                .frame(width: 40)
                .offset(x: phase * 140),
        )
        .allowsHitTesting(false)
    }
}

// MARK: - Liquid Glass Expandable Rail

/// An expandable rail that morphs between compact and expanded states

struct LiquidGlassExpandableRail<CompactContent: View, ExpandedContent: View>: View {
    @Binding var isExpanded: Bool
    @Namespace private var morphNamespace

    let compactContent: () -> CompactContent
    let expandedContent: () -> ExpandedContent

    init(
        isExpanded: Binding<Bool>,
        @ViewBuilder compact: @escaping () -> CompactContent,
        @ViewBuilder expanded: @escaping () -> ExpandedContent,
    ) {
        _isExpanded = isExpanded
        compactContent = compact
        expandedContent = expanded
    }

    var body: some View {
        GlassEffectContainer {
            if isExpanded {
                expandedContent()
                    .glassEffect()
                    .glassEffectID("expandable-rail", in: morphNamespace)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 1.2).combined(with: .opacity),
                        ),
                    )
            } else {
                compactContent()
                    .glassEffect()
                    .glassEffectID("expandable-rail", in: morphNamespace)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 1.2).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity),
                        ),
                    )
            }
        }
        .animation(
            .spring(response: 0.5, dampingFraction: 0.8),
            value: isExpanded,
        )
    }
}

// MARK: - Preview

#Preview("Liquid Glass Rail") {
    @Previewable @State var isExpanded = false

    VStack(spacing: 40) {
        // Basic rail
        LiquidGlassRail(isExpanded: $isExpanded) {
            ForEach(0 ..< 3) { _ in
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }
        }

        // Toggle expansion
        Button("Toggle Expansion") {
            isExpanded.toggle()
        }
        .buttonStyle(.borderedProminent)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}

#Preview("Segmented Tabs") {
    @Previewable @State var selection = 0

    VStack(spacing: 40) {
        LiquidGlassSegmentedTabs(
            tabs: [
                .init(title: "Classic", icon: "music.note"),
                .init(title: "Modern", icon: "waveform"),
                .init(title: "Live", icon: "mic.fill"),
            ],
            selection: $selection,
        )
        .padding(.horizontal)

        Text("Selected: \(selection)")
            .font(.title2)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
