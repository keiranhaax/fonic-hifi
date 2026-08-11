@testable import Fonic_HiFi
import Foundation
import XCTest

final class SignalPathSnapshotTests: XCTestCase {
    func testEligibleSnapshotRequiresMeasuredLoadedEnginePath() {
        let evidence = AudioEngineFormatEvidence(
            isTrackLoaded: true,
            loadedSampleRate: 96_000,
            loadedChannelCount: 2,
            engineOutputSampleRate: 96_000,
            engineOutputChannelCount: 2,
            hasEngineProcessing: false
        )
        let result = makeValidationResult(
            isValid: true,
            measurementEvidence: [.sourceFormat, .actualEngineOutputFormat]
        )

        let snapshot = SignalPathSnapshot(
            sourceFormat: makeSourceFormat(),
            context: makeContext(evidence: evidence),
            validationResult: result,
            device: .usbDAC(name: "Test DAC"),
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(snapshot.eligibility, .eligible)
        XCTAssertEqual(snapshot.source.codec, "FLAC")
        XCTAssertEqual(snapshot.loadedFormat?.sampleRate, 96_000)
        XCTAssertEqual(snapshot.loadedFormat?.sampleRateEvidence, .measured)
        XCTAssertEqual(snapshot.outputFormat.sampleRate, 96_000)
        XCTAssertEqual(snapshot.outputFormat.sampleRateEvidence, .measured)
        XCTAssertEqual(snapshot.outputFormat.bitDepthEvidence, .estimated)
        XCTAssertEqual(
            snapshot.device?.supportedSampleRates,
            [44_100, 48_000, 88_200, 96_000, 176_400, 192_000]
        )
        XCTAssertEqual(snapshot.device?.supportedBitDepths, [16, 24, 32])
        XCTAssertEqual(snapshot.device?.maxChannels, 2)
        XCTAssertTrue(snapshot.device?.supportsBitPerfect == true)
        XCTAssertTrue(snapshot.processing.isBypassed)
    }

    func testSnapshotIsUnavailableWithoutPostLoadEngineEvidence() {
        let result = makeValidationResult(isValid: true)

        let snapshot = SignalPathSnapshot(
            sourceFormat: makeSourceFormat(),
            context: makeContext(evidence: nil),
            validationResult: result,
            device: nil,
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(snapshot.eligibility, .unavailable)
        XCTAssertNil(snapshot.loadedFormat)
        XCTAssertEqual(snapshot.outputFormat.sampleRateEvidence, .estimated)
    }

    func testSnapshotIsIneligibleWhenMeasuredPathHasProcessing() {
        let evidence = AudioEngineFormatEvidence(
            isTrackLoaded: true,
            loadedSampleRate: 96_000,
            loadedChannelCount: 2,
            engineOutputSampleRate: 96_000,
            engineOutputChannelCount: 2,
            hasEngineProcessing: true
        )
        let result = makeValidationResult(
            isValid: false,
            measurementEvidence: [.sourceFormat, .actualEngineOutputFormat],
            hasAudioProcessing: true,
            mismatchReason: .audioProcessingActive
        )

        let snapshot = SignalPathSnapshot(
            sourceFormat: makeSourceFormat(),
            context: makeContext(evidence: evidence),
            validationResult: result,
            device: nil,
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(snapshot.eligibility, .ineligible)
        XCTAssertFalse(snapshot.processing.isBypassed)
        XCTAssertEqual(snapshot.mismatchReason, .audioProcessingActive)
    }

    func testSnapshotPreservesMeasuredOutputMismatchAndEstimatedBitDepth() {
        let evidence = AudioEngineFormatEvidence(
            isTrackLoaded: true,
            loadedSampleRate: 96_000,
            loadedChannelCount: 2,
            engineOutputSampleRate: 48_000,
            engineOutputChannelCount: 2,
            hasEngineProcessing: false
        )
        let result = makeValidationResult(
            isValid: false,
            measurementEvidence: [.sourceFormat, .actualEngineOutputFormat],
            actualSampleRate: 48_000,
            mismatchReason: .sampleRateMismatch
        )

        let snapshot = SignalPathSnapshot(
            sourceFormat: makeSourceFormat(),
            context: makeContext(evidence: evidence),
            validationResult: result,
            device: .builtInSpeaker(),
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(snapshot.eligibility, .ineligible)
        XCTAssertEqual(snapshot.outputFormat.sampleRate, 48_000)
        XCTAssertEqual(snapshot.outputFormat.sampleRateEvidence, .measured)
        XCTAssertEqual(snapshot.outputFormat.bitDepth, 24)
        XCTAssertEqual(snapshot.outputFormat.bitDepthEvidence, .estimated)
        XCTAssertEqual(snapshot.mismatchReason, .sampleRateMismatch)
    }

    private func makeSourceFormat() -> AudioFileInfo {
        AudioFileInfo(
            url: URL(fileURLWithPath: "/synthetic/test.flac"),
            format: .flac,
            duration: 1,
            bitDepth: 24,
            sampleRate: 96_000,
            channels: 2,
            fileSize: 1,
            codec: "FLAC"
        )
    }

    private func makeContext(
        evidence: AudioEngineFormatEvidence?
    ) -> BitPerfectEligibilityContext {
        BitPerfectEligibilityContext(
            engineIdentifier: AudioEngineType.avAudioEngine.rawValue,
            applicationVolume: 1,
            playbackRate: 1,
            replayGainEnabled: false,
            equalizerEnabled: false,
            crossfadeEnabled: false,
            engineEvidence: evidence
        )
    }

    private func makeValidationResult(
        isValid: Bool,
        measurementEvidence: Set<BitPerfectMeasurementEvidence> = [.sourceFormat],
        actualSampleRate: Int = 96_000,
        hasAudioProcessing: Bool = false,
        mismatchReason: BitPerfectMismatchReason? = nil
    ) -> BitPerfectValidationResult {
        BitPerfectValidationResult(
            isValid: isValid,
            measurementEvidence: measurementEvidence,
            expectedSampleRate: 96_000,
            actualSampleRate: actualSampleRate,
            expectedBitDepth: 24,
            actualBitDepth: 24,
            actualBitDepthIsEstimated: true,
            expectedChannels: 2,
            actualChannels: 2,
            mismatchReason: mismatchReason,
            deviceSupportsFormat: true,
            deviceCapabilitiesAreEstimated: true,
            hasAudioProcessing: hasAudioProcessing,
            systemVolume: 1,
            applicationVolume: 1
        )
    }
}
