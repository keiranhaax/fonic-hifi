//
//  BitPerfectProcessingAnalyzer.swift
//  Fonic HiFi
//
//  Created by Factory Droid on 10/6/25.
//

import AVFoundation
import Foundation

@MainActor
public protocol BitPerfectProcessingAnalyzing {
    func detectProcessing(in session: AVAudioSession) async -> BitPerfectProcessingDetection
}

struct AudioSessionProcessingContext: Sendable, Equatable {
    let isOtherAudioPlaying: Bool
    let outputVolume: Float
    let mode: AVAudioSession.Mode
    let hasSpatialAudioEnabled: Bool
    let hasBluetoothOutput: Bool
}

public struct BitPerfectProcessingDetection: Sendable, Equatable {
    public let hasProcessing: Bool
    public let stages: [AudioProcessingStage]

    public init(hasProcessing: Bool, stages: [AudioProcessingStage]) {
        self.hasProcessing = hasProcessing
        self.stages = stages
    }
}

@MainActor
public final class BitPerfectProcessingAnalyzer: BitPerfectProcessingAnalyzing {
    public init() {}

    public func detectProcessing(in session: AVAudioSession) async -> BitPerfectProcessingDetection {
        let context = AudioSessionProcessingContext(
            isOtherAudioPlaying: session.isOtherAudioPlaying,
            outputVolume: session.outputVolume,
            mode: session.mode,
            hasSpatialAudioEnabled: session.currentRoute.outputs.contains(where: \.isSpatialAudioEnabled),
            hasBluetoothOutput: session.currentRoute.outputs.contains { output in
                [AVAudioSession.Port.bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains(output.portType)
            },
        )

        return detectProcessing(context: context)
    }

    func detectProcessing(context: AudioSessionProcessingContext) -> BitPerfectProcessingDetection {
        var stages: [AudioProcessingStage] = []

        if context.isOtherAudioPlaying {
            stages.append(AudioProcessingStage(
                type: .systemMixer,
                description: "System audio mixer is active - other apps are playing audio",
                affectsBitPerfect: true,
                performanceImpact: 0.2,
            ))
        }

        if context.outputVolume < 1.0 {
            stages.append(AudioProcessingStage(
                type: .volumeControl,
                description: "Digital volume scaling at \(Int(context.outputVolume * 100))%",
                affectsBitPerfect: true,
                performanceImpact: 0.1,
            ))
        }

        switch context.mode {
        case .moviePlayback:
            stages.append(AudioProcessingStage(
                type: .movieMode,
                description: "Movie playback mode - may apply dynamic range processing",
                affectsBitPerfect: false,
                performanceImpact: 0.05,
            ))
        case .voiceChat, .videoChat:
            stages.append(AudioProcessingStage(
                type: .voiceProcessing,
                description: "Voice/Video chat mode - echo cancellation and noise reduction active",
                affectsBitPerfect: true,
                performanceImpact: 0.3,
            ))
        case .spokenAudio:
            stages.append(AudioProcessingStage(
                type: .spokenAudioMode,
                description: "Spoken audio mode - may apply speech enhancement",
                affectsBitPerfect: false,
                performanceImpact: 0.1,
            ))
        default:
            break
        }

        if context.hasSpatialAudioEnabled {
            stages.append(AudioProcessingStage(
                type: .spatialAudio,
                description: "Spatial Audio processing is enabled",
                affectsBitPerfect: true,
                performanceImpact: 0.4,
            ))
        }

        if context.hasBluetoothOutput {
            stages.append(AudioProcessingStage(
                type: .bluetoothCodec,
                description: "Bluetooth audio codec compression (AAC/SBC)",
                affectsBitPerfect: true,
                performanceImpact: 0.2,
            ))
        }

        return BitPerfectProcessingDetection(hasProcessing: !stages.isEmpty, stages: stages)
    }
}
