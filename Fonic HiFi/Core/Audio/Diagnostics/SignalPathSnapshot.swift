import Foundation

/// Strength of the evidence behind one signal-path value.
public enum SignalPathEvidenceLevel: Sendable, Equatable {
    case measured
    case reported
    case estimated
    case unavailable
}

/// Compact eligibility state used by the signal-path inspector and badge.
public enum SignalPathEligibility: Sendable, Equatable {
    /// Post-load engine evidence and the validator agree that no conversion or
    /// processing is detected. This is eligibility, not physical-output proof.
    case eligible

    /// Post-load engine evidence is available and identifies at least one
    /// blocker.
    case ineligible

    /// No current track, validation, or verifiable post-load engine path.
    case unavailable
}

/// One format observation in the playback signal path.
public struct SignalPathFormatSnapshot: Sendable, Equatable {
    public let codec: String?
    public let sampleRate: Double?
    public let sampleRateEvidence: SignalPathEvidenceLevel
    public let bitDepth: Int?
    public let bitDepthEvidence: SignalPathEvidenceLevel
    public let channels: Int?
    public let channelEvidence: SignalPathEvidenceLevel

    public init(
        codec: String?,
        sampleRate: Double?,
        sampleRateEvidence: SignalPathEvidenceLevel,
        bitDepth: Int?,
        bitDepthEvidence: SignalPathEvidenceLevel,
        channels: Int?,
        channelEvidence: SignalPathEvidenceLevel
    ) {
        self.codec = codec
        self.sampleRate = sampleRate
        self.sampleRateEvidence = sampleRateEvidence
        self.bitDepth = bitDepth
        self.bitDepthEvidence = bitDepthEvidence
        self.channels = channels
        self.channelEvidence = channelEvidence
    }
}

/// Processing and volume state that can alter samples before output.
public struct SignalPathProcessingSnapshot: Sendable, Equatable {
    public let applicationDSPActive: Bool
    public let engineProcessingActive: Bool?
    public let systemVolume: Float
    public let applicationVolume: Float
    public let stages: [AudioProcessingStage]

    /// A true bypass requires both application state and measured engine graph
    /// state to report no processing.
    public var isBypassed: Bool {
        !applicationDSPActive &&
            engineProcessingActive == false &&
            !stages.contains(where: \.affectsBitPerfect)
    }

    public init(
        applicationDSPActive: Bool,
        engineProcessingActive: Bool?,
        systemVolume: Float,
        applicationVolume: Float,
        stages: [AudioProcessingStage]
    ) {
        self.applicationDSPActive = applicationDSPActive
        self.engineProcessingActive = engineProcessingActive
        self.systemVolume = systemVolume
        self.applicationVolume = applicationVolume
        self.stages = stages
    }
}

/// Read-only aggregation of the source, engine, DSP, output, route, and
/// eligibility evidence for the current track.
///
/// The snapshot is composed by the audio facade and published through its
/// existing diagnostics state. Views must not query engine adapters directly.
public struct SignalPathSnapshot: Sendable, Equatable {
    public let source: SignalPathFormatSnapshot
    public let loadedFormat: SignalPathFormatSnapshot?
    public let engineIdentifier: String
    public let engineDisplayName: String
    public let processing: SignalPathProcessingSnapshot
    public let outputFormat: SignalPathFormatSnapshot
    public let device: AudioDevice?
    public let eligibility: SignalPathEligibility
    public let mismatchReason: BitPerfectMismatchReason?
    public let validationIssues: [ValidationIssue]
    public let updatedAt: Date

    public init(
        sourceFormat: AudioFileInfo,
        context: BitPerfectEligibilityContext,
        validationResult: BitPerfectValidationResult,
        device: AudioDevice?,
        updatedAt: Date = Date()
    ) {
        let engineEvidence = context.engineEvidence
        let loadedEvidence = engineEvidence.flatMap { $0.isTrackLoaded ? $0 : nil }
        let codec = sourceFormat.codec ?? sourceFormat.format.displayName

        source = SignalPathFormatSnapshot(
            codec: codec,
            sampleRate: sourceFormat.sampleRate,
            sampleRateEvidence: .reported,
            bitDepth: Int(sourceFormat.bitDepth),
            bitDepthEvidence: .reported,
            channels: Int(sourceFormat.channels),
            channelEvidence: .reported
        )

        if let loadedEvidence {
            loadedFormat = SignalPathFormatSnapshot(
                codec: codec,
                sampleRate: loadedEvidence.loadedSampleRate,
                sampleRateEvidence: loadedEvidence.loadedSampleRate == nil ? .unavailable : .measured,
                bitDepth: nil,
                bitDepthEvidence: .unavailable,
                channels: loadedEvidence.loadedChannelCount,
                channelEvidence: loadedEvidence.loadedChannelCount == nil ? .unavailable : .measured
            )
        } else {
            loadedFormat = nil
        }

        engineIdentifier = context.engineIdentifier
        engineDisplayName = AudioEngineType(rawValue: context.engineIdentifier)?.displayName
            ?? context.engineIdentifier

        processing = SignalPathProcessingSnapshot(
            applicationDSPActive: context.hasDSP,
            engineProcessingActive: loadedEvidence?.hasEngineProcessing,
            systemVolume: validationResult.systemVolume,
            applicationVolume: validationResult.applicationVolume,
            stages: validationResult.processingStages
        )

        let hasMeasuredRate = loadedEvidence?.engineOutputSampleRate != nil
        let hasMeasuredChannels = loadedEvidence?.engineOutputChannelCount != nil
        outputFormat = SignalPathFormatSnapshot(
            codec: "PCM",
            sampleRate: loadedEvidence?.engineOutputSampleRate ?? Double(validationResult.actualSampleRate),
            sampleRateEvidence: hasMeasuredRate ? .measured : .estimated,
            bitDepth: validationResult.actualBitDepth,
            bitDepthEvidence: validationResult.actualBitDepthIsEstimated ? .estimated : .measured,
            channels: loadedEvidence?.engineOutputChannelCount ?? validationResult.actualChannels,
            channelEvidence: hasMeasuredChannels ? .measured : .estimated
        )

        self.device = device
        mismatchReason = validationResult.mismatchReason
        validationIssues = validationResult.validationIssues
        self.updatedAt = updatedAt

        let hasVerifiablePostLoadPath = loadedEvidence != nil &&
            hasMeasuredRate &&
            hasMeasuredChannels &&
            validationResult.measurementEvidence.contains(.actualEngineOutputFormat)

        if !hasVerifiablePostLoadPath {
            eligibility = .unavailable
        } else if validationResult.isValid, processing.isBypassed {
            eligibility = .eligible
        } else {
            eligibility = .ineligible
        }
    }
}
