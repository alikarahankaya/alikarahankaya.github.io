import SwiftUI
import Analysis

/// The road, drawn as a line and nothing else.
///
/// No map tiles, no basemap, no labels, no north arrow. Stripped of the map,
/// a driven road becomes a drawing, and a good road makes a good one. This is
/// the one loud thing in the app, so everything around it stays quiet.
///
/// Deliberately not MapKit: a map would put the road back into the world and
/// take the drawing away. MapKit belongs in the "where was this" sheet.
public struct TraceView: View {
    /// The points, already normalised to the unit square with the aspect
    /// ratio preserved, so this view only has to decide how big to draw them.
    public var trace: [TracePoint]
    public var palette: Palette
    /// 0...1 for the replay. 1 draws the finished road.
    public var progress: Double
    /// The travelling dot, during replay only.
    public var showsHead: Bool

    public init(
        trace: [TracePoint],
        palette: Palette,
        progress: Double = 1,
        showsHead: Bool = false
    ) {
        self.trace = trace
        self.palette = palette
        self.progress = progress
        self.showsHead = showsHead
    }

    /// Stroke weight as a fraction of the frame, so the line looks the same
    /// on a phone and on a 3× poster. The thin end is a hairline on a
    /// straight; the thick end is 0.6 g of corner.
    private static let thinnest = 0.0045
    private static let thickest = 0.0150
    /// Room for the stroke, and for the drawing to breathe.
    private static let inset = 0.05

    public var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            guard trace.count > 1 else { return }
            let side = min(size.width, size.height) * (1 - 2 * Self.inset)
            let originX = (size.width - side) / 2
            let originY = (size.height - side) / 2
            func place(_ p: TracePoint) -> CGPoint {
                // Screens grow downwards and roads do not: flip y so north is up.
                CGPoint(x: originX + p.x * side, y: originY + (1 - p.y) * side)
            }

            let total = trace[trace.count - 1].distance
            let limit = total * min(1, max(0, progress))
            var last = place(trace[0])
            for i in 1..<trace.count {
                let point = trace[i]
                guard point.distance <= limit else { break }
                let here = place(point)
                var segment = Path()
                segment.move(to: last)
                segment.addLine(to: here)
                let load = (trace[i - 1].intensity + point.intensity) / 2
                context.stroke(
                    segment,
                    with: .color(palette.inkColor),
                    style: StrokeStyle(
                        lineWidth: side * (Self.thinnest + (Self.thickest - Self.thinnest) * load),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                last = here
            }

            if showsHead, progress < 1 {
                let radius = side * 0.013
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: last.x - radius,
                        y: last.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )),
                    with: .color(palette.inkColor)
                )
            }
        }
    }
}

extension TraceView: Animatable {
    /// Makes `progress` the thing SwiftUI interpolates, so the replay draws
    /// the road in frame by frame instead of jumping to the end.
    public var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
}
