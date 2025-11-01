//
//  URL+SourceIdentifier.swift
//  Fonic HiFi
//
//  Created by Droid on 2025-10-07.
//

import CryptoKit
import Foundation

extension URL {
    /// Normalized file-system path used for duplicate detection
    func normalizedLibraryPath() -> String {
        standardizedFileURL.resolvingSymlinksInPath().path.lowercased()
    }

    /// Deterministic hash for the normalized path
    func librarySourceHash() -> String {
        let normalizedPath = normalizedLibraryPath()
        let digest = SHA256.hash(data: Data(normalizedPath.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
