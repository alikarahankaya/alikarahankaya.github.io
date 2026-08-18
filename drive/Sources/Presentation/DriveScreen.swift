import SwiftUI

/// The artifact, plus the two things a driver can actually do with it: share
/// it, and write one line about it.
public struct DriveScreen: View {
    public var drive: DrivePresentation
    public var onNoteChanged: (String) -> Void

    @State private var poster: Image?
    @State private var isWritingNote = false
    @State private var draft = ""

    public init(drive: DrivePresentation, onNoteChanged: @escaping (String) -> Void) {
        self.drive = drive
        self.onNoteChanged = onNoteChanged
    }

    public var body: some View {
        ArtifactView(drive: drive)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if let poster {
                        ShareLink(
                            item: poster,
                            preview: SharePreview(
                                Formatting.date(drive.startedAt, timeZone: drive.timeZone),
                                image: poster
                            )
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button(drive.note == nil ? "Write a line" : "Edit the line") {
                        draft = drive.note ?? ""
                        isWritingNote = true
                    }
                }
            }
            .task(id: drive.id) {
                // Rendered once the screen is up rather than on the way in:
                // it costs a frame or two and nobody is waiting for it.
                poster = PosterRenderer.image(for: drive).map(Image.init(uiImage:))
            }
            .alert("One line about this drive", isPresented: $isWritingNote) {
                TextField("", text: $draft)
                Button("Save") { onNoteChanged(draft) }
                Button("Cancel", role: .cancel) {}
            }
    }
}

#if DEBUG
#Preview("Drive") {
    NavigationStack {
        DriveScreen(drive: PreviewDrive.sample(light: .dusk)) { _ in }
    }
}
#endif
