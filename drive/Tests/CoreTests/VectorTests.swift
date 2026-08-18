import Testing
import Foundation
@testable import Core

@Suite("Vectors and angles")
struct VectorTests {
    @Test("Compass differences wrap the short way round")
    func angleWrapping() {
        #expect(abs(Angles.difference(1, 359) - 2) < 1e-9)
        #expect(abs(Angles.difference(359, 1) + 2) < 1e-9)
        #expect(abs(Angles.difference(90, 90)) < 1e-9)
        #expect(abs(abs(Angles.difference(0, 180)) - 180) < 1e-9)
    }

    @Test("Cross products are right-handed")
    func crossProduct() {
        let x = Vector3(1, 0, 0)
        let y = Vector3(0, 1, 0)
        #expect(x.cross(y) == Vector3(0, 0, 1))
        #expect(y.cross(x) == Vector3(0, 0, -1))
    }

    @Test("Orthogonalising removes the parallel part")
    func orthogonalize() {
        let axis = Vector3(0, 0, 1)
        let v = Vector3(3, 0, 7)
        let o = v.orthogonalized(to: axis)
        #expect(abs(o.z) < 1e-12)
        #expect(abs(o.x - 3) < 1e-12)
    }

    @Test("A vector too short to have a direction has no direction")
    func degenerateNormalisation() {
        #expect(Vector3(0, 0, 0).normalized == nil)
        #expect(Vector3(0, 0, 3).normalized == Vector3(0, 0, 1))
    }
}
