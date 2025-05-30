//
//  MainActorHelpers.swift
//  Fonic HiFi
//
//  Debug helpers for MainActor verification
//

import Foundation

extension MainActor {
    /// Asserts that we are isolated to the MainActor in debug builds
    static func assertIsolated(function: String = #function, file: String = #file, line: Int = #line) {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))
        print("[MainActor] ✓ Verified isolation in \(function) at \(file):\(line)")
        #endif
    }
    
    /// Logs current execution context
    static func logContext(message: String, function: String = #function) {
        #if DEBUG
        print("[MainActor] \(message) in \(function)")
        print("  Queue: \(String(cString: __dispatch_queue_get_label(nil)))")
        #endif
    }
}

/// Global helper to check if we're on main thread before entering async context
func debugLogThreadContext(_ message: String, function: String = #function) {
    #if DEBUG
    print("\n[\(function)] \(message)")
    print("  Main thread: \(Thread.isMainThread)")
    print("  Queue: \(String(cString: __dispatch_queue_get_label(nil)))")
    #endif
}