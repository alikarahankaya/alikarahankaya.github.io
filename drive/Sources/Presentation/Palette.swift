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

/// The six lights a drive can be made in, and the two colours each one gives
/// the artifact. A library of drives ends up sorted by the light it was driven
/// in, which is a truer memory than a timestamp.
///
/// Every ink/ground pair clears 7:1 contrast; `PaletteTests` proves it rather
/// than trusting the eye.
public enum Palette: String, Sendable, CaseIterable, Codable {
    case night
    case dawn
    case morning
    case day
    case golden
    case dusk

    /// The paper.
    public var ground: PaletteColor {
        switch self {
        case .night: PaletteColor(hex: 0x0B0C0E)   // near-black
        case .dawn: PaletteColor(hex: 0x1C2430)    // deep blue-grey
        case .morning: PaletteColor(hex: 0xEEF1F4) // cool off-white
        case .day: PaletteColor(hex: 0xF5F1E8)     // warm off-white
        case .golden: PaletteColor(hex: 0xF2E0BC)  // pale amber
        case .dusk: PaletteColor(hex: 0x241D28)    // dark plum-grey
        }
    }

    /// The line, and the headline figure. The only strong colour on screen.
    public var ink: PaletteColor {
        switch self {
        case .night: PaletteColor(hex: 0xD8D2C8)   // pale warm grey
        case .dawn: PaletteColor(hex: 0xE9BFC0)    // soft rose
        case .morning: PaletteColor(hex: 0x2A3440) // slate
        case .day: PaletteColor(hex: 0x14120E)     // near-black
        case .golden: PaletteColor(hex: 0x3A2408)  // dark umber
        case .dusk: PaletteColor(hex: 0xE8CE96)    // pale gold
        }
    }

    /// Secondary type. One rule rather than six more colours: the ink, pulled
    /// 30% back towards the ground. A fixed grey cannot clear 4.5:1 on both a
    /// near-black and a near-white ground; this can, on all six.
    public var neutral: PaletteColor { ink.mixed(with: ground, amount: 0.30) }

    /// The rhythm strip, which wants to read as texture rather than as a
    /// second headline. Half way to the ground.
    public var texture: PaletteColor { ink.mixed(with: ground, amount: 0.50) }
}
