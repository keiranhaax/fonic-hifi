//
//  EngineMetricsCollector.swift
//  Fonic HiFi
//
//  Created by Droid on 11/7/25.
//

import Foundation

@MainActor
public protocol EngineMetricsCollecting: Sendable {
    func metrics(for engine: AudioEngineService?) async -> EngineMetrics
}

@MainActor
public struct EngineMetricsCollector: EngineMetricsCollecting {
    public init() {}

    public func metrics(for engine: AudioEngineService?) async -> EngineMetrics {
        guard let engine else {
            return .default
        }

        let audioMetrics = await engine.getMetrics()
        return EngineMetrics(
            bufferUnderruns: audioMetrics.bufferUnderruns,
            decodingLatency: audioMetrics.decodingLatency,
            bufferFillLevel: audioMetrics.bufferFillLevel,
            droppedFrames: audioMetrics.droppedFrames,
            renderLatency: audioMetrics.renderLatency,
            currentBitrate: audioMetrics.currentBitrate,
            glitchCount: audioMetrics.glitchCount,
            sampleRate: audioMetrics.sampleRate,
            bitDepth: audioMetrics.bitDepth,
            channelCount: audioMetrics.channelCount,
            engineType: audioMetrics.engineType,
            audioFormat: audioMetrics.audioFormat,
            isBitPerfect: audioMetrics.isBitPerfect,
            bufferSize: audioMetrics.bufferSize,
            bufferResets: audioMetrics.bufferResets,
            threadUtilization: audioMetrics.threadUtilization,
            estimatedSNR: audioMetrics.estimatedSNR,
            dynamicRange: audioMetrics.dynamicRange,
            frequencyResponseScore: audioMetrics.frequencyResponseScore,
            jitter: audioMetrics.jitter,
            clockDrift: audioMetrics.clockDrift,
            recoverableErrors: audioMetrics.recoverableErrors,
            criticalErrors: audioMetrics.criticalErrors,
            recoverySuccessRate: audioMetrics.recoverySuccessRate,
            lastRecoveryTime: audioMetrics.lastRecoveryTime,
        )
    }
}
