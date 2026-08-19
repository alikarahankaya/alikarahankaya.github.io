import SwiftUI

public extension PaletteColor {
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}

public extension Palette {
    var groundColor: Color { ground.color }
    var inkColor: Color { ink.color }
    var signalColor: Color { signal.color }
    var neutralColor: Color { neutral.color }

    /// Light text on a dark ground wants a lighter status bar behind it.
    var colorScheme: ColorScheme {
        switch surface {
        case .paper: .light
        case .night: .dark
        }
    }
}
