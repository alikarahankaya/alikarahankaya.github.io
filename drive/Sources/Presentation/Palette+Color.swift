import SwiftUI

public extension PaletteColor {
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}

public extension Palette {
    var groundColor: Color { ground.color }
    var inkColor: Color { ink.color }
    var neutralColor: Color { neutral.color }
    var textureColor: Color { texture.color }
}
