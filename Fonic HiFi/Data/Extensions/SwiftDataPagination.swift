//
//  SwiftDataPagination.swift
//  Fonic HiFi
//
//  Created by Claude on 8/14/25.
//  Purpose: Provides pagination support for SwiftData to prevent memory crashes with large libraries
//

import Foundation
import SwiftData

/// Provides pagination support for SwiftData fetch operations
/// This prevents loading entire datasets into memory which causes crashes for users with >5,000 tracks
@MainActor
public struct PaginatedFetchDescriptor<T: PersistentModel> {
    let descriptor: FetchDescriptor<T>
    let pageSize: Int

    /// Initialize a paginated fetch descriptor
    /// - Parameters:
    ///   - descriptor: The base fetch descriptor with predicates and sorting
    ///   - pageSize: Number of items per page (default: 100)
    public init(
        descriptor: FetchDescriptor<T> = FetchDescriptor<T>(),
        pageSize: Int = 100,
    ) {
        self.descriptor = descriptor
        self.pageSize = pageSize
    }

    /// Get a specific page of results
    /// - Parameter pageNumber: Zero-based page number
    /// - Returns: FetchDescriptor configured for the requested page
    public func page(_ pageNumber: Int) -> FetchDescriptor<T> {
        var paginatedDescriptor = descriptor
        paginatedDescriptor.fetchLimit = pageSize
        paginatedDescriptor.fetchOffset = pageNumber * pageSize
        return paginatedDescriptor
    }

    /// Get the total count without loading data
    /// - Parameter context: The model context to query
    /// - Returns: Total count of items matching the descriptor
    public func count(in context: ModelContext) throws -> Int {
        var countDescriptor = descriptor
        countDescriptor.fetchLimit = nil
        countDescriptor.fetchOffset = nil
        return try context.fetchCount(countDescriptor)
    }
}

/// Helper for batch processing large datasets
@MainActor
public struct BatchProcessor<T: PersistentModel> {
    let context: ModelContext
    let batchSize: Int

    public init(context: ModelContext, batchSize: Int = 100) {
        self.context = context
        self.batchSize = batchSize
    }

    /// Process items in batches to avoid memory spikes
    /// - Parameters:
    ///   - descriptor: The fetch descriptor for items to process
    ///   - processor: Closure to process each batch
    @MainActor
    public func processBatches(
        descriptor: FetchDescriptor<T>,
        processor: ([T]) throws -> Void,
    ) throws {
        let paginator = PaginatedFetchDescriptor(descriptor: descriptor, pageSize: batchSize)
        let totalCount = try paginator.count(in: context)
        let pageCount = (totalCount + batchSize - 1) / batchSize

        for pageNumber in 0 ..< pageCount {
            let pageDescriptor = paginator.page(pageNumber)
            let batch = try context.fetch(pageDescriptor)
            try processor(batch)
        }
    }
}
