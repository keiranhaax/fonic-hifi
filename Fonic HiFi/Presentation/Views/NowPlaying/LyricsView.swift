//
//  LyricsView.swift
//  Fonic HiFi
//
//  Lyrics overlay display with Liquid Glass Clear effect.
//

import SwiftUI

struct LyricsView: View {
    let lyrics: String?
    @Binding var isPresented: Bool
    @AccessibilityFocusState private var closeFocused: Bool

    var body: some View {
        ZStack {
            // Dimming layer for Clear variant
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            VStack {
                // Header
                HStack {
                    Text("Lyrics")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close lyrics")
                    .accessibilityFocused($closeFocused)
                }
                .padding()

                // Lyrics content
                ScrollView {
                    if let lyrics, !lyrics.isEmpty {
                        Text(lyrics)
                            .font(.title3)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .padding()
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "text.quote")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No lyrics available")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassEffect(.clear)
            .padding()
        }
        .transition(.opacity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("LyricsModal")
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) {
            isPresented = false
        }
        .onAppear {
            closeFocused = true
        }
    }
}

#Preview {
    LyricsView(
        lyrics: "Sample lyrics here\nLine two\nLine three\n\nVerse two begins\nWith more text",
        isPresented: .constant(true)
    )
}
