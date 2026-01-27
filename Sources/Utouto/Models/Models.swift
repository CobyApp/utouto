import Foundation

// MARK: - Core Data Models

struct Alarm: Identifiable, Codable, Equatable {
    var id: UUID
    var time: DateComponents // hour, minute only for scheduling
    var enabled: Bool
    var repeatDays: [Int] // 0=Sun, 1=Mon, ..., 6=Sat
    var oneTimeDate: Date?
    var label: String
    var characterId: String?
    var snoozeEnabled: Bool
    var snoozeIntervalMin: Int
    var snoozeMaxCount: SnoozeMaxCount
    var dismissMode: DismissMode
    var createdAt: Date
    var updatedAt: Date

    enum SnoozeMaxCount: Codable, Equatable, Hashable {
        case limited(Int)
        case unlimited
    }

    enum DismissMode: String, Codable, Equatable {
        case slide
        case longPress
    }

    static func newDefault() -> Alarm {
        let now = Date()
        let calendar = Calendar.current
        var components = calendar.dateComponents([.hour, .minute], from: now)
        components.hour = 7
        components.minute = 0

        return Alarm(
            id: UUID(),
            time: components,
            enabled: true,
            repeatDays: [],
            oneTimeDate: nil,
            label: "",
            characterId: nil,
            snoozeEnabled: true,
            snoozeIntervalMin: 5,
            snoozeMaxCount: .limited(3),
            dismissMode: .slide,
            createdAt: now,
            updatedAt: now
        )
    }

    var hour: Int { time.hour ?? 0 }
    var minute: Int { time.minute ?? 0 }

    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var repeatDaysString: String {
        if repeatDays.isEmpty {
            return "一度だけ"
        } else if repeatDays.count == 7 {
            return "毎日"
        } else {
            let dayNames = ["日", "月", "火", "水", "木", "金", "土"]
            return repeatDays.sorted().map { dayNames[$0] }.joined(separator: " ")
        }
    }
}

struct Settings: Codable, Equatable {
    var defaultCharacterId: String?
    var defaultSnoozeIntervalMin: Int
    var defaultSnoozeMaxCount: Alarm.SnoozeMaxCount
    var defaultDismissMode: Alarm.DismissMode
    var vibrationEnabled: Bool

    static let `default` = Settings(
        defaultCharacterId: nil,
        defaultSnoozeIntervalMin: 5,
        defaultSnoozeMaxCount: .limited(3),
        defaultDismissMode: .slide,
        vibrationEnabled: true
    )
}

struct Character: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var personalityType: String
    var imageAssetName: String
    var voiceClipsWake: [String]
    var voiceClipsSnooze: [String]
    var voiceClipsAngry: [String]

    // Built-in characters
    static let gentle = Character(
        id: "gentle",
        name: "優しい",
        personalityType: "gentle",
        imageAssetName: "character_gentle", // TODO: Add asset
        voiceClipsWake: ["wake_gentle_1", "wake_gentle_2"], // TODO: Add assets
        voiceClipsSnooze: ["snooze_gentle_1"],
        voiceClipsAngry: ["angry_gentle_1"]
    )

    static let tsundere = Character(
        id: "tsundere",
        name: "ツンデレ",
        personalityType: "tsundere",
        imageAssetName: "character_tsundere", // TODO: Add asset
        voiceClipsWake: ["wake_tsundere_1", "wake_tsundere_2"], // TODO: Add assets
        voiceClipsSnooze: ["snooze_tsundere_1"],
        voiceClipsAngry: ["angry_tsundere_1"]
    )

    static let cool = Character(
        id: "cool",
        name: "クール",
        personalityType: "cool",
        imageAssetName: "character_cool", // TODO: Add asset
        voiceClipsWake: ["wake_cool_1", "wake_cool_2"], // TODO: Add assets
        voiceClipsSnooze: ["snooze_cool_1"],
        voiceClipsAngry: ["angry_cool_1"]
    )

    static let builtIn: [Character] = [gentle, tsundere, cool]
}

struct AlarmLog: Codable, Equatable {
    var id: UUID
    var alarmId: UUID
    var firedAt: Date
    var dismissedAt: Date?
    var snoozeCount: Int
    var result: Result

    enum Result: String, Codable {
        case dismissed
        case snoozed
        case timedOut
    }
}