import SwiftUI

/// Forge design tokens: a dark, athletic, premium palette.
/// All screens draw from these tokens — never ad-hoc colors.
enum Theme {

    // MARK: Backgrounds

    /// Near-black app background.
    static let background = Color(red: 0.043, green: 0.047, blue: 0.055)
    /// Elevated card surface.
    static let surface = Color(red: 0.090, green: 0.098, blue: 0.114)
    /// Higher-elevation surface (sheets, nested cards, inputs).
    static let surfaceElevated = Color(red: 0.129, green: 0.141, blue: 0.161)
    /// Hairline separators.
    static let separator = Color.white.opacity(0.08)

    // MARK: Content

    static let textPrimary = Color(white: 0.96)
    static let textSecondary = Color(white: 0.62)
    static let textTertiary = Color(white: 0.42)

    // MARK: Semantic accents

    /// Primary brand accent — used for strength and key actions.
    static let accent = Color(red: 0.29, green: 0.78, blue: 0.40)
    /// Running & cardio.
    static let running = Color(red: 0.27, green: 0.68, blue: 0.96)
    /// Flexibility & mobility.
    static let flexibility = Color(red: 0.69, green: 0.52, blue: 0.98)
    /// Body & measurements.
    static let body = Color(red: 0.99, green: 0.65, blue: 0.28)
    /// Records & highlights.
    static let gold = Color(red: 0.95, green: 0.78, blue: 0.34)
    /// Destructive actions.
    static let danger = Color(red: 0.94, green: 0.35, blue: 0.36)
    /// Rest / neutral.
    static let neutral = Color(white: 0.55)

    /// Subtle vertical sheen applied to hero cards.
    static let heroGradient = LinearGradient(
        colors: [Color.white.opacity(0.06), Color.white.opacity(0.0)],
        startPoint: .top,
        endPoint: .bottom
    )

    static func accent(for kind: ActivityKind) -> Color {
        switch kind {
        case .strength: return accent
        case .running: return running
        case .frontSplit, .middleSplit, .mobility: return flexibility
        case .recovery: return Color(red: 0.42, green: 0.80, blue: 0.72)
        case .rest: return neutral
        case .custom: return gold
        }
    }

    static func accent(for kind: FlexibilityKind) -> Color {
        flexibility
    }
}

// MARK: - Spacing & radius tokens

enum Spacing {
    /// 4pt — tight intra-element gaps.
    static let xs: CGFloat = 4
    /// 8pt — related elements.
    static let s: CGFloat = 8
    /// 12pt — element groups.
    static let m: CGFloat = 12
    /// 16pt — card padding, screen margins.
    static let l: CGFloat = 16
    /// 24pt — section separation.
    static let xl: CGFloat = 24
    /// 32pt — major breaks.
    static let xxl: CGFloat = 32
}

enum Radius {
    /// Small controls: chips, steppers.
    static let s: CGFloat = 10
    /// Inputs and buttons.
    static let m: CGFloat = 14
    /// Cards.
    static let l: CGFloat = 20
    /// Hero cards & sheets.
    static let xl: CGFloat = 28
}

// MARK: - Typography tokens
// Text styles wrap Dynamic Type styles so accessibility sizes work throughout.

extension Font {
    /// Oversized numerals on hero stats.
    static let forgeHero = Font.system(.largeTitle, design: .rounded, weight: .bold)
    /// Screen titles.
    static let forgeTitle = Font.system(.title2, design: .rounded, weight: .bold)
    /// Card titles.
    static let forgeHeadline = Font.system(.headline, design: .rounded, weight: .semibold)
    /// Emphasized stat values.
    static let forgeStat = Font.system(.title3, design: .rounded, weight: .bold)
    /// Body copy.
    static let forgeBody = Font.system(.body, design: .rounded)
    /// Secondary copy.
    static let forgeSubheadline = Font.system(.subheadline, design: .rounded)
    /// Labels, captions and units.
    static let forgeCaption = Font.system(.caption, design: .rounded, weight: .medium)
    /// Tiny overline section labels.
    static let forgeOverline = Font.system(.caption2, design: .rounded, weight: .semibold)
}

// MARK: - Hex color support (template accents)

extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        var hexString = hex.trimmingCharacters(in: .whitespaces)
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        Scanner(string: hexString).scanHexInt64(&value)
        let r, g, b: Double
        if hexString.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        } else {
            r = 0.29; g = 0.78; b = 0.40
        }
        self.init(red: r, green: g, blue: b)
    }

    /// Preset accent choices for templates.
    static let templatePalette: [String] = [
        "#4AC766", "#45AEF5", "#B085FA", "#FDA647",
        "#F25A5C", "#F3C757", "#39CCB4", "#EC6FB9",
    ]
}
