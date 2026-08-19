import Foundation
import Analysis

/// Decides what this particular drive has to say, so the screen and the
/// poster say the same things and neither has to work it out twice.
///
/// The rule throughout: a line exists only if it carries something. No
/// zeroes, no "unknown", no labels standing over an empty space.
struct DriveCopy {
    let drive: DrivePresentation

    /// Below this a road is straight, and its sinuosity is a number about
    /// nothing.
    static let sinuosityWorthSaying = 1.05

    init(_ drive: DrivePresentation) {
        self.drive = drive
    }

    private var analysis: DriveAnalysis { drive.analysis }

    /// Flow when there was any, distance when there was not. A proud zero is
    /// worse than a smaller true thing.
    var headline: (value: String, label: String) {
        if analysis.flowDistance > 0 {
            (Formatting.distance(analysis.flowDistance), "Longest unbroken sequence")
        } else {
            (Formatting.distance(analysis.distance), "Distance driven")
        }
    }

    var secondary: [String] {
        var items: [String] = []
        if !analysis.corners.isEmpty {
            items.append(Formatting.corners(analysis.corners.count))
        }
        if analysis.sinuosity >= Self.sinuosityWorthSaying {
            items.append(Formatting.sinuosity(analysis.sinuosity))
        }
        return items
    }

    /// The quiet lines: conditions, logistics, and whatever else happens to
    /// be known about this drive.
    var tertiary: [String] {
        var lines: [String] = []
        let conditions = Formatting.conditions(drive)
        if !conditions.isEmpty { lines.append(conditions) }
        lines.append(logistics)
        if let soundtrack = drive.soundtrack, !soundtrack.isEmpty { lines.append(soundtrack) }
        if let note = drive.note, !note.isEmpty { lines.append(note) }
        return lines
    }

    /// The headline already said the distance when there was no flow, so it
    /// is not said twice.
    var logistics: String {
        var parts: [String] = []
        if analysis.flowDistance > 0 { parts.append(Formatting.distance(analysis.distance)) }
        parts.append(Formatting.duration(analysis.duration))
        return parts.joined(separator: " · ")
    }

    /// The poster carries its own footer: where, when, and in what light.
    var posterFooter: String {
        [
            drive.placeName,
            Formatting.date(drive.startedAt, timeZone: drive.timeZone),
            Formatting.light(analysis.light),
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    var spokenRhythm: String {
        let corners = analysis.corners
        guard !corners.isEmpty else { return "No corners" }
        let tightest = corners.min { $0.severity < $1.severity }?.severity ?? 6
        let left = corners.filter { $0.direction == .left }.count
        return """
        Corner rhythm. \(corners.count) corners, \(left) left and \
        \(corners.count - left) right, tightest severity \(tightest).
        """
    }
}
