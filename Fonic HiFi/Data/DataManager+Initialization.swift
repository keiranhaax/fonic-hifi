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
        let startTime = CFAbsoluteTimeGetCurrent()
        Self.initLogger.info("Starting DataManager initialization")

        // Pre-create App Group directories to avoid CoreData's synchronous recovery
        let dirStart = CFAbsoluteTimeGetCurrent()
        Self.ensureAppGroupDirectoriesExist()
        let dirDuration = String(format: "%.3f", CFAbsoluteTimeGetCurrent() - dirStart)
        Self.initLogger.info("Directory setup: \(dirDuration, privacy: .public)s")

        let schema = Schema(versionedSchema: SchemaV3.self)
        let modelConfiguration = ModelConfiguration(
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier(WidgetConstants.appGroupIdentifier),
            cloudKitDatabase: .none
        )

        do {
            let containerStart = CFAbsoluteTimeGetCurrent()
            let container = try Self.buildContainer(
                schema: schema,
                configuration: modelConfiguration,
                logger: Self.initLogger
            )
            let containerDuration = String(format: "%.3f", CFAbsoluteTimeGetCurrent() - containerStart)
            Self.initLogger.info("Container creation: \(containerDuration, privacy: .public)s")

            self.init(container: container, isFallback: false, mutationPolicy: .normal)

            let totalDuration = String(format: "%.3f", CFAbsoluteTimeGetCurrent() - startTime)
            Self.initLogger.info("DataManager initialized successfully in \(totalDuration, privacy: .public)s")
        } catch {
            Self.initLogger.error("Failed to initialize DataManager: \(error, privacy: .private)")
            Self.initLogger.error("Error details: \(String(reflecting: error), privacy: .private)")

            // Try emergency fallback
            Self.initLogger.info("Attempting emergency fallback DataManager")
            if let fallback = try? Self.ensureFallbackDataManager() {
                Self.initLogger.info("Successfully created emergency fallback DataManager")
                // Copy the fallback's container
                self.init(
                    container: fallback.container,
                    isFallback: true,
                    importRecoveryState: fallback.importRecoveryState,
                    mutationPolicy: fallback.mutationPolicy
                )
                return
            }

            throw DataManagerError.initializationFailed(error)
        }
    }
}

@MainActor
extension DataManager {
    /// Pre-creates App Group directories before SwiftData attempts to use them.
    ///
    /// When `ModelContainer` is created with an App Group, CoreData expects the
    /// `Library/Application Support` directory to exist. If missing, CoreData's
    /// recovery mechanism runs synchronously, adding 2-3 seconds to launch time.
    ///
    /// This method creates the required directories upfront to avoid that delay.
    private static func ensureAppGroupDirectoriesExist() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WidgetConstants.appGroupIdentifier
        ) else {
            initLogger.warning("App Group container not available, using default location")
            return
        }

        let applicationSupportURL = containerURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)

        let cachesURL = containerURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)

        let fileManager = FileManager.default

        for url in [applicationSupportURL, cachesURL] {
            if !fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
                    initLogger.info("Created directory: \(LogPrivacy.filename(url.lastPathComponent), privacy: .private(mask: .hash))")
                } catch {
                    // Log but don't throw - let SwiftData attempt its own recovery
                    initLogger.error("Failed to create directory: \(error.localizedDescription, privacy: .private)")
                }
            }
        }
    }

    static func buildContainer(
        schema: Schema,
        configuration: ModelConfiguration,
        logger: Logger
    ) throws -> ModelContainer {
        // The user store must always be opened through the complete production
        // migration plan. Retrying the same store without a plan can mutate its
        // metadata before a versioned migration is selected.
        do {
            logger.info("Creating container with production migration plan")
            let container = try ModelContainer(
                for: schema,
                migrationPlan: FonicHiFiMigrationPlan.self,
                configurations: [configuration]
            )
            logger.info("Successfully created ModelContainer with migration plan")
            return container
        } catch {
            logger.critical("Failed to create ModelContainer with migration plan: \(error, privacy: .private)")
            logger.error("Error details: \(String(reflecting: error), privacy: .private)")
            throw error
        }
    }
}

// MARK: - Preview & Fallback Support

@MainActor
public extension DataManager {
    static func previewContainer() -> ModelContainer? {
        previewContainerWithPolicy()?.container
    }

    static func makePreviewDataManager() -> DataManager? {
        initLogger.info("Creating preview DataManager")
        guard let preview = previewContainerWithPolicy() else {
            initLogger.error("Unable to create an in-memory preview DataManager")
            return nil
        }

        return DataManager(
            container: preview.container,
            isFallback: false,
            mutationPolicy: preview.policy
        )
    }

    private static func previewContainerWithPolicy() -> (container: ModelContainer, policy: DataMutationPolicy)? {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let modelConfiguration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        if let container = try? buildContainer(
            schema: schema,
            configuration: modelConfiguration,
            logger: initLogger
        ) {
            return (container, .normal)
        }

        initLogger.fault("Falling back to read-only preview container")
        let readOnlyConfiguration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: false,
            cloudKitDatabase: .none
        )

        if let container = try? ModelContainer(
            for: schema,
            configurations: [readOnlyConfiguration]
        ) {
            return (container, .readOnly)
        }

        initLogger.critical("Unable to create preview container")
        return nil
    }

    static func makePreviewImportService() -> LibraryImportService? {
        guard let container = previewContainer() else {
            return nil
        }

        let trackDataActor = TrackDataActor(modelContainer: container, mutationPolicy: .normal)
        let metadataExtractor = MetadataExtractionService(
            formatDetectionService: AudioFormatDetectionManager()
        )
        return LibraryImportService(
            trackDataActor: trackDataActor,
            metadataExtractor: metadataExtractor,
            mutationPolicy: .normal
        )
    }

    static func makeFallbackDataManager() -> DataManager? {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            let container = try buildContainer(
                schema: schema,
                configuration: configuration,
                logger: initLogger
            )
            return makeFallbackManager(container: container, mode: .ephemeralStorage)
        } catch {
            initLogger.critical("Failed to create fallback DataManager: \(error.localizedDescription, privacy: .private)")
            return nil
        }
    }

    static func ensureFallbackDataManager() throws -> DataManager {
        if let fallback = makeFallbackDataManager() {
            return fallback
        }

        let schema = Schema(versionedSchema: SchemaV3.self)
        let inMemoryConfiguration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: false,
            cloudKitDatabase: .none
        )

        if let container = try? buildContainer(
            schema: schema,
            configuration: inMemoryConfiguration,
            logger: initLogger
        ) {
            return makeFallbackManager(container: container, mode: .readOnly)
        }

        if let container = try? ModelContainer(
            for: schema,
            configurations: [inMemoryConfiguration]
        ) {
            return makeFallbackManager(container: container, mode: .readOnly)
        }

        let error = DataManagerError.emergencyFallbackFailed(
            NSError(
                domain: "DataManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to create an in-memory recovery container."]
            )
        )
        initLogger.critical("Emergency fallback container creation failed")
        throw error
    }
}

private extension DataManager {
    static func makeFallbackManager(
        container: ModelContainer,
        mode: ImportRecoveryMode
    ) -> DataManager {
        DataManager(
            container: container,
            isFallback: true,
            importRecoveryState: recoveryState(for: mode),
            mutationPolicy: .readOnly
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
                    "is restored to resume full functionality."
            )
        case .readOnly:
            ImportRecoveryState(
                mode: .readOnly,
                headline: "Read-Only Recovery Mode",
                message: "Fonic HiFi switched to a read-only library because persistent storage " +
                    "could not be initialized.",
                guidance: "You can browse your existing library but changes cannot be saved. Restart " +
                    "the app after freeing storage or resolving migration issues."
            )
        }
    }
}
