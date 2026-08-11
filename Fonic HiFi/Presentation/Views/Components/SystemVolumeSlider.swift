//
//  SystemVolumeSlider.swift
//  Fonic HiFi
//
//  Public system volume control, synchronized with hardware volume buttons.
//

import MediaPlayer
import SwiftUI

/// Hosts Apple's public system-volume control directly.
/// Hardware buttons and touch interaction stay synchronized on a physical device.
@MainActor
struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context _: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.showsVolumeSlider = true
        volumeView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        volumeView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return volumeView
    }

    func updateUIView(_: MPVolumeView, context _: Context) {}
}

// MARK: - Preview

#Preview {
    SystemVolumeSlider()
        .padding()
        .preferredColorScheme(.dark)
}
