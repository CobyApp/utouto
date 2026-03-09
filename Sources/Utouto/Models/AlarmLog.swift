import Foundation

struct AlarmLog: Codable, Equatable {
    var id: UUID
    var alarmId: UUID
    var firedAt: Date
    var dismissedAt: Date?
    var snoozeCount: Int
    var result: Result

    enum Result: String, Codable {
        case dismissed, snoozed, timedOut
    }
}
