import Foundation
import CoreMotion

/// Notices that a drive has begun, and that it has ended.
///
/// The phone already knows it is in a car — asking it is far cheaper than
/// leaving GPS running, and it means the driver never has to remember to
/// press anything.
public actor TripDetector {
    public enum Event: Sendable {
        case started
        case ended
    }

    public enum Tuning {
        /// Three minutes of not being in a car. Long enough to cover fuel
        /// stops, level crossings and a wait at a barrier; short enough that
        /// the drive is filed before you have unpacked the boot.
        public static let endAfter: TimeInterval = 3 * 60
        /// How often the clock is checked once the car has stopped being a
        /// car. Activity updates only arrive on change, so something has to
        /// watch the gap.
        public static let pollInterval: TimeInterval = 15
    }

    private let manager = CMMotionActivityManager()
    private let queue = OperationQueue()
    private var continuation: AsyncStream<Event>.Continuation?
    private var poller: Task<Void, Never>?
    private var isDriving = false
    private var lastAutomotive: Date?

    public init() {}

    public static var isAvailable: Bool { CMMotionActivityManager.isActivityAvailable() }

    public func events() -> AsyncStream<Event> {
        stop()
        let (stream, continuation) = AsyncStream<Event>.makeStream()
        self.continuation = continuation
        guard Self.isAvailable else {
            continuation.finish()
            return stream
        }
        manager.startActivityUpdates(to: queue) { activity in
            guard let activity else { return }
            // CMMotionActivity is a class: reduce it to two facts here.
            // High confidence only, as the brief asks. It costs a little
            // time at the start of a drive — medium arrives sooner — but a
            // false start records a bus ride.
            let automotive = activity.automotive && activity.confidence == .high
            Task { await self.observe(automotive: automotive, at: Date()) }
        }
        poller = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Tuning.pollInterval))
                await self?.checkForEnd(now: Date())
            }
        }
        return stream
    }

    public func stop() {
        manager.stopActivityUpdates()
        poller?.cancel()
        poller = nil
        continuation?.finish()
        continuation = nil
        isDriving = false
        lastAutomotive = nil
    }

    /// Called by the app when a drive is started or stopped by hand, so the
    /// detector does not immediately disagree.
    public func setDriving(_ driving: Bool) {
        isDriving = driving
        lastAutomotive = driving ? Date() : nil
    }

    private func observe(automotive: Bool, at date: Date) {
        if automotive {
            lastAutomotive = date
            guard !isDriving else { return }
            isDriving = true
            continuation?.yield(.started)
        }
    }

    private func checkForEnd(now: Date) {
        guard isDriving, let last = lastAutomotive else { return }
        guard now.timeIntervalSince(last) >= Tuning.endAfter else { return }
        isDriving = false
        continuation?.yield(.ended)
    }
}
