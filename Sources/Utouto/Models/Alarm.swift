import Foundation

struct Alarm: Identifiable, Codable, Equatable {
    var id: UUID
    var time: DateComponents
    var enabled: Bool
    var repeatDays: [Int] // 0=Sun ... 6=Sat
    var oneTimeDate: Date?
    var label: String
    var clipId: UUID?           // ローカルクリップID
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
        var components = Calendar.current.dateComponents([.hour, .minute], from: now)
        components.hour = 7; components.minute = 0
        return Alarm(id: UUID(), time: components, enabled: true, repeatDays: [],
                     oneTimeDate: nil, label: "", clipId: nil,
                     snoozeEnabled: true, snoozeIntervalMin: 5,
                     snoozeMaxCount: .limited(3), dismissMode: .slide,
                     createdAt: now, updatedAt: now)
    }

    var hour: Int { time.hour ?? 0 }
    var minute: Int { time.minute ?? 0 }
    var timeString: String { String(format: "%02d:%02d", hour, minute) }

    var repeatDaysString: String {
        if repeatDays.isEmpty { return "一度だけ" }
        if repeatDays.count == 7 { return "毎日" }
        let names = ["日","月","火","水","木","金","土"]
        return repeatDays.sorted().map { names[$0] }.joined(separator: " ")
    }
}
