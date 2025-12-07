//
//  ABLoopState.swift
//  Fonic HiFi
//
//  A-B loop state for section repeat playback.
//

import Foundation

public struct ABLoopState: Sendable, Equatable {
    public var isEnabled: Bool = false
    public var pointA: TimeInterval?
    public var pointB: TimeInterval?

    public var isComplete: Bool {
        pointA != nil && pointB != nil
    }

    public var isValid: Bool {
        guard let a = pointA, let b = pointB else { return false }
        return b > a
    }

    public mutating func clear() {
        isEnabled = false
        pointA = nil
        pointB = nil
    }

    public init(isEnabled: Bool = false, pointA: TimeInterval? = nil, pointB: TimeInterval? = nil) {
        self.isEnabled = isEnabled
        self.pointA = pointA
        self.pointB = pointB
    }
}
