//
//  NowPlayingEnvironment.swift
//  Fonic HiFi
//
//  Environment values for Now Playing presentation state
//

import SwiftUI

/// Environment key for the showingNowPlaying binding
struct ShowingNowPlayingKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var showingNowPlaying: Binding<Bool> {
        get { self[ShowingNowPlayingKey.self] }
        set { self[ShowingNowPlayingKey.self] = newValue }
    }
}
