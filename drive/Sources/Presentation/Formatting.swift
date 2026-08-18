import Foundation
import Analysis

/// Copy rules: plain, active, specific. Numbers carry their units; labels say
/// what the number is, not what the app is doing.
enum Formatting {
    /// Distances follow the reader's locale — kilometres here, miles in the
    /// places that use them.
    static func distance(_ metres: Double, locale: Locale = .autoupdatingCurrent) -> String {
        let measurement = Measurement(value: metres, unit: UnitLength.meters)
        return measurement.formatted(
            .measurement(width: .abbreviated, usage: .road)
                .locale(locale)
        )
    }

    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }

    static func corners(_ count: Int) -> String {
        count == 1 ? "1 corner" : "\(count) corners"
    }

    static func sinuosity(_ value: Double) -> String {
        String(format: "%.2f sin.", value)
    }

    static func light(_ light: Light) -> String {
        switch light {
        case .night: "Night"
        case .dawn: "Dawn"
        case .morning: "Morning"
        case .day: "Day"
        case .golden: "Golden"
        case .dusk: "Dusk"
        }
    }

    static func date(_ date: Date, timeZone: TimeZone, locale: Locale = .autoupdatingCurrent) -> String {
        date.formatted(
            .dateTime.day().month(.wide).year()
                .locale(locale)
                .timeZone(timeZone)
        )
    }

    /// The tertiary line: light, then whatever else is actually known.
    static func conditions(_ drive: DrivePresentation) -> String {
        [light(drive.analysis.light), drive.weatherSummary, drive.placeName]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// What VoiceOver reads for the trace: the drive, described.
    static func spokenSummary(_ drive: DrivePresentation) -> String {
        var parts = [
            distance(drive.analysis.distance),
            corners(drive.analysis.corners.count),
            "driven at \(light(drive.analysis.light).lowercased())",
        ]
        if drive.analysis.flowDistance > 0 {
            parts.insert(
                "longest unbroken sequence \(distance(drive.analysis.flowDistance))",
                at: 2
            )
        }
        return parts.joined(separator: ", ")
    }
}
