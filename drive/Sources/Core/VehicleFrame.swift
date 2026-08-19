import Foundation

/// Acceleration expressed in the car's own axes.
public struct VehicleAcceleration: Sendable, Equatable {
    /// Positive forward, in g.
    public var longitudinal: Double
    /// Positive to the driver's right, in g. A right-hand corner is positive.
    public var lateral: Double
    /// Positive downwards, in g.
    public var vertical: Double

    public init(longitudinal: Double, lateral: Double, vertical: Double) {
        self.longitudinal = longitudinal
        self.lateral = lateral
        self.vertical = vertical
    }
}

/// The rotation from device axes to vehicle axes.
///
/// The phone sits in a mount at an arbitrary angle, so raw device-frame
/// acceleration says nothing about the car until this is solved. Stored with
/// the drive so the same raw samples always resolve the same way.
public struct VehicleFrame: Sendable, Codable, Equatable {
    /// Unit vector, device frame, pointing at the ground.
    public let down: Vector3
    /// Unit vector, device frame, pointing where the car points.
    public let forward: Vector3
    /// Unit vector, device frame, pointing out of the driver's right window.
    public let lateral: Vector3

    /// Builds an orthonormal frame from a measured gravity direction and a
    /// rough forward direction. The hint need not be perpendicular to down —
    /// it is orthogonalised here. Returns nil when the hint is (near) parallel
    /// to down, which means it carried no horizontal information.
    public init?(down rawDown: Vector3, forwardHint: Vector3) {
        guard let d = rawDown.normalized else { return nil }
        let horizontal = forwardHint.orthogonalized(to: d)
        // A hint this short is numerically all rounding error. 0.02 g is about
        // the noise floor of a phone's user-acceleration estimate in a car.
        guard horizontal.length > 0.02, let f = horizontal.normalized else { return nil }
        down = d
        forward = f
        // Right-handed: down × forward points to the vehicle's right, so a
        // right-hand corner (centripetal acceleration to the right) reads
        // positive. Same sign convention as curvature in Analysis.
        lateral = d.cross(f)
    }

    /// Resolves a device-frame acceleration (in g) into vehicle axes.
    public func resolve(_ deviceAcceleration a: Vector3) -> VehicleAcceleration {
        VehicleAcceleration(
            longitudinal: a.dot(forward),
            lateral: a.dot(lateral),
            vertical: a.dot(down)
        )
    }

    /// Angle in degrees between this frame's down axis and a fresh gravity
    /// reading. Large values mean the phone moved in its mount.
    public func drift(from gravity: Vector3) -> Double { down.angle(to: gravity) }
}
