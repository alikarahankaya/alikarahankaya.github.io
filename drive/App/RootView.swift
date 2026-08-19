import SwiftUI
import UniformTypeIdentifiers
// UIKit for one line: keeping the screen awake while driving has no SwiftUI
// equivalent.
import UIKit
import Presentation

struct RootView: View {
    let library: DriveLibrary
    @State private var path: [UUID] = []
    #if DEBUG
    @State private var isPickingGPX = false
    #endif

    var body: some View {
        Group {
            if library.isRecording {
                // While the car is moving there is no app: there is the
                // drive, and a long press to end it.
                LiveDriveView(telemetry: library.telemetry) {
                    Task { await library.stopRecording() }
                }
            } else {
                libraryStack
            }
        }
        .task {
            await library.load()
            await library.watchForDrives()
        }
        .onChange(of: library.isRecording, initial: true) { _, recording in
            UIApplication.shared.isIdleTimerDisabled = recording
        }
    }

    private var libraryStack: some View {
        NavigationStack(path: $path) {
            LibraryView(
                drives: library.drives,
                onStart: { Task { await library.startRecording() } },
                onDelete: { drive in Task { await library.delete(drive) } }
            )
            .navigationTitle("Drives")
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
    }
}
