import SwiftUI
import WidgetKit
import ActivityKit
import Capture

/// Everything the driver sees while driving.
///
/// Elapsed time, and the word for what is happening. No speed, no distance,
/// no map, no corner count: those all invite a glance, and a glance is the
/// thing this app is built to avoid. The timer runs in the widget from the
/// start date, so nothing is ever pushed to it mid-drive.
struct DriveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DriveActivityAttributes.self) { context in
            HStack {
                Text("Recording")
                    .font(.footnote)
                    .textCase(.uppercase)
                    .tracking(1.6)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(context.attributes.startedAt, style: .timer)
                    .font(.system(.title2, design: .serif).monospacedDigit())
            }
            .padding()
            .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.startedAt, style: .timer)
                        .font(.system(.title, design: .serif).monospacedDigit())
                        .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                Image(systemName: "record.circle")
            } compactTrailing: {
                Text(context.attributes.startedAt, style: .timer)
                    .monospacedDigit()
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "record.circle")
            }
        }
    }
}

@main
struct DriveWidgets: WidgetBundle {
    var body: some Widget {
        DriveActivityWidget()
    }
}
