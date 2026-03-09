import Foundation

struct Settings: Codable, Equatable {
    var defaultSnoozeIntervalMin: Int
    var defaultSnoozeMaxCount: Alarm.SnoozeMaxCount
    var defaultDismissMode: Alarm.DismissMode
    var vibrationEnabled: Bool

    static let `default` = Settings(
        defaultSnoozeIntervalMin: 5,
        defaultSnoozeMaxCount: .limited(3),
        defaultDismissMode: .slide,
        vibrationEnabled: true
    )
}
