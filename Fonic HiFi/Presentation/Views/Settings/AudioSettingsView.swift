//
//  AudioSettingsView.swift
//  Fonic HiFi
//
//  Created by Assistant on 12/22/24.
//

import SwiftUI

struct AudioSettingsView: View {
    @Environment(\.audioEngine) private var audioService
    @AppStorage("preferredAudioEngine") private var preferredAudioEngine = "AVAudioEngine"
    @AppStorage("enableBitPerfectPlayback") private var enableBitPerfectPlayback = false
    @AppStorage("audioBufferSize") private var audioBufferSize = 512.0
    @AppStorage("sampleRate") private var sampleRate = 44100.0
    @AppStorage("enableGaplessPlayback") private var enableGaplessPlayback = true
    @AppStorage("crossfadeDuration") private var crossfadeDuration: Double = 0.0
    @AppStorage("replayGainMode") private var replayGainMode: String = "off"

    private let logger = Log.logger(.audio)

    var body: some View {
        Group {
            Form {
                Section {
                    Picker("Audio Engine", selection: $preferredAudioEngine) {
                        Text("AVAudioEngine").tag("AVAudioEngine")
                        Text("AudioKit").tag("AudioKit")
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Audio Engine")
                } footer: {
                    Text("Choose the audio engine for playback. Different engines may provide different audio quality and compatibility.")
                }

                Section {
                    Toggle("Enable Bit-Perfect Playback", isOn: $enableBitPerfectPlayback)
                } header: {
                    Text("Audio Quality")
                } footer: {
                    Text("Bit-perfect playback ensures no digital processing is applied to the audio signal, preserving the original quality.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Buffer Size")
                            Spacer()
                            Text("\(Int(audioBufferSize)) samples")
                                .foregroundColor(.secondary)
                        }

                        Slider(
                            value: $audioBufferSize,
                            in: 64 ... 2048,
                            step: 64
                        )
                        .accessibilityLabel("Buffer Size")
                        .accessibilityValue("\(Int(audioBufferSize)) samples")
                        .accessibilityIdentifier("BufferSizeSlider")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Sample Rate")
                            Spacer()
                            Text("\(Int(sampleRate)) Hz")
                                .foregroundColor(.secondary)
                        }

                        Picker("Sample Rate", selection: $sampleRate) {
                            Text("44,100 Hz").tag(44100.0)
                            Text("48,000 Hz").tag(48000.0)
                            Text("88,200 Hz").tag(88200.0)
                            Text("96,000 Hz").tag(96000.0)
                            Text("176,400 Hz").tag(176_400.0)
                            Text("192,000 Hz").tag(192_000.0)
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("Audio Configuration")
                } footer: {
                    Text("Lower buffer sizes reduce latency but may cause audio dropouts. Higher sample rates provide better quality but require more processing power.")
                }

                Section {
                    Toggle("Gapless Playback", isOn: $enableGaplessPlayback)
                        .onChange(of: enableGaplessPlayback) { _, newValue in
                            Task {
                                await audioService?.updateGaplessEnabled(newValue)
                            }
                        }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Crossfade")
                            Spacer()
                            Text(crossfadeDuration == 0 ? "Off" : "\(Int(crossfadeDuration))s")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $crossfadeDuration, in: 0...12, step: 1)
                            .accessibilityLabel("Crossfade Duration")
                            .accessibilityValue(
                                crossfadeDuration == 0 ? "Off" : "\(Int(crossfadeDuration)) seconds"
                            )
                            .accessibilityIdentifier("CrossfadeDurationSlider")
                            .onChange(of: crossfadeDuration) { _, newValue in
                                Task {
                                    await audioService?.updateCrossfadeDuration(newValue)
                                }
                            }
                    }

                    Picker("Replay Gain", selection: $replayGainMode) {
                        Text("Off").tag("off")
                        Text("Track").tag("track")
                        Text("Album").tag("album")
                    }
                    .onChange(of: replayGainMode) { _, newValue in
                        let mode = ReplayGainMode(rawValue: newValue) ?? .off
                        Task {
                            await audioService?.updateReplayGainMode(mode)
                        }
                    }
                } header: {
                    Text("Playback Features")
                } footer: {
                    Text("Gapless eliminates silence between tracks. Crossfade smoothly transitions between tracks. Replay Gain normalizes volume across your library.")
                }

                Section {
                    Button("Test Audio Configuration") {
                        testAudioConfiguration()
                    }

                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .foregroundColor(.red)
                } header: {
                    Text("Actions")
                }
            }
            .navigationTitle("Audio Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func testAudioConfiguration() {
        // Test audio configuration
        Task {
            // This would test the current audio configuration
            logger.info("Testing audio configuration from settings view")
        }
    }

    private func resetToDefaults() {
        preferredAudioEngine = "AVAudioEngine"
        enableBitPerfectPlayback = false
        audioBufferSize = 512.0
        sampleRate = 44100.0
        enableGaplessPlayback = true
        crossfadeDuration = 0.0
        replayGainMode = "off"
    }
}

#Preview {
    AudioSettingsView()
        .audioEngine(AudioEngineFacade(stateManager: PlaybackStateManager()))
}
