//
//  RecentSearch.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Foundation
import SwiftData

/// Model for storing recent search queries in the app
@Model
public final class RecentSearch {
    /// The search query string
    var query: String

    /// When the search was performed
    var timestamp: Date

    /// Number of results returned (optional tracking)
    var resultCount: Int

    /// Initialize a new recent search entry
    init(query: String, timestamp: Date = Date(), resultCount: Int = 0) {
        self.query = query
        self.timestamp = timestamp
        self.resultCount = resultCount
    }
}

/// Sendable value type for transferring recent search data across actor boundaries
public struct RecentSearchData: Sendable {
    public let query: String
    public let timestamp: Date
    public let resultCount: Int

    public init(query: String, timestamp: Date, resultCount: Int) {
        self.query = query
        self.timestamp = timestamp
        self.resultCount = resultCount
    }

    public init(from model: RecentSearch) {
        query = model.query
        timestamp = model.timestamp
        resultCount = model.resultCount
    }
}
