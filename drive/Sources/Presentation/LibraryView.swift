import SwiftUI
import Analysis

/// A set of prints.
///
/// Each drive is its own small trace on its own ground, so the library sorts
/// itself by the light it was driven in. No text but the date — the drawing
/// is the identifier, and it is a better one than "Tuesday afternoon".
public struct LibraryView: View {
    public var drives: [DrivePresentation]
    public var onStart: () -> Void
    public var onDelete: (DrivePresentation) -> Void

    /// There is no stop here. While a drive is running the app is showing the
    /// drive, not the library, and that screen owns ending it.
    public init(
        drives: [DrivePresentation],
        onStart: @escaping () -> Void,
        onDelete: @escaping (DrivePresentation) -> Void
    ) {
        self.drives = drives
        self.onStart = onStart
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
        .background(Palette.day.groundColor)
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
                .listRowBackground(Color.clear)
                .swipeActions {
                    Button("Delete", role: .destructive) { onDelete(drive) }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// Says what to do, not that nothing is here.
    private var empty: some View {
        VStack(spacing: 12) {
            Text("Drive somewhere")
                .font(Typography.headline(.title2))
                .foregroundStyle(Palette.day.inkColor)
            Text("Recording starts on its own once you are moving. Anything over three minutes and two kilometres is kept.")
                .font(Typography.figure)
                .foregroundStyle(Palette.day.neutralColor)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// A drive starts on its own once the car does. This is for the times it
    /// does not — a dot, not a word, because it is almost never the thing you
    /// came here to do.
    private var recordingControl: some View {
        Button(action: onStart) {
            Circle()
                .fill(Palette.day.signalColor)
                .frame(width: 14, height: 14)
        }
        .accessibilityLabel("Start recording")
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
            Text(Formatting.shortDate(drive.startedAt, timeZone: drive.timeZone))
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
            onStart: {},
            onDelete: { _ in }
        )
    }
}

#Preview("Empty library") {
    NavigationStack {
        LibraryView(
            drives: [],
            onStart: {},
            onDelete: { _ in }
        )
    }
}
#endif
