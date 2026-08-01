//
//  AudioSessionInterruption.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/2025.
//

import AVFoundation
import Foundation

/// Represents audio session interruption events and their characteristics
@frozen
public struct AudioSessionInterruption: Sendable, Equatable {
    // MARK: - Core Properties

    /// Type of interruption event
    public let type: InterruptionType

    /// Whether playback should automatically resume when interruption ends
    public let shouldResume: Bool

    /// Timestamp when the interruption occurred
    public let timestamp: Date

    /// Optional category that caused the interruption
    public let category: InterruptionCategory?

    /// Additional context about the interruption
    public let context: [String: String]

    // MARK: - Initialization

    public init(
        type: InterruptionType,
        shouldResume: Bool = false,
        timestamp: Date = Date(),
        category: InterruptionCategory? = nil,
        context: [String: String] = [:],
    ) {
        self.type = type
        self.shouldResume = shouldResume
        self.timestamp = timestamp
        self.category = category
        self.context = context
    }

    // MARK: - Factory Methods

    /// Create interruption for when interruption begins
    public static func began(
        category: InterruptionCategory? = nil,
        context: [String: String] = [:],
    ) -> AudioSessionInterruption {
        AudioSessionInterruption(
            type: .began,
            shouldResume: false,
            category: category,
            context: context,
        )
    }

    /// Create interruption for when interruption ends
    public static func ended(
        shouldResume: Bool,
        category: InterruptionCategory? = nil,
        context: [String: String] = [:],
    ) -> AudioSessionInterruption {
        AudioSessionInterruption(
            type: .ended,
            shouldResume: shouldResume,
            category: category,
            context: context,
        )
    }

    /// Create an interruption from the reason carried by an iOS 27
    /// `DidBecomeInactiveMessage`.
    public static func from(
        interruptionReason reason: AVAudioSession.InterruptionReason
    ) -> AudioSessionInterruption {
        AudioSessionInterruption.began(
            category: InterruptionCategory.from(reason: reason),
            context: [
                "reason": String(reason.rawValue),
                "notification": "AudioSessionDidBecomeInactive",
            ]
        )
    }

    /// Create an interruption-end event from an iOS 27 resumption recommendation.
    public static func from(
        resumptionRecommendation recommendation: AVAudioSession.ResumptionRecommendation
    ) -> AudioSessionInterruption {
        AudioSessionInterruption.ended(
            shouldResume: recommendation == .shouldResume,
            context: [
                "recommendation": String(recommendation.rawValue),
                "notification": "AudioSessionResumptionRecommendation",
            ]
        )
    }
}

// MARK: - Supporting Enums

/// Types of audio session interruptions
public enum InterruptionType: Sendable, Equatable, CaseIterable {
    /// Interruption has begun (audio should stop)
    case began

    /// Interruption has ended (audio may resume)
    case ended

    public var description: String {
        switch self {
        case .began:
            "Interruption Began"
        case .ended:
            "Interruption Ended"
        }
    }

    /// Whether this interruption type typically requires user action
    public var requiresUserAction: Bool {
        switch self {
        case .began:
            false // System handles stopping
        case .ended:
            true // User may need to resume
        }
    }
}

/// Categories of what caused the interruption
public enum InterruptionCategory: String, Sendable, CaseIterable {
    case phoneCall = "Phone Call"
    case alarm = "Alarm"
    case notification = "Notification"
    case siri = "Siri"
    case otherApp = "Other App"
    case systemSound = "System Sound"
    case routeChange = "Route Change"
    case unknown = "Unknown"

    public var description: String {
        rawValue
    }

    /// User-friendly explanation of the interruption
    public var explanation: String {
        switch self {
        case .phoneCall:
            "An incoming or outgoing phone call interrupted audio playback"
        case .alarm:
            "A system alarm or timer interrupted audio playback"
        case .notification:
            "A notification sound interrupted audio playback"
        case .siri:
            "Siri activation interrupted audio playback"
        case .otherApp:
            "Another app requested audio focus"
        case .systemSound:
            "A system sound interrupted audio playback"
        case .routeChange:
            "The audio route changed (headphones disconnected, etc.)"
        case .unknown:
            "An unknown event interrupted audio playback"
        }
    }

    /// Priority level of this interruption type
    public var priority: InterruptionPriority {
        switch self {
        case .phoneCall:
            .high
        case .alarm:
            .high
        case .siri:
            .medium
        case .notification, .systemSound:
            .low
        case .otherApp:
            .medium
        case .routeChange:
            .medium
        case .unknown:
            .low
        }
    }

    /// Whether this interruption should typically allow auto-resume
    public var allowsAutoResume: Bool {
        switch self {
        case .phoneCall:
            false // User should manually resume after call
        case .alarm:
            true // Can resume after alarm
        case .notification, .systemSound:
            true // Brief interruptions
        case .siri:
            false // User interaction required
        case .otherApp:
            false // Depends on user intent
        case .routeChange:
            true // Technical change, can resume
        case .unknown:
            false // Conservative approach
        }
    }

    /// Create category from AVAudioSession interruption reason
    static func from(reason: AVAudioSession.InterruptionReason) -> InterruptionCategory {
        switch reason {
        case .default:
            return .unknown
        case .appWasSuspended:
            return .otherApp
        case .builtInMicMuted:
            return .systemSound
        case .routeDisconnected:
            return .routeChange
        @unknown default:
            return .unknown
        }
    }
}

/// Priority levels for interruptions
public enum InterruptionPriority: Int, Sendable, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3

    public var description: String {
        switch self {
        case .low:
            "Low Priority"
        case .medium:
            "Medium Priority"
        case .high:
            "High Priority"
        }
    }

    /// Emoji representation
    public var emoji: String {
        switch self {
        case .low:
            "🔔"
        case .medium:
            "⚠️"
        case .high:
            "🚨"
        }
    }
}

// MARK: - Extensions

public extension AudioSessionInterruption {
    /// Duration since the interruption occurred
    var timeSinceInterruption: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }

    /// Whether this interruption is recent (within last 5 seconds)
    var isRecent: Bool {
        timeSinceInterruption < 5.0
    }

    /// User-friendly description of the interruption
    var userDescription: String {
        _ = type.description
        let categoryDesc = category?.explanation ?? "An interruption occurred"

        switch type {
        case .began:
            return categoryDesc
        case .ended:
            if shouldResume {
                return "Interruption ended - audio will resume automatically"
            } else {
                return "Interruption ended - tap to resume audio"
            }
        }
    }

    /// Technical description for debugging
    var debugDescription: String {
        var components = [
            "Type: \(type.description)",
            "Should Resume: \(shouldResume)",
            "Timestamp: \(timestamp)",
        ]

        if let category {
            components.append("Category: \(category.rawValue)")
        }

        if !context.isEmpty {
            components.append("Context: \(context.keys.joined(separator: ", "))")
        }

        return "AudioSessionInterruption(\(components.joined(separator: ", ")))"
    }

    /// Extract specific context values
    func contextValue<T>(for key: String) -> T? {
        context[key] as? T
    }

    /// Whether this interruption suggests the user should manually resume
    var suggestsManualResume: Bool {
        guard type == .ended else { return false }

        if let category {
            return !category.allowsAutoResume
        }

        return !shouldResume
    }

    /// Recommended action for handling this interruption
    var recommendedAction: InterruptionAction {
        switch type {
        case .began:
            .pause
        case .ended:
            if shouldResume, category?.allowsAutoResume != false {
                .resume
            } else {
                .waitForUserAction
            }
        }
    }
}

/// Recommended actions for handling interruptions
public enum InterruptionAction: Sendable, CaseIterable {
    case pause
    case resume
    case waitForUserAction
    case stop

    public var description: String {
        switch self {
        case .pause:
            "Pause playback"
        case .resume:
            "Resume playback"
        case .waitForUserAction:
            "Wait for user to resume"
        case .stop:
            "Stop playback"
        }
    }
}

// MARK: - Equatable Conformance

public extension AudioSessionInterruption {
    static func == (lhs: AudioSessionInterruption, rhs: AudioSessionInterruption) -> Bool {
        lhs.type == rhs.type &&
            lhs.shouldResume == rhs.shouldResume &&
            lhs.timestamp == rhs.timestamp &&
            lhs.category == rhs.category
        // Note: context comparison omitted due to [String: Any] not being Equatable
    }
}
