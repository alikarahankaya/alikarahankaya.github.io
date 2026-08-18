import Foundation
import Core

/// A point of the drawing. Normalised to the unit square with the aspect
/// ratio preserved, so the view only has to decide how big to draw it.
public struct TracePoint: Sendable, Codable, Equatable {
    /// 0...1 across, east positive.
    public var x: Double
    /// 0...1 up, north positive. Views flip this; screens grow downwards.
    public var y: Double
    /// Metres from the start of the drive, so the replay dot knows where it is.
    public var distance: Double
    /// 0...1 lateral load, which the stroke weight follows: the line thickens
    /// through hard corners and thins on the straights.
    public var intensity: Double
}

/// One column of the rhythm strip.
public struct RhythmSample: Sendable, Codable, Equatable {
    public var distance: Double
    /// -1...1. Right corners positive, left negative.
    public var value: Double
}

public enum TraceBuilder {
    /// Lateral load that counts as a full-strength stroke. 0.6 g is a firm
    /// corner in a road car on a public road; above that the line is simply
    /// at its thickest.
    static let fullIntensityG: Double = 0.6

    /// The tightest corner the rhythm strip draws at full height: radius 15 m,
    /// a first-gear hairpin.
    static let fullHeightCurvature: Double = 1.0 / 15.0

    public static func trace(
        points: [PathPoint],
        curvature: [Double],
        useIMU: Bool,
        maximum: Int = Tuning.maximumTracePoints
    ) -> (points: [TracePoint], aspect: Double) {
        guard points.count > 1 else { return ([], 1) }
        var minX = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude
        var minY = Double.greatestFiniteMagnitude
        var maxY = -Double.greatestFiniteMagnitude
        for p in points {
            minX = min(minX, p.position.x)
            maxX = max(maxX, p.position.x)
            minY = min(minY, p.position.y)
            maxY = max(maxY, p.position.y)
        }
        let width = maxX - minX
        let height = maxY - minY
        let scale = max(width, height)
        guard scale > 1 else { return ([], 1) }

        // Simplify geometrically rather than by taking every nth point: a
        // stride long enough to fit a long drive would cut the corners off
        // the hairpins, which are the whole picture.
        let indices = simplified(points.map(\.position), maximum: maximum, extent: scale)
        let centreX = (minX + maxX) / 2
        let centreY = (minY + maxY) / 2
        let trace = indices.map { i -> TracePoint in
            let p = points[i]
            let g: Double
            if useIMU, let measured = p.lateralG {
                g = abs(measured)
            } else {
                g = abs(Curvature.lateralG(speed: p.speed, curvature: curvature[i]))
            }
            return TracePoint(
                x: 0.5 + (p.position.x - centreX) / scale,
                y: 0.5 + (p.position.y - centreY) / scale,
                distance: p.s,
                intensity: min(1, g / fullIntensityG)
            )
        }
        return (trace, height > 0 ? width / height : 1)
    }

    public static func rhythm(
        points: [PathPoint],
        curvature: [Double],
        maximum: Int = Tuning.maximumRhythmPoints
    ) -> [RhythmSample] {
        guard !points.isEmpty else { return [] }
        let stride = max(1, points.count / maximum)
        var out: [RhythmSample] = []
        out.reserveCapacity(points.count / stride + 1)
        var i = 0
        while i < points.count {
            let end = min(points.count, i + stride)
            // Keep the sharpest curvature in each bucket. Averaging would
            // sand the hairpins down to nothing, which is exactly the
            // information the strip exists to show.
            var peak = 0.0
            for j in i..<end where abs(curvature[j]) > abs(peak) { peak = curvature[j] }
            // Square root compression: without it a 300 m sweeper is a
            // twentieth the height of a hairpin and reads as flat. Height
            // still ranks corners by severity, just legibly.
            let magnitude = min(1, (abs(peak) / fullHeightCurvature).squareRoot())
            out.append(
                RhythmSample(
                    distance: points[i].s,
                    value: peak < 0 ? -magnitude : magnitude
                )
            )
            i = end
        }
        return out
    }

    /// Ramer–Douglas–Peucker, tightened until the result fits the budget.
    static func simplified(_ points: [Point2], maximum: Int, extent: Double) -> [Int] {
        guard points.count > maximum else { return Array(points.indices) }
        // Start well under a pixel on a 3× poster and back off if needed.
        var tolerance = extent / 4000
        for _ in 0..<12 {
            let kept = douglasPeucker(points, tolerance: tolerance)
            if kept.count <= maximum { return kept }
            tolerance *= 1.8
        }
        return douglasPeucker(points, tolerance: tolerance)
    }

    static func douglasPeucker(_ points: [Point2], tolerance: Double) -> [Int] {
        guard points.count > 2 else { return Array(points.indices) }
        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        var stack: [(Int, Int)] = [(0, points.count - 1)]
        while let (a, b) = stack.popLast() {
            guard b > a + 1 else { continue }
            let start = points[a]
            let end = points[b]
            let dx = end.x - start.x
            let dy = end.y - start.y
            let span = (dx * dx + dy * dy).squareRoot()
            var worst = 0.0
            var worstIndex = a
            for i in (a + 1)..<b {
                let p = points[i]
                let distance: Double
                if span < 1e-9 {
                    distance = p.distance(to: start)
                } else {
                    distance = abs(dy * p.x - dx * p.y + end.x * start.y - end.y * start.x) / span
                }
                if distance > worst {
                    worst = distance
                    worstIndex = i
                }
            }
            guard worst > tolerance else { continue }
            keep[worstIndex] = true
            stack.append((a, worstIndex))
            stack.append((worstIndex, b))
        }
        return points.indices.filter { keep[$0] }
    }
}
