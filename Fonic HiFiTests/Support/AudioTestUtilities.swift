import AVFoundation
import Foundation
import XCTest

@MainActor
func makePCMTestAudioFile(
    duration: TimeInterval = 0.25,
    sampleRate: Double = 44_100,
    channels: AVAudioChannelCount = 2,
    fileExtension: String = "caf",
    testCase: XCTestCase
) throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let url = directory.appendingPathComponent("test-audio.").appendingPathExtension(fileExtension)

    guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels) else {
        throw XCTSkip("Unable to create audio format")
    }

    let frameCount = AVAudioFrameCount(duration * sampleRate)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
        throw XCTSkip("Unable to allocate audio buffer")
    }

    buffer.frameLength = frameCount
    if let channelData = buffer.floatChannelData {
        let totalSamples = Int(buffer.frameLength)
        for channel in 0..<Int(channels) {
            let samples = channelData[channel]
            for index in 0..<totalSamples {
                samples[index] = sinf(2.0 * .pi * Float(index) / Float(sampleRate / 440.0)) * 0.1
            }
        }
    }

    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    try file.write(from: buffer)

    testCase.addTeardownBlock {
        try? FileManager.default.removeItem(at: directory)
    }

    return url
}
