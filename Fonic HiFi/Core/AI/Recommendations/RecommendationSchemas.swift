// Fonic HiFi/Core/AI/Recommendations/RecommendationSchemas.swift
import Foundation
import FoundationModels

/// Time-based greeting recommendation (e.g., "Good Morning")
@Generable
public struct TimeBasedGreeting: Sendable {
    @Guide(description: "A time-appropriate greeting like 'Good Morning', 'Good Afternoon', 'Good Evening', or 'Late Night'")
    public var greeting: String

    @Guide(description: "Track UUID strings that match the time of day mood", .count(5))
    public var trackIDStrings: [String]

    @Guide(description: "A brief description of the mood or theme")
    public var moodDescription: String

    /// Computed property to get UUIDs from strings
    public var trackIDs: [UUID] {
        trackIDStrings.compactMap { UUID(uuidString: $0) }
    }

    public init(greeting: String, trackIDs: [UUID], moodDescription: String) {
        self.greeting = greeting
        self.trackIDStrings = trackIDs.map { $0.uuidString }
        self.moodDescription = moodDescription
    }
}

/// AI-generated mix definition
@Generable
public struct MixDefinition: Sendable {
    @Guide(description: "A short, catchy name for the mix like 'Chill Vibes' or 'Energy Boost'")
    public var name: String

    @Guide(description: "Track UUID strings for this mix", .count(7))
    public var trackIDStrings: [String]

    @Guide(description: "A brief description of the mix's mood")
    public var moodDescription: String

    /// Computed property to get UUIDs from strings
    public var trackIDs: [UUID] {
        trackIDStrings.compactMap { UUID(uuidString: $0) }
    }

    public init(name: String, trackIDs: [UUID], moodDescription: String) {
        self.name = name
        self.trackIDStrings = trackIDs.map { $0.uuidString }
        self.moodDescription = moodDescription
    }
}

/// Result from "Surprise Me" button
@Generable
public struct SurpriseMixResult: Sendable {
    @Guide(description: "A fun, engaging greeting for the user")
    public var greeting: String

    @Guide(description: "Track UUID strings for the surprise mix", .count(7))
    public var trackIDStrings: [String]

    @Guide(description: "The theme of this surprise mix")
    public var mixTheme: String

    /// Computed property to get UUIDs from strings
    public var trackIDs: [UUID] {
        trackIDStrings.compactMap { UUID(uuidString: $0) }
    }

    public init(greeting: String, trackIDs: [UUID], mixTheme: String) {
        self.greeting = greeting
        self.trackIDStrings = trackIDs.map { $0.uuidString }
        self.mixTheme = mixTheme
    }
}
