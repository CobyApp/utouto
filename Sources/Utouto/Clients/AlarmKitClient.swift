import Foundation
import SwiftUI
import AlarmKit
import ActivityKit
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
                manager.authorizationState == .authorized
            },
            scheduleAlarm: { alarm, audioURL in
                let schedule = makeSchedule(from: alarm)
                let presentation = AlarmPresentation(
                    alert: AlarmPresentation.Alert(
                        title: LocalizedStringResource(stringLiteral: alarm.label.isEmpty ? L10n.alarmKitDefaultTitle : alarm.label),
                        secondaryButton: alarm.snoozeEnabled
                            ? AlarmButton(text: LocalizedStringResource(stringLiteral: L10n.alarmKitSnoozeButton), textColor: .blue, systemImageName: "moon.zzz")
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
                let sound = Self.soundForAlarm(alarmId: alarm.id, clipAudioURL: audioURL)
                let config = AlarmManager.AlarmConfiguration<UtoutoAlarmMetadata>.alarm(
                    schedule: schedule,
                    attributes: attributes,
                    stopIntent: nil,
                    secondaryIntent: nil,
                    sound: sound
                )
                _ = try await manager.schedule(id: alarm.id, configuration: config)
            },
            cancelAlarm: { id in
                try? await manager.cancel(id: id)
            }
        )
    }()
}

// MARK: - Custom alarm sound (Library/Sounds for lock screen playback)

private extension AlarmKitClient {
    /// Copy clip audio to Library/Sounds and return AlertSound so the alarm rings with custom sound on lock screen.
    static func soundForAlarm(alarmId: UUID, clipAudioURL: URL?) -> AlertConfiguration.AlertSound {
        guard let sourceURL = clipAudioURL else { return .default }
        let fm = FileManager.default
        guard let libraryURL = fm.urls(for: .libraryDirectory, in: .userDomainMask).first else { return .default }
        let soundsDir = libraryURL.appendingPathComponent("Sounds", isDirectory: true)
        let fileName = "\(alarmId.uuidString).m4a"
        let destURL = soundsDir.appendingPathComponent(fileName)
        do {
            try fm.createDirectory(at: soundsDir, withIntermediateDirectories: true)
            if fm.fileExists(atPath: destURL.path) { try fm.removeItem(at: destURL) }
            try fm.copyItem(at: sourceURL, to: destURL)
            return .named(fileName)
        } catch {
            return .default
        }
    }
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
