import Foundation
import ComposableArchitecture

struct LoggerClient: DependencyKey {
    var log: @Sendable (String) -> Void
    var error: @Sendable (String) -> Void
    static let liveValue = LoggerClient(log: { print("[LOG] \($0)") }, error: { print("[ERR] \($0)") })
}

extension DependencyValues {
    var logger: LoggerClient {
        get { self[LoggerClient.self] }
        set { self[LoggerClient.self] = newValue }
    }
}
