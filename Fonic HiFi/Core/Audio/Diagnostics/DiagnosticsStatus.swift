import Foundation

public struct DiagnosticsStatus: Sendable, Equatable {
    public let track: TrackSummary?
    public let validationResult: BitPerfectValidationResult?
    public let device: AudioDevice?
    public let dacInfo: DACCompatibilityInfo?
    public let metrics: AudioMetrics?
    public let signalPath: SignalPathSnapshot?
    public let updatedAt: Date

    public init(
        track: TrackSummary?,
        validationResult: BitPerfectValidationResult?,
        device: AudioDevice?,
        dacInfo: DACCompatibilityInfo?,
        metrics: AudioMetrics?,
        signalPath: SignalPathSnapshot? = nil,
        updatedAt: Date
    ) {
        self.track = track
        self.validationResult = validationResult
        self.device = device
        self.dacInfo = dacInfo
        self.metrics = metrics
        self.signalPath = signalPath
        self.updatedAt = updatedAt
    }

    public static var empty: DiagnosticsStatus {
        DiagnosticsStatus(
            track: nil,
            validationResult: nil,
            device: nil,
            dacInfo: nil,
            metrics: nil,
            signalPath: nil,
            updatedAt: Date(),
        )
    }
}

public struct TrackSummary: Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let artist: String
    public let album: String
    public let format: String

    public init(id: UUID, title: String, artist: String, album: String, format: String) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.format = format
    }
}
