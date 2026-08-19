import Foundation

/// A place, in degrees. Kept out of CoreLocation so that analysis, storage
/// and the tests never have to import it.
public struct Coordinate: Sendable, Codable, Equatable {
    public var lat: Double
    public var lon: Double

    public init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }
}
