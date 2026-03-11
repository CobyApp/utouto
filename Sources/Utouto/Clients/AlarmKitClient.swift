import Foundation
import SwiftUI
import AlarmKit
import ComposableArchitecture

/// Metadata for AlarmKit UI (required by AlarmAttributes).
struct UtoutoAlarmMetadata: AlarmMetadata, Sendable {}

struct AlarmKitClient {
    var requestAuthorization: @Sendable () async throws -> Bool
    var isAuthorized: @Sendable () async -> Bool
    var scheduleAlarm: @Sendable (Alarm, URL?) async throws -> Void
    var cancelAlarm: @Sendable (UUID) async -> Void
}

extension AlarmKitClient: DependencyKey {
    static let liveValue: AlarmKitClient = {
        let manager = AlarmManager.shared
        return AlarmKitClient(
            requestAuthorization: {
                let state = try await manager.requestAuthorization()
                return state == .authorized
            },
            isAuthorized: {
                await manager.authorizationState == .authorized
            },
            scheduleAlarm: { alarm, _ in
                let schedule = makeSchedule(from: alarm)
                let presentation = AlarmPresentation(
                    alert: AlarmPresentation.Alert(
                        title: LocalizedStringResource(stringLiteral: alarm.label.isEmpty ? "うとうと" : alarm.label),
                        secondaryButton: alarm.snoozeEnabled
                            ? AlarmButton(text: "スヌーズ", textColor: .blue, systemImageName: "moon.zzz")
                            : nil,
                        secondaryButtonBehavior: alarm.snoozeEnabled ? .countdown : nil
                    )
                )
                let metadata = UtoutoAlarmMetadata()
                let attributes = AlarmAttributes(
                    presentation: presentation,
                    metadata: metadata,
                    tintColor: Color.blue
                )
                let config = AlarmManager.AlarmConfiguration<UtoutoAlarmMetadata>.alarm(
                    schedule: schedule,
                    attributes: attributes,
                    stopIntent: nil,
                    secondaryIntent: nil,
                    sound: .default
                )
                _ = try await manager.schedule(id: alarm.id, configuration: config)
            },
            cancelAlarm: { id in
                try? await manager.cancel(id: id)
            }
        )
    }()
}

extension DependencyValues {
    var alarmKitClient: AlarmKitClient {
        get { self[AlarmKitClient.self] }
        set { self[AlarmKitClient.self] = newValue }
    }
}

// MARK: - Map app Alarm to AlarmKit.Alarm.Schedule

private func makeSchedule(from alarm: Alarm) -> AlarmKit.Alarm.Schedule? {
    let hour = alarm.hour
    let minute = alarm.minute
    let time = AlarmKit.Alarm.Schedule.Relative.Time(hour: hour, minute: minute)

    if let oneTime = alarm.oneTimeDate, alarm.repeatDays.isEmpty {
        return .fixed(oneTime)
    }

    if alarm.repeatDays.isEmpty {
        return .relative(.init(time: time, repeats: .never))
    }

    let weekdays: [Locale.Weekday] = alarm.repeatDays.compactMap { dayIndex in
        guard (0..<7).contains(dayIndex) else { return nil }
        let symbols = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
        return Locale.Weekday(rawValue: symbols[dayIndex])
    }
    return .relative(.init(time: time, repeats: .weekly(weekdays)))
}
