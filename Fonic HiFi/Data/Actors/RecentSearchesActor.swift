//
//  RecentSearchesActor.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import SwiftData
import Foundation

/// Actor for managing recent searches using @ModelActor pattern
@ModelActor
public actor RecentSearchesActor {
    // @ModelActor provides modelExecutor and modelContainer
    // No need for manual ModelContext - it's provided as modelContext

    /// Add a new search query to recent searches
    public func addSearch(_ query: String) async throws {
        let search = RecentSearch(query: query, timestamp: Date())
        modelContext.insert(search)
        try modelContext.save()

        // Cleanup old searches (keep last 20)
        var descriptor = FetchDescriptor<RecentSearch>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let allSearches = try modelContext.fetch(descriptor)
        if allSearches.count > 20 {
            for search in allSearches.suffix(from: 20) {
                modelContext.delete(search)
            }
            try modelContext.save()
        }
    }

    /// Get recent searches, most recent first
    public func getRecentSearches(limit: Int = 10) async throws -> [RecentSearchData] {
        var descriptor = FetchDescriptor<RecentSearch>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let searches = try modelContext.fetch(descriptor)
        return searches.map { RecentSearchData(from: $0) }
    }

    /// Clear all recent searches
    public func clearAllSearches() async throws {
        var descriptor = FetchDescriptor<RecentSearch>()
        let allSearches = try modelContext.fetch(descriptor)
        for search in allSearches {
            modelContext.delete(search)
        }
        try modelContext.save()
    }

    /// Remove a specific recent search
    public func removeSearch(_ search: RecentSearchData) async throws {
        // Capture values outside the predicate to avoid type mismatch
        let searchQuery = search.query
        let searchTimestamp = search.timestamp

        var descriptor = FetchDescriptor<RecentSearch>(
            predicate: #Predicate<RecentSearch> { candidate in
                candidate.query == searchQuery &&
                candidate.timestamp == searchTimestamp
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let match = try modelContext.fetch(descriptor).first {
            modelContext.delete(match)
            try modelContext.save()
        }
    }

    /// Update the result count for a search query
    public func updateResultCount(for query: String, count: Int) async throws {
        var descriptor = FetchDescriptor<RecentSearch>(
            predicate: #Predicate<RecentSearch> { search in
                search.query == query
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let existingSearch = try modelContext.fetch(descriptor).first {
            existingSearch.resultCount = count
            try modelContext.save()
        }
    }
}
