import Foundation
import UserNotifications
import ComposableArchitecture

struct NotificationClient {
    var requestAuthorization: @Sendable () async throws -> Bool
    var isAuthorized: @Sendable () async -> Bool
    var scheduleAlarm: @Sendable (Alarm, URL?) async throws -> Void
    var cancelAlarm: @Sendable (UUID) async -> Void
}

extension NotificationClient: DependencyKey {
    static let liveValue: NotificationClient = {
        let impl = NotificationClientLive()
        return NotificationClient(
            requestAuthorization: { try await impl.requestAuthorization() },
            isAuthorized: { await impl.isAuthorized() },
            scheduleAlarm: { try await impl.scheduleAlarm($0, audioURL: $1) },
            cancelAlarm: { await impl.cancelAlarm($0) }
        )
    }()
}

extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}

private actor NotificationClientLive {
    func requestAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { cont in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
                granted, error in
                if let error = error { cont.resume(throwing: error) }
                else { cont.resume(returning: granted) }
            }
        }
    }
    func isAuthorized() async -> Bool {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        return s.authorizationStatus == .authorized || s.authorizationStatus == .provisional
    }
    func scheduleAlarm(_ alarm: Alarm, audioURL: URL?) async throws {
        let content = UNMutableNotificationContent()
        content.title = "うとうと"
        content.body = alarm.label.isEmpty ? "アラーム" : alarm.label
        content.userInfo = ["alarmId": alarm.id.uuidString]

        // カスタムサウンド
        if let audioURL = audioURL {
            // UNNotificationSound はApp Groupなどで共有ストレージへのコピーが必要
            // 開発段階ではデフォルトサウンドにフォールバック
            let soundName = audioURL.deletingPathExtension().lastPathComponent
            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName + ".m4a"))
        } else {
            content.sound = .default
        }

        let days = alarm.repeatDays
        if days.isEmpty {
            var comps = DateComponents(); comps.hour = alarm.hour; comps.minute = alarm.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let req = UNNotificationRequest(identifier: alarm.id.uuidString, content: content, trigger: trigger)
            try await UNUserNotificationCenter.current().add(req)
        } else {
            for day in days {
                var comps = DateComponents()
                comps.hour = alarm.hour; comps.minute = alarm.minute; comps.weekday = day + 1
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                let req = UNNotificationRequest(identifier: "\(alarm.id.uuidString)_\(day)", content: content, trigger: trigger)
                try await UNUserNotificationCenter.current().add(req)
            }
        }
    }
    func cancelAlarm(_ id: UUID) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.filter { $0.identifier.hasPrefix(id.uuidString) }.map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
