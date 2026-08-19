import Foundation

/// An sRGB colour, held as plain numbers so contrast can be checked in a test
/// without importing SwiftUI or rendering anything.
public struct PaletteColor: Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// `amount` of `other` blended in, in sRGB space.
    public func mixed(with other: PaletteColor, amount: Double) -> PaletteColor {
        let a = min(1, max(0, amount))
        return PaletteColor(
            red: red * (1 - a) + other.red * a,
            green: green * (1 - a) + other.green * a,
            blue: blue * (1 - a) + other.blue * a
        )
    }

    /// WCAG relative luminance.
    public var relativeLuminance: Double {
        func channel(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// WCAG contrast ratio, 1...21.
    public func contrastRatio(against other: PaletteColor) -> Double {
        let a = relativeLuminance
        let b = other.relativeLuminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

/// White, or near-black. Which one depends on whether the sun is up.
///
/// Two surfaces rather than six: a white ground by day, and its inverse at
/// night, where a white screen in a dark car is glare rather than design.
public enum Surface: Sendable, Equatable {
    case paper
    case night
}

/// White and orange.
///
/// One identity, four roles, and the light of the drive to modulate them:
///
/// - **ground** — white, or near-black after dark. Tinted a degree or two by
///   the light, never coloured by it.
/// - **ink** — type. One per surface, and deep enough to clear 7:1.
/// - **signal** — the orange. Every line in the app: the trace, the rhythm
///   strip, the live ribbon. Nothing else is ever coloured.
/// - **neutral** — secondary type, derived from the ink rather than picked.
///
/// The orange has to be a deep ember to carry type at 7:1 and a vivid one to
/// carry a line, so those are two weights of one hue rather than two colours.
/// `PaletteTests` proves every ratio instead of trusting the eye.
public enum Palette: String, Sendable, CaseIterable, Codable {
    case night
    case dawn
    case morning
    case day
    case golden
    case dusk

    public var surface: Surface {
        switch self {
        case .night, .dawn, .dusk: .night
        case .morning, .day, .golden: .paper
        }
    }

    /// The paper. Warmer or cooler by an amount you would only notice with
    /// two drives side by side, which is exactly where it should be noticed.
    public var ground: PaletteColor {
        switch self {
        case .morning: PaletteColor(hex: 0xF7F8F9)  // cool white
        case .day: PaletteColor(hex: 0xFBFAF7)      // warm white
        case .golden: PaletteColor(hex: 0xFDF6EA)   // white, gone amber
        case .dawn: PaletteColor(hex: 0x12100F)
        case .dusk: PaletteColor(hex: 0x14100E)
        case .night: PaletteColor(hex: 0x0C0B0A)
        }
    }

    /// Type. Deep burnt orange on paper, warm apricot at night: still the
    /// same hue, turned around.
    public var ink: PaletteColor {
        switch surface {
        case .paper: PaletteColor(hex: 0x6E2C05)
        case .night: PaletteColor(hex: 0xFFC79E)
        }
    }

    /// The line. Vivid, and the only colour in the app that is allowed to be.
    public var signal: PaletteColor {
        switch self {
        case .morning: PaletteColor(hex: 0xCC5410)
        case .day: PaletteColor(hex: 0xD9590A)
        case .golden: PaletteColor(hex: 0xC85206)
        case .dawn: PaletteColor(hex: 0xFF8A4D)
        case .dusk: PaletteColor(hex: 0xFF7A33)
        case .night: PaletteColor(hex: 0xFF6A1F)
        }
    }

    /// Secondary type: the ink, three quarters of the way back to the ground.
    /// One rule instead of six more colours, and it clears 4.5:1 on every
    /// ground — which no single fixed grey can do across white and black.
    public var neutral: PaletteColor { ink.mixed(with: ground, amount: 0.75) }
}
