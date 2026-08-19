// swift-tools-version: 6.0
import PackageDescription

// Strict concurrency is the whole point of Swift 6 mode here: capture runs on
// sensor callbacks, analysis runs off the main actor, and the UI reads the
// result. Data races in that shape are silent and expensive, so the compiler
// checks them rather than us.
let strict: [SwiftSetting] = [.swiftLanguageMode(.v6)]

let package = Package(
    name: "DriveKit",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "GPX", targets: ["GPX"]),
        .library(name: "Analysis", targets: ["Analysis"]),
        .library(name: "Storage", targets: ["Storage"]),
        .library(name: "Capture", targets: ["Capture"]),
        .library(name: "Presentation", targets: ["Presentation"]),
    ],
    targets: [
        // Value types and pure vector maths shared by every module. No I/O,
        // no framework imports beyond Foundation. This is the one place a
        // dependency arrow is allowed to point.
        .target(name: "Core", swiftSettings: strict),

        // GPX in, [Sample] out. Pure string parsing; used by the tests and by
        // the debug replay recorder.
        .target(name: "GPX", dependencies: ["Core"], swiftSettings: strict),

        // [Sample] -> DriveAnalysis. Pure functions, no I/O, no clock.
        .target(name: "Analysis", dependencies: ["Core"], swiftSettings: strict),

        // Persistence. Stores blobs; does not know what is in them.
        .target(name: "Storage", dependencies: ["Core"], swiftSettings: strict),

        // Sensors in, samples out. Knows nothing about analysis or UI.
        .target(name: "Capture", dependencies: ["Core", "GPX"], swiftSettings: strict),

        // SwiftUI. Reads analysis output. Never touches CLLocationManager.
        .target(
            name: "Presentation",
            dependencies: ["Core", "Analysis", "Storage"],
            swiftSettings: strict
        ),

        // Synthetic GPX of known geometry, shared by the test targets.
        .target(
            name: "Fixtures",
            dependencies: ["Core", "GPX"],
            resources: [.copy("GPX")],
            swiftSettings: strict
        ),

        .testTarget(name: "CoreTests", dependencies: ["Core"], swiftSettings: strict),
        .testTarget(
            name: "GPXTests",
            dependencies: ["Core", "GPX", "Fixtures"],
            swiftSettings: strict
        ),
        .testTarget(
            name: "AnalysisTests",
            dependencies: ["Core", "Analysis", "Fixtures"],
            swiftSettings: strict
        ),
        .testTarget(
            name: "CaptureTests",
            dependencies: ["Core", "Capture"],
            swiftSettings: strict
        ),
        .testTarget(
            name: "StorageTests",
            dependencies: ["Core", "Storage"],
            swiftSettings: strict
        ),
        .testTarget(
            name: "PresentationTests",
            dependencies: ["Analysis", "Presentation"],
            swiftSettings: strict
        ),
    ]
)
