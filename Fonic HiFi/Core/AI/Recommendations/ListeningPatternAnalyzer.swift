// Fonic HiFi/Core/AI/Recommendations/ListeningPatternAnalyzer.swift
import Foundation

/// Analyzes listening patterns to build context for Foundation Models
public enum ListeningPatternAnalyzer {

    // MARK: - Time Period

    public enum TimePeriod: String, Sendable {
        case morning
        case afternoon
        case evening
        case lateNight

        public var greeting: String {
            switch self {
            case .morning: return "Good Morning"
            case .afternoon: return "Good Afternoon"
            case .evening: return "Good Evening"
            case .lateNight: return "Late Night"
            }
        }

        public var moodHint: String {
            switch self {
            case .morning: return "energizing, uplifting, fresh start"
            case .afternoon: return "focused, productive, steady rhythm"
            case .evening: return "relaxing, mellow, unwinding"
            case .lateNight: return "calm, ambient, introspective"
            }
        }
    }

    /// Determine time period from hour (0-23)
    public static func timePeriod(for hour: Int) -> TimePeriod {
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .lateNight
        }
    }

    /// Get current time period
    public static var currentTimePeriod: TimePeriod {
        let hour = Calendar.current.component(.hour, from: Date())
        return timePeriod(for: hour)
    }

    // MARK: - Context Building

    /// Build a natural language context string from listening sessions
    public static func buildContext(from sessions: [ListeningSessionData]) -> String {
        guard !sessions.isEmpty else {
            return "No listening history available yet."
        }

        // Analyze time patterns
        let morningCount = sessions.filter { (5..<12).contains($0.hourOfDay) }.count
        let afternoonCount = sessions.filter { (12..<17).contains($0.hourOfDay) }.count
        let eveningCount = sessions.filter { (17..<21).contains($0.hourOfDay) }.count
        let nightCount = sessions.filter { !(5..<21).contains($0.hourOfDay) }.count

        // Analyze completion patterns
        let completedCount = sessions.filter { $0.wasCompleted }.count
        let skippedCount = sessions.filter { $0.wasSkipped }.count
        let avgCompletion = sessions.map(\.completionPercentage).reduce(0, +) / Double(sessions.count)

        // Analyze day patterns
        let weekdayCount = sessions.filter { (2...6).contains($0.dayOfWeek) }.count
        let weekendCount = sessions.count - weekdayCount

        var context = "User listening patterns:\n"
        context += "- Prefers \(dominantTimePeriod(morning: morningCount, afternoon: afternoonCount, evening: eveningCount, night: nightCount)) listening\n"
        context += "- Average completion: \(Int(avgCompletion * 100))%\n"
        context += "- Completed \(completedCount) tracks, skipped \(skippedCount)\n"
        context += "- \(weekdayCount > weekendCount ? "Mostly weekday" : "Mostly weekend") listener\n"

        return context
    }

    private static func dominantTimePeriod(morning: Int, afternoon: Int, evening: Int, night: Int) -> String {
        let max = max(morning, afternoon, evening, night)
        switch max {
        case morning: return "morning"
        case afternoon: return "afternoon"
        case evening: return "evening"
        default: return "late night"
        }
    }

    // MARK: - Track Context

    /// Build context about available tracks for the model
    public static func buildTrackContext(
        trackIDs: [UUID],
        genres: [String],
        recentlyPlayed: [UUID]
    ) -> String {
        var context = "Available library:\n"
        context += "- \(trackIDs.count) tracks available\n"
        context += "- Genres: \(genres.prefix(5).joined(separator: ", "))\n"
        context += "- Recently played: \(recentlyPlayed.count) tracks\n"
        context += "- Track UUIDs to choose from: \(trackIDs.prefix(20).map { $0.uuidString }.joined(separator: ", "))\n"
        return context
    }
}
