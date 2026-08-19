import Foundation
import Observation
import Core
import Capture
import Storage
import Analysis
import Presentation

/// Wires the four modules together. This is the only place that knows about
/// all of them; each of them still knows about none of the others.
@MainActor
@Observable
final class DriveLibrary {
    private(set) var drives: [DrivePresentation] = []
    private(set) var isRecording = false
    /// What the car is doing, for the screen that draws it while driving.
    /// Held in memory only; nothing here is ever written down.
    let telemetry = LiveTelemetry()
    /// One line, shown once, if something went wrong that the driver can do
    /// anything about.
    private(set) var failure: String?

    private let store: DriveStore
    // A var only so the debug replay can put a file-backed recorder in its
    // place; on the road it is set once and never changes.
    private var recorder: DriveRecorder
    private let detector: TripDetector
    private var soundtrack: Task<Void, Never>?
    private var heardSoundtrack: String?
    private var live: Task<Void, Never>?

    init(
        store: DriveStore,
        recorder: DriveRecorder = DriveRecorder(),
        detector: TripDetector = TripDetector()
    ) {
        self.store = store
        self.recorder = recorder
        self.detector = detector
    }

    /// Swaps the recorder. Debug replay only; see DebugReplay.swift.
    func useRecorder(_ replacement: DriveRecorder) {
        recorder = replacement
    }

    func load() async {
        do {
            let records = try await store.records()
            drives = await Self.present(records, store: store)
        } catch {
            failure = "The drive library could not be opened."
        }
    }

    /// Listens for the phone deciding it is in a car. Runs for the lifetime
    /// of the app.
    func watchForDrives() async {
        for await event in await detector.events() {
            switch event {
            case .started: await startRecording()
            case .ended: await stopRecording()
            }
        }
    }

    func startRecording() async {
        guard !isRecording else { return }
        let now = Date()
        isRecording = true
        heardSoundtrack = nil
        telemetry.clear()
        let readings = await recorder.liveReadings()
        live = Task { [weak self] in
            for await reading in readings {
                self?.telemetry.append(reading)
            }
        }
        await recorder.start(at: now)
        await detector.setDriving(true)
        DriveActivityController.start(startedAt: now)
        soundtrack = Task { [weak self] in await self?.listenForMusic() }
    }

    func stopRecording() async {
        guard isRecording else { return }
        isRecording = false
        soundtrack?.cancel()
        soundtrack = nil
        live?.cancel()
        live = nil
        DriveActivityController.stop()
        await detector.setDriving(false)
        // Nothing back means the drive was too short to keep, which is not
        // worth a message.
        guard let recorded = await recorder.finish() else { return }
        await save(recorded)
    }

    func setNote(_ note: String, for drive: DrivePresentation) async {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        try? await store.setNote(trimmed.isEmpty ? nil : trimmed, id: drive.id)
        await load()
    }

    func delete(_ drive: DrivePresentation) async {
        try? await store.delete(id: drive.id)
        await load()
    }

    // MARK: - Behind the drive

    private func save(_ recorded: DriveRecorder.Recorded) async {
        do {
            let record = DriveRecord(
                startedAt: recorded.startedAt,
                endedAt: recorded.endedAt,
                timeZoneIdentifier: recorded.timeZoneIdentifier,
                samplesBlob: try SampleCodec.encode(recorded.samples),
                vehicleFrame: recorded.vehicleFrame,
                soundtrack: heardSoundtrack
            )
            let saved = try await store.insert(record)
            await Self.describe(saved, samples: recorded.samples, store: store)
            await load()
        } catch {
            failure = "That drive could not be saved."
        }
    }

    /// Analyse, then ask the sky and the map what this was — in that order,
    /// because the analysis is what says where the middle of the drive was.
    private nonisolated static func describe(
        _ record: DriveRecord,
        samples: [Sample],
        store: DriveStore
    ) async {
        guard let analysis = DriveAnalyser.analyse(
            samples: samples,
            startedAt: record.startedAt
        ) else { return }
        try? await store.cacheAnalysis(
            BlobCodec.encode(analysis),
            schemaVersion: analysis.schemaVersion,
            id: record.id
        )
        let weather = await WeatherSummary.fetch(
            lat: analysis.midpoint.lat,
            lon: analysis.midpoint.lon,
            at: analysis.midpointTime
        )
        let place = await PlaceName.fetch(
            lat: analysis.midpoint.lat,
            lon: analysis.midpoint.lon
        )
        try? await store.describe(id: record.id, weather: weather, place: place)
    }

    /// Off the main actor: a long library means a lot of decompression, and
    /// possibly a lot of re-analysis after a schema bump.
    private nonisolated static func present(
        _ records: [DriveRecord],
        store: DriveStore
    ) async -> [DrivePresentation] {
        var out: [DrivePresentation] = []
        for record in records {
            guard let analysis = await analysis(for: record, store: store) else { continue }
            out.append(
                DrivePresentation(
                    id: record.id,
                    startedAt: record.startedAt,
                    timeZoneIdentifier: record.timeZoneIdentifier,
                    analysis: analysis,
                    weatherSummary: record.weatherSummary,
                    placeName: record.placeName,
                    note: record.note,
                    soundtrack: record.soundtrack
                )
            )
        }
        return out
    }

    /// The cache is an opinion; the samples are the record. A schema bump
    /// throws the opinion away and asks again.
    private nonisolated static func analysis(
        for record: DriveRecord,
        store: DriveStore
    ) async -> DriveAnalysis? {
        if record.analysisSchemaVersion == DriveAnalysis.currentSchemaVersion,
           let blob = record.analysisBlob,
           let cached = try? BlobCodec.decode(DriveAnalysis.self, from: blob) {
            return cached
        }
        guard let samples = try? SampleCodec.decode(record.samplesBlob),
              let analysis = DriveAnalyser.analyse(
                  samples: samples,
                  startedAt: record.startedAt
              ) else { return nil }
        try? await store.cacheAnalysis(
            BlobCodec.encode(analysis),
            schemaVersion: analysis.schemaVersion,
            id: record.id
        )
        return analysis
    }

    /// The system music player can only see Apple Music and the local
    /// library, so this often finds nothing. It looks until it does, then
    /// stops: what matters is what you set off to.
    private func listenForMusic() async {
        while !Task.isCancelled, heardSoundtrack == nil {
            heardSoundtrack = NowPlaying.current()
            try? await Task.sleep(for: .seconds(30))
        }
    }
}
