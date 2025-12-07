// Fonic HiFi/Data/DataManager+SmartSearch.swift
import Foundation

extension DataManager {
    /// Get all data needed for smart search context
    /// - Returns: Tuple with sessions, track IDs, and metadata
    public func getSmartSearchContext() async throws -> (
        sessions: [ListeningSessionData],
        trackIDs: [UUID],
        metadata: [TrackSearchMetadata]
    ) {
        let sessions = try await trackDataActor.getListeningSessions(limit: 50)
        let trackIDs = try await trackDataActor.getAllTrackIDs(limit: 200)
        let metadata = try await trackDataActor.getTrackMetadataForSearch(limit: 100)

        return (sessions, trackIDs, metadata)
    }
}
