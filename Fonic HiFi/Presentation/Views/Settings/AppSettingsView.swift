//
//  AppSettingsView.swift
//  Fonic HiFi
//
//  Created by Assistant on 12/22/24.
//
//  Supporting views for Settings (About, Privacy Policy, Terms of Service)
//

import SwiftUI

// MARK: - About View

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)

                    Text("Fonic HiFi")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(appVersionString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                        FeatureRow(
                            title: "Bit-Perfect Eligibility",
                            description: "Checks configuration; physical output is not measured"
                        )
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

    private var appVersionString: LocalizedStringResource {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return LocalizedStringResource(
            "Version \(version) (\(build))",
            comment: "App version followed by the build number"
        )
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let title: LocalizedStringResource
    let description: LocalizedStringResource

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Privacy Policy View

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

                Text(
                    """
                    Fonic HiFi only accesses your music files with your explicit permission.
                    We do not collect, store, or transmit any personal data or music files to external servers.
                    """
                )
                .font(.body)

                Text("Local Storage")
                    .font(.headline)

                Text(
                    """
                    All app data, including your music library metadata and preferences, is stored locally on your device.
                    This data is not shared with third parties.
                    """
                )
                .font(.body)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Terms of Service View

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

                Text(
                    """
                    Fonic HiFi is intended for personal use with legally obtained music files.
                    Users are responsible for ensuring they have the right to play the music files they import.
                    """
                )
                .font(.body)

                Text("Liability")
                    .font(.headline)

                Text(
                    """
                    The app is provided 'as is' without warranties.
                    We are not liable for any data loss or damage resulting from the use of this app.
                    """
                )
                .font(.body)
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Previews

#Preview("About") {
    NavigationStack {
        AboutView()
    }
}

#Preview("Privacy Policy") {
    NavigationStack {
        PrivacyPolicyView()
    }
}

#Preview("Terms of Service") {
    NavigationStack {
        TermsOfServiceView()
    }
}
