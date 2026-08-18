import Foundation
import ActivityKit

/// What the driver sees while driving: elapsed time, and nothing else.
///
/// No speed, no map, no gauges, no sound. The road is the thing worth looking
/// at; anything on the screen is competing with it. The start time is an
/// attribute rather than state, so the widget can run its own timer and the
/// app never has to push an update — which also means nothing on the lock
/// screen ever changes mid-corner.
public struct DriveActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public init() {}
    }

    public var startedAt: Date

    public init(startedAt: Date) {
        self.startedAt = startedAt
    }
}

@MainActor
public enum DriveActivityController {
    private static var activity: Activity<DriveActivityAttributes>?

    public static var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    public static func start(startedAt: Date) {
        guard isAvailable, activity == nil else { return }
        activity = try? Activity.request(
            attributes: DriveActivityAttributes(startedAt: startedAt),
            content: ActivityContent(state: .init(), staleDate: nil)
        )
    }

    public static func stop() {
        let current = activity
        activity = nil
        Task { await current?.end(nil, dismissalPolicy: .immediate) }
    }
}
