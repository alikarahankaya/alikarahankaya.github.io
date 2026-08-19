import Testing
import Foundation
import Core
import Fixtures
@testable import Analysis

/// The whole pipeline over the four synthetic roads. The numbers here were
/// measured against the geometry the fixtures were generated from, not
/// guessed: a 12 m hairpin has to come out as a 12 m hairpin.
@Suite("Fixtures")
struct FixtureTests {
    private func analyse(_ fixture: Fixture) throws -> DriveAnalysis {
        let track = try fixture.load()
        return try #require(
            DriveAnalyser.analyse(samples: track.samples, startedAt: track.startedAt)
        )
    }

    @Test("A mountain pass: eight hairpins, one of them on its own")
    func hairpinPass() throws {
        let analysis = try analyse(.hairpinPass)
        #expect(abs(analysis.distance - 2224) < 30)
        #expect(analysis.corners.count == 8)

        // The first hairpin sits between 300 m of straight on either side, so
        // it must resolve as exactly one corner — not three, which is what a
        // smoothing window that is too wide produces.
        let isolated = analysis.corners.filter { (250...400).contains($0.entryDistance) }
        #expect(isolated.count == 1)
        let hairpin = try #require(isolated.first)
        #expect(hairpin.direction == .left)
        #expect(hairpin.severity == 1)
        #expect(abs(hairpin.radius - 12) < 1.5)

        // Hairpins alternate on a switchback road.
        for (a, b) in zip(analysis.corners, analysis.corners.dropFirst()) {
            #expect(a.direction != b.direction)
        }
        #expect(analysis.sinuosity > 3)
        #expect(analysis.elevationGain > 100 && analysis.elevationGain < 150)
        #expect(analysis.elevationLoss < 10)
        #expect(analysis.light == .dusk)
        #expect(analysis.cornerDensity > 3)
    }

    @Test("A motorway is not a driving road")
    func motorway() throws {
        let analysis = try analyse(.motorway)
        #expect(abs(analysis.distance - 10353) < 60)
        #expect(analysis.corners.isEmpty)
        #expect(analysis.flowDistance == 0)
        #expect(analysis.sinuosity < 1.02)
        #expect(analysis.light == .day)
    }

    @Test("A flowing road flows")
    func sweepers() throws {
        let analysis = try analyse(.sweepers)
        #expect(abs(analysis.distance - 3212) < 40)
        // Eight bends, but the 500 m one is too open to count.
        #expect(analysis.corners.count == 7)
        #expect(analysis.corners.allSatisfy { $0.severity == 6 })
        #expect(analysis.flowDistance > 900)
        // Both ways, near enough evenly.
        #expect(abs(analysis.directionBalance - 0.5) < 0.1)
        #expect(analysis.light == .morning)
    }

    @Test("Town driving has corners but no rhythm")
    func urban() throws {
        let analysis = try analyse(.urban)
        #expect(analysis.corners.count == 8)
        // Every junction is a stop, so nothing ever links up.
        #expect(analysis.flowDistance < 120)
        #expect(analysis.light == .night)
    }

    @Test("A drive with corners has more flow than one without")
    func flowRanksTheFixtures() throws {
        let pass = try analyse(.hairpinPass).flowDistance
        let fast = try analyse(.sweepers).flowDistance
        let town = try analyse(.urban).flowDistance
        let dual = try analyse(.motorway).flowDistance
        #expect(fast > pass)
        #expect(pass > town)
        #expect(town > dual)
    }

    @Test("The trace and the rhythm strip fit their budgets")
    func renderingData() throws {
        for fixture in Fixture.allCases {
            let analysis = try analyse(fixture)
            #expect(analysis.trace.count > 20)
            #expect(analysis.trace.count <= Tuning.maximumTracePoints)
            #expect(analysis.rhythm.count <= Tuning.maximumRhythmPoints)
            #expect(analysis.trace.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
            #expect(analysis.trace.allSatisfy { (0...1).contains($0.intensity) })
            #expect(analysis.rhythm.allSatisfy { abs($0.value) <= 1 })
            // The drawing has to stay recognisable after simplification.
            #expect(abs(analysis.trace[analysis.trace.count - 1].distance - analysis.distance) < 5)
        }
    }

    @Test("Analysis of the same samples is always the same")
    func deterministic() throws {
        let track = try Fixture.sweepers.load()
        let first = DriveAnalyser.analyse(samples: track.samples, startedAt: track.startedAt)
        let second = DriveAnalyser.analyse(samples: track.samples, startedAt: track.startedAt)
        #expect(first == second)
    }

    @Test("Without an IMU the analysis says so rather than guessing")
    func imuAbsent() throws {
        let analysis = try analyse(.hairpinPass)
        #expect(analysis.imuAgreement == nil)
        #expect(analysis.imuTrusted == false)
    }
}
