import Foundation
import Core

/// One point of the road after conditioning: evenly spaced by distance,
/// smoothed, and carrying what the drive was doing there.
public struct PathPoint: Sendable, Equatable {
    /// Metres travelled since the start of the drive.
    public var s: Double
    /// Smoothed position on the local tangent plane.
    public var position: Point2
    /// Position before smoothing, kept so the trace can be drawn from the
    /// road as recorded rather than as filtered.
    public var raw: Point2
    public var t: TimeInterval
    public var speed: Double
    /// The lowest speed seen since the previous point. A stop takes time but
    /// no distance, so resampling by distance would otherwise step straight
    /// over it and flow would never notice the car stood still.
    public var minimumSpeed: Double
    public var altitude: Double
    public var lateralG: Double?
    public var lat: Double
    public var lon: Double
}

public enum Conditioning {
    /// Raw samples in, road out: bad fixes dropped, missing speeds filled,
    /// resampled to one point per metre, smoothed.
    public static func path(from samples: [Sample]) -> [PathPoint] {
        let usable = usableSamples(samples)
        guard usable.count >= 2 else { return [] }
        let speeds = filledSpeeds(usable)
        let projected = Geo.project(usable)
        let resampled = resample(usable, projected: projected, speeds: speeds)
        return smoothed(resampled)
    }

    static func usableSamples(_ samples: [Sample]) -> [Sample] {
        var out: [Sample] = []
        out.reserveCapacity(samples.count)
        for s in samples {
            guard s.lat.isFinite, s.lon.isFinite, abs(s.lat) <= 90, abs(s.lon) <= 180 else {
                continue
            }
            // A negative accuracy means the fix carried no position at all.
            guard s.horizontalAccuracy >= 0,
                  s.horizontalAccuracy <= Tuning.maximumHorizontalAccuracy else { continue }
            // Time must run forwards, or resampling walks backwards.
            if let last = out.last, s.t <= last.t { continue }
            out.append(s)
        }
        return out
    }

    /// A fix may arrive without a speed. Falling back to the distance between
    /// neighbours is close enough: the number is used for lateral g and for
    /// spotting stops, not for anything that needs precision.
    static func filledSpeeds(_ samples: [Sample]) -> [Double] {
        samples.indices.map { i in
            if samples[i].hasValidSpeed { return samples[i].speed }
            let a = samples[max(0, i - 1)]
            let b = samples[min(samples.count - 1, i + 1)]
            let dt = b.t - a.t
            guard dt > 0 else { return 0 }
            let d = Geo.distance(fromLat: a.lat, lon: a.lon, toLat: b.lat, lon: b.lon)
            return d / dt
        }
    }

    static func resample(
        _ samples: [Sample],
        projected: [Point2],
        speeds: [Double]
    ) -> [PathPoint] {
        let spacing = Tuning.resampleSpacing
        var out: [PathPoint] = []
        out.reserveCapacity(1000)
        out.append(
            PathPoint(
                s: 0,
                position: projected[0],
                raw: projected[0],
                t: samples[0].t,
                speed: speeds[0],
                minimumSpeed: speeds[0],
                altitude: samples[0].altitude,
                lateralG: samples[0].lateralG,
                lat: samples[0].lat,
                lon: samples[0].lon
            )
        )
        var carry = 0.0     // distance since the last emitted point
        var total = 0.0     // distance at the start of the current segment
        var minimumSpeed = speeds[0]
        for i in 0..<(samples.count - 1) {
            minimumSpeed = min(minimumSpeed, speeds[i])
            let a = projected[i]
            let b = projected[i + 1]
            let segment = a.distance(to: b)
            guard segment > 1e-9 else { continue }
            var pos = spacing - carry
            while pos <= segment + 1e-9 {
                let f = pos / segment
                let here = Point2(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
                let speed = interpolate(speeds[i], speeds[i + 1], f)
                out.append(
                    PathPoint(
                        s: total + pos,
                        position: here,
                        raw: here,
                        t: interpolate(samples[i].t, samples[i + 1].t, f),
                        speed: speed,
                        minimumSpeed: min(minimumSpeed, speed),
                        altitude: interpolate(samples[i].altitude, samples[i + 1].altitude, f),
                        lateralG: interpolate(samples[i].lateralG, samples[i + 1].lateralG, f),
                        lat: interpolate(samples[i].lat, samples[i + 1].lat, f),
                        lon: interpolate(samples[i].lon, samples[i + 1].lon, f)
                    )
                )
                minimumSpeed = speed
                pos += spacing
            }
            carry = segment - (pos - spacing)
            total += segment
        }
        return out
    }

    private static func interpolate(_ a: Double, _ b: Double, _ f: Double) -> Double {
        a + (b - a) * f
    }

    private static func interpolate(_ a: Double?, _ b: Double?, _ f: Double) -> Double? {
        switch (a, b) {
        case (let x?, let y?): return x + (y - x) * f
        case (let x?, nil): return x
        case (nil, let y?): return y
        case (nil, nil): return nil
        }
    }

    /// Savitzky–Golay over arc length. The window shrinks at the ends so the
    /// filter stays symmetric rather than dragging the first and last points
    /// sideways.
    static func smoothed(_ points: [PathPoint]) -> [PathPoint] {
        let n = points.count
        guard n > 5 else { return points }
        var cache: [Int: [Double]] = [:]
        var out = points
        for i in 0..<n {
            let half = min(i, n - 1 - i, Tuning.smoothingHalfWidth)
            guard half >= 2 else { continue }
            let w: [Double]
            if let cached = cache[half] {
                w = cached
            } else {
                w = SavitzkyGolay.weights(halfWidth: half, order: Tuning.smoothingOrder)
                cache[half] = w
            }
            var x = 0.0
            var y = 0.0
            for k in 0...(2 * half) {
                x += w[k] * points[i - half + k].position.x
                y += w[k] * points[i - half + k].position.y
            }
            out[i].position = Point2(x: x, y: y)
        }
        return out
    }
}
