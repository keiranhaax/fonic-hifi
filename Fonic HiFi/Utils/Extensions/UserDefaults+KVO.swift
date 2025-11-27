//
//  UserDefaults+KVO.swift
//  Fonic HiFi
//
//  Created by Claude on 11/27/25.
//

import Foundation

extension UserDefaults {
    /// Expose preferredAudioEngine for KVO observation.
    /// This allows using \.preferredAudioEngine key path with observe().
    @objc dynamic var preferredAudioEngine: String? {
        string(forKey: "preferredAudioEngine")
    }
}
