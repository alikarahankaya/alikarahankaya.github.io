import Foundation

/// A point on a local tangent plane, in metres: x east, y north.
public struct Point2: Sendable, Codable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public func distance(to o: Point2) -> Double {
        ((x - o.x) * (x - o.x) + (y - o.y) * (y - o.y)).squareRoot()
    }
}

public enum Geo {
    /// WGS84 mean radius. A drive is small enough that a sphere is exact
    /// to well under a metre, and a tangent plane keeps the maths readable.
    public static let earthRadius: Double = 6_371_008.8

    /// Projects to a tangent plane touching the first sample. Distances are
    /// true near the origin and drift by roughly (d/R)² — a part in ten
    /// million over 20 km, which is far below GPS noise.
    public static func project(_ samples: [Sample]) -> [Point2] {
        guard let first = samples.first else { return [] }
        let cosLat = cos(Angles.radians(first.lat))
        return samples.map { s in
            Point2(
                x: Angles.radians(s.lon - first.lon) * earthRadius * cosLat,
                y: Angles.radians(s.lat - first.lat) * earthRadius
            )
        }
    }

    /// Great-circle distance in metres, for sinuosity's denominator.
    public static func distance(
        fromLat lat1: Double, lon lon1: Double,
        toLat lat2: Double, lon lon2: Double
    ) -> Double {
        let p1 = Angles.radians(lat1)
        let p2 = Angles.radians(lat2)
        let dp = Angles.radians(lat2 - lat1)
        let dl = Angles.radians(lon2 - lon1)
        let a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * earthRadius * atan2(a.squareRoot(), (1 - a).squareRoot())
    }

    /// Bearing in degrees from true north, clockwise.
    public static func bearing(
        fromLat lat1: Double, lon lon1: Double,
        toLat lat2: Double, lon lon2: Double
    ) -> Double {
        let p1 = Angles.radians(lat1)
        let p2 = Angles.radians(lat2)
        let dl = Angles.radians(lon2 - lon1)
        let y = sin(dl) * cos(p2)
        let x = cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl)
        return (Angles.degrees(atan2(y, x)) + 360).truncatingRemainder(dividingBy: 360)
    }
}
