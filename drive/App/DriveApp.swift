import SwiftUI
import Storage

@main
struct DriveApp: App {
    @State private var library: DriveLibrary?
    private let failure: String?

    init() {
        do {
            let container = try DriveStore.container()
            _library = State(
                initialValue: DriveLibrary(store: DriveStore(modelContainer: container))
            )
            failure = nil
        } catch {
            _library = State(initialValue: nil)
            failure = "The drive library could not be opened."
        }
    }

    var body: some Scene {
        WindowGroup {
            if let library {
                RootView(library: library)
            } else {
                Text(failure ?? "")
                    .font(.footnote)
                    .padding()
            }
        }
    }
}
