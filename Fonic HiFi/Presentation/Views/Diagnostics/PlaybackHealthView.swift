import SwiftUI

/// Read-only, session-scoped playback reliability timeline.
struct PlaybackHealthView: View {
    @EnvironmentObject private var audioService: AudioEngineFacade

    var body: some View {
        Group {
            if audioService.playbackHealthEvents.isEmpty {
                ContentUnavailableView(
                    "No Playback Events",
                    systemImage: "checkmark.circle",
                    description: Text(
                        "Recovery and reliability events will appear here when they occur."
                    )
                )
            } else {
                eventList(audioService.playbackHealthEvents)
            }
        }
        .navigationTitle("Playback Health")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("PlaybackHealthView")
    }

    private func eventList(_ events: [PlaybackHealthEvent]) -> some View {
        let summary = PlaybackHealthSummary(events: events)

        return List {
            Section("This Session") {
                LabeledContent("Events Recorded", value: summary.totalEvents.formatted())
                LabeledContent("Media Service Resets", value: summary.resetsDetected.formatted())
                LabeledContent("Recoveries Succeeded", value: summary.recoveriesSucceeded.formatted())
                LabeledContent("Recovery Failures", value: summary.recoveriesFailed.formatted())
            }

            Section("Recent Events") {
                ForEach(events.reversed()) { event in
                    PlaybackHealthEventRow(event: event)
                }
            }

            Section {
                Text(
                    "Fonic keeps up to 200 events in memory for this app session. Track names and file locations are never recorded."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct PlaybackHealthSummary: Equatable {
    let totalEvents: Int
    let resetsDetected: Int
    let recoveriesSucceeded: Int
    let recoveriesFailed: Int

    init(events: [PlaybackHealthEvent]) {
        totalEvents = events.count
        resetsDetected = events.count { $0.kind == .mediaServicesResetDetected }
        recoveriesSucceeded = events.count { $0.kind == .mediaServicesResetRecoverySucceeded }
        recoveriesFailed = events.count {
            $0.kind == .mediaServicesResetRecoveryFailed ||
                $0.kind == .audioEngineConfigurationRecoveryFailed
        }
    }
}

private struct PlaybackHealthEventRow: View {
    let event: PlaybackHealthEvent

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
                Text(eventTitle)
                    .font(.body.weight(.medium))

                Text(event.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute().second())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let detail = event.detail {
                    Text(detail)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: eventIcon)
                .foregroundStyle(eventTint)
        }
        .accessibilityElement(children: .combine)
    }

    private var eventTitle: String {
        switch event.kind {
        case .mediaServicesResetDetected:
            "Media services reset detected"
        case .mediaServicesResetRecoverySucceeded:
            "Playback recovery succeeded"
        case .mediaServicesResetRecoveryFailed:
            "Playback recovery failed"
        case .audioEngineConfigurationRecoveryFailed:
            "Audio route recovery failed"
        }
    }

    private var eventIcon: String {
        switch event.kind {
        case .mediaServicesResetDetected:
            "arrow.trianglehead.2.clockwise.rotate.90"
        case .mediaServicesResetRecoverySucceeded:
            "checkmark.circle.fill"
        case .mediaServicesResetRecoveryFailed:
            "exclamationmark.triangle.fill"
        case .audioEngineConfigurationRecoveryFailed:
            "arrow.trianglehead.2.clockwise.rotate.90"
        }
    }

    private var eventTint: Color {
        switch event.kind {
        case .mediaServicesResetDetected:
            .orange
        case .mediaServicesResetRecoverySucceeded:
            .green
        case .mediaServicesResetRecoveryFailed:
            .red
        case .audioEngineConfigurationRecoveryFailed:
            .red
        }
    }
}

#Preview {
    NavigationStack {
        PlaybackHealthView()
            .audioEngine(AudioEngineFacade())
    }
}
