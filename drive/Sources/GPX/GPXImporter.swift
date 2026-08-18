import Foundation
import Core

public enum GPXError: Error, Equatable {
    case malformed(String)
    case noTrackPoints
    /// A track without timestamps is a shape, not a drive: there is no speed
    /// in it, so no lateral load and no stops. Better to say so than to
    /// invent a pace.
    case noTimestamps
}

/// GPX in, `[Sample]` out.
///
/// This exists so the analysis pipeline can be worked on at a desk: without
/// it, every change to curvature or corner segmentation would need a car and
/// a mountain. It also backs the debug replay recorder.
public struct ImportedTrack: Sendable {
    public var samples: [Sample]
    /// Wall-clock time of the first point. Analysis needs it for the sun.
    public var startedAt: Date
    public var name: String?
}

public enum GPXImporter {
    public static func track(fromGPX data: Data) throws -> ImportedTrack {
        let (points, name) = try TrackParser.parse(data)
        guard !points.isEmpty else { throw GPXError.noTrackPoints }
        guard let start = points.first?.time,
              points.allSatisfy({ $0.time != nil }) else { throw GPXError.noTimestamps }
        return ImportedTrack(samples: samples(from: points), startedAt: start, name: name)
    }

    public static func track(contentsOf url: URL) throws -> ImportedTrack {
        try track(fromGPX: Data(contentsOf: url))
    }

    public static func samples(fromGPX data: Data) throws -> [Sample] {
        try track(fromGPX: data).samples
    }

    static func samples(from points: [TrackPoint]) -> [Sample] {
        guard let start = points.first?.time else { return [] }
        return points.indices.map { i in
            let p = points[i]
            let before = points[max(0, i - 1)]
            let after = points[min(points.count - 1, i + 1)]
            let span = (after.time ?? start).timeIntervalSince(before.time ?? start)
            let stride = Geo.distance(
                fromLat: before.lat, lon: before.lon,
                toLat: after.lat, lon: after.lon
            )

            // A recorder gives speed and course directly. A GPX file usually
            // does not, so they come from the neighbouring points instead.
            let speed = p.speed ?? (span > 0 ? stride / span : 0)
            let course = p.course ?? (stride > 0.5
                ? Geo.bearing(fromLat: before.lat, lon: before.lon, toLat: after.lat, lon: after.lon)
                : -1)

            return Sample(
                t: (p.time ?? start).timeIntervalSince(start),
                lat: p.lat,
                lon: p.lon,
                altitude: p.elevation ?? 0,
                speed: speed,
                course: course,
                // Horizontal DOP is unitless; multiplying by the ~3 m ranging
                // error of consumer GPS turns it into something the accuracy
                // filter can use. Files without it are assumed decent.
                horizontalAccuracy: p.hdop.map { max(3, $0 * 3) } ?? 5
            )
        }
    }

}

struct TrackPoint {
    var lat: Double
    var lon: Double
    var elevation: Double?
    var time: Date?
    var speed: Double?
    var course: Double?
    var hdop: Double?
}
