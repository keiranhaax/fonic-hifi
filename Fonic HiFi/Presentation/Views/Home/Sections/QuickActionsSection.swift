//
//  QuickActionsSection.swift
//  Fonic HiFi
//
//  Quick action buttons for Shuffle All and Surprise Me
//

import SwiftUI

@MainActor
struct QuickActionsSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let isGeneratingRecommendations: Bool
    let onShuffleAll: () -> Void
    let onSurpriseMe: () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 16) {
                    shuffleButton
                    surpriseMeButton
                }
            } else {
                HStack(spacing: 16) {
                    shuffleButton
                    surpriseMeButton
                }
            }
        }
        .padding(.horizontal)
    }

    private var shuffleButton: some View {
        Button {
            onShuffleAll()
        } label: {
            Label("Shuffle All", systemImage: "shuffle")
                .frame(maxWidth: .infinity)
        }
        .buttonSizing(.flexible)
        .buttonStyle(.glass)
    }

    private var surpriseMeButton: some View {
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
}

#Preview {
    QuickActionsSection(
        isGeneratingRecommendations: false,
        onShuffleAll: {},
        onSurpriseMe: {}
    )
    .padding()
}
