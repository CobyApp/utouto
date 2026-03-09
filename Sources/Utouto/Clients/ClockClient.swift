import Foundation
import ComposableArchitecture

struct ClockClient: DependencyKey {
    var now: @Sendable () -> Date
    static let liveValue = ClockClient(now: { Date() })
}

extension DependencyValues {
    var clock: ClockClient {
        get { self[ClockClient.self] }
        set { self[ClockClient.self] = newValue }
    }
}
