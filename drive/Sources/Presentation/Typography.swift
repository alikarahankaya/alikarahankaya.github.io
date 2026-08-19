import SwiftUI

/// Two roles, and no more than two sizes on screen at once.
///
/// Everything scales with Dynamic Type because the sizes are relative to text
/// styles rather than fixed points. The artifact gets tighter at the largest
/// accessibility sizes; it does not break.
enum Typography {
    /// The one big number. New York, because a single moment of warmth
    /// against otherwise clinical type is worth having — and only here. If it
    /// ever reads as decoration rather than emphasis, cut the `design`
    /// argument and it becomes SF Pro again.
    static func headline(_ size: Font.TextStyle = .largeTitle) -> Font {
        .system(size, design: .serif).monospacedDigit()
    }

    /// Data: numbers that have to line up as they change.
    static let figure: Font = .system(.footnote, design: .default).monospacedDigit()

    /// Labels: small, uppercase, wide tracking, in the shared neutral.
    static let label: Font = .system(.footnote, design: .default)

    /// Tracking for uppercase labels. Uppercase needs the air.
    static let labelTracking: CGFloat = 1.6
}

extension Text {
    /// A label: uppercase, tracked, quiet. Named to stay clear of SwiftUI's
    /// own `labelStyle(_:)`.
    func quietLabel(_ palette: Palette) -> some View {
        textCase(.uppercase)
            .font(Typography.label)
            .tracking(Typography.labelTracking)
            .foregroundStyle(palette.neutralColor)
    }
}
