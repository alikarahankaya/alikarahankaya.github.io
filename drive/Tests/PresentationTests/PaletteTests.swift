import Testing
import Foundation
import Analysis
@testable import Presentation

@Suite("Palette")
struct PaletteTests {
    /// The brief asks for 7:1 and says to check rather than assume. Checked.
    @Test("Ink on ground clears 7:1 in every light", arguments: Palette.allCases)
    func inkContrast(palette: Palette) {
        #expect(palette.ink.contrastRatio(against: palette.ground) >= 7)
    }

    /// Secondary type is smaller, so it is held to the ordinary text floor.
    /// A single fixed grey cannot clear this on both a near-black and a
    /// near-white ground, which is why the neutral is derived from the ink.
    @Test("Secondary type clears 4.5:1 in every light", arguments: Palette.allCases)
    func neutralContrast(palette: Palette) {
        #expect(palette.neutral.contrastRatio(against: palette.ground) >= 4.5)
    }

    /// The rhythm strip is texture, not text, and is allowed to be quieter —
    /// but it still has to be visible.
    @Test("The rhythm strip stays visible", arguments: Palette.allCases)
    func textureContrast(palette: Palette) {
        #expect(palette.texture.contrastRatio(against: palette.ground) >= 3)
    }

    @Test("Every light has its own ground")
    func groundsAreDistinct() {
        let grounds = Palette.allCases.map(\.ground)
        for (i, a) in grounds.enumerated() {
            for b in grounds[(i + 1)...] {
                #expect(a.contrastRatio(against: b) > 1.05)
            }
        }
    }

    @Test("Each light picks its own palette")
    func lightMapping() {
        #expect(Palette(Light.dusk) == .dusk)
        #expect(Palette(Light.night) == .night)
        #expect(Light.allCases.map(Palette.init).count == Set(Light.allCases.map(Palette.init)).count)
    }

    @Test("Contrast maths agrees with the published figures")
    func contrastReference() {
        let black = PaletteColor(hex: 0x000000)
        let white = PaletteColor(hex: 0xFFFFFF)
        #expect(abs(black.contrastRatio(against: white) - 21) < 0.01)
        #expect(abs(white.contrastRatio(against: white) - 1) < 0.01)
    }
}
