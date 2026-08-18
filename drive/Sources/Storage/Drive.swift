import Foundation
import SwiftData
import Core

/// A drive on disk.
///
/// Everything heavy is a blob. Storage knows the blobs exist and what version
/// the cached one was written by; it does not know what is in them, which is
/// what keeps this module free of any opinion about analysis.
@Model
public final class Drive {
    #Index<Drive>([\.startedAt])
    public var id: UUID = UUID()
    public var startedAt: Date = Date()
    public var endedAt: Date = Date()
    public var timeZoneIdentifier: String = TimeZone.current.identifier
    /// Packed `[Sample]`. Never rewritten.
    public var samplesBlob: Data = Data()
    /// Cached analysis, thrown away and recomputed when the schema moves on.
    public var analysisBlob: Data?
    public var analysisSchemaVersion: Int = 0
    /// The phone's orientation in the car, so an old drive re-analyses the
    /// same way it did the day it was recorded.
    public var vehicleFrameBlob: Data?
    public var weatherSummary: String?
    /// Coarse: the town, never the street.
    public var placeName: String?
    /// The driver's own line.
    public var note: String?

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        timeZoneIdentifier: String,
        samplesBlob: Data,
        analysisBlob: Data? = nil,
        analysisSchemaVersion: Int = 0,
        vehicleFrameBlob: Data? = nil,
        weatherSummary: String? = nil,
        placeName: String? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.samplesBlob = samplesBlob
        self.analysisBlob = analysisBlob
        self.analysisSchemaVersion = analysisSchemaVersion
        self.vehicleFrameBlob = vehicleFrameBlob
        self.weatherSummary = weatherSummary
        self.placeName = placeName
        self.note = note
    }
}

/// A drive as a value, because `@Model` objects belong to their context and
/// this one has to cross actors.
public struct DriveRecord: Sendable, Identifiable, Equatable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date
    public var timeZoneIdentifier: String
    public var samplesBlob: Data
    public var analysisBlob: Data?
    public var analysisSchemaVersion: Int
    public var vehicleFrame: VehicleFrame?
    public var weatherSummary: String?
    public var placeName: String?
    public var note: String?

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        samplesBlob: Data,
        analysisBlob: Data? = nil,
        analysisSchemaVersion: Int = 0,
        vehicleFrame: VehicleFrame? = nil,
        weatherSummary: String? = nil,
        placeName: String? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.samplesBlob = samplesBlob
        self.analysisBlob = analysisBlob
        self.analysisSchemaVersion = analysisSchemaVersion
        self.vehicleFrame = vehicleFrame
        self.weatherSummary = weatherSummary
        self.placeName = placeName
        self.note = note
    }
}
