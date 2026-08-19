import Foundation
import Core

/// Roads built from arithmetic, for tests that need a shape whose answer is
/// known exactly rather than one that was driven.
enum Synthetic {
    static let origin = (lat: 46.5, lon: 11.0)

    enum Leg {
        case straight(Double)
        /// Constant radius. Positive radius turns right, negative left.
        case arc(radius: Double, length: Double)
        /// Radius easing from one value to another along the arc.
        case taper(from: Double, to: Double, length: Double)
    }

    /// Walks a road made of legs, one point every `spacing` metres.
    static func road(_ legs: [Leg], spacing: Double = 2) -> [(x: Double, y: Double)] {
        var points: [(x: Double, y: Double)] = []
        var x = 0.0
        var y = 0.0
        var heading = 0.0               // radians clockwise from north
        func step(_ curvature: Double) {
            points.append((x: x, y: y))
            heading += spacing * curvature
            x += spacing * sin(heading)
            y += spacing * cos(heading)
        }
        for leg in legs {
            switch leg {
            case let .straight(length):
                for _ in 0..<Int((length / spacing).rounded()) { step(0) }
            case let .arc(radius, length):
                for _ in 0..<Int((length / spacing).rounded()) { step(1 / radius) }
            case let .taper(from, to, length):
                let steps = max(1, Int((length / spacing).rounded()))
                for i in 0..<steps {
                    let f = Double(i) / Double(steps)
                    step(1 / (from + (to - from) * f))
                }
            }
        }
        points.append((x: x, y: y))
        return points
    }

    /// A closed circle, sampled every `spacing` metres of arc.
    static func circle(radius: Double, spacing: Double = 3) -> [(x: Double, y: Double)] {
        let count = max(8, Int((2 * .pi * radius / spacing).rounded()))
        return (0...count).map { i in
            let theta = 2 * Double.pi * Double(i) / Double(count)
            return (x: radius * cos(theta), y: radius * sin(theta))
        }
    }

    /// Samples straight from arrays, for tests that need to control time and
    /// speed exactly — stops, gaps, bad fixes.
    static func samples(
        points: [(x: Double, y: Double)],
        times: [Double],
        speeds: [Double],
        accuracy: Double = 5
    ) -> [Sample] {
        let cosLat = cos(Angles.radians(origin.lat))
        return points.indices.map { i in
            Sample(
                t: times[i],
                lat: origin.lat + Angles.degrees(points[i].y / Geo.earthRadius),
                lon: origin.lon + Angles.degrees(points[i].x / (Geo.earthRadius * cosLat)),
                altitude: 0,
                speed: speeds[i],
                course: -1,
                horizontalAccuracy: accuracy
            )
        }
    }

    /// A road with a stop in the middle of it: `before` metres, standing
    /// still for `duration`, then `after` metres.
    static func stopping(
        before: Double,
        duration: TimeInterval,
        after: Double,
        speed: Double
    ) -> [Sample] {
        var points: [(x: Double, y: Double)] = []
        var times: [Double] = []
        var speeds: [Double] = []
        var t = 0.0
        var y = 0.0
        while y <= before {
            points.append((x: 0, y: y))
            times.append(t)
            speeds.append(speed)
            y += speed / 10                     // 10 Hz, like the recorder
            t += 0.1
        }
        for _ in 0..<Int(duration * 10) {
            points.append((x: 0, y: y))
            times.append(t)
            speeds.append(0)
            t += 0.1
        }
        let end = y + after
        while y <= end {
            points.append((x: 0, y: y))
            times.append(t)
            speeds.append(speed)
            y += speed / 10
            t += 0.1
        }
        return samples(points: points, times: times, speeds: speeds)
    }

    /// Turns local metres into samples, spacing them in time by the speed.
    static func samples(
        points: [(x: Double, y: Double)],
        speed: Double,
        accuracy: Double = 5,
        altitude: (Int) -> Double = { _ in 0 }
    ) -> [Sample] {
        var out: [Sample] = []
        var t = 0.0
        let cosLat = cos(Angles.radians(origin.lat))
        for (i, p) in points.enumerated() {
            if i > 0 {
                let previous = points[i - 1]
                let dx = p.x - previous.x
                let dy = p.y - previous.y
                t += (dx * dx + dy * dy).squareRoot() / speed
            }
            out.append(
                Sample(
                    t: t,
                    lat: origin.lat + Angles.degrees(p.y / Geo.earthRadius),
                    lon: origin.lon + Angles.degrees(p.x / (Geo.earthRadius * cosLat)),
                    altitude: altitude(i),
                    speed: speed,
                    course: -1,
                    horizontalAccuracy: accuracy
                )
            )
        }
        return out
    }
}
