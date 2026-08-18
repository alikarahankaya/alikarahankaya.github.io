import Foundation

/// What counts as a drive.
///
/// Lives in Core because both ends need it: capture uses it to throw away the
/// trip to the shops without asking, and analysis uses it to decide there is
/// nothing worth drawing.
public enum Keeping {
    /// Three minutes. Shorter than that and nothing has happened yet.
    public static let minimumDuration: TimeInterval = 3 * 60
    /// Two kilometres. A drive around the block is not a drive.
    public static let minimumDistance: Double = 2_000
}
