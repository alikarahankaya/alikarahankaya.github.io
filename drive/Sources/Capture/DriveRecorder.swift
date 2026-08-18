import Foundation
import Core

/// The one place capture keeps mutable state.
///
/// Fixes and motion arrive on their own schedules from their own threads; the
/// actor is what makes "the drive so far" a single consistent thing rather
/// than three of them. It produces `[Sample]` and knows nothing about
/// analysis, storage or the interface.
public actor DriveRecorder {
    public struct Recorded: Sendable {
        public var samples: [Sample]
        public var startedAt: Date
        public var endedAt: Date
        public var timeZoneIdentifier: String
        /// The phone's orientation in the car, if it was ever solved.
        public var vehicleFrame: VehicleFrame?
        /// Straight-line sum between fixes, only used to decide whether this
        /// was a drive at all.
        public var distance: Double
    }

    /// Motion readings waiting for the next fix. A second's worth at 50 Hz is
    /// 50; the cap is there so a stalled location feed cannot grow the buffer
    /// without limit.
    private static let motionBufferLimit = 500

    private let location: any LocationFeed
    private let motion: any MotionFeed

    private var samples: [Sample] = []
    private var solver = VehicleFrameSolver()
    private var pending: [MotionReading] = []
    private var tasks: [Task<Void, Never>] = []
    private var startedAt: Date?
    private var lastFix: LocationFix?
    private var distance: Double = 0

    public init(
        location: any LocationFeed = LiveLocationFeed(),
        motion: any MotionFeed = LiveMotionFeed()
    ) {
        self.location = location
        self.motion = motion
    }

    public var isRecording: Bool { startedAt != nil }
    public var sampleCount: Int { samples.count }
    public var travelled: Double { distance }

    public func start(at date: Date = .now) async {
        guard startedAt == nil else { return }
        startedAt = date
        samples = []
        pending = []
        solver = VehicleFrameSolver()
        lastFix = nil
        distance = 0

        let readings = await motion.readings()
        tasks.append(
            Task { [weak self] in
                for await reading in readings { await self?.ingest(reading) }
            }
        )
        let fixes = await location.fixes()
        tasks.append(
            Task { [weak self] in
                for await fix in fixes { await self?.ingest(fix) }
            }
        )
    }

    /// Stops the sensors and hands back the drive — or nothing, when it was
    /// too short to be one. Drives under three minutes or two kilometres are
    /// discarded without asking, which is the only correct thing to do with a
    /// trip to the shops.
    public func finish(at date: Date = .now) async -> Recorded? {
        await location.stop()
        await motion.stop()
        for task in tasks { task.cancel() }
        tasks = []
        guard let started = startedAt else { return nil }
        startedAt = nil

        let ended = samples.last.map { started.addingTimeInterval($0.t) } ?? date
        let recorded = Recorded(
            samples: samples,
            startedAt: started,
            endedAt: ended,
            timeZoneIdentifier: TimeZone.current.identifier,
            vehicleFrame: solver.frame,
            distance: distance
        )
        samples = []
        pending = []
        guard ended.timeIntervalSince(started) >= Keeping.minimumDuration,
              distance >= Keeping.minimumDistance else { return nil }
        return recorded
    }

    private func ingest(_ reading: MotionReading) {
        pending.append(reading)
        if pending.count > Self.motionBufferLimit { pending.removeFirst(pending.count / 2) }
    }

    private func ingest(_ fix: LocationFix) {
        guard let started = startedAt else { return }
        let t = fix.timestamp.timeIntervalSince(started)
        guard t >= 0 else { return }

        var lateralG: Double?
        var longitudinalG: Double?
        if let averaged = averagedMotion() {
            // Downsampled to the fix rate by averaging, not by picking one
            // reading: the average is steadier and it is what the frame
            // solver wants to see.
            solver.add(
                VehicleFrameSolver.Input(
                    t: t,
                    gravity: averaged.gravity,
                    userAcceleration: averaged.userAcceleration,
                    speed: fix.speed,
                    course: fix.course
                )
            )
            if let frame = solver.frame {
                let resolved = frame.resolve(averaged.userAcceleration)
                lateralG = resolved.lateral
                longitudinalG = resolved.longitudinal
            }
        }

        samples.append(
            Sample(
                t: t,
                lat: fix.lat,
                lon: fix.lon,
                altitude: fix.altitude,
                speed: fix.speed,
                course: fix.course,
                horizontalAccuracy: fix.horizontalAccuracy,
                lateralG: lateralG,
                longitudinalG: longitudinalG
            )
        )

        if let last = lastFix {
            distance += Geo.distance(
                fromLat: last.lat, lon: last.lon,
                toLat: fix.lat, lon: fix.lon
            )
        }
        lastFix = fix
    }

    private func averagedMotion() -> MotionReading? {
        guard !pending.isEmpty else { return nil }
        var gravity = Vector3.zero
        var user = Vector3.zero
        for reading in pending {
            gravity += reading.gravity
            user += reading.userAcceleration
        }
        let count = Double(pending.count)
        let averaged = MotionReading(
            timestamp: pending[pending.count - 1].timestamp,
            gravity: gravity / count,
            userAcceleration: user / count
        )
        pending.removeAll(keepingCapacity: true)
        return averaged
    }
}
