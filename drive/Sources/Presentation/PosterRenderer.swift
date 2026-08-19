import SwiftUI
// UIKit only for the pixels: ImageRenderer hands back a UIImage and there is
// no SwiftUI-native image type to put in its place.
import UIKit

/// Renders the poster at print scale.
@MainActor
public enum PosterRenderer {
    /// 3:4, 1200 × 1600 at 3×. Big enough to look deliberate when it is
    /// reposted, small enough to share over anything.
    public static let posterSize = CGSize(width: 400, height: 533)

    public static func image(for drive: DrivePresentation) -> UIImage? {
        let renderer = ImageRenderer(
            content: PosterView(drive: drive).frame(
                width: posterSize.width,
                height: posterSize.height
            )
        )
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
