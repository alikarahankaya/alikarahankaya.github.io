import SwiftUI
import Core

/// What is on screen while the car is moving.
///
/// One line, and a number that is not always there.
///
/// The line is the same line the artifact draws, turned ninety degrees in
/// meaning: it runs left to right through the last forty-five seconds, it
/// rises when you accelerate and falls when you brake, and it thickens with
/// how hard the car is cornering. Nothing on this screen has to be read. At a
/// steady cruise the line flattens to a hairline and the number is gone, so
/// the screen empties itself without being told to.
///
/// What is deliberately not here: speed, distance, elapsed time, corner
/// count, a map, a button. Elapsed time is on the lock screen where it costs
/// nothing. The rest would each be a reason to look down.
public struct LiveDriveView: View {
    public var telemetry: LiveTelemetry
    public var onStop: () -> Void

    @State private var isStopping = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(telemetry: LiveTelemetry, onStop: @escaping () -> Void) {
        self.telemetry = telemetry
        self.onStop = onStop
    }

    /// Held this long, the drive ends. Long enough that a hand resting on the
    /// phone cannot do it by accident.
    private static let stopHold: Double = 1.5
    /// The ribbon at its quietest and its hardest, as a fraction of the frame.
    private static let thinnest = 0.004
    private static let thickest = 0.022
    /// How much of the half-height a full 0.6 g of acceleration uses. The
    /// rest is air, so a hard stop still has somewhere to go.
    private static let deflection = 0.55

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            palette.groundColor
                .ignoresSafeArea()
            ribbon
            number
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: Self.stopHold) {
            onStop()
        } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: pressing ? Self.stopHold : 0.25)) {
                isStopping = pressing
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Recording")
        .accessibilityValue(spokenValue)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityAction(named: "Stop recording", onStop)
        .preferredColorScheme(palette.colorScheme)
        .statusBarHidden()
    }

    private var palette: Palette { telemetry.palette }

    private var ribbon: some View {
        // Read out of the model here, in the body, rather than inside the
        // Canvas closure: observation only notices what the body touches, and
        // a ribbon that never redraws is a very quiet bug.
        let readings = telemetry.readings
        let window = telemetry.window
        let palette = self.palette
        return Canvas(rendersAsynchronously: false) { context, size in
            let middle = size.height / 2
            let amplitude = middle * Self.deflection
            let span = min(size.width, size.height)

            // The one thing that is always drawn. Without it the screen looks
            // switched off rather than quiet, and the line has nothing to be
            // above or below.
            var axis = Path()
            axis.move(to: CGPoint(x: 0, y: middle))
            axis.addLine(to: CGPoint(x: size.width, y: middle))
            context.stroke(
                axis,
                with: .color(palette.neutral.mixed(with: palette.ground, amount: 0.55).color),
                style: StrokeStyle(lineWidth: 0.5)
            )

            guard let now = readings.last?.t else { return }
            let points = readings.map { reading -> (point: CGPoint, load: Double) in
                let age = now - reading.t
                let x = size.width * (1 - age / window)
                let g = (reading.longitudinalG ?? 0) / LiveTelemetry.fullScaleG
                let lateral = abs(reading.lateralG ?? 0) / LiveTelemetry.fullScaleG
                return (
                    point: CGPoint(x: x, y: middle - CGFloat(min(1, max(-1, g))) * amplitude),
                    load: min(1, lateral)
                )
            }
            VariableStroke.draw(
                &context,
                points: points,
                color: palette.signalColor,
                thinnest: span * Self.thinnest,
                thickest: span * Self.thickest
            )
        }
        // The whole drive fades out under a long press: the screen answers
        // the gesture, rather than a progress ring answering it.
        .opacity(isStopping ? 0.15 : 1)
    }

    @ViewBuilder
    private var number: some View {
        Text(Self.format(telemetry.peak))
            .font(.system(.largeTitle, design: .serif).monospacedDigit())
            .foregroundStyle(palette.neutralColor)
            .padding(.leading, 32)
            .padding(.bottom, 40)
            .opacity(telemetry.isWorking ? 1 : 0)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.5),
                value: telemetry.isWorking
            )
            .accessibilityHidden(true)
    }

    static func format(_ g: Double) -> String {
        String(format: "%.2f g", g)
    }

    private var spokenValue: String {
        guard telemetry.isCalibrated else { return "Finding the car's axes" }
        guard telemetry.isWorking else { return "Steady" }
        return Self.format(telemetry.peak)
    }
}

#if DEBUG
/// A minute of driving, so the ribbon can be watched without a car.
private struct LivePreviewHost: View {
    @State private var telemetry = LiveTelemetry()

    var body: some View {
        LiveDriveView(telemetry: telemetry) {}
            .task {
                for i in 0..<2000 {
                    let t = Double(i) / 17
                    telemetry.append(
                        LiveReading(
                            t: t,
                            lateralG: sin(t / 3) * 0.45,
                            longitudinalG: cos(t / 5) * 0.35,
                            speed: 20,
                            coordinate: Coordinate(lat: 46.5, lon: 11)
                        )
                    )
                    try? await Task.sleep(for: .milliseconds(59))
                }
            }
    }
}

#Preview("Live") {
    LivePreviewHost()
}
#endif
