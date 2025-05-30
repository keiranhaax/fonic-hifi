//
//  NowPlayingContainer.swift
//  Fonic HiFi
//
//  Created by Claude on 5/29/25.
//

import SwiftUI

/// Container view that manages the transition between mini player and full Now Playing view
@MainActor
struct NowPlayingContainer: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var animationNamespace
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Mini player
            if appState.showMiniPlayer && !appState.showingNowPlaying {
                MiniPlayerView(animationNamespace: animationNamespace)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                    .zIndex(1)
            }
            
            // Full Now Playing view
            if appState.showingNowPlaying {
                NowPlayingView(animationNamespace: animationNamespace)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .move(edge: .bottom)
                        )
                    )
                    .zIndex(2)
            }
        }
        .animation(
            reduceMotion ? .none : .interactiveSpring(response: 0.6, dampingFraction: 0.8),
            value: appState.showingNowPlaying
        )
    }
}