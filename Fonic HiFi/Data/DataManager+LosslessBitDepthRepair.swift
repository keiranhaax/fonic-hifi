//
//  DataManager+LosslessBitDepthRepair.swift
//  Fonic HiFi
//

import Foundation

@MainActor
extension DataManager {
    static let losslessBitDepthRepairDefaultsKey = "library.losslessSourceBitDepthRepair.v1.completed"

    func repairLosslessSourceBitDepthsIfNeeded(
        formatDetector overrideDetector: (any FormatDetectionService)? = nil
    ) async {
        guard mutationPolicy == .normal,
              !UserDefaults.standard.bool(forKey: Self.losslessBitDepthRepairDefaultsKey) else {
            return
        }

        let batchSize = 100
        let detector = overrideDetector ?? AudioFormatDetectionManager()
        var seenTrackIDs = Set<UUID>()
        var failedTrackCount = 0
        var updatedTrackCount = 0

        do {
            while !Task.isCancelled {
                let page = try await trackDataActor.losslessBitDepthRepairCandidates(
                    limit: batchSize,
                    excluding: seenTrackIDs
                )
                guard !page.isEmpty else { break }
                let isFinalPage = page.count < batchSize
                var updates: [LosslessBitDepthRepairUpdate] = []
                updates.reserveCapacity(page.count)

                for candidate in page {
                    guard seenTrackIDs.insert(candidate.trackID).inserted else { continue }
                    do {
                        try Task.checkCancellation()
                        let info = try await detector.detectFormat(at: candidate.url)
                        guard info.format == .flac || info.format == .alac else { continue }
                        updates.append(
                            LosslessBitDepthRepairUpdate(
                                trackID: candidate.trackID,
                                bitDepth: Int(info.bitDepth)
                            )
                        )
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        failedTrackCount += 1
                        logger.warning(
                            "Lossless source-depth repair skipped a track: \(error.localizedDescription, privacy: .private)"
                        )
                    }
                }

                if !updates.isEmpty {
                    updatedTrackCount += try await trackDataActor.repairLosslessBitDepths(updates)
                }
                if isFinalPage { break }
            }

            guard !Task.isCancelled, failedTrackCount == 0 else {
                logger.notice("Lossless source-depth repair remains pending after an incomplete scan")
                return
            }

            if updatedTrackCount > 0 {
                invalidateLibrary()
            }
            UserDefaults.standard.set(true, forKey: Self.losslessBitDepthRepairDefaultsKey)
            logger.info(
                "Lossless source-depth repair complete scanned=\(seenTrackIDs.count, privacy: .public) updated=\(updatedTrackCount, privacy: .public)"
            )
        } catch is CancellationError {
            logger.notice("Lossless source-depth repair cancelled; it will retry later")
        } catch {
            logger.error("Lossless source-depth repair failed: \(error.localizedDescription, privacy: .private)")
        }
    }
}
