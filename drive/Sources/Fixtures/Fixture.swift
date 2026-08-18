import Foundation
import Core
import GPX

/// The four synthetic roads the analysis is developed against.
///
/// Each one is built from exact straights and constant-radius arcs by
/// `Tools/make_fixtures.py`, so what the pipeline ought to find is known
/// before it is run. They cover the four shapes of road worth telling apart:
/// a switchback pass, a fast flowing road, a motorway, and town traffic.
public enum Fixture: String, CaseIterable, Sendable {
    /// Eight hairpins, climbing 130 m. The first is isolated by 300 m of
    /// straight so it can be counted on its own. Driven at dusk.
    case hairpinPass = "hairpin-pass"
    /// Eight constant-radius sweepers, one of them (500 m) deliberately too
    /// open to count as a corner. Morning.
    case sweepers
    /// Ten kilometres with two 2 km-radius bends and nothing else. Midday.
    case motorway
    /// Right angles and a stop at every junction. Night.
    case urban

    public var url: URL {
        guard let url = Bundle.module.url(
            forResource: rawValue,
            withExtension: "gpx",
            subdirectory: "GPX"
        ) else {
            preconditionFailure("fixture \(rawValue).gpx is missing from the bundle")
        }
        return url
    }

    public func load() throws -> ImportedTrack {
        try GPXImporter.track(contentsOf: url)
    }

    public func samples() throws -> [Sample] {
        try load().samples
    }
}
