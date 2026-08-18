import Testing
import Foundation
import Core
@testable import Analysis

@Suite("Corners")
struct SegmentationTests {
    private func corners(_ legs: [Synthetic.Leg], speed: Double = 15) -> [Corner] {
        let path = Conditioning.path(from: Synthetic.samples(
            points: Synthetic.road(legs),
            speed: speed
        ))
        return Segmentation.corners(points: path, curvature: Curvature.signed(path))
    }

    @Test("One bend is one corner")
    func singleCorner() {
        let found = corners([.straight(200), .arc(radius: 60, length: 100), .straight(200)])
        #expect(found.count == 1)
        #expect(found[0].direction == .right)
        #expect(abs(found[0].radius - 60) < 6)
        #expect(found[0].severity == 4)
    }

    @Test("A motorway bend is not a corner")
    func openBendIgnored() {
        #expect(corners([.straight(500), .arc(radius: 2000, length: 700), .straight(500)]).isEmpty)
    }

    @Test("Severity bands, tightest first")
    func severityTable() {
        #expect(Corner.severity(forRadius: 10) == 1)
        #expect(Corner.severity(forRadius: 20) == 2)
        #expect(Corner.severity(forRadius: 33) == 3)
        #expect(Corner.severity(forRadius: 55) == 4)
        #expect(Corner.severity(forRadius: 95) == 5)
        #expect(Corner.severity(forRadius: 250) == 6)
    }

    @Test("Shape: a constant-radius corner is not said to tighten")
    func constantShape() {
        let found = corners([.straight(200), .arc(radius: 60, length: 100), .straight(200)])
        #expect(found.first?.shape == .constant)
    }

    @Test("Shape: tightening and opening are told apart")
    func tighteningAndOpening() {
        let tightens = corners([
            .straight(200), .taper(from: 120, to: 40, length: 100), .straight(200),
        ])
        #expect(tightens.first?.shape == .tightens)

        let opens = corners([
            .straight(200), .taper(from: 40, to: 120, length: 100), .straight(200),
        ])
        #expect(opens.first?.shape == .opens)
    }

    @Test("Shape: two apexes with a breath between them")
    func doubleApex() {
        let found = corners([
            .straight(200),
            .arc(radius: 50, length: 60),
            .arc(radius: 350, length: 140),
            .arc(radius: 50, length: 60),
            .straight(200),
        ])
        #expect(found.count == 1)
        #expect(found.first?.shape == .double)
    }

    @Test("A change of direction always ends the corner")
    func esseIsTwoCorners() {
        let found = corners([
            .straight(200),
            .arc(radius: 70, length: 90),
            .arc(radius: -70, length: 90),
            .straight(200),
        ])
        #expect(found.count == 2)
        #expect(found[0].direction == .right)
        #expect(found[1].direction == .left)
    }

    @Test("Kinks shorter than 12 m are not corners")
    func kinksIgnored() {
        #expect(corners([.straight(300), .arc(radius: 200, length: 6), .straight(300)]).isEmpty)
    }
}
