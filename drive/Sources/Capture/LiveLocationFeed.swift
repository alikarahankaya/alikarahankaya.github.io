import Foundation
import CoreLocation

/// Position from CoreLocation's async API.
///
/// `.automotiveNavigation` is the configuration that asks for
/// `kCLLocationAccuracyBestForNavigation` and the sensor fusion that goes with
/// it; the modern API takes the intent rather than the constant.
///
/// Note on rate: the brief assumes about 10 Hz. CoreLocation delivers what the
/// hardware gives, which on current phones is roughly 1 Hz while moving.
/// Nothing downstream depends on the rate — analysis resamples by distance —
/// and the IMU is averaged between fixes rather than thrown away.
///
/// An actor because the background activity session is a live object that has
/// to outlive the call that made it and be invalidated exactly once.
public actor LiveLocationFeed: LocationFeed {
    private var session: CLBackgroundActivitySession?
    private var task: Task<Void, Never>?

    public init() {}

    public func fixes() -> AsyncStream<LocationFix> {
        stop()
        // Keeps updates coming with the screen off and the app in the
        // background, and puts the indicator in the status bar while it does.
        session = CLBackgroundActivitySession()
        let (stream, continuation) = AsyncStream<LocationFix>.makeStream()
        task = Task {
            do {
                for try await update in CLLocationUpdate.liveUpdates(.automotiveNavigation) {
                    if Task.isCancelled { break }
                    guard let location = update.location else { continue }
                    continuation.yield(
                        LocationFix(
                            timestamp: location.timestamp,
                            lat: location.coordinate.latitude,
                            lon: location.coordinate.longitude,
                            altitude: location.altitude,
                            speed: location.speed,
                            course: location.course,
                            horizontalAccuracy: location.horizontalAccuracy
                        )
                    )
                }
            } catch {
                // Permission withdrawn, or location switched off mid-drive.
                // Nothing to say to the driver: they are driving.
            }
            continuation.finish()
        }
        return stream
    }

    public func stop() {
        task?.cancel()
        task = nil
        session?.invalidate()
        session = nil
    }
}
