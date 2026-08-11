import SwiftUI

/// Non-color-only status control for the current playback path.
struct SignalPathBadge: View {
    struct Presentation: Equatable {
        let title: String
        let systemImage: String
        let accessibilityValue: String
    }

    let eligibility: SignalPathEligibility
    let action: () -> Void

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    static func presentation(for eligibility: SignalPathEligibility) -> Presentation {
        switch eligibility {
        case .eligible:
            Presentation(
                title: "Eligible",
                systemImage: "checkmark.seal.fill",
                accessibilityValue: "Eligible based on measured engine evidence. Physical output is not measured."
            )
        case .ineligible:
            Presentation(
                title: "Needs Changes",
                systemImage: "exclamationmark.triangle.fill",
                accessibilityValue: "Not eligible. Open the signal path for details."
            )
        case .unavailable:
            Presentation(
                title: "Unverified",
                systemImage: "questionmark.circle.fill",
                accessibilityValue: "Signal path has not been verified for the loaded track."
            )
        }
    }

    var body: some View {
        let presentation = Self.presentation(for: eligibility)

        Button(action: action) {
            Label(presentation.title, systemImage: presentation.systemImage)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, DesignTokens.Spacing.medium)
                .frame(minHeight: 44)
                .foregroundStyle(tint)
                .background(tint.opacity(0.16), in: Capsule())
                .overlay {
                    if differentiateWithoutColor {
                        Capsule()
                            .strokeBorder(tint, lineWidth: 2)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Playback signal path")
        .accessibilityValue(presentation.accessibilityValue)
        .accessibilityHint("Opens technical playback details")
        .accessibilityIdentifier("SignalPathBadge")
    }

    private var tint: Color {
        switch eligibility {
        case .eligible:
            .green
        case .ineligible:
            .orange
        case .unavailable:
            .secondary
        }
    }
}

#Preview {
    VStack(spacing: DesignTokens.Spacing.medium) {
        SignalPathBadge(eligibility: .eligible, action: {})
        SignalPathBadge(eligibility: .ineligible, action: {})
        SignalPathBadge(eligibility: .unavailable, action: {})
    }
    .padding()
}
