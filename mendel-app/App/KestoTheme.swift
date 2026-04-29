#if !WIDGET_EXTENSION
//
// KestoTheme.swift
// Transitional brand layer for the future KESTO visual system.
//

import SwiftUI

enum KestoTheme {
    enum Colors {
        static let ink = Color(hex: 0x0E0E0C)
        static let paper = Color(hex: 0xF2EDE6)
        static let bone = Color(hex: 0xE4DDD3)
        static let slate = Color(hex: 0x3D3C38)
        static let ember = Color(hex: 0xC8502A)
        static let forest = Color(hex: 0x4A6741)

        static let whiteWarm = Color(hex: 0xFBF8F4)
        static let inkSoft = ink.opacity(0.35)
        static let inkFaint = ink.opacity(0.12)
        static let slateSoft = slate.opacity(0.72)
        static let border = ink.opacity(0.1)
        static let borderSoft = ink.opacity(0.06)
        static let shadow = ink.opacity(0.06)
        static let emberSoft = ember.opacity(0.1)
        static let forestSoft = forest.opacity(0.12)
        static let white = Color.white
    }

    enum Typography {
        static func display(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
            .system(size: size, weight: weight, design: .serif)
        }

        static func ui(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }

        static func mono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }

        static let hero = display(size: 52, weight: .bold)
        static let screenTitle = display(size: 24, weight: .semibold)
        static let sectionTitle = display(size: 20, weight: .semibold)
        static let metric = display(size: 28, weight: .semibold)
        static let body = ui(size: 17, weight: .regular)
        static let bodyStrong = ui(size: 15, weight: .semibold)
        static let detail = ui(size: 14, weight: .regular)
        static let buttonSmall = ui(size: 13, weight: .semibold)
        static let caption = mono(size: 12, weight: .regular)
        static let label = mono(size: 11, weight: .semibold)
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32

        static let screenPadding: CGFloat = xxl
        static let sectionGap: CGFloat = xl
        static let cardPadding: CGFloat = 18
        static let inlinePadding: CGFloat = 14
    }

    enum Radius {
        static let inline: CGFloat = 14
        static let card: CGFloat = 22
        static let pill: CGFloat = 999
    }
}

private extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
#endif
