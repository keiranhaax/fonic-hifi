import Foundation
import OSLog

/// Canonical list of logging categories used throughout the application.
///
/// Categories follow the pattern `<domain>.<area>[.<subarea>]` to keep
/// OSLog streams easy to filter. When adding new categories prefer extending
/// the existing domains rather than introducing completely new roots.
enum LogCategory: String, CaseIterable {
    // App lifecycle & debug
    case app = "app.core"
    case appLifecycle = "app.lifecycle"
    case appDebug = "app.debug"

    // Audio domain
    case audio = "audio.core"
    case audioEngine = "audio.engine"
    case audioEngineFacade = "audio.engine.facade"
    case audioEngineManager = "audio.engine.manager"
    case audioEngineFactory = "audio.engine.factory"
    case audioEngineSwitch = "audio.engine.switch"
    case audioSession = "audio.session"
    case audioQueue = "audio.queue"
    case audioQueueCoordinator = "audio.queue.coordinator"
    case audioQueueManager = "audio.queue.manager"
    case audioQueueState = "audio.queue.state"
    case audioStateCoordinator = "audio.stateCoordinator"
    case audioDetection = "audio.detection"
    case audioMetrics = "audio.metrics"

    // Playback orchestration
    case playback = "playback.core"
    case playbackController = "playback.controller"
    case playbackStateManager = "playback.stateManager"

    // Data and import pipelines
    case data = "data.core"
    case dataManager = "data.manager"
    case dataManagerInit = "data.manager.init"
    case dataTrackActor = "data.track.actor"
    case dataImportSession = "data.import.session"
    case dataFileImportProcessor = "data.import.fileProcessor"
    case dataMetadataExtraction = "data.metadata"
    case dataSearchCache = "data.search.cache"
    case importService = "library.import.service"
    case importPipeline = "library.import.pipeline"

    // Cache & library state
    case cacheTrack = "cache.track"
    case cacheSearch = "cache.search"
    case library = "library.core"

    // UI & presentation
    case presentation = "ui.presentation"
    case userInterface = "ui.general"
    case accessibility = "ui.accessibility"
    case nowPlaying = "ui.nowPlaying"
    case search = "ui.search"

    // Diagnostics & performance tooling
    case diagnostics = "diagnostics.core"
    case diagnosticsMonitor = "diagnostics.monitor"
    case diagnosticsBitPerfectValidator = "diagnostics.bitPerfect.validator"
    case diagnosticsBitPerfectDevice = "diagnostics.bitPerfect.deviceManager"
    case diagnosticsPerformance = "diagnostics.performance"
    case performance = "performance.core"
    case liquidGlass = "visual.liquidGlass"

    // Metrics (optional structured counters)
    case metrics = "metrics.core"
    case metricsImport = "metrics.import"
    case metricsEngine = "metrics.engine"
    case metricsQueue = "metrics.queue"
}

enum Log {
    private static let subsystem = "com.fonichifi"

    /// Convenience factory that returns a preconfigured `Logger` for the
    /// requested category. All logging should flow through here to keep the
    /// subsystem and category taxonomy consistent.
    static func logger(_ category: LogCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }
}
