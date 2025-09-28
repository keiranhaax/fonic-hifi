import Foundation
import OSLog

enum LogCategory: String {
    case audio
    case audioEngine
    case audioQueue
    case data
    case presentation
    case search
    case ui
    case diagnostics
    case importService
    case app
    case liquidGlass
    case library
    case performance
}

enum Log {
    private static let subsystem = "com.fonichifi"

    static func logger(_ category: LogCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }
}
