//
//  AudioMonitor.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/25.
//

import AVFoundation
import Combine
import Foundation
import OSLog
#if canImport(UIKit)
    import UIKit
#endif

/// Comprehensive audio monitoring implementation with periodic polling and real-time metrics
@MainActor
public final class AudioMonitor: ObservableObject, AudioPerformanceMonitoring, PlaybackHealthEventLogging {
    // MARK: - Publishers

    private let _metricsSubject = PassthroughSubject<AudioMetrics, Never>()
    private let _healthStatusSubject = PassthroughSubject<PlaybackHealthStatus, Never>()
    private let _alertsSubject = PassthroughSubject<PlaybackAlert, Never>()

    // MARK: - Private Properties

    private var interruptionObservationTokens = Set<NotificationCenter.ObservationToken>()
    private var _currentEngine: AudioEngineService?
    private let alertManager: any AudioAlertManaging
    private let runtime: any AudioMonitorRuntimeControlling

    // MARK: - Data Storage

    private let playbackHealthEventLog = PlaybackHealthEventLog()
    private let analytics = AudioSessionAnalytics()
    private let metricsCollector: AudioMonitorMetricsCollector
    private let engineHooks: any AudioMonitorEngineHooking

    // MARK: - Performance Tracking

    private let systemMetricsCollector: any SystemMetricsCollecting
    private let thermalStateMonitor: any ThermalStateMonitoring
    private let interruptionStatsTracker: any InterruptionStatsTracking
    private let engineMetricsCollector: any EngineMetricsCollecting

    // MARK: - Logging

    private let logger = Log.logger(.diagnosticsMonitor)

    // MARK: - Initialization

    public convenience init(
        performanceMonitor: PerformanceMonitor? = nil,
        systemMetricsCollector: (any SystemMetricsCollecting)? = nil,
        thermalStateMonitor: (any ThermalStateMonitoring)? = nil,
        interruptionStatsTracker: (any InterruptionStatsTracking)? = nil,
        engineMetricsCollector: (any EngineMetricsCollecting)? = nil,
        alertManager: (any AudioAlertManaging)? = nil
    ) {
        self.init(
            performanceMonitor: performanceMonitor,
            systemMetricsCollector: systemMetricsCollector,
            thermalStateMonitor: thermalStateMonitor,
            interruptionStatsTracker: interruptionStatsTracker,
            engineMetricsCollector: engineMetricsCollector,
            alertManager: alertManager,
            runtimeController: nil,
            engineHookController: nil
        )
    }

    init(
        performanceMonitor: PerformanceMonitor? = nil,
        systemMetricsCollector: (any SystemMetricsCollecting)? = nil,
        thermalStateMonitor: (any ThermalStateMonitoring)? = nil,
        interruptionStatsTracker: (any InterruptionStatsTracking)? = nil,
        engineMetricsCollector: (any EngineMetricsCollecting)? = nil,
        alertManager: (any AudioAlertManaging)? = nil,
        runtimeController: (any AudioMonitorRuntimeControlling)? = nil,
        engineHookController: (any AudioMonitorEngineHooking)? = nil
    ) {
        self.systemMetricsCollector = systemMetricsCollector ?? SystemMetricsCollector()
        self.thermalStateMonitor = thermalStateMonitor ?? ThermalStateMonitor()
        self.interruptionStatsTracker = interruptionStatsTracker ?? InterruptionStatsTracker()
        self.engineMetricsCollector = engineMetricsCollector ?? EngineMetricsCollector()
        let performanceMonitorInstance = performanceMonitor ?? PerformanceMonitor()
        self.alertManager = alertManager ?? AudioAlertManager()

        self.metricsCollector = AudioMonitorMetricsCollector(
            systemMetricsCollector: self.systemMetricsCollector,
            thermalStateMonitor: self.thermalStateMonitor,
            engineMetricsCollector: self.engineMetricsCollector
        )

        let metricsSubject = _metricsSubject
        let healthStatusSubject = _healthStatusSubject
        let alertsSubject = _alertsSubject

        let runtimeInstance: any AudioMonitorRuntimeControlling
        if let runtimeController {
            runtimeInstance = runtimeController
        } else {
            let scheduler = AudioMetricsScheduler()
            runtimeInstance = AudioMonitorRuntime(
                scheduler: scheduler,
                analytics: analytics,
                metricsCollector: metricsCollector,
                alertManager: self.alertManager,
                performanceMonitor: performanceMonitorInstance,
                logger: logger,
                publishMetrics: { metricsSubject.send($0) },
                publishHealthStatus: { healthStatusSubject.send($0) },
                publishAlert: { alertsSubject.send($0) }
            )
        }
        self.runtime = runtimeInstance

        let engineHooksInstance = engineHookController ?? AudioMonitorEngineHooks(logger: logger)
        self.engineHooks = engineHooksInstance

        setupMonitoring()
        setupInterruptionHandling()
    }

    deinit {
        MainActor.assumeIsolated {
            for token in interruptionObservationTokens {
                NotificationCenter.default.removeObserver(token)
            }
            runtime.invalidate()
        }
    }

    // MARK: - Monitoring Control

    public func startMonitoring(updateInterval: TimeInterval = 1.0) async {
        await runtime.startMonitoring(updateInterval: updateInterval, engine: _currentEngine)
        engineHooks.startMonitoring(interval: updateInterval)
    }

    public func stopMonitoring() async {
        await runtime.stopMonitoring()
        engineHooks.stopMonitoring()
    }

    public func updateMonitoringInterval(_ interval: TimeInterval) async {
        runtime.updateMonitoringInterval(to: interval)
        engineHooks.updateMonitoringInterval(to: interval)
    }

    // MARK: - Metrics Retrieval

    public func getCurrentMetrics() async -> AudioMetrics {
        await runtime.collectCurrentMetrics()
    }

    // MARK: - Engine Integration

    public func attachToEngine(_ engine: AudioEngineService) async {
        logger.info("Attaching to audio engine: \(type(of: engine), privacy: .public)")
        _currentEngine = engine
        runtime.updateEngine(engine)
        engineHooks.setEngine(engine)
    }

    public func detachFromEngine() async {
        logger.info("Detaching from current audio engine")
        engineHooks.setEngine(nil)
        _currentEngine = nil
        runtime.updateEngine(nil)
    }

}

// MARK: - Private Implementation

private extension AudioMonitor {
    func setupMonitoring() {
        // Set up system-level monitoring
        Task { @MainActor in
            await systemMetricsCollector.startMonitoring()
            await thermalStateMonitor.startMonitoring()
        }
    }

    func setupInterruptionHandling() {
        let notificationCenter = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        let inactiveObservation = notificationCenter.addObserver(
            of: session,
            for: .didBecomeInactive
        ) { [weak self] message in
            guard case let .systemInterruption(context) = message.deactivationResult else {
                return
            }
            let interruption = AudioSessionInterruption.from(
                interruptionReason: context.reason
            )
            Self.routeAudioInterruption(interruption, to: self)
        }
        interruptionObservationTokens.insert(inactiveObservation)

        let resumptionObservation = notificationCenter.addObserver(
            of: session,
            for: .resumptionRecommendation
        ) { [weak self] message in
            let interruption = AudioSessionInterruption.from(
                resumptionRecommendation: message.recommendation
            )
            Self.routeAudioInterruption(interruption, to: self)
        }
        interruptionObservationTokens.insert(resumptionObservation)
    }

    nonisolated static func routeAudioInterruption(
        _ interruption: AudioSessionInterruption,
        to owner: AudioMonitor?
    ) {
        Task { @MainActor [weak owner] in
            await owner?.handleAudioInterruption(interruption)
        }
    }

    func handleAudioInterruption(_ interruption: AudioSessionInterruption) async {
        await interruptionStatsTracker.recordInterruption(interruption)

        let severity: AlertSeverity = interruption.type == .began ? .medium : .low
        let alert = PlaybackAlert(
            type: .audioInterruption,
            severity: severity,
            message: interruption.userDescription,
            technicalDetails: interruption.debugDescription,
            suggestedActions: [interruption.recommendedAction.description]
        )

        alertManager.recordInterruptionAlert(alert)
        _alertsSubject.send(alert)
    }

    // MARK: - Calculation Helpers

}

// MARK: - PlaybackHealthEventLogging

extension AudioMonitor {
    public var playbackHealthEvents: [PlaybackHealthEvent] {
        playbackHealthEventLog.events
    }

    public var playbackHealthEventsPublisher: AnyPublisher<[PlaybackHealthEvent], Never> {
        playbackHealthEventLog.eventsPublisher
    }

    public func recordPlaybackHealthEvent(_ kind: PlaybackHealthEvent.Kind, detail: String?) {
        playbackHealthEventLog.record(kind, detail: detail)
    }
}

extension ThermalState {
    var isElevated: Bool {
        switch self {
        case .nominal:
            false
        case .fair, .serious, .critical:
            true
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}
