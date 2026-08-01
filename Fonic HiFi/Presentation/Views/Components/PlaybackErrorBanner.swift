import SwiftUI

struct PlaybackErrorBanner: View {
    let error: PlaybackErrorPresentation
    let accessibilityIdentifier: String
    let dismiss: () -> Void

    static func presentationAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }

    static func presentationTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)

            Text(error.message)
                .font(.footnote)
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss playback error")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassSurface(style: .standard, cornerRadius: 22)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct PlaybackErrorOverlayModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let error: PlaybackErrorPresentation?
    let accessibilityIdentifier: String
    let dismiss: (UUID) -> Void

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let error {
                    PlaybackErrorBanner(
                        error: error,
                        accessibilityIdentifier: accessibilityIdentifier,
                        dismiss: { dismiss(error.id) }
                    )
                    .transition(PlaybackErrorBanner.presentationTransition(reduceMotion: reduceMotion))
                }
            }
            .animation(
                PlaybackErrorBanner.presentationAnimation(reduceMotion: reduceMotion),
                value: error?.id
            )
    }
}

extension View {
    func playbackErrorOverlay(
        _ error: PlaybackErrorPresentation?,
        accessibilityIdentifier: String,
        dismiss: @escaping (UUID) -> Void
    ) -> some View {
        modifier(
            PlaybackErrorOverlayModifier(
                error: error,
                accessibilityIdentifier: accessibilityIdentifier,
                dismiss: dismiss
            )
        )
    }
}
