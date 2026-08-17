//
//  SettingsView.swift
//  Fonic HiFi
//
//  Created by Assistant on 12/22/24.
//

import OSLog
import SwiftUI

struct SettingsView: View {
    // MARK: - AppStorage (inline toggles)

    @AppStorage("darkModeEnabled") private var darkModeEnabled = true
    @AppStorage("showNowPlayingAnimation") private var animationEnabled = true
    @AppStorage("enableHapticFeedback") private var hapticsEnabled = true
    @AppStorage("showFileExtensions") private var showExtensions = true
    @AppStorage("artworkThemingEnabled") private var artworkThemingEnabled = true
    @AppStorage("artworkThemingLightMode") private var artworkThemingLightMode = true
    @State private var showingResetConfirmation = false

    @Environment(\.themePalette) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                            subtitle: "Engine and playback settings",
                        )
                    }

                    NavigationLink {
                        EqualizerView()
                    } label: {
                        SettingsRow(
                            icon: "slider.horizontal.3",
                            iconColor: .purple,
                            title: "Equalizer",
                            subtitle: "10-band parametric EQ"
                        )
                    }
                }

                // MARK: - Diagnostics

                Section("Diagnostics") {
                    NavigationLink {
                        SignalPathView()
                    } label: {
                        SettingsRow(
                            icon: "waveform.path.ecg",
                            iconColor: .green,
                            title: "Signal Path",
                            subtitle: "Source, processing, and output evidence"
                        )
                    }

                    NavigationLink {
                        PlaybackHealthView()
                    } label: {
                        SettingsRow(
                            icon: "waveform.path",
                            iconColor: .orange,
                            title: "Playback Health",
                            subtitle: "Recent recovery and reliability events"
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
                        showingResetConfirmation = true
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
            .navigationBarTitleDisplayMode(dynamicTypeSize.isAccessibilitySize ? .inline : .large)
            .alert(
                "Reset all settings?",
                isPresented: $showingResetConfirmation
            ) {
                Button("Reset Settings", role: .destructive) {
                    resetSettings()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Playback, appearance, haptics, file display, and artwork theme preferences return to defaults. Your music library and imported files are not deleted.")
            }
        }
    }

    // MARK: - Computed Properties

    private var appVersionString: LocalizedStringResource {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return LocalizedStringResource(
            "Version \(version) (\(build))",
            comment: "App version followed by the build number"
        )
    }

    // MARK: - Actions

    private func exportSettings() {
        logger.info("Exporting settings")
    }

    private func importSettings() {
        logger.info("Importing settings")
    }

    private func resetSettings() {
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
    let title: LocalizedStringResource
    var subtitle: LocalizedStringResource?

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
    if let importService = DataManager.makePreviewImportService() {
        SettingsView()
            .audioEngine(AudioEngineFacade())
            .importService(importService)
    } else {
        Text("Preview unavailable")
    }
}
