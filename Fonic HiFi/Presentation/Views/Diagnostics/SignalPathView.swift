import SwiftUI

/// Read-only view of the evidence Fonic can observe along the current
/// playback path. It intentionally distinguishes measurements from estimates.
struct SignalPathView: View {
    @EnvironmentObject private var audioService: AudioEngineFacade

    var body: some View {
        Group {
            if let snapshot = audioService.diagnosticsStatus.signalPath {
                signalPathList(snapshot)
            } else {
                ContentUnavailableView(
                    "Signal Path Unverified",
                    systemImage: "waveform.path.ecg",
                    description: Text(
                        "Play a track to collect source, engine, processing, and output evidence."
                    )
                )
            }
        }
        .navigationTitle("Signal Path")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("SignalPathView")
    }

    private func signalPathList(_ snapshot: SignalPathSnapshot) -> some View {
        List {
            Section("Source") {
                formatRows(snapshot.source)
            }

            if let loadedFormat = snapshot.loadedFormat {
                Section("Decoded by \(snapshot.engineDisplayName)") {
                    formatRows(loadedFormat)
                }
            }

            Section("Processing") {
                LabeledContent("Engine", value: snapshot.engineDisplayName)
                LabeledContent("DSP") {
                    evidenceValue(
                        processingDescription(snapshot.processing),
                        evidence: snapshot.processing.engineProcessingActive == nil
                            ? .unavailable
                            : .measured
                    )
                }
                LabeledContent("System Volume", value: formattedVolume(snapshot.processing.systemVolume))
                LabeledContent("App Volume", value: formattedVolume(snapshot.processing.applicationVolume))

                ForEach(Array(snapshot.processing.stages.enumerated()), id: \.offset) { _, stage in
                    Label(stage.description, systemImage: "waveform.badge.exclamationmark")
                        .foregroundStyle(stage.affectsBitPerfect ? .orange : .secondary)
                }
            }

            Section("Engine Output") {
                formatRows(snapshot.outputFormat)

                LabeledContent("Route") {
                    Text(snapshot.device?.displayName ?? "Unavailable")
                }

                if let device = snapshot.device {
                    LabeledContent("Connection", value: device.connectionType.description)
                }
            }

            if let device = snapshot.device {
                Section("Device Capabilities") {
                    LabeledContent(
                        "Sample Rates",
                        value: formattedSampleRates(device.supportedSampleRates)
                    )
                    LabeledContent(
                        "Bit Depths",
                        value: formattedBitDepths(device.supportedBitDepths)
                    )
                    LabeledContent(
                        "Channel Limit",
                        value: formattedChannelLimit(device.maxChannels)
                    )
                    LabeledContent(
                        "Capability Status",
                        value: capabilityStatus(for: device)
                    )

                    Text(
                        "Capabilities are reported or estimated for the active route; physical output is not measured."
                    )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !snapshot.validationIssues.isEmpty {
                Section("Detected Issues") {
                    ForEach(Array(snapshot.validationIssues.enumerated()), id: \.offset) { _, issue in
                        Label(issue.description, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(issue.severity == .error ? .red : .orange)
                    }
                }
            }

            Section("Assessment") {
                assessment(snapshot)

                Text(
                    "Fonic checks software eligibility. iOS, the active route, and connected hardware can still alter output. Physical output is not measured."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func formatRows(_ format: SignalPathFormatSnapshot) -> some View {
        LabeledContent("Codec") {
            Text(format.codec ?? "Unavailable")
        }
        LabeledContent("Sample Rate") {
            evidenceValue(
                formattedSampleRate(format.sampleRate),
                evidence: format.sampleRateEvidence
            )
        }
        LabeledContent("Bit Depth") {
            evidenceValue(
                format.bitDepth.map { "\($0)-bit" } ?? "Unavailable",
                evidence: format.bitDepthEvidence
            )
        }
        LabeledContent("Channels") {
            evidenceValue(
                format.channels.map(channelDescription) ?? "Unavailable",
                evidence: format.channelEvidence
            )
        }
    }

    private func assessment(_ snapshot: SignalPathSnapshot) -> some View {
        let presentation = SignalPathBadge.presentation(for: snapshot.eligibility)

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Label(assessmentTitle(snapshot), systemImage: presentation.systemImage)
                .font(.headline)
                .foregroundStyle(assessmentTint(snapshot.eligibility))

            Text(assessmentDetail(snapshot))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func evidenceValue(
        _ value: String,
        evidence: SignalPathEvidenceLevel
    ) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
            Text(evidenceDescription(evidence))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func assessmentTitle(_ snapshot: SignalPathSnapshot) -> String {
        switch snapshot.eligibility {
        case .eligible:
            "No detected conversion"
        case .ineligible:
            "Conversion or processing detected"
        case .unavailable:
            "Signal path unverified"
        }
    }

    private func assessmentDetail(_ snapshot: SignalPathSnapshot) -> String {
        switch snapshot.eligibility {
        case .eligible:
            "The measured engine output matches the source, tracked DSP is bypassed, and software volumes are at unity."
        case .ineligible:
            snapshot.mismatchReason?.userFriendlyDescription
                ?? "At least one measured or reported condition prevents eligibility."
        case .unavailable:
            "Post-load engine output evidence is required before Fonic can assess eligibility."
        }
    }

    private func processingDescription(_ processing: SignalPathProcessingSnapshot) -> String {
        if processing.isBypassed {
            "Bypassed"
        } else if processing.applicationDSPActive || processing.engineProcessingActive == true {
            "Active"
        } else {
            "Unverified"
        }
    }

    private func evidenceDescription(_ evidence: SignalPathEvidenceLevel) -> String {
        switch evidence {
        case .measured:
            "Measured"
        case .reported:
            "File metadata"
        case .estimated:
            "Estimated"
        case .unavailable:
            "Not available"
        }
    }

    private func formattedSampleRate(_ sampleRate: Double?) -> String {
        guard let sampleRate, sampleRate > 0 else { return "Unavailable" }
        let kilohertz = sampleRate / 1_000
        let format = kilohertz.rounded() == kilohertz ? "%.0f kHz" : "%.1f kHz"
        return String(format: format, kilohertz)
    }

    private func formattedSampleRates(_ sampleRates: [Double]) -> String {
        guard !sampleRates.isEmpty else { return "Unavailable" }
        return sampleRates.map { formattedSampleRate($0) }.joined(separator: ", ")
    }

    private func formattedBitDepths(_ bitDepths: [UInt16]) -> String {
        guard !bitDepths.isEmpty else { return "Unavailable" }
        return bitDepths.map { "\($0)-bit" }.joined(separator: ", ")
    }

    private func formattedChannelLimit(_ maxChannels: UInt8) -> String {
        guard maxChannels > 0 else { return "Unavailable" }
        return "Up to \(maxChannels) (\(channelDescription(Int(maxChannels))))"
    }

    private func capabilityStatus(for device: AudioDevice) -> String {
        guard device.isAvailable else { return "Unavailable" }
        return device.supportsBitPerfect ? "Bit-perfect capable" : "Standard output"
    }

    private func channelDescription(_ channels: Int) -> String {
        switch channels {
        case 1:
            "Mono"
        case 2:
            "Stereo"
        default:
            "\(channels) channels"
        }
    }

    private func formattedVolume(_ volume: Float) -> String {
        "\(Int((volume * 100).rounded()))%"
    }

    private func assessmentTint(_ eligibility: SignalPathEligibility) -> Color {
        switch eligibility {
        case .eligible:
            .green
        case .ineligible:
            .orange
        case .unavailable:
            .secondary
        }
    }
}

#Preview {
    NavigationStack {
        SignalPathView()
            .audioEngine(AudioEngineFacade())
    }
}
