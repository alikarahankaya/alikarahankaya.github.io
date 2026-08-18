import SwiftUI
import UniformTypeIdentifiers
import Presentation

struct RootView: View {
    let library: DriveLibrary
    @State private var path: [UUID] = []
    #if DEBUG
    @State private var isPickingGPX = false
    #endif

    var body: some View {
        NavigationStack(path: $path) {
            LibraryView(
                drives: library.drives,
                isRecording: library.isRecording,
                onStart: { Task { await library.startRecording() } },
                onStop: { Task { await library.stopRecording() } },
                onDelete: { drive in Task { await library.delete(drive) } }
            )
            .navigationTitle(library.isRecording ? "Recording" : "Drives")
            .navigationDestination(for: UUID.self) { id in
                if let drive = library.drives.first(where: { $0.id == id }) {
                    DriveScreen(drive: drive) { note in
                        Task { await library.setNote(note, for: drive) }
                    }
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Replay a GPX") { isPickingGPX = true }
                }
            }
            .fileImporter(
                isPresented: $isPickingGPX,
                allowedContentTypes: [.xml, .data]
            ) { result in
                guard case let .success(url) = result else { return }
                Task { await library.replay(gpx: url) }
            }
            #endif
            .overlay(alignment: .bottom) {
                if let failure = library.failure {
                    Text(failure)
                        .font(.footnote)
                        .padding()
                }
            }
        }
        .task {
            await library.load()
            await library.watchForDrives()
        }
    }
}
