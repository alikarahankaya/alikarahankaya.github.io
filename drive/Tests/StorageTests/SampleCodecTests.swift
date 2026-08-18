import Testing
import Foundation
import Core
@testable import Storage

@Suite("Sample codec")
struct SampleCodecTests {
    private func drive(minutes: Int) -> [Sample] {
        // 10 Hz, the rate the recorder writes at.
        (0..<(minutes * 60 * 10)).map { i in
            let t = Double(i) / 10
            return Sample(
                t: t,
                lat: 46.5 + t * 1e-5,
                lon: 11.0 + sin(t / 40) * 1e-4,
                altitude: 800 + sin(t / 90) * 60,
                speed: 18 + sin(t / 12) * 6,
                course: (t * 3).truncatingRemainder(dividingBy: 360),
                horizontalAccuracy: 5,
                lateralG: sin(t / 7) * 0.4,
                longitudinalG: cos(t / 9) * 0.2
            )
        }
    }

    @Test("Samples survive the round trip exactly")
    func roundTrip() throws {
        let samples = drive(minutes: 5)
        let decoded = try SampleCodec.decode(SampleCodec.encode(samples))
        #expect(decoded == samples)
    }

    @Test("An empty drive round-trips too")
    func emptyRoundTrip() throws {
        #expect(try SampleCodec.decode(SampleCodec.encode([])).isEmpty)
    }

    @Test("Missing IMU values stay missing rather than becoming zero")
    func optionalsPreserved() throws {
        var samples = drive(minutes: 1)
        for i in samples.indices { samples[i].lateralG = nil }
        let decoded = try SampleCodec.decode(SampleCodec.encode(samples))
        #expect(decoded.allSatisfy { $0.lateralG == nil })
        #expect(decoded.allSatisfy { $0.longitudinalG != nil })
    }

    @Test("A ninety-minute drive is a blob worth storing, not a table")
    func size() throws {
        let samples = drive(minutes: 90)
        let blob = try SampleCodec.encode(samples)
        // Roughly 54,000 samples. If this ever exceeds a few megabytes the
        // packing has regressed and the library will feel it.
        #expect(samples.count > 50_000)
        #expect(blob.count < 4_000_000)
        #expect(try SampleCodec.decode(blob).count == samples.count)
    }

    @Test("Rubbish in is an error, not a crash")
    func rejectsGarbage() {
        #expect(throws: (any Error).self) {
            try SampleCodec.decode(Data([0x00, 0x01, 0x02, 0x03]))
        }
    }

    @Test("Analysis blobs round-trip through the same packing")
    func blobCodec() throws {
        struct Cached: Codable, Equatable {
            var version: Int
            var values: [Double]
        }
        let value = Cached(version: 3, values: (0..<1000).map(Double.init))
        let decoded = try BlobCodec.decode(Cached.self, from: BlobCodec.encode(value))
        #expect(decoded == value)
    }
}
