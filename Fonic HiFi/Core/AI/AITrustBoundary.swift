import Foundation

enum GeneratedTrackIDValidator {
    static func validatedTrackIDs(
        from candidateStrings: [String],
        offeredTrackIDs: [UUID],
        limit: Int
    ) -> [UUID] {
        guard limit > 0 else { return [] }

        let offeredTrackIDs = Set(offeredTrackIDs)
        var seenTrackIDs = Set<UUID>()
        var validatedTrackIDs: [UUID] = []
        validatedTrackIDs.reserveCapacity(min(limit, candidateStrings.count))

        for candidateString in candidateStrings {
            guard let trackID = UUID(uuidString: candidateString),
                  offeredTrackIDs.contains(trackID),
                  seenTrackIDs.insert(trackID).inserted
            else {
                continue
            }

            validatedTrackIDs.append(trackID)
            if validatedTrackIDs.count == limit {
                break
            }
        }

        return validatedTrackIDs
    }
}

enum AIUntrustedData {
    enum Kind: String {
        case availableTracks = "available-tracks"
        case listeningHistory = "listening-history"
        case userQuery = "user-query"
    }

    static func section(_ kind: Kind, content: String) -> String {
        """
        <untrusted-data kind="\(kind.rawValue)">
        \(escaped(content))
        </untrusted-data>
        """
    }

    private static func escaped(_ content: String) -> String {
        content
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
