import Foundation
import ComposableArchitecture

struct AlarmRepositoryClient {
    var loadAlarms: @Sendable () async throws -> [Alarm]
    var saveAlarm: @Sendable (Alarm) async throws -> Void
    var updateAlarm: @Sendable (Alarm) async throws -> Void
    var deleteAlarm: @Sendable (UUID) async throws -> Void
    var loadSettings: @Sendable () async throws -> Settings
    var saveSettings: @Sendable (Settings) async throws -> Void
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
