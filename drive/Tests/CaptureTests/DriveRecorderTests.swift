import Testing
import Foundation
import Core
@testable import Capture

@Suite("Recorder")
struct DriveRecorderTests {
    /// The feeds run in their own tasks, so the test waits for the samples to
    /// land rather than assuming they already have.
    private func wait(
        for recorder: DriveRecorder,
        toReach count: Int
    ) async throws {
        for _ in 0..<200 {
            if await recorder.sampleCount >= count { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        let reached = await recorder.sampleCount
        Issue.record("recorder only reached \(reached) of \(count) samples")
    }

    @Test("A real drive comes back as samples")
    func recordsADrive() async throws {
        let script = Script.straight(seconds: 400, speed: 20)   // 400 s, 8 km
        let recorder = DriveRecorder(
            location: ScriptedLocationFeed(script),
            motion: SilentMotionFeed()
        )
        await recorder.start(at: script[0].timestamp)
        try await wait(for: recorder, toReach: script.count)

        let recorded = try #require(await recorder.finish())
        #expect(recorded.samples.count == script.count)
        #expect(recorded.samples[0].t == 0)
        #expect(abs(recorded.samples[recorded.samples.count - 1].t - 399) < 0.01)
        #expect(abs(recorded.distance - 7980) < 50)
        // No IMU on this drive, and nothing pretends otherwise.
        #expect(recorded.samples.allSatisfy { $0.lateralG == nil })
        #expect(recorded.vehicleFrame == nil)
    }

    @Test("A trip to the shops is thrown away without being asked about")
    func discardsShortDrives() async throws {
        let script = Script.straight(seconds: 100, speed: 8)    // 100 s, 800 m
        let recorder = DriveRecorder(
            location: ScriptedLocationFeed(script),
            motion: SilentMotionFeed()
        )
        await recorder.start(at: script[0].timestamp)
        try await wait(for: recorder, toReach: script.count)
        let recorded = await recorder.finish()
        #expect(recorded == nil)
    }

    @Test("Long enough but not far enough is still not a drive")
    func discardsSlowCrawls() async throws {
        // Twenty minutes of traffic covering 1.2 km.
        let script = Script.straight(seconds: 1200, speed: 1)
        let recorder = DriveRecorder(
            location: ScriptedLocationFeed(script),
            motion: SilentMotionFeed()
        )
        await recorder.start(at: script[0].timestamp)
        try await wait(for: recorder, toReach: script.count)
        let recorded = await recorder.finish()
        #expect(recorded == nil)
    }

    @Test("Starting twice does not start twice")
    func startIsIdempotent() async throws {
        let script = Script.straight(seconds: 400, speed: 20)
        let recorder = DriveRecorder(
            location: ScriptedLocationFeed(script),
            motion: SilentMotionFeed()
        )
        await recorder.start(at: script[0].timestamp)
        await recorder.start(at: script[0].timestamp)
        try await wait(for: recorder, toReach: script.count)
        #expect(await recorder.sampleCount == script.count)
        #expect(await recorder.isRecording)
        _ = await recorder.finish()
        let stillRecording = await recorder.isRecording
        #expect(!stillRecording)
    }
}
