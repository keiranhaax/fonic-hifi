import Foundation

/// Utility helpers for redacting or truncating information before it is
/// emitted to logs or metrics metadata. Returned fragments are still user
/// content and must remain private when interpolated into logs or metadata.
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
