import Foundation
import Core

/// The numbers that go on the artifact. Chosen for what they say about the
/// road and the rhythm of driving it — never about how fast it was driven.
public enum DriveCharacter {
    /// Path length over the straight line between its ends. 1.0 is a ruler;
    /// past about 1.5 the road has stopped pretending to go anywhere.
    public static func sinuosity(pathLength: Double, endToEnd: Double) -> Double {
        guard endToEnd > 1 else { return 1 }
        return pathLength / endToEnd
    }

    /// Sinuosity of the drive, measured over rolling kilometres rather than
    /// end to end.
    ///
    /// The brief asks for path length over the great-circle distance between
    /// the endpoints, and for a point-to-point drive that is the same number.
    /// But a great many drives come home again, and for those the endpoints
    /// are metres apart: the honest answer would be infinity, and the
    /// convenient one (fall back to 1.0) would call a mountain pass a
    /// motorway. Measuring each kilometre against its own chord and averaging
    /// gives the same reading for a point-to-point road and a sensible one
    /// for a loop.
    public static func sinuosity(
        points: [PathPoint],
        window: Double = 1000,
        step: Double = 250
    ) -> Double {
        guard let last = points.last, points.count > 2 else { return 1 }
        let length = last.s - points[0].s
        guard length > window else {
            return sinuosity(pathLength: length, endToEnd: chord(points, 0, points.count - 1))
        }
        // Points are one metre apart, so distance indexes straight into them.
        var total = 0.0
        var windows = 0
        var start = 0.0
        while start + window <= length {
            let a = index(of: start, in: points)
            let b = index(of: start + window, in: points)
            total += sinuosity(pathLength: window, endToEnd: chord(points, a, b))
            windows += 1
            start += step
        }
        return windows > 0 ? total / Double(windows) : 1
    }

    private static func index(of distance: Double, in points: [PathPoint]) -> Int {
        max(0, min(points.count - 1, Int(distance.rounded())))
    }

    private static func chord(_ points: [PathPoint], _ a: Int, _ b: Int) -> Double {
        points[a].position.distance(to: points[b].position)
    }

    /// The longest stretch of road where the corners keep coming: no gap
    /// longer than `flowMaximumGap`, no stop anywhere in between. Reported as
    /// the distance from the entry of the first corner to the exit of the
    /// last.
    ///
    /// This is the number the app leads with. Corner count says how many;
    /// flow says how long the road let you keep going.
    public static func flowDistance(corners: [Corner], points: [PathPoint]) -> Double {
        guard !corners.isEmpty else { return 0 }
        var best = 0.0
        var runStart = 0
        for i in corners.indices {
            if i > 0 {
                let gap = corners[i].entryDistance - corners[i - 1].exitDistance
                if gap > Tuning.flowMaximumGap
                    || stopped(between: corners[i - 1].exitDistance,
                               and: corners[i].entryDistance,
                               points: points) {
                    runStart = i
                }
            }
            best = max(best, corners[i].exitDistance - corners[runStart].entryDistance)
        }
        return best
    }

    static func stopped(between from: Double, and to: Double, points: [PathPoint]) -> Bool {
        guard to > from else { return false }
        // Points are one metre apart, so distance indexes straight into them.
        let first = max(0, min(points.count - 1, Int(from)))
        let last = max(0, min(points.count - 1, Int(to)))
        guard first <= last else { return false }
        for i in first...last where points[i].minimumSpeed < Tuning.flowStopSpeed { return true }
        return false
    }

    /// Metres of corner turning each way. A road that only turns one way
    /// feels different to drive, and nothing else measures it.
    public static func directionMetres(corners: [Corner]) -> (left: Double, right: Double) {
        var left = 0.0
        var right = 0.0
        for corner in corners {
            switch corner.direction {
            case .left: left += corner.length
            case .right: right += corner.length
            }
        }
        return (left, right)
    }

    /// Approximate, and labelled as such wherever it is shown: GPS altitude
    /// wanders by tens of metres. Smoothed over ±50 m of road, with a small
    /// deadband, so the number is at least not pure noise.
    public static func elevation(points: [PathPoint]) -> (gain: Double, loss: Double) {
        guard points.count > 2 else { return (0, 0) }
        let half = Tuning.elevationSmoothingHalfWidth
        var prefix = [Double](repeating: 0, count: points.count + 1)
        for i in points.indices { prefix[i + 1] = prefix[i] + points[i].altitude }
        var gain = 0.0
        var loss = 0.0
        var reference: Double?
        for i in points.indices {
            let lower = max(0, i - half)
            let upper = min(points.count - 1, i + half)
            let mean = (prefix[upper + 1] - prefix[lower]) / Double(upper - lower + 1)
            guard let last = reference else {
                reference = mean
                continue
            }
            let delta = mean - last
            guard abs(delta) >= Tuning.elevationDeadband else { continue }
            if delta > 0 { gain += delta } else { loss -= delta }
            reference = mean
        }
        return (gain, loss)
    }
}
