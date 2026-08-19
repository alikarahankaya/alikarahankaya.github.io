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

    /// In the drive's own time zone, so an evening drive abroad still reads
    /// as an evening. `timeZone` has to be set on the style rather than
    /// chained: the chainable `timeZone(_:)` decides how a zone is *shown*,
    /// not which one is used.
    static func date(
        _ date: Date,
        timeZone: TimeZone,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        var style = Date.FormatStyle.dateTime.day().month(.wide).year()
        style.timeZone = timeZone
        style.locale = locale
        return date.formatted(style)
    }

    /// The library's date: the year only when it is not this one. A shelf of
    /// this year's drives does not need to be told what year it is.
    static func shortDate(
        _ date: Date,
        timeZone: TimeZone,
        relativeTo now: Date = .now,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let sameYear = calendar.component(.year, from: date)
            == calendar.component(.year, from: now)
        var style = sameYear
            ? Date.FormatStyle.dateTime.day().month(.wide)
            : Date.FormatStyle.dateTime.day().month(.wide).year()
        style.timeZone = timeZone
        style.locale = locale
        return date.formatted(style)
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
