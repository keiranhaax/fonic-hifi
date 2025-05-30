//
//  AudioSessionInterruption.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/2025.
//

import Foundation
import AVFoundation

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
        context: [String: String] = [:]
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
        context: [String: String] = [:]
    ) -> AudioSessionInterruption {
        return AudioSessionInterruption(
            type: .began,
            shouldResume: false,
            category: category,
            context: context
        )
    }
    
    /// Create interruption for when interruption ends
    public static func ended(
        shouldResume: Bool,
        category: InterruptionCategory? = nil,
        context: [String: String] = [:]
    ) -> AudioSessionInterruption {
        return AudioSessionInterruption(
            type: .ended,
            shouldResume: shouldResume,
            category: category,
            context: context
        )
    }
    
    /// Create interruption from AVAudioSession notification
    public static func from(notification: Notification) -> AudioSessionInterruption? {
        guard notification.name == AVAudioSession.interruptionNotification,
              let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return nil
        }
        
        let type: InterruptionType
        var shouldResume = false
        var category: InterruptionCategory?
        var context: [String: String] = [:]
        
        switch interruptionType {
        case .began:
            type = .began
            
            // Extract interruption category if available
            if let reasonValue = userInfo[AVAudioSessionInterruptionReasonKey] as? UInt,
               let reason = AVAudioSession.InterruptionReason(rawValue: reasonValue) {
                category = InterruptionCategory.from(reason: reason)
                context["reason"] = String(reason.rawValue)
            }
            
        case .ended:
            type = .ended
            
            // Check if we should resume
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                shouldResume = options.contains(.shouldResume)
                context["options"] = String(optionsValue)
            }
            
        @unknown default:
            return nil
        }
        
        // Add any additional context
        context["notification"] = "AudioSessionInterruption"
        
        return AudioSessionInterruption(
            type: type,
            shouldResume: shouldResume,
            category: category,
            context: context
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
            return "Interruption Began"
        case .ended:
            return "Interruption Ended"
        }
    }
    
    /// Whether this interruption type typically requires user action
    public var requiresUserAction: Bool {
        switch self {
        case .began:
            return false // System handles stopping
        case .ended:
            return true // User may need to resume
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
        return rawValue
    }
    
    /// User-friendly explanation of the interruption
    public var explanation: String {
        switch self {
        case .phoneCall:
            return "An incoming or outgoing phone call interrupted audio playback"
        case .alarm:
            return "A system alarm or timer interrupted audio playback"
        case .notification:
            return "A notification sound interrupted audio playback"
        case .siri:
            return "Siri activation interrupted audio playback"
        case .otherApp:
            return "Another app requested audio focus"
        case .systemSound:
            return "A system sound interrupted audio playback"
        case .routeChange:
            return "The audio route changed (headphones disconnected, etc.)"
        case .unknown:
            return "An unknown event interrupted audio playback"
        }
    }
    
    /// Priority level of this interruption type
    public var priority: InterruptionPriority {
        switch self {
        case .phoneCall:
            return .high
        case .alarm:
            return .high
        case .siri:
            return .medium
        case .notification, .systemSound:
            return .low
        case .otherApp:
            return .medium
        case .routeChange:
            return .medium
        case .unknown:
            return .low
        }
    }
    
    /// Whether this interruption should typically allow auto-resume
    public var allowsAutoResume: Bool {
        switch self {
        case .phoneCall:
            return false // User should manually resume after call
        case .alarm:
            return true // Can resume after alarm
        case .notification, .systemSound:
            return true // Brief interruptions
        case .siri:
            return false // User interaction required
        case .otherApp:
            return false // Depends on user intent
        case .routeChange:
            return true // Technical change, can resume
        case .unknown:
            return false // Conservative approach
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
            return "Low Priority"
        case .medium:
            return "Medium Priority"
        case .high:
            return "High Priority"
        }
    }
    
    /// Emoji representation
    public var emoji: String {
        switch self {
        case .low:
            return "🔔"
        case .medium:
            return "⚠️"
        case .high:
            return "🚨"
        }
    }
}

// MARK: - Extensions

extension AudioSessionInterruption {
    /// Duration since the interruption occurred
    public var timeSinceInterruption: TimeInterval {
        return Date().timeIntervalSince(timestamp)
    }
    
    /// Whether this interruption is recent (within last 5 seconds)
    public var isRecent: Bool {
        return timeSinceInterruption < 5.0
    }
    
    /// User-friendly description of the interruption
    public var userDescription: String {
        let _ = type.description
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
    public var debugDescription: String {
        var components = [
            "Type: \(type.description)",
            "Should Resume: \(shouldResume)",
            "Timestamp: \(timestamp)"
        ]
        
        if let category = category {
            components.append("Category: \(category.rawValue)")
        }
        
        if !context.isEmpty {
            components.append("Context: \(context.keys.joined(separator: ", "))")
        }
        
        return "AudioSessionInterruption(\(components.joined(separator: ", ")))"
    }
    
    /// Extract specific context values
    public func contextValue<T>(for key: String) -> T? {
        return context[key] as? T
    }
    
    /// Whether this interruption suggests the user should manually resume
    public var suggestsManualResume: Bool {
        guard type == .ended else { return false }
        
        if let category = category {
            return !category.allowsAutoResume
        }
        
        return !shouldResume
    }
    
    /// Recommended action for handling this interruption
    public var recommendedAction: InterruptionAction {
        switch type {
        case .began:
            return .pause
        case .ended:
            if shouldResume && category?.allowsAutoResume != false {
                return .resume
            } else {
                return .waitForUserAction
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
            return "Pause playback"
        case .resume:
            return "Resume playback"
        case .waitForUserAction:
            return "Wait for user to resume"
        case .stop:
            return "Stop playback"
        }
    }
}

// MARK: - Equatable Conformance

extension AudioSessionInterruption {
    public static func == (lhs: AudioSessionInterruption, rhs: AudioSessionInterruption) -> Bool {
        return lhs.type == rhs.type &&
               lhs.shouldResume == rhs.shouldResume &&
               lhs.timestamp == rhs.timestamp &&
               lhs.category == rhs.category
        // Note: context comparison omitted due to [String: Any] not being Equatable
    }
}