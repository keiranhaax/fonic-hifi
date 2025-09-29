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

    func start(pollInterval: TimeInterval = 0.2, update: @escaping @MainActor () async -> Void) {
        task?.cancel()
        task = Task { @MainActor [pollInterval] in
            let interval = UInt64(pollInterval * 1_000_000_000)

            while !Task.isCancelled {
                await update()
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
