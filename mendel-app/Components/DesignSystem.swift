import SwiftUI

// MARK: - Colors

enum MendelColors {
    static let background  = Color("Background")   // #F8F7F5
    static let surface     = Color("Surface")       // #FFFFFF
    static let primary     = Color("Primary")       // #0F0F0F
    static let secondary   = Color("Secondary")     // rgba(0,0,0,0.35)
    static let tertiary    = Color("Tertiary")      // rgba(0,0,0,0.2)
    static let accent      = Color("Accent")        // #C4A882 (warm stone)
    static let border      = Color("Border")        // rgba(0,0,0,0.08)

    // Fallbacks for previews (use asset catalog in real project)
    static let bg          = Color(red: 0.97, green: 0.97, blue: 0.96)
    static let ink         = Color(red: 0.06, green: 0.06, blue: 0.06)
    static let inkSoft     = Color(red: 0.06, green: 0.06, blue: 0.06).opacity(0.35)
    static let inkFaint    = Color(red: 0.06, green: 0.06, blue: 0.06).opacity(0.12)
    static let stone       = Color(red: 0.77, green: 0.66, blue: 0.51)
    static let white       = Color.white
}

// MARK: - Typography

enum MendelType {
    /// 72pt, weight 800 — the big state word
    static func stateWord() -> Font {
        .system(size: 72, weight: .heavy, design: .default)
    }
    /// 22pt, weight 700
    static func screenTitle() -> Font {
        .system(size: 22, weight: .bold, design: .default)
    }
    /// 17pt, weight 400
    static func body() -> Font {
        .system(size: 17, weight: .regular, design: .default)
    }
    /// 15pt, weight 500
    static func bodyMedium() -> Font {
        .system(size: 15, weight: .medium, design: .default)
    }
    /// 13pt, weight 400
    static func caption() -> Font {
        .system(size: 13, weight: .regular, design: .default)
    }
    /// 11pt, weight 600, spaced — for labels
    static func label() -> Font {
        .system(size: 11, weight: .semibold, design: .default)
    }
    /// 14pt, weight 400
    static func chatText() -> Font {
        .system(size: 14, weight: .regular, design: .default)
    }
}

// MARK: - Spacing

enum MendelSpacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius

enum MendelRadius {
    static let sm:  CGFloat = 10
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let pill: CGFloat = 100
}
