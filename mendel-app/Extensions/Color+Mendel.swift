#if !WIDGET_EXTENSION
//
// Color+Mendel.swift
// App palette and typography tokens.
//

import SwiftUI

enum MendelColors {
    static let bg = KestoTheme.Colors.paper
    static let white = KestoTheme.Colors.white
    static let ink = KestoTheme.Colors.ink
    static let inkSoft = KestoTheme.Colors.inkSoft
    static let inkFaint = KestoTheme.Colors.inkFaint
    static let stone = KestoTheme.Colors.bone
}

enum MendelType {
    static func stateWord() -> Font { KestoTheme.Typography.hero }
    static func screenTitle() -> Font { KestoTheme.Typography.screenTitle }
    static func sectionTitle() -> Font { KestoTheme.Typography.sectionTitle }
    static func body() -> Font { KestoTheme.Typography.body }
    static func bodyMedium() -> Font { KestoTheme.Typography.bodyStrong }
    static func caption() -> Font { KestoTheme.Typography.caption }
    static func label() -> Font { KestoTheme.Typography.label }
    static func chatText() -> Font { KestoTheme.Typography.body }
}

enum MendelSpacing {
    static let xs: CGFloat = KestoTheme.Spacing.xxs
    static let sm: CGFloat = KestoTheme.Spacing.xs
    static let md: CGFloat = KestoTheme.Spacing.md
    static let lg: CGFloat = KestoTheme.Spacing.xl
    static let xl: CGFloat = KestoTheme.Spacing.screenPadding
    static let xxl: CGFloat = 48
}

enum MendelRadius {
    static let sm: CGFloat = KestoTheme.Radius.inline
    static let md: CGFloat = KestoTheme.Radius.card
    static let lg: CGFloat = 24
    static let pill: CGFloat = KestoTheme.Radius.pill
}
#endif
