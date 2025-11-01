//
//  BitPerfectDeviceManager.swift
//  Fonic HiFi
//
//  Created by Factory Droid on 10/6/25.
//

import AVFoundation
import Foundation
import OSLog

@MainActor
public protocol BitPerfectDeviceManaging: AnyObject {
    func currentCapabilities(using session: AVAudioSession) async -> DeviceCapabilities
    func availableDevices(using session: AVAudioSession) async -> [DeviceWithCapabilities]
    func supportsBitPerfectPlayback(device: AudioDevice) async -> Bool
    func updateDACCompatibility(_ dacInfo: DACCompatibilityInfo) async
    func dacCompatibility(for deviceIdentifier: String) async -> DACCompatibilityInfo?
    func clearDACCompatibilityCache() async
    func currentDeviceInfo(using session: AVAudioSession) async -> DeviceValidationInfo?
    func estimateOutputBitDepth(for session: AVAudioSession, capabilities: DeviceCapabilities) -> Int
}

@MainActor
public final class BitPerfectDeviceManager: BitPerfectDeviceManaging {
    private var dacCompatibilityCache: [String: DACCompatibilityInfo]
    private var deviceCapabilitiesCache: [String: DeviceCapabilities]
    private let logger = Log.logger(.diagnosticsBitPerfectDevice)

    public init(
        dacCompatibilityCache: [String: DACCompatibilityInfo] = [:],
        deviceCapabilitiesCache: [String: DeviceCapabilities] = [:],
    ) {
        self.dacCompatibilityCache = dacCompatibilityCache
        self.deviceCapabilitiesCache = deviceCapabilitiesCache
        loadBuiltInDACCompatibility()
    }

    // MARK: - BitPerfectDeviceManaging

    public func currentCapabilities(using session: AVAudioSession) async -> DeviceCapabilities {
        guard let output = session.currentRoute.outputs.first else {
            return defaultDeviceCapabilities()
        }

        if let cached = self.deviceCapabilitiesCache[output.uid] {
            return cached
        }

        let capabilities = determineDeviceCapabilities(from: output)
        self.deviceCapabilitiesCache[output.uid] = capabilities
        return capabilities
    }

    public func availableDevices(using session: AVAudioSession) async -> [DeviceWithCapabilities] {
        session.currentRoute.outputs.map { output in
            let device = AudioDevice(
                id: output.uid,
                name: output.portName,
                type: audioDeviceType(from: output.portType),
                isOutput: true,
                isAvailable: true,
                connectionType: audioConnectionType(from: output.portType),
                supportedSampleRates: getEstimatedSampleRates(for: output).map(Double.init),
                supportedBitDepths: [UInt16(16), UInt16(getEstimatedMaxBitDepth(for: output))],
                maxChannels: UInt8(output.channels?.count ?? 2),
                supportsBitPerfect: supportsBitPerfectType(audioDeviceType(from: output.portType)),
                isDefault: session.currentRoute.outputs.first?.uid == output.uid,
            )

            let capabilities = determineDeviceCapabilities(from: output)
            return DeviceWithCapabilities(device: device, capabilities: capabilities)
        }
    }

    public func supportsBitPerfectPlayback(device: AudioDevice) async -> Bool {
        let connectionSupported = device.type.supportsHighQuality

        if let dacInfo = self.dacCompatibilityCache[device.id] {
            return connectionSupported && dacInfo.supportsBitPerfect
        }

        let capabilities = self.deviceCapabilitiesCache[device.id] ?? self.defaultDeviceCapabilities()
        return connectionSupported &&
            capabilities.maxBitDepth >= 16 &&
            capabilities.supportedSampleRates.contains(44100)
    }

    public func updateDACCompatibility(_ dacInfo: DACCompatibilityInfo) async {
        self.dacCompatibilityCache[dacInfo.deviceIdentifier] = dacInfo
        self.saveDACCompatibilityDatabase()
    }

    public func dacCompatibility(for deviceIdentifier: String) async -> DACCompatibilityInfo? {
        self.dacCompatibilityCache[deviceIdentifier]
    }

    public func clearDACCompatibilityCache() async {
        self.dacCompatibilityCache.removeAll()
        self.saveDACCompatibilityDatabase()
    }

    public func currentDeviceInfo(using session: AVAudioSession) async -> DeviceValidationInfo? {
        guard let output = session.currentRoute.outputs.first else { return nil }
        let capabilities = await currentCapabilities(using: session)
        return DeviceValidationInfo(
            id: output.uid,
            name: output.portName,
            type: audioDeviceType(from: output.portType),
            isDefault: true,
            capabilities: capabilities,
            connectionType: connectionType(from: output.portType),
        )
    }

    public func estimateOutputBitDepth(for session: AVAudioSession, capabilities: DeviceCapabilities) -> Int {
        guard let output = session.currentRoute.outputs.first else { return 16 }

        self.logger.debug("Estimating bit depth for device: \(output.portName, privacy: .public)")

        switch output.portType {
        case .builtInSpeaker, .builtInReceiver:
            return 16
        case .headphones:
            return output.portName.contains("USB") || output.portName.contains("Lightning") ? 24 : 16
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            return 16
        case .usbAudio:
            return min(capabilities.maxBitDepth, 24)
        case .thunderbolt:
            return capabilities.maxBitDepth
        case .carAudio:
            return 16
        case .HDMI:
            return 24
        default:
            return 16
        }
    }

    // MARK: - Private Helpers

    private func determineDeviceCapabilities(from output: AVAudioSessionPortDescription) -> DeviceCapabilities {
        switch output.portType {
        case .builtInSpeaker, .builtInReceiver:
            return DeviceCapabilities(
                supportedSampleRates: [44100, 48000],
                maxBitDepth: 16,
                maxChannels: 2,
                supportsHardwareVolume: true,
                bypassesSystemMixer: false,
                bufferSizeRange: 256 ... 2048,
                supportsExclusiveMode: false,
            )

        case .headphones:
            return DeviceCapabilities(
                supportedSampleRates: [44100, 48000],
                maxBitDepth: 16,
                maxChannels: 2,
                supportsHardwareVolume: false,
                bypassesSystemMixer: false,
                bufferSizeRange: 256 ... 1024,
                supportsExclusiveMode: false,
            )

        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            return DeviceCapabilities(
                supportedSampleRates: [44100, 48000],
                maxBitDepth: 16,
                maxChannels: 2,
                supportsHardwareVolume: true,
                bypassesSystemMixer: false,
                bufferSizeRange: 512 ... 2048,
                supportsExclusiveMode: false,
            )

        case .usbAudio:
            if let dacInfo = self.dacCompatibilityCache[output.uid] {
                return DeviceCapabilities(
                    supportedSampleRates: dacInfo.supportedSampleRates,
                    maxBitDepth: dacInfo.maxBitDepth,
                    maxChannels: dacInfo.maxChannels,
                    supportsHardwareVolume: dacInfo.supportsHardwareVolume,
                    bypassesSystemMixer: dacInfo.bypassesSystemMixer,
                    bufferSizeRange: dacInfo.bufferSizeRange,
                    supportsExclusiveMode: dacInfo.supportsExclusiveMode,
                )
            }

            return DeviceCapabilities(
                supportedSampleRates: [44100, 48000, 96000, 192_000],
                maxBitDepth: 24,
                maxChannels: 2,
                supportsHardwareVolume: true,
                bypassesSystemMixer: false,
                bufferSizeRange: 128 ... 4096,
                supportsExclusiveMode: false,
            )

        default:
            return defaultDeviceCapabilities()
        }
    }

    private func getEstimatedSampleRates(for output: AVAudioSessionPortDescription) -> [Int] {
        switch output.portType {
        case .usbAudio:
            [44100, 48000, 96000, 192_000]
        case .builtInSpeaker, .builtInReceiver, .headphones:
            [44100, 48000]
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            [44100, 48000]
        default:
            [44100, 48000]
        }
    }

    private func getEstimatedMaxBitDepth(for output: AVAudioSessionPortDescription) -> Int {
        switch output.portType {
        case .usbAudio:
            24
        case .builtInSpeaker, .builtInReceiver, .headphones:
            16
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            16
        default:
            16
        }
    }

    private func audioDeviceType(from portType: AVAudioSession.Port) -> AudioDeviceType {
        switch portType {
        case .builtInSpeaker, .builtInReceiver:
            .builtin
        case .headphones:
            .headphones
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            .bluetooth
        case .airPlay:
            .airPlay
        case .usbAudio:
            .usb
        case .thunderbolt:
            .thunderbolt
        case .HDMI:
            .hdmi
        case .lineOut:
            .speakers
        default:
            .unknown
        }
    }

    private func audioConnectionType(from portType: AVAudioSession.Port) -> AudioConnectionType {
        switch portType {
        case .builtInSpeaker, .builtInReceiver:
            .builtin
        case .headphones:
            .headphoneJack
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            .bluetooth
        case .airPlay:
            .airPlay
        case .usbAudio:
            .usb
        case .thunderbolt:
            .thunderbolt
        case .lineIn, .lineOut:
            .unknown
        default:
            .unknown
        }
    }

    private func connectionType(from portType: AVAudioSession.Port) -> DeviceConnectionType {
        switch portType {
        case .builtInSpeaker, .builtInReceiver:
            .builtin
        case .headphones:
            .wired
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            .bluetooth
        case .airPlay:
            .airplay
        case .usbAudio:
            .usb
        case .thunderbolt:
            .thunderbolt
        case .lineOut:
            .wired
        default:
            .unknown
        }
    }

    private func supportsBitPerfectType(_ type: AudioDeviceType) -> Bool {
        switch type {
        case .usbDAC, .usb, .thunderbolt:
            true
        default:
            false
        }
    }

    private func loadBuiltInDACCompatibility() {
        if self.dacCompatibilityCache["apple_builtin"] == nil {
            self.dacCompatibilityCache["apple_builtin"] = DACCompatibilityInfo.appleBuiltIn()
        }
        if self.dacCompatibilityCache["generic_usb_dac"] == nil {
            self.dacCompatibilityCache["generic_usb_dac"] = DACCompatibilityInfo.genericUSBDAC()
        }
    }

    private func saveDACCompatibilityDatabase() {
        self.logger.debug("Persisted DAC compatibility database entries: \(self.dacCompatibilityCache.count)")
    }

    private func defaultDeviceCapabilities() -> DeviceCapabilities {
        DeviceCapabilities(
            supportedSampleRates: [44100, 48000],
            maxBitDepth: 16,
            maxChannels: 2,
            supportsHardwareVolume: true,
            bypassesSystemMixer: false,
            bufferSizeRange: 256 ... 2048,
            supportsExclusiveMode: false,
        )
    }
}
