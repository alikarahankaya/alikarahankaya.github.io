import SwiftUI
import Analysis

/// A set of prints.
///
/// Each drive is its own small trace on its own ground, so the library sorts
/// itself by the light it was driven in. No text but the date — the drawing
/// is the identifier, and it is a better one than "Tuesday afternoon".
public struct LibraryView: View {
    public var drives: [DrivePresentation]
    public var isRecording: Bool
    public var onStart: () -> Void
    public var onStop: () -> Void
    public var onDelete: (DrivePresentation) -> Void

    public init(
        drives: [DrivePresentation],
        isRecording: Bool,
        onStart: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onDelete: @escaping (DrivePresentation) -> Void
    ) {
        self.drives = drives
        self.isRecording = isRecording
        self.onStart = onStart
        self.onStop = onStop
        self.onDelete = onDelete
    }

    public var body: some View {
        Group {
            if drives.isEmpty {
                empty
            } else {
                list
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) { recordingControl }
        }
    }

    private var list: some View {
        List {
            ForEach(drives) { drive in
                NavigationLink(value: drive.id) {
                    LibraryRow(drive: drive)
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .swipeActions {
                    Button("Delete", role: .destructive) { onDelete(drive) }
                }
            }
        }
        .listStyle(.plain)
    }

    /// Says what to do, not that nothing is here.
    private var empty: some View {
        VStack(spacing: 12) {
            Text("Drive somewhere")
                .font(Typography.headline(.title2))
            Text("Recording starts on its own once you are moving. Anything over three minutes and two kilometres is kept.")
                .font(Typography.figure)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var recordingControl: some View {
        if isRecording {
            Button("Stop", action: onStop)
        } else {
            Button("Record", action: onStart)
        }
    }
}

/// One print: the trace, small, on its own ground, with the date underneath.
struct LibraryRow: View {
    let drive: DrivePresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TraceView(trace: drive.analysis.trace, palette: drive.palette)
                .frame(height: 150)
                .background(drive.palette.groundColor)
            Text(Formatting.date(drive.startedAt, timeZone: drive.timeZone))
                .quietLabel(drive.palette)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(drive.palette.groundColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(Formatting.date(drive.startedAt, timeZone: drive.timeZone)). \(Formatting.spokenSummary(drive))"
        )
    }
}

#if DEBUG
#Preview("Library") {
    NavigationStack {
        LibraryView(
            drives: [
                PreviewDrive.sample(light: .dusk),
                PreviewDrive.sample(light: .morning),
                PreviewDrive.sample(light: .night),
            ],
            isRecording: false,
            onStart: {},
            onStop: {},
            onDelete: { _ in }
        )
    }
}

#Preview("Empty library") {
    NavigationStack {
        LibraryView(
            drives: [],
            isRecording: false,
            onStart: {},
            onStop: {},
            onDelete: { _ in }
        )
    }
}
#endif
