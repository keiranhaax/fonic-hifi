//
//  AirPlayRouteButton.swift
//  Fonic HiFi
//
//  Created by Codex on 10/5/25.
//

import AVKit
import SwiftUI

@MainActor
struct AirPlayRouteButton: UIViewRepresentable {
    func makeUIView(context _: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView(frame: .zero)
        picker.prioritizesVideoDevices = false
        picker.tintColor = UIColor.white
        picker.activeTintColor = UIColor.white
        picker.backgroundColor = .clear
        picker.accessibilityLabel = NSLocalizedString("Select AirPlay device", comment: "AirPlay route picker")
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context _: Context) {
        uiView.tintColor = UIColor.white
        uiView.activeTintColor = UIColor.white
    }
}
