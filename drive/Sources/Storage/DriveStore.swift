import Foundation
import SwiftData
import Core

/// The only way in and out of the database.
///
/// A model actor because `@Model` objects belong to the context that made
/// them: everything here crosses the boundary as a `DriveRecord` value, which
/// is what lets the rest of the app stay off the main thread without the
/// compiler having to take anyone's word for it.
@ModelActor
public actor DriveStore {
    public static func container(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: Drive.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }

    /// Newest first, which is the order the library shows them in.
    public func records() throws -> [DriveRecord] {
        let descriptor = FetchDescriptor<Drive>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(Self.record)
    }

    public func record(id: UUID) throws -> DriveRecord? {
        try drive(id: id).map(Self.record)
    }

    @discardableResult
    public func insert(_ record: DriveRecord) throws -> DriveRecord {
        let drive = Drive(
            id: record.id,
            startedAt: record.startedAt,
            endedAt: record.endedAt,
            timeZoneIdentifier: record.timeZoneIdentifier,
            samplesBlob: record.samplesBlob,
            analysisBlob: record.analysisBlob,
            analysisSchemaVersion: record.analysisSchemaVersion,
            vehicleFrameBlob: try record.vehicleFrame.map { try JSONEncoder().encode($0) },
            weatherSummary: record.weatherSummary,
            placeName: record.placeName,
            note: record.note
        )
        modelContext.insert(drive)
        try modelContext.save()
        return Self.record(drive)
    }

    /// Writes a fresh analysis cache. The samples are never touched.
    public func cacheAnalysis(_ blob: Data, schemaVersion: Int, id: UUID) throws {
        guard let drive = try drive(id: id) else { return }
        drive.analysisBlob = blob
        drive.analysisSchemaVersion = schemaVersion
        try modelContext.save()
    }

    public func describe(id: UUID, weather: String?, place: String?) throws {
        guard let drive = try drive(id: id) else { return }
        if let weather { drive.weatherSummary = weather }
        if let place { drive.placeName = place }
        try modelContext.save()
    }

    public func setNote(_ note: String?, id: UUID) throws {
        guard let drive = try drive(id: id) else { return }
        drive.note = note
        try modelContext.save()
    }

    public func delete(id: UUID) throws {
        guard let drive = try drive(id: id) else { return }
        modelContext.delete(drive)
        try modelContext.save()
    }

    private func drive(id: UUID) throws -> Drive? {
        var descriptor = FetchDescriptor<Drive>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private static func record(_ drive: Drive) -> DriveRecord {
        DriveRecord(
            id: drive.id,
            startedAt: drive.startedAt,
            endedAt: drive.endedAt,
            timeZoneIdentifier: drive.timeZoneIdentifier,
            samplesBlob: drive.samplesBlob,
            analysisBlob: drive.analysisBlob,
            analysisSchemaVersion: drive.analysisSchemaVersion,
            vehicleFrame: drive.vehicleFrameBlob.flatMap {
                try? JSONDecoder().decode(VehicleFrame.self, from: $0)
            },
            weatherSummary: drive.weatherSummary,
            placeName: drive.placeName,
            note: drive.note
        )
    }
}
