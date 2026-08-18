import Foundation

/// A three-component vector. Small enough to be worth writing rather than
/// importing simd, which would drag SIMD types into the persisted formats.
public struct Vector3: Sendable, Codable, Equatable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(_ x: Double, _ y: Double, _ z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = Vector3(0, 0, 0)

    public var length: Double { (x * x + y * y + z * z).squareRoot() }

    /// Nil for a vector too short to have a meaningful direction.
    public var normalized: Vector3? {
        let l = length
        guard l > 1e-9 else { return nil }
        return Vector3(x / l, y / l, z / l)
    }

    public func dot(_ o: Vector3) -> Double { x * o.x + y * o.y + z * o.z }

    public func cross(_ o: Vector3) -> Vector3 {
        Vector3(
            y * o.z - z * o.y,
            z * o.x - x * o.z,
            x * o.y - y * o.x
        )
    }

    /// Component of self perpendicular to `axis`, which must be a unit vector.
    public func orthogonalized(to axis: Vector3) -> Vector3 {
        self - axis * dot(axis)
    }

    /// Angle between two vectors, in degrees.
    public func angle(to o: Vector3) -> Double {
        guard let a = normalized, let b = o.normalized else { return 0 }
        return acos(min(1, max(-1, a.dot(b)))) * 180 / .pi
    }

    public static func + (a: Vector3, b: Vector3) -> Vector3 {
        Vector3(a.x + b.x, a.y + b.y, a.z + b.z)
    }

    public static func - (a: Vector3, b: Vector3) -> Vector3 {
        Vector3(a.x - b.x, a.y - b.y, a.z - b.z)
    }

    public static func * (a: Vector3, s: Double) -> Vector3 {
        Vector3(a.x * s, a.y * s, a.z * s)
    }

    public static func / (a: Vector3, s: Double) -> Vector3 {
        Vector3(a.x / s, a.y / s, a.z / s)
    }

    public static func += (a: inout Vector3, b: Vector3) { a = a + b }
}
