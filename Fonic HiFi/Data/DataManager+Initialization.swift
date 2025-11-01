//
//  DataManager+Initialization.swift
//  Fonic HiFi
//
//  Created by Droid on 10/07/25.
//

import Foundation
import OSLog
import SwiftData

@MainActor
public extension DataManager {
    enum ImportRecoveryMode: Sendable {
        case ephemeralStorage
        case readOnly
    }

    struct ImportRecoveryState: Equatable, Sendable {
        public let mode: ImportRecoveryMode
        public let headline: String
        public let message: String
        public let guidance: String

        public init(mode: ImportRecoveryMode, headline: String, message: String, guidance: String) {
            self.mode = mode
            self.headline = headline
            self.message = message
            self.guidance = guidance
        }
    }

    convenience init() throws {
        let schema = Schema(SchemaV2.models)
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none,
        )

        do {
            let container = try Self.buildContainer(
                schema: schema,
                configuration: modelConfiguration,
                logger: Self.initLogger,
            )
            self.init(container: container, isFallback: false)
            logger.info("DataManager initialized successfully")
        } catch {
            Self.initLogger.error("Failed to initialize DataManager: \(error.localizedDescription)")
            throw DataManagerError.initializationFailed(error)
        }
    }
}

@MainActor
extension DataManager {
    static func buildContainer(
        schema: Schema,
        configuration: ModelConfiguration,
        logger: Logger,
    ) throws -> ModelContainer {
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: RecentSearchMigrationPlan.self,
                configurations: [configuration],
            )
        } catch {
            logger.error("Failed to create ModelContainer with migration plan: \(error.localizedDescription)")
            do {
                return try ModelContainer(
                    for: schema,
                    configurations: [configuration],
                )
            } catch {
                logger.critical("Failed to create fallback ModelContainer: \(error.localizedDescription)")
                throw error
            }
        }
    }
}

// MARK: - Preview & Fallback Support

@MainActor
public extension DataManager {
    static func previewContainer() -> ModelContainer? {
        let schema = Schema(SchemaV2.models)
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none,
        )

        if let container = try? buildContainer(
            schema: schema,
            configuration: modelConfiguration,
            logger: initLogger,
        ) {
            return container
        }

        initLogger.fault("Falling back to read-only preview container")
        let readOnlyConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: false,
            cloudKitDatabase: .none,
        )

        if let container = try? ModelContainer(
            for: schema,
            configurations: [readOnlyConfiguration],
        ) {
            return container
        }

        initLogger.critical("Unable to create preview container")
        return nil
    }

    static func makePreviewDataManager() -> DataManager? {
        if let fallback = makeFallbackDataManager() {
            return fallback
        }

        do {
            return try DataManager()
        } catch {
            initLogger.error("Error creating preview DataManager: \(error.localizedDescription)")
            return nil
        }
    }

    static func makePreviewImportService() -> LibraryImportService? {
        guard let container = previewContainer() else {
            return nil
        }

        let trackDataActor = TrackDataActor(modelContainer: container)
        let metadataExtractor = MetadataExtractionService(
            formatDetectionService: AudioFormatDetectionManager(),
        )
        return LibraryImportService(
            trackDataActor: trackDataActor,
            metadataExtractor: metadataExtractor,
        )
    }

    static func makeFallbackDataManager() -> DataManager? {
        let schema = Schema(SchemaV2.models)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none,
        )

        do {
            let container = try buildContainer(
                schema: schema,
                configuration: configuration,
                logger: initLogger,
            )
            return makeFallbackManager(container: container, mode: .ephemeralStorage)
        } catch {
            initLogger.critical("Failed to create fallback DataManager: \(error.localizedDescription)")
            return nil
        }
    }

    static func ensureFallbackDataManager() throws -> DataManager {
        if let fallback = makeFallbackDataManager() {
            return fallback
        }

        if let preview = makePreviewDataManager() {
            return preview
        }

        let schema = Schema(SchemaV2.models)
        let inMemoryConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: false,
            cloudKitDatabase: .none,
        )

        if let container = try? buildContainer(
            schema: schema,
            configuration: inMemoryConfiguration,
            logger: initLogger,
        ) {
            return makeFallbackManager(container: container, mode: .readOnly)
        }

        if let container = try? ModelContainer(
            for: schema,
            configurations: [inMemoryConfiguration],
        ) {
            return makeFallbackManager(container: container, mode: .readOnly)
        }

        do {
            let container = try ModelContainer(for: schema)
            return makeFallbackManager(container: container, mode: .readOnly)
        } catch {
            initLogger.critical("Emergency fallback container creation failed: \(error.localizedDescription)")
            throw DataManagerError.emergencyFallbackFailed(error)
        }
    }
}

private extension DataManager {
    static func makeFallbackManager(
        container: ModelContainer,
        mode: ImportRecoveryMode,
    ) -> DataManager {
        DataManager(
            container: container,
            isFallback: true,
            importRecoveryState: recoveryState(for: mode),
        )
    }

    static func recoveryState(for mode: ImportRecoveryMode) -> ImportRecoveryState {
        switch mode {
        case .ephemeralStorage:
            ImportRecoveryState(
                mode: .ephemeralStorage,
                headline: "Temporary Library Active",
                message: "Fonic HiFi is using an in-memory library because the persistent store " +
                    "is unavailable.",
                guidance: "Keep the app open to preserve playback queues. Restart once storage access " +
                    "is restored to resume full functionality.",
            )
        case .readOnly:
            ImportRecoveryState(
                mode: .readOnly,
                headline: "Read-Only Recovery Mode",
                message: "Fonic HiFi switched to a read-only library because persistent storage " +
                    "could not be initialized.",
                guidance: "You can browse your existing library but changes cannot be saved. Restart " +
                    "the app after freeing storage or resolving migration issues.",
            )
        }
    }
}
