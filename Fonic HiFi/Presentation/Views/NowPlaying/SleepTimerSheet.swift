import SwiftUI

/// Sheet for configuring and monitoring the sleep timer.
struct SleepTimerSheet: View {
    @ObservedObject var timerManager: SleepTimerManager
    @Environment(\.dismiss) private var dismiss

    // MARK: - Timer Presets

    private let presets: [(label: String, seconds: Int)] = [
        ("5 min", 5 * 60),
        ("10 min", 10 * 60),
        ("15 min", 15 * 60),
        ("30 min", 30 * 60),
        ("45 min", 45 * 60),
        ("1 hour", 60 * 60),
    ]

    // MARK: - State

    @State private var enableFadeOut: Bool = true
    @State private var fadeOutDuration: Double = 30

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                if timerManager.isActive {
                    activeTimerSection
                } else {
                    presetSection
                    fadeOutSection
                }
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var activeTimerSection: some View {
        Section {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(.orange)
                    .font(.title2)

                VStack(alignment: .leading) {
                    Text("Time Remaining")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(formatTime(timerManager.remainingSeconds))
                        .font(.system(.title, design: .monospaced, weight: .medium))
                }

                Spacer()
            }
            .padding(.vertical, 8)

            Button(role: .destructive) {
                timerManager.stop()
            } label: {
                HStack {
                    Spacer()
                    Text("Cancel Timer")
                    Spacer()
                }
            }
        } header: {
            Text("Active Timer")
        }
    }

    private var presetSection: some View {
        Section {
            ForEach(presets, id: \.seconds) { preset in
                Button {
                    startTimer(seconds: preset.seconds)
                } label: {
                    HStack {
                        Text(preset.label)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "moon.zzz")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Set Timer")
        } footer: {
            Text("Playback will pause when the timer ends.")
        }
    }

    private var fadeOutSection: some View {
        Section {
            Toggle("Fade Out", isOn: $enableFadeOut)

            if enableFadeOut {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text("\(Int(fadeOutDuration)) seconds")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $fadeOutDuration, in: 10...60, step: 5)
                }
            }
        } header: {
            Text("Fade Out")
        } footer: {
            Text("Gradually reduce volume before pausing.")
        }
    }

    // MARK: - Helpers

    private func startTimer(seconds: Int) {
        timerManager.fadeOutDuration = enableFadeOut ? Int(fadeOutDuration) : 0
        timerManager.start(seconds: seconds, currentVolume: 1.0)
        dismiss()
    }

    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

#Preview {
    SleepTimerSheet(timerManager: SleepTimerManager())
}
