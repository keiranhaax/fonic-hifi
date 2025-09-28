import SwiftUI

@MainActor
struct DiagnosticsDetailView: View {
    let diagnostics: DiagnosticsStatus

    private var validationResult: BitPerfectValidationResult? { diagnostics.validationResult }
    private var device: AudioDevice? { diagnostics.device }
    private var dacInfo: DACCompatibilityInfo? { diagnostics.dacInfo }
    private var metrics: AudioMetrics? { diagnostics.metrics }

    var body: some View {
        NavigationStack {
            List {
                validationSection
                deviceSection
                metricsSection
            }
            .navigationTitle("Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var validationSection: some View {
        Section("Bit-Perfect") {
            if let result = validationResult {
                LabeledContent("Status") {
                    Text(result.isValid ? "Bit-perfect" : "Issues detected")
                        .foregroundStyle(result.isValid ? Color.green : Color.orange)
                        .fontWeight(.semibold)
                }

                if let reason = result.mismatchReason, !result.isValid {
                    LabeledContent("Reason") {
                        Text(reason.userFriendlyDescription)
                            .foregroundStyle(Color.secondary)
                    }
                }

                LabeledContent("Sample Rate") {
                    Text("\(result.actualSampleRate) Hz")
                }

                LabeledContent("Bit Depth") {
                    Text("\(result.actualBitDepth)-bit")
                }
            } else {
                Text("No validation data available")
                    .foregroundStyle(Color.secondary)
            }
        }
    }

    @ViewBuilder
    private var deviceSection: some View {
        Section("Output Device") {
            if let dacInfo {
                LabeledContent("Device") {
                    Text("\(dacInfo.manufacturer) \(dacInfo.modelName)")
                }

                LabeledContent("Supports Bit-perfect") {
                    Image(systemName: dacInfo.supportsBitPerfect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(dacInfo.supportsBitPerfect ? Color.green : Color.orange)
                }

                if let requirement = dacInfo.specialRequirements.first {
                    Text("Requirement: \(requirement)")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .padding(.top, 4)
                }

                if let note = dacInfo.userNotes.first {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            } else if let device {
                LabeledContent("Device") {
                    Text(device.name)
                }

                LabeledContent("Connection") {
                    Text(device.connectionType.rawValue)
                }
            } else {
                Text("No device data available")
                    .foregroundStyle(Color.secondary)
            }
        }
    }

    @ViewBuilder
    private var metricsSection: some View {
        Section("Performance Metrics") {
            if let metrics {
                LabeledContent("CPU") {
                    Text(String(format: "%.1f%%", metrics.cpuUsage))
                }

                LabeledContent("Memory") {
                    Text(ByteCountFormatter.string(fromByteCount: metrics.memoryUsage, countStyle: .memory))
                }

                LabeledContent("Buffer Underruns") {
                    Text("\(metrics.bufferUnderruns)")
                }

                LabeledContent("Render Latency") {
                    Text(String(format: "%.2f ms", metrics.renderLatency * 1000))
                }
            } else {
                Text("Metrics unavailable")
                    .foregroundStyle(Color.secondary)
            }
        }
    }
}

#Preview {
    DiagnosticsDetailView(
        diagnostics: DiagnosticsStatus(
            track: TrackSummary(
                id: UUID(),
                title: "Test Track",
                artist: "Artist",
                album: "Album",
                format: "FLAC",
            ),
            validationResult: BitPerfectValidationResult(
                isValid: true,
                expectedSampleRate: 44100,
                actualSampleRate: 44100,
                expectedBitDepth: 16,
                actualBitDepth: 16,
            ),
            device: nil,
            dacInfo: nil,
            metrics: AudioMetrics(
                cpuUsage: 12.5,
                memoryUsage: 45_000_000,
                bufferUnderruns: 0,
                decodingLatency: 0.002,
                bufferFillLevel: 0.9,
                droppedFrames: 0,
                renderLatency: 0.006,
            ),
            updatedAt: Date(),
        ),
    )
}
