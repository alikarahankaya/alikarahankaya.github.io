import Testing
import Foundation
import Core
@testable import Presentation

@Suite("Live telemetry")
@MainActor
struct LiveTelemetryTests {
    private func reading(
        _ t: Double,
        lateral: Double? = 0,
        longitudinal: Double? = 0
    ) -> LiveReading {
        LiveReading(t: t, lateralG: lateral, longitudinalG: longitudinal, speed: 20)
    }

    @Test("Only the recent past is kept")
    func windowIsBounded() {
        let telemetry = LiveTelemetry(window: 45)
        for i in 0..<2000 {
            telemetry.append(reading(Double(i) / 17))
        }
        let span = telemetry.readings.map(\.t)
        let range = (span.max() ?? 0) - (span.min() ?? 0)
        // Pruning happens in batches, so a few seconds of slack is expected.
        #expect(range <= 51)
        #expect(telemetry.readings.count < 900)
    }

    @Test("The number appears only when the car is doing something")
    func numberIsConditional() {
        let telemetry = LiveTelemetry()
        for i in 0..<20 {
            telemetry.append(reading(Double(i) / 17, lateral: 0.05, longitudinal: 0.02))
        }
        #expect(!telemetry.isWorking)

        telemetry.append(reading(20 / 17, lateral: 0.42, longitudinal: 0.1))
        #expect(telemetry.isWorking)
        #expect(abs(telemetry.peak - 0.42) < 0.001)
    }

    @Test("A hard corner stops counting once it is over")
    func peakDecays() {
        let telemetry = LiveTelemetry()
        telemetry.append(reading(0, lateral: 0.8))
        #expect(telemetry.isWorking)
        // Two seconds later, with nothing happening, the number is gone.
        telemetry.append(reading(2, lateral: 0.01))
        #expect(!telemetry.isWorking)
    }

    @Test("Nothing is claimed before the phone knows which way the car faces")
    func uncalibratedSaysNothing() {
        let telemetry = LiveTelemetry()
        telemetry.append(
            LiveReading(t: 0, lateralG: nil, longitudinalG: nil, speed: 20)
        )
        #expect(!telemetry.isCalibrated)
        #expect(!telemetry.isWorking)
    }

    @Test("The screen takes its colours from the sun outside")
    func paletteFollowsTheSun() {
        let telemetry = LiveTelemetry()
        let alpine = Coordinate(lat: 46.5, lon: 11)
        // 2024-06-12 13:00Z: the sun is 58° up.
        telemetry.append(
            LiveReading(t: 0, lateralG: 0, longitudinalG: 0, speed: 20, coordinate: alpine),
            now: Date(timeIntervalSince1970: 1_718_197_200)
        )
        #expect(telemetry.palette.surface == .paper)

        let night = LiveTelemetry()
        // 2024-12-03 22:30Z: well below the horizon.
        night.append(
            LiveReading(t: 0, lateralG: 0, longitudinalG: 0, speed: 20, coordinate: alpine),
            now: Date(timeIntervalSince1970: 1_733_265_000)
        )
        #expect(night.palette == .night)
        #expect(night.palette.surface == .night)
    }

    @Test("Clearing forgets the drive entirely")
    func clearing() {
        let telemetry = LiveTelemetry()
        telemetry.append(reading(0, lateral: 0.5))
        telemetry.clear()
        #expect(telemetry.readings.isEmpty)
        #expect(telemetry.peak == 0)
    }
}
