//
//  AudioMetrics.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import Foundation

/// Performance metrics for audio playback monitoring
public struct AudioMetrics: Sendable {
    /// CPU usage percentage (0-100)
    public let cpuUsage: Float
    
    /// Memory usage in bytes
    public let memoryUsage: Int64
    
    /// Number of buffer underruns since playback started
    public let bufferUnderruns: Int
    
    /// Average decoding latency in seconds
    public let decodingLatency: TimeInterval
    
    /// Current buffer fill level (0.0-1.0)
    public let bufferFillLevel: Float
    
    /// Number of frames dropped
    public let droppedFrames: Int
    
    /// Audio render latency in seconds
    public let renderLatency: TimeInterval
    
    /// Timestamp when metrics were captured
    public let timestamp: Date
    
    public init(
        cpuUsage: Float,
        memoryUsage: Int64,
        bufferUnderruns: Int,
        decodingLatency: TimeInterval,
        bufferFillLevel: Float,
        droppedFrames: Int,
        renderLatency: TimeInterval,
        timestamp: Date = Date()
    ) {
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.bufferUnderruns = bufferUnderruns
        self.decodingLatency = decodingLatency
        self.bufferFillLevel = bufferFillLevel
        self.droppedFrames = droppedFrames
        self.renderLatency = renderLatency
        self.timestamp = timestamp
    }
    
    /// Empty metrics for initial state
    public static var empty: AudioMetrics {
        return AudioMetrics(
            cpuUsage: 0,
            memoryUsage: 0,
            bufferUnderruns: 0,
            decodingLatency: 0,
            bufferFillLevel: 1.0,
            droppedFrames: 0,
            renderLatency: 0
        )
    }
    
    /// Indicates if playback performance is healthy
    public var isHealthy: Bool {
        return bufferUnderruns == 0 && 
               droppedFrames == 0 && 
               bufferFillLevel > 0.5 &&
               cpuUsage < 80
    }
    
    /// Human-readable memory usage
    public var formattedMemoryUsage: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: memoryUsage)
    }
}