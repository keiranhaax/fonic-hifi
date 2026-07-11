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

extension Animation {
    /// Liquid Glass smooth animation curve
    static let liquidSmooth = Animation.timingCurve(0.2, 0.0, 0.38, 0.9, duration: 0.6)

    /// Bouncy spring for interactive elements
    static let liquidBouncy = Animation.spring(duration: 0.6, bounce: 0.4)

    /// Fluid transition for morphing effects
    static let liquidMorph = Animation.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.8)
}
