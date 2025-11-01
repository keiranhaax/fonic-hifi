import Foundation

/// Utility helpers for redacting or truncating information before it is
/// emitted to logs or metrics metadata. Only surface non-sensitive fragments
/// such as filenames instead of full paths when reporting on file activity.
enum LogPrivacy {
    static func filename(_ url: URL) -> String {
        url.lastPathComponent
    }

    static func filename(_ path: String) -> String {
        (path as NSString).lastPathComponent
    }

    static func truncated(_ value: String, limit: Int = 80) -> String {
        guard value.count > limit else { return value }
        let endIndex = value.index(value.startIndex, offsetBy: limit)
        return String(value[..<endIndex]) + "…"
    }
}
