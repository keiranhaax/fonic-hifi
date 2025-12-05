//
//  SettingsView.swift
//  Fonic HiFi
//
//  Created by Assistant on 12/22/24.
//

import SwiftUI

struct SettingsView: View {
    // MARK: - AppStorage (inline toggles)

    @AppStorage("enableBitPerfectPlayback") private var bitPerfectEnabled = false
    @AppStorage("darkModeEnabled") private var darkModeEnabled = true
    @AppStorage("showNowPlayingAnimation") private var animationEnabled = true
    @AppStorage("enableHapticFeedback") private var hapticsEnabled = true
    @AppStorage("showFileExtensions") private var showExtensions = true
    @AppStorage("artworkThemingEnabled") private var artworkThemingEnabled = true
    @AppStorage("artworkThemingLightMode") private var artworkThemingLightMode = true

    @Environment(\.themePalette) private var theme

    private let logger = Log.logger(.presentation)

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Playback

                Section("Playback") {
                    NavigationLink {
                        AudioSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "speaker.wave.3.fill",
                            iconColor: .orange,
                            title: "Audio Engine",
                            subtitle: "Quality, engine, buffer settings"
                        )
                    }

                    Toggle(isOn: $bitPerfectEnabled) {
                        SettingsRow(
                            icon: "waveform",
                            iconColor: .blue,
                            title: "Bit-Perfect Mode"
                        )
                    }
                }

                // MARK: - Appearance

                Section("Appearance") {
                    Toggle(isOn: $darkModeEnabled) {
                        SettingsRow(
                            icon: "moon.fill",
                            iconColor: .purple,
                            title: "Dark Mode"
                        )
                    }

                    Toggle(isOn: $animationEnabled) {
                        SettingsRow(
                            icon: "waveform.circle.fill",
                            iconColor: .pink,
                            title: "Now Playing Animation"
                        )
                    }

                    Toggle(isOn: $hapticsEnabled) {
                        SettingsRow(
                            icon: "hand.tap.fill",
                            iconColor: .gray,
                            title: "Haptic Feedback"
                        )
                    }

                    Toggle(isOn: $artworkThemingEnabled) {
                        SettingsRow(
                            icon: "paintpalette.fill",
                            iconColor: .orange,
                            title: "Artwork Theming"
                        )
                    }

                    if artworkThemingEnabled {
                        Toggle(isOn: $artworkThemingLightMode) {
                            SettingsRow(
                                icon: "sun.max.fill",
                                iconColor: .yellow,
                                title: "Theme in Light Mode"
                            )
                        }
                    }
                }

                // MARK: - Storage

                Section("Storage") {
                    NavigationLink {
                        FileManagerView()
                    } label: {
                        SettingsRow(
                            icon: "folder.fill",
                            iconColor: .blue,
                            title: "File Manager",
                            subtitle: "Browse and manage imported files"
                        )
                    }

                    Toggle(isOn: $showExtensions) {
                        SettingsRow(
                            icon: "doc.text.fill",
                            iconColor: .gray,
                            title: "Show File Extensions"
                        )
                    }
                }

                // MARK: - About

                Section("About") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        SettingsRow(
                            icon: "info.circle.fill",
                            iconColor: .blue,
                            title: "About Fonic HiFi",
                            subtitle: appVersionString
                        )
                    }

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        SettingsRow(
                            icon: "hand.raised.fill",
                            iconColor: .green,
                            title: "Privacy Policy"
                        )
                    }

                    NavigationLink {
                        TermsOfServiceView()
                    } label: {
                        SettingsRow(
                            icon: "doc.text.fill",
                            iconColor: .gray,
                            title: "Terms of Service"
                        )
                    }
                }

                // MARK: - Advanced

                Section("Advanced") {
                    Button {
                        exportSettings()
                    } label: {
                        SettingsRow(
                            icon: "square.and.arrow.up",
                            iconColor: .blue,
                            title: "Export Settings"
                        )
                    }

                    Button {
                        importSettings()
                    } label: {
                        SettingsRow(
                            icon: "square.and.arrow.down",
                            iconColor: .blue,
                            title: "Import Settings"
                        )
                    }

                    Button(role: .destructive) {
                        resetSettings()
                    } label: {
                        SettingsRow(
                            icon: "arrow.counterclockwise",
                            iconColor: .red,
                            title: "Reset All Settings"
                        )
                    }
                }
            }
            .tint(theme.accent)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Computed Properties

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    // MARK: - Actions

    private func exportSettings() {
        logger.info("Exporting settings")
    }

    private func importSettings() {
        logger.info("Importing settings")
    }

    private func resetSettings() {
        bitPerfectEnabled = false
        darkModeEnabled = true
        animationEnabled = true
        hapticsEnabled = true
        showExtensions = true
        artworkThemingEnabled = true
        artworkThemingLightMode = true
        logger.info("Reset all settings to defaults")
    }
}

// MARK: - Settings Row Component

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
