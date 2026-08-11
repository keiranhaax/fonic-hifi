import AVFAudio
import Combine
import Foundation
import Testing

@testable import Fonic_HiFi

@Suite("AudioEngineFacade Orchestrator Tests")
struct AudioEngineFacadeOrchestratorTests {
    @Test("Initializes with default dependencies")
    @MainActor
    func initializesWithDefaults() async throws {
        let facade = AudioEngineFacade()

        #expect(facade.isReady == false)
        #expect(facade.showMiniPlayer == false)
        #expect(facade.currentTrack == nil)
    }

    @Test("Retains custom dependency instances")
    @MainActor
    func retainsCustomDependencies() async throws {
        let sessionManager = AudioSessionManager()
        let formatManager = AudioFormatDetectionManager()
        let stateManager = PlaybackStateManager()
        let queueManager = AudioQueueManager()
        let validator = BitPerfectValidator()
        let monitor = FacadeMonitorStub()
        let settings = AudioPlaybackSettingsStore(defaults: makeFacadeDefaults("custom"))
        let uiState = AudioUIState()

        let facade = AudioEngineFacade(
            sessionManager: sessionManager,
            formatDetectionManager: formatManager,
            stateManager: stateManager,
            queueManager: queueManager,
            validator: validator,
            monitor: monitor,
            playbackSettingsStore: settings,
            uiStateStore: uiState
        )

        #expect(facade.sessionManager === sessionManager)
        #expect(facade.formatDetectionManager === formatManager)
        #expect(facade.stateManager === stateManager)
        #expect(facade.queueManager === queueManager)
    }

    @Test("Switching engines reattaches monitor to latest engine")
    @MainActor
    func switchingEnginesReattachesMonitor() async throws {
        let monitor = FacadeMonitorStub()
        let facade = AudioEngineFacade(
            stateManager: PlaybackStateManager(),
            queueManager: AudioQueueManager(),
            monitor: monitor
        )

        let first = FacadeEngineStub()
        let second = FacadeEngineStub()

        facade.setCurrentEngine(first, type: .avAudioEngine, format: .wav)
        facade.setCurrentEngine(second, type: .audioKitEngine, format: .flac)

        try await Task.sleep(for: .milliseconds(100))

        #expect(monitor.attachedEngines.count >= 2)
        #expect(monitor.attachedEngines.last as? FacadeEngineStub === second)
    }

    @Test("Stop delegates to current engine and updates state")
    @MainActor
    func stopDelegatesToEngine() async throws {
        let facade = AudioEngineFacade(
            stateManager: PlaybackStateManager(enableTransitionValidation: false),
            queueManager: AudioQueueManager(),
            monitor: FacadeMonitorStub()
        )
        let engine = FacadeEngineStub(isPlayingValue: true)
        facade.setCurrentEngine(engine, type: .avAudioEngine, format: .wav)

        try await Task.sleep(for: .milliseconds(50))
        await facade.stop()

        #expect(engine.stopCallCount >= 1)
        #expect(facade.currentState == .stopped)
    }

    @Test("Explicit stop releases audio focus exactly once")
    @MainActor
    func explicitStopDeactivatesSessionOnce() async throws {
        let sessionManager = AudioSessionManager(notificationCenter: NotificationCenter())
        let facade = AudioEngineFacade(
            sessionManager: sessionManager,
            monitor: FacadeMonitorStub(),
            runtimeMonitoringEnabled: false
        )

        try await facade.initialize()
        try await sessionManager.activateAudioSession()
        await facade.stop()

        #expect(sessionManager.deactivationTransitionCount == 1)
        await facade.shutdown()
        #expect(sessionManager.deactivationTransitionCount == 1)
    }

    @Test("Pause and queue navigation do not release audio focus")
    @MainActor
    func pauseAndNavigationKeepSessionActive() async throws {
        let sessionManager = AudioSessionManager(notificationCenter: NotificationCenter())
        let facade = AudioEngineFacade(
            sessionManager: sessionManager,
            monitor: FacadeMonitorStub(),
            runtimeMonitoringEnabled: false
        )

        try await facade.initialize()
        try await sessionManager.activateAudioSession()
        await facade.pause()
        try? await facade.playNext()

        #expect(sessionManager.deactivationTransitionCount == 0)
        await facade.shutdown()
    }

    @Test("setCurrentTrack propagates without revealing playback UI")
    @MainActor
    func setCurrentTrackPropagatesUiState() async throws {
        let uiState = AudioUIState()
        let facade = AudioEngineFacade(
            stateManager: PlaybackStateManager(),
            queueManager: AudioQueueManager(),
            monitor: FacadeMonitorStub(),
            uiStateStore: uiState
        )
        let track = makeTrack(name: "ui-track")

        facade.setCurrentTrack(track)

        #expect(uiState.currentTrack?.id == track.id)
        #expect(uiState.showMiniPlayer == false)

        facade.setCurrentTrack(nil)
        #expect(uiState.currentTrack == nil)
        #expect(uiState.showMiniPlayer == false)
        #expect(uiState.diagnosticsStatus.track == nil)
        #expect(uiState.diagnosticsStatus.validationResult == nil)
        #expect(uiState.diagnosticsStatus.device == nil)
        #expect(uiState.diagnosticsStatus.dacInfo == nil)
        #expect(uiState.diagnosticsStatus.metrics == nil)
    }

    @Test("Diagnostics refresh publishes the facade-composed signal path")
    @MainActor
    func diagnosticsRefreshPublishesSignalPath() async {
        let monitor = FacadeMonitorStub()
        let uiState = AudioUIState()
        let facade = AudioEngineFacade(
            stateManager: PlaybackStateManager(),
            queueManager: AudioQueueManager(),
            monitor: monitor,
            uiStateStore: uiState
        )
        let evidence = AudioEngineFormatEvidence(
            isTrackLoaded: true,
            loadedSampleRate: 96_000,
            loadedChannelCount: 2,
            engineOutputSampleRate: 96_000,
            engineOutputChannelCount: 2,
            hasEngineProcessing: false
        )
        let engine = FacadeEngineStub(formatEvidence: evidence)
        facade.setCurrentEngine(engine, type: .avAudioEngine, format: .flac)
        let track = makeTrack(name: "signal-path")
        let sourceFormat = AudioFileInfo(
            url: track.url,
            format: .flac,
            duration: 120,
            bitDepth: 24,
            sampleRate: 96_000,
            channels: 2,
            fileSize: 1,
            codec: "FLAC"
        )

        await facade.refreshDiagnostics(for: track, formatInfo: sourceFormat)

        #expect(uiState.diagnosticsStatus.signalPath?.source.codec == "FLAC")
        #expect(uiState.diagnosticsStatus.signalPath?.engineIdentifier == AudioEngineType.avAudioEngine.rawValue)
        #expect(uiState.diagnosticsStatus.signalPath?.loadedFormat?.sampleRate == 96_000)
        #expect(facade.diagnosticsStatus.signalPath == uiState.diagnosticsStatus.signalPath)
    }

    @Test("Playback health events invalidate the facade for live UI updates")
    @MainActor
    func playbackHealthEventsInvalidateFacade() async {
        let monitor = FacadeMonitorStub()
        let facade = AudioEngineFacade(monitor: monitor)
        var didPublishChange = false
        let cancellable = facade.objectWillChange.sink {
            didPublishChange = true
        }

        monitor.recordPlaybackHealthEvent(.mediaServicesResetDetected)
        await Task.yield()

        #expect(didPublishChange)
        #expect(facade.playbackHealthEvents.map(\.kind) == [.mediaServicesResetDetected])
        withExtendedLifetime(cancellable) {}
    }

    @Test("Restoring a persisted track reveals the launch mini player")
    @MainActor
    func restoringPersistedTrackRevealsMiniPlayer() async throws {
        let uiState = AudioUIState()
        let track = makeTrack(name: "restored-track")

        uiState.restorePersistedTrack(track)

        #expect(uiState.currentTrack?.id == track.id)
        #expect(uiState.showMiniPlayer)

        uiState.restorePersistedTrack(nil)
        #expect(uiState.currentTrack == nil)
        #expect(uiState.showMiniPlayer == false)
    }

    @Test("Restoring a recent library track creates a playable launch queue")
    @MainActor
    func restoringRecentLibraryTrackCreatesLaunchQueue() throws {
        let queueManager = AudioQueueManager()
        let uiState = AudioUIState()
        let facade = AudioEngineFacade(
            stateManager: PlaybackStateManager(),
            queueManager: queueManager,
            monitor: FacadeMonitorStub(),
            uiStateStore: uiState
        )
        let audioURL = try makeValidPCMTestAudioFile(name: "recent-library-track")
        let track = Track(
            url: audioURL,
            title: "recent-library-track",
            artist: "Artist",
            album: "Album",
            audioFormat: "CAF",
            duration: 0.25
        )
        defer { try? FileManager.default.removeItem(at: track.url) }

        let didRestore = facade.restoreLaunchTrack(track)

        #expect(didRestore)
        #expect(queueManager.currentTrack?.id == track.id)
        #expect(uiState.currentTrack?.id == track.id)
        #expect(uiState.showMiniPlayer)
    }

    @Test("Rebasing a recent library track preserves its complete display metadata")
    @MainActor
    func rebasingRecentLibraryTrackPreservesMetadata() throws {
        let fileManager = FileManager.default
        let documentsDirectory = try #require(
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        )
        let relativeDirectory = "Restore-\(UUID().uuidString)"
        let currentDirectory = documentsDirectory
            .appendingPathComponent("Music", isDirectory: true)
            .appendingPathComponent(relativeDirectory, isDirectory: true)
        try fileManager.createDirectory(at: currentDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: currentDirectory) }

        let sourceURL = try makeValidPCMTestAudioFile(name: "rebased-\(UUID().uuidString)")
        let availableURL = currentDirectory.appendingPathComponent("Song.caf")
        try fileManager.moveItem(at: sourceURL, to: availableURL)
        let staleURL = URL(
            fileURLWithPath: "/private/var/mobile/Containers/Data/Application/OLD/Documents/Music/"
                + relativeDirectory + "/Song.caf"
        )
        let track = Track(
            url: staleURL,
            title: "Metadata Track",
            artist: "Artist",
            album: "Album",
            audioFormat: "CAF",
            duration: 0.25,
            sampleRate: 96_000,
            bitDepth: 24,
            channels: 2,
            isLossless: true
        )
        track.genre = "Electronic"
        track.bitrate = 2_304

        let queueManager = AudioQueueManager()
        let uiState = AudioUIState()
        let facade = AudioEngineFacade(
            stateManager: PlaybackStateManager(),
            queueManager: queueManager,
            monitor: FacadeMonitorStub(),
            uiStateStore: uiState
        )

        let didRestore = facade.restoreLaunchTrack(track)

        #expect(didRestore)
        #expect(queueManager.currentTrack?.url == availableURL.standardizedFileURL)
        #expect(uiState.currentTrack === track)
        #expect(uiState.currentTrack?.sampleRate == 96_000)
        #expect(uiState.currentTrack?.bitDepth == 24)
        #expect(uiState.currentTrack?.genre == "Electronic")
        #expect(uiState.currentTrack?.bitrate == 2_304)
    }

    @Test("Launch fallback preserves an unavailable queue until playback commits it")
    @MainActor
    func launchFallbackDefersPersistenceUntilPlayback() async throws {
        let suiteName = "AudioEngineFacadeOrchestratorTests.fallback.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let unavailableTrack = LegacyTrack(
            title: "Unavailable Queue Track",
            artist: "Artist",
            album: "Album",
            url: URL(fileURLWithPath: "/unavailable/\(UUID().uuidString).caf"),
            duration: 120,
            format: .wav
        )
        try QueueState(tracks: [unavailableTrack], currentIndex: 0).save(to: defaults)

        let fallbackURL = try makeValidPCMTestAudioFile(name: "fallback-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: fallbackURL) }
        let fallbackTrack = Track(
            url: fallbackURL,
            title: "Recent Track",
            artist: "Artist",
            album: "Album",
            audioFormat: "CAF",
            duration: 0.25
        )
        let queueManager = AudioQueueManager(queueStateSuiteName: suiteName)
        let facade = AudioEngineFacade(
            stateManager: PlaybackStateManager(),
            queueManager: queueManager,
            monitor: FacadeMonitorStub(),
            uiStateStore: AudioUIState()
        )

        #expect(facade.restoreLaunchTrack(fallbackTrack))
        await queueManager.flushPendingPersistence()
        #expect(QueueState.load(from: defaults)?.currentTrack?.id == unavailableTrack.id)

        queueManager.commitRestoredFallbackIfNeeded()
        await queueManager.flushPendingPersistence()
        #expect(QueueState.load(from: defaults)?.currentTrack?.id == fallbackTrack.id)
    }

    @Test("Media-services reset before readiness records only the detection event")
    @MainActor
    func mediaServicesResetBeforeReadinessRecordsDetectionOnly() async {
        let monitor = FacadeMonitorStub()
        let facade = AudioEngineFacade(
            stateManager: PlaybackStateManager(),
            queueManager: AudioQueueManager(),
            monitor: monitor,
            runtimeMonitoringEnabled: false
        )

        await facade.audioSessionMediaServicesWereReset()

        #expect(monitor.playbackHealthEvents.map(\.kind) == [.mediaServicesResetDetected])
        #expect(facade.playbackHealthEvents.map(\.kind) == [.mediaServicesResetDetected])
    }

    @Test("Media-services reset recovery preserves the paused position and records the outcome")
    @MainActor
    func mediaServicesResetRecoveryPreservesPositionAndRecordsEvents() async throws {
        let suiteName = "AudioEngineFacadeOrchestratorTests.reset.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let monitor = FacadeMonitorStub()
        let queueManager = AudioQueueManager(queueStateSuiteName: suiteName)
        let facade = AudioEngineFacade(
            configuration: .default.with(performanceMode: .efficiency),
            engineFactory: AudioEngineFactory(preferences: defaults),
            stateManager: PlaybackStateManager(),
            queueManager: queueManager,
            monitor: monitor,
            playbackSettingsStore: AudioPlaybackSettingsStore(suiteName: suiteName),
            runtimeMonitoringEnabled: false
        )

        let audioURL = try makeValidPCMTestAudioFile(
            name: "reset-recovery-\(UUID().uuidString)",
            fileExtension: "wav"
        )
        defer { try? FileManager.default.removeItem(at: audioURL) }
        let track = Track(
            url: audioURL,
            title: "reset-recovery",
            artist: "Artist",
            album: "Album",
            audioFormat: "WAV",
            duration: 0.25
        )

        try await facade.initialize()
        #expect(facade.restoreLaunchTrack(track))
        await queueManager.saveState(playbackPosition: 0.2)

        await facade.audioSessionMediaServicesWereReset()

        #expect(monitor.playbackHealthEvents.map(\.kind) == [
            .mediaServicesResetDetected,
            .mediaServicesResetRecoverySucceeded,
        ])
        #expect(monitor.playbackHealthEvents.last?.detail == "position=0.200")
        #expect(facade.currentState == .paused(currentTime: 0.2, duration: 0.25))

        await facade.shutdown()
        await facade.sessionManager.disableRemoteCommands()
    }

    @Test("getCurrentMetrics delegates to monitor")
    @MainActor
    func getCurrentMetricsDelegatesToMonitor() async throws {
        let monitor = FacadeMonitorStub()
        monitor.currentMetrics = AudioMetrics(
            cpuUsage: 12,
            memoryUsage: 1_024,
            bufferUnderruns: 0,
            decodingLatency: 0.01,
            bufferFillLevel: 0.8,
            droppedFrames: 0,
            renderLatency: 0.01
        )
        let facade = AudioEngineFacade(
            stateManager: PlaybackStateManager(),
            queueManager: AudioQueueManager(),
            monitor: monitor
        )

        let metrics = await facade.getCurrentMetrics()

        #expect(metrics.cpuUsage == 12)
        #expect(monitor.getCurrentMetricsCallCount == 1)
    }

    @Test("Concurrent initialization callers share one attempt")
    @MainActor
    func concurrentInitializationCallersShareOneAttempt() async throws {
        let monitor = FacadeMonitorStub()
        monitor.suspendStartMonitoring()
        let facade = AudioEngineFacade(
            monitor: monitor,
            runtimeMonitoringEnabled: true
        )

        let firstInitialization = Task { @MainActor in
            try await facade.initialize()
        }
        await monitor.waitUntilStartMonitoringBegins()

        let secondInitialization = Task { @MainActor in
            try await facade.initialize()
        }
        await Task.yield()

        #expect(monitor.startMonitoringIntervals.count == 1)

        monitor.resumeStartMonitoring()
        try await firstInitialization.value
        try await secondInitialization.value

        #expect(facade.isReady)
        #expect(monitor.startMonitoringIntervals.count == 1)

        await facade.shutdown()
    }

    @Test("Shutdown cancels initialization and leaves retryable state")
    @MainActor
    func shutdownCancelsInitializationAndLeavesRetryableState() async throws {
        let monitor = FacadeMonitorStub()
        monitor.suspendStartMonitoring()
        let facade = AudioEngineFacade(
            monitor: monitor,
            runtimeMonitoringEnabled: true
        )

        let initialization = Task { @MainActor in
            try await facade.initialize()
        }
        await monitor.waitUntilStartMonitoringBegins()

        await facade.shutdown()
        monitor.resumeStartMonitoring()

        await #expect(throws: CancellationError.self) {
            try await initialization.value
        }
        #expect(facade.isReady == false)

        monitor.allowStartMonitoring()
        try await facade.initialize()

        #expect(facade.isReady)
        #expect(monitor.startMonitoringIntervals.count == 2)

        await facade.shutdown()
    }

    @Test("Latest playback request wins while the delayed request cannot commit")
    @MainActor
    func latestPlaybackRequestWins() async throws {
        let clock = ControlledTestClock()
        let facade = AudioEngineFacade(
            monitor: FacadeMonitorStub(),
            runtimeMonitoringEnabled: false
        )
        var committedRequests: [String] = []

        let delayedRequest = Task { @MainActor in
            try await facade.performLatestPlaybackRequest {
                try await clock.sleep(for: .seconds(10))
                committedRequests.append("A")
            }
        }
        try await clock.waitUntilSleeperCount()

        let latestRequest = Task { @MainActor in
            try await facade.performLatestPlaybackRequest {
                committedRequests.append("B")
            }
        }

        try await latestRequest.value
        try await delayedRequest.value

        #expect(committedRequests == ["B"])
        #expect(facade.playbackError == nil)
    }

    @Test("Caller cancellation remains observable when no newer playback request supersedes it")
    @MainActor
    func callerCancellationRemainsObservable() async throws {
        let clock = ControlledTestClock()
        let facade = AudioEngineFacade(
            monitor: FacadeMonitorStub(),
            runtimeMonitoringEnabled: false
        )

        let request = Task { @MainActor in
            try await facade.performLatestPlaybackRequest {
                try await clock.sleep(for: .seconds(10))
            }
        }
        try await clock.waitUntilSleeperCount()
        request.cancel()

        await #expect(throws: CancellationError.self) {
            try await request.value
        }
        #expect(facade.playbackError == nil)
    }

    @Test("Playback control errors publish user-visible message")
    @MainActor
    func playbackControlErrorsPublishMessage() async throws {
        let facade = AudioEngineFacade()

        facade.reportPlaybackControlError(AudioError.queueEmpty)

        #expect(facade.lastPlaybackErrorMessage == AudioError.queueEmpty.errorDescription)
    }

    @Test("Latest playback error replaces previous message")
    @MainActor
    func latestPlaybackErrorReplacesPreviousMessage() async throws {
        let facade = AudioEngineFacade()
        let firstError = AudioError.queueEmpty
        let secondError = AudioError.playbackFailed(reason: "Second failure")

        facade.reportPlaybackControlError(firstError)
        facade.reportPlaybackControlError(secondError)

        #expect(facade.lastPlaybackErrorMessage == secondError.errorDescription)
    }

    @Test("Repeated playback error reuses the visible presentation")
    @MainActor
    func repeatedPlaybackErrorReusesVisiblePresentation() async throws {
        let facade = AudioEngineFacade()
        let error = AudioError.queueEmpty

        facade.reportPlaybackControlError(error)
        let firstPresentation = try #require(facade.playbackError)
        facade.reportPlaybackControlError(error)

        #expect(facade.playbackError?.id == firstPresentation.id)
        #expect(facade.playbackError?.message == error.errorDescription)
    }

    @Test("Only the current playback error presentation can dismiss itself")
    @MainActor
    func onlyCurrentPlaybackErrorCanDismissItself() async throws {
        let facade = AudioEngineFacade()

        facade.reportPlaybackControlError(AudioError.queueEmpty)
        let supersededID = try #require(facade.playbackError?.id)
        facade.reportPlaybackControlError(AudioError.playbackFailed(reason: "Current failure"))
        let currentID = try #require(facade.playbackError?.id)

        facade.dismissPlaybackControlError(id: supersededID)
        #expect(facade.playbackError?.id == currentID)

        facade.dismissPlaybackControlError(id: currentID)
        #expect(facade.playbackError == nil)
        #expect(facade.lastPlaybackErrorMessage == nil)
    }

    @Test("Playback error presentation disables animation for Reduce Motion")
    @MainActor
    func playbackErrorPresentationDisablesAnimationForReduceMotion() async throws {
        #expect(PlaybackErrorBanner.presentationAnimation(reduceMotion: true) == nil)
        #expect(PlaybackErrorBanner.presentationAnimation(reduceMotion: false) != nil)
    }

    @Test("Remote command failures are surfaced by facade")
    @MainActor
    func remoteCommandFailuresAreSurfaced() async throws {
        let stateManager = PlaybackStateManager(enableTransitionValidation: false)
        let queueManager = AudioQueueManager()
        let facade = AudioEngineFacade(
            stateManager: stateManager,
            queueManager: queueManager,
            monitor: FacadeMonitorStub()
        )

        await facade.audioSessionDidReceiveCommand(.seek(to: 15))

        #expect(facade.lastPlaybackErrorMessage != nil)
    }

    @MainActor
    private func makeTrack(name: String) -> Track {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(name)
            .appendingPathExtension("flac")
        return Track(
            url: url,
            title: name,
            artist: "Artist",
            album: "Album",
            audioFormat: "FLAC",
            duration: 120
        )
    }

    private func makeFacadeDefaults(_ suffix: String) -> UserDefaults {
        let suiteName = "AudioEngineFacadeOrchestratorTests.\(suffix)"
        if let defaults = UserDefaults(suiteName: suiteName) {
            defaults.removePersistentDomain(forName: suiteName)
            return defaults
        }

        let fallback = UserDefaults.standard
        fallback.removePersistentDomain(forName: suiteName)
        return fallback
    }

    @MainActor
    private func makeValidPCMTestAudioFile(name: String, fileExtension: String = "caf") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
            .appendingPathExtension(fileExtension)
        let format = try #require(
            AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)
        )
        let buffer = try #require(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 11_025)
        )
        buffer.frameLength = 11_025
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
}

private final class FacadeMonitorStub: AudioPerformanceMonitoring, PlaybackHealthEventLogging {
    var metricsPublisher: AnyPublisher<AudioMetrics, Never> { Empty(completeImmediately: false).eraseToAnyPublisher() }
    var currentMetrics: AudioMetrics = .empty
    var attachedEngines: [AudioEngineService] = []
    var getCurrentMetricsCallCount = 0
    private(set) var playbackHealthEvents: [PlaybackHealthEvent] = []
    private let playbackHealthEventsSubject = CurrentValueSubject<[PlaybackHealthEvent], Never>([])

    var playbackHealthEventsPublisher: AnyPublisher<[PlaybackHealthEvent], Never> {
        playbackHealthEventsSubject.eraseToAnyPublisher()
    }

    func recordPlaybackHealthEvent(_ kind: PlaybackHealthEvent.Kind, detail: String?) {
        playbackHealthEvents.append(
            PlaybackHealthEvent(kind: kind, timestamp: Date(), detail: detail)
        )
        playbackHealthEventsSubject.send(playbackHealthEvents)
    }
    private(set) var updateIntervals: [TimeInterval] = []
    private(set) var startMonitoringIntervals: [TimeInterval] = []
    private(set) var stopMonitoringCallCount = 0
    private(set) var detachCallCount = 0
    private var shouldSuspendStartMonitoring = false
    private var suspendedStartMonitoringContinuation: CheckedContinuation<Void, Never>?
    private var startMonitoringObservers: [CheckedContinuation<Void, Never>] = []
    private var suspendedStartMonitoringWasCancelled = false

    var isMonitoring: Bool { get async { !startMonitoringIntervals.isEmpty && stopMonitoringCallCount == 0 } }

    func startMonitoring(updateInterval: TimeInterval) async {
        startMonitoringIntervals.append(updateInterval)

        let observers = startMonitoringObservers
        startMonitoringObservers.removeAll()
        observers.forEach { $0.resume() }

        guard shouldSuspendStartMonitoring else { return }

        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if suspendedStartMonitoringWasCancelled || Task.isCancelled {
                    continuation.resume()
                } else {
                    suspendedStartMonitoringContinuation = continuation
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelSuspendedStartMonitoring()
            }
        }
    }

    func stopMonitoring() async {
        stopMonitoringCallCount += 1
    }

    func updateMonitoringInterval(_ interval: TimeInterval) async {
        updateIntervals.append(interval)
    }

    func getCurrentMetrics() async -> AudioMetrics {
        getCurrentMetricsCallCount += 1
        return currentMetrics
    }

    func getSystemAudioMetrics() async -> SystemAudioMetrics {
        SystemAudioMetrics(
            systemAudioCPU: 0,
            activeAudioSessions: 0,
            systemAudioMemory: 0,
            deviceInfo: AudioDeviceInfo(
                deviceID: "stub",
                name: "stub",
                sampleRate: 44_100,
                bitDepth: 16,
                channels: 2,
                bufferSize: 512,
                latency: 0
            ),
            interruptionCount: 0,
            audioUnitLoad: 0
        )
    }

    func attachToEngine(_ engine: AudioEngineService) async {
        attachedEngines.append(engine)
    }

    func detachFromEngine() async {
        detachCallCount += 1
    }

    func suspendStartMonitoring() {
        shouldSuspendStartMonitoring = true
        suspendedStartMonitoringWasCancelled = false
    }

    func allowStartMonitoring() {
        shouldSuspendStartMonitoring = false
        suspendedStartMonitoringWasCancelled = false
        resumeStartMonitoring()
    }

    func waitUntilStartMonitoringBegins() async {
        if !startMonitoringIntervals.isEmpty {
            return
        }

        await withCheckedContinuation { continuation in
            startMonitoringObservers.append(continuation)
        }
    }

    func resumeStartMonitoring() {
        let continuation = suspendedStartMonitoringContinuation
        suspendedStartMonitoringContinuation = nil
        continuation?.resume()
    }

    private func cancelSuspendedStartMonitoring() {
        suspendedStartMonitoringWasCancelled = true
        resumeStartMonitoring()
    }

    var currentEngine: AudioEngineService? { get async { attachedEngines.last } }

    func startProfiling(duration _: TimeInterval?) async {}
    func stopProfiling() async {}
    var isProfiling: Bool { get async { false } }

}

private final class FacadeEngineStub: AudioEngineService {
    var currentTimeValue: TimeInterval
    var durationValue: TimeInterval
    var isPlayingValue: Bool
    var stopCallCount = 0
    let formatEvidence: AudioEngineFormatEvidence?

    init(
        currentTimeValue: TimeInterval = 0,
        durationValue: TimeInterval = 120,
        isPlayingValue: Bool = false,
        formatEvidence: AudioEngineFormatEvidence? = nil
    ) {
        self.currentTimeValue = currentTimeValue
        self.durationValue = durationValue
        self.isPlayingValue = isPlayingValue
        self.formatEvidence = formatEvidence
    }

    var currentTime: TimeInterval { get async { currentTimeValue } }
    var duration: TimeInterval { get async { durationValue } }
    var isPlaying: Bool { get async { isPlayingValue } }
    var volume: Float { get async { 1.0 } }
    var audioFormat: AudioFormat? { get async { .flac } }
    func playbackFormatEvidence() async -> AudioEngineFormatEvidence? { formatEvidence }

    func load(url _: URL) async throws {}
    func play() async throws { isPlayingValue = true }
    func pause() async { isPlayingValue = false }
    func stop() async {
        stopCallCount += 1
        isPlayingValue = false
    }

    func seek(to time: TimeInterval) async throws {
        currentTimeValue = time
    }

    func setVolume(_: Float) async {}
    func setPlaybackRate(_: Double) async {}
    func applyReplayGain(_: Float) async {}
    func configure(with _: AudioEngineConfiguration) async throws {}
    func prepareNext(url _: URL) async {}
    func invalidatePreparedTransition() async {}
    func crossfade(to _: URL, duration _: TimeInterval, playbackRate _: Double, gainDB _: Float) async throws {}
    var metricsAvailability: AudioMetricsAvailability { .available }
    func availableMetrics() async -> AudioMetrics? { .empty }
    func collectMetrics() async {}
}
