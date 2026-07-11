//
//  GlassModifiers.swift
//  Fonic HiFi
//
//  Created by Factory Droid on 10/7/25.
//

import OSLog
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

private struct AdaptiveGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let borderOpacity: Double

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let tint = colorScheme == .dark ? Color.white.opacity(0.4) : Color.white.opacity(0.2)
        content
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(borderOpacity), lineWidth: 1))
            .glassEffect(.regular.tint(tint), in: shape)
    }
}

private struct ClearGlassFixModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Color.white.opacity(0.01))
    }
}

private struct A11yAwareGlassModifier: ViewModifier {
    let style: LiquidGlassStyle
    let tint: Color?
    let fallbackColor: Color
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if reduceTransparency {
            content
                .background(
                    shape
                        .fill(fallbackColor)
                        .overlay(
                            shape.strokeBorder(borderColor, lineWidth: differentiateWithoutColor ? 2 : 1),
                        ),
                )
                .clipShape(shape)
        } else {
            let glass = accessibleGlass()
            content
                .clipShape(shape)
                .overlay(
                    shape.strokeBorder(borderColor, lineWidth: differentiateWithoutColor ? 2 : 1),
                )
                .glassEffect(glass, in: shape)
        }
    }

    private func accessibleGlass() -> Glass {
        let overrideTint: Color = differentiateWithoutColor
            ? (colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.4))
            : .white.opacity(colorScheme == .dark ? 0.5 : 0.35)
        let appliedTint = tint ?? overrideTint
        return style.resolvedGlass(tint: appliedTint, interactive: false, colorScheme: colorScheme)
    }

    private var borderColor: Color {
        if differentiateWithoutColor {
            colorScheme == .dark ? .white.opacity(0.45) : .black.opacity(0.4)
        } else {
            .white.opacity(0.25)
        }
    }
}

private struct GlassPerformanceProfileModifier: ViewModifier {
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

private struct AdaptiveGlassPerformanceModifier: ViewModifier {
    @State private var isMonitoring = false

    func body(content: Content) -> some View {
        content
            .task(startMonitoring)
    }

    private func startMonitoring() async {
        guard !isMonitoring else { return }
        isMonitoring = true

        let thermalState = ProcessInfo.processInfo.thermalState
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

        await MainActor.run {
            if thermalState == .critical || lowPower {
                GlassPerformanceProfiler.shared.recordAdaptiveHint(.performance)
            } else if thermalState == .serious {
                GlassPerformanceProfiler.shared.recordAdaptiveHint(.balanced)
            } else {
                GlassPerformanceProfiler.shared.recordAdaptiveHint(.quality)
            }
        }
    }
}

private struct FrameRateControlModifier: ViewModifier {
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

    func adaptiveGlass(cornerRadius: CGFloat = 16, borderOpacity: Double = 0.2) -> some View {
        modifier(AdaptiveGlassModifier(cornerRadius: cornerRadius, borderOpacity: borderOpacity))
    }

    func clearGlassFix() -> some View {
        modifier(ClearGlassFixModifier())
    }

    func a11yAwareGlass(
        style: LiquidGlassStyle = .standard,
        tint: Color? = nil,
        fallbackColor: Color = .init(uiColor: .systemBackground),
        cornerRadius: CGFloat = 16,
    ) -> some View {
        modifier(A11yAwareGlassModifier(style: style, tint: tint, fallbackColor: fallbackColor, cornerRadius: cornerRadius))
    }

    func glassPerformanceProfiled(_ label: String) -> some View {
        modifier(GlassPerformanceProfileModifier(label: label))
    }

    func adaptiveGlassPerformance() -> some View {
        modifier(AdaptiveGlassPerformanceModifier())
    }

    func preferredFrameRate(_ rate: Double) -> some View {
        modifier(FrameRateControlModifier(targetFrameRate: rate))
    }
}

// MARK: - Performance Utilities

@MainActor
final class GlassPerformanceProfiler: ObservableObject {
    enum OptimizationHint {
        case performance
        case balanced
        case quality
    }

    static let shared = GlassPerformanceProfiler()

    private let logger = Log.logger(.performance)
    private var activeProfiles: [String: Date] = [:]
    private(set) var performanceMetrics: [String: PerformanceMetric] = [:]
    private(set) var lastHint: OptimizationHint = .quality

    private init() {}

    func startProfiling(_ label: String) {
        self.activeProfiles[label] = Date()
        self.logger.debug("Started glass effect profiling: \(label, privacy: .public)")
    }

    func endProfiling(_ label: String) {
        guard let startTime = self.activeProfiles.removeValue(forKey: label) else { return }
        let duration = Date().timeIntervalSince(startTime)

        let metric = PerformanceMetric(label: label, duration: duration, timestamp: Date())
        self.performanceMetrics[label] = metric

        self.logger.debug("Ended glass effect profiling: \(label, privacy: .public) (\(duration, format: .fixed(precision: 3)) seconds)")

        if duration > 0.1 {
            self.logger.warning("Glass effect performance warning: \(label, privacy: .public) took \(duration, format: .fixed(precision: 3)) seconds")
        }
    }

    func getMetrics() -> [PerformanceMetric] {
        Array(self.performanceMetrics.values)
    }

    func clearMetrics() {
        self.performanceMetrics.removeAll()
    }

    func recordAdaptiveHint(_ hint: OptimizationHint) {
        self.lastHint = hint
    }
}

struct PerformanceMetric: Identifiable {
    let id = UUID()
    let label: String
    let duration: TimeInterval
    let timestamp: Date
}

@MainActor
final class GlassEffectMemoryManager: ObservableObject {
    static let shared = GlassEffectMemoryManager()

    @Published var activeEffectCount: Int = 0
    @Published var memoryPressure: MemoryPressureLevel = .normal

    private let maxActiveEffects = 12
    private var memoryWarningObserver: NSObjectProtocol?
    private let logger = Log.logger(.liquidGlass)

    private init() {
        observeMemoryWarnings()
    }

    func registerEffect() -> Bool {
        guard self.activeEffectCount < self.maxActiveEffects else {
            self.logger.error("Glass effect registration denied: too many active effects (\(self.activeEffectCount))")
            return false
        }

        self.activeEffectCount += 1
        self.logger.debug("Glass effect registered: \(self.activeEffectCount) active")
        return true
    }

    func unregisterEffect() {
        self.activeEffectCount = max(0, self.activeEffectCount - 1)
        self.logger.debug("Glass effect unregistered: \(self.activeEffectCount) active")
    }

    private func observeMemoryWarnings() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.memoryPressure = .high
                self.logger.error("Memory warning received: adjusting glass effects")

                if self.activeEffectCount > 6 {
                    self.activeEffectCount = 6
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

enum GlassElementType {
    case interactive
    case decorative
    case background
}

enum BatteryOptimizedGlassUtilities {
    static func optimalFrameRate(for elementType: GlassElementType, isBackground: Bool = false) -> Double {
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let thermalState = ProcessInfo.processInfo.thermalState

        var base: Double = switch elementType {
        case .interactive:
            120
        case .decorative:
            60
        case .background:
            30
        }

        if lowPower {
            base = min(base, 60)
        }

        switch thermalState {
        case .nominal:
            break
        case .fair:
            base = min(base, 90)
        case .serious:
            base = min(base, 60)
        case .critical:
            base = min(base, 30)
        @unknown default:
            base = min(base, 60)
        }

        if isBackground {
            base *= 0.5
        }

        return max(base, 15)
    }

    static func optimalBlurRadius(requested: CGFloat, for elementType: GlassElementType) -> CGFloat {
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let thermalState = ProcessInfo.processInfo.thermalState

        var maxBlur = requested

        if lowPower {
            maxBlur = min(maxBlur, 8)
        }

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

        switch elementType {
        case .interactive:
            break
        case .decorative:
            maxBlur = min(maxBlur, 10)
        case .background:
            maxBlur = min(maxBlur, 6)
        }

        return max(maxBlur, 2)
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
