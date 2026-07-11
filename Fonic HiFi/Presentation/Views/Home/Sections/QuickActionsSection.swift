//
//  QuickActionsSection.swift
//  Fonic HiFi
//
//  Quick action buttons for Shuffle All and Surprise Me
//

import SwiftUI

@MainActor
struct QuickActionsSection: View {
    let isGeneratingRecommendations: Bool
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
                Group {
                    if isGeneratingRecommendations {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Choosing…")
                        }
                    } else {
                        Label("Surprise Me", systemImage: "dice")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonSizing(.flexible)
            .buttonStyle(.glass)
            .disabled(isGeneratingRecommendations)
            .accessibilityLabel("Surprise Me")
            .accessibilityValue(isGeneratingRecommendations ? "Choosing music" : "Ready")
        }
        .padding(.horizontal)
    }
}

#Preview {
    QuickActionsSection(
        isGeneratingRecommendations: false,
        onShuffleAll: {},
        onSurpriseMe: {}
    )
    .padding()
}
