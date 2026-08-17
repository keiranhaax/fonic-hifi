//
//  TrackDataActor+LosslessBitDepthRepair.swift
//  Fonic HiFi
//

import Foundation
import SwiftData

struct LosslessBitDepthRepairCandidate: Sendable {
    let trackID: UUID
    let url: URL
}

struct LosslessBitDepthRepairUpdate: Sendable {
    let trackID: UUID
    let bitDepth: Int
}

extension TrackDataActor {
    func losslessBitDepthRepairCandidates(
        limit: Int = 100,
        excluding excludedTrackIDs: Set<UUID> = []
    ) throws -> [LosslessBitDepthRepairCandidate] {
        let effectiveLimit = max(1, limit)
        let pageSize = max(100, effectiveLimit)
        var sourceOffset = 0
        var candidates: [LosslessBitDepthRepairCandidate] = []

        while candidates.count < effectiveLimit {
            var descriptor = FetchDescriptor<Track>(
                sortBy: [SortDescriptor(\Track.dateAdded, order: .forward)]
            )
            descriptor.fetchLimit = pageSize
            descriptor.fetchOffset = sourceOffset

            let page: [Track]
            do {
                page = try modelContext.fetch(descriptor)
            } catch {
                throw TrackDataError.fetchFailed(error)
            }

            guard !page.isEmpty else { break }

            for track in page where isLosslessBitDepthRepairCandidate(track) {
                guard !excludedTrackIDs.contains(track.id) else { continue }
                candidates.append(
                    LosslessBitDepthRepairCandidate(
                        trackID: track.id,
                        url: ManagedMediaURLResolver.resolveAvailableURL(track.url) ?? track.url
                    )
                )
                if candidates.count == effectiveLimit { break }
            }

            sourceOffset += page.count
            if page.count < pageSize { break }
        }

        return candidates
    }

    func repairLosslessBitDepths(_ updates: [LosslessBitDepthRepairUpdate]) throws -> Int {
        try requireMutationAllowed()
        var updatedTracks = 0

        for update in updates {
            try Task.checkCancellation()
            guard (1 ... 32).contains(update.bitDepth),
                  let track = try getTrack(by: update.trackID),
                  isLosslessBitDepthRepairCandidate(track),
                  track.bitDepth != update.bitDepth else {
                continue
            }

            track.bitDepth = update.bitDepth
            updatedTracks += 1
        }

        if modelContext.hasChanges {
            do {
                try modelContext.save()
            } catch {
                throw TrackDataError.saveFailed(error)
            }
        }

        return updatedTracks
    }

    private func isLosslessBitDepthRepairCandidate(_ track: Track) -> Bool {
        let normalizedFormat = track.audioFormat
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalizedFormat == AudioFormat.flac.rawValue ||
            normalizedFormat == AudioFormat.alac.rawValue ||
            normalizedFormat == AudioFormat.flac.displayName.lowercased() ||
            normalizedFormat == AudioFormat.alac.displayName.lowercased() {
            return true
        }

        return track.url.pathExtension.lowercased() == AudioFormat.flac.fileExtension
    }
}
