import Foundation
import UIKit
import ComposableArchitecture

enum DeepLink: Sendable {
    case ringing(alarmId: UUID)
}

struct AppRouterClient {
    var openSettings: @Sendable () async -> Void
    var openURL: @Sendable (URL) async -> Void
    /// Parses app URL scheme into a typed deep link (SRP: URL format knowledge in one place).
    var parseDeepLink: @Sendable (URL) -> DeepLink?
}

extension AppRouterClient: DependencyKey {
    static let liveValue = AppRouterClient(
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
        },
        parseDeepLink: { url in
            guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  comps.host == "ringing",
                  let idStr = comps.queryItems?.first(where: { $0.name == "alarmId" })?.value,
                  let id = UUID(uuidString: idStr) else { return nil }
            return .ringing(alarmId: id)
        }
    )
}

extension DependencyValues {
    var appRouter: AppRouterClient {
        get { self[AppRouterClient.self] }
        set { self[AppRouterClient.self] = newValue }
    }
}
