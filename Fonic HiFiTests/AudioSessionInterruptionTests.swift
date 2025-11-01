@testable import Fonic_HiFi
import AVFoundation
import XCTest

final class AudioSessionInterruptionTests: XCTestCase {
    func testFactoryHelpersProduceExpectedValues() {
        let began = AudioSessionInterruption.began(category: .alarm, context: ["source": "system"])
        XCTAssertEqual(began.type, .began)
        XCTAssertFalse(began.shouldResume)
        XCTAssertEqual(began.category, .alarm)
        XCTAssertEqual(began.contextValue(for: "source"), "system")
        XCTAssertEqual(began.recommendedAction, .pause)

        let ended = AudioSessionInterruption.ended(shouldResume: true, category: .notification)
        XCTAssertEqual(ended.type, .ended)
        XCTAssertTrue(ended.shouldResume)
        XCTAssertEqual(ended.category?.allowsAutoResume, true)
        XCTAssertEqual(ended.recommendedAction, .resume)
        XCTAssertFalse(ended.suggestsManualResume)
    }

    func testFromNotificationBeganParsesReason() {
        let userInfo: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue,
            AVAudioSessionInterruptionReasonKey: AVAudioSession.InterruptionReason.routeDisconnected.rawValue,
        ]

        let notification = Notification(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: userInfo
        )

        let interruption = AudioSessionInterruption.from(notification: notification)

        XCTAssertNotNil(interruption)
        XCTAssertEqual(interruption?.type, .began)
        XCTAssertEqual(interruption?.category, .routeChange)
        XCTAssertEqual(interruption?.contextValue(for: "reason"), String(AVAudioSession.InterruptionReason.routeDisconnected.rawValue))
        XCTAssertEqual(interruption?.contextValue(for: "notification"), "AudioSessionInterruption")
    }

    func testFromNotificationEndedParsesOptions() {
        let options = AVAudioSession.InterruptionOptions.shouldResume
        let userInfo: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
            AVAudioSessionInterruptionOptionKey: options.rawValue,
        ]

        let notification = Notification(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: userInfo
        )

        let interruption = AudioSessionInterruption.from(notification: notification)

        XCTAssertNotNil(interruption)
        XCTAssertEqual(interruption?.type, .ended)
        XCTAssertTrue(interruption?.shouldResume ?? false)
        XCTAssertEqual(interruption?.contextValue(for: "options"), String(options.rawValue))
        XCTAssertFalse(interruption?.suggestsManualResume ?? true)
        XCTAssertEqual(interruption?.recommendedAction, .resume)
    }

    func testSuggestsManualResumeAndDescriptions() {
        let manual = AudioSessionInterruption(
            type: .ended,
            shouldResume: false,
            timestamp: Date().addingTimeInterval(-10),
            category: .siri
        )

        XCTAssertTrue(manual.suggestsManualResume)
        XCTAssertTrue(manual.userDescription.contains("tap to resume"))

        let auto = AudioSessionInterruption(
            type: .ended,
            shouldResume: true,
            category: .alarm
        )

        XCTAssertFalse(auto.suggestsManualResume)
        XCTAssertTrue(auto.userDescription.contains("resume automatically"))

        let began = AudioSessionInterruption(
            type: .began,
            shouldResume: false,
            category: .phoneCall,
            context: ["call": "incoming"]
        )

        XCTAssertEqual(began.recommendedAction, .pause)
        XCTAssertTrue(began.userDescription.contains("phone call"))
        XCTAssertTrue(began.isRecent)
    }

    func testInterruptionCategoryMappings() {
        let mapping: [(AVAudioSession.InterruptionReason, InterruptionCategory)] = [
            (.default, .unknown),
            (.builtInMicMuted, .systemSound),
            (.routeDisconnected, .routeChange),
        ]

        for (reason, expected) in mapping {
            XCTAssertEqual(InterruptionCategory.from(reason: reason), expected)
        }

        if let suspendedReason = AVAudioSession.InterruptionReason(rawValue: 1), suspendedReason != .default {
            XCTAssertEqual(InterruptionCategory.from(reason: suspendedReason), .otherApp)
        }

        XCTAssertEqual(InterruptionCategory.phoneCall.priority, .high)
        XCTAssertEqual(InterruptionCategory.notification.priority, .low)
        XCTAssertEqual(InterruptionPriority.high.emoji, "🚨")
    }
}
