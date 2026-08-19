#if DEBUG
import Foundation
import Core
import Analysis

/// A drive made of arithmetic, so the artifact can be looked at in a preview
/// without a car or a fixture file. Debug builds only.
public enum PreviewDrive {
    public static func sample(light: Light = .dusk) -> DrivePresentation {
        var trace: [TracePoint] = []
        var rhythm: [RhythmSample] = []
        var corners: [Corner] = []
        let count = 900
        for i in 0..<count {
            let f = Double(i) / Double(count - 1)
            let theta = f * 2 * .pi
            // A wandering closed curve: enough corners to look like a road.
            let x = 0.5 + 0.42 * sin(theta) * cos(theta * 0.5)
            let y = 0.5 + 0.42 * sin(theta * 1.5) * 0.9
            let load = abs(sin(theta * 6)) * 0.85
            trace.append(
                TracePoint(x: x, y: y, distance: f * 42_000, intensity: load)
            )
            rhythm.append(
                RhythmSample(distance: f * 42_000, value: sin(theta * 9) * load)
            )
        }
        for i in 0..<118 {
            corners.append(
                Corner(
                    entryDistance: Double(i) * 340,
                    length: 60,
                    direction: i.isMultiple(of: 2) ? .left : .right,
                    peakCurvature: 1.0 / 45,
                    severity: 4,
                    shape: .constant,
                    meanLateralG: 0.42
                )
            )
        }
        let analysis = DriveAnalysis(
            schemaVersion: DriveAnalysis.currentSchemaVersion,
            distance: 42_000,
            duration: 4_320,
            sinuosity: 1.87,
            corners: corners,
            cornerDensity: 2.8,
            flowDistance: 4_200,
            leftMetres: 1_800,
            rightMetres: 1_740,
            elevationGain: 890,
            elevationLoss: 870,
            light: light,
            solarAltitude: -2,
            midpoint: Coordinate(lat: 46.5, lon: 11.0),
            midpointTime: Date(timeIntervalSince1970: 1_718_219_700),
            trace: trace,
            traceAspect: 1,
            rhythm: rhythm,
            imuAgreement: 1.02,
            imuTrusted: true
        )
        return DrivePresentation(
            id: UUID(),
            startedAt: Date(timeIntervalSince1970: 1_718_219_700),
            timeZoneIdentifier: "Europe/Rome",
            analysis: analysis,
            weatherSummary: "12 °C · clear",
            placeName: "Passo Gardena"
        )
    }
}
#endif
