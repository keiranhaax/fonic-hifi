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

    @Test("setCurrentTrack propagates to facade UI state")
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
        #expect(uiState.showMiniPlayer == true)

        facade.setCurrentTrack(nil)
        #expect(uiState.currentTrack == nil)
        #expect(uiState.showMiniPlayer == false)
        #expect(uiState.diagnosticsStatus.track == nil)
        #expect(uiState.diagnosticsStatus.validationResult == nil)
        #expect(uiState.diagnosticsStatus.device == nil)
        #expect(uiState.diagnosticsStatus.dacInfo == nil)
        #expect(uiState.diagnosticsStatus.metrics == nil)
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
}

private final class FacadeMonitorStub: AudioPerformanceMonitoring, AudioDiagnosticsReporting {
    var metricsPublisher: AnyPublisher<AudioMetrics, Never> { Empty(completeImmediately: false).eraseToAnyPublisher() }
    var currentMetrics: AudioMetrics = .empty
    var attachedEngines: [AudioEngineService] = []
    var getCurrentMetricsCallCount = 0
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
    func getProfilingResults() async -> PerformanceProfile? { nil }
    var isProfiling: Bool { get async { false } }

    func performDiagnosticsCheck() async -> PlaybackDiagnostics {
        fatalError("performDiagnosticsCheck() is not used by these tests")
    }

    func getPerformanceRecommendations() async -> [PerformanceRecommendation] {
        []
    }

    func exportMetrics(format _: ExportFormat, timeRange _: DateInterval?) async -> Data {
        Data()
    }

    func generateReport(for _: DateInterval) async -> MonitoringReport {
        fatalError("generateReport(for:) is not used by these tests")
    }
}

private final class FacadeEngineStub: AudioEngineService {
    var currentTimeValue: TimeInterval
    var durationValue: TimeInterval
    var isPlayingValue: Bool
    var stopCallCount = 0

    init(
        currentTimeValue: TimeInterval = 0,
        durationValue: TimeInterval = 120,
        isPlayingValue: Bool = false
    ) {
        self.currentTimeValue = currentTimeValue
        self.durationValue = durationValue
        self.isPlayingValue = isPlayingValue
    }

    var currentTime: TimeInterval { get async { currentTimeValue } }
    var duration: TimeInterval { get async { durationValue } }
    var isPlaying: Bool { get async { isPlayingValue } }
    var volume: Float { get async { 1.0 } }
    var audioFormat: AudioFormat? { get async { .flac } }

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
    func crossfade(to _: URL, duration _: TimeInterval, playbackRate _: Double, gainDB _: Float) async throws {}
    var metricsAvailability: AudioMetricsAvailability { .available }
    func availableMetrics() async -> AudioMetrics? { .empty }
    func collectMetrics() async {}
}
