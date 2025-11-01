//
//  AudioUIState.swift
//  Fonic HiFi
//
//  Centralised store for facade UI state, extracted for Phase 2C modularisation.
//

import Foundation

/// Stores UI-facing audio state consumed by SwiftUI.
@MainActor
public final class AudioUIState: ObservableObject {
    @Published public var currentTrack: Track?
    @Published public var showMiniPlayer: Bool
    @Published public var diagnosticsStatus: DiagnosticsStatus

    public init(
        currentTrack: Track? = nil,
        showMiniPlayer: Bool = false,
        diagnosticsStatus: DiagnosticsStatus = .empty,
    ) {
        self.currentTrack = currentTrack
        self.showMiniPlayer = showMiniPlayer
        self.diagnosticsStatus = diagnosticsStatus
    }

    public func reset() {
        currentTrack = nil
        showMiniPlayer = false
        diagnosticsStatus = .empty
    }
}
