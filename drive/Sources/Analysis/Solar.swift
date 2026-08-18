import Foundation
import Core

/// The light a drive was made in. This is what colours the artifact, and it
/// matters more than the weather: a road at dusk is a different road.
public enum Light: String, Sendable, Codable, CaseIterable, Equatable {
    case night
    case dawn
    case morning
    case day
    case golden
    case dusk
}

/// Where the sun was. Pure arithmetic — no network, no location permission
/// beyond the drive itself, and reproducible forever.
public enum Solar {
    /// Sun altitude in degrees above the horizon. Uses the low-precision
    /// solar position model, good to about 0.01°, which is far finer than the
    /// six bands below need.
    public static func altitude(at date: Date, lat: Double, lon: Double) -> Double {
        let julian = date.timeIntervalSince1970 / 86400 + 2_440_587.5
        let n = julian - 2_451_545.0                       // days since J2000
        let meanLongitude = (280.460 + 0.985_647_4 * n).truncatingRemainder(dividingBy: 360)
        let meanAnomaly = Angles.radians(
            (357.528 + 0.985_600_3 * n).truncatingRemainder(dividingBy: 360)
        )
        let eclipticLongitude = Angles.radians(
            meanLongitude + 1.915 * sin(meanAnomaly) + 0.020 * sin(2 * meanAnomaly)
        )
        let obliquity = Angles.radians(23.439 - 0.000_000_4 * n)
        let declination = asin(sin(obliquity) * sin(eclipticLongitude))
        let rightAscension = atan2(
            cos(obliquity) * sin(eclipticLongitude),
            cos(eclipticLongitude)
        )
        // Greenwich mean sidereal time, in hours.
        let gmst = (18.697_374_558 + 24.065_709_824_419_08 * n)
            .truncatingRemainder(dividingBy: 24)
        let localSidereal = gmst * 15 + lon                // degrees
        var hourAngle = localSidereal - Angles.degrees(rightAscension)
        hourAngle = Angles.difference(hourAngle, 0)        // wrap to ±180
        let phi = Angles.radians(lat)
        let h = Angles.radians(hourAngle)
        let sinAltitude = sin(phi) * sin(declination) + cos(phi) * cos(declination) * cos(h)
        return Angles.degrees(asin(min(1, max(-1, sinAltitude))))
    }

    /// True when the sun is on its way up. Asked ten minutes apart, which is
    /// long enough to beat the arithmetic's own noise and short enough that
    /// the answer still belongs to the drive.
    public static func isRising(at date: Date, lat: Double, lon: Double) -> Bool {
        altitude(at: date.addingTimeInterval(600), lat: lat, lon: lon)
            > altitude(at: date, lat: lat, lon: lon)
    }

    /// The six lights, by sun altitude.
    ///
    /// −6° is civil twilight: below it you are driving on headlights. 0° to
    /// 8° is the low, long light everyone means by golden. Above 8° the sun
    /// is simply up, and the only thing left worth distinguishing is whether
    /// the day is still arriving or already going.
    public static func light(at date: Date, lat: Double, lon: Double) -> Light {
        let altitude = altitude(at: date, lat: lat, lon: lon)
        switch altitude {
        case ..<(-6):
            return .night
        case ..<0:
            return isRising(at: date, lat: lat, lon: lon) ? .dawn : .dusk
        case ..<8:
            return .golden
        case ..<30:
            return isRising(at: date, lat: lat, lon: lon) ? .morning : .day
        default:
            return .day
        }
    }
}
