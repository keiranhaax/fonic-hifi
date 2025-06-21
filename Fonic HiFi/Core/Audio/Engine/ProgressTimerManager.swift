//
//  ProgressTimerManager.swift
//  Fonic HiFi
//
//  Created by Claude on 5/29/25.
//

import Foundation

/// Handles periodic playback-time updates on the MainActor without mixing queues.
@MainActor
final class ProgressTimerManager {
    private var task: Task<Void, Never>?

    func start(pollInterval: TimeInterval = 0.2, update: @escaping @MainActor () -> Void) {
        task?.cancel()
        task = Task { @MainActor in
            while !Task.isCancelled {
                update()
                // suspend on the MainActor for the interval
                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}