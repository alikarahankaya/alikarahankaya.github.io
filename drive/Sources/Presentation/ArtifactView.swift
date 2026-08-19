import SwiftUI
import Analysis

/// One drive, one screen. This is the product.
///
/// Flow leads because it is the number that describes pleasure: how far the
/// road let you keep going without interruption. Distance and duration are
/// down at the bottom, where logistics belong.
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
            rhythm
                .frame(height: 44)
                .padding(.top, 24)
            figures
                .padding(.top, 28)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(drive.palette.groundColor)
        .sheet(isPresented: $showsLocation) {
            LocationSheet(drive: drive)
        }
    }

    private var trace: some View {
        TraceView(
            trace: drive.analysis.trace,
            palette: drive.palette,
            progress: progress,
            showsHead: progress < 1
        )
        .contentShape(Rectangle())
        .onTapGesture { replay() }
        .accessibilityElement()
        .accessibilityLabel(Formatting.spokenSummary(drive))
        .accessibilityHint("Double tap to replay the drive")
        .accessibilityAddTraits(.isImage)
    }

    private var rhythm: some View {
        RhythmStripView(
            rhythm: drive.analysis.rhythm,
            palette: drive.palette,
            progress: progress
        )
        .accessibilityElement()
        .accessibilityLabel(spokenRhythm)
    }

    private var figures: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Formatting.distance(drive.analysis.flowDistance))
                .font(Typography.headline())
                .foregroundStyle(drive.palette.inkColor)
                .accessibilityLabel(
                    "Flow, \(Formatting.distance(drive.analysis.flowDistance))"
                )
            Text("Longest unbroken sequence")
                .quietLabel(drive.palette)

            HStack(spacing: 18) {
                Text(Formatting.corners(drive.analysis.corners.count))
                Text(Formatting.sinuosity(drive.analysis.sinuosity))
            }
            .font(Typography.figure)
            .foregroundStyle(drive.palette.inkColor)
            .padding(.top, 14)

            conditions

            Text(logistics)
                .font(Typography.figure)
                .foregroundStyle(drive.palette.neutralColor)

            if let soundtrack = drive.soundtrack, !soundtrack.isEmpty {
                Text(soundtrack)
                    .font(Typography.figure)
                    .foregroundStyle(drive.palette.neutralColor)
            }

            if let note = drive.note, !note.isEmpty {
                Text(note)
                    .font(Typography.figure)
                    .foregroundStyle(drive.palette.neutralColor)
                    .padding(.top, 8)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The only place MapKit appears: a quiet "where was this", asked for
    /// rather than volunteered.
    private var conditions: some View {
        Button { showsLocation = true } label: {
            Text(Formatting.conditions(drive))
                .font(Typography.figure)
                .foregroundStyle(drive.palette.neutralColor)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows where this drive was")
    }

    private var logistics: String {
        [
            Formatting.distance(drive.analysis.distance),
            Formatting.duration(drive.analysis.duration),
        ].joined(separator: " · ")
    }

    private var spokenRhythm: String {
        let corners = drive.analysis.corners
        guard !corners.isEmpty else { return "No corners" }
        let tightest = corners.min { $0.severity < $1.severity }?.severity ?? 6
        let left = corners.filter { $0.direction == .left }.count
        return """
        Corner rhythm. \(corners.count) corners, \(left) left and \
        \(corners.count - left) right, tightest severity \(tightest).
        """
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
