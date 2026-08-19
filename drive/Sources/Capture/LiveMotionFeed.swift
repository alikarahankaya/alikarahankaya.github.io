import Foundation
import CoreMotion
import Core

/// Device motion at 50 Hz.
///
/// 50 Hz rather than the location rate because gravity and user acceleration
/// are averaged between fixes: averaging is what makes the vehicle-frame
/// solution stable, and there is nothing to average at 1 Hz.
public actor LiveMotionFeed: MotionFeed {
    /// Fast enough to average properly, slow enough not to matter to the
    /// battery next to the GPS.
    public static let sampleRate: Double = 50

    private let manager = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "motion"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    public init() {}

    public func readings() -> AsyncStream<MotionReading> {
        stop()
        guard manager.isDeviceMotionAvailable else {
            // A phone without a usable IMU still records a perfectly good
            // drive; lateral g simply comes from the road instead.
            return AsyncStream { $0.finish() }
        }
        let (stream, continuation) = AsyncStream<MotionReading>.makeStream()
        manager.deviceMotionUpdateInterval = 1 / Self.sampleRate
        manager.startDeviceMotionUpdates(to: queue) { motion, _ in
            guard let motion else { return }
            // Reduced to plain numbers here: CMDeviceMotion is a class and
            // must not travel.
            continuation.yield(
                MotionReading(
                    timestamp: motion.timestamp,
                    gravity: Vector3(motion.gravity.x, motion.gravity.y, motion.gravity.z),
                    userAcceleration: Vector3(
                        motion.userAcceleration.x,
                        motion.userAcceleration.y,
                        motion.userAcceleration.z
                    )
                )
            )
        }
        return stream
    }

    public func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
