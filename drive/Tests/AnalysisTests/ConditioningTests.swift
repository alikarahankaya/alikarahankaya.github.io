import Testing
import Foundation
import Core
@testable import Analysis

@Suite("Conditioning")
struct ConditioningTests {
    @Test("Resampling puts one point every metre")
    func uniformSpacing() {
        let samples = Synthetic.samples(
            points: Synthetic.road([.straight(500), .arc(radius: 80, length: 200)]),
            speed: 20
        )
        let path = Conditioning.path(from: samples)
        #expect(path.count > 600)
        for i in 1..<path.count {
            #expect(abs(path[i].s - path[i - 1].s - 1) < 1e-6)
        }
    }

    @Test("Fixes worse than 20 m are thrown away")
    func accuracyFilter() {
        let bad = Synthetic.samples(
            points: Synthetic.road([.straight(500)]),
            speed: 20,
            accuracy: 45
        )
        #expect(Conditioning.path(from: bad).isEmpty)

        let good = Synthetic.samples(points: Synthetic.road([.straight(500)]), speed: 20)
        #expect(!Conditioning.path(from: good).isEmpty)
    }

    @Test("Samples that go backwards in time are dropped")
    func monotonicTime() {
        var samples = Synthetic.samples(points: Synthetic.road([.straight(200)]), speed: 20)
        let stale = samples[10]
        samples.insert(stale, at: 40)
        let kept = Conditioning.usableSamples(samples)
        #expect(kept.count == samples.count - 1)
        for i in 1..<kept.count { #expect(kept[i].t > kept[i - 1].t) }
    }

    @Test("A missing speed is filled in from the neighbours")
    func speedFallback() {
        var samples = Synthetic.samples(points: Synthetic.road([.straight(400)]), speed: 25)
        for i in samples.indices { samples[i].speed = -1 }
        let speeds = Conditioning.filledSpeeds(Conditioning.usableSamples(samples))
        // Ends are one-sided differences, so check the middle.
        for speed in speeds[2..<(speeds.count - 2)] {
            #expect(abs(speed - 25) < 0.5)
        }
    }

    @Test("A stop is remembered even though it covers no distance")
    func stopSurvivesResampling() {
        let samples = Synthetic.stopping(before: 200, duration: 30, after: 200, speed: 10)
        let path = Conditioning.path(from: samples)
        #expect(path.count > 350)
        #expect(path.contains { $0.minimumSpeed < Tuning.flowStopSpeed })
    }
}
