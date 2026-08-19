import Testing
import Foundation
@testable import Core

@Suite("Vehicle frame")
struct VehicleFrameTests {
    /// An arbitrary mount angle: the phone is tilted back 25° and turned 40°
    /// away from the direction of travel, which is what a windscreen cradle
    /// actually does.
    static func mounted() -> (down: Vector3, forward: Vector3, lateral: Vector3) {
        let tilt = Angles.radians(25)
        let yaw = Angles.radians(40)
        let down = Vector3(0, -sin(tilt), -cos(tilt))
        var forward = Vector3(sin(yaw), cos(yaw) * cos(tilt), -cos(yaw) * sin(tilt))
        forward = forward.orthogonalized(to: down).normalized!
        return (down, forward, down.cross(forward))
    }

    @Test("Lateral points out of the right window")
    func handedness() throws {
        // Straight up-and-north device frame: down is -z, forward is +y.
        let frame = try #require(
            VehicleFrame(down: Vector3(0, 0, -1), forwardHint: Vector3(0, 1, 0))
        )
        #expect(frame.lateral == Vector3(1, 0, 0))

        // Cornering right pushes the car — and the phone — to the right.
        let resolved = frame.resolve(Vector3(0.4, 0.1, 0))
        #expect(abs(resolved.lateral - 0.4) < 1e-12)
        #expect(abs(resolved.longitudinal - 0.1) < 1e-12)
    }

    @Test("A forward hint parallel to gravity carries no information")
    func degenerateHint() {
        #expect(VehicleFrame(down: Vector3(0, 0, -1), forwardHint: Vector3(0, 0, -0.5)) == nil)
    }

    @Test("The hint does not have to be perpendicular to gravity")
    func hintIsOrthogonalised() throws {
        let frame = try #require(
            VehicleFrame(down: Vector3(0, 0, -1), forwardHint: Vector3(0, 1, -0.6))
        )
        #expect(abs(frame.forward.dot(frame.down)) < 1e-12)
        #expect(abs(frame.forward.y - 1) < 1e-9)
    }

    @Test("Drift is the angle between the frame and fresh gravity")
    func drift() throws {
        let frame = try #require(
            VehicleFrame(down: Vector3(0, 0, -1), forwardHint: Vector3(0, 1, 0))
        )
        #expect(frame.drift(from: Vector3(0, 0, -1)) < 1e-9)
        #expect(abs(frame.drift(from: Vector3(0, -1, -1)) - 45) < 1e-6)
    }
}

@Suite("Vehicle frame solver")
struct VehicleFrameSolverTests {
    /// Three seconds of cruising, then four of pulling away in a straight
    /// line, at 10 Hz — the shortest drive that can solve the frame.
    static func drive(
        mount: (down: Vector3, forward: Vector3, lateral: Vector3),
        gravity: Vector3? = nil
    ) -> [VehicleFrameSolver.Input] {
        var inputs: [VehicleFrameSolver.Input] = []
        var t = 0.0
        for _ in 0..<30 {
            inputs.append(
                VehicleFrameSolver.Input(
                    t: t,
                    gravity: gravity ?? mount.down,
                    userAcceleration: .zero,
                    speed: 15,
                    course: 90
                )
            )
            t += 0.1
        }
        var speed = 15.0
        for _ in 0..<40 {
            speed += 0.25                       // 2.5 m/s², a firm pull away
            inputs.append(
                VehicleFrameSolver.Input(
                    t: t,
                    gravity: gravity ?? mount.down,
                    userAcceleration: mount.forward * 0.255,
                    speed: speed,
                    course: 90
                )
            )
            t += 0.1
        }
        return inputs
    }

    @Test("The frame is solved from an arbitrary mount angle")
    func solves() throws {
        let mount = VehicleFrameTests.mounted()
        var solver = VehicleFrameSolver()
        for input in Self.drive(mount: mount) { solver.add(input) }
        let frame = try #require(solver.frame)
        #expect(frame.forward.dot(mount.forward) > 0.999)
        #expect(frame.down.dot(mount.down) > 0.999)
        #expect(frame.lateral.dot(mount.lateral) > 0.999)
    }

    @Test("Cornering in the car reads as cornering in the phone")
    func resolvesCornering() throws {
        let mount = VehicleFrameTests.mounted()
        var solver = VehicleFrameSolver()
        for input in Self.drive(mount: mount) { solver.add(input) }
        let frame = try #require(solver.frame)
        // 0.5 g to the right, expressed in device axes.
        let measured = frame.resolve(mount.lateral * 0.5)
        #expect(abs(measured.lateral - 0.5) < 0.01)
        #expect(abs(measured.longitudinal) < 0.01)
    }

    @Test("Cruising alone never solves the frame")
    func needsAnAcceleration() {
        let mount = VehicleFrameTests.mounted()
        var solver = VehicleFrameSolver()
        for _ in 0..<600 {
            solver.add(
                VehicleFrameSolver.Input(
                    t: 0,
                    gravity: mount.down,
                    userAcceleration: .zero,
                    speed: 25,
                    course: 90
                )
            )
        }
        #expect(solver.frame == nil)
    }

    @Test("A knock to the phone throws the frame away")
    func knockResets() throws {
        let mount = VehicleFrameTests.mounted()
        var solver = VehicleFrameSolver()
        for input in Self.drive(mount: mount) { solver.add(input) }
        #expect(solver.frame != nil)

        // The mount slips 30°, and stays there.
        let knocked = Vector3(sin(Angles.radians(30)), 0, -cos(Angles.radians(30)))
        var t = 100.0
        for _ in 0..<40 {
            solver.add(
                VehicleFrameSolver.Input(
                    t: t,
                    gravity: knocked,
                    userAcceleration: .zero,
                    speed: 25,
                    course: 90
                )
            )
            t += 0.1
        }
        #expect(solver.frame == nil)
    }

    @Test("A turn while accelerating is not mistaken for straight")
    func curvedRunIsRejected() {
        let mount = VehicleFrameTests.mounted()
        var solver = VehicleFrameSolver()
        var t = 0.0
        var speed = 15.0
        var course = 90.0
        for _ in 0..<200 {
            speed += 0.05
            course += 1.0                       // 10°/s: a long sweeping bend
            solver.add(
                VehicleFrameSolver.Input(
                    t: t,
                    gravity: mount.down,
                    userAcceleration: mount.forward * 0.1 + mount.lateral * 0.3,
                    speed: speed,
                    course: course.truncatingRemainder(dividingBy: 360)
                )
            )
            t += 0.1
        }
        #expect(solver.frame == nil)
    }
}
