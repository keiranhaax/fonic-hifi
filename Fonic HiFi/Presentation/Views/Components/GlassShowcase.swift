//
//  GlassShowcase.swift
//  Fonic HiFi
//
//  Created by Factory Droid on 10/7/25.
//

import SwiftUI

struct GlassShowcase: View {
    @State private var isPlayingParticles = true
    private let profiler = GlassPerformanceProfiler.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                showcaseHeader
                adaptiveGlassExample
                accessibilityExample
                buttonExample
                cardExample
                progressExample
                particlesExample
            }
            .padding(24)
        }
        .background(gradientBackground)
        .preferredColorScheme(.dark)
        .glassPerformanceProfiled("glass-showcase")
    }

    private var showcaseHeader: some View {
        VStack(spacing: 4) {
            Text("Liquid Glass Modifiers")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Native glassEffect() demos")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var adaptiveGlassExample: some View {
        VStack(spacing: 6) {
            Text("Adaptive Glass")
                .font(.headline)
            Text("Auto adjusts tint by color scheme")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .adaptiveGlass(cornerRadius: 16)
    }

    private var accessibilityExample: some View {
        VStack(spacing: 6) {
            Text("Accessibility Aware")
                .font(.headline)
            Text("Respects reduce transparency and contrast")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .a11yAwareGlass(style: .standard)
    }

    private var buttonExample: some View {
        GlassButton(style: .standard) {
            profiler.startProfiling("demo-button-tap")
            profiler.endProfiling("demo-button-tap")
        } label: {
            Label("Glass Button", systemImage: "sparkles")
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .foregroundStyle(.white)
        }
    }

    private var cardExample: some View {
        GlassCard(style: .thick) {
            VStack(spacing: 8) {
                Text("Glass Card")
                    .font(.headline)
                Text("Rounded rectangle with border overlay")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var progressExample: some View {
        FluidProgressView(progress: 0.68, height: 8)
            .frame(height: 12)
    }

    private var particlesExample: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.clear)
            .frame(width: 120, height: 120)
            .playingParticles(isPlaying: isPlayingParticles, particleCount: 12)
            .overlay(
                VStack(spacing: 4) {
                    Text("Particles")
                        .font(.caption)
                        .foregroundStyle(.white)
                    Toggle("Active", isOn: $isPlayingParticles)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .padding(12)
                .glassSurface(style: .ultraThin),
            )
    }

    private var gradientBackground: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color.blue.opacity(0.35),
                Color.purple.opacity(0.25),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
    }
}

#Preview("Glass Showcase") {
    GlassShowcase()
}
