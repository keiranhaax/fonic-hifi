//
//  AudioEnvironment.swift
//  Fonic HiFi
//
//  Created by Claude on 8/13/25.
//  Environment values for audio and data service dependency injection
//

import SwiftUI

// MARK: - Audio Engine Environment

/// Environment key for AudioEngineFacade dependency injection
struct AudioEngineKey: EnvironmentKey {
    static let defaultValue: AudioEngineFacade? = nil
}

extension EnvironmentValues {
    /// Access to the audio engine facade through environment
    var audioEngine: AudioEngineFacade? {
        get { self[AudioEngineKey.self] }
        set { self[AudioEngineKey.self] = newValue }
    }
}

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

// MARK: - Import Service Environment

/// Environment key for LibraryImportService dependency injection
struct ImportServiceKey: EnvironmentKey {
    static let defaultValue: LibraryImportService? = nil
}

extension EnvironmentValues {
    /// Access to the library import service through environment
    var importService: LibraryImportService? {
        get { self[ImportServiceKey.self] }
        set { self[ImportServiceKey.self] = newValue }
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Injects the audio engine into the environment
    func audioEngine(_ audioEngine: AudioEngineFacade) -> some View {
        environment(\.audioEngine, audioEngine)
    }

    /// Injects the data manager into the environment
    func dataManager(_ dataManager: DataManager) -> some View {
        environment(\.dataManager, dataManager)
    }

    /// Injects the import service into the environment
    func importService(_ importService: LibraryImportService) -> some View {
        environment(\.importService, importService)
    }

    /// Injects an optional import service into the environment
    func importService(_ importService: LibraryImportService?) -> some View {
        environment(\.importService, importService)
    }
}
