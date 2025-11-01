//
//  PlaybackDiagnosticUtilities.swift
//  Fonic HiFi
//

import Foundation

public extension TrendDirection {
    /// Symbol for trend direction
    var symbol: String {
        switch self {
        case .improving: "↗"
        case .degrading: "↘"
        case .stable: "→"
        case .volatile: "↕"
        }
    }
}

public extension TimeInterval {
    /// Format duration for display
    var formattedDuration: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

public extension DateFormatter {
    /// Formatter for diagnostic timestamps
    static var diagnosticFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }
}
