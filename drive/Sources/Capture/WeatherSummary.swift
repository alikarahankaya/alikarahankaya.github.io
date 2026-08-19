import Foundation
import CoreLocation
import WeatherKit

/// One call, at the end of the drive, for what the sky was doing halfway
/// along it. The only network request the app makes.
public enum WeatherSummary {
    /// Returns something like "12 °C · Clear", or nothing at all. A drive
    /// without weather is a drive; it is never worth telling anyone the
    /// lookup failed.
    public static func fetch(lat: Double, lon: Double, at date: Date) async -> String? {
        let location = CLLocation(latitude: lat, longitude: lon)
        do {
            let hourly = try await WeatherService.shared.weather(
                for: location,
                including: .hourly(
                    startDate: date.addingTimeInterval(-1800),
                    endDate: date.addingTimeInterval(1800)
                )
            )
            guard let hour = hourly.forecast.min(by: {
                abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
            }) else { return nil }
            let temperature = hour.temperature.formatted(
                .measurement(width: .abbreviated, usage: .weather)
            )
            return "\(temperature) · \(hour.condition.description)"
        } catch {
            return nil
        }
    }
}

/// The town, never the street. A drive belongs to a place, not an address.
public enum PlaceName {
    public static func fetch(lat: Double, lon: Double) async -> String? {
        let geocoder = CLGeocoder()
        let placemarks = try? await geocoder.reverseGeocodeLocation(
            CLLocation(latitude: lat, longitude: lon)
        )
        guard let placemark = placemarks?.first else { return nil }
        // Locality first, then the wider names, so a drive in the hills still
        // gets called something.
        return placemark.locality
            ?? placemark.subAdministrativeArea
            ?? placemark.administrativeArea
            ?? placemark.country
    }
}
