@testable import Fonic_HiFi
import AVFoundation
import XCTest

@MainActor
final class AVAudioEngineGaplessWaveformTests: XCTestCase {
    func testPreparedBoundaryHasNoInsertedSilenceOrOverlap() async throws {
        let trackDuration: TimeInterval = 0.5
        let sourceURL = try makePCMTestAudioFile(
            duration: trackDuration,
            fileExtension: "wav",
            testCase: self
        )
        let targetURL = try makePCMTestAudioFile(
            duration: trackDuration,
            fileExtension: "wav",
            testCase: self
        )
        let adapter = try AVAudioEngineAdapter()
        try await adapter.load(url: sourceURL)

        let captureNode = try XCTUnwrap(
            Mirror(reflecting: adapter).children
                .first(where: { $0.label == "submixNode" })?
                .value as? AVAudioMixerNode,
            "The waveform probe requires the native engine's mixed player output"
        )
        let captureFormat = captureNode.outputFormat(forBus: 0)
        let captureDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaplessWaveform-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: captureDirectory,
            withIntermediateDirectories: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: captureDirectory)
        }
        let captureURL = captureDirectory.appendingPathComponent("prepared-boundary.caf")
        let (sampleStream, sampleContinuation) = AsyncStream<[Float]>.makeStream()
        let sampleCollector = Task {
            var collected: [Float] = []
            for await chunk in sampleStream {
                collected.append(contentsOf: chunk)
            }
            return collected
        }

        try captureNode.installAudioTap(
            onBus: 0,
            bufferSize: 256,
            format: captureFormat,
            tapProvider: Self.makeCaptureTap(continuation: sampleContinuation)
        )
        var tapIsInstalled = true
        defer {
            if tapIsInstalled {
                captureNode.removeTap(onBus: 0)
                sampleContinuation.finish()
            }
        }

        let completions = expectation(description: "Both scheduled files completed")
        completions.expectedFulfillmentCount = 2
        adapter.setCompletionHandler {
            completions.fulfill()
        }

        try await adapter.play()
        for _ in 0 ..< 100 {
            if await adapter.currentTime > 0.02 {
                break
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        let preparedAtTime = await adapter.currentTime
        XCTAssertGreaterThan(
            preparedAtTime,
            0.02,
            "The source player must have a render time before scheduling the boundary"
        )

        await adapter.prepareNext(url: targetURL)
        XCTAssertTrue(adapter.hasNextPrepared)
        await fulfillment(of: [completions], timeout: 3)
        try await Task.sleep(for: .milliseconds(100))
        await adapter.stop()

        captureNode.removeTap(onBus: 0)
        tapIsInstalled = false
        sampleContinuation.finish()
        let samples = await sampleCollector.value

        let attachmentFormat = try XCTUnwrap(
            AVAudioFormat(
                standardFormatWithSampleRate: captureFormat.sampleRate,
                channels: 1
            )
        )
        let attachmentBuffer = try XCTUnwrap(
            AVAudioPCMBuffer(
                pcmFormat: attachmentFormat,
                frameCapacity: AVAudioFrameCount(samples.count)
            )
        )
        attachmentBuffer.frameLength = AVAudioFrameCount(samples.count)
        let attachmentSamples = try XCTUnwrap(attachmentBuffer.floatChannelData).pointee
        for (index, sample) in samples.enumerated() {
            attachmentSamples[index] = sample
        }
        let captureFile = try AVAudioFile(
            forWriting: captureURL,
            settings: attachmentFormat.settings
        )
        try captureFile.write(from: attachmentBuffer)

        let activeThreshold: Float = 0.0001
        let activeRange = try XCTUnwrap(
            activeSampleRange(
                samples: samples,
                threshold: activeThreshold
            ),
            "The captured output must contain rendered audio"
        )

        let framesPerTrack = Int(trackDuration * captureFormat.sampleRate)
        let expectedBoundary = activeRange.lowerBound + framesPerTrack
        let analysisRange = max(activeRange.lowerBound, expectedBoundary - 256) ...
            min(activeRange.upperBound, expectedBoundary + 256)
        let longestSilence = longestSilenceRun(
            samples: samples,
            range: analysisRange,
            threshold: activeThreshold
        )
        let preBoundaryRange = max(activeRange.lowerBound, expectedBoundary - 2_048) ...
            max(activeRange.lowerBound, expectedBoundary - 257)
        let preBoundaryPeak = peakMagnitude(samples: samples, range: preBoundaryRange)
        let boundaryPeak = peakMagnitude(samples: samples, range: analysisRange)
        let activeFrameCount = activeRange.count
        let expectedActiveFrameCount = framesPerTrack * 2
        let frameCountDelta = activeFrameCount - expectedActiveFrameCount

        let report = """
        engine_path=AVAudioEngineAdapter.renderBoundary
        input_format=linear PCM WAV
        input_sample_rate=44100
        input_channels=2
        input_frames_per_track=\(Int(trackDuration * 44_100))
        capture_sample_rate=\(captureFormat.sampleRate)
        expected_boundary_frame=\(expectedBoundary)
        active_frame_range=\(activeRange.lowerBound)...\(activeRange.upperBound)
        active_frame_count=\(activeFrameCount)
        expected_active_frame_count=\(expectedActiveFrameCount)
        frame_count_delta=\(frameCountDelta)
        longest_silence_run_at_boundary=\(longestSilence)
        pre_boundary_peak=\(preBoundaryPeak)
        boundary_peak=\(boundaryPeak)
        overlap_peak_ratio=\(boundaryPeak / max(preBoundaryPeak, .leastNonzeroMagnitude))
        """

        let reportAttachment = XCTAttachment(string: report)
        reportAttachment.name = "AVAudioEngine prepared-boundary sample report"
        reportAttachment.lifetime = .keepAlways
        add(reportAttachment)

        let waveformAttachment = XCTAttachment(contentsOfFile: captureURL)
        waveformAttachment.name = "AVAudioEngine prepared-boundary rendered output"
        waveformAttachment.lifetime = .keepAlways
        add(waveformAttachment)

        XCTAssertLessThanOrEqual(
            longestSilence,
            2,
            "The scheduled boundary inserted a multi-frame silence run.\n\(report)"
        )
        XCTAssertLessThanOrEqual(
            boundaryPeak,
            preBoundaryPeak * 1.25,
            "The scheduled boundary contains an overlapped or duplicated amplitude spike.\n\(report)"
        )
        XCTAssertLessThanOrEqual(
            abs(frameCountDelta),
            512,
            "Rendered active duration differs from the two known fixtures.\n\(report)"
        )
    }

    private func activeSampleRange(
        samples: [Float],
        threshold: Float
    ) -> ClosedRange<Int>? {
        guard let first = samples.indices.first(where: { abs(samples[$0]) > threshold }),
              let last = samples.indices.last(where: { abs(samples[$0]) > threshold })
        else {
            return nil
        }
        return first ... last
    }

    private func longestSilenceRun(
        samples: [Float],
        range: ClosedRange<Int>,
        threshold: Float
    ) -> Int {
        var longest = 0
        var current = 0
        for index in range {
            if abs(samples[index]) <= threshold {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        return longest
    }

    private func peakMagnitude(
        samples: [Float],
        range: ClosedRange<Int>
    ) -> Float {
        range.reduce(0) { peak, index in
            max(peak, abs(samples[index]))
        }
    }

    private nonisolated static func makeCaptureTap(
        continuation: AsyncStream<[Float]>.Continuation
    ) -> @Sendable (AVReadOnlyAudioPCMBuffer, AVAudioTime) -> Void {
        { buffer, _ in
            guard case let .float(samples) = buffer.channelData(0) else { return }
            var copiedSamples: [Float] = []
            copiedSamples.reserveCapacity(samples.count)
            for index in 0 ..< samples.count {
                copiedSamples.append(samples[index])
            }
            continuation.yield(copiedSamples)
        }
    }
}
