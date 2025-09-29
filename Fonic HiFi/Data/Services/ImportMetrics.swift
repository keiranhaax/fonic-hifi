//
//  ImportMetrics.swift
//  Fonic HiFi
//
//  Created by Claude on 9/26/25.
//

import Foundation

/// Track import performance metrics
public struct ImportMetrics: Sendable {
    public var totalFiles: Int
    public var successfulImports: Int
    public var failedImports: Int
    public var duplicatesSkipped: Int
    public var averageFileProcessingTime: TimeInterval
    public var totalImportTime: TimeInterval

    public init(
        totalFiles: Int = 0,
        successfulImports: Int = 0,
        failedImports: Int = 0,
        duplicatesSkipped: Int = 0,
        averageFileProcessingTime: TimeInterval = 0,
        totalImportTime: TimeInterval = 0,
    ) {
        self.totalFiles = totalFiles
        self.successfulImports = successfulImports
        self.failedImports = failedImports
        self.duplicatesSkipped = duplicatesSkipped
        self.averageFileProcessingTime = averageFileProcessingTime
        self.totalImportTime = totalImportTime
    }

    /// Calculate the average processing time per file
    public var calculatedAverageTime: TimeInterval {
        guard successfulImports > 0 else { return 0 }
        return totalImportTime / TimeInterval(successfulImports)
    }

    /// Calculate the success rate as a percentage
    public var successRate: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(successfulImports) / Double(totalFiles) * 100
    }

    /// Get a formatted description of the metrics
    public var formattedDescription: String {
        """
        Import Metrics:
        - Total files: \(totalFiles)
        - Successful imports: \(successfulImports)
        - Failed imports: \(failedImports)
        - Duplicates skipped: \(duplicatesSkipped)
        - Average time per file: \(String(format: "%.2f", averageFileProcessingTime))s
        - Total import time: \(String(format: "%.2f", totalImportTime))s
        - Success rate: \(String(format: "%.1f", successRate))%
        """
    }
}
