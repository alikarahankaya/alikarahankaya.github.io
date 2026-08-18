import Foundation

/// Every number the analysis has an opinion about, in one place.
///
/// These are the app's argument about what a corner is and what makes a drive
/// good. They were set against the synthetic fixtures in `Tools/` (a 12 m
/// hairpin, 150–500 m sweepers, a 2 km-radius motorway bend) and they will
/// want arguing with once there is real road data to argue with.
public enum Tuning {
    // MARK: Conditioning

    /// Fixes worse than this are noise pretending to be a road. 20 m is where
    /// automotive GPS starts putting the car in the next field.
    public static let maximumHorizontalAccuracy: Double = 20

    /// Curvature is a property of the road, not of how fast it was driven, so
    /// the path is resampled by distance before anything is measured. One
    /// metre is fine enough for a hairpin and cheap enough for a long drive.
    public static let resampleSpacing: Double = 1

    /// Savitzky–Golay smoothing: a cubic fit over a 21 m window (±10 m).
    ///
    /// The window has to be small compared with the tightest radius worth
    /// keeping, or hairpins get flattened: a 31 m window pulls a 12 m hairpin
    /// in by about 15%, a 21 m window by well under 1% (measured on synthetic
    /// circles, Tools/reference_pipeline.py). It is still wide enough to sit
    /// on several seconds of fixes and swallow ordinary GPS wander.
    public static let smoothingHalfWidth = 10
    public static let smoothingOrder = 3

    // MARK: Curvature

    /// Menger curvature is taken over three points this far apart. Shorter
    /// arms resolve tighter corners but square the position noise; 15 m is
    /// the compromise that kept a 12 m hairpin intact without inventing
    /// corners on a motorway.
    public static let curvatureArm = 15

    // MARK: Corners

    /// A corner starts when the radius drops below 300 m. At 100 km/h that is
    /// 0.26 g — the point where a bend stops being scenery and starts being
    /// something you drive. Motorway sweepers (1 km radius and up) do not
    /// qualify, which is the intended answer.
    public static let cornerEnterCurvature: Double = 1.0 / 300.0

    /// It ends when the radius opens past 450 m. The hysteresis stops one
    /// long corner with a slight breath in the middle reading as two, and is
    /// applied at both ends so corners do not all look like they open.
    public static let cornerExitCurvature: Double = 1.0 / 450.0

    /// Anything shorter than this is a kink in the GPS trace, not a corner.
    public static let cornerMinimumLength: Double = 12

    /// Two same-direction corners this close together are one corner with a
    /// dip in it — a double apex, which the shape classifier will notice.
    public static let cornerMergeGap: Double = 20

    /// Radius bands for severity, rally convention: 1 is tightest.
    /// 1 hairpin, 2 first gear, 3 second, 4 third, 5 fast, 6 barely a corner.
    /// The last entry doubles as the detection threshold above.
    public static let severityRadii: [Double] = [15, 25, 40, 70, 120, 300]

    /// Shape: the last third of a corner has to be this much tighter than the
    /// first third before it counts as tightening. 15% is about the point
    /// where a driver would notice needing more lock.
    public static let shapeTightensRatio: Double = 1.15
    public static let shapeOpensRatio: Double = 0.87

    /// Double apex: two peaks within 20% of the corner's maximum, at least
    /// this fraction of the corner apart, with a real dip between them.
    public static let doubleApexPeakFraction: Double = 0.80
    public static let doubleApexSeparation: Double = 0.30
    public static let doubleApexDip: Double = 0.75
    /// Shorter corners cannot hold two apexes worth naming.
    public static let doubleApexMinimumLength: Double = 40

    // MARK: Character

    /// Flow breaks when the road goes quiet for longer than this. 150 m at a
    /// sensible pace is about five seconds — long enough that the rhythm is
    /// gone and you are just travelling again.
    public static let flowMaximumGap: Double = 150

    /// Below 2 m/s the car is stopped, whatever the GPS thinks. A stop ends
    /// the sequence no matter how short the gap.
    public static let flowStopSpeed: Double = 2

    /// GPS altitude is bad. Smoothing over ±50 m of road and ignoring changes
    /// under 0.5 m keeps the number from being pure noise. It is still only
    /// approximate, and is labelled as such in the interface.
    public static let elevationSmoothingHalfWidth = 50
    public static let elevationDeadband: Double = 0.5

    // MARK: IMU cross-check

    /// Lateral g from the IMU should match v²·κ from the GPS. Beyond 30%
    /// disagreement over a whole drive the vehicle frame is wrong (phone
    /// slipped, mount rotated) and the GPS figure is used instead.
    public static let imuAgreementTolerance: Double = 0.30
    /// Only corners hard enough to measure take part in the comparison.
    public static let imuComparisonMinimumG: Double = 0.15

    // MARK: Rendering data

    /// The trace and the rhythm strip are stored decimated: 1500 points is
    /// more than a 3× poster can resolve and keeps the cached analysis small.
    public static let maximumTracePoints = 1500
    public static let maximumRhythmPoints = 1500

    // MARK: Worth keeping

    /// Drives shorter than these are errands, not drives, and are discarded
    /// without asking.
    public static let minimumDriveDuration: TimeInterval = 3 * 60
    public static let minimumDriveDistance: Double = 2000
}
