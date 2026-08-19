import Foundation
import Core
@testable import Capture

/// A drive on paper: every fix already known, delivered as fast as the
/// recorder will take them.
actor ScriptedLocationFeed: LocationFeed {
    private let script: [LocationFix]

    init(_ script: [LocationFix]) {
        self.script = script
    }

    func fixes() -> AsyncStream<LocationFix> {
        let script = script
        return AsyncStream { continuation in
            for fix in script { continuation.yield(fix) }
            continuation.finish()
        }
    }

    func stop() {}
}

/// No IMU at all, which is a phone in a pocket — and the case that has to
/// keep working.
actor SilentMotionFeed: MotionFeed {
    func readings() -> AsyncStream<MotionReading> {
        AsyncStream { $0.finish() }
    }

    func stop() {}
}

enum Script {
    /// A straight run north at a steady speed, one fix a second.
    static func straight(
        seconds: Int,
        speed: Double,
        from start: Date = Date(timeIntervalSince1970: 1_718_219_700)
    ) -> [LocationFix] {
        (0..<seconds).map { i in
            let metres = Double(i) * speed
            return LocationFix(
                timestamp: start.addingTimeInterval(Double(i)),
                lat: 46.5 + (metres / Geo.earthRadius) * 180 / .pi,
                lon: 11.0,
                altitude: 800,
                speed: speed,
                course: 0,
                horizontalAccuracy: 5
            )
        }
    }
}
