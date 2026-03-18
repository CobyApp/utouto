import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit
import UtoutoAlarmKit

// MARK: - Alarm Live Activity (Lock Screen, Dynamic Island)

struct UtoutoAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<UtoutoAlarmMetadata>.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    leadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    trailingView(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    centerView(context: context)
                }
            } compactLeading: {
                compactLeadingView(context: context)
            } compactTrailing: {
                compactTrailingView(context: context)
            } minimal: {
                minimalView(context: context)
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<AlarmAttributes<UtoutoAlarmMetadata>>) -> some View {
        switch context.state.mode {
        case .countdown:
            countdownView(context: context)
        case .paused:
            pausedView(context: context)
        case .alert:
            alertView(context: context)
        @unknown default:
            countdownView(context: context)
        }
    }

    private func countdownView(context: ActivityViewContext<AlarmAttributes<UtoutoAlarmMetadata>>) -> some View {
        Group {
            if case .countdown(let data) = context.state.mode {
                VStack(alignment: .leading, spacing: 8) {
                    Text(context.attributes.presentation.alert.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(timerInterval: Date() ... data.fireDate, countsDown: true)
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(context.attributes.presentation.alert.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private func pausedView(context: ActivityViewContext<AlarmAttributes<UtoutoAlarmMetadata>>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paused")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private func alertView(context: ActivityViewContext<AlarmAttributes<UtoutoAlarmMetadata>>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(context.attributes.presentation.alert.title)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private func leadingView(context: ActivityViewContext<AlarmAttributes<UtoutoAlarmMetadata>>) -> some View {
        Image(systemName: "alarm.fill")
            .foregroundStyle(context.attributes.tintColor)
    }

    private func trailingView(context: ActivityViewContext<AlarmAttributes<UtoutoAlarmMetadata>>) -> some View {
        Text(context.attributes.presentation.alert.title)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func centerView(context: ActivityViewContext<AlarmAttributes<UtoutoAlarmMetadata>>) -> some View {
        countdownView(context: context)
    }

    private func compactLeadingView(context: ActivityViewContext<AlarmAttributes<UtoutoAlarmMetadata>>) -> some View {
        Image(systemName: "alarm.fill")
            .foregroundStyle(context.attributes.tintColor)
    }

    private func compactTrailingView(context: ActivityViewContext<AlarmAttributes<UtoutoAlarmMetadata>>) -> some View {
        Group {
            if case .countdown(let data) = context.state.mode {
                Text(timerInterval: Date() ... data.fireDate, countsDown: true)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "alarm")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func minimalView(context: ActivityViewContext<AlarmAttributes<UtoutoAlarmMetadata>>) -> some View {
        Image(systemName: "alarm.fill")
            .foregroundStyle(context.attributes.tintColor)
    }
}

// MARK: - Widget Bundle

@main
struct UtoutoWidgetBundle: WidgetBundle {
    var body: some Widget {
        UtoutoAlarmLiveActivity()
    }
}
