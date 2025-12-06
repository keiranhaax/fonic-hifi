//
//  EqualizerView.swift
//  Fonic HiFi
//
//  10-band parametric equalizer UI with presets and DSP indicator
//

import SwiftUI

struct EqualizerView: View {
    @Environment(\.audioEngine) private var audioEngine
    @State private var configuration = EqualizerConfiguration.default
    @State private var selectedPreset: String = "Flat"

    private let frequencyLabels = ["32", "64", "125", "250", "500", "1K", "2K", "4K", "8K", "16K"]
    private let presetNames = Array(EqualizerConfiguration.presets.keys).sorted()

    var body: some View {
        List {
            // DSP Warning Section
            if configuration.isEnabled {
                Section {
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundStyle(.orange)
                        Text("DSP Active")
                            .font(.subheadline.bold())
                        Spacer()
                        Text("Bit-perfect disabled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            // Enable Toggle Section
            Section {
                Toggle("Enable Equalizer", isOn: $configuration.isEnabled)
                    .onChange(of: configuration.isEnabled) { _, _ in
                        applyConfiguration()
                    }
            } footer: {
                Text("Enabling the equalizer disables bit-perfect playback mode.")
            }

            // Preset Picker Section
            Section("Preset") {
                Picker("Preset", selection: $selectedPreset) {
                    ForEach(presetNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedPreset) { _, newValue in
                    if let preset = EqualizerConfiguration.presets[newValue] {
                        configuration = preset
                        applyConfiguration()
                    }
                }
            }

            // Band Sliders Section
            Section("Frequency Bands") {
                VStack(spacing: 16) {
                    // Gain scale labels
                    HStack {
                        Text("+12 dB")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("0 dB")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("-12 dB")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // Band sliders
                    HStack(alignment: .center, spacing: 4) {
                        ForEach(0..<10, id: \.self) { index in
                            VStack(spacing: 4) {
                                // Vertical slider
                                VerticalSlider(
                                    value: $configuration.bands[index].gain,
                                    range: -12...12
                                )
                                .frame(height: 140)
                                .disabled(!configuration.isEnabled)
                                .onChange(of: configuration.bands[index].gain) { _, _ in
                                    selectedPreset = "Custom"
                                    applyConfiguration()
                                }

                                // Frequency label
                                Text(frequencyLabels[index])
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                // Gain value
                                Text(String(format: "%.1f", configuration.bands[index].gain))
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(gainColor(for: configuration.bands[index].gain))
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.vertical)
            }

            // Reset Button
            Section {
                Button("Reset to Flat") {
                    configuration = .default
                    selectedPreset = "Flat"
                    applyConfiguration()
                }
                .foregroundStyle(.orange)
            }
        }
        .navigationTitle("Equalizer")
        .onAppear {
            // Sync preset name with current configuration
            if let presetName = configuration.presetName {
                selectedPreset = presetName
            }
        }
    }

    private func applyConfiguration() {
        Task {
            await audioEngine?.applyEQ(configuration)
        }
    }

    private func gainColor(for gain: Float) -> Color {
        if gain > 0 {
            .orange
        } else if gain < 0 {
            .blue
        } else {
            .secondary
        }
    }
}

// MARK: - Vertical Slider

private struct VerticalSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let normalizedValue = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let yPosition = height * (1 - normalizedValue)

            ZStack {
                // Track background
                Capsule()
                    .fill(Color(.systemGray5))
                    .frame(width: 4)

                // Center line (0 dB)
                Rectangle()
                    .fill(Color(.systemGray3))
                    .frame(width: 12, height: 1)
                    .offset(y: (height / 2) - (height * normalizedValue))

                // Active fill
                Capsule()
                    .fill(value >= 0 ? Color.orange : Color.blue)
                    .frame(width: 4, height: abs(CGFloat(value) / 12) * (height / 2))
                    .offset(y: value >= 0 ? -(abs(CGFloat(value) / 12) * (height / 4)) : (abs(CGFloat(value) / 12) * (height / 4)))

                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .offset(y: yPosition - (height / 2))
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let newY = gesture.location.y
                        let normalizedY = 1 - (newY / height)
                        let clampedY = max(0, min(1, normalizedY))
                        let newValue = range.lowerBound + Float(clampedY) * (range.upperBound - range.lowerBound)
                        // Snap to 0 if close
                        if abs(newValue) < 0.5 {
                            value = 0
                        } else {
                            value = round(newValue * 2) / 2 // Round to 0.5
                        }
                    }
            )
        }
        .frame(width: 30)
    }
}

#Preview {
    NavigationStack {
        EqualizerView()
    }
}
