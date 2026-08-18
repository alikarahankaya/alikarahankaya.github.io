import Foundation

/// Works out the phone's orientation in the car from the motion it sees.
///
/// Pure state machine over numbers, so it can be tested without a car, a
/// phone, or CoreMotion. Capture feeds it; it hands back a frame when it has
/// seen enough, and takes the frame away again if the phone is knocked.
///
/// The method, in two steps:
///   1. Down is where gravity points, averaged over quiet moments.
///   2. Forward is where the car pushes you back into the seat: during a
///      sustained straight-line acceleration, the horizontal part of user
///      acceleration points forward.
public struct VehicleFrameSolver: Sendable {
    public struct Input: Sendable {
        /// Seconds since drive start.
        public var t: TimeInterval
        /// Gravity in device frame, in g (CMDeviceMotion.gravity).
        public var gravity: Vector3
        /// User acceleration in device frame, in g (CMDeviceMotion.userAcceleration).
        public var userAcceleration: Vector3
        /// Metres per second, negative when unknown.
        public var speed: Double
        /// Degrees from true north, negative when unknown.
        public var course: Double

        public init(
            t: TimeInterval,
            gravity: Vector3,
            userAcceleration: Vector3,
            speed: Double,
            course: Double
        ) {
            self.t = t
            self.gravity = gravity
            self.userAcceleration = userAcceleration
            self.speed = speed
            self.course = course
        }
    }

    public enum Tuning {
        /// Gravity is only averaged while the car is not shoving the phone
        /// around. 0.15 g is gentle traffic; anything harder is left out.
        public static let quietUserAcceleration = 0.15
        /// Two seconds at 10 Hz is twenty readings — enough to average out
        /// the noise, short enough to be solved before the first corner.
        public static let downSettleDuration: TimeInterval = 2.0
        /// A course this stable is a straight road, not a long sweeper.
        /// ±3° is about the heading noise of a good GPS fix at speed.
        public static let straightCourseTolerance = 3.0
        /// Below this the reported course is mostly noise, so "straight"
        /// cannot be established. 5 m/s is 18 km/h.
        public static let minimumSpeedForCourse = 5.0
        /// Three seconds of pulling away in a straight line. Shorter runs
        /// pick up gear changes and road camber instead of the car's axis.
        public static let straightRunDuration: TimeInterval = 3.0
        /// The run must actually be an acceleration, not a cruise: 2 m/s
        /// gained is a firm squeeze of throttle rather than drift in the fix.
        public static let straightRunSpeedGain = 2.0
        /// Below this there is no push to point at.
        public static let minimumForwardAcceleration = 0.03
        /// The phone was knocked. Ten degrees is well past mount flex and
        /// well short of anything a road surface produces.
        public static let driftLimit = 10.0
        /// Drift has to hold, or one pothole recalibrates the drive.
        public static let driftDuration: TimeInterval = 2.0
    }

    /// The frame, once solved. Nil until then, and again after a knock.
    public private(set) var frame: VehicleFrame?
    /// How many times the frame has been solved. Useful for logging only.
    public private(set) var solveCount = 0

    private var gravitySum = Vector3.zero
    private var gravitySamples = 0
    private var gravityFirstQuietTime: TimeInterval?
    private var lastQuietTime: TimeInterval = 0

    private var forwardSum = Vector3.zero
    private var forwardSamples = 0

    // The straight-line acceleration run currently being watched.
    private var runStartTime: TimeInterval?
    private var runStartSpeed = 0.0
    private var runCourse = 0.0
    private var runSum = Vector3.zero
    private var runSamples = 0

    private var driftStart: TimeInterval?

    public init() {}

    /// Feeds one motion sample in. Returns the frame currently in force.
    @discardableResult
    public mutating func add(_ input: Input) -> VehicleFrame? {
        updateDown(input)
        if let frame { checkDrift(frame: frame, input: input) }
        updateForward(input)
        trySolve()
        return frame
    }

    /// Throws away the solution and starts again. Called when the phone moves
    /// in its mount.
    public mutating func reset() {
        frame = nil
        gravitySum = .zero
        gravitySamples = 0
        gravityFirstQuietTime = nil
        lastQuietTime = 0
        forwardSum = .zero
        forwardSamples = 0
        cancelRun()
        driftStart = nil
    }

    private mutating func updateDown(_ input: Input) {
        guard input.userAcceleration.length < Tuning.quietUserAcceleration else { return }
        if gravityFirstQuietTime == nil { gravityFirstQuietTime = input.t }
        lastQuietTime = input.t
        gravitySum += input.gravity
        gravitySamples += 1
    }

    private var downIsSettled: Bool {
        guard let start = gravityFirstQuietTime, gravitySamples > 0 else { return false }
        return lastQuietTime - start >= Tuning.downSettleDuration
    }

    private mutating func updateForward(_ input: Input) {
        guard gravitySamples > 0, let down = gravitySum.normalized else { return }
        guard input.speed >= Tuning.minimumSpeedForCourse, input.course >= 0 else {
            cancelRun()
            return
        }

        if let start = runStartTime {
            let straight = abs(Angles.difference(input.course, runCourse))
                <= Tuning.straightCourseTolerance
            guard straight, input.speed >= runStartSpeed else {
                cancelRun()
                startRun(input)
                return
            }
            runSum += input.userAcceleration.orthogonalized(to: down)
            runSamples += 1
            let long = input.t - start >= Tuning.straightRunDuration
            let faster = input.speed - runStartSpeed >= Tuning.straightRunSpeedGain
            if long, faster, runSamples > 0 {
                // Commit this run's average push as one vote for forward.
                forwardSum += runSum / Double(runSamples)
                forwardSamples += 1
                cancelRun()
            }
        } else {
            startRun(input)
        }
    }

    private mutating func startRun(_ input: Input) {
        runStartTime = input.t
        runStartSpeed = input.speed
        runCourse = input.course
        runSum = .zero
        runSamples = 0
    }

    private mutating func cancelRun() {
        runStartTime = nil
        runSamples = 0
        runSum = .zero
    }

    private mutating func trySolve() {
        guard frame == nil, downIsSettled, forwardSamples > 0 else { return }
        let hint = forwardSum / Double(forwardSamples)
        guard hint.length >= Tuning.minimumForwardAcceleration else { return }
        guard let solved = VehicleFrame(down: gravitySum, forwardHint: hint) else { return }
        frame = solved
        solveCount += 1
    }

    private mutating func checkDrift(frame: VehicleFrame, input: Input) {
        guard frame.drift(from: input.gravity) > Tuning.driftLimit else {
            driftStart = nil
            return
        }
        if let start = driftStart {
            if input.t - start >= Tuning.driftDuration { reset() }
        } else {
            driftStart = input.t
        }
    }
}
