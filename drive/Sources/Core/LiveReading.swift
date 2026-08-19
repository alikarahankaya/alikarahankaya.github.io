import Foundation

/// What the car is doing, right now.
///
/// Separate from `Sample` on purpose: a sample is evidence, kept forever and
/// never thrown away. A live reading is a glance — it exists for a few
/// seconds of screen and is then gone. Nothing is stored from these.
public struct LiveReading: Sendable, Equatable {
    /// Seconds since the drive started.
    public var t: TimeInterval
    /// Vehicle-frame lateral acceleration in g, positive to the right.
    /// Nil until the phone's orientation in the car has been worked out —
    /// and the screen says nothing rather than guessing.
    public var lateralG: Double?
    /// Vehicle-frame longitudinal acceleration in g, positive forward.
    public var longitudinalG: Double?
    /// Metres per second, negative when unknown.
    public var speed: Double
    /// Where the car is, which the screen uses only to ask where the sun is.
    /// Nil until the first fix lands.
    public var coordinate: Coordinate?

    public init(
        t: TimeInterval,
        lateralG: Double?,
        longitudinalG: Double?,
        speed: Double,
        coordinate: Coordinate? = nil
    ) {
        self.t = t
        self.lateralG = lateralG
        self.longitudinalG = longitudinalG
        self.speed = speed
        self.coordinate = coordinate
    }

    /// The stronger of the two axes, which is the one worth a number.
    public var dominantG: Double {
        max(abs(lateralG ?? 0), abs(longitudinalG ?? 0))
    }

    public var isCalibrated: Bool { lateralG != nil && longitudinalG != nil }
}
