import SwiftUI
import Analysis

/// The drive as a 3:4 print: the line, the rhythm, one figure, one footer.
///
/// This is the app's growth mechanism and its only one, so it has to survive
/// being screenshotted, cropped and reposted — which means no chrome, no app
/// name, and nothing that needs the surrounding interface to make sense.
public struct PosterView: View {
    public var drive: DrivePresentation

    public init(drive: DrivePresentation) {
        self.drive = drive
    }

    private var palette: Palette { drive.palette }
    private var copy: DriveCopy { DriveCopy(drive) }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TraceView(trace: drive.analysis.trace, palette: palette)
                .frame(maxHeight: .infinity)
            if !drive.analysis.corners.isEmpty {
                RhythmStripView(rhythm: drive.analysis.rhythm, palette: palette)
                    .frame(height: 54)
                    .padding(.top, 20)
            }
            Text(copy.headline.value)
                .font(.system(size: 56, design: .serif).monospacedDigit())
                .foregroundStyle(palette.inkColor)
                .padding(.top, 26)
            Text(copy.headline.label)
                .quietLabel(palette)
            if !copy.secondary.isEmpty {
                Text(copy.secondary.joined(separator: "   "))
                    .font(.system(size: 15).monospacedDigit())
                    .foregroundStyle(palette.inkColor)
                    .padding(.top, 18)
            }
            Text(copy.posterFooter)
                .font(.system(size: 15))
                .foregroundStyle(palette.neutralColor)
                .padding(.top, 4)
        }
        .padding(44)
        .background(palette.groundColor)
    }
}

#if DEBUG
#Preview("Poster") {
    PosterView(drive: PreviewDrive.sample(light: .golden))
        .frame(width: 480, height: 640)
}
#endif
