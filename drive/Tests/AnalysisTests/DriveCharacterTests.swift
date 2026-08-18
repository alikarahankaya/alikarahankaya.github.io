import Testing
import Foundation
import Core
@testable import Analysis

@Suite("Drive character")
struct DriveCharacterTests {
    private func path(_ legs: [Synthetic.Leg], speed: Double = 15) -> [PathPoint] {
        Conditioning.path(from: Synthetic.samples(points: Synthetic.road(legs), speed: speed))
    }

    @Test("A straight line has sinuosity 1.0")
    func straightSinuosity() {
        let sinuosity = DriveCharacter.sinuosity(points: path([.straight(3000)]))
        #expect(abs(sinuosity - 1) < 0.001)
    }

    @Test("A switchback road is measurably more sinuous than a fast road")
    func sinuosityRanksRoads() {
        let switchbacks = path(
            Array(repeating: [Synthetic.Leg.arc(radius: 15, length: 47),
                              .straight(100),
                              .arc(radius: -15, length: 47),
                              .straight(100)], count: 6).flatMap { $0 }
        )
        let fast = path([.straight(1500), .arc(radius: 400, length: 300), .straight(1500)])
        #expect(DriveCharacter.sinuosity(points: switchbacks) > 1.5)
        #expect(DriveCharacter.sinuosity(points: fast) < 1.05)
    }

    @Test("Flow runs through short gaps and stops at long ones")
    func flowBreaksOnLongStraights() {
        let points = path([
            .straight(100), .arc(radius: 60, length: 80),
            .straight(100), .arc(radius: -60, length: 80),
            .straight(400), .arc(radius: 60, length: 80),
            .straight(100),
        ])
        let corners = Segmentation.corners(points: points, curvature: Curvature.signed(points))
        #expect(corners.count == 3)
        let flow = DriveCharacter.flowDistance(corners: corners, points: points)
        // The first two corners chain; the 400 m straight ends the sequence.
        #expect(flow > 250 && flow < 320)
    }

    @Test("A stop breaks flow even when the corners are close together")
    func flowBreaksOnStops() {
        var samples = Synthetic.samples(
            points: Synthetic.road([
                .straight(100), .arc(radius: 60, length: 80),
                .straight(60), .arc(radius: -60, length: 80),
                .straight(100),
            ]),
            speed: 15
        )
        // Stand still for 20 seconds halfway down the 60 m straight between
        // the two corners, without moving the road under it.
        let middle = samples.count / 2
        let halt = samples[middle]
        for i in (middle + 1)..<samples.count { samples[i].t += 20 }
        let standing = (0..<200).map { i -> Sample in
            var sample = halt
            sample.t = halt.t + Double(i) * 0.1
            sample.speed = 0
            return sample
        }
        samples.insert(contentsOf: standing, at: middle + 1)
        let points = Conditioning.path(from: samples)
        let corners = Segmentation.corners(points: points, curvature: Curvature.signed(points))
        let flow = DriveCharacter.flowDistance(corners: corners, points: points)
        #expect(corners.count == 2)
        #expect(flow < 150)
    }

    @Test("Direction balance counts metres of corner, not corners")
    func directionMetres() {
        let corners = [
            Corner(entryDistance: 0, length: 100, direction: .left, peakCurvature: 0.01,
                   severity: 5, shape: .constant, meanLateralG: 0.3),
            Corner(entryDistance: 200, length: 40, direction: .right, peakCurvature: 0.02,
                   severity: 3, shape: .constant, meanLateralG: 0.4),
        ]
        let metres = DriveCharacter.directionMetres(corners: corners)
        #expect(metres.left == 100)
        #expect(metres.right == 40)
    }

    @Test("Elevation gain follows a climb and ignores noise")
    func elevation() {
        let road = Synthetic.road([.straight(2000)])
        // 40 m of climb over 2 km, with a metre of GPS wander on top.
        let climbing = Synthetic.samples(points: road, speed: 20) { i in
            Double(i) * 0.04 * 2 + (i % 7 == 0 ? 1.0 : 0)
        }
        let result = DriveCharacter.elevation(points: Conditioning.path(from: climbing))
        #expect(abs(result.gain - 80) < 12)
        #expect(result.loss < 6)
    }
}
