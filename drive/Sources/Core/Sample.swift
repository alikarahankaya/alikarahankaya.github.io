import Foundation

/// One instant of a drive, as recorded. Roughly 10 Hz.
///
/// This is the only shape the rest of the app agrees on: capture writes it,
/// storage packs it, analysis reads it. It deliberately holds raw sensor
/// values and nothing derived — derived numbers change when the analysis
/// improves, and raw data does not come back.
public struct Sample: Sendable, Codable, Equatable {
    /// Seconds since the drive started.
    public var t: TimeInterval
    public var lat: Double
    public var lon: Double
    /// Metres above sea level, as reported by GPS. Poor; treat as approximate.
    public var altitude: Double
    /// Metres per second, -1 when the fix carried no valid speed.
    public var speed: Double
    /// Degrees clockwise from true north, -1 when invalid.
    public var course: Double
    public var horizontalAccuracy: Double
    /// Vehicle-frame lateral acceleration in g, positive to the right.
    /// Nil until the vehicle frame is solved, or when the IMU is untrusted.
    public var lateralG: Double?
    /// Vehicle-frame longitudinal acceleration in g, positive forward.
    public var longitudinalG: Double?

    public init(
        t: TimeInterval,
        lat: Double,
        lon: Double,
        altitude: Double = 0,
        speed: Double = -1,
        course: Double = -1,
        horizontalAccuracy: Double = 5,
        lateralG: Double? = nil,
        longitudinalG: Double? = nil
    ) {
        self.t = t
        self.lat = lat
        self.lon = lon
        self.altitude = altitude
        self.speed = speed
        self.course = course
        self.horizontalAccuracy = horizontalAccuracy
        self.lateralG = lateralG
        self.longitudinalG = longitudinalG
    }

    public var hasValidSpeed: Bool { speed >= 0 }
    public var hasValidCourse: Bool { course >= 0 }
}

public extension Sample {
    /// Standard gravity, for converting between g and m/s².
    static let g = 9.80665
}
