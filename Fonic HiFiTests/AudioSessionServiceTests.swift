import AVFoundation
@testable import Fonic_HiFi
import XCTest

final class AudioSessionServiceTests: XCTestCase {
    func testRouteChangeReasonMappingMatchesAVFoundationCases() {
        let expectations: [(AVAudioSession.RouteChangeReason, AudioRouteChangeReason)] = [
            (.newDeviceAvailable, .newDeviceAvailable),
            (.oldDeviceUnavailable, .oldDeviceUnavailable),
            (.categoryChange, .categoryChange),
            (.override, .override),
            (.wakeFromSleep, .wakeFromSleep),
            (.noSuitableRouteForCategory, .noSuitableRouteForCategory),
            (.routeConfigurationChange, .routeConfigurationChange),
        ]

        for (reason, expected) in expectations {
            XCTAssertEqual(AudioRouteChangeReason(from: reason), expected)
        }

        XCTAssertEqual(AudioRouteChangeReason(from: .unknown), .unknown)
    }

    func testRouteChangeReasonDescriptions() {
        let allReasons: [AudioRouteChangeReason] = [
            .newDeviceAvailable,
            .oldDeviceUnavailable,
            .categoryChange,
            .override,
            .wakeFromSleep,
            .noSuitableRouteForCategory,
            .routeConfigurationChange,
            .unknown,
        ]

        for reason in allReasons {
            XCTAssertFalse(reason.description.isEmpty)
        }
    }

    func testRemoteCommandDescriptionsRenderAssociatedValues() {
        XCTAssertEqual(RemoteCommand.play.description, "play")
        XCTAssertEqual(RemoteCommand.pause.description, "pause")
        XCTAssertEqual(RemoteCommand.changePlaybackRate(1.25).description, "changePlaybackRate(1.25)")
        XCTAssertEqual(RemoteCommand.seek(to: 42.5).description, "seek(to: 42.5)")
        XCTAssertEqual(RemoteCommand.skipForward(15).description, "skipForward(15.0)")
        XCTAssertEqual(RemoteCommand.skipBackward(7.5).description, "skipBackward(7.5)")
    }
}
