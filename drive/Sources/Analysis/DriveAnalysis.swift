import Foundation
import Core

/// Everything the artifact needs, and nothing about how it is drawn.
///
/// Cached alongside the raw samples, and recomputable from them at any time:
/// when `schemaVersion` no longer matches, the cache is thrown away and the
/// drive is analysed again. Raw data is the record; this is an opinion about
/// it, and opinions get better.
public struct DriveAnalysis: Sendable, Codable, Equatable {
    /// Bump whenever the pipeline's output changes meaningfully.
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    /// Metres of road actually driven.
    public var distance: Double
    public var duration: TimeInterval
    public var sinuosity: Double
    public var corners: [Corner]
    /// Corners per kilometre.
    public var cornerDensity: Double
    /// The headline: longest unbroken sequence of corners, in metres.
    public var flowDistance: Double
    public var leftMetres: Double
    public var rightMetres: Double
    public var elevationGain: Double
    public var elevationLoss: Double
    public var light: Light
    public var solarAltitude: Double
    /// Halfway along the road, which is where the weather and the place name
    /// are asked about — the start of a drive is usually a driveway.
    public var midpoint: Coordinate
    public var midpointTime: Date
    public var trace: [TracePoint]
    /// Width over height of the trace, in metres, for fitting it to a frame.
    public var traceAspect: Double
    public var rhythm: [RhythmSample]
    /// IMU lateral g over GPS lateral g across the drive. Nil when there was
    /// nothing to compare.
    public var imuAgreement: Double?
    public var imuTrusted: Bool

    public init(
        schemaVersion: Int,
        distance: Double,
        duration: TimeInterval,
        sinuosity: Double,
        corners: [Corner],
        cornerDensity: Double,
        flowDistance: Double,
        leftMetres: Double,
        rightMetres: Double,
        elevationGain: Double,
        elevationLoss: Double,
        light: Light,
        solarAltitude: Double,
        midpoint: Coordinate,
        midpointTime: Date,
        trace: [TracePoint],
        traceAspect: Double,
        rhythm: [RhythmSample],
        imuAgreement: Double?,
        imuTrusted: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.distance = distance
        self.duration = duration
        self.sinuosity = sinuosity
        self.corners = corners
        self.cornerDensity = cornerDensity
        self.flowDistance = flowDistance
        self.leftMetres = leftMetres
        self.rightMetres = rightMetres
        self.elevationGain = elevationGain
        self.elevationLoss = elevationLoss
        self.light = light
        self.solarAltitude = solarAltitude
        self.midpoint = midpoint
        self.midpointTime = midpointTime
        self.trace = trace
        self.traceAspect = traceAspect
        self.rhythm = rhythm
        self.imuAgreement = imuAgreement
        self.imuTrusted = imuTrusted
    }

    public var cornerCount: Int { corners.count }

    /// 0 = every corner turns left, 1 = every corner turns right, 0.5 = even.
    public var directionBalance: Double {
        let total = leftMetres + rightMetres
        guard total > 0 else { return 0.5 }
        return rightMetres / total
    }
}

public enum DriveAnalyser {
    /// The whole pipeline: samples in, artifact out.
    ///
    /// `startedAt` is passed in rather than read from a clock, so the same
    /// samples always produce the same analysis.
    public static func analyse(samples: [Sample], startedAt: Date) -> DriveAnalysis? {
        let path = Conditioning.path(from: samples)
        guard path.count > 2 * Tuning.curvatureArm + 2 else { return nil }

        let curvature = Curvature.signed(path)
        let agreement = imuAgreement(path: path, curvature: curvature)
        let trusted = agreement.map { abs($0 - 1) <= Tuning.imuAgreementTolerance } ?? false

        let corners = Segmentation.corners(
            points: path,
            curvature: curvature,
            useIMU: trusted
        )
        let distance = path[path.count - 1].s
        let elevation = DriveCharacter.elevation(points: path)
        let direction = DriveCharacter.directionMetres(corners: corners)
        let middle = path[path.count / 2]
        let midpointTime = startedAt.addingTimeInterval(middle.t)
        let (trace, aspect) = TraceBuilder.trace(
            points: path,
            curvature: curvature,
            useIMU: trusted
        )

        return DriveAnalysis(
            schemaVersion: DriveAnalysis.currentSchemaVersion,
            distance: distance,
            duration: path[path.count - 1].t - path[0].t,
            sinuosity: DriveCharacter.sinuosity(points: path),
            corners: corners,
            cornerDensity: distance > 0 ? Double(corners.count) / (distance / 1000) : 0,
            flowDistance: DriveCharacter.flowDistance(corners: corners, points: path),
            leftMetres: direction.left,
            rightMetres: direction.right,
            elevationGain: elevation.gain,
            elevationLoss: elevation.loss,
            light: Solar.light(at: midpointTime, lat: middle.lat, lon: middle.lon),
            solarAltitude: Solar.altitude(at: midpointTime, lat: middle.lat, lon: middle.lon),
            midpoint: Coordinate(lat: middle.lat, lon: middle.lon),
            midpointTime: midpointTime,
            trace: trace,
            traceAspect: aspect,
            rhythm: TraceBuilder.rhythm(points: path, curvature: curvature),
            imuAgreement: agreement,
            imuTrusted: trusted
        )
    }

    /// How well the IMU's lateral g matches what the road and the speed say
    /// it should be. Only hard cornering takes part: at 0.05 g both numbers
    /// are mostly noise and the ratio between them means nothing.
    ///
    /// The result is logged, never shown. A driver should not have to know
    /// their phone slipped in its mount.
    static func imuAgreement(path: [PathPoint], curvature: [Double]) -> Double? {
        var imu = 0.0
        var gps = 0.0
        var count = 0
        for i in path.indices {
            guard let measured = path[i].lateralG else { continue }
            let inferred = abs(Curvature.lateralG(speed: path[i].speed, curvature: curvature[i]))
            guard inferred >= Tuning.imuComparisonMinimumG else { continue }
            imu += abs(measured)
            gps += inferred
            count += 1
        }
        // A handful of points is not a drive's worth of evidence.
        guard count >= 100, gps > 0 else { return nil }
        return imu / gps
    }
}
