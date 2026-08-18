#if DEBUG
import Foundation
import Core
import GPX

/// Feeds a recorded drive back through the live capture path, faster than it
/// happened.
///
/// This is how the recorder and the Live Activity get tested at a desk. The
/// drive keeps its real timestamps, so a 40-minute drive still records as 40
/// minutes — it just arrives in four.
public actor ReplayLocationFeed: LocationFeed {
    private let samples: [Sample]
    private let rate: Double
    private var task: Task<Void, Never>?

    public init(samples: [Sample], rate: Double = 10) {
        self.samples = samples
        self.rate = max(1, rate)
    }

    public init(gpx url: URL, rate: Double = 10) throws {
        samples = try GPXImporter.samples(contentsOf: url)
        self.rate = max(1, rate)
    }

    public func fixes() -> AsyncStream<LocationFix> {
        stop()
        let (stream, continuation) = AsyncStream<LocationFix>.makeStream()
        let samples = samples
        let rate = rate
        task = Task {
            let began = Date()
            for sample in samples {
                let due = sample.t / rate
                let elapsed = Date().timeIntervalSince(began)
                if due > elapsed {
                    try? await Task.sleep(for: .seconds(due - elapsed))
                }
                if Task.isCancelled { break }
                continuation.yield(
                    LocationFix(
                        timestamp: began.addingTimeInterval(sample.t),
                        lat: sample.lat,
                        lon: sample.lon,
                        altitude: sample.altitude,
                        speed: sample.speed,
                        course: sample.course,
                        horizontalAccuracy: sample.horizontalAccuracy
                    )
                )
            }
            continuation.finish()
        }
        return stream
    }

    public func stop() {
        task?.cancel()
        task = nil
    }
}

/// Motion to go with a replayed drive. A GPX file carries no inertia, so this
/// reports a level phone and no acceleration: the frame never solves and
/// lateral g comes from the road, exactly as it does on a phone left in a
/// pocket. Anything else here would be fabricated data pretending to be
/// measured.
public actor ReplayMotionFeed: MotionFeed {
    private var task: Task<Void, Never>?

    public init() {}

    public func readings() -> AsyncStream<MotionReading> {
        stop()
        let (stream, continuation) = AsyncStream<MotionReading>.makeStream()
        task = Task {
            var t = 0.0
            while !Task.isCancelled {
                continuation.yield(
                    MotionReading(
                        timestamp: t,
                        gravity: Vector3(0, 0, -1),
                        userAcceleration: .zero
                    )
                )
                t += 0.02
                try? await Task.sleep(for: .milliseconds(20))
            }
            continuation.finish()
        }
        return stream
    }

    public func stop() {
        task?.cancel()
        task = nil
    }
}
#endif
