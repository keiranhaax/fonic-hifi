//
//  UUIDArrayTransformer.swift
//  Fonic HiFi
//
//  Created by Claude on 10/1/25.
//  Secure transformer for UUID arrays in SwiftData models
//

import Foundation

/// Secure transformer for UUID arrays
///
/// SwiftData requires secure transformers for array properties to avoid deprecation warnings.
/// This transformer enables secure coding for UUID arrays used in playlist track ordering.
///
/// Usage:
/// ```swift
/// @Attribute(.transformable(by: "UUIDArrayTransformer"))
/// public var trackIds: [UUID]
/// ```
@objc(UUIDArrayTransformer)
final class UUIDArrayTransformer: NSSecureUnarchiveFromDataTransformer {
    /// Specify allowed classes for secure unarchiving
    override static var allowedTopLevelClasses: [AnyClass] {
        [NSArray.self, NSUUID.self]
    }

    /// Register the transformer with Foundation's ValueTransformer system
    ///
    /// Must be called during app initialization (e.g., in app init or scene delegate)
    /// before any SwiftData models using this transformer are accessed.
    static func register() {
        let transformer = UUIDArrayTransformer()
        ValueTransformer.setValueTransformer(
            transformer,
            forName: NSValueTransformerName("UUIDArrayTransformer")
        )
    }
}
