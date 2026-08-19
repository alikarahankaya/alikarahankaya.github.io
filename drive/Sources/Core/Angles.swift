import Foundation

public enum Angles {
    /// Smallest signed difference `a - b`, in degrees, wrapped to (-180, 180].
    /// Courses are compass bearings, so 359° and 1° are 2° apart, not 358°.
    public static func difference(_ a: Double, _ b: Double) -> Double {
        var d = (a - b).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d <= -180 { d += 360 }
        return d
    }

    public static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    public static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
}
