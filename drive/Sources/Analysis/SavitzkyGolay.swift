import Foundation

/// Savitzky–Golay smoothing weights: fit a polynomial to a window by least
/// squares and take its value at the centre.
///
/// Used instead of a Kalman filter because the thing being smoothed is a
/// shape, not a trajectory: the pipeline has already thrown time away by
/// resampling on distance, and a polynomial fit over arc length preserves
/// curvature far better than a moving average does.
enum SavitzkyGolay {
    /// Weights for a window of `2 * halfWidth + 1` evenly spaced points.
    static func weights(halfWidth: Int, order: Int) -> [Double] {
        let order = min(order, 2 * halfWidth)
        let n = order + 1
        // Normal equations A c = b for the fit, where A[r][c] = Σ i^(r+c).
        var a = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
        for r in 0..<n {
            for c in 0..<n {
                var sum = 0.0
                for i in -halfWidth...halfWidth {
                    sum += pow(Double(i), Double(r + c))
                }
                a[r][c] = sum
            }
        }
        // The fitted value at the centre is the constant term, so only the
        // first row of A⁻¹ is needed; weights are Σ_r inv[0][r] · i^r.
        let inv0 = firstRowOfInverse(a)
        return (-halfWidth...halfWidth).map { i in
            (0..<n).reduce(0.0) { $0 + inv0[$1] * pow(Double(i), Double($1)) }
        }
    }

    /// Gauss–Jordan on [A | e₀]. A is symmetric and well conditioned for the
    /// window sizes used here, so no pivoting subtleties are needed beyond
    /// picking the largest pivot.
    private static func firstRowOfInverse(_ a: [[Double]]) -> [Double] {
        let n = a.count
        var m = a.enumerated().map { row -> [Double] in
            row.element + (0..<n).map { $0 == 0 ? 1.0 : 0.0 }
        }
        for col in 0..<n {
            var pivot = col
            for r in col..<n where abs(m[r][col]) > abs(m[pivot][col]) { pivot = r }
            m.swapAt(col, pivot)
            let p = m[col][col]
            guard abs(p) > 1e-12 else { continue }
            for c in 0..<(2 * n) { m[col][c] /= p }
            for r in 0..<n where r != col {
                let f = m[r][col]
                guard f != 0 else { continue }
                for c in 0..<(2 * n) { m[r][c] -= f * m[col][c] }
            }
        }
        return (0..<n).map { m[$0][n] }
    }
}
