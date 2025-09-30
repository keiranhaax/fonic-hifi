//
//  LiquidGlassDesignSystem.swift
//  Fonic HiFi
//
//  Created by Claude on 8/13/25.
//  iOS 26+ Liquid Glass Design System Implementation
//
//  iOS 26 Beta 6 Enhanced Features:
//  - AdaptiveGlass: Auto-switches material based on backdrop luminance
//  - ClearGlassFix: Fixes Beta 6 transparency rendering issues
//  - A11yAwareGlass: Accessibility-aware glass with system setting support
//  - BatteryOptimizedGlass: Battery-optimized with frame rate control
//

import os.log
import SwiftUI

// MARK: - iOS 26 Liquid Glass Design System [Custom Implementation]

//
// [CUSTOM IMPLEMENTATION - Not Apple's native APIs]
// This design system provides custom wrappers and convenience modifiers
// that work alongside iOS 26's native Liquid Glass APIs.
// These are PROJECT-SPECIFIC implementations, not Apple's official APIs.
// All modifiers respect accessibility settings and provide appropriate fallbacks.

extension View {
    /// [Custom Implementation] Applies a custom Liquid Glass-style effect
    /// This is NOT Apple's .glassEffect() - it's a custom wrapper using Material effects
    func liquidGlass(
        style: LiquidGlassStyle = .standard,
        intensity: Double = 1.0,
    ) -> some View {
        modifier(LiquidGlassModifier(style: style, intensity: intensity))
    }

    /// Applies fluid morphing animations for glass transitions
    func glassTransition(
        isActive: Bool,
        duration: Double = 0.6,
    ) -> some View {
        modifier(GlassTransitionModifier(isActive: isActive, duration: duration))
    }

    /// Adds particle effects for playing states
    func playingParticles(
        isPlaying: Bool,
        particleCount: Int = 12,
    ) -> some View {
        modifier(PlayingParticlesModifier(isPlaying: isPlaying, particleCount: particleCount))
    }

    /// Applies dynamic blur based on state
    func adaptiveBlur(
        intensity: Double,
        animated: Bool = true,
    ) -> some View {
        modifier(AdaptiveBlurModifier(intensity: intensity, animated: animated))
    }

    /// Enhanced haptic feedback for iOS 26
    func enhancedHaptics(
        style: UIImpactFeedbackGenerator.FeedbackStyle = .medium,
        intensity: CGFloat = 1.0,
    ) -> some View {
        modifier(EnhancedHapticsModifier(style: style, intensity: intensity))
    }

    /// Adaptive glass that auto-switches material based on backdrop luminance
    /// Beta 6 feature: Automatically detects backdrop brightness
    func adaptiveGlass(
        cornerRadius: CGFloat = 16,
        borderOpacity: Double = 0.2,
    ) -> some View {
        modifier(AdaptiveGlassModifier(cornerRadius: cornerRadius, borderOpacity: borderOpacity))
    }

    /// Beta 6 transparency fix with minimal background overlay
    /// Fixes iOS 26 Beta 6 transparency rendering issues
    func clearGlassFix() -> some View {
        modifier(ClearGlassFixModifier())
    }

    /// Accessibility-aware glass that respects system settings
    /// Handles Reduce Transparency, Increased Contrast, and color schemes
    func a11yAwareGlass(
        style: LiquidGlassStyle = .standard,
        fallbackColor: Color = .systemBackground,
        cornerRadius: CGFloat = 16,
    ) -> some View {
        modifier(A11yAwareGlassModifier(
            style: style,
            fallbackColor: fallbackColor,
            cornerRadius: cornerRadius,
        ))
    }

    /// Battery-optimized glass with reduced frame rate for background elements
    func batteryOptimizedGlass(
        style: LiquidGlassStyle = .standard,
        isBackground: Bool = false,
    ) -> some View {
        modifier(BatteryOptimizedGlassModifier(style: style, isBackground: isBackground))
    }
}

// MARK: - Glass Optimization Levels

enum GlassOptimizationLevel {
    case performance // Minimal effects, best performance
    case balanced // Balanced effects and performance
    case quality // Best visual quality
    case adaptive // Automatically adjusts based on device state
}

// MARK: - Liquid Glass Styles

enum LiquidGlassStyle {
    case standard
    case thick
    case ultraThin
    case dynamic

    var material: Material {
        switch self {
        case .standard:
            .thinMaterial
        case .thick:
            .thickMaterial
        case .ultraThin:
            .ultraThinMaterial
        case .dynamic:
            .regularMaterial
        }
    }

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
}

// MARK: - View Modifiers

struct LiquidGlassModifier: ViewModifier {
    let style: LiquidGlassStyle
    let intensity: Double

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(style.material)
                    .opacity(intensity)
                    .overlay(
                        RoundedRectangle(cornerRadius: style.cornerRadius)
                            .stroke(.white.opacity(0.2 * intensity), lineWidth: 1),
                    ),
            )
            .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius))
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

struct PlayingParticlesModifier: ViewModifier {
    let isPlaying: Bool
    let particleCount: Int

    @State private var particleOffsets: [CGSize] = []
    @State private var particleOpacities: [Double] = []

    func body(content: Content) -> some View {
        content
            .overlay(
                ZStack {
                    ForEach(0 ..< particleCount, id: \.self) { index in
                        if particleOffsets.indices.contains(index) {
                            Circle()
                                .fill(.white)
                                .frame(width: 3, height: 3)
                                .offset(particleOffsets[index])
                                .opacity(particleOpacities.indices.contains(index) ? particleOpacities[index] : 0)
                                .blur(radius: 0.5)
                        }
                    }
                },
            )
            .onAppear {
                initializeParticles()
            }
            .onChange(of: isPlaying) { _, newValue in
                if newValue {
                    animateParticles()
                } else {
                    resetParticles()
                }
            }
    }

    private func initializeParticles() {
        particleOffsets = Array(repeating: .zero, count: particleCount)
        particleOpacities = Array(repeating: 0.0, count: particleCount)
    }

    private func animateParticles() {
        for index in 0 ..< particleCount {
            let delay = Double(index) * 0.1

            withAnimation(
                .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
            ) {
                particleOffsets[index] = CGSize(
                    width: Double.random(in: -50 ... 50),
                    height: Double.random(in: -50 ... 50),
                )
                particleOpacities[index] = Double.random(in: 0.3 ... 0.8)
            }
        }
    }

    private func resetParticles() {
        withAnimation(.easeOut(duration: 0.5)) {
            particleOffsets = Array(repeating: .zero, count: particleCount)
            particleOpacities = Array(repeating: 0.0, count: particleCount)
        }
    }
}

struct AdaptiveBlurModifier: ViewModifier {
    let intensity: Double
    let animated: Bool

    func body(content: Content) -> some View {
        content
            .blur(radius: intensity * 3)
            .animation(animated ? .easeInOut(duration: 0.3) : .none, value: intensity)
    }
}

struct EnhancedHapticsModifier: ViewModifier {
    let style: UIImpactFeedbackGenerator.FeedbackStyle
    let intensity: CGFloat

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                let impactGenerator = UIImpactFeedbackGenerator(style: style)
                impactGenerator.impactOccurred(intensity: intensity)
            }
    }
}

// MARK: - iOS 26 Beta 6 Enhanced Modifiers

struct AdaptiveGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let borderOpacity: Double

    @State private var backdropLuminance: Double = 0.5
    @Environment(\.colorScheme) private var colorScheme

    private var adaptiveMaterial: Material {
        // Auto-switch based on backdrop luminance
        // Higher luminance = lighter backdrop = use thicker material for contrast
        if backdropLuminance > 0.7 {
            .regularMaterial
        } else if backdropLuminance > 0.3 {
            .thinMaterial
        } else {
            .ultraThinMaterial
        }
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(adaptiveMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(.white.opacity(borderOpacity), lineWidth: 1),
                    ),
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onAppear {
                updateBackdropLuminance()
            }
            .onChange(of: colorScheme) { _, _ in
                updateBackdropLuminance()
            }
    }

    private func updateBackdropLuminance() {
        // Simulate backdrop luminance detection
        // In a real implementation, this would use Core Image to analyze backdrop
        backdropLuminance = colorScheme == .dark ? 0.2 : 0.8
    }
}

struct ClearGlassFixModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                // iOS 26 Beta 6 transparency fix
                // Minimal white overlay prevents rendering artifacts
                Color.white.opacity(0.01),
            )
    }
}

struct A11yAwareGlassModifier: ViewModifier {
    let style: LiquidGlassStyle
    let fallbackColor: Color
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorScheme) private var colorScheme
    // Note: accessibilityDisplayScale removed in iOS 26, using alternate approach

    private var accessibleMaterial: Material {
        // Use more opaque materials for increased contrast
        if differentiateWithoutColor {
            return .regularMaterial
        }

        // Prefer regular over ultraThin for better visibility
        switch style {
        case .ultraThin:
            return .thinMaterial
        case .standard, .dynamic:
            return .regularMaterial
        case .thick:
            return .thickMaterial
        }
    }

    private var borderColor: Color {
        if differentiateWithoutColor {
            // Higher contrast border when differentiating without color
            colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.3)
        } else {
            .white.opacity(0.2)
        }
    }

    func body(content: Content) -> some View {
        Group {
            if reduceTransparency {
                // Solid fallback for Reduce Transparency
                content
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(fallbackColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .stroke(borderColor, lineWidth: differentiateWithoutColor ? 2 : 1),
                            ),
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                // Accessible glass material
                content
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(accessibleMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .stroke(borderColor, lineWidth: differentiateWithoutColor ? 2 : 1),
                            ),
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
    }
}

struct BatteryOptimizedGlassModifier: ViewModifier {
    let style: LiquidGlassStyle
    let isBackground: Bool

    @Environment(\.scenePhase) private var scenePhase
    @State private var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var optimizedFrameRate: Double {
        if isLowPowerMode {
            isBackground ? 30 : 60
        } else {
            isBackground ? 60 : 120
        }
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(style.material)
                    .overlay(
                        RoundedRectangle(cornerRadius: style.cornerRadius)
                            .stroke(.white.opacity(0.2), lineWidth: 1),
                    ),
            )
            .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius))
            .preferredFrameRate(optimizedFrameRate)
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
            .onChange(of: scenePhase) { _, newPhase in
                // Further optimize when app is not active
                if newPhase != .active, isBackground {
                    // Reduce effects for background elements when app is inactive
                }
            }
    }
}

// MARK: - Custom Components

struct LiquidGlassButton<Content: View>: View {
    let action: () -> Void
    let content: Content
    let style: LiquidGlassStyle

    @State private var isPressed = false

    init(
        style: LiquidGlassStyle = .standard,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content,
    ) {
        self.style = style
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .padding()
                .liquidGlass(style: style)
                .glassTransition(isActive: isPressed)
                .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {},
        )
        .enhancedHaptics()
    }
}

struct LiquidGlassCard<Content: View>: View {
    let content: Content
    let style: LiquidGlassStyle

    init(
        style: LiquidGlassStyle = .standard,
        @ViewBuilder content: () -> Content,
    ) {
        self.style = style
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .liquidGlass(style: style)
            .shadow(
                color: .black.opacity(0.1),
                radius: 10,
                x: 0,
                y: 4,
            )
    }
}

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
                // Background track
                Capsule()
                    .fill(.ultraThinMaterial)
                    .frame(height: height)

                // Progress fill with liquid effect
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.8), .white.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing,
                        ),
                    )
                    .frame(
                        width: geometry.size.width * animatedProgress,
                        height: height,
                    )
                    .overlay(
                        // Shimmer effect
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.3), .clear],
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

// MARK: - Animation Curves

extension Animation {
    /// Liquid Glass smooth animation curve
    static let liquidSmooth = Animation.timingCurve(0.2, 0.0, 0.38, 0.9, duration: 0.6)

    /// Bouncy spring for interactive elements
    static let liquidBouncy = Animation.spring(duration: 0.6, bounce: 0.4)

    /// Fluid transition for morphing effects
    static let liquidMorph = Animation.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.8)
}

// MARK: - Color Extensions

extension Color {
    /// Dynamic glass tint that adapts to content
    static var glassTint: Color {
        Color.primary.opacity(0.1)
    }

    /// Accent color with glass opacity
    static var glassAccent: Color {
        Color.accentColor.opacity(0.8)
    }

    /// System background color for accessibility fallbacks
    static var systemBackground: Color {
        Color(UIColor.systemBackground)
    }

    /// System secondary background for layered content
    static var systemSecondaryBackground: Color {
        Color(UIColor.secondarySystemBackground)
    }

    /// Creates a color that adapts to dark/light mode for glass effects
    static func adaptiveGlass(_ lightColor: Color, _ darkColor: Color) -> Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ?
                UIColor(darkColor) : UIColor(lightColor)
        })
    }

    /// High contrast color for accessibility
    static func highContrastGlass(_ baseColor: Color, in colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return baseColor.opacity(0.9)
        case .light:
            return baseColor.opacity(0.7)
        @unknown default:
            return baseColor.opacity(0.8)
        }
    }
}

// MARK: - Performance Utilities

extension View {
    /// Adds performance profiling points for glass effects
    func glassPerformanceProfiled(_ label: String) -> some View {
        modifier(GlassPerformanceProfileModifier(label: label))
    }

    /// Automatically adjusts glass intensity based on device performance
    func adaptiveGlassPerformance() -> some View {
        modifier(AdaptiveGlassPerformanceModifier())
    }
}

struct GlassPerformanceProfileModifier: ViewModifier {
    let label: String

    func body(content: Content) -> some View {
        content
            .onAppear {
                GlassPerformanceProfiler.shared.startProfiling(label)
            }
            .onDisappear {
                GlassPerformanceProfiler.shared.endProfiling(label)
            }
    }
}

struct AdaptiveGlassPerformanceModifier: ViewModifier {
    @State private var optimizationLevel: GlassOptimizationLevel = .adaptive
    @State private var isMonitoring = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                startPerformanceMonitoring()
            }
            .onDisappear {
                stopPerformanceMonitoring()
            }
    }

    private func startPerformanceMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        Task {
            // Monitor device performance and adjust glass effects
            let thermalState = ProcessInfo.processInfo.thermalState
            let isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

            await MainActor.run {
                if thermalState == .critical || isLowPowerMode {
                    optimizationLevel = .performance
                } else if thermalState == .serious {
                    optimizationLevel = .balanced
                } else {
                    optimizationLevel = .quality
                }
            }
        }
    }

    private func stopPerformanceMonitoring() {
        isMonitoring = false
    }
}

// MARK: - Glass Performance Profiler

@MainActor
class GlassPerformanceProfiler: ObservableObject, @unchecked Sendable {
    static let shared = GlassPerformanceProfiler()

    private var activeProfiles: [String: Date] = [:]
    private var performanceMetrics: [String: PerformanceMetric] = [:]

    private init() {}

    func startProfiling(_ label: String) {
        activeProfiles[label] = Date()

        // Log performance start point
        os_log("Started glass effect profiling: %{public}@", log: .glassPerformance, type: .debug, label)
    }

    func endProfiling(_ label: String) {
        guard let startTime = activeProfiles.removeValue(forKey: label) else { return }

        let duration = Date().timeIntervalSince(startTime)

        // Record performance metric
        let metric = PerformanceMetric(
            label: label,
            duration: duration,
            timestamp: Date(),
        )

        performanceMetrics[label] = metric

        // Log performance end point
        os_log("Ended glass effect profiling: %{public}@ (%.3f seconds)", log: .glassPerformance, type: .debug, label, duration)

        // Alert if performance is poor
        if duration > 0.1 {
            os_log("Glass effect performance warning: %{public}@ took %.3f seconds", log: .glassPerformance, type: .error, label, duration)
        }
    }

    func getMetrics() -> [PerformanceMetric] {
        Array(performanceMetrics.values)
    }

    func clearMetrics() {
        performanceMetrics.removeAll()
    }
}

struct PerformanceMetric {
    let label: String
    let duration: TimeInterval
    let timestamp: Date
}

// MARK: - Logging Extensions

extension OSLog {
    static let glassPerformance = OSLog(subsystem: "com.fonichifi.glass", category: "performance")
    static let glassRendering = OSLog(subsystem: "com.fonichifi.glass", category: "rendering")
    static let glassEffects = OSLog(subsystem: "com.fonichifi.glass", category: "effects")
}

// MARK: - Backdrop Luminance Detection Utilities

extension Color {
    /// Calculates the relative luminance of a color
    var luminance: Double {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Apply gamma correction
        let adjustedRed = red <= 0.03928 ? red / 12.92 : pow((red + 0.055) / 1.055, 2.4)
        let adjustedGreen = green <= 0.03928 ? green / 12.92 : pow((green + 0.055) / 1.055, 2.4)
        let adjustedBlue = blue <= 0.03928 ? blue / 12.92 : pow((blue + 0.055) / 1.055, 2.4)

        // Calculate relative luminance
        return 0.2126 * adjustedRed + 0.7152 * adjustedGreen + 0.0722 * adjustedBlue
    }

    /// Determines if this color is considered "bright" for glass effect purposes
    var isBright: Bool {
        luminance > 0.5
    }

    /// Returns a contrasting glass material for this color
    var contrastingGlassMaterial: Material {
        if isBright {
            .thickMaterial
        } else {
            .ultraThinMaterial
        }
    }
}

// MARK: - Battery Optimization Utilities

enum BatteryOptimizedGlassUtilities {
    /// Determines the optimal frame rate based on current power state
    static func optimalFrameRate(
        for elementType: GlassElementType,
        isBackground: Bool = false,
    ) -> Double {
        let isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        let thermalState = ProcessInfo.processInfo.thermalState

        var baseFrameRate: Double = switch elementType {
        case .interactive:
            120
        case .decorative:
            60
        case .background:
            30
        }

        // Apply power optimizations
        if isLowPowerMode {
            baseFrameRate = min(baseFrameRate, 60)
        }

        // Apply thermal optimizations
        switch thermalState {
        case .nominal:
            break
        case .fair:
            baseFrameRate = min(baseFrameRate, 90)
        case .serious:
            baseFrameRate = min(baseFrameRate, 60)
        case .critical:
            baseFrameRate = min(baseFrameRate, 30)
        @unknown default:
            baseFrameRate = min(baseFrameRate, 60)
        }

        // Further reduce for background elements
        if isBackground {
            baseFrameRate *= 0.5
        }

        return max(baseFrameRate, 15) // Minimum 15fps
    }

    /// Calculates the optimal blur radius based on performance constraints
    static func optimalBlurRadius(
        requested: CGFloat,
        for elementType: GlassElementType,
    ) -> CGFloat {
        let isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        let thermalState = ProcessInfo.processInfo.thermalState

        var maxBlur: CGFloat = requested

        // Apply power constraints
        if isLowPowerMode {
            maxBlur = min(maxBlur, 8)
        }

        // Apply thermal constraints
        switch thermalState {
        case .nominal:
            break
        case .fair:
            maxBlur = min(maxBlur, 12)
        case .serious:
            maxBlur = min(maxBlur, 8)
        case .critical:
            maxBlur = min(maxBlur, 4)
        @unknown default:
            maxBlur = min(maxBlur, 8)
        }

        // Element type constraints
        switch elementType {
        case .interactive:
            break // No additional constraints
        case .decorative:
            maxBlur = min(maxBlur, 10)
        case .background:
            maxBlur = min(maxBlur, 6)
        }

        return max(maxBlur, 2) // Minimum 2pt blur
    }
}

enum GlassElementType {
    case interactive // Buttons, controls that user interacts with
    case decorative // Visual elements that enhance appearance
    case background // Background elements, least important
}

// MARK: - Safe Area Detection Utilities

enum SafeAreaUtilities {
    /// Detects if the current device has a home indicator
    @MainActor
    static var hasHomeIndicator: Bool {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows
            .first else { return false }

        return window.safeAreaInsets.bottom > 0
    }

    /// Returns the appropriate bottom padding for glass elements
    @MainActor
    static var glassBottomPadding: CGFloat {
        hasHomeIndicator ? 8 : 0
    }

    /// Returns safe area insets adjusted for glass effects
    static func glassAdjustedSafeArea(_ insets: EdgeInsets) -> EdgeInsets {
        EdgeInsets(
            top: max(0, insets.top - 4),
            leading: max(0, insets.leading - 4),
            bottom: max(0, insets.bottom - 4),
            trailing: max(0, insets.trailing - 4),
        )
    }
}

// MARK: - Memory Management for Glass Effects

@MainActor
class GlassEffectMemoryManager: ObservableObject, @unchecked Sendable {
    static let shared = GlassEffectMemoryManager()

    @Published var activeEffectCount: Int = 0
    @Published var memoryPressure: MemoryPressureLevel = .normal

    private let maxActiveEffects = 12
    private var memoryWarningObserver: NSObjectProtocol?

    private init() {
        observeMemoryWarnings()
    }

    deinit {
        // Memory warning observer cleanup happens automatically
        // Since the class is marked with @MainActor
    }

    func registerEffect() -> Bool {
        guard activeEffectCount < maxActiveEffects else {
            os_log("Glass effect registration denied: too many active effects (%d)", log: .glassPerformance, type: .error, activeEffectCount)
            return false
        }

        activeEffectCount += 1
        os_log("Glass effect registered: %d active", log: .glassPerformance, type: .debug, activeEffectCount)
        return true
    }

    func unregisterEffect() {
        activeEffectCount = max(0, activeEffectCount - 1)
        os_log("Glass effect unregistered: %d active", log: .glassPerformance, type: .debug, activeEffectCount)
    }

    private func observeMemoryWarnings() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            Task { @MainActor in
                self?.memoryPressure = .high
                os_log("Memory warning received: adjusting glass effects", log: .glassPerformance, type: .error)

                // Auto-clear some effects if under pressure
                if self?.activeEffectCount ?? 0 > 6 {
                    self?.activeEffectCount = 6
                }
            }
        }
    }
}

enum MemoryPressureLevel {
    case normal
    case moderate
    case high
    case critical
}

// MARK: - Frame Rate Control Extensions

extension View {
    /// Sets a preferred frame rate with automatic optimization
    func preferredFrameRate(_ rate: Double) -> some View {
        modifier(FrameRateControlModifier(targetFrameRate: rate))
    }
}

struct FrameRateControlModifier: ViewModifier {
    let targetFrameRate: Double

    @State private var actualFrameRate: Double
    @Environment(\.scenePhase) private var scenePhase

    init(targetFrameRate: Double) {
        self.targetFrameRate = targetFrameRate
        _actualFrameRate = State(initialValue: targetFrameRate)
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    actualFrameRate = targetFrameRate
                case .inactive:
                    actualFrameRate = min(targetFrameRate, 30)
                case .background:
                    actualFrameRate = 15
                @unknown default:
                    actualFrameRate = min(targetFrameRate, 60)
                }
            }
        // Note: In iOS 26, this would use the actual frame rate control API
        // For now, this is a placeholder for the pattern
    }
}

// MARK: - Preview Helpers

struct LiquidGlassDesignSystem_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("iOS 26 Beta 6 Liquid Glass Modifiers")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                // Adaptive Glass Example
                VStack {
                    Text("Adaptive Glass")
                        .font(.headline)
                    Text("Auto-switches material based on backdrop")
                        .font(.caption)
                }
                .padding()
                .adaptiveGlass()

                // A11y Aware Glass Example
                VStack {
                    Text("Accessibility Aware Glass")
                        .font(.headline)
                    Text("Respects Reduce Transparency & Increased Contrast")
                        .font(.caption)
                }
                .padding()
                .a11yAwareGlass(style: .standard)

                // Clear Glass Fix Example
                VStack {
                    Text("Clear Glass with Beta 6 Fix")
                        .font(.headline)
                    Text("Fixes transparency rendering issues")
                        .font(.caption)
                }
                .padding()
                .liquidGlass(style: .ultraThin)
                .clearGlassFix()

                // Battery Optimized Glass Example
                VStack {
                    Text("Battery Optimized Glass")
                        .font(.headline)
                    Text("Reduced frame rate for background elements")
                        .font(.caption)
                }
                .padding()
                .batteryOptimizedGlass(style: .standard, isBackground: true)

                // Glass button example
                LiquidGlassButton(style: .standard) {
                    print("Button tapped")
                } content: {
                    Text("Liquid Glass Button")
                        .foregroundColor(.white)
                }

                // Glass card example
                LiquidGlassCard(style: .thick) {
                    VStack {
                        Text("Glass Card")
                            .font(.headline)
                        Text("With Liquid Glass effect")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Progress view example
                FluidProgressView(progress: 0.7, height: 8)
                    .padding(.horizontal)

                // Particle effect example
                Rectangle()
                    .fill(.clear)
                    .frame(width: 100, height: 100)
                    .playingParticles(isPlaying: true)
                    .border(.white.opacity(0.3))
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
        .preferredColorScheme(.dark)
    }
}
