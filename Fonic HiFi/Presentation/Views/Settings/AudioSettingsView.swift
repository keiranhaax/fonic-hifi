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
    
    var body: some View {
        NavigationStack {
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
                            in: 64...2048,
                            step: 64
                        ) {
                            Text("Buffer Size")
                        }
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
                            Text("176,400 Hz").tag(176400.0)
                            Text("192,000 Hz").tag(192000.0)
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("Audio Configuration")
                } footer: {
                    Text("Lower buffer sizes reduce latency but may cause audio dropouts. Higher sample rates provide better quality but require more processing power.")
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
            print("Testing audio configuration...")
        }
    }
    
    private func resetToDefaults() {
        preferredAudioEngine = "AVAudioEngine"
        enableBitPerfectPlayback = false
        audioBufferSize = 512.0
        sampleRate = 44100.0
    }
}

#Preview {
    AudioSettingsView()
        .audioEngine(AudioEngineFacade(stateManager: PlaybackStateManager()))
}