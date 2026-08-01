//
//  EqualizerView.swift
//  Fonic HiFi
//
//  10-band parametric equalizer UI with presets and DSP indicator
//

import SwiftUI

struct EqualizerView: View {
    @EnvironmentObject private var audioEngine: AudioEngineFacade
    @Environment(\.locale) private var locale
    @State private var configuration = EqualizerConfiguration.default
    @State private var selectedPreset: String = "Flat"
    @State private var hasLoadedFromPersistence = false

    private let frequencies: [Double] = [32, 64, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]
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
                        Text("Not bit-perfect eligible")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            if let unavailableMessage = localizedUnavailableMessage {
                Section {
                    Label("Equalizer Unavailable", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(verbatim: unavailableMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            // Enable Toggle Section
            Section {
                Toggle("Enable Equalizer", isOn: $configuration.isEnabled)
                    .onChange(of: configuration.isEnabled) { _, _ in
                        applyConfiguration()
                    }
            } footer: {
                Text("Enabling the equalizer makes playback ineligible for bit-perfect output.")
            }

            // Preset Picker Section
            Section("Preset") {
                Picker("Preset", selection: $selectedPreset) {
                    ForEach(presetNames, id: \.self) { name in
                        presetLabel(name)
                            .tag(name)
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

            // Frequency Response Curve
            Section {
                EQCurveView(configuration: configuration)
            } header: {
                Text("Frequency Response")
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
                    ScrollView(.horizontal) {
                        HStack(alignment: .center, spacing: 4) {
                            ForEach(0..<10, id: \.self) { index in
                                VStack(spacing: 4) {
                                    // Vertical slider
                                    VerticalSlider(
                                        value: $configuration.bands[index].gain,
                                        range: -12...12,
                                        accessibilityLabel: LocalizedFormatters.frequency(
                                            frequencies[index],
                                            locale: locale
                                        )
                                    )
                                    .frame(width: 44, height: 140)
                                    .disabled(!configuration.isEnabled)
                                    .onChange(of: configuration.bands[index].gain) { _, _ in
                                        selectedPreset = "Custom"
                                        applyConfiguration()
                                    }

                                    // Frequency label
                                    Text(verbatim: frequencies[index].formatted(
                                        .number
                                            .notation(.compactName)
                                            .locale(locale)
                                    ))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    // Gain value
                                    Text(verbatim: LocalizedFormatters.gainNumber(
                                        configuration.bands[index].gain,
                                        locale: locale
                                    ))
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(gainColor(for: configuration.bands[index].gain))
                                }
                                .frame(width: 44)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .scrollIndicators(.hidden)
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
        .task {
            // The facade restores persistence during audio-service initialization.
            guard !hasLoadedFromPersistence else { return }
            hasLoadedFromPersistence = true

            configuration = audioEngine.equalizerConfiguration
            selectedPreset = configuration.presetName ?? "Custom"
        }
    }

    private func applyConfiguration() {
        Task {
            await audioEngine.applyEQ(configuration)
        }
    }

    private var localizedUnavailableMessage: String? {
        guard case let .unsupported(engine) = audioEngine.equalizerApplicationResult else {
            return nil
        }
        return LocalizedFormatters.equalizerUnavailable(
            engineName: LocalizedFormatters.audioEngineName(engine, locale: locale),
            locale: locale
        )
    }

    @ViewBuilder
    private func presetLabel(_ name: String) -> some View {
        switch name {
        case "Flat":
            Text("Flat")
        case "Bass Boost":
            Text("Bass Boost")
        case "Treble Boost":
            Text("Treble Boost")
        case "Vocal":
            Text("Vocal")
        case "Rock":
            Text("Rock")
        default:
            Text(verbatim: name)
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
    @Environment(\.locale) private var locale
    @Binding var value: Float
    let range: ClosedRange<Float>
    let accessibilityLabel: String

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
                        setValue(range.lowerBound + Float(clampedY) * (range.upperBound - range.lowerBound))
                    }
            )
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(LocalizedFormatters.gainAccessibilityValue(
            value,
            locale: locale
        ))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: setValue(value + 0.5)
            case .decrement: setValue(value - 0.5)
            @unknown default: break
            }
        }
    }

    private func setValue(_ proposedValue: Float) {
        let clampedValue = min(range.upperBound, max(range.lowerBound, proposedValue))
        value = abs(clampedValue) < 0.5 ? 0 : round(clampedValue * 2) / 2
    }
}

#Preview {
    NavigationStack {
        EqualizerView()
    }
    .audioEngine(AudioEngineFacade())
}
