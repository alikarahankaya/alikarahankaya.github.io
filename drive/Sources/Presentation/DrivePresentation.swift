import Foundation
import Analysis

/// One drive, ready to be looked at. Everything the artifact draws comes from
/// here; nothing in Presentation goes and fetches anything.
public struct DrivePresentation: Sendable, Identifiable, Equatable {
    public var id: UUID
    public var startedAt: Date
    /// The time zone the drive happened in, so an evening drive abroad still
    /// reads as an evening.
    public var timeZoneIdentifier: String
    public var analysis: DriveAnalysis
    /// Short, already formatted: "12 °C · clear". Nil when the weather was
    /// never fetched, which is not worth mentioning to anybody.
    public var weatherSummary: String?
    /// Coarse on purpose — the town, never the street.
    public var placeName: String?
    /// The driver's own line, if they wrote one.
    public var note: String?

    public init(
        id: UUID,
        startedAt: Date,
        timeZoneIdentifier: String,
        analysis: DriveAnalysis,
        weatherSummary: String? = nil,
        placeName: String? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.analysis = analysis
        self.weatherSummary = weatherSummary
        self.placeName = placeName
        self.note = note
    }

    public var palette: Palette { Palette(analysis.light) }

    public var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }
}
