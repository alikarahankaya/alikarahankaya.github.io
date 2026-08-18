import SwiftUI
import Analysis

/// Signed curvature against distance, drawn as a seismograph: right corners
/// above the axis, left corners below.
///
/// Dense, honest information rendered as texture. A mountain pass and a
/// motorway produce visibly different objects, which is the whole point — so
/// it stays hairline-precise and never gets rounded off or animated.
public struct RhythmStripView: View {
    public var rhythm: [RhythmSample]
    public var palette: Palette
    /// 0...1 for the replay: the strip fills in behind the dot.
    public var progress: Double

    public init(rhythm: [RhythmSample], palette: Palette, progress: Double = 1) {
        self.rhythm = rhythm
        self.palette = palette
        self.progress = progress
    }

    public var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            guard rhythm.count > 1, let total = rhythm.last?.distance, total > 0 else { return }
            let middle = size.height / 2
            let amplitude = size.height / 2
            let limit = total * min(1, max(0, progress))

            func x(_ distance: Double) -> CGFloat {
                CGFloat(distance / total) * size.width
            }

            // Two fills rather than one: a single path through a signed
            // waveform crosses itself at every change of direction, and the
            // winding rule then decides what the road looked like.
            for side in [1.0, -1.0] {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: middle))
                for sample in rhythm where sample.distance <= limit {
                    let value = side > 0 ? max(0, sample.value) : min(0, sample.value)
                    path.addLine(
                        to: CGPoint(x: x(sample.distance), y: middle - CGFloat(value) * amplitude)
                    )
                }
                path.addLine(to: CGPoint(x: x(limit), y: middle))
                path.closeSubpath()
                context.fill(path, with: .color(palette.textureColor))
            }

            var axis = Path()
            axis.move(to: CGPoint(x: 0, y: middle))
            axis.addLine(to: CGPoint(x: x(limit), y: middle))
            context.stroke(
                axis,
                with: .color(palette.neutralColor),
                style: StrokeStyle(lineWidth: 0.5)
            )
        }
    }
}

extension RhythmStripView: Animatable {
    public var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
}
