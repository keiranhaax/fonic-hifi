//
//  ErrorView.swift
//  Fonic HiFi
//
//  Created by Claude on 9/27/25.
//

import SwiftUI

/// User-friendly error display view
struct ErrorView: View {
    let error: Error
    let retryAction: (() -> Void)?

    init(error: Error, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: errorIcon)
                .font(.system(size: 50))
                .foregroundColor(iconColor)

            // Title
            Text(errorTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            // Description
            Text(errorDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Actions
            VStack(spacing: 12) {
                if let retryAction {
                    Button(action: retryAction) {
                        Label("Try Again", systemImage: "arrow.clockwise")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                // Additional help text
                if let helpText = additionalHelpText {
                    Text(helpText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Error Categorization

    private var errorIcon: String {
        switch categorizeError() {
        case .network:
            "wifi.exclamationmark"
        case .fileAccess:
            "folder.badge.questionmark"
        case .audio:
            "speaker.slash"
        case .storage:
            "externaldrive.badge.exclamationmark"
        case .format:
            "doc.badge.ellipsis"
        case .permission:
            "lock.shield"
        case .memory:
            "memorychip"
        case .general:
            "exclamationmark.triangle"
        }
    }

    private var iconColor: Color {
        switch categorizeError() {
        case .network:
            .blue
        case .fileAccess, .storage:
            .orange
        case .audio, .format:
            .purple
        case .permission:
            .red
        case .memory:
            .yellow
        case .general:
            .secondary
        }
    }

    private var errorTitle: String {
        switch categorizeError() {
        case .network:
            "Network Connection Issue"
        case .fileAccess:
            "Cannot Access File"
        case .audio:
            "Audio Playback Error"
        case .storage:
            "Storage Issue"
        case .format:
            "Unsupported Format"
        case .permission:
            "Permission Required"
        case .memory:
            "Memory Warning"
        case .general:
            "Something Went Wrong"
        }
    }

    var errorDescription: String {
        // First try to get a user-friendly message based on error type
        if let friendlyMessage = getUserFriendlyMessage() {
            return friendlyMessage
        }

        // Fallback to localized description
        return error.localizedDescription
    }

    private var additionalHelpText: String? {
        switch categorizeError() {
        case .network:
            "Check your internet connection and try again"
        case .fileAccess:
            "Make sure the file exists and you have permission to access it"
        case .audio:
            "Try selecting a different audio engine in Settings"
        case .storage:
            "Free up some space on your device"
        case .format:
            "This file format may not be supported. Try converting it to a compatible format"
        case .permission:
            "Grant the necessary permissions in Settings > Privacy & Security"
        case .memory:
            "Close some apps to free up memory"
        case .general:
            nil
        }
    }

    // MARK: - Error Categorization Logic

    private enum ErrorCategory {
        case network
        case fileAccess
        case audio
        case storage
        case format
        case permission
        case memory
        case general
    }

    private func categorizeError() -> ErrorCategory {
        let errorString = String(describing: error).lowercased()
        let localizedString = error.localizedDescription.lowercased()

        // Check for specific error types
        if containsKeyword(["network", "connection", "internet"], in: [errorString, localizedString]) {
            return .network
        }

        if containsKeyword(["file", "url", "cannot open"], in: [errorString, localizedString]) {
            return .fileAccess
        }

        if containsKeyword(["audio", "playback", "engine"], in: [errorString, localizedString]) {
            return .audio
        }

        if containsKeyword(["storage", "disk", "space"], in: [errorString, localizedString]) {
            return .storage
        }

        if containsKeyword(["format", "codec", "unsupported"], in: [errorString, localizedString]) {
            return .format
        }

        if containsKeyword(["permission", "denied", "not allowed"], in: [errorString, localizedString]) {
            return .permission
        }

        if containsKeyword(["memory", "ram"], in: [errorString, localizedString]) {
            return .memory
        }

        return .general
    }

    private func containsKeyword(_ keywords: [String], in targets: [String]) -> Bool {
        keywords.contains { keyword in
            targets.contains { $0.contains(keyword) }
        }
    }

    private func getUserFriendlyMessage() -> String? {
        let errorString = String(describing: error)

        // Map common technical errors to user-friendly messages
        if errorString.contains("AVAudioEngineConfigurationChange") {
            return "The audio configuration changed. Please try playing the track again."
        }

        if errorString.contains("NSFileReadNoSuchFileError") {
            return "The audio file could not be found. It may have been moved or deleted."
        }

        if errorString.contains("NSFileReadNoPermissionError") {
            return "You don't have permission to access this file."
        }

        if errorString.contains("NSFileReadCorruptFileError") {
            return "The audio file appears to be damaged and cannot be played."
        }

        if errorString.contains("NSURLErrorNotConnectedToInternet") {
            return "No internet connection available."
        }

        if errorString.contains("NSURLErrorTimedOut") {
            return "The request took too long. Please try again."
        }

        if errorString.contains("kAudioUnitErr_InvalidProperty") {
            return "The audio system encountered an issue. Try restarting the app."
        }

        if errorString.contains("kAudioUnitErr_FormatNotSupported") {
            return "This audio format is not supported on your device."
        }

        if errorString.contains("NSCocoaErrorDomain"), errorString.contains("512") {
            return "The file couldn't be saved. Check your storage space."
        }

        if errorString.contains("bufferUnderrun") {
            return "Audio playback was interrupted. This might be due to system load."
        }

        if errorString.contains("engineInitializationFailed") {
            return "The audio player couldn't start. Try restarting the app."
        }

        if errorString.contains("formatNotSupported") {
            return "This audio format isn't supported. Try converting the file to MP3 or AAC."
        }

        return nil
    }
}

// MARK: - Alert Modifier

extension View {
    func errorAlert(error: Binding<Error?>, retryAction: (() -> Void)? = nil) -> some View {
        alert(
            "Error",
            isPresented: .constant(error.wrappedValue != nil),
            presenting: error.wrappedValue,
        ) { _ in
            if let retryAction {
                Button("Try Again", action: retryAction)
                Button("OK", role: .cancel) {
                    error.wrappedValue = nil
                }
            } else {
                Button("OK", role: .cancel) {
                    error.wrappedValue = nil
                }
            }
        } message: { presentedError in
            Text(ErrorView(error: presentedError).errorDescription)
        }
    }
}

// MARK: - Preview

#Preview("Network Error") {
    ErrorView(
        error: NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."],
        ),
        retryAction: {
            Log.logger(.userInterface).info("Retry tapped - network error preview")
        },
    )
}

#Preview("File Error") {
    ErrorView(
        error: NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileReadNoSuchFileError,
            userInfo: [NSLocalizedDescriptionKey: "The file could not be found."],
        ),
        retryAction: {
            Log.logger(.userInterface).info("Retry tapped - file error preview")
        },
    )
}

#Preview("Audio Error") {
    ErrorView(
        error: NSError(
            domain: "com.fonichifi.audio",
            code: 1001,
            userInfo: [NSLocalizedDescriptionKey: "Audio engine initialization failed"],
        ),
        retryAction: {
            Log.logger(.userInterface).info("Retry tapped - audio error preview")
        },
    )
}
