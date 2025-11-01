//
//  AudioAlertManager.swift
//  Fonic HiFi
//
//  Created by Droid on 10/6/25.
//

import Foundation

@MainActor
public protocol AudioAlertManaging: Sendable {
    var alertConfiguration: AlertConfiguration { get }
    var alertHistory: [PlaybackAlert] { get }

    func updateConfiguration(_ configuration: AlertConfiguration)
    func evaluateAlerts(for metrics: AudioMetrics) -> [PlaybackAlert]
    func recordInterruptionAlert(_ alert: PlaybackAlert)
    func reset()
}

@MainActor
public final class AudioAlertManager: AudioAlertManaging {
    private var configuration: AlertConfiguration
    private var lastAlertTimes: [AlertType: Date] = [:]
    public private(set) var alertHistory: [PlaybackAlert] = []

    public init(configuration: AlertConfiguration = .default) {
        self.configuration = configuration
    }

    public var alertConfiguration: AlertConfiguration {
        configuration
    }

    public func updateConfiguration(_ configuration: AlertConfiguration) {
        self.configuration = configuration
    }

    public func evaluateAlerts(for metrics: AudioMetrics) -> [PlaybackAlert] {
        var newAlerts: [PlaybackAlert] = []

        func record(_ alert: PlaybackAlert) {
            alertHistory.append(alert)
            lastAlertTimes[alert.type] = Date()
            newAlerts.append(alert)
        }

        if metrics.cpuUsage > configuration.cpuThreshold, shouldSendAlert(type: .highCPUUsage) {
            let alert = PlaybackAlert(
                type: .highCPUUsage,
                severity: metrics.cpuUsage > 90 ? .critical : .high,
                message: "High CPU usage detected (\(String(format: "%.1f", metrics.cpuUsage))%)",
                technicalDetails: "CPU usage above threshold: \(configuration.cpuThreshold)%",
                triggerValues: ["cpu_usage": Double(metrics.cpuUsage)],
                suggestedActions: [
                    "Close background applications",
                    "Reduce audio quality settings",
                    "Check for system updates",
                ],
            )
            record(alert)
        }

        if metrics.memoryUsage > configuration.memoryThreshold, shouldSendAlert(type: .highMemoryUsage) {
            let alert = PlaybackAlert(
                type: .highMemoryUsage,
                severity: .high,
                message: "High memory usage detected (\(metrics.formattedMemoryUsage))",
                technicalDetails: "Memory usage above threshold: \(ByteCountFormatter().string(fromByteCount: configuration.memoryThreshold))",
                triggerValues: ["memory_usage": Double(metrics.memoryUsage)],
                suggestedActions: [
                    "Close unused applications",
                    "Restart the audio engine",
                    "Clear audio cache",
                ],
            )
            record(alert)
        }

        if metrics.averageBufferFill < configuration.bufferFillThreshold, shouldSendAlert(type: .lowBufferFill) {
            let alert = PlaybackAlert(
                type: .lowBufferFill,
                severity: metrics.averageBufferFill < 0.25 ? .critical : .high,
                message: "Audio buffer fill is low (\(Int(metrics.averageBufferFill * 100))%)",
                technicalDetails: "Buffer fill below threshold: \(Int(configuration.bufferFillThreshold * 100))%",
                triggerValues: ["buffer_fill": Double(metrics.averageBufferFill)],
                suggestedActions: [
                    "Check storage speed",
                    "Reduce simultaneous playback tasks",
                    "Increase buffer size",
                ],
            )
            record(alert)
        }

        if metrics.bufferUnderruns > 0, shouldSendAlert(type: .bufferUnderrun) {
            let alert = PlaybackAlert(
                type: .bufferUnderrun,
                severity: metrics.bufferUnderruns > 2 ? .critical : .medium,
                message: metrics.bufferUnderruns > 1 ? "Multiple buffer underruns detected" : "Buffer underrun detected",
                technicalDetails: "Underrun count: \(metrics.bufferUnderruns)",
                triggerValues: ["buffer_underruns": Double(metrics.bufferUnderruns)],
                suggestedActions: [
                    "Check disk health",
                    "Verify audio file integrity",
                    "Restart playback",
                ],
            )
            record(alert)
        }

        if metrics.renderLatency > configuration.latencyThreshold, shouldSendAlert(type: .latencySpike) {
            let alert = PlaybackAlert(
                type: .latencySpike,
                severity: metrics.renderLatency > configuration.latencyThreshold * 1.5 ? .high : .medium,
                message: "Audio latency spike detected (\(String(format: "%.2f", metrics.renderLatency))s)",
                technicalDetails: "Latency above threshold: \(String(format: "%.2f", configuration.latencyThreshold))s",
                triggerValues: ["render_latency": metrics.renderLatency],
                suggestedActions: [
                    "Close CPU intensive apps",
                    "Reduce effects processing",
                    "Check system logs",
                ],
            )
            record(alert)
        }

        if metrics.thermalPressure > 0.7, shouldSendAlert(type: .thermalThrottling) {
            let alert = PlaybackAlert(
                type: .thermalThrottling,
                severity: .high,
                message: "Thermal throttling detected",
                technicalDetails: "Device reported high thermal state",
                triggerValues: ["thermal_pressure": Double(metrics.thermalPressure)],
                suggestedActions: [
                    "Move device to cooler environment",
                    "Reduce background workloads",
                    "Disable unnecessary visual effects",
                ],
            )
            record(alert)
        }

        return newAlerts
    }

    public func recordInterruptionAlert(_ alert: PlaybackAlert) {
        alertHistory.append(alert)
        lastAlertTimes[alert.type] = Date()
    }

    public func reset() {
        alertHistory.removeAll()
        lastAlertTimes.removeAll()
    }

    private func shouldSendAlert(type: AlertType) -> Bool {
        guard let lastTime = lastAlertTimes[type] else { return true }
        let timeSinceLastAlert = Date().timeIntervalSince(lastTime)
        return timeSinceLastAlert >= configuration.alertCooldownSeconds
    }
}
