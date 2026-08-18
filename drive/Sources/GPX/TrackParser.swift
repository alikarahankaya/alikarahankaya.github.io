import Foundation

/// XMLParser rather than a hand-rolled scanner: real GPX files carry
/// namespaces, entities and vendor extensions, and getting those wrong
/// silently is worse than the delegate boilerplate.
enum TrackParser {
    static func parse(_ data: Data) throws -> (points: [TrackPoint], name: String?) {
        let collector = Collector()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = collector
        guard parser.parse() else {
            throw GPXError.malformed(parser.parserError?.localizedDescription ?? "unreadable")
        }
        return (collector.points, collector.trackName)
    }

    /// Collects track points during one synchronous parse. Never crosses an
    /// isolation boundary: created, used and dropped inside `parse`.
    private final class Collector: NSObject, XMLParserDelegate {
        var points: [TrackPoint] = []
        var trackName: String?
        private var current: TrackPoint?
        private var text = ""
        private let timeParser = TimeParser()

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName: String?,
            attributes: [String: String]
        ) {
            text = ""
            guard elementName == "trkpt" || elementName == "rtept" else { return }
            guard let lat = attributes["lat"].flatMap(Double.init),
                  let lon = attributes["lon"].flatMap(Double.init) else { return }
            current = TrackPoint(
                lat: lat,
                lon: lon,
                elevation: nil,
                time: nil,
                speed: nil,
                course: nil,
                hdop: nil
            )
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            text += string
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName: String?
        ) {
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            text = ""
            switch elementName {
            case "trkpt", "rtept":
                if let point = current { points.append(point) }
                current = nil
            case "ele":
                current?.elevation = Double(value)
            case "time":
                current?.time = timeParser.date(from: value)
            // GPX 1.0 carried speed and course on the point; 1.1 dropped them
            // and most writers put them in <extensions> under the same names.
            case "speed":
                current?.speed = Double(value)
            case "course", "heading":
                current?.course = Double(value)
            case "hdop":
                current?.hdop = Double(value)
            case "name":
                // The track's name, not a waypoint's: first one wins.
                if current == nil, trackName == nil, !value.isEmpty { trackName = value }
            default:
                break
            }
        }
    }
}

/// ISO 8601 with and without fractional seconds; writers disagree.
final class TimeParser {
    private let fractional: ISO8601DateFormatter
    private let plain: ISO8601DateFormatter

    init() {
        fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
    }

    func date(from string: String) -> Date? {
        fractional.date(from: string) ?? plain.date(from: string)
    }
}
