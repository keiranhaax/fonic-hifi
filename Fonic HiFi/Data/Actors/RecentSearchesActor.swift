//
//  RecentSearchesActor.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Foundation
import SwiftData

/// Actor for managing recent searches using @ModelActor pattern
@ModelActor
public actor RecentSearchesActor {
    // @ModelActor provides modelExecutor and modelContainer
    // No need for manual ModelContext - it's provided as modelContext

    /// Add a new search query to recent searches
    public func addSearch(_ query: String) async throws {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        let normalizedQuery = normalize(trimmedQuery)
        let descriptor = FetchDescriptor<RecentSearch>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)],
        )
        let matches = try modelContext.fetch(descriptor).filter {
            normalize($0.query) == normalizedQuery
        }

        if let existing = matches.first {
            existing.timestamp = Date()
            for duplicate in matches.dropFirst() {
                modelContext.delete(duplicate)
            }
        } else {
            modelContext.insert(RecentSearch(query: trimmedQuery, timestamp: Date()))
        }
        try modelContext.save()

        // Cleanup old searches (keep last 20)
        let cleanupDescriptor = FetchDescriptor<RecentSearch>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)],
        )
        let allSearches = try modelContext.fetch(cleanupDescriptor)
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
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)],
        )
        descriptor.fetchLimit = limit
        let searches = try modelContext.fetch(descriptor)
        return searches.map { RecentSearchData(from: $0) }
    }

    /// Clear all recent searches
    public func clearAllSearches() async throws {
        let descriptor = FetchDescriptor<RecentSearch>()
        let allSearches = try modelContext.fetch(descriptor)
        for search in allSearches {
            modelContext.delete(search)
        }
        try modelContext.save()
    }

    /// Remove a specific recent search
    public func removeSearch(_ search: RecentSearchData) async throws {
        if let match = modelContext.model(for: search.id) as? RecentSearch {
            modelContext.delete(match)
            try modelContext.save()
        }
    }

    /// Update the result count for a search query
    public func updateResultCount(for query: String, count: Int) async throws {
        let normalizedQuery = normalize(query)
        let descriptor = FetchDescriptor<RecentSearch>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)],
        )

        if let existingSearch = try modelContext.fetch(descriptor).first(where: {
            normalize($0.query) == normalizedQuery
        }) {
            existingSearch.resultCount = count
            try modelContext.save()
        }
    }

    private func normalize(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
