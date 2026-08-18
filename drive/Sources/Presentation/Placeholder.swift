import SwiftUI

/// Scaffold only: proves the module builds and the palette renders. Replaced
/// by the artifact in phase 4.
struct PalettePreview: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Palette.allCases, id: \.self) { palette in
                Text(palette.rawValue.uppercased())
                    .font(.footnote)
                    .tracking(2)
                    .foregroundStyle(palette.inkColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(palette.groundColor)
            }
        }
    }
}
