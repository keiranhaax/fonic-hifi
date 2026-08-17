//
//  AudioSettingsView.swift
//  Fonic HiFi
//
//  Created by Assistant on 12/22/24.
//

import OSLog
import SwiftUI

struct AudioSettingsView: View {
    @EnvironmentObject private var audioService: AudioEngineFacade
    @Environment(\.locale) private var locale
    @AppStorage(AudioEnginePreference.storageKey) private var preferredAudioEngine: AudioEngineType = .avAudioEngine

    private let logger = Log.logger(.audio)

    var body: some View {
        Form {
            Section {
                Picker("Audio Engine", selection: $preferredAudioEngine) {
                    ForEach(AudioEngineType.allCases, id: \.self) { engineType in
                        Text(audioEngineDisplayName(engineType)).tag(engineType)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Audio Engine")
            } footer: {
                Text("Choose the audio engine for playback. Different engines may provide different audio quality and compatibility.")
            }

            Section {
                Toggle("Gapless Playback", isOn: gaplessEnabledBinding)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Crossfade")
                        Spacer()
                        Group {
                            if audioService.crossfadeDuration == 0 {
                                Text("Off")
                            } else {
                                Text(verbatim: LocalizedFormatters.crossfadeDuration(
                                    Int(audioService.crossfadeDuration),
                                    locale: locale
                                ))
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                    Slider(value: crossfadeDurationBinding, in: 0 ... 12, step: 1)
                        .accessibilityLabel("Crossfade Duration")
                        .accessibilityValue(
                            audioService.crossfadeDuration == 0
                                ? String(localized: "Off")
                                : LocalizedFormatters.crossfadeDuration(
                                    Int(audioService.crossfadeDuration),
                                    locale: locale
                                )
                        )
                        .accessibilityIdentifier("CrossfadeDurationSlider")
                }

                Picker("Replay Gain", selection: replayGainModeBinding) {
                    Text("Off").tag(ReplayGainMode.off)
                    Text("Track").tag(ReplayGainMode.track)
                    Text("Album").tag(ReplayGainMode.album)
                }
            } header: {
                Text("Playback Features")
            } footer: {
                Text("Gapless eliminates silence between tracks. Crossfade smoothly transitions between tracks. Replay Gain normalizes volume across your library.")
            }

            Section {
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
        .task {
            normalizePersistedEnginePreference()
        }
    }

    private var gaplessEnabledBinding: Binding<Bool> {
        Binding(
            get: { audioService.isGaplessEnabled },
            set: { enabled in
                Task {
                    await audioService.updateGaplessEnabled(enabled)
                }
            }
        )
    }

    private var crossfadeDurationBinding: Binding<Double> {
        Binding(
            get: { audioService.crossfadeDuration },
            set: { duration in
                Task {
                    await audioService.updateCrossfadeDuration(duration)
                }
            }
        )
    }

    private var replayGainModeBinding: Binding<ReplayGainMode> {
        Binding(
            get: { audioService.replayGainMode },
            set: { mode in
                Task {
                    await audioService.updateReplayGainMode(mode)
                }
            }
        )
    }

    private func audioEngineDisplayName(
        _ engineType: AudioEngineType
    ) -> LocalizedStringResource {
        switch engineType {
        case .avAudioEngine:
            "Native Audio Engine"
        case .audioKitEngine:
            "AudioKit Engine"
        }
    }

    private func normalizePersistedEnginePreference() {
        let storedValue = UserDefaults.standard.string(forKey: AudioEnginePreference.storageKey)

        switch AudioEnginePreference(storedValue: storedValue) {
        case .automatic:
            break
        case let .requested(engineType):
            preferredAudioEngine = engineType
        case .unsupported:
            logger.warning("Unsupported audio engine preference; using Native Audio Engine")
            preferredAudioEngine = .avAudioEngine
        }
    }

    private func resetToDefaults() {
        preferredAudioEngine = .avAudioEngine
        Task {
            await audioService.updateGaplessEnabled(AudioEngineConfiguration.default.enableGapless)
            await audioService.updateCrossfadeDuration(AudioEngineConfiguration.default.crossfadeDuration)
            await audioService.updateReplayGainMode(AudioEngineConfiguration.default.replayGainMode)
        }
    }
}

#Preview {
    AudioSettingsView()
        .audioEngine(AudioEngineFacade(stateManager: PlaybackStateManager()))
}
