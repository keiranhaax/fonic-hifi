import SwiftUI

enum DesignTokens {
    enum Grid {
        static let adaptiveMinimum: CGFloat = 150
        static let adaptiveMaximum: CGFloat = 200
        static let spacing: CGFloat = 16
    }

    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }

    enum Animation {
        static let springResponse: Double = 0.5
        static let springDamping: Double = 0.85
        static let collapseSpringResponse: Double = 0.4
        static let collapseSpringDamping: Double = 0.9
        static let quickFadeDuration: Double = 0.25
        static let standardFadeDuration: Double = 0.3
    }

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
        static let section: CGFloat = 32
        static let horizontal: CGFloat = 12
        static let vertical: CGFloat = 16
    }
}
