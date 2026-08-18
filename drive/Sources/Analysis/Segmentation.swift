import Foundation
import Core

public enum Segmentation {
    /// Cuts the curvature trace into corners.
    ///
    /// A corner is a maximal run where the curvature holds one sign and rises
    /// past the entry threshold. The run is grown outwards in both directions
    /// to the lower exit threshold, which keeps the two ends symmetric — do it
    /// only on the exit side and every corner appears to open.
    public static func corners(
        points: [PathPoint],
        curvature k: [Double],
        useIMU: Bool = false
    ) -> [Corner] {
        precondition(points.count == k.count, "curvature must be one value per path point")
        let runs = merged(runs(in: k, points: points), points: points)
        return runs.compactMap { corner(from: $0, points: points, curvature: k, useIMU: useIMU) }
    }

    struct Run {
        var start: Int
        var end: Int
        var direction: Direction
    }

    static func runs(in k: [Double], points: [PathPoint]) -> [Run] {
        var out: [Run] = []
        var i = 0
        while i < k.count {
            guard abs(k[i]) >= Tuning.cornerEnterCurvature else {
                i += 1
                continue
            }
            let direction: Direction = k[i] > 0 ? .right : .left
            var start = i
            while start - 1 >= 0,
                  abs(k[start - 1]) >= Tuning.cornerExitCurvature,
                  (k[start - 1] > 0 ? Direction.right : .left) == direction {
                start -= 1
            }
            var end = i
            while end + 1 < k.count,
                  abs(k[end + 1]) >= Tuning.cornerExitCurvature,
                  (k[end + 1] > 0 ? Direction.right : .left) == direction {
                end += 1
            }
            out.append(Run(start: start, end: end, direction: direction))
            i = end + 1
        }
        return out
    }

    static func merged(_ runs: [Run], points: [PathPoint]) -> [Run] {
        var out: [Run] = []
        for run in runs {
            if var last = out.last,
               last.direction == run.direction,
               points[run.start].s - points[last.end].s < Tuning.cornerMergeGap {
                last.end = run.end
                out[out.count - 1] = last
            } else {
                out.append(run)
            }
        }
        return out
    }

    static func corner(
        from run: Run,
        points: [PathPoint],
        curvature k: [Double],
        useIMU: Bool
    ) -> Corner? {
        let length = points[run.end].s - points[run.start].s
        guard length >= Tuning.cornerMinimumLength else { return nil }
        let range = run.start...run.end
        var peak = 0.0
        for i in range { peak = max(peak, abs(k[i])) }
        guard peak > 0 else { return nil }

        var gpsSum = 0.0
        var imuSum = 0.0
        var imuCount = 0
        for i in range {
            gpsSum += abs(Curvature.lateralG(speed: points[i].speed, curvature: k[i]))
            if let g = points[i].lateralG {
                imuSum += abs(g)
                imuCount += 1
            }
        }
        let count = Double(range.count)
        // The IMU measures what the car did; v²·κ infers it. Prefer the
        // measurement when it is trusted and covers most of the corner.
        let meanG = (useIMU && Double(imuCount) > count / 2)
            ? imuSum / Double(imuCount)
            : gpsSum / count

        return Corner(
            entryDistance: points[run.start].s,
            length: length,
            direction: run.direction,
            peakCurvature: peak,
            severity: Corner.severity(forRadius: 1 / peak),
            shape: shape(of: run, curvature: k, peak: peak),
            meanLateralG: meanG
        )
    }

    /// Shape from where the corner is tight, not from where the single
    /// highest sample happens to land: on a constant-radius corner the peak
    /// is wherever the noise put it, so comparing thirds is the only stable
    /// way to ask whether it tightens.
    static func shape(of run: Run, curvature k: [Double], peak: Double) -> CornerShape {
        let count = run.end - run.start + 1
        if isDoubleApex(run, curvature: k, peak: peak) { return .double }
        let third = max(1, count / 3)
        var head = 0.0
        var tail = 0.0
        for i in 0..<third {
            head += abs(k[run.start + i])
            tail += abs(k[run.end - i])
        }
        head /= Double(third)
        tail /= Double(third)
        guard head > 0 else { return .constant }
        let ratio = tail / head
        if ratio >= Tuning.shapeTightensRatio { return .tightens }
        if ratio <= Tuning.shapeOpensRatio { return .opens }
        return .constant
    }

    static func isDoubleApex(_ run: Run, curvature k: [Double], peak: Double) -> Bool {
        let count = run.end - run.start + 1
        guard Double(count) >= Tuning.doubleApexMinimumLength else { return false }
        // Group the samples that are near the peak; two apexes means two
        // groups, far enough apart, with a genuine dip between them.
        var groups: [(Int, Int)] = []
        var current: (Int, Int)?
        for i in run.start...run.end {
            if abs(k[i]) >= Tuning.doubleApexPeakFraction * peak {
                if let c = current, i == c.1 + 1 {
                    current = (c.0, i)
                } else {
                    if let c = current { groups.append(c) }
                    current = (i, i)
                }
            }
        }
        if let c = current { groups.append(c) }
        guard let first = groups.first, let last = groups.last, groups.count >= 2 else {
            return false
        }
        guard Double(last.0 - first.1) >= Tuning.doubleApexSeparation * Double(count) else {
            return false
        }
        var dip = Double.greatestFiniteMagnitude
        for i in first.1...last.0 { dip = min(dip, abs(k[i])) }
        var firstPeak = 0.0
        for i in first.0...first.1 { firstPeak = max(firstPeak, abs(k[i])) }
        var lastPeak = 0.0
        for i in last.0...last.1 { lastPeak = max(lastPeak, abs(k[i])) }
        return dip < Tuning.doubleApexDip * min(firstPeak, lastPeak)
    }
}
