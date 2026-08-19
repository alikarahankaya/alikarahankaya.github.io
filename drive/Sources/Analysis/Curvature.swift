import Foundation
import Core

public enum Curvature {
    /// Signed Menger curvature along the path, one value per point.
    ///
    /// Menger curvature is 1/R of the circle through three points, which for
    /// three points actually on a circle is exact whatever their spacing —
    /// that is the reason for choosing it over a finite-difference second
    /// derivative, which is far more sensitive to how the path was sampled.
    ///
    /// Sign convention: positive is a right-hand corner. It matches the
    /// vehicle frame's lateral axis, so `v²·κ` and the IMU's lateral g agree
    /// in sign as well as in size.
    ///
    /// The first and last `arm` points have no curvature and are reported as
    /// zero; a drive that begins mid-corner loses 15 m of it.
    public static func signed(_ points: [PathPoint], arm: Int = Tuning.curvatureArm) -> [Double] {
        let n = points.count
        var k = [Double](repeating: 0, count: n)
        guard n > 2 * arm else { return k }
        for i in arm..<(n - arm) {
            let a = points[i - arm].position
            let b = points[i].position
            let c = points[i + arm].position
            let ab = a.distance(to: b)
            let bc = b.distance(to: c)
            let ca = c.distance(to: a)
            guard ab > 1e-6, bc > 1e-6, ca > 1e-6 else { continue }
            // Twice the signed area of the triangle: positive turning
            // anticlockwise (left), negative clockwise (right).
            let cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
            let magnitude = 2 * abs(cross) / (ab * bc * ca)
            k[i] = cross > 0 ? -magnitude : magnitude
        }
        return k
    }

    /// Lateral acceleration in g implied by the road and the speed driven,
    /// `a = v²·κ`. This is the fallback when the IMU cannot be trusted, and
    /// the cross-check when it can.
    public static func lateralG(speed: Double, curvature: Double) -> Double {
        speed * speed * curvature / Sample.g
    }
}
