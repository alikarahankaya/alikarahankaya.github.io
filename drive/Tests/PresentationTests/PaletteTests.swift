import Testing
import Foundation
import Analysis
@testable import Presentation

@Suite("Palette")
struct PaletteTests {
    /// Type has to clear 7:1, as the brief asks — checked rather than assumed.
    @Test("Ink on ground clears 7:1 in every light", arguments: Palette.allCases)
    func inkContrast(palette: Palette) {
        #expect(palette.ink.contrastRatio(against: palette.ground) >= 7)
    }

    /// The orange is a line, not a paragraph, so it is held to the 3:1
    /// graphics floor. It cannot reach 7:1 on white and still be orange —
    /// which is why type uses the ember weight instead.
    @Test("The signal orange clears 3:1 in every light", arguments: Palette.allCases)
    func signalContrast(palette: Palette) {
        #expect(palette.signal.contrastRatio(against: palette.ground) >= 3)
    }

    @Test("Secondary type clears 4.5:1 in every light", arguments: Palette.allCases)
    func neutralContrast(palette: Palette) {
        #expect(palette.neutral.contrastRatio(against: palette.ground) >= 4.5)
    }

    /// Two surfaces, and they are genuinely different: a white screen in a
    /// dark car is glare.
    @Test("Day and night are opposite, not adjacent")
    func surfacesInvert() {
        let day = Palette.day
        let night = Palette.night
        #expect(day.surface == .paper)
        #expect(night.surface == .night)
        #expect(day.ground.contrastRatio(against: night.ground) > 15)
    }

    /// Each light gets its own orange, or the library stops sorting itself by
    /// the light it was driven in.
    @Test("Every light has its own orange")
    func signalsAreDistinct() {
        let signals = Palette.allCases.map(\.signal)
        for (i, a) in signals.enumerated() {
            for b in signals[(i + 1)...] {
                #expect(a != b)
            }
        }
    }

    @Test("One ink per surface, not one per light")
    func inkFollowsTheSurface() {
        #expect(Palette.day.ink == Palette.golden.ink)
        #expect(Palette.night.ink == Palette.dusk.ink)
        #expect(Palette.day.ink != Palette.night.ink)
    }

    @Test("Each light picks its own palette")
    func lightMapping() {
        #expect(Palette(Light.dusk) == .dusk)
        #expect(Palette(Light.night) == .night)
        let palettes = Light.allCases.map(Palette.init)
        #expect(palettes.count == Set(palettes).count)
    }

    @Test("Contrast maths agrees with the published figures")
    func contrastReference() {
        let black = PaletteColor(hex: 0x000000)
        let white = PaletteColor(hex: 0xFFFFFF)
        #expect(abs(black.contrastRatio(against: white) - 21) < 0.01)
        #expect(abs(white.contrastRatio(against: white) - 1) < 0.01)
    }
}
