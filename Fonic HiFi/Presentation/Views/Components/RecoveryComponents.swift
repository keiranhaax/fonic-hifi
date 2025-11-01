import SwiftUI

struct RecoveryModeBanner: View {
    let state: DataManager.ImportRecoveryState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(state.headline)
                .font(.caption.bold())
            Text(state.message)
                .font(.footnote)
            Text(state.guidance)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassSurface(style: .standard, cornerRadius: 24)
        .padding()
    }
}

struct RecoveryUnavailableView: View {
    let launchError: LaunchError?
    let fallbackError: DataManagerError?

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .symbolRenderingMode(.multicolor)

            Text("Fonic HiFi Could Not Start")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                if let message = launchError?.message {
                    Text(message)
                }

                if let fallbackError {
                    Text(fallbackError.localizedDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text(
                    "Please restart the app after verifying that storage is available " +
                        "and data permissions are granted.",
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }
}
