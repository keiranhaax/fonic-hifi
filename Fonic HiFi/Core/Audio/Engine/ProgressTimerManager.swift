//
//  ProgressTimerManager.swift
//  Fonic HiFi
//
//  Created by Claude on 5/29/25.
//

import Foundation

/// Manages the progress timer for AudioEngineFacade
@MainActor
final class ProgressTimerManager {
    private var timer: Timer?
    
    func start(interval: TimeInterval = 0.1, handler: @escaping @MainActor () -> Void) {
        stop()
        
        // Execute immediately
        handler()
        
        // Start timer
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                handler()
            }
        }
    }
    
    @MainActor
    func stop() {
        timer?.invalidate()
        timer = nil
    }
}