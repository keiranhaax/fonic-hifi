//
//  FonicHiFiApp_Debug.swift
//  Fonic HiFi
//
//  Debug version to test different approaches
//

import OSLog
import SwiftData
import SwiftUI

/// Debug version of the app to isolate the crash
// @main  // UNCOMMENT THIS AND COMMENT OUT @main IN FonicHiFiApp.swift TO USE
struct FonicHiFiApp_Debug: App {
    @StateObject private var dependencies: DebugAppDependencies

    private let logger: Logger

    init() {
        let loggerInstance = Log.logger(.app)
        logger = loggerInstance
        _dependencies = StateObject(wrappedValue: DebugAppDependencies(logger: loggerInstance))
    }

    @State private var useDebugMode = true
    @State private var useSafeContentView = false

    var body: some Scene {
        WindowGroup {
            Group {
                switch dependencies.status {
                case let .ready(context):
                    readyContent(using: context)
                case let .failure(message):
                    EmergencyRecoveryView(message: message)
                }
            }
            .onAppear {
                guard case let .ready(context) = dependencies.status else { return }

                logger.info("App launched with debug mode: \(useDebugMode, privacy: .public)")
                logger.debug("Main thread status: \(Thread.isMainThread, privacy: .public)")

                Task { @MainActor in
                    do {
                        try await context.audioEngine.initialize()
                        logger.info("Audio engine initialized successfully")
                    } catch {
                        logger.error("Failed to initialize audio engine: \(error.localizedDescription, privacy: .public)")
                    }
                }
            }
        }
    }
}

// Comment out the original @main in FonicHiFiApp.swift when using this

private extension FonicHiFiApp_Debug {
    @MainActor
    static func makeEmergencyDataManager(logger: Logger) -> DataManager? {
        if let fallback = DataManager.makeFallbackDataManager()
            ?? DataManager.makePreviewDataManager()
            ?? (try? DataManager.ensureFallbackDataManager()) {
            return fallback
        }

        let schema = Schema(SchemaV2.models)
        let inMemoryReadOnly = ModelConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: false,
            cloudKitDatabase: .none
        )

        if let container = try? DataManager.buildContainer(
            schema: schema,
            configuration: inMemoryReadOnly,
            logger: DataManager.initLogger,
        ) {
            return DataManager(
                container: container,
                isFallback: true,
                importRecoveryState: DataManager.ImportRecoveryState(
                    mode: .readOnly,
                    headline: "Emergency Library Mode",
                    message: "Running with temporary read-only library after initialization failure.",
                    guidance: "Restart Fonic HiFi once storage access is restored.",
                ),
            )
        }

        if let container = try? ModelContainer(
            for: schema,
            configurations: [inMemoryReadOnly],
        ) {
            return DataManager(
                container: container,
                isFallback: true,
                importRecoveryState: DataManager.ImportRecoveryState(
                    mode: .readOnly,
                    headline: "Emergency Library Mode",
                    message: "Running with temporary read-only library after initialization failure.",
                    guidance: "Restart Fonic HiFi once storage access is restored.",
                ),
            )
        }

        let emergencyDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "FonicEmergency-\(UUID().uuidString)",
            isDirectory: true,
        )
        try? FileManager.default.createDirectory(at: emergencyDirectory, withIntermediateDirectories: true)
        let diskConfiguration = ModelConfiguration(
            url: emergencyDirectory,
            allowsSave: false,
            cloudKitDatabase: .none
        )

        if let container = try? ModelContainer(
            for: schema,
            configurations: [diskConfiguration],
        ) {
            return DataManager(
                container: container,
                isFallback: true,
                importRecoveryState: DataManager.ImportRecoveryState(
                    mode: .readOnly,
                    headline: "Emergency Library Mode",
                    message: "Running with temporary read-only library after initialization failure.",
                    guidance: "Restart Fonic HiFi once storage access is restored.",
                ),
            )
        }

        logger.critical("Emergency container creation failed after all strategies")
        return nil
    }

    @ViewBuilder
    private func readyContent(using context: DebugAppDependencies.ReadyContext) -> some View {
        if useDebugMode {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Fonic HiFi Debug Mode")
                        .font(.title)

                    Toggle("Use Safe ContentView (Sheet)", isOn: $useSafeContentView)
                        .padding()

                    Button("Launch App") {
                        useDebugMode = false
                    }
                    .buttonStyle(.borderedProminent)

                    Divider()

                    VStack(alignment: .leading) {
                        Text("Debug Options:")
                            .font(.headline)
                        Text("• Safe ContentView uses sheet presentation")
                        Text("• Regular ContentView uses overlay")
                        Text("• Check console for debug logs")
                    }
                    .padding()

                    Spacer()
                }
                .padding()
                .navigationTitle("Debug Mode")
            }
        } else if useSafeContentView {
            ContentView_Safe()
                .modelContainer(context.dataManager.container)
                .environmentObject(context.dataManager.importService)
                .environmentObject(context.audioEngine)
        } else {
            ContentView()
                .modelContainer(context.dataManager.container)
                .environmentObject(context.dataManager.importService)
                .environmentObject(context.audioEngine)
        }
    }
}

@MainActor
private final class DebugAppDependencies: ObservableObject {
    struct ReadyContext {
        let dataManager: DataManager
        let playbackStateManager: PlaybackStateManager
        let audioEngine: AudioEngineFacade
    }

    enum Status {
        case ready(ReadyContext)
        case failure(String)
    }

    @Published private(set) var status: Status

    init(logger: Logger) {
        if let manager = DebugAppDependencies.bootstrapDataManager(logger: logger) {
            let playbackStateManager = PlaybackStateManager()
            let audioEngine = AudioEngineFacade(stateManager: playbackStateManager)
            status = .ready(ReadyContext(
                dataManager: manager,
                playbackStateManager: playbackStateManager,
                audioEngine: audioEngine,
            ))
        } else {
            status = .failure("Unable to construct any DataManager fallback. Restart Fonic HiFi once storage access is restored.")
        }
    }

    private static func bootstrapDataManager(logger: Logger) -> DataManager? {
        do {
            return try DataManager()
        } catch {
            logger.error("Failed to initialize DataManager for debug build: \(error.localizedDescription, privacy: .public)")
            logger.warning("Falling back to in-memory DataManager for debug")

            if let fallback = DataManager.makeFallbackDataManager()
                ?? DataManager.makePreviewDataManager()
                ?? (try? DataManager()) {
                return fallback
            }

            do {
                return try DataManager.ensureFallbackDataManager()
            } catch {
                logger.critical("Unable to build fallback DataManager: \(error.localizedDescription, privacy: .public)")
                return FonicHiFiApp_Debug.makeEmergencyDataManager(logger: logger)
            }
        }
    }
}

private struct EmergencyRecoveryView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Text("Library Unavailable")
                .font(.title2)
            Text(message)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Text("Restart the app after resolving storage or migration issues.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
