import Foundation
import UIKit
import ComposableArchitecture

struct AppRouterClient {
    var openSettings: @Sendable () async -> Void
    var openURL: @Sendable (URL) async -> Void
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
        }
    )
}

extension DependencyValues {
    var appRouter: AppRouterClient {
        get { self[AppRouterClient.self] }
        set { self[AppRouterClient.self] = newValue }
    }
}
