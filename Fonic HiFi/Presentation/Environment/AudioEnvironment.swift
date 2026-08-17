//
//  AudioEnvironment.swift
//  Fonic HiFi
//
//  Created by Claude on 8/13/25.
//  Environment values for audio and data service dependency injection
//

import SwiftUI

// MARK: - Data Manager Environment

/// Environment key for DataManager dependency injection
struct DataManagerKey: EnvironmentKey {
    static let defaultValue: DataManager? = nil
}

extension EnvironmentValues {
    /// Access to the data manager through environment
    var dataManager: DataManager? {
        get { self[DataManagerKey.self] }
        set { self[DataManagerKey.self] = newValue }
    }
}

// MARK: - Library Repository Environment

/// Environment key for LibraryRepository dependency injection
struct LibraryRepositoryKey: EnvironmentKey {
    static let defaultValue: LibraryRepository? = nil
}

extension EnvironmentValues {
    /// Access to the library repository through environment
    var libraryRepository: LibraryRepository? {
        get { self[LibraryRepositoryKey.self] }
        set { self[LibraryRepositoryKey.self] = newValue }
    }
}

// MARK: - Artwork Service Environment

/// Environment key for ArtworkService dependency injection
struct ArtworkServiceKey: EnvironmentKey {
    static let defaultValue: ArtworkService? = nil
}

extension EnvironmentValues {
    /// Access to the artwork service through environment
    var artworkService: ArtworkService? {
        get { self[ArtworkServiceKey.self] }
        set { self[ArtworkServiceKey.self] = newValue }
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Injects the observable audio engine throughout the view hierarchy.
    func audioEngine(_ audioEngine: AudioEngineFacade) -> some View {
        environmentObject(audioEngine)
    }

    /// Injects the data manager into the environment
    func dataManager(_ dataManager: DataManager) -> some View {
        environment(\.dataManager, dataManager)
    }

    /// Injects an optional data manager into the environment
    func dataManager(_ dataManager: DataManager?) -> some View {
        environment(\.dataManager, dataManager)
    }

    /// Injects the observable import service throughout the view hierarchy.
    func importService(_ importService: LibraryImportService) -> some View {
        environmentObject(importService)
    }

    /// Injects the library repository into the environment
    func libraryRepository(_ repository: LibraryRepository?) -> some View {
        environment(\.libraryRepository, repository)
    }

    /// Injects the artwork service into the environment
    func artworkService(_ service: ArtworkService) -> some View {
        environment(\.artworkService, service)
    }

    /// Injects an optional artwork service into the environment
    func artworkService(_ service: ArtworkService?) -> some View {
        environment(\.artworkService, service)
    }
}
