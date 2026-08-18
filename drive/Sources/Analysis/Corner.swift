import Foundation

public enum Direction: String, Sendable, Codable, Equatable {
    case left
    case right
}

/// What the corner does once you are in it — the thing a co-driver would call
/// out after the severity.
public enum CornerShape: String, Sendable, Codable, Equatable {
    /// Holds one radius. Point the car and wait.
    case constant
    /// Tightens on the exit. The one that catches people out.
    case tightens
    /// Opens onto the straight. The one worth getting right.
    case opens
    /// Two apexes with a breath between them.
    case double
}

public struct Corner: Sendable, Codable, Equatable, Identifiable {
    /// Metres from the start of the drive to where the corner begins.
    public var entryDistance: Double
    public var length: Double
    public var direction: Direction
    /// Unsigned, 1/m.
    public var peakCurvature: Double
    /// 1...6, rally convention: 1 is tightest.
    public var severity: Int
    public var shape: CornerShape
    /// Mean lateral acceleration through the corner, in g, unsigned.
    public var meanLateralG: Double

    public var id: Double { entryDistance }
    public var exitDistance: Double { entryDistance + length }
    /// Radius at the apex, in metres.
    public var radius: Double { peakCurvature > 0 ? 1 / peakCurvature : .infinity }

    public init(
        entryDistance: Double,
        length: Double,
        direction: Direction,
        peakCurvature: Double,
        severity: Int,
        shape: CornerShape,
        meanLateralG: Double
    ) {
        self.entryDistance = entryDistance
        self.length = length
        self.direction = direction
        self.peakCurvature = peakCurvature
        self.severity = severity
        self.shape = shape
        self.meanLateralG = meanLateralG
    }

    /// Severity from radius, using the one band table in `Tuning`.
    public static func severity(forRadius radius: Double) -> Int {
        for (index, limit) in Tuning.severityRadii.enumerated() where radius < limit {
            return index + 1
        }
        return Tuning.severityRadii.count
    }
}
