import Foundation
import Observation
import Core
import Analysis

/// The last minute of the drive, held in memory and nowhere else.
///
/// Everything here is discarded when the drive ends. The record of a drive is
/// its samples; this is only what the screen needs to draw the present tense.
@MainActor
@Observable
public final class LiveTelemetry {
    /// How much of the recent past the ribbon shows. Forty-five seconds is
    /// about a village, a slip road and the corner after it: long enough to
    /// see a rhythm, short enough that the right-hand edge is still now.
    public let window: TimeInterval

    /// A number appears only once the car is doing something worth a number.
    /// Below a quarter of a g you are just driving.
    public static let numberThreshold = 0.25

    /// Full deflection, and full stroke weight, at 0.6 g — the same scale the
    /// artifact uses, so a hard corner looks equally hard in both places.
    public static let fullScaleG = 0.6

    public private(set) var readings: [LiveReading] = []
    /// The colours of the sun outside, recomputed as the drive moves.
    public private(set) var palette: Palette = .day

    private var paletteAskedAt: Date?

    public init(window: TimeInterval = 45) {
        self.window = window
    }

    public func append(_ reading: LiveReading, now: Date = .now) {
        readings.append(reading)
        // Pruned in batches rather than on every reading: trimming one
        // element off the front seventeen times a second is a lot of work to
        // avoid keeping five seconds of doubles.
        let cutoff = reading.t - window
        if let oldest = readings.first?.t, oldest < cutoff - 5 {
            readings.removeAll { $0.t < cutoff }
        }
        updatePalette(for: reading, now: now)
    }

    public func clear() {
        readings.removeAll()
        paletteAskedAt = nil
    }

    /// The strongest recent load, which is what the number reports. Taken
    /// over a short window rather than the last reading, so the digits settle
    /// instead of flickering.
    public var peak: Double {
        guard let last = readings.last else { return 0 }
        var peak = 0.0
        for reading in readings.reversed() {
            guard last.t - reading.t <= 1.5 else { break }
            peak = max(peak, reading.dominantG)
        }
        return peak
    }

    public var isCalibrated: Bool { readings.last?.isCalibrated ?? false }

    /// True when the car is doing enough to be worth saying so.
    public var isWorking: Bool { peak >= Self.numberThreshold }

    /// The sun barely moves, so this is asked once a minute rather than
    /// seventeen times a second.
    private func updatePalette(for reading: LiveReading, now: Date) {
        guard let coordinate = reading.coordinate else { return }
        if let asked = paletteAskedAt, now.timeIntervalSince(asked) < 60 { return }
        paletteAskedAt = now
        palette = Palette(Solar.light(at: now, lat: coordinate.lat, lon: coordinate.lon))
    }
}
