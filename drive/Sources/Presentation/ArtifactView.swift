import SwiftUI
import Analysis

/// One drive, one screen. This is the product.
///
/// Every element here has to earn its place on this particular drive. A
/// motorway has no rhythm strip, because it has no rhythm; a road that never
/// bends says nothing about sinuosity; a drive whose weather was never
/// fetched does not apologise for it. The layout is the same, the contents
/// are not.
///
/// Flow leads, because it is the number that describes pleasure: how far the
/// road let you keep going without interruption. When there was no such
/// stretch, the headline is simply the distance — a real number instead of a
/// proud zero.
public struct ArtifactView: View {
    public var drive: DrivePresentation

    @State private var progress: Double = 1
    @State private var showsLocation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(drive: DrivePresentation) {
        self.drive = drive
    }

    /// Eight seconds to drive the whole road again: long enough to watch,
    /// short enough that nobody reaches for a scrub bar — which is why there
    /// isn't one.
    private static let replayDuration: Double = 8

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The trace takes whatever the figures do not, which lands near
            // the intended 55% on a phone and stays legible when Dynamic Type
            // asks the figures for three times the room.
            trace
                .frame(maxHeight: .infinity)
            if !drive.analysis.corners.isEmpty {
                rhythm
                    .frame(height: 44)
                    .padding(.top, 24)
            }
            figures
                .padding(.top, 28)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.groundColor)
        .sheet(isPresented: $showsLocation) {
            LocationSheet(drive: drive)
        }
    }

    private var palette: Palette { drive.palette }
    private var copy: DriveCopy { DriveCopy(drive) }

    private var trace: some View {
        TraceView(
            trace: drive.analysis.trace,
            palette: palette,
            progress: progress,
            showsHead: progress < 1
        )
        .contentShape(Rectangle())
        .onTapGesture { replay() }
        // Where the drive was, on a long press. One gesture for the drawing,
        // one for the world behind it, and no visible controls for either.
        .onLongPressGesture { showsLocation = true }
        .accessibilityElement()
        .accessibilityLabel(Formatting.spokenSummary(drive))
        .accessibilityHint("Double tap to replay the drive")
        .accessibilityAction(named: "Show where this drive was") { showsLocation = true }
        .accessibilityAddTraits(.isImage)
    }

    private var rhythm: some View {
        RhythmStripView(
            rhythm: drive.analysis.rhythm,
            palette: palette,
            progress: progress
        )
        .accessibilityElement()
        .accessibilityLabel(copy.spokenRhythm)
    }

    private var figures: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(copy.headline.value)
                .font(Typography.headline())
                .foregroundStyle(palette.inkColor)
                .accessibilityLabel("\(copy.headline.label), \(copy.headline.value)")
            Text(copy.headline.label)
                .quietLabel(palette)

            if !copy.secondary.isEmpty {
                HStack(spacing: 18) {
                    ForEach(copy.secondary, id: \.self) { item in
                        Text(item)
                    }
                }
                .font(Typography.figure)
                .foregroundStyle(palette.inkColor)
                .padding(.top, 14)
            }

            ForEach(copy.tertiary, id: \.self) { line in
                Text(line)
                    .font(Typography.figure)
                    .foregroundStyle(palette.neutralColor)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func replay() {
        guard !reduceMotion else {
            progress = 1
            return
        }
        progress = 0
        withAnimation(.linear(duration: Self.replayDuration)) { progress = 1 }
    }
}

#if DEBUG
#Preview("Dusk") {
    ArtifactView(drive: PreviewDrive.sample(light: .dusk))
}

#Preview("Day") {
    ArtifactView(drive: PreviewDrive.sample(light: .day))
}

#Preview("Night") {
    ArtifactView(drive: PreviewDrive.sample(light: .night))
}
#endif
