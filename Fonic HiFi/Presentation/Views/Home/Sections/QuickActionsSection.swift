//
//  QuickActionsSection.swift
//  Fonic HiFi
//
//  Quick action buttons for Shuffle All and Surprise Me
//

import SwiftUI

@MainActor
struct QuickActionsSection: View {
    let onShuffleAll: () -> Void
    let onSurpriseMe: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button {
                onShuffleAll()
            } label: {
                Label("Shuffle All", systemImage: "shuffle")
                    .frame(maxWidth: .infinity)
            }
            .buttonSizing(.flexible)
            .buttonStyle(.glass)

            Button {
                onSurpriseMe()
            } label: {
                Label("Surprise Me", systemImage: "dice")
                    .frame(maxWidth: .infinity)
            }
            .buttonSizing(.flexible)
            .buttonStyle(.glass)
        }
        .padding(.horizontal)
    }
}

#Preview {
    QuickActionsSection(
        onShuffleAll: {},
        onSurpriseMe: {}
    )
    .padding()
}
