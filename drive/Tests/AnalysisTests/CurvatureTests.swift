import Testing
import Foundation
import Core
@testable import Analysis

@Suite("Curvature")
struct CurvatureTests {
    /// The brief's headline requirement: a circle of radius r has to come out
    /// as 1/r. Everything downstream — severity, lateral g, the rhythm strip
    /// — is built on this being true.
    @Test("A constant-radius circle reads 1/r within 2%", arguments: [12.0, 25.0, 60.0, 250.0])
    func circleCurvature(radius: Double) {
        let samples = Synthetic.samples(points: Synthetic.circle(radius: radius), speed: 15)
        let path = Conditioning.path(from: samples)
        let k = Curvature.signed(path)
        let measured = k[Tuning.curvatureArm..<(k.count - Tuning.curvatureArm)]
        #expect(!measured.isEmpty)
        for value in measured {
            #expect(abs(abs(value) * radius - 1) < 0.02)
        }
    }

    @Test("A straight road has no curvature")
    func straightIsFlat() {
        let samples = Synthetic.samples(points: Synthetic.road([.straight(1000)]), speed: 25)
        let k = Curvature.signed(Conditioning.path(from: samples))
        for value in k { #expect(abs(value) < 1e-4) }
    }

    @Test("Right is positive, left is negative")
    func signConvention() {
        let right = Synthetic.samples(
            points: Synthetic.road([.straight(100), .arc(radius: 80, length: 200), .straight(100)]),
            speed: 20
        )
        let left = Synthetic.samples(
            points: Synthetic.road([.straight(100), .arc(radius: -80, length: 200), .straight(100)]),
            speed: 20
        )
        let rightPeak = Curvature.signed(Conditioning.path(from: right)).max() ?? 0
        let leftPeak = Curvature.signed(Conditioning.path(from: left)).min() ?? 0
        #expect(rightPeak > 0.01)
        #expect(leftPeak < -0.01)
    }

    @Test("Lateral g is v squared over r, in g")
    func lateralG() {
        // 100 km/h through a 100 m radius: 7.7 m/s², a bit under 0.8 g.
        let g = Curvature.lateralG(speed: 27.78, curvature: 1.0 / 100)
        #expect(abs(g - 0.787) < 0.01)
    }
}
