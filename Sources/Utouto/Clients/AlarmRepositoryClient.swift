import Foundation
import ComposableArchitecture

// MARK: - AlarmRepositoryBackend (DIP: depend on abstraction for testability)
protocol AlarmRepositoryBackend: Sendable {
    func loadAlarms() async throws -> [Alarm]
    func saveAlarm(_ alarm: Alarm) async throws
    func updateAlarm(_ alarm: Alarm) async throws
    func deleteAlarm(_ id: UUID) async throws
    func loadSettings() async throws -> Settings
    func saveSettings(_ s: Settings) async throws
    func loadAlarmLogs() async throws -> [AlarmLog]
    func saveAlarmLog(_ log: AlarmLog) async throws
}

struct AlarmRepositoryClient {
    var loadAlarms: @Sendable () async throws -> [Alarm]
    var saveAlarm: @Sendable (Alarm) async throws -> Void
    var updateAlarm: @Sendable (Alarm) async throws -> Void
    var deleteAlarm: @Sendable (UUID) async throws -> Void
    var loadSettings: @Sendable () async throws -> Settings
    var saveSettings: @Sendable (Settings) async throws -> Void
    var loadAlarmLogs: @Sendable () async throws -> [AlarmLog]
    var saveAlarmLog: @Sendable (AlarmLog) async throws -> Void

    /// Build client with injectable backend (DIP: tests can pass a mock).
    static func live(backend: AlarmRepositoryBackend) -> AlarmRepositoryClient {
        AlarmRepositoryClient(
            loadAlarms: { try await backend.loadAlarms() },
            saveAlarm: { try await backend.saveAlarm($0) },
            updateAlarm: { try await backend.updateAlarm($0) },
            deleteAlarm: { try await backend.deleteAlarm($0) },
            loadSettings: { try await backend.loadSettings() },
            saveSettings: { try await backend.saveSettings($0) },
            loadAlarmLogs: { try await backend.loadAlarmLogs() },
            saveAlarmLog: { try await backend.saveAlarmLog($0) }
        )
    }
}

extension AlarmRepositoryClient: DependencyKey {
    static let liveValue: AlarmRepositoryClient = {
        let impl = AlarmRepositoryLive()
        return AlarmRepositoryClient.live(backend: impl)
    }()
}

extension DependencyValues {
    var alarmRepository: AlarmRepositoryClient {
        get { self[AlarmRepositoryClient.self] }
        set { self[AlarmRepositoryClient.self] = newValue }
    }
}

private actor AlarmRepositoryLive: AlarmRepositoryBackend {
    private let fm = FileManager.default
    private let enc = JSONEncoder()
    private let dec = JSONDecoder()
    private var docs: URL { fm.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    private var alarmsURL: URL { docs.appendingPathComponent("alarms.json") }
    private var settingsURL: URL { docs.appendingPathComponent("settings.json") }
    private var logsURL: URL { docs.appendingPathComponent("logs.json") }

    func loadAlarms() async throws -> [Alarm] {
        guard let data = try? Data(contentsOf: alarmsURL) else { return [] }
        return try dec.decode([Alarm].self, from: data)
    }
    func saveAlarm(_ alarm: Alarm) async throws {
        var list = try await loadAlarms()
        guard !list.contains(where: { $0.id == alarm.id }) else { return }
        list.append(alarm)
        try enc.encode(list).write(to: alarmsURL)
    }
    func updateAlarm(_ alarm: Alarm) async throws {
        var list = try await loadAlarms()
        if let i = list.firstIndex(where: { $0.id == alarm.id }) { list[i] = alarm }
        try enc.encode(list).write(to: alarmsURL)
    }
    func deleteAlarm(_ id: UUID) async throws {
        var list = try await loadAlarms()
        list.removeAll { $0.id == id }
        try enc.encode(list).write(to: alarmsURL)
    }
    func loadSettings() async throws -> Settings {
        guard let data = try? Data(contentsOf: settingsURL) else { return .default }
        return try dec.decode(Settings.self, from: data)
    }
    func saveSettings(_ s: Settings) async throws {
        try enc.encode(s).write(to: settingsURL)
    }
    func loadAlarmLogs() async throws -> [AlarmLog] {
        guard let data = try? Data(contentsOf: logsURL) else { return [] }
        return try dec.decode([AlarmLog].self, from: data)
    }
    func saveAlarmLog(_ log: AlarmLog) async throws {
        var list = try await loadAlarmLogs(); list.append(log)
        try enc.encode(list).write(to: logsURL)
    }
}
