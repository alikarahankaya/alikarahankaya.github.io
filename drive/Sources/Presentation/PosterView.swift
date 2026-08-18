import SwiftUI
import Analysis

/// The drive as a 3:4 print: trace, rhythm, flow, date, place.
///
/// This is the app's growth mechanism and its only one, so it has to survive
/// being screenshotted, cropped and reposted — which means no chrome, no app
/// name, and nothing that needs the surrounding interface to make sense.
public struct PosterView: View {
    public var drive: DrivePresentation

    public init(drive: DrivePresentation) {
        self.drive = drive
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TraceView(trace: drive.analysis.trace, palette: drive.palette)
                .frame(maxHeight: .infinity)
            RhythmStripView(rhythm: drive.analysis.rhythm, palette: drive.palette)
                .frame(height: 54)
                .padding(.top, 20)
            Text(Formatting.distance(drive.analysis.flowDistance))
                .font(.system(size: 56, design: .serif).monospacedDigit())
                .foregroundStyle(drive.palette.inkColor)
                .padding(.top, 26)
            Text("Longest unbroken sequence")
                .quietLabel(drive.palette)
            HStack(spacing: 16) {
                Text(Formatting.corners(drive.analysis.corners.count))
                Text(Formatting.sinuosity(drive.analysis.sinuosity))
            }
            .font(.system(size: 15).monospacedDigit())
            .foregroundStyle(drive.palette.inkColor)
            .padding(.top, 18)
            Text(footer)
                .font(.system(size: 15))
                .foregroundStyle(drive.palette.neutralColor)
                .padding(.top, 4)
        }
        .padding(44)
        .background(drive.palette.groundColor)
    }

    private var footer: String {
        [
            drive.placeName,
            Formatting.date(drive.startedAt, timeZone: drive.timeZone),
            Formatting.light(drive.analysis.light),
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

#if DEBUG
#Preview("Poster") {
    PosterView(drive: PreviewDrive.sample(light: .golden))
        .frame(width: 480, height: 640)
}
#endif
