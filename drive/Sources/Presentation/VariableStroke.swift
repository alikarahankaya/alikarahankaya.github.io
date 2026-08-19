import SwiftUI

/// One line whose weight follows how hard the car was working.
///
/// The artifact draws it against distance, the live ribbon draws it against
/// time, and they are the same line: thick through load, hairline when
/// nothing is happening. Sharing the drawing is what makes the two screens
/// read as one object rather than two features.
enum VariableStroke {
    /// `points` are positions paired with a 0...1 load.
    static func draw(
        _ context: inout GraphicsContext,
        points: [(point: CGPoint, load: Double)],
        color: Color,
        thinnest: Double,
        thickest: Double
    ) {
        guard points.count > 1 else { return }
        for i in 1..<points.count {
            var segment = Path()
            segment.move(to: points[i - 1].point)
            segment.addLine(to: points[i].point)
            let load = min(1, max(0, (points[i - 1].load + points[i].load) / 2))
            context.stroke(
                segment,
                with: .color(color),
                style: StrokeStyle(
                    lineWidth: thinnest + (thickest - thinnest) * load,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }
}
