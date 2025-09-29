//
//  AppSettingsView.swift
//  Fonic HiFi
//
//  Created by Assistant on 12/22/24.
//

import SwiftUI

struct AppSettingsView: View {
    @AppStorage("darkModeEnabled") private var darkModeEnabled = true
    @AppStorage("showNowPlayingAnimation") private var showNowPlayingAnimation = true
    @AppStorage("autoImportFromPhotos") private var autoImportFromPhotos = false
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback = true
    @AppStorage("showFileExtensions") private var showFileExtensions = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Dark Mode", isOn: $darkModeEnabled)
                    Toggle("Now Playing Animation", isOn: $showNowPlayingAnimation)
                    Toggle("Haptic Feedback", isOn: $enableHapticFeedback)
                } header: {
                    Text("Interface")
                } footer: {
                    Text("Customize the app's appearance and behavior.")
                }

                Section {
                    Toggle("Auto-import from Photos", isOn: $autoImportFromPhotos)
                    Toggle("Show File Extensions", isOn: $showFileExtensions)
                } header: {
                    Text("File Management")
                } footer: {
                    Text("Configure how files are handled and displayed.")
                }

                Section {
                    NavigationLink("About Fonic HiFi") {
                        AboutView()
                    }

                    NavigationLink("Privacy Policy") {
                        PrivacyPolicyView()
                    }

                    NavigationLink("Terms of Service") {
                        TermsOfServiceView()
                    }
                } header: {
                    Text("Information")
                }

                Section {
                    Button("Export Settings") {
                        exportSettings()
                    }

                    Button("Import Settings") {
                        importSettings()
                    }

                    Button("Reset All Settings") {
                        resetAllSettings()
                    }
                    .foregroundColor(.red)
                } header: {
                    Text("Settings Management")
                }
            }
            .navigationTitle("App Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func exportSettings() {
        // Export settings functionality
        print("Exporting settings...")
    }

    private func importSettings() {
        // Import settings functionality
        print("Importing settings...")
    }

    private func resetAllSettings() {
        darkModeEnabled = true
        showNowPlayingAnimation = true
        autoImportFromPhotos = false
        enableHapticFeedback = true
        showFileExtensions = true
    }
}

// MARK: - Supporting Views

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Fonic HiFi")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Version 1.0.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()

                VStack(alignment: .leading, spacing: 16) {
                    Text("About")
                        .font(.headline)

                    Text("Fonic HiFi is a high-fidelity music player designed for audiophiles who demand the best possible sound quality from their digital music collection.")
                        .font(.body)

                    Text("Features")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(title: "Bit-Perfect Playback", description: "Unaltered digital audio signal")
                        FeatureRow(title: "Multiple Audio Engines", description: "Choose your preferred audio backend")
                        FeatureRow(title: "High-Resolution Support", description: "Up to 192kHz/24-bit audio")
                        FeatureRow(title: "File Management", description: "Organize your music collection")
                    }
                }
                .padding()
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureRow: View {
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your privacy is important to us. This policy explains how we handle your data.")
                    .font(.body)

                Text("Data Collection")
                    .font(.headline)

                Text("Fonic HiFi only accesses your music files with your explicit permission. We do not collect, store, or transmit any personal data or music files to external servers.")
                    .font(.body)

                Text("Local Storage")
                    .font(.headline)

                Text("All app data, including your music library metadata and preferences, is stored locally on your device. This data is not shared with third parties.")
                    .font(.body)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Terms of Service")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("By using Fonic HiFi, you agree to these terms.")
                    .font(.body)

                Text("Usage")
                    .font(.headline)

                Text("Fonic HiFi is intended for personal use with legally obtained music files. Users are responsible for ensuring they have the right to play the music files they import.")
                    .font(.body)

                Text("Liability")
                    .font(.headline)

                Text("The app is provided 'as is' without warranties. We are not liable for any data loss or damage resulting from the use of this app.")
                    .font(.body)
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    AppSettingsView()
}
