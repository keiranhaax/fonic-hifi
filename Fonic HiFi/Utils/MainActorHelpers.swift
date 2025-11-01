//
//  MainActorHelpers.swift
//  Fonic HiFi
//
//  Debug helpers for MainActor verification
//

import Foundation

private let mainActorLogger = Log.logger(.diagnostics)

extension MainActor {
    /// Asserts that we are isolated to the MainActor in debug builds
    static func assertIsolated(function: String = #function, file: String = #file, line: Int = #line) {
        #if DEBUG
            dispatchPrecondition(condition: .onQueue(.main))
            mainActorLogger.debug("[MainActor] ✓ Verified isolation in \(function, privacy: .public)")
            mainActorLogger.debug("Location: \(file, privacy: .public):\(line, privacy: .public)")
        #endif
    }

    /// Logs current execution context
    static func logContext(message: String, function: String = #function) {
        #if DEBUG
            mainActorLogger.debug("[MainActor] \(message, privacy: .public) in \(function, privacy: .public)")
            let queueLabel = String(cString: __dispatch_queue_get_label(nil))
            mainActorLogger.debug("Queue: \(queueLabel, privacy: .public)")
        #endif
    }
}

/// Global helper to check if we're on main thread before entering async context
func debugLogThreadContext(_ message: String, function: String = #function) {
    #if DEBUG
        mainActorLogger.debug("\n[\(function, privacy: .public)] \(message, privacy: .public)")
        mainActorLogger.debug("Main thread: \(Thread.isMainThread, privacy: .public)")
        let queueLabel = String(cString: __dispatch_queue_get_label(nil))
        mainActorLogger.debug("Queue: \(queueLabel, privacy: .public)")
    #endif
}
