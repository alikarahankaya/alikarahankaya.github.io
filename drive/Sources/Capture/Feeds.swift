import Foundation
import Core

/// One position fix, as a value: `CLLocation` is a class and does not cross
/// actors, and nothing downstream should be importing CoreLocation anyway.
public struct LocationFix: Sendable, Equatable {
    public var timestamp: Date
    public var lat: Double
    public var lon: Double
    public var altitude: Double
    /// Metres per second, negative when the fix carried no speed.
    public var speed: Double
    /// Degrees from true north, negative when unknown.
    public var course: Double
    public var horizontalAccuracy: Double

    public init(
        timestamp: Date,
        lat: Double,
        lon: Double,
        altitude: Double,
        speed: Double,
        course: Double,
        horizontalAccuracy: Double
    ) {
        self.timestamp = timestamp
        self.lat = lat
        self.lon = lon
        self.altitude = altitude
        self.speed = speed
        self.course = course
        self.horizontalAccuracy = horizontalAccuracy
    }
}

/// One inertial reading, already reduced to two vectors in g.
public struct MotionReading: Sendable, Equatable {
    public var timestamp: TimeInterval
    public var gravity: Vector3
    public var userAcceleration: Vector3

    public init(timestamp: TimeInterval, gravity: Vector3, userAcceleration: Vector3) {
        self.timestamp = timestamp
        self.gravity = gravity
        self.userAcceleration = userAcceleration
    }
}

/// Where fixes come from. A protocol so the debug replay can feed a GPX file
/// through the same recorder the road uses — without it, testing the recorder
/// means driving somewhere.
///
/// Both sides are asked to stop explicitly rather than cleaning up in
/// `onTermination`: the hardware objects behind them are classes that cannot
/// travel into a `@Sendable` closure, and keeping them inside an actor is
/// honest about that instead of asserting it away.
public protocol LocationFeed: Sendable {
    func fixes() async -> AsyncStream<LocationFix>
    func stop() async
}

public protocol MotionFeed: Sendable {
    func readings() async -> AsyncStream<MotionReading>
    func stop() async
}
