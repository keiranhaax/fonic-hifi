//
//  SystemMetricsCollector.swift
//  Fonic HiFi
//
//  Created by Droid on 11/7/25.
//

import AVFoundation
import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Darwin)
import Darwin
#endif

@MainActor
public protocol SystemMetricsCollecting: Sendable {
    func startMonitoring() async
    func collectCurrentMetrics() async -> SystemMetrics
    func collectSystemMetrics() async -> SystemAudioMetrics
}

@MainActor
public protocol ThermalStateMonitoring: Sendable {
    func startMonitoring() async
    func getCurrentState() async -> ThermalMonitoringInfo
}

@MainActor
public protocol InterruptionStatsTracking: Sendable {
    func recordInterruption(_ interruption: AudioSessionInterruption) async
    func getStatistics() async -> InterruptionStatistics
}

@MainActor
public final class SystemMetricsCollector: SystemMetricsCollecting {
    struct CPUSample {
        let user: UInt32
        let system: UInt32
        let idle: UInt32
        let nice: UInt32
    }

    private struct NetworkSample {
        let bytesIn: UInt64
        let bytesOut: UInt64
        let timestamp: TimeInterval
    }

    private struct DiskSample {
        let readOperations: UInt64
        let writeOperations: UInt64
        let timestamp: TimeInterval
    }

    #if canImport(UIKit)
    private struct BatterySample {
        let level: Float
        let state: UIDevice.BatteryState
        let timestamp: TimeInterval
    }
    #endif

    private var previousCpuSample: CPUSample?
    private var cachedCPUUsage: (value: Float, timestamp: TimeInterval)?

    private var previousNetworkSample: NetworkSample?
    private var cachedNetworkBandwidth: (value: Int64, timestamp: TimeInterval)?

    private var previousDiskSample: DiskSample?
    private var cachedDiskIOPS: (value: Float, timestamp: TimeInterval)?

    #if canImport(UIKit)
    private var previousBatterySample: BatterySample?
    #endif

    public init() {}

    static func makeCPUSample(from ticks: (UInt32, UInt32, UInt32, UInt32)) -> CPUSample {
        CPUSample(
            user: ticks.0,
            system: ticks.1,
            idle: ticks.2,
            nice: ticks.3
        )
    }

    static func cpuUsage(previous: CPUSample, current: CPUSample) -> Float? {
        let user = Double(current.user &- previous.user)
        let system = Double(current.system &- previous.system)
        let nice = Double(current.nice &- previous.nice)
        let idle = Double(current.idle &- previous.idle)
        let total = user + system + nice + idle
        guard total > 0 else { return nil }

        let active = user + system + nice
        return max(0, min(Float((active / total) * 100), 100))
    }

    public func startMonitoring() async {
        previousCpuSample = captureCPUSample()
        previousNetworkSample = captureNetworkSample()
        previousDiskSample = captureDiskSample()
        cachedCPUUsage = nil
        cachedNetworkBandwidth = nil
        cachedDiskIOPS = nil

        #if canImport(UIKit)
        enableBatteryMonitoringIfNeeded()
        previousBatterySample = captureBatterySample()
        #endif
    }

    public func collectCurrentMetrics() async -> SystemMetrics {
        let cpuUsage = computeCPUUsage()
        let memoryUsage = currentMemoryUsage()
        let diskIOPS = computeDiskIOPS()
        let networkBandwidth = computeNetworkBandwidth()
        let batteryUsageRate = batteryUsageRate()

        return SystemMetrics(
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            diskIOPS: diskIOPS,
            networkBandwidth: networkBandwidth,
            batteryUsageRate: batteryUsageRate
        )
    }

    public func collectSystemMetrics() async -> SystemAudioMetrics {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs
        let primaryOutput = outputs.first
        let sampleRate = session.sampleRate
        let bufferDuration = session.ioBufferDuration
        let bufferFrames = max(Int(bufferDuration * sampleRate), 1)
        let latency = session.outputLatency + bufferDuration

        let cpuUsage = computeCPUUsage()
        let memoryUsage = currentMemoryUsage()
        let audioUnitLoad = min(cpuUsage / 100.0, 1.0)
        let activeSessions = max(outputs.count, 1) + (session.isOtherAudioPlaying ? 1 : 0)

        let deviceInfo = AudioDeviceInfo(
            deviceID: primaryOutput?.uid ?? "unknown",
            name: primaryOutput?.portName ?? "Unknown Output",
            sampleRate: sampleRate,
            bitDepth: 32,
            channels: max(Int(session.outputNumberOfChannels), 1),
            bufferSize: bufferFrames,
            latency: latency
        )

        return SystemAudioMetrics(
            systemAudioCPU: cpuUsage,
            activeAudioSessions: activeSessions,
            systemAudioMemory: memoryUsage,
            deviceInfo: deviceInfo,
            interruptionCount: 0,
            audioUnitLoad: audioUnitLoad
        )
    }
}

@MainActor
public final class ThermalStateMonitor: ThermalStateMonitoring {
    public init() {}

    public func startMonitoring() async {}

    public func getCurrentState() async -> ThermalMonitoringInfo {
        #if canImport(UIKit)
        let processInfo = ProcessInfo.processInfo
        let state = processInfo.thermalState

        let mapped: ThermalState
        let adjustments: [String]
        let throttling: Bool

        switch state {
        case .nominal:
            mapped = .nominal
            adjustments = []
            throttling = false
        case .fair:
            mapped = .fair
            adjustments = ["Reduce background activity", "Lower sample rate if possible"]
            throttling = false
        case .serious:
            mapped = .serious
            adjustments = ["Pause profiling", "Reduce visual effects", "Lower output volume"]
            throttling = true
        case .critical:
            mapped = .critical
            adjustments = ["Stop playback", "Allow device to cool"]
            throttling = true
        @unknown default:
            mapped = .nominal
            adjustments = []
            throttling = false
        }

        return ThermalMonitoringInfo(
            thermalState: mapped,
            cpuTemperature: nil,
            isThrottling: throttling,
            recommendedAdjustments: adjustments
        )
        #else
        return ThermalMonitoringInfo(
            thermalState: .nominal,
            cpuTemperature: nil,
            isThrottling: false,
            recommendedAdjustments: []
        )
        #endif
    }
}

@MainActor
public final class InterruptionStatsTracker: InterruptionStatsTracking {
    private var events: [InterruptionRecord] = []
    private var activeInterruption: AudioSessionInterruption?
    private var completedDurations: [TimeInterval] = []
    private var successfulRecoveries = 0
    private var completedInterruptionCount = 0

    public init() {}

    public func recordInterruption(_ interruption: AudioSessionInterruption) async {
        events.append(
            InterruptionRecord(
                type: interruption.type,
                timestamp: interruption.timestamp,
                duration: 0,
                recoverySuccessful: interruption.shouldResume
            )
        )

        switch interruption.type {
        case .began:
            if let active = activeInterruption,
               interruption.timestamp > active.timestamp {
                finalizeActiveInterruption(
                    endTime: interruption.timestamp,
                    shouldResume: false,
                    fallbackCategory: active.category
                )
            }
            activeInterruption = interruption
        case .ended:
            finalizeActiveInterruption(
                endTime: interruption.timestamp,
                shouldResume: interruption.shouldResume,
                fallbackCategory: interruption.category
            )
        }
    }

    public func getStatistics() async -> InterruptionStatistics {
        let grouped = Dictionary(grouping: events, by: { $0.type })
        let byType = grouped.mapValues { $0.count }

        let totalEvents = events.count
        let averageDuration: TimeInterval
        if completedDurations.isEmpty {
            averageDuration = 0
        } else {
            averageDuration = completedDurations.reduce(0, +) / Double(completedDurations.count)
        }
        let longestDuration = completedDurations.max() ?? 0
        let successRate: Double
        if completedInterruptionCount > 0 {
            successRate = Double(successfulRecoveries) / Double(completedInterruptionCount)
        } else {
            successRate = totalEvents == 0 ? 1.0 : 0.0
        }

        return InterruptionStatistics(
            totalInterruptions: totalEvents,
            interruptionsByType: byType,
            averageInterruptionDuration: averageDuration,
            longestInterruptionDuration: longestDuration,
            recoverySuccessRate: successRate,
            lastInterruptionTime: events.last?.timestamp
        )
    }

    private func finalizeActiveInterruption(
        endTime: Date,
        shouldResume: Bool?,
        fallbackCategory: InterruptionCategory?
    ) {
        let startTime = activeInterruption?.timestamp ?? endTime
        let duration = max(endTime.timeIntervalSince(startTime), 0)
        completedDurations.append(duration)
        completedInterruptionCount += 1

        let autoResume = shouldResume ?? fallbackCategory?.allowsAutoResume ?? false
        if autoResume {
            successfulRecoveries += 1
        }

        if var last = events.last, last.type == .ended {
            last = InterruptionRecord(
                type: last.type,
                timestamp: last.timestamp,
                duration: duration,
                recoverySuccessful: autoResume
            )
            events[events.count - 1] = last
        }

        activeInterruption = nil
    }
}

// MARK: - System Metric Helpers

private extension SystemMetricsCollector {
    func computeCPUUsage() -> Float {
        let now = ProcessInfo.processInfo.systemUptime
        if let cached = cachedCPUUsage, now - cached.timestamp < 0.25 {
            return cached.value
        }

        guard let currentSample = captureCPUSample() else {
            return cachedCPUUsage?.value ?? 0
        }

        defer { previousCpuSample = currentSample }

        guard let previousSample = previousCpuSample else {
            cachedCPUUsage = (0, now)
            return 0
        }

        guard let usage = Self.cpuUsage(previous: previousSample, current: currentSample) else {
            cachedCPUUsage = (cachedCPUUsage?.value ?? 0, now)
            return cachedCPUUsage?.value ?? 0
        }

        cachedCPUUsage = (usage, now)
        return usage
    }

    func currentMemoryUsage() -> Int64 {
        #if canImport(Darwin)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            return Int64(info.resident_size)
        }
        #endif

        return 0
    }

    func computeDiskIOPS() -> Float {
        let now = ProcessInfo.processInfo.systemUptime
        if let cached = cachedDiskIOPS, now - cached.timestamp < 0.25 {
            return cached.value
        }

        guard let sample = captureDiskSample() else {
            return cachedDiskIOPS?.value ?? 0
        }

        defer { previousDiskSample = sample }

        guard let previous = previousDiskSample, sample.timestamp > previous.timestamp else {
            cachedDiskIOPS = (cachedDiskIOPS?.value ?? 0, now)
            return cachedDiskIOPS?.value ?? 0
        }

        let deltaRead = Double(sample.readOperations &- previous.readOperations)
        let deltaWrite = Double(sample.writeOperations &- previous.writeOperations)
        let deltaTime = sample.timestamp - previous.timestamp
        guard deltaTime > 0 else {
            cachedDiskIOPS = (cachedDiskIOPS?.value ?? 0, now)
            return cachedDiskIOPS?.value ?? 0
        }

        let operations = max(deltaRead + deltaWrite, 0)
        let iops = Float(operations / deltaTime)
        let clamped = max(iops, 0)
        cachedDiskIOPS = (clamped, now)
        return clamped
    }

    func computeNetworkBandwidth() -> Int64 {
        let now = ProcessInfo.processInfo.systemUptime
        if let cached = cachedNetworkBandwidth, now - cached.timestamp < 0.25 {
            return cached.value
        }

        guard let sample = captureNetworkSample() else {
            return cachedNetworkBandwidth?.value ?? 0
        }

        defer { previousNetworkSample = sample }

        guard let previous = previousNetworkSample, sample.timestamp > previous.timestamp else {
            cachedNetworkBandwidth = (cachedNetworkBandwidth?.value ?? 0, now)
            return cachedNetworkBandwidth?.value ?? 0
        }

        let deltaIn = Double(sample.bytesIn &- previous.bytesIn)
        let deltaOut = Double(sample.bytesOut &- previous.bytesOut)
        let deltaTime = sample.timestamp - previous.timestamp
        guard deltaTime > 0 else {
            cachedNetworkBandwidth = (cachedNetworkBandwidth?.value ?? 0, now)
            return cachedNetworkBandwidth?.value ?? 0
        }

        let bytesPerSecond = max((deltaIn + deltaOut) / deltaTime, 0)
        let bandwidth = Int64(bytesPerSecond)
        cachedNetworkBandwidth = (bandwidth, now)
        return bandwidth
    }

    private func captureCPUSample() -> CPUSample? {
        #if canImport(Darwin)
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size) / 4
        var info = host_cpu_load_info_data_t()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            return Self.makeCPUSample(from: info.cpu_ticks)
        }
        #endif

        return nil
    }

    private func captureNetworkSample() -> NetworkSample? {
        #if canImport(Darwin)
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let head = pointer else {
            return nil
        }

        defer { freeifaddrs(head) }

        var inbound: UInt64 = 0
        var outbound: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = head

        while let entry = cursor {
            if let data = entry.pointee.ifa_data {
                let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                inbound &+= UInt64(networkData.ifi_ibytes)
                outbound &+= UInt64(networkData.ifi_obytes)
            }
            cursor = entry.pointee.ifa_next
        }

        return NetworkSample(
            bytesIn: inbound,
            bytesOut: outbound,
            timestamp: ProcessInfo.processInfo.systemUptime
        )
        #else
        return nil
        #endif
    }

    private func captureDiskSample() -> DiskSample? {
        #if canImport(Darwin)
        var usage = rusage()
        let result = getrusage(RUSAGE_SELF, &usage)
        guard result == 0 else {
            return nil
        }

        return DiskSample(
            readOperations: UInt64(max(usage.ru_inblock, 0)),
            writeOperations: UInt64(max(usage.ru_oublock, 0)),
            timestamp: ProcessInfo.processInfo.systemUptime
        )
        #else
        return nil
        #endif
    }

    func batteryUsageRate() -> Float? {
        #if canImport(UIKit)
        enableBatteryMonitoringIfNeeded()
        guard let sample = captureBatterySample() else {
            return nil
        }

        defer { previousBatterySample = sample }

        guard let previous = previousBatterySample else {
            return nil
        }

        let deltaTime = sample.timestamp - previous.timestamp
        guard deltaTime > 0 else {
            return nil
        }

        if sample.state == .charging || sample.state == .full {
            return 0
        }

        let deltaLevel = previous.level - sample.level
        guard deltaLevel > 0 else {
            return 0
        }

        let hours = deltaTime / 3600
        guard hours > 0 else {
            return nil
        }

        let rate = max(deltaLevel * 100 / Float(hours), 0)
        return min(rate, 1000)
        #else
        return nil
        #endif
    }

    #if canImport(UIKit)
    private func enableBatteryMonitoringIfNeeded() {
        let device = UIDevice.current
        if !device.isBatteryMonitoringEnabled {
            device.isBatteryMonitoringEnabled = true
        }
    }

    private func captureBatterySample() -> BatterySample? {
        let device = UIDevice.current
        guard device.isBatteryMonitoringEnabled else { return nil }
        let level = device.batteryLevel
        guard level >= 0 else { return nil }
        return BatterySample(level: level, state: device.batteryState, timestamp: ProcessInfo.processInfo.systemUptime)
    }
    #endif
}
