#if DEBUG
import Foundation
import Capture
import GPX

/// Drives the recorder from a file, at ten times speed, so the whole capture
/// path — samples, Live Activity, storage, analysis — can be exercised at a
/// desk. Without this, every change to capture needs a car and a mountain.
extension DriveLibrary {
    func replay(gpx url: URL) async {
        guard !isRecording else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let samples = try? GPXImporter.samples(contentsOf: url),
              let last = samples.last else { return }

        let rate = 10.0
        useRecorder(
            DriveRecorder(
                location: ReplayLocationFeed(samples: samples, rate: rate),
                motion: ReplayMotionFeed()
            )
        )
        await startRecording()
        // The file's own length, played back at rate, plus a moment for the
        // last fix to land.
        try? await Task.sleep(for: .seconds(last.t / rate + 1))
        await stopRecording()
        useRecorder(DriveRecorder())
    }
}
#endif
