import SwiftUI
import MapKit

/// Where was this. The only map in the app, and only when asked for.
struct LocationSheet: View {
    let drive: DrivePresentation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Map(initialPosition: .region(region))
                .navigationTitle(drive.placeName ?? "Where")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: drive.analysis.midpoint.lat,
                longitude: drive.analysis.midpoint.lon
            ),
            // Wide enough to say which valley, not which junction.
            latitudinalMeters: 20_000,
            longitudinalMeters: 20_000
        )
    }
}
