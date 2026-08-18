import Testing
import Foundation
import Core
import Fixtures
@testable import GPX

@Suite("GPX import")
struct GPXImporterTests {
    @Test("Every fixture parses", arguments: Fixture.allCases)
    func fixturesParse(fixture: Fixture) throws {
        let track = try fixture.load()
        #expect(track.samples.count > 400)
        #expect(track.name?.isEmpty == false)
        // Timestamps run forwards and start at zero.
        #expect(track.samples[0].t == 0)
        for (a, b) in zip(track.samples, track.samples.dropFirst()) {
            #expect(b.t >= a.t)
        }
    }

    @Test("Speed and course are derived when the file does not carry them")
    func derivedSpeedAndCourse() throws {
        let samples = try Fixture.motorway.samples()
        // The motorway fixture was written at a steady 33 m/s.
        let cruising = samples[100..<(samples.count - 100)]
        for sample in cruising {
            #expect(abs(sample.speed - 33) < 1.5)
            #expect(sample.hasValidCourse)
        }
    }

    @Test("Altitude comes through")
    func elevation() throws {
        let samples = try Fixture.hairpinPass.samples()
        #expect(samples[0].altitude == 0)
        #expect(samples[samples.count - 1].altitude > 100)
    }

    @Test("A track without timestamps is refused rather than invented")
    func timelessTrackRejected() {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1"><trk><trkseg>
        <trkpt lat="46.5" lon="11.0"><ele>100</ele></trkpt>
        <trkpt lat="46.5001" lon="11.0"><ele>101</ele></trkpt>
        </trkseg></trk></gpx>
        """
        #expect(throws: GPXError.noTimestamps) {
            try GPXImporter.samples(fromGPX: Data(gpx.utf8))
        }
    }

    @Test("An empty track is refused")
    func emptyTrackRejected() {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1"><trk><trkseg>
        </trkseg></trk></gpx>
        """
        #expect(throws: GPXError.noTrackPoints) {
            try GPXImporter.samples(fromGPX: Data(gpx.utf8))
        }
    }

    @Test("Speed, course and hdop are read when a file does carry them")
    func explicitFields() throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1"><trk>
        <name>With extensions</name><trkseg>
        <trkpt lat="46.5" lon="11.0"><ele>100</ele><time>2024-06-12T10:00:00Z</time>
          <hdop>2.0</hdop><speed>17.5</speed><course>91.0</course></trkpt>
        <trkpt lat="46.5001" lon="11.0"><ele>101</ele><time>2024-06-12T10:00:01Z</time>
          <hdop>2.0</hdop><speed>17.6</speed><course>92.0</course></trkpt>
        </trkseg></trk></gpx>
        """
        let track = try GPXImporter.track(fromGPX: Data(gpx.utf8))
        #expect(track.name == "With extensions")
        #expect(track.samples[0].speed == 17.5)
        #expect(track.samples[0].course == 91)
        #expect(track.samples[0].horizontalAccuracy == 6)
    }

    @Test("Fractional seconds are accepted, and so is their absence")
    func timeFormats() throws {
        let parser = TimeParser()
        #expect(parser.date(from: "2024-06-12T10:00:00Z") != nil)
        #expect(parser.date(from: "2024-06-12T10:00:00.250Z") != nil)
        #expect(parser.date(from: "not a time") == nil)
    }
}
