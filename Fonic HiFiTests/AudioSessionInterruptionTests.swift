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

    func testFromInterruptionReasonMapsCategoryAndContext() {
        let interruption = AudioSessionInterruption.from(
            interruptionReason: .routeDisconnected
        )

        XCTAssertEqual(interruption.type, .began)
        XCTAssertEqual(interruption.category, .routeChange)
        XCTAssertEqual(
            interruption.contextValue(for: "reason"),
            String(AVAudioSession.InterruptionReason.routeDisconnected.rawValue)
        )
        XCTAssertEqual(
            interruption.contextValue(for: "notification"),
            "AudioSessionDidBecomeInactive"
        )
    }

    func testFromResumptionRecommendationMapsBothOutcomes() {
        let shouldResume = AudioSessionInterruption.from(
            resumptionRecommendation: .shouldResume
        )
        let shouldNotResume = AudioSessionInterruption.from(
            resumptionRecommendation: .shouldNotResume
        )

        XCTAssertEqual(shouldResume.type, .ended)
        XCTAssertTrue(shouldResume.shouldResume)
        XCTAssertEqual(
            shouldResume.contextValue(for: "recommendation"),
            String(AVAudioSession.ResumptionRecommendation.shouldResume.rawValue)
        )
        XCTAssertFalse(shouldResume.suggestsManualResume)
        XCTAssertEqual(shouldResume.recommendedAction, .resume)
        XCTAssertFalse(shouldNotResume.shouldResume)
        XCTAssertTrue(shouldNotResume.suggestsManualResume)
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
