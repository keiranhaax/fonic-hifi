import AVFoundation
import Foundation

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class AudioMonitorReporter {
    private let analytics: AudioSessionAnalytics
    private let thermalStateMonitor: any ThermalStateMonitoring
    private let alertHistoryProvider: @Sendable @MainActor () -> [PlaybackAlert]

    init(
        analytics: AudioSessionAnalytics,
        thermalStateMonitor: any ThermalStateMonitoring,
        alertHistoryProvider: @escaping @Sendable @MainActor () -> [PlaybackAlert]
    ) {
        self.analytics = analytics
        self.thermalStateMonitor = thermalStateMonitor
        self.alertHistoryProvider = alertHistoryProvider
    }

    func engineInfo(for engine: AudioEngineService?, metricsCollector: EngineMetricsCollecting) async -> AudioEngineInfo {
        let engineMetrics = await metricsCollector.metrics(for: engine)
        if engineMetrics.availability.supportsCollection {
            return AudioEngineInfo(
                type: engineMetrics.engineType,
                version: ProcessInfo.processInfo.operatingSystemVersionString,
                capabilities: [engineMetrics.isBitPerfect ? "BitPerfectEligible" : "Standard"],
                configuration: [
                    "sampleRate": String(format: "%.0f", engineMetrics.sampleRate),
                    "bitDepth": String(engineMetrics.bitDepth),
                    "channels": String(engineMetrics.channelCount)
                ],
                performanceProfile: engineMetrics.availability == .available ? "Measured" : "Partial",
                lastInitialized: Date()
            )
        }

        return AudioEngineInfo(
            type: engine.map { String(describing: type(of: $0)) } ?? "Unknown",
            version: ProcessInfo.processInfo.operatingSystemVersionString,
            capabilities: ["Standard"],
            configuration: [:],
            performanceProfile: "Unknown",
            lastInitialized: Date()
        )
    }

    func sessionInfo(isMonitoring: Bool) -> AudioSessionInfo {
        let session = AVAudioSession.sharedInstance()
        let category = session.category.rawValue
        let mode = session.mode.rawValue
        let options = session.categoryOptions.optionNames
        let sampleRate = session.sampleRate
        let bufferDuration = session.ioBufferDuration
        let isOtherAudioPlaying = session.isOtherAudioPlaying
        let isActive = !session.secondaryAudioShouldBeSilencedHint || isMonitoring

        return AudioSessionInfo(
            category: category,
            mode: mode,
            options: options,
            sampleRate: sampleRate,
            ioBufferDuration: bufferDuration,
            isActive: isActive,
            isOtherAudioPlaying: isOtherAudioPlaying
        )
    }

    func deviceInfo(latestMetric: AudioMetrics?) -> AudioDeviceInfo {
        let session = AVAudioSession.sharedInstance()
        let route = session.currentRoute
        let output = route.outputs.first
        let sampleRate = session.sampleRate
        let channels = Int(session.outputNumberOfChannels)
        let bufferFrames = Int(session.ioBufferDuration * sampleRate)
        let latency = session.outputLatency + session.ioBufferDuration
        let bitDepth = max(latestMetric?.bitDepth ?? 24, 16)

        return AudioDeviceInfo(
            deviceID: output?.uid ?? "unknown",
            name: output?.portName ?? "Unknown Output",
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            channels: max(channels, 2),
            bufferSize: max(bufferFrames, 256),
            latency: latency
        )
    }

    func debugInformation(
        updateInterval: TimeInterval,
        isMonitoring: Bool,
        isProfiling: Bool,
        metricsCount: Int,
        engine: AudioEngineService?,
        sessionInfo: AudioSessionInfo,
        deviceInfo: AudioDeviceInfo
    ) async -> DebugInformation {
        let thermalInfo = await thermalStateMonitor.getCurrentState()
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let deviceIdentifier = currentDeviceIdentifier()
        let architecture = currentArchitecture()
        let availableMemory = Int64(ProcessInfo.processInfo.physicalMemory)

        let history = analytics.historySnapshot
        let bufferAverage = history.isEmpty ? 1.0 : Double(history.map(\.bufferFillLevel).reduce(0, +)) / Double(history.count)
        let bufferMinimum = history.map { Double($0.bufferFillLevel) }.min() ?? 1.0

        let audioStackInfo = AudioStackDebugInfo(
            activeAudioUnits: engine.map { [String(describing: type(of: $0))] } ?? [],
            sessionDetails: [
                "category": sessionInfo.category,
                "mode": sessionInfo.mode,
                "options": sessionInfo.options.joined(separator: ",")
            ],
            engineConfiguration: [
                "updateInterval": updateInterval,
                "profiling": isProfiling,
                "metricsSamples": metricsCount
            ].mapValues { String(describing: $0) },
            bufferInfo: BufferDebugInfo(
                bufferSizes: [
                    "ioBufferFrames": Int(sessionInfo.ioBufferDuration * sessionInfo.sampleRate),
                    "deviceFrames": deviceInfo.bufferSize
                ],
                bufferUtilization: [
                    "average": Float(bufferAverage),
                    "minimum": Float(bufferMinimum)
                ],
                allocationHistory: []
            )
        )

        let debugFlags: [String: Bool] = [
            "monitoring": isMonitoring,
            "profiling": isProfiling,
            "alerts": !alertHistoryProvider().isEmpty
        ]

        return DebugInformation(
            sessionID: UUID().uuidString,
            systemInfo: SystemDebugInfo(
                deviceIdentifier: deviceIdentifier,
                systemVersion: systemVersion,
                availableMemory: availableMemory,
                cpuArchitecture: architecture,
                thermalState: thermalInfo.thermalState.rawValue
            ),
            audioStackInfo: audioStackInfo,
            performanceCounters: analytics.performanceCounters,
            debugFlags: debugFlags
        )
    }

    func recentLogEntries() -> [DiagnosticLogEntry] {
        var entries: [DiagnosticLogEntry] = []
        for alert in alertHistoryProvider().suffix(10) {
            let level: LogLevel = switch alert.severity {
            case .low: .warning
            case .medium: .warning
            case .high: .error
            case .critical: .critical
            }
            let context = alert.triggerValues.mapValues { String(format: "%.2f", $0) }
            entries.append(
                DiagnosticLogEntry(
                    timestamp: alert.timestamp,
                    level: level,
                    category: alert.type.rawValue,
                    message: alert.message,
                    context: context
                )
            )
        }
        for metric in analytics.historySnapshot.suffix(5) {
            let context: [String: String] = [
                "cpu": String(format: "%.1f", metric.cpuUsage),
                "memoryMB": String(format: "%.0f", Double(metric.memoryUsage) / 1_048_576),
                "latencyMs": String(format: "%.2f", metric.renderLatency * 1000),
                "buffer": String(format: "%.1f", metric.bufferFillLevel * 100)
            ]
            entries.append(
                DiagnosticLogEntry(
                    timestamp: metric.timestamp,
                    level: .info,
                    category: "metrics",
                    message: "Metrics snapshot",
                    context: context
                )
            )
        }
        return entries.sorted { $0.timestamp < $1.timestamp }
    }

    func configurationDump(
        updateInterval: TimeInterval,
        isProfiling: Bool,
        metricsCount: Int,
        sessionInfo: AudioSessionInfo,
        deviceInfo: AudioDeviceInfo
    ) -> ConfigurationDump {
        let engineConfig = [
            "updateInterval": String(format: "%.2f", updateInterval),
            "profiling": String(isProfiling),
            "metricsSamples": String(metricsCount)
        ]
        let sessionConfig = [
            "category": sessionInfo.category,
            "mode": sessionInfo.mode,
            "options": sessionInfo.options.joined(separator: ","),
            "sampleRate": String(format: "%.0f", sessionInfo.sampleRate),
            "ioBufferDuration": String(format: "%.4f", sessionInfo.ioBufferDuration)
        ]
        let deviceConfig = [
            "name": deviceInfo.name,
            "sampleRate": String(format: "%.0f", deviceInfo.sampleRate),
            "bitDepth": String(deviceInfo.bitDepth),
            "channels": String(deviceInfo.channels),
            "bufferSize": String(deviceInfo.bufferSize)
        ]
        let defaults = UserDefaults.standard
        let userPreferences = [
            "volume": String(format: "%.2f", defaults.double(forKey: "volume")),
            "isShuffleEnabled": String(defaults.bool(forKey: "isShuffleEnabled")),
            "repeatMode": defaults.string(forKey: "repeatMode") ?? "none"
        ]
        let systemSettings = [
            "osVersion": ProcessInfo.processInfo.operatingSystemVersionString,
            "device": currentDeviceIdentifier()
        ]

        return ConfigurationDump(
            engineConfig: engineConfig,
            sessionConfig: sessionConfig,
            deviceConfig: deviceConfig,
            userPreferences: userPreferences,
            systemSettings: systemSettings
        )
    }

    func export(metrics: [AudioMetrics], format: ExportFormat) -> Data {
        switch format {
        case .json:
            return exportAsJSON(metrics)
        case .csv:
            return exportAsCSV(metrics)
        case .xml:
            return exportAsXML(metrics)
        case .binary:
            return exportAsBinary(metrics)
        }
    }

    private func exportAsJSON(_ metrics: [AudioMetrics]) -> Data {
        let payload = metrics.map(EncodedMetric.init)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(payload)) ?? Data()
    }

    private func exportAsCSV(_ metrics: [AudioMetrics]) -> Data {
        var rows = [
            "timestamp,engineMetricsAvailability,cpuUsage,memoryUsageMB,bufferFill,renderLatencyMs,performanceScore,qualityScore,bitPerfectEligible"
        ]
        let formatter = ISO8601DateFormatter()
        for metric in metrics {
            let memoryMB = Double(metric.memoryUsage) / 1_048_576
            let rowComponents = [
                formatter.string(from: metric.timestamp),
                metric.engineMetricsAvailability.rawValue,
                String(format: "%.1f", metric.cpuUsage),
                String(format: "%.0f", memoryMB),
                String(format: "%.2f", metric.bufferFillLevel),
                String(format: "%.3f", metric.renderLatency * 1_000),
                String(format: "%.2f", metric.performanceScore),
                String(format: "%.2f", metric.qualityScore),
                String(metric.isBitPerfect)
            ]
            rows.append(rowComponents.joined(separator: ","))
        }
        return rows.joined(separator: "\n").data(using: .utf8) ?? Data()
    }

    private func exportAsXML(_ metrics: [AudioMetrics]) -> Data {
        let formatter = ISO8601DateFormatter()
        var xml = "<metrics>\n"
        for metric in metrics {
            xml += "  <metric timestamp=\"\(formatter.string(from: metric.timestamp))\">\n"
            xml += "    <engineMetricsAvailability>\(metric.engineMetricsAvailability.rawValue)</engineMetricsAvailability>\n"
            xml += "    <cpuUsage>\(String(format: "%.1f", metric.cpuUsage))</cpuUsage>\n"
            xml += "    <memoryUsageMB>\(String(format: "%.0f", Double(metric.memoryUsage) / 1_048_576))</memoryUsageMB>\n"
            xml += "    <bufferFill>\(String(format: "%.2f", metric.bufferFillLevel))</bufferFill>\n"
            xml += "    <renderLatencyMs>\(String(format: "%.3f", metric.renderLatency * 1000))</renderLatencyMs>\n"
            xml += "    <performanceScore>\(String(format: "%.2f", metric.performanceScore))</performanceScore>\n"
            xml += "    <qualityScore>\(String(format: "%.2f", metric.qualityScore))</qualityScore>\n"
            xml += "    <bitPerfectEligible>\(metric.isBitPerfect)</bitPerfectEligible>\n"
            xml += "  </metric>\n"
        }
        xml += "</metrics>"
        return xml.data(using: .utf8) ?? Data()
    }

    private func exportAsBinary(_ metrics: [AudioMetrics]) -> Data {
        let payload = metrics.map(EncodedMetric.init)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return (try? encoder.encode(payload)) ?? Data()
    }

    private func currentDeviceIdentifier() -> String {
        #if canImport(UIKit)
            return UIDevice.current.name
        #else
            return Host.current().localizedName ?? "Unknown"
        #endif
    }

    private func currentArchitecture() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce(into: "") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            identifier.append(Character(UnicodeScalar(UInt8(value))))
        }
        return identifier.isEmpty ? "arm64" : identifier
    }
}

private extension AVAudioSession.CategoryOptions {
    var optionNames: [String] {
        var names: [String] = []
        if contains(.mixWithOthers) { names.append("mixWithOthers") }
        if contains(.duckOthers) { names.append("duckOthers") }
        if contains(.allowBluetoothHFP) { names.append("allowBluetoothHFP") }
        if contains(.defaultToSpeaker) { names.append("defaultToSpeaker") }
        if contains(.allowBluetoothA2DP) { names.append("allowBluetoothA2DP") }
        if contains(.allowAirPlay) { names.append("allowAirPlay") }
        if contains(.interruptSpokenAudioAndMixWithOthers) { names.append("interruptSpokenAudio") }
        if names.isEmpty { names.append("none") }
        return names
    }
}
