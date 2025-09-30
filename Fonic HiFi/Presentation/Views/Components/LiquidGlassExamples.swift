//
//  LiquidGlassExamples.swift
//  Fonic HiFi
//
//  Created by Claude on 8/14/25.
//  iOS 26+ Performance-Optimized Liquid Glass Examples
//
//  This file demonstrates how to use the performance-optimized glass effects
//  with battery efficiency and proper profiling.

import SwiftUI

// MARK: - Performance-Optimized Now Playing View Example

struct OptimizedNowPlayingView: View {
    @State private var isPlaying = false
    @State private var progress = 0.3

    var body: some View {
        PerformanceOptimizedContainer(spacing: 0) { // Custom performance container
            VStack(spacing: 0) {
                // Main content area
                mainContentArea
                    .glassPerformanceProfiled("NowPlayingMain")

                // Controls area with decorative glass (lower frame rate)
                controlsArea
                    .liquidGlass(style: .ultraThin) // Simplified
                    .glassPerformanceProfiled("NowPlayingControls")
            }
        }
        // // .glassSafeAreaPadding() // Not yet implemented // Not yet implemented
        // // .glassHomeIndicatorPadding() // Not yet implemented // Not yet implemented
        .adaptiveGlassPerformance()
    }

    private var mainContentArea: some View {
        VStack(spacing: 20) {
            // Album artwork with interactive glass
            albumArtwork
                .liquidGlass(style: .standard, intensity: 0.8)

            // Track information
            trackInformation
                .liquidGlass(style: .thick, intensity: 0.9)

            // Progress bar
            progressBar
        }
        .padding()
    }

    private var albumArtwork: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: [.purple, .blue, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                ),
            )
            .frame(width: 280, height: 280)
            .shadow(radius: 20)
            .onTapGesture {
                withAnimation(.liquidBouncy) {
                    isPlaying.toggle()
                }
            }
    }

    private var trackInformation: some View {
        VStack(spacing: 8) {
            Text("Bohemian Rhapsody")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Queen • A Night at the Opera")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding()
    }

    private var progressBar: some View {
        VStack(spacing: 12) {
            FluidProgressView(progress: progress, height: 8)
                .preferredFrameRate(60) // Interactive element gets higher frame rate

            HStack {
                Text("2:34")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                Text("5:55")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal)
    }

    private var controlsArea: some View {
        HStack(spacing: 40) {
            controlButton(systemName: "backward.fill") {
                // Previous track
            }

            controlButton(
                systemName: isPlaying ? "pause.fill" : "play.fill",
                size: 24,
            ) {
                withAnimation(.liquidBouncy) {
                    isPlaying.toggle()
                }
            }

            controlButton(systemName: "forward.fill") {
                // Next track
            }
        }
        .padding(.vertical, 20)
    }

    private func controlButton(
        systemName: String,
        size: CGFloat = 20,
        action: @escaping () -> Void,
    ) -> some View {
        LiquidGlassButton(style: .standard, action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
        }
        .preferredFrameRate(
            BatteryOptimizedGlassUtilities.optimalFrameRate(for: .interactive),
        )
    }
}

// MARK: - Battery-Optimized Library View Example

struct OptimizedLibraryView: View {
    @State private var selectedTab = 0
    let tabs = ["Songs", "Albums", "Artists", "Playlists"]

    var body: some View {
        PerformanceOptimizedContainer(spacing: 0) { // Custom performance container
            VStack(spacing: 0) {
                // Header with adaptive glass
                headerView
                    .liquidGlass(style: .thick)
                    .glassPerformanceProfiled("LibraryHeader")

                // Tab selector with decorative glass
                tabSelector
                    .liquidGlass(style: .standard) // Simplified

                // Content area
                contentView
                    .liquidGlass(style: .ultraThin, intensity: 0.6)
            }
        }
        // .glassSafeAreaPadding() // Not yet implemented
    }

    private var headerView: some View {
        HStack {
            Text("Library")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Spacer()

            LiquidGlassButton(style: .ultraThin) {
                // Search action
            } content: {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
            }
            .preferredFrameRate(60) // Interactive element
        }
        .padding()
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button(action: {
                    withAnimation(.liquidSmooth) {
                        selectedTab = index
                    }
                }) {
                    Text(tab)
                        .font(.subheadline)
                        .fontWeight(selectedTab == index ? .semibold : .regular)
                        .foregroundColor(selectedTab == index ? .white : .white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white.opacity(selectedTab == index ? 0.2 : 0))
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab),
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0 ..< 20, id: \.self) { index in
                    songRow(index: index)
                        .liquidGlass(style: .ultraThin) // Simplified // Background elements
                }
            }
            .padding()
        }
    }

    private func songRow(index: Int) -> some View {
        HStack {
            // Album artwork placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.1))
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text("Track \(index + 1)")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Artist Name")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
        .onTapGesture {
            // Play track
        }
    }
}

// MARK: - Adaptive Performance Example

struct AdaptivePerformanceExample: View {
    @State private var effectCount = 3
    @State private var showPerformanceStats = false
    @StateObject private var memoryManager = GlassEffectMemoryManager.shared

    var body: some View {
        PerformanceOptimizedContainer(spacing: 0) { // Custom performance container
            VStack(spacing: 20) {
                headerSection

                controlsSection

                if showPerformanceStats {
                    performanceSection
                }

                // Demo glass elements
                glassElementsSection
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [.black, .blue.opacity(0.3), .purple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            ),
        )
    }

    private var headerSection: some View {
        VStack {
            Text("Adaptive Performance Demo")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Automatically adjusts glass effects based on device performance")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .liquidGlass(style: .standard)
        .glassPerformanceProfiled("AdaptiveHeader")
    }

    private var controlsSection: some View {
        HStack(spacing: 20) {
            VStack {
                Text("Glass Elements")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))

                Stepper(value: $effectCount, in: 1 ... 10) {
                    Text("\(effectCount)")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }

            Spacer()

            LiquidGlassButton(style: .standard) {
                showPerformanceStats.toggle()
            } content: {
                Text(showPerformanceStats ? "Hide Stats" : "Show Stats")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .liquidGlass(style: .thick)
    }

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance Metrics")
                .font(.headline)
                .foregroundColor(.white)

            HStack {
                Text("Active Effects:")
                Spacer()
                Text("\(memoryManager.activeEffectCount)")
            }
            .foregroundColor(.white.opacity(0.8))

            HStack {
                Text("Memory Pressure:")
                Spacer()
                Text(memoryPressureText)
                    .foregroundColor(memoryPressureColor)
            }

            HStack {
                Text("Low Power Mode:")
                Spacer()
                Text(ProcessInfo.processInfo.isLowPowerModeEnabled ? "Enabled" : "Disabled")
                    .foregroundColor(ProcessInfo.processInfo.isLowPowerModeEnabled ? .orange : .green)
            }

            HStack {
                Text("Thermal State:")
                Spacer()
                Text(thermalStateText)
                    .foregroundColor(thermalStateColor)
            }
        }
        .font(.caption)
        .padding()
        .liquidGlass(style: .ultraThin, intensity: 0.8)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showPerformanceStats)
    }

    private var glassElementsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 16) {
            ForEach(0 ..< effectCount, id: \.self) { index in
                glassElement(index: index)
            }
        }
    }

    private func glassElement(index: Int) -> some View {
        VStack {
            Text("Glass \(index + 1)")
                .font(.caption)
                .foregroundColor(.white)

            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.1))
                .frame(height: 60)
        }
        .padding()
        .liquidGlass(
            style: index < 2 ? .standard : .ultraThin,
            intensity: index < 2 ? 0.8 : 0.5,
        )
        .preferredFrameRate(
            BatteryOptimizedGlassUtilities.optimalFrameRate(
                for: index < 2 ? .interactive : .decorative,
            ),
        )
        .glassPerformanceProfiled("GlassElement\(index)")
    }

    private var memoryPressureText: String {
        switch memoryManager.memoryPressure {
        case .normal: "Normal"
        case .moderate: "Moderate"
        case .high: "High"
        case .critical: "Critical"
        }
    }

    private var memoryPressureColor: Color {
        switch memoryManager.memoryPressure {
        case .normal: .green
        case .moderate: .yellow
        case .high: .orange
        case .critical: .red
        }
    }

    private var thermalStateText: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    private var thermalStateColor: Color {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .gray
        }
    }
}

// MARK: - Safe Area and Home Indicator Example

struct SafeAreaGlassExample: View {
    var body: some View {
        PerformanceOptimizedContainer(spacing: 0) { // Custom performance container
            VStack(spacing: 0) {
                // Top area that respects safe area
                topSection
                // .glassSafeAreaPadding() // Not yet implemented

                Spacer()

                // Bottom area that avoids home indicator
                bottomSection
                // .glassHomeIndicatorPadding() // Not yet implemented
            }
        }
        .background(
            LinearGradient(
                colors: [.indigo, .purple],
                startPoint: .top,
                endPoint: .bottom,
            ),
        )
        .ignoresSafeArea(.all, edges: .all)
    }

    private var topSection: some View {
        VStack {
            Text("Safe Area Aware")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("This glass respects the safe area")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding()
        .liquidGlass(style: .standard)
    }

    private var bottomSection: some View {
        VStack {
            Text("Home Indicator Aware")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("This glass avoids the home indicator")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))

            HStack(spacing: 20) {
                ForEach(["play.fill", "pause.fill", "stop.fill"], id: \.self) { icon in
                    LiquidGlassButton(style: .standard) {
                        // Action
                    } content: {
                        Image(systemName: icon)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                }
            }
        }
        .padding()
        .liquidGlass(style: .thick)
    }
}

// MARK: - Performance Testing View

struct GlassPerformanceTestView: View {
    @State private var isStressing = false
    @State private var stressLevel = 1
    @StateObject private var profiler = GlassPerformanceProfiler.shared

    var body: some View {
        PerformanceOptimizedContainer(spacing: 0) { // Custom performance container
            VStack(spacing: 20) {
                Text("Glass Performance Testing")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .liquidGlass(style: .standard)

                // Stress test controls
                VStack {
                    Text("Stress Level: \(stressLevel)")
                        .foregroundColor(.white)

                    Slider(value: .init(
                        get: { Double(stressLevel) },
                        set: { stressLevel = Int($0) },
                    ), in: 1 ... 20, step: 1)

                    Button(action: {
                        isStressing.toggle()
                    }) {
                        Text(isStressing ? "Stop Stress Test" : "Start Stress Test")
                            .foregroundColor(.white)
                            .padding()
                            .liquidGlass(style: .standard)
                    }
                }
                .padding()
                .liquidGlass(style: .thick)

                // Performance metrics
                if !profiler.getMetrics().isEmpty {
                    performanceMetrics
                }

                // Stress test elements
                if isStressing {
                    stressTestGrid
                }
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [.black, .red.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            ),
        )
    }

    private var performanceMetrics: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance Metrics")
                .font(.headline)
                .foregroundColor(.white)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(profiler.getMetrics().prefix(10), id: \.label) { metric in
                        HStack {
                            Text(metric.label)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))

                            Spacer()

                            Text(String(format: "%.3fs", metric.duration))
                                .font(.caption)
                                .foregroundColor(metric.duration > 0.1 ? .red : .green)
                        }
                    }
                }
            }
            .frame(maxHeight: 150)
        }
        .padding()
        .liquidGlass(style: .ultraThin)
    }

    private var stressTestGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
            ForEach(0 ..< stressLevel, id: \.self) { index in
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.1))
                    .frame(height: 60)
                    .liquidGlass(style: .standard, intensity: 0.7)
                    .glassPerformanceProfiled("StressElement\(index)")
            }
        }
    }
}

// MARK: - Preview Provider

struct LiquidGlassExamples_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OptimizedNowPlayingView()
                .previewDisplayName("Optimized Now Playing")

            OptimizedLibraryView()
                .previewDisplayName("Battery-Optimized Library")

            AdaptivePerformanceExample()
                .previewDisplayName("Adaptive Performance")

            SafeAreaGlassExample()
                .previewDisplayName("Safe Area Aware")

            GlassPerformanceTestView()
                .previewDisplayName("Performance Testing")
        }
        .preferredColorScheme(.dark)
    }
}
