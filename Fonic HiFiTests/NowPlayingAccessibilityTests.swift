import SwiftUI
import XCTest

@testable import Fonic_HiFi

@MainActor
final class NowPlayingAccessibilityTests: XCTestCase {
    func testLyricsTransitionAnimationRespectsReduceMotion() {
        XCTAssertNil(NowPlayingContent.lyricsTransitionAnimation(reduceMotion: true))
        XCTAssertNotNil(NowPlayingContent.lyricsTransitionAnimation(reduceMotion: false))
    }
}
