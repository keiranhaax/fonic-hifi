//
//  ABLoopState.swift
//  Fonic HiFi
//
//  A-B loop state for section repeat playback.
//

import Foundation

struct ABLoopState: Sendable, Equatable {
    var isEnabled: Bool = false
    var pointA: TimeInterval?
    var pointB: TimeInterval?

    var isComplete: Bool {
        pointA != nil && pointB != nil
    }

    var isValid: Bool {
        guard let a = pointA, let b = pointB else { return false }
        return b > a
    }

    mutating func clear() {
        isEnabled = false
        pointA = nil
        pointB = nil
    }
}
