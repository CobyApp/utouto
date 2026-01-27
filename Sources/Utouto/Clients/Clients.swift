import Foundation
import UserNotifications
import AVFoundation
import UIKit
import ComposableArchitecture

// MARK: - TCA Clients

struct AlarmRepositoryClient {
    var loadAlarms: @Sendable () async throws -> [Alarm]
    var saveAlarm: @Sendable (Alarm) async throws -> Void
    var updateAlarm: @Sendable (Alarm) async throws -> Void
    var deleteAlarm: @Sendable (UUID) async throws -> Void
    var loadSettings: @Sendable () async throws -> Settings
    var saveSettings: @Sendable (Settings) async throws -> Void
    var loadCharacters: @Sendable () async throws -> [Character]
    var loadAlarmLogs: @Sendable () async throws -> [AlarmLog]
    var saveAlarmLog: @Sendable (AlarmLog) async throws -> Void
}

extension AlarmRepositoryClient: DependencyKey {
    static let liveValue: AlarmRepositoryClient = {
        let impl = AlarmRepositoryLive()
        return AlarmRepositoryClient(
            loadAlarms: { try await impl.loadAlarms() },
            saveAlarm: { try await impl.saveAlarm($0) },
            updateAlarm: { try await impl.updateAlarm($0) },
            deleteAlarm: { try await impl.deleteAlarm($0) },
            loadSettings: { try await impl.loadSettings() },
            saveSettings: { try await impl.saveSettings($0) },
            loadCharacters: { try await impl.loadCharacters() },
            loadAlarmLogs: { try await impl.loadAlarmLogs() },
            saveAlarmLog: { try await impl.saveAlarmLog($0) }
        )
    }()
}

extension DependencyValues {
    var alarmRepository: AlarmRepositoryClient {
        get { self[AlarmRepositoryClient.self] }
        set { self[AlarmRepositoryClient.self] = newValue }
    }
}

private actor AlarmRepositoryLive {
    private let fileManager = FileManager.default
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var alarmsURL: URL { documentsDirectory.appendingPathComponent("alarms.json") }
    private var settingsURL: URL { documentsDirectory.appendingPathComponent("settings.json") }
    private var charactersURL: URL { documentsDirectory.appendingPathComponent("characters.json") }
    private var logsURL: URL { documentsDirectory.appendingPathComponent("logs.json") }

    func loadAlarms() async throws -> [Alarm] {
        try await seedIfNeeded()
        guard let data = try? Data(contentsOf: alarmsURL) else { return [] }
        return try jsonDecoder.decode([Alarm].self, from: data)
    }

    func saveAlarm(_ alarm: Alarm) async throws {
        var alarms = try await loadAlarms()
        alarms.append(alarm)
        let data = try jsonEncoder.encode(alarms)
        try data.write(to: alarmsURL)
    }

    func updateAlarm(_ alarm: Alarm) async throws {
        var alarms = try await loadAlarms()
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index] = alarm
            let data = try jsonEncoder.encode(alarms)
            try data.write(to: alarmsURL)
        }
    }

    func deleteAlarm(_ id: UUID) async throws {
        var alarms = try await loadAlarms()
        alarms.removeAll { $0.id == id }
        let data = try jsonEncoder.encode(alarms)
        try data.write(to: alarmsURL)
    }

    func loadSettings() async throws -> Settings {
        guard let data = try? Data(contentsOf: settingsURL) else {
            return .default
        }
        return try jsonDecoder.decode(Settings.self, from: data)
    }

    func saveSettings(_ settings: Settings) async throws {
        let data = try jsonEncoder.encode(settings)
        try data.write(to: settingsURL)
    }

    func loadCharacters() async throws -> [Character] {
        try await seedCharactersIfNeeded()
        guard let data = try? Data(contentsOf: charactersURL) else { return [] }
        return try jsonDecoder.decode([Character].self, from: data)
    }

    func loadAlarmLogs() async throws -> [AlarmLog] {
        guard let data = try? Data(contentsOf: logsURL) else { return [] }
        return try jsonDecoder.decode([AlarmLog].self, from: data)
    }

    func saveAlarmLog(_ log: AlarmLog) async throws {
        var logs = try await loadAlarmLogs()
        logs.append(log)
        let data = try jsonEncoder.encode(logs)
        try data.write(to: logsURL)
    }

    private func seedIfNeeded() async throws {
        if !fileManager.fileExists(atPath: alarmsURL.path) {
            try JSONEncoder().encode([Alarm]()).write(to: alarmsURL)
        }
    }

    private func seedCharactersIfNeeded() async throws {
        if !fileManager.fileExists(atPath: charactersURL.path) {
            let data = try jsonEncoder.encode(Character.builtIn)
            try data.write(to: charactersURL)
        }
    }
}

struct NotificationClient {
    var requestAuthorization: @Sendable () async throws -> Bool
    var isAuthorized: @Sendable () async -> Bool
    var scheduleAlarm: @Sendable (Alarm) async throws -> Void
    var cancelAlarm: @Sendable (UUID) async -> Void
    var getPendingRequests: @Sendable () async -> [String]
}

extension NotificationClient: DependencyKey {
    static let liveValue: NotificationClient = {
        let impl = NotificationClientLive()
        return NotificationClient(
            requestAuthorization: { try await impl.requestAuthorization() },
            isAuthorized: { await impl.isAuthorized() },
            scheduleAlarm: { try await impl.scheduleAlarm($0) },
            cancelAlarm: { await impl.cancelAlarm($0) },
            getPendingRequests: { await impl.getPendingRequests() }
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
        print("[NotificationClient] requestAuthorization called")
        return try await withCheckedThrowingContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    print("[NotificationClient] requestAuthorization error: \(error)")
                    continuation.resume(throwing: error)
                } else {
                    print("[NotificationClient] requestAuthorization result: granted=\(granted)")
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        print("[NotificationClient] isAuthorized: status=\(settings.authorizationStatus.rawValue), result=\(isAuthorized)")
        return isAuthorized
    }

    func scheduleAlarm(_ alarm: Alarm) async throws {
        let content = UNMutableNotificationContent()
        content.title = "うとうと"
        content.body = alarm.label.isEmpty ? "アラーム" : alarm.label
        content.sound = .default
        content.userInfo = ["alarmId": alarm.id.uuidString]

        if alarm.repeatDays.isEmpty {
            // One-time alarm
            guard let oneTimeDate = alarm.oneTimeDate else {
                // Use today's time
                var components = DateComponents()
                components.hour = alarm.hour
                components.minute = alarm.minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(identifier: alarm.id.uuidString, content: content, trigger: trigger)
                try await UNUserNotificationCenter.current().add(request)
                return
            }

            let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: oneTimeDate), repeats: false)
            let request = UNNotificationRequest(identifier: alarm.id.uuidString, content: content, trigger: trigger)
            try await UNUserNotificationCenter.current().add(request)
        } else {
            // Repeating alarm for specific days
            for day in alarm.repeatDays {
                var components = DateComponents()
                components.hour = alarm.hour
                components.minute = alarm.minute
                components.weekday = day + 1 // UNCalendarNotificationTrigger uses 1=Sunday

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(identifier: "\(alarm.id.uuidString)_\(day)", content: content, trigger: trigger)
                try await UNUserNotificationCenter.current().add(request)
            }
        }
    }

    func cancelAlarm(_ id: UUID) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending
            .filter { $0.identifier.hasPrefix(id.uuidString) }
            .map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func getPendingRequests() async -> [String] {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.map { $0.identifier }
    }
}

struct AudioClient {
    var playWakeClip: @Sendable (Character?, String?) async -> Void
    var playSnoozeClip: @Sendable (Character?) async -> Void
    var playAngryClip: @Sendable (Character?) async -> Void
    var stopPlayback: @Sendable () async -> Void
    var setVolume: @Sendable (Float) async -> Void
}

extension AudioClient: DependencyKey {
    static let liveValue: AudioClient = {
        let impl = AudioClientLive()
        return AudioClient(
            playWakeClip: { await impl.playWakeClip(character: $0, clipName: $1) },
            playSnoozeClip: { await impl.playSnoozeClip(character: $0) },
            playAngryClip: { await impl.playAngryClip(character: $0) },
            stopPlayback: { await impl.stopPlayback() },
            setVolume: { await impl.setVolume($0) }
        )
    }()
}

extension DependencyValues {
    var audioClient: AudioClient {
        get { self[AudioClient.self] }
        set { self[AudioClient.self] = newValue }
    }
}

private actor AudioClientLive {
    private var player: AVAudioPlayer?

    func playWakeClip(character: Character?, clipName: String?) async {
        await configureAudioSession()

        let clipToPlay: String
        if let clipName = clipName {
            clipToPlay = clipName
        } else if let character = character, let randomClip = character.voiceClipsWake.randomElement() {
            clipToPlay = randomClip
        } else {
            // Fallback to default
            clipToPlay = "wake_default" // TODO: Add default asset
        }

        guard let url = Bundle.main.url(forResource: clipToPlay, withExtension: "mp3") else {
            print("Audio file not found: \(clipToPlay)")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = 0 // Play once, app will handle looping
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("Audio playback error: \(error)")
        }
    }

    func playSnoozeClip(character: Character?) async {
        await configureAudioSession()

        let clipToPlay = character?.voiceClipsSnooze.randomElement() ?? "snooze_default" // TODO: Add default asset

        guard let url = Bundle.main.url(forResource: clipToPlay, withExtension: "mp3") else {
            print("Audio file not found: \(clipToPlay)")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = 0
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("Audio playback error: \(error)")
        }
    }

    func playAngryClip(character: Character?) async {
        await configureAudioSession()

        let clipToPlay = character?.voiceClipsAngry.randomElement() ?? "angry_default" // TODO: Add default asset

        guard let url = Bundle.main.url(forResource: clipToPlay, withExtension: "mp3") else {
            print("Audio file not found: \(clipToPlay)")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = 0
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("Audio playback error: \(error)")
        }
    }

    func stopPlayback() async {
        player?.stop()
        player = nil
    }

    func setVolume(_ volume: Float) async {
        player?.volume = volume
    }

    private func configureAudioSession() async {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            print("Audio session configuration error: \(error)")
        }
    }
}

struct AppRouterClient {
    var openSettings: @Sendable () async -> Void
    var openURL: @Sendable (URL) async -> Void
}

extension AppRouterClient: DependencyKey {
    static let liveValue: AppRouterClient = AppRouterClient(
        openSettings: {
            await MainActor.run {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        },
        openURL: { url in
            await MainActor.run {
                UIApplication.shared.open(url)
            }
        }
    )
}

extension DependencyValues {
    var appRouter: AppRouterClient {
        get { self[AppRouterClient.self] }
        set { self[AppRouterClient.self] = newValue }
    }
}

struct ClockClient {
    var now: @Sendable () -> Date
    var calendar: @Sendable () -> Calendar
}

extension ClockClient: DependencyKey {
    static let liveValue: ClockClient = ClockClient(
        now: { Date() },
        calendar: { Calendar.current }
    )
}

extension DependencyValues {
    var clock: ClockClient {
        get { self[ClockClient.self] }
        set { self[ClockClient.self] = newValue }
    }
}

struct LoggerClient {
    var log: @Sendable (String) -> Void
    var error: @Sendable (String) -> Void
}

extension LoggerClient: DependencyKey {
    static let liveValue: LoggerClient = LoggerClient(
        log: { print("[LOG] \($0)") },
        error: { print("[ERROR] \($0)") }
    )
}

extension DependencyValues {
    var logger: LoggerClient {
        get { self[LoggerClient.self] }
        set { self[LoggerClient.self] = newValue }
    }
}
